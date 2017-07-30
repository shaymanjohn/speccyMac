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
        
        let instruction = cbprefixedOps[Int(opcode)]
        
        let offset = UInt16(first)
        
        switch opcode {
            
        case 0xce:
            indexSet(1, offset: offset)
            
        default:
            throw NSError(domain: "z80+ddcb", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
        pc = pc + instruction.length
        
        let ts = instruction.tStates
        incCounters(amount: UInt16(ts))
        
        incR()
        incR()
    }

}
