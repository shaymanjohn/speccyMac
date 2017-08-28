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
//        log(instruction)
        
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
            ixy.value = ixy.value &+ 1
            
        case 0x24:  // inc ixh
            ixy.hi.inc()
            
        case 0x25:  // dec ixh
            ixy.hi.dec()
            
        case 0x26:  // ld ixh, n
            ixy.hi.value = first
            
        case 0x29:  // add ix, ix
            ixy.add(ixy.value)
            
        case 0x2a:  // ld ix, (nn)
            ixy.lo.value = memory.get(word16)
            ixy.hi.value = memory.get(word16 &+ 1)
            
        case 0x2b:  // dec ixy
            ixy.value = ixy.value &- 1
            
        case 0x2d:  // dec ixl
            ixy.lo.dec()
            
        case 0x2e:  // ld ixl, n
            ixy.lo.value = first
            
        case 0x34:  // inc (ix+d)
            memory.inc(offsetAddress)
            
        case 0x35:  // dec (ixy + d)
            memory.dec(offsetAddress)
            
        case 0x36:  // ld (ix+d), n
            memory.set(offsetAddress, byte: second)
            
        case 0x39:  // add ix, sp
            ixy.add(Z80.sp)
            
        case 0x3f:  //
            Z80.f.value = (Z80.f.value & (Z80.pvBit | Z80.zBit | Z80.sBit)) | ((Z80.f.value & Z80.cBit) > 0 ? Z80.hBit : Z80.cBit) | (a.value & (Z80.threeBit | Z80.fiveBit))
            
        case 0x44:  // ld b, ixh
            b.value = ixy.hi.value
            
        case 0x46:  // ld b, (ix+d)
            b.value = memory.get(offsetAddress)
            
        case 0x4d:  // ld c, ixl
            c.value = ixy.lo.value
            
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
            
        case 0x67:  // ld ixh, a
            ixy.hi.value = a.value
            
        case 0x68:  // ld ixl, b
            ixy.lo.value = b.value
            
        case 0x69:  // ld ixl, c
            ixy.lo.value = c.value
            
        case 0x6e:  // ld l, (ix+d)
            l.value = memory.get(offsetAddress)
            
        case 0x6f:  // ld ixlh, a
            ixy.lo.value = a.value
            
        case 0x70:  // ld (ix+d), b
            memory.set(offsetAddress, reg: b)
            
        case 0x71:  // ld (ix+d), c
            memory.set(offsetAddress, reg: c)
            
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
            
        case 0x7c:  // ld a, ixh
            a.value = ixy.hi.value
            
        case 0x7d:  // ld a, ixl
            a.value = ixy.lo.value
            
        case 0x7e:  // ld a, (ix+d)
            a.value = memory.get(offsetAddress)
            
        case 0x86:  // add a, (ix + d)
            a.add(memory.get(offsetAddress))
            
        case 0x8e:  // adc a, (ix + d)
            a.adc(memory.get(offsetAddress))
            
        case 0x96:  // sub a, (ix + d)
            a.sub(memory.get(offsetAddress))
            
        case 0xa6:  // and (ix+d)
            a.and(memory.get(offsetAddress))
            
        case 0xae:  // xor (ix+d)
            a.xor(memory.get(offsetAddress))
            
        case 0xb6:  // or (ix+d)
            a.or(memory.get(offsetAddress))
            
        case 0xbe:  // cp (ix + d)
            a.cp(memory.get(offsetAddress))
            
        case 0xcd:  // call nnnn
            memory.push(pc &+ 4)
            pc = word16
            pc = pc &- 4
            
        case 0xe1:  // pop ixy
            ixy.value = memory.pop()
            
        case 0xe5:  // push ixy
            memory.push(ixy)
            
        case 0xe9:  // jp (ix)
            pc = ixy.value
            pc = pc &- 2
            
        case 0xf9:  // ld sp, ix
            Z80.sp = ixy.value
            
        default:
            throw NSError(domain: "z80+dd", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }        
        
        pc = pc &+ instruction.length        
        incCounters(instruction.tStates)
        
        r.inc()
        r.inc()
    }
}
