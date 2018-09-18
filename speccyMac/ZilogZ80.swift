//
//  ZilogZ80.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

protocol Processor: class {
    
    func start()
    func pause()
    func unpause()
    
    var counter:    UInt32 { get set }
    var machine:    Machine? { get set }
    var lateFrames: Int { get }
}

class ZilogZ80 : Processor {
    
    let a = Accumulator()
    let b = Register()
    let c = Register()
    let d = Register()
    let e = Register()
    
    static let f = Register()
    
    let h = Register()
    let l = Register()
    
    let ixyh = Register()
    let ixyl = Register()
    
    let af: RegisterPair
    let hl: RegisterPair
    let bc: RegisterPair
    let de: RegisterPair
    
    var ixy: RegisterPair
    
    var ix: UInt16 = 0
    var iy: UInt16 = 0
    
    static var sp: UInt16 = 0
    var pc: UInt16 = 0
    
    var r = RefreshReg()
    
    var i:    UInt8 = 0
    var iff1: UInt8 = 0
    var iff2: UInt8 = 0
    
    var machine: Machine?
    var memory:  Memory
    
    var exaf: UInt16 = 0
    var exhl: UInt16 = 0
    var exbc: UInt16 = 0
    var exde: UInt16 = 0
    
    var counter:       UInt32 = 0    
    
    var paused:        Bool = false
    var lastFrame:     TimeInterval = 0
    let frameTime:     TimeInterval = 0.02      // pal refresh rate = 50Hz
    var lateFrames:    Int = 0
    var interrupts:    Bool = false
    var halted:        Bool = false
    var interruptMode: UInt8 = 0
    var running:       Bool = false
    
    static let cBit:     UInt8 = 1 << 0
    static let nBit:     UInt8 = 1 << 1
    static let pvBit:    UInt8 = 1 << 2
    static let threeBit: UInt8 = 1 << 3
    static let hBit:     UInt8 = 1 << 4
    static let fiveBit:  UInt8 = 1 << 5
    static let zBit:     UInt8 = 1 << 6
    static let sBit:     UInt8 = 1 << 7
    
    static var sz53pvTable: [UInt8] = []
    static var sz53Table:   [UInt8] = []
    static var parityBit:   [UInt8] = []
    
    static let halfCarryAdd:  [UInt8] = [0, 1 << 4, 1 << 4, 1 << 4, 0, 0, 0, 1 << 4]
    static let halfCarrySub:  [UInt8] = [0, 0, 1 << 4, 0, 1 << 4, 0, 1 << 4, 1 << 4]
    static let overFlowAdd:   [UInt8] = [0, 0, 0, 1 << 2, 1 << 2, 0, 0, 0]
    static let overFlowSub:   [UInt8] = [0, 1 << 2, 0, 0, 0, 0, 1 << 2, 0]

    struct Instruction : Codable {
        var opcode:     String
        var tstates:    UInt32
        var alttstates: UInt32
        var length:     UInt16

        func log(_ pc: UInt16) {
            //            if pc >= 0x4000 {
            print("pc: ", String(pc, radix: 16, uppercase: true), opcode)
            //            }
        }
    }

    struct Instructions : Codable {
        var unprefixed: [Instruction]
        var edprefix:   [Instruction]
        var ddprefix:   [Instruction]
        var cbprefix:   [Instruction]
    }

    var instructionSet: Instructions!
    var log = false
    
    init(memory: Memory) {
        
        af  = RegisterPair(hi: a, lo: ZilogZ80.f)
        hl  = RegisterPair(hi: h, lo: l)
        bc  = RegisterPair(hi: b, lo: c)
        de  = RegisterPair(hi: d, lo: e)
        ixy = RegisterPair(hi: ixyh, lo: ixyl)
        
        self.memory = memory
        
        parseInstructions()
        calculateTables()
        
        ZilogZ80.sp = 0xffff
        pc = 0x0000
        iff1 = 0
        iff2 = 0
    }
    
    func log(_ instruction: Instruction) {
        if log {
            instruction.log(pc)
        }
    }
    
    func dumpReg() {
        print("af: ", String(af.value, radix: 16, uppercase: true))
        print("bc: ", String(bc.value, radix: 16, uppercase: true))
        print("de: ", String(de.value, radix: 16, uppercase: true))
        print("hl: ", String(hl.value, radix: 16, uppercase: true))
        print("ix: ", String(ix, radix: 16, uppercase: true))
        print("iy: ", String(iy, radix: 16, uppercase: true))
        print("sp: ", String(ZilogZ80.sp, radix: 16, uppercase: true))
    }
    
    func start() {
        var opCode: UInt8
        var byte1:  UInt8
        var byte2:  UInt8
        var byte3:  UInt8
        
        running = true        
        
        while running {
            
            if !paused {
                if counter >= machine?.ticksPerFrame ?? 0 {
                    serviceInterrupts()
                } else {
                    do {
                        opCode = memory.get(pc)
                        byte1  = memory.get(pc &+ 1)
                        
                        switch opCode {
                            
                        case 0xcb:
                            try cbprefix(opcode: byte1)
                            
                        case 0xed:
                            byte2 = memory.get(pc &+ 2)
                            byte3 = memory.get(pc &+ 3)
                            try edprefix(opcode: byte1, first: byte2, second: byte3)
                            
                        case 0xdd, 0xfd:
                            byte2 = memory.get(pc &+ 2)
                            byte3 = memory.get(pc &+ 3)
                            
                            let activeRegPair = opCode == 0xdd ? ix : iy
                            ixy.value = activeRegPair
                            
                            if byte1 == 0xcb {
                                try ddcbprefix(opcode: byte3, first: byte2)
                            } else {
                                try ddprefix(opcode: byte1, first: byte2, second: byte3)
                            }
                            
                            if opCode == 0xdd {
                                ix = ixy.value
                            } else {
                                iy = ixy.value
                            }
                            
                        default:
                            byte2 = memory.get(pc &+ 2)
                            try unprefixed(opcode: opCode, first: byte1, second: byte2)
                        }
                    } catch {
                        DispatchQueue.main.async {                  // instruction not emulated...
                            self.machine?.reportProblem(error)
                        }
                        
                        running = false
                    }
                }
                
                machine?.tick()                
            }
        }
    }
    
    final func pause() {
        paused = true
        Thread.sleep(forTimeInterval: 0.1)
    }
    
    final func unpause() {
        counter = 0
        paused = false
    }
    
    final func incCounters(_ amount: UInt32) {
        counter += amount
        machine!.ula = machine!.ula + amount
    }
    
    final func parseInstructions() {
        if let path = Bundle.main.path(forResource: "z80ops", ofType: "json"),
            let json = try? String.init(contentsOfFile: path),
            let data = json.data(using: .utf8) {

            do {
                instructionSet = try JSONDecoder().decode(Instructions.self, from: data)
            } catch {
                print("couldn't parse json")
            }
        } else {
            print("couldn't find opcodes")
        }
    }

    func calculateTables() {
        for ii in 0...255 {
            ZilogZ80.sz53Table.append(UInt8(ii) & (ZilogZ80.threeBit | ZilogZ80.fiveBit | ZilogZ80.sBit))
            var j = UInt(ii)
            var parity:UInt8 = 0
            for _ in 0...7 {
                parity = parity ^ UInt8(j) & 1
                j = j >> 1
            }
            
            if parity == 0 {
                ZilogZ80.parityBit.append(0)
            } else {
                ZilogZ80.parityBit.append(ZilogZ80.pvBit)
            }
            
            ZilogZ80.sz53pvTable.append(ZilogZ80.sz53Table[ii] | ZilogZ80.parityBit[ii])
        }
        
        ZilogZ80.sz53Table[0]   = ZilogZ80.sz53Table[0]   | ZilogZ80.zBit
        ZilogZ80.sz53pvTable[0] = ZilogZ80.sz53pvTable[0] | ZilogZ80.zBit
    }
    
    final func serviceInterrupts() {
        let timeNow = Date.timeIntervalSinceReferenceDate
        let thisFrameTime = timeNow - lastFrame
        
        if thisFrameTime < frameTime {
            lastFrame += frameTime
            Thread.sleep(forTimeInterval: frameTime - thisFrameTime)
        } else if thisFrameTime > frameTime {
            lateFrames += 1
            lastFrame = timeNow
        } else {
            lastFrame += frameTime
        }
        
        counter -= UInt32(machine?.ticksPerFrame ?? 0)
        machine!.ula = counter
        machine!.videoRow = 0
        
        if interrupts {
            interrupts = false
            
            if halted {
                pc = pc &+ 1
                halted = false
            }
            
            memory.push(pc)
            r.inc()
            
            if interruptMode < 2 {
                pc = 0x0038
                incCounters(13)
            } else {
                let vector = (UInt16(i) << 8) | 0xff
                let loByte = memory.get(vector)
                let hiByte = memory.get(vector &+ 1)
                pc = (UInt16(hiByte) << 8) | UInt16(loByte)
                incCounters(19)
            }
        }
    }
    
}
