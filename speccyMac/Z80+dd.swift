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
            
        case 0x19:  // add ix, de
            ixy.add(de.value)
            
        case 0x21:  // ld ixy, nnnn
            ixy.value = word16
            
        case 0x22:  // ld (nn), ix
            memory.set(word16, regPair: ixy)
            
        case 0x23:  // inc ixy
            ixy.inc()
            
        case 0x26:  // ld ixh, n
            ixy.hi.value = first
            
        case 0x2a:  // ld ix, (nn)
            ixy.lo.value = memory.get(word16)
            ixy.hi.value = memory.get(word16 &+ 1)
            
        case 0x34:  // inc (ix+d)
            memory.inc(ixy.value &+ offset)
            
        case 0x35:  // dec (ixy + d)
            memory.dec(ixy.value &+ offset)
            
        case 0x46:  // ld b, (ix+d)
            b.value = memory.get(ixy.value &+ offset)
            
        case 0x54:  // ld d, ixh
            d.value = ixy.hi.value
            
        case 0x56:  // ld b, (ix+d)
            d.value = memory.get(ixy.value &+ offset)
            
        case 0x5d:  // ld e, ixl
            e.value = ixy.lo.value
            
        case 0x5e:  // ld e, (ix+d)
            e.value = memory.get(ixy.value &+ offset)
            
        case 0x66:  // ld h, (ix+d)
            h.value = memory.get(ixy.value &+ offset)
            
        case 0x6e:  // ld l, (ix+d)
            l.value = memory.get(ixy.value &+ offset)
            
        case 0x6f:  // ld ixlh, a
            ixy.lo.value = a.value
            
        case 0x70:  // ld (ix+d), b
            memory.set(ixy.value &+ offset, reg: b)
            
        case 0x72:  // ld (ix+d), d
            memory.set(ixy.value &+ offset, reg: d)
            
        case 0x73:  // ld (ix+d), e
            memory.set(ixy.value &+ offset, reg: e)
            
        case 0x74:  // ld (ix+d), h
            memory.set(ixy.value &+ offset, reg: h)
            
        case 0x75:  // ld (ix+d), l
            memory.set(ixy.value &+ offset, reg: l)
            
        case 0x77:  // ld (ix+d), a
            memory.set(ixy.value &+ offset, reg: a)
            
        case 0x7e:  // ld a, (ix+d)
            a.value = memory.get(ixy.value &+ offset)
            
        case 0xa6:  // and (ix+d)
            a.and(memory.get(ixy.value &+ offset))
            
        case 0xbe:  // cp (ix + d)
            a.cp(memory.get(ixy.value &+ offset))
            
        case 0xe1:  // pop ixy
            ixy.value = memory.pop()
            
        case 0xe5:  // push ixy
            memory.push(ixy)
            
        default:
            throw NSError(domain: "z80+dd", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
//        print("\(pc) : \(instruction.opCode)")
        
        pc = pc &+ instruction.length        
        incCounters(instruction.tStates)
        
        r.inc()
        r.inc()
    }
}
