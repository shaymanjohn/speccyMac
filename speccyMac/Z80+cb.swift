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
            
        case 0x01:  // rlc c
            c.rlc()
            
        case 0x07:  // rlc a
            a.rlc()
            
        case 0x08:  // rrc b
            b.rrc()
            
        case 0x09:  // rrc c
            c.rrc()
            
        case 0x0a:  // rrc d
            d.rrc()
            
        case 0x0b:  // rrc e
            e.rrc()
            
        case 0x0f:  // rrc a
            a.rrc()
            
        case 0x16:  // rl (hl)
            memory.rl(hl.value)
            
        case 0x17:  // rl a
            a.rl()
            
        case 0x1f:  // rr a
            a.rr()
            
        case 0x25:  // sla l
            l.sla()
            
        case 0x27:  // sla a
            a.sla()
            
        case 0x39:  // srl c
            c.srl()
            
        case 0x3c:  // srl h
            h.srl()
            
        case 0x3f:  // srl a
            a.srl()
            
        case 0x41:  // bit 0, c
            c.bit(0)
            
        case 0x46:  // bit 0, (hl)
            memory.indexBit(0, baseAddress: hl.value, offset: 0)
            
        case 0x47:  // bit 0, a
            a.bit(0)
            
        case 0x4b:  // bit 1, e
            e.bit(1)
            
        case 0x4e:  // bit 1, (hl)
            memory.indexBit(1, baseAddress: hl.value, offset: 0)
            
        case 0x4f:  // bit 1, a
            a.bit(1)
            
        case 0x63:  // bit 4, e
            e.bit(4)
            
        case 0x67:  // bit 4, a
            a.bit(4)
            
        case 0x78:  // bit 7, b
            b.bit(7)
            
        case 0x7c:  // bit 7, h
            h.bit(7)
            
        case 0x7e:  // bit 7, (hl)
            memory.indexBit(7, baseAddress: hl.value, offset: 0)
            
        case 0x86:  // res 0, (hl)
            memory.indexRes(0, baseAddress: hl.value, offset: 0)
            
        case 0xae: // res 5, (hl)
            memory.indexRes(5, baseAddress: hl.value, offset: 0)
            
        case 0xc6: // set 0, (hl)
            memory.indexSet(0, baseAddress: hl.value, offset: 0)
            
        case 0xd9:  // set 3, c
            c.set(3)
            
        case 0xf4: // set 6, h
            h.set(6)
            
        case 0xfb: // set 7, e
            e.set(7)
            
        case 0xfd: // set 7, l
            l.set(7)
            
        default:
            throw NSError(domain: "z80+cb", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
//        print("\(pc) : \(instruction.opCode)")
        
        pc = pc &+ instruction.length        
        incCounters(instruction.tStates)
        
        r.inc()
        r.inc()
    }
}
