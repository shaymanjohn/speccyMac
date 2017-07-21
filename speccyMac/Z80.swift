//
//  Z80.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

class Z80 {
    
    var a: UInt8 = 0
    var b: UInt8 = 0
    var c: UInt8 = 0
    var d: UInt8 = 0
    var e: UInt8 = 0
    var f: UInt8 = 0
    var h: UInt8 = 0
    var l: UInt8 = 0
    
    var ixyh: UInt8 = 0
    var ixyl: UInt8 = 0
    
    var ix: UInt16 = 0
    var iy: UInt16 = 0
    
    var sp: UInt16 = 0
    var pc: UInt16 = 0
    
    var r: UInt8 = 0
    var i: UInt8 = 0
    
    var iff1: UInt8 = 0
    var iff2: UInt8 = 0
    
    var af: UInt16 {
        @inline(__always) get {
            return (UInt16(a) << 8) + UInt16(f)
        }
        
        @inline(__always) set(newValue) {
            a = UInt8(newValue >> 8)
            f = UInt8(newValue & 0x00ff)
        }
    }
    
    var bc: UInt16 {
        @inline(__always) get {
            return (UInt16(b) << 8) + UInt16(c)
        }
        
        @inline(__always) set(newValue) {
            b = UInt8(newValue >> 8)
            c = UInt8(newValue & 0x00ff)
        }
    }
    
    var de: UInt16 {
        @inline(__always) get {
            return (UInt16(d) << 8) + UInt16(e)
        }
        
        @inline(__always) set(newValue) {
            d = UInt8(newValue >> 8)
            e = UInt8(newValue & 0x00ff)
        }
    }
    
    var hl: UInt16 {
        @inline(__always) get {
            return (UInt16(h) << 8) + UInt16(l)
        }
        
        @inline(__always) set(newValue) {
            h = UInt8(newValue >> 8)
            l = UInt8(newValue & 0x00ff)
        }
    }
    
    var ixy: UInt16 {
        @inline(__always) get {
            return (UInt16(ixyh) << 8) + UInt16(ixyl)
        }
        
        @inline(__always) set(newValue) {
            ixyh = UInt8(newValue >> 8)
            ixyl = UInt8(newValue & 0x00ff)
        }
    }
    
    weak var screen: Screen?
    
    var memory: Memory
    
    var exaf: UInt16 = 0
    var exhl: UInt16 = 0
    var exbc: UInt16 = 0
    var exde: UInt16 = 0
    
    var counter:       UInt32 = 0
    let ticksPerFrame: UInt32 = 69888
    
    var paused:        Bool = false
    var ula:           UInt16 = 0
    var videoRow:      UInt16 = 0
    var lastFrame:     TimeInterval = 0
    let frameTime:     TimeInterval = 0.02
    var lateFrames:    UInt16 = 0
    var interrupts:    Bool = false
    var halted:        Bool = false
    var interruptMode: UInt8 = 0
    var running:       Bool = false
    
    var cBit:          UInt8 = 1 << 0
    var nBit:          UInt8 = 1 << 1
    var pvBit:         UInt8 = 1 << 2
    var threeBit:      UInt8 = 1 << 3
    var hBit:          UInt8 = 1 << 4
    var fiveBit:       UInt8 = 1 << 5
    var zBit:          UInt8 = 1 << 6
    var sBit:          UInt8 = 1 << 7
    
    var sz53pvTable:   Array<UInt8> = []
    var sz53Table:     Array<UInt8> = []
    var parityBit:     Array<UInt8> = []
    let halfCarryAdd:  Array<UInt8> = [0, 1 << 4, 1 << 4, 1 << 4, 0, 0, 0, 1 << 4]
    let halfCarrySub:  Array<UInt8> = [0, 0, 1 << 4, 0, 1 << 4, 0, 1 << 4, 1 << 4]
    var overFlowAdd:   Array<UInt8> = [0, 0, 0, 1 << 2, 1 << 2, 0, 0, 0]
    var overFlowSub:   Array<UInt8> = [0, 1 << 2, 0, 0, 0, 0, 1 << 2, 0]
    
    var clicksCount:   UInt32 = 0
    
    struct Instruction {
        var length:     UInt16
        var tStates:    Int
        var altTStates: Int
        var opCode:     String
    }
    
    var unprefixedOps: Array<Instruction> = []
    var edprefixedOps: Array<Instruction> = []
    var ddprefixedOps: Array<Instruction> = []
    
    init(memory: Memory) {
        self.memory = memory
        
        self.parseInstructions()
        self.calculateTables()
    }
    
    func start() {
        var tempPC: UInt16
        var opCode: UInt8
        var byte1:  UInt8
        var byte2:  UInt8
        var byte3:  UInt8
        
        self.running = true
        
        while running {
            do {
                if counter >= self.ticksPerFrame {
                    self.serviceInterrupts()
                } else if !paused {
                    do {
                        tempPC = self.pc
                        opCode = memory.get(tempPC)
                        byte1  = memory.get(tempPC + 1)
                        byte2  = memory.get(tempPC + 2)
                        byte3  = memory.get(tempPC + 3)
                        
                        switch opCode {
                        case 0xcb:
                            try self.cbprefix(opcode: byte1, first: byte2, second: byte3)
                            
                        case 0xdd:
                            self.ixy = self.ix
                            if byte1 == 0xcb {
                                try self.ddcbprefix(opcode: byte3, first: byte2)
                            } else {
                                try self.ddprefix(opcode: byte1, first: byte2, second: byte3)
                            }
                            self.ix = self.ixy
                            
                        case 0xed:
                            try self.edprefix(opcode: byte1, first: byte2, second: byte3)
                            
                        case 0xfd:
                            self.ixy = self.iy
                            if byte1 == 0xcb {
                                try self.ddcbprefix(opcode: byte3, first: byte2)
                            } else {
                                try self.ddprefix(opcode: byte1, first: byte2, second: byte3)
                            }
                            self.iy = self.ixy
                            
                        default:
                            try self.unprefixed(opcode: opCode, first: byte1, second: byte2)
                        }
                    }
                }
                
                if self.ula >= 224 {
                    if self.videoRow > 63 && self.videoRow < 256 {
                        
                    } else if self.videoRow == 311 {
                        self.screen?.refreshScreen()
                    }
                    
                    self.ula = self.ula - 224
                    self.videoRow = self.videoRow + 1
                }
            } catch {
                let err = error as NSError
                print("Unknown opcode error, \(err.domain), \(err.userInfo)")
                running = false
                break
            }
        }
        
        print("Game over")
    }
    
    func loadGame(_ game: String) {
        
        if let loader = Loader(game, memory: self.memory) {
            self.af = loader.af
            self.hl = loader.hl
            self.bc = loader.bc
            self.de = loader.de
            
            self.exaf = loader.exaf
            self.exhl = loader.exhl
            self.exbc = loader.exbc
            self.exde = loader.exde
            
            self.sp = loader.sp
            self.pc = loader.pc
            
            self.ix = loader.ix;
            self.iy = loader.iy;
            
            r = loader.r;
            i = loader.i;
            
            interrupts = loader.interrupts;
            interruptMode = loader.interruptMode;
            
            if (interrupts) {
                iff1 = 1;
                iff2 = 1;
            } else {
                iff1 = 0;
                iff2 = 0;
            }
            
            screen?.borderColour = loader.borderColour;
            
            counter = 0;
            lateFrames = 0;
            halted = false;
            ula = 0;
            videoRow = 0;
            
            // Sound vars
            clicksCount = 0;
            //            beep = false;
            //            soundCounter = 0;
            //            bufferIndex = 0;
            
            //            kempston = 0;
        }
    }
    
    func pause() {
        paused = true
    }
    
    func unpause() {
        paused = false
    }
    
    final func incCounters(amount: UInt16) {
        self.counter = self.counter + UInt32(amount)
        self.ula = self.ula + amount
    }
    
    final func parseInstructions() {
        var json: String
        do {
            let path = Bundle.main.path(forResource: "z80ops", ofType: "txt")
            try json = String.init(contentsOfFile: path!)
            
            let data = json.data(using: .utf8)
            var dict: Dictionary<String, Any>
            do {
                try dict = JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! Dictionary<String, Any>
                
                let unprefixed = dict["unprefixed"] as! Array<Dictionary<String, Any>>
                for opDic in unprefixed {
                    let inst = Instruction(length: opDic["length"] as! UInt16, tStates: opDic["tstates"] as! Int, altTStates: opDic["alt_tstate"] as! Int, opCode: opDic["opcode"] as! String)
                    self.unprefixedOps.append(inst)
                }
                
                let edprefixed = dict["edprefix"] as! Array<Dictionary<String, Any>>
                for opDic in edprefixed {
                    let inst = Instruction(length: opDic["length"] as! UInt16, tStates: opDic["tstates"] as! Int, altTStates: opDic["alt_tstate"] as! Int, opCode: opDic["opcode"] as! String)
                    self.edprefixedOps.append(inst)
                }
                
                let ddprefixed = dict["ddprefix"] as! Array<Dictionary<String, Any>>
                for opDic in ddprefixed {
                    let inst = Instruction(length: opDic["length"] as! UInt16, tStates: opDic["tstates"] as! Int, altTStates: opDic["alt_tstate"] as! Int, opCode: opDic["opcode"] as! String)
                    self.ddprefixedOps.append(inst)
                }
                
            } catch {
                print("couldn't get json")
            }
        } catch {
            print("couldn't find z80ops")
        }
    }
    
    func calculateTables() {
        for ii in 0...255 {
            self.sz53Table.append(UInt8(ii) & (self.threeBit | self.fiveBit | self.sBit))
            var j = UInt(ii)
            var parity:UInt8 = 0
            for _ in 0...7 {
                parity = parity ^ UInt8(j) & 1
                j = j >> 1
            }
            
            if parity == 0 {
                self.parityBit.append(0)
            } else {
                self.parityBit.append(self.pvBit)
            }
            
            self.sz53pvTable.append(sz53Table[ii] | parityBit[ii])
        }
        
        sz53Table[0]   = sz53Table[0] | self.zBit
        sz53pvTable[0] = sz53pvTable[0] | self.zBit
    }
    
    final func serviceInterrupts() {
        let timeNow = Date.timeIntervalSinceReferenceDate
        let thisFrameTime = timeNow - self.lastFrame
        
        if thisFrameTime < self.frameTime {
            self.lastFrame = self.lastFrame + self.frameTime
            Thread.sleep(forTimeInterval: self.frameTime - thisFrameTime)
        } else if thisFrameTime > self.frameTime {
            self.lateFrames = self.lateFrames + 1
            self.lastFrame = timeNow
        } else {
            self.lastFrame = self.lastFrame + self.frameTime
        }
        
        self.counter = self.counter - self.ticksPerFrame
        self.ula = UInt16(self.counter)
        self.videoRow = 0
        
        if self.interrupts == true {
            self.interrupts = false
            
            if self.halted == true {
                self.pc = self.pc + 1
                self.halted = false
            }
            
            self.push(registerPair: self.pc)
            self.incR()
            
            if self.interruptMode < 2 {
                self.pc = 0x0038
                self.incCounters(amount: 13)
            } else {
                let vector = (UInt16(self.i) << 8) + 0xff
                let loByte = memory.get(vector + 1)
                let hiByte = memory.get(vector)
                self.pc = (UInt16(hiByte) << 8) + UInt16(loByte)
                self.incCounters(amount: 19)
            }
        }
    }
    
}
