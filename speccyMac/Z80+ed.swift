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
        
        let word16 = (UInt16(second) << 8) | UInt16(first)
        let instruction = edprefixedOps[opcode]

        switch opcode {
            
        case 0x43:  // ld (nnnn), bc
            memory.set(word16, byte: c.value)
            memory.set(word16 &+ 1, byte: b.value)
            
        case 0x47:  // ld i, a
            i = a.value
            
        case 0x52:  // sbc hl, de
            hl.sbc(de)
            
        case 0x53:  // ld (nnnn), de
            memory.set(word16, byte: e.value)
            memory.set(word16 &+ 1, byte: d.value)
            
        case 0x56:  // im 1
            interruptMode = 1
            
        case 0x78:  // in a, (c)
            a.value = portIn(b.value, low: c.value)
            
        case 0xb0:  // ldir
            let val = memory.get(hl)
            memory.set(de.value, byte: val)
            bc.value = bc.value &- 1
            
            if bc.value > 0 {
                pc = pc &- 2
                incCounters(amount: 5)
            }
            
            hl.value = hl.value &+ 1
            de.value = de.value &+ 1
            
        case 0xb8:  // lddr
            let val = memory.get(hl)
            memory.set(de.value, byte: val)
            bc.value = bc.value &- 1
            
            if bc.value > 0 {
                pc = pc &- 2
                incCounters(amount: 5)
            }
            
            hl.value = hl.value &- 1
            de.value = de.value &- 1
            
        default:
            throw NSError(domain: "z80+ed", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
//        print("\(pc) : \(instruction.opCode)")
        
        pc = pc &+ instruction.length        
        incCounters(amount: instruction.tStates)
        
        r.inc()
        r.inc()
    }
}
