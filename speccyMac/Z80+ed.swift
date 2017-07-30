//
//  Z80+ed.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
    
    final func edprefix(opcode: UInt8, first: UInt8, second: UInt8) throws {
        
        let word16 = (UInt16(second) << 8) + UInt16(first)
        let instruction = self.edprefixedOps[Int(opcode)]

        switch opcode {
            
        case 0x43:  // ld (nnnn), bc
            memory.set(word16, byte: self.c)
            memory.set(word16 &+ 1, byte: self.b)
            
        case 0x47:  // ld i, a
            self.i = self.a
            
        case 0x52:  // sbc hl, de
            var result = Int(self.hl) - Int(self.de)
            if self.f & self.cBit > 0 {
                result = result - 1
            }
            if (result < 0) {
                self.hl = UInt16(65536 + result)
            } else {
                self.hl = UInt16(result)
            }
            
        case 0x53:  // ld (nnnn), de
            memory.set(word16, byte: self.e)
            memory.set(word16 &+ 1, byte: self.d)
            
        case 0x56:  // im 1
            self.interruptMode = 1
            
        case 0xb0:  // ldir
            let val = memory.get(self.hl)
            memory.set(self.de, byte: val)
            self.bc = self.bc &- 1
            
            if self.bc > 0 {
                self.pc = self.pc &- 2
                self.incCounters(amount: 5)
            }
            
            self.hl = self.hl &+ 1
            self.de = self.de &+ 1
            
        case 0xb8:  // lddr
            let val = memory.get(self.hl)
            memory.set(self.de, byte: val)
            self.bc = self.bc &- 1
            
            if self.bc > 0 {
                self.pc = self.pc &- 2
                self.incCounters(amount: 5)
            }
            
            self.hl = self.hl &- 1
            self.de = self.de &- 1
            
        default:
            throw NSError(domain: "Z80+ed", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode])
        }
        
        self.pc = self.pc + instruction.length
        
        let ts = instruction.tStates
        self.incCounters(amount: UInt16(ts))
        
        self.incR()
        self.incR()
    }
}
