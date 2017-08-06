//
//  Z80+ddcb.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
        
    final func ddcbprefix(opcode: UInt8, first: UInt8) throws {
        
        let instruction = cbprefixedOps[opcode]
                
        switch opcode {
            
        case 0xce:
            memory.indexSet(1, baseAddress: ixy.value, offset: first)
            
        default:
            throw NSError(domain: "z80+ddcb", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
//        print("\(pc) : \(instruction.opCode)")
        
        pc = pc &+ instruction.length
        incCounters(amount: instruction.tStates)
        
        r.inc()
        r.inc()
    }

}
