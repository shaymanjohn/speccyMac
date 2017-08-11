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
        
//        if pc >= 0x1219 && pc <= 0x12a2 {
//            print("pc: ", String(pc, radix: 16, uppercase: true), instruction.opCode)
//        }
        
        switch opcode {
            
        case 0x2e:
            memory.sra(offsetAddress)
            
        case 0x46:
            memory.indexBit(0, address: offsetAddress)
            
        case 0x4e:
            memory.indexBit(1, address: offsetAddress)

        case 0x56:
            memory.indexBit(2, address: offsetAddress)
            
        case 0x5e:
            memory.indexBit(3, address: offsetAddress)
            
        case 0x66:
            memory.indexBit(4, address: offsetAddress)
            
        case 0x6e:
            memory.indexBit(5, address: offsetAddress)
            
        case 0x76:
            memory.indexBit(6, address: offsetAddress)
            
        case 0x7e:
            memory.indexBit(7, address: offsetAddress)
            
        case 0x86:
            memory.indexRes(0, address: offsetAddress)
            
        case 0x8e:
            memory.indexRes(1, address: offsetAddress)
            
        case 0x96:
            memory.indexRes(2, address: offsetAddress)
            
        case 0x9e:
            memory.indexRes(3, address: offsetAddress)
            
        case 0xa6:
            memory.indexRes(4, address: offsetAddress)
            
        case 0xae:
            memory.indexRes(5, address: offsetAddress)
            
        case 0xb6:
            memory.indexSet(6, address: offsetAddress)
            
        case 0xbe:
            memory.indexRes(7, address: offsetAddress)
            
        case 0xc6:
            memory.indexSet(0, address: offsetAddress)
            
        case 0xce:
            memory.indexSet(1, address: offsetAddress)
            
        case 0xd6:
            memory.indexSet(2, address: offsetAddress)
            
        case 0xde:
            memory.indexSet(3, address: offsetAddress)
            
        case 0xe6:
            memory.indexSet(4, address: offsetAddress)
            
        case 0xee:
            memory.indexSet(5, address: offsetAddress)
            
        case 0xf6:
            memory.indexSet(6, address: offsetAddress)
            
        default:
            throw NSError(domain: "z80+ddcb", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
//        print("\(pc) : \(instruction.opCode)")
        
        pc = pc &+ instruction.length + 2
        incCounters(instruction.tStates + 8)
        
        r.inc()
        r.inc()
    }

}
