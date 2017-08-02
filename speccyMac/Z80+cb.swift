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
            b = rlc(b)
            
        default:
            throw NSError(domain: "z80+cb", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
//        print("\(pc) : \(instruction.opCode)")
        
        pc = pc &+ instruction.length
        
        let ts = instruction.tStates
        incCounters(amount: ts)
        
        incR()
        incR()
    }
}
