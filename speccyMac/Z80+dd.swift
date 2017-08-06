//
//  Z80+dd.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
    
    final func ddprefix(opcode: UInt8, first: UInt8, second: UInt8) throws {
        
        let word16 = (UInt16(second) << 8) | UInt16(first)
        let instruction = ddprefixedOps[opcode]
        
        var offset = UInt16(first)
        if first > 127 {
            offset = UInt16(256) - UInt16(first)
        }
        
        switch opcode {
            
        case 0x21:  // ld ixy, nnnn
            ixy.value = word16
            
        case 0x35:  // dec (ixy + d)
            let paired = ixy.value + offset
            memory.set(paired, byte: memory.get(paired))
            
        case 0x46:  // ld b, (ix+d)
            b.value = memory.get(ixy.value &+ offset)
            
        case 0x56:  // ld b, (ix+d)
            d.value = memory.get(ixy.value &+ offset)
            
        case 0x5e:  // ld e, (ix+d)
            e.value = memory.get(ixy.value &+ offset)
            
        case 0x6e:  // ld l, (ix+d)
            l.value = memory.get(ixy.value &+ offset)
            
        default:
            throw NSError(domain: "z80+dd", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
//        print("\(pc) : \(instruction.opCode)")
        
        pc = pc &+ instruction.length        
        incCounters(amount: instruction.tStates)
        
        r.inc()
        r.inc()
    }
}
