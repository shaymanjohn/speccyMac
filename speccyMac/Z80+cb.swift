//
//  Z80+cb.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
    
    final func cbprefix(opcode: UInt8, first: UInt8, second: UInt8) throws {
        
        let instruction = cbprefixedOps[opcode]
        
        switch opcode {
            
        case 0x00:  // rlc b
            b.rlc()
            
        case 0x67: // bit 4, a
            a.bit(4)
            
        case 0x7e: // bit 7, (hl)
            memory.indexBit(7, baseAddress: hl.value, offset: first)
            
        case 0xae: // res 5, (hl)
            memory.indexRes(5, baseAddress: hl.value, offset: first)
            
        case 0xc6: // set 0, (hl)
            memory.indexSet(0, baseAddress: hl.value, offset: first)
            
        default:
            throw NSError(domain: "z80+cb", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
//        print("\(pc) : \(instruction.opCode)")
        
        pc = pc &+ instruction.length        
        incCounters(amount: instruction.tStates)
        
        r.inc()
        r.inc()
    }
}
