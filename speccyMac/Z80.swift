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
    
    weak var machine: Machine?
    
    var memory: Memory
    
    var exaf: UInt16 = 0
    var exhl: UInt16 = 0
    var exbc: UInt16 = 0
    var exde: UInt16 = 0
    
    var counter:       UInt32 = 0
    
    var paused:        Bool = false
    var ula:           UInt32 = 0
    var videoRow:      UInt16 = 0
    var lastFrame:     TimeInterval = 0
    let frameTime:     TimeInterval = 0.02      // 50 Fps
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
    
//    var clicksCount:   UInt32 = 0
    
    struct Instruction {
        var length:     UInt16
        var tStates:    UInt32
        var altTStates: UInt32
        var opCode:     String
    }
    
    var unprefixedOps:   Array<Instruction> = []
    var edprefixedOps:   Array<Instruction> = []
    var ddprefixedOps:   Array<Instruction> = []
    var cbprefixedOps:   Array<Instruction> = []
    
    init(memory: Memory) {
        self.memory = memory
        
        parseInstructions()
        calculateTables()
    }
    
    func start() {
        var opCode: UInt8
        var byte1:  UInt8
        var byte2:  UInt8
        var byte3:  UInt8
        
        running = true
        
        var insCount = 0
        
        while running {
            do {
                if counter >= machine?.ticksPerFrame ?? 0 {
                    serviceInterrupts()
                } else if !paused {
                    do {
                        opCode = memory.get(pc)
                        byte1  = memory.get(pc + 1)
                        byte2  = memory.get(pc + 2)
                        byte3  = memory.get(pc + 3)
                        
//                        print("insCount: \(insCount), pc: \(pc)")
//                        insCount = insCount + 1
                        
                        switch opCode {
                        case 0xcb:
                            try cbprefix(opcode: byte1, first: byte2, second: byte3)
                            
                        case 0xdd:
                            ixy = ix
                            if byte1 == 0xcb {
                                try ddcbprefix(opcode: byte3, first: byte2)
                            } else {
                                try ddprefix(opcode: byte1, first: byte2, second: byte3)
                            }
                            ix = ixy
                            
                        case 0xed:
                            try edprefix(opcode: byte1, first: byte2, second: byte3)
                            
                        case 0xfd:
                            ixy = iy
                            if byte1 == 0xcb {
                                try ddcbprefix(opcode: byte3, first: byte2)
                            } else {
                                try ddprefix(opcode: byte1, first: byte2, second: byte3)
                            }
                            iy = ixy
                            
                        default:
                            try unprefixed(opcode: opCode, first: byte1, second: byte2)
                        }
                    }
                }
                
                // machine specifics here...
                
                if ula >= 224 {
                    if videoRow > 63 && videoRow < 256 {
                        
                    } else if videoRow == 311 {
                        DispatchQueue.main.async {
                            self.machine?.refreshScreen()
                        }
                    }
                    
                    ula = ula - 224
                    videoRow = videoRow + 1
                }
            } catch {
                let err = error as NSError
                print("Unknown opcode error, \(err.domain), \(err.userInfo)")
                running = false
            }
        }
        
        DispatchQueue.main.async {
            print("Game over")
        }
    }
    
    func loadGame(_ game: String) {
        
        if let loader = Loader(game, memory: memory) {
            af = loader.af
            hl = loader.hl
            bc = loader.bc
            de = loader.de
            
            exaf = loader.exaf
            exhl = loader.exhl
            exbc = loader.exbc
            exde = loader.exde
            
            sp = loader.sp
            pc = loader.pc
            
            ix = loader.ix;
            iy = loader.iy;
            
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
            
            machine?.borderColour = loader.borderColour;
            
            counter = 0;
            lateFrames = 0;
            halted = false;
            ula = 0;
            videoRow = 0;
            
            // Sound vars
//            clicksCount = 0;
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
    
    final func incCounters(amount: UInt32) {
        counter = counter + amount
        ula = ula + amount
    }
    
    final func parseInstructions() {
        var json: String
        do {
            let path = Bundle.main.path(forResource: "z80ops", ofType: "json")
            try json = String.init(contentsOfFile: path!)
            
            let data = json.data(using: .utf8)
            var dict: Dictionary<String, Any>
            do {
                try dict = JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! Dictionary<String, Any>
                
                if let unprefixed = dict["unprefixed"] as? Array<Dictionary<String, Any>> {
                    for opDic in unprefixed {
                        let inst = Instruction(length: opDic["length"] as! UInt16, tStates: opDic["tstates"] as! UInt32, altTStates: opDic["alt_tstate"] as! UInt32, opCode: opDic["opcode"] as! String)
                        unprefixedOps.append(inst)
                    }
                }
                
                if let edprefixed = dict["edprefix"] as? Array<Dictionary<String, Any>> {
                    for opDic in edprefixed {
                        let inst = Instruction(length: opDic["length"] as! UInt16, tStates: opDic["tstates"] as! UInt32, altTStates: opDic["alt_tstate"] as! UInt32, opCode: opDic["opcode"] as! String)
                        edprefixedOps.append(inst)
                    }
                }
                
                if let ddprefixed = dict["ddprefix"] as? Array<Dictionary<String, Any>> {
                    for opDic in ddprefixed {
                        let inst = Instruction(length: opDic["length"] as! UInt16, tStates: opDic["tstates"] as! UInt32, altTStates: opDic["alt_tstate"] as! UInt32, opCode: opDic["opcode"] as! String)
                        ddprefixedOps.append(inst)
                    }
                }
                
                if let cbprefixed = dict["cbprefix"] as? Array<Dictionary<String, Any>> {
                    for opDic in cbprefixed {
                        let inst = Instruction(length: opDic["length"] as! UInt16, tStates: opDic["tstates"] as! UInt32, altTStates: opDic["alt_tstate"] as! UInt32, opCode: opDic["opcode"] as! String)
                        cbprefixedOps.append(inst)
                    }
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
            sz53Table.append(UInt8(ii) & (threeBit | fiveBit | sBit))
            var j = UInt(ii)
            var parity:UInt8 = 0
            for _ in 0...7 {
                parity = parity ^ UInt8(j) & 1
                j = j >> 1
            }
            
            if parity == 0 {
                parityBit.append(0)
            } else {
                parityBit.append(pvBit)
            }
            
            sz53pvTable.append(sz53Table[ii] | parityBit[ii])
        }
        
        sz53Table[0]   = sz53Table[0]   | zBit
        sz53pvTable[0] = sz53pvTable[0] | zBit
    }
    
    final func serviceInterrupts() {
        let timeNow = Date.timeIntervalSinceReferenceDate
        let thisFrameTime = timeNow - lastFrame
        
        if thisFrameTime < frameTime {
            lastFrame = lastFrame + frameTime
            Thread.sleep(forTimeInterval: frameTime - thisFrameTime)
        } else if thisFrameTime > frameTime {
            lateFrames = lateFrames + 1
            lastFrame = timeNow
        } else {
            lastFrame = lastFrame + frameTime
        }
        
        counter = counter - (machine?.ticksPerFrame ?? 0)
        ula = counter
        videoRow = 0
        
        if interrupts == true {
            interrupts = false
            
            if halted == true {
                pc = pc + 1
                halted = false
            }
            
            push(pc)
            incR()
            
            if interruptMode < 2 {
                pc = 0x0038
                incCounters(amount: 13)
            } else {
                let vector = (UInt16(i) << 8) + 0xff
                let loByte = memory.get(vector + 1)
                let hiByte = memory.get(vector)
                pc = (UInt16(hiByte) << 8) + UInt16(loByte)
                incCounters(amount: 19)
            }
        }
    }
    
}
