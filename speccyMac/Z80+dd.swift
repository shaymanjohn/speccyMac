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
        
        let offsetAddress = first > 127 ? ixy.value &- (UInt16(256) - UInt16(first)) : ixy.value &+ UInt16(first)
        
        switch opcode {
            
        case 0x09:  // add ix, bc
            ixy.add(bc.value)
            
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
            
        case 0x2b:  // dec ixy
            ixy.dec()
            
        case 0x34:  // inc (ix+d)
            memory.inc(offsetAddress)
            
        case 0x35:  // dec (ixy + d)
            memory.dec(offsetAddress)
            
        case 0x36:  // ld (ix+d), n
            memory.set(offsetAddress, byte: second)
            
        case 0x46:  // ld b, (ix+d)
            b.value = memory.get(offsetAddress)
            
        case 0x4e:  // ld c, (ix+d)
            c.value = memory.get(offsetAddress)
            
        case 0x54:  // ld d, ixh
            d.value = ixy.hi.value
            
        case 0x56:  // ld d, (ix+d)
            d.value = memory.get(offsetAddress)
            
        case 0x5d:  // ld e, ixl
            e.value = ixy.lo.value
            
        case 0x5e:  // ld e, (ix+d)
            e.value = memory.get(offsetAddress)
            
        case 0x66:  // ld h, (ix+d)
            h.value = memory.get(offsetAddress)
            
        case 0x6e:  // ld l, (ix+d)
            l.value = memory.get(offsetAddress)
            
        case 0x6f:  // ld ixlh, a
            ixy.lo.value = a.value
            
        case 0x70:  // ld (ix+d), b
            memory.set(offsetAddress, reg: b)
            
        case 0x72:  // ld (ix+d), d
            memory.set(offsetAddress, reg: d)
            
        case 0x73:  // ld (ix+d), e
            memory.set(offsetAddress, reg: e)
            
        case 0x74:  // ld (ix+d), h
            memory.set(offsetAddress, reg: h)
            
        case 0x75:  // ld (ix+d), l
            memory.set(offsetAddress, reg: l)
            
        case 0x77:  // ld (ix+d), a
            memory.set(offsetAddress, reg: a)
            
        case 0x7e:  // ld a, (ix+d)
            a.value = memory.get(offsetAddress)
            
        case 0x86:  // add a, (ix + d)
            a.add(memory.get(offsetAddress))
            
        case 0xa6:  // and (ix+d)
            a.and(memory.get(offsetAddress))
            
        case 0xb6:  // or (ix+d)
            a.or(memory.get(offsetAddress))
            
        case 0xbe:  // cp (ix + d)
            a.cp(memory.get(offsetAddress))
            
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
