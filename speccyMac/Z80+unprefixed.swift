//
//  Z80+unprefixed.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
    
    final func unprefixed(opcode: UInt8, first: UInt8, second: UInt8) throws {
        
        let instruction = unprefixedOps[opcode]
        var normalFlow = true
        let word16 = (UInt16(second) << 8) + UInt16(first)
        
        switch opcode {
            
        case 0x00:  // nop
            break
            
        case 0x01:  // ld bc, nnnn
            bc.value = word16
            
        case 0x02:  // ld (bc), a
            memory.set(bc.value, byte: a.value)
            
        case 0x03:  // inc bc
            bc.inc()
            
        case 0x04:  // inc b
            b.inc()
            
        case 0x05:  // dec b
            b.dec()
            
        case 0x06:  // ld b, n
            b.value = first
            
        case 0x07:  // rlca
            rlca()
            
        case 0x08:  // ex af, af'
            let temp = af.value
            af.value = exaf
            exaf = temp
            
        case 0x09:  // add hl, bc
            hl.add(bc.value)
            
        case 0x0a:  // ld a, (bc)
            a.value = memory.get(bc)
            
        case 0x0b:  // dec bc
            bc.dec()
            
        case 0x0c:  // inc c
            c.inc()
            
        case 0x0d:  // dec c
            c.dec()
            
        case 0x0e:  // ld c, n
            c.value = first
            
        case 0x0f:  // rrca
            rrca()
            
        case 0x10:  // djnz nn
            b.value = b.value &- 1
            if b.value > 0 {
                setRelativePC(first)
            } else {
                normalFlow = false
            }
            
        case 0x11:  // ld de, nnnn
            de.value = word16
            
        case 0x14:  // inc d
            d.inc()
            
        case 0x19:  // add hl, de
            hl.add(de.value)
            
        case 0x1d:  // dec e
            e.dec()
            
        case 0x20:  // jr nz, nn
            if Z80.f.value & Z80.zBit > 0 {
                normalFlow = false
            } else {
                setRelativePC(first)
            }
            
        case 0x21:  // ld hl, nnnn
            hl.value = word16
            
        case 0x22:  // ld (nnnn), hl
            memory.set(word16, byte: l.value)
            memory.set(word16 &+ 1, byte: h.value)
            
        case 0x23:  // inc hl
            hl.inc()
            
        case 0x28:  // jr z, nn
            if Z80.f.value & Z80.zBit > 0 {
                setRelativePC(first)
            } else {
                normalFlow = false
            }
            
        case 0x2a:  // ld hl, (nnnn)
            l.value = memory.get(word16)
            h.value = memory.get(word16 &+ 1)
            
        case 0x2b:  // dec hl
            hl.dec()
            
        case 0x2d:  // dec l
            l.dec()
            
        case 0x2e:  // ld l, n
            l.value = first
            
        case 0x2f:  // cpl
            a.cpl()
            
        case 0x30:  // jr nc, nn
            if Z80.f.value & Z80.cBit > 0 {
                normalFlow = false
            } else {
                setRelativePC(first)
            }
            
        case 0x32:  // ld (nnnn), a
            memory.set(word16, byte: a.value)
            
        case 0x35:  // dec (hl)
            let temp = a.value
            a.value = memory.get(hl)
            a.dec()
            memory.set(hl.value, byte: a.value)
            a.value = temp
            
            
        case 0x36:  // ld (hl), n
            memory.set(hl.value, byte: first)
            
        case 0x38:  // jr c, nn
            if Z80.f.value & Z80.cBit > 0 {
                setRelativePC(first)
            } else {
                normalFlow = false
            }
            
        case 0x3c:  // inc a
            a.inc()
            
        case 0x3e:  // ld a, n
            a.value = first
            
        case 0x3f:  // ccf
            Z80.f.value = (Z80.f.value & (Z80.pvBit | Z80.zBit | Z80.sBit)) | ((Z80.f.value & Z80.cBit) > 0 ? Z80.hBit : Z80.cBit) | (a.value & (Z80.threeBit | Z80.fiveBit))
            
        case 0x40:  // ld b, b
            break
            
        case 0x47:  // ld b, a
            b.value = a.value
            
        case 0x54:  // ld d, h
            d.value = h.value
            
        case 0x56:  // ld d, (hl)
            d.value = memory.get(hl)
            
        case 0x5e:  // ld e, (hl)
            e.value = memory.get(hl)
            
        case 0x62:  // ld h, d
            h.value = d.value
            
        case 0x67:  // ld h, a
            h.value = a.value
            
        case 0x6b:  // ld l, e
            l.value = e.value
            
        case 0x7a:  // ld a, d
            a.value = d.value
            
        case 0x7c:  // ld a, h
            a.value = h.value
            
        case 0x7d:  // ld a, l
            a.value = l.value
            
        case 0x7e:  // ld a, (hl)
            a.value = memory.get(hl)
            
        case 0xa7:  // and a
            a.and(a)
            
        case 0xaf:  // xor a
            a.xor(a)
            
        case 0xb5:  // or l
            a.or(l)
            
        case 0xbc:  // cp h
            a.cp(h)
            
        case 0xc0:  // ret nz
            if Z80.f.value & Z80.zBit > 0 {
                normalFlow = false
            } else {
                pc = pop()
                pc = pc &- 1
            }
            
        case 0xc3:  // jp nnnn
            pc = word16
            pc = pc &- 3
            
        case 0xc5:  // push bc
            push(bc)
            
        case 0xc8:  // ret z
            if Z80.f.value & Z80.zBit > 0 {
                pc = pop()
                pc = pc &- 1
            } else {
                normalFlow = false
            }
            
        case 0xcd:  // call nnnn
            push(pc &+ 3)
            pc = word16
            pc = pc &- 3
            
        case 0xd0:  // ret nc
            if Z80.f.value & Z80.cBit > 0 {
                normalFlow = false
            } else {
                pc = pop()
                pc = pc &- 1
            }
            
        case 0xd3:  // out (n), a
            out(first, byte:a.value)
            
        case 0xd5:  // push de
            push(de)
            
        case 0xd6:  // sub n
            a.sub(first)
            
        case 0xd9:  // exx
            var temp = bc.value
            bc.value = exbc
            exbc = temp
            
            temp = de.value
            de.value = exde
            exde = temp
            
            temp = hl.value
            hl.value = exhl
            exhl = temp
            
        case 0xdf:  // rst 18
            rst(0x0018)
            
        case 0xe5:  // push hl
            push(hl)
            
        case 0xe6:  // and n
            a.and(first)
            
        case 0xe9:  // jp (hl)
            pc = hl.value
            pc = pc &- 1
            
        case 0xeb:  // ex de, hl
            let temp = de.value
            de.value = hl.value
            hl.value = temp
            
        case 0xf3:  // di
            interrupts = false
            iff1 = 0
            iff2 = 2
            
        case 0xf5:  // push af
            push(af)
            
        case 0xf9:  // ld sp, hl
            sp = hl.value
            
        case 0xfb:  // ei
            interrupts = true
            iff1 = 1
            iff2 = 1
            
        case 0xfe:  // cp n
            a.cp(first)
            
        case 0xff:  // rst 38
            rst(0x0038)
            
        default:
            throw NSError(domain: "z80 unprefixed", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
//        print("\(pc) : \(instruction.opCode)")        
        
        pc = pc &+ instruction.length
        
        incCounters(amount: normalFlow ? instruction.tStates : instruction.altTStates)        
        incR()
    }
}
