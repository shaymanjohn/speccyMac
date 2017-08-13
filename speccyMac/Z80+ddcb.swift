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
        let offsetAddress = first > 127 ? ixy.value &- (UInt16(256) - UInt16(first)) : ixy.value &+ UInt16(first)
        log(instruction)
        
        switch opcode {
            
        case 0x2e:
            memory.sra(offsetAddress)
            
        case 0x46, 0x4e, 0x56, 0x5e, 0x66, 0x6e, 0x76, 0x7e:
            let bitValue = (opcode - 0x46) >> 3
            memory.indexBit(bitValue, address: offsetAddress)
            
        case 0x86, 0x8e, 0x96, 0x9e, 0xa6, 0xae, 0xb6, 0xbe:
            let bitValue = (opcode - 0x86) >> 3
            memory.indexRes(bitValue, address: offsetAddress)
            
        case 0xc6, 0xce, 0xd6, 0xde, 0xe6, 0xee, 0xf6, 0xfe:
            let bitValue = (opcode - 0xc6) >> 3
            memory.indexSet(bitValue, address: offsetAddress)            
            
        default:
            throw NSError(domain: "z80+ddcb", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }

        pc = pc &+ instruction.length + 2
        incCounters(instruction.tStates + 8)
        
        r.inc()
        r.inc()
    }

}
