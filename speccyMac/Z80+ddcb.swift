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
        
        switch opcode {
            
        case 0x46:
            memory.indexBit(0, address: offsetAddress)
            
        case 0x4e:
            memory.indexBit(1, address: offsetAddress)
            
        case 0x7e:
            memory.indexBit(7, address: offsetAddress)
            
        case 0x86:
            memory.indexRes(0, address: offsetAddress)
            
        case 0x96:
            memory.indexRes(2, address: offsetAddress)
            
        case 0xc6:
            memory.indexSet(0, address: offsetAddress)
            
        case 0xce:
            memory.indexSet(1, address: offsetAddress)
            
        default:
            throw NSError(domain: "z80+ddcb", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
//        print("\(pc) : \(instruction.opCode)")
        
        pc = pc &+ instruction.length
        incCounters(instruction.tStates)
        
        r.inc()
        r.inc()
    }

}
