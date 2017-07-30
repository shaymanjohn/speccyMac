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
        let instruction = edprefixedOps[Int(opcode)]

        switch opcode {
            
        case 0x43:  // ld (nnnn), bc
            memory.set(word16, byte: c)
            memory.set(word16 &+ 1, byte: b)
            
        case 0x47:  // ld i, a
            i = a
            
        case 0x52:  // sbc hl, de
            var result = Int(hl) - Int(de)
            if f & cBit > 0 {
                result = result - 1
            }
            if (result < 0) {
                hl = UInt16(65536 + result)
            } else {
                hl = UInt16(result)
            }
            
        case 0x53:  // ld (nnnn), de
            memory.set(word16, byte: e)
            memory.set(word16 &+ 1, byte: d)
            
        case 0x56:  // im 1
            interruptMode = 1
            
        case 0xb0:  // ldir
            let val = memory.get(hl)
            memory.set(de, byte: val)
            bc = bc &- 1
            
            if bc > 0 {
                pc = pc &- 2
                incCounters(amount: 5)
            }
            
            hl = hl &+ 1
            de = de &+ 1
            
        case 0xb8:  // lddr
            let val = memory.get(hl)
            memory.set(de, byte: val)
            bc = bc &- 1
            
            if bc > 0 {
                pc = pc &- 2
                incCounters(amount: 5)
            }
            
            hl = hl &- 1
            de = de &- 1
            
        default:
            throw NSError(domain: "z80+ed", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
        pc = pc + instruction.length
        
        let ts = instruction.tStates
        incCounters(amount: UInt16(ts))
        
        incR()
        incR()
    }
}
