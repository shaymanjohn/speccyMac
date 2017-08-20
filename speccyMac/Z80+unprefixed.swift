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
        let word16 = (UInt16(second) << 8) | UInt16(first)
//        log(instruction)

        switch opcode {
            
        case 0x00:  // nop
            break
            
        case 0x01:  // ld bc, nnnn
            bc.value = word16
            
        case 0x02:  // ld (bc), a
            memory.set(bc.value, byte: a.value)
            
        case 0x03:  // inc bc
            bc.value = bc.value &+ 1
            
        case 0x04:  // inc b
            b.inc()
            
        case 0x05:  // dec b
            b.dec()
            
        case 0x06:  // ld b, n
            b.value = first
            
        case 0x07:  // rlca
            a.rlca()
            
        case 0x08:  // ex af, af'
            let temp = af.value
            af.value = exaf
            exaf = temp
            
        case 0x09:  // add hl, bc
            hl.add(bc.value)
            
        case 0x0a:  // ld a, (bc)
            a.value = memory.get(bc)
            
        case 0x0b:  // dec bc
            bc.value = bc.value &- 1
            
        case 0x0c:  // inc c
            c.inc()
            
        case 0x0d:  // dec c
            c.dec()
            
        case 0x0e:  // ld c, n
            c.value = first
            
        case 0x0f:  // rrca
            a.rrca()
            
        case 0x10:  // djnz nn
            b.value = b.value &- 1
            if b.value > 0 {
                setRelativePC(first)
            } else {
                normalFlow = false
            }
            
        case 0x11:  // ld de, nnnn
            de.value = word16
            
        case 0x12:  // ld (de), a
            memory.set(de.value, byte: a.value)
            
        case 0x13:  // inc de
            de.value = de.value &+ 1
            
        case 0x14:  // inc d
            d.inc()
            
        case 0x15:  // dec d
            d.dec()
            
        case 0x16:  // ld d, n
            d.value = first
            
        case 0x17:  // rla
            a.rla()
            
        case 0x18:  // jr d
            setRelativePC(first)
            
        case 0x19:  // add hl, de
            hl.add(de.value)
            
        case 0x1a:  // ld a, (de)
            a.value = memory.get(de)
            
        case 0x1b:  // dec de
            de.value = de.value &- 1
            
        case 0x1c:  // inc e
            e.inc()
            
        case 0x1d:  // dec e
            e.dec()
            
        case 0x1e:  // ld e, n
            e.value = first
            
        case 0x1f:  // rra
            a.rra()
            
        case 0x20:  // jr nz, nn
            if Z80.f.value & Z80.zBit > 0 {
                normalFlow = false
            } else {
                setRelativePC(first)
            }
            
        case 0x21:  // ld hl, nnnn
            hl.value = word16
            
        case 0x22:  // ld (nnnn), hl
            memory.set(word16, regPair: hl)
            
        case 0x23:  // inc hl
            hl.value = hl.value &+ 1
            
        case 0x24:  // inc h
            h.inc()
            
        case 0x25:  // dec h
            h.dec()
            
        case 0x26:  // ld h, n
            h.value = first
            
        case 0x27:  // daa
            a.daa()
            
        case 0x28:  // jr z, nn
            if Z80.f.value & Z80.zBit > 0 {
                setRelativePC(first)
            } else {
                normalFlow = false
            }
            
        case 0x29:  // add hl, hl
            hl.add(hl.value)
            
        case 0x2a:  // ld hl, (nnnn)
            l.value = memory.get(word16)
            h.value = memory.get(word16 &+ 1)
            
        case 0x2b:  // dec hl
            hl.value = hl.value &- 1
            
        case 0x2c:  // inc l
            l.inc()
            
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
            
        case 0x31:  // ld sp, nn
            Z80.sp = word16
            
        case 0x32:  // ld (nnnn), a
            memory.set(word16, reg: a)
            
        case 0x33:  // inc sp
            Z80.sp = Z80.sp &+ 1
            
        case 0x34:  // inc (hl)
            memory.inc(hl.value)
            
        case 0x35:  // dec (hl)
            memory.dec(hl.value)
            
        case 0x36:  // ld (hl), n
            memory.set(hl.value, byte: first)
            
        case 0x37:  // scf
            Z80.f.value &= Z80.zBit | Z80.sBit | Z80.pvBit
            Z80.f.value |= (a.value & (Z80.threeBit | Z80.fiveBit))
            Z80.f.value |= Z80.cBit
            
        case 0x38:  // jr c, nn
            if Z80.f.value & Z80.cBit > 0 {
                setRelativePC(first)
            } else {
                normalFlow = false
            }
            
        case 0x39:  // add hl, sp
            hl.add(Z80.sp)
            
        case 0x3a:  // ld a, (nn)
            a.value = memory.get(word16)
            
        case 0x3b:  // dec sp
            Z80.sp = Z80.sp &- 1
            
        case 0x3c:  // inc a
            a.inc()
            
        case 0x3d:  // dec a
            a.dec()
            
        case 0x3e:  // ld a, n
            a.value = first
            
        case 0x3f:  // ccf
            Z80.f.value = (Z80.f.value & (Z80.pvBit | Z80.zBit | Z80.sBit)) | ((Z80.f.value & Z80.cBit) > 0 ? Z80.hBit : Z80.cBit) | (a.value & (Z80.threeBit | Z80.fiveBit))
            
        case 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x47:  // ld b, reg
            b.value = [b, c, d, e, h, l, a, a][opcode - 0x40].value
            
        case 0x46:  // ld b, (hl)
            b.value = memory.get(hl)
            
        case 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4f:  // ld c, reg
            c.value = [b, c, d, e, h, l, a, a][opcode - 0x48].value
            
        case 0x4e:  // ld c, (hl)
            c.value = memory.get(hl)
            
        case 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x57:  // ld d, reg
            d.value = [b, c, d, e, h, l, a, a][opcode - 0x50].value
            
        case 0x56:  // ld d, (hl)
            d.value = memory.get(hl)
            
        case 0x58, 0x59, 0x5a, 0x5b, 0x5c, 0x5d, 0x5f:  // ld e, reg
            e.value = [b, c, d, e, h, l, a, a][opcode - 0x58].value
            
        case 0x5e:  // ld e, (hl)
            e.value = memory.get(hl)
            
        case 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x67:  // ld h, reg
            h.value = [b, c, d, e, h, l, a, a][opcode - 0x60].value
            
        case 0x66:  // ld h, (hl)
            h.value = memory.get(hl)
            
        case 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6f:  // ld l, reg
            l.value = [b, c, d, e, h, l, a, a][opcode - 0x68].value
            
        case 0x6e:  // ld l, (hl)
            l.value = memory.get(hl)
            
        case 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x77:  // ld (hl), reg
            memory.set(hl.value, byte: [b, c, d, e, h, l, a, a][opcode - 0x70].value)
            
        case 0x76:  // halt
            halted = true
            pc = pc &- 1
            
        case 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x7f:  // ld a, reg
            a.value = [b, c, d, e, h, l, a, a][opcode - 0x78].value
            
        case 0x7e:  // ld a, (hl)
            a.value = memory.get(hl)
            
        case 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x87:  // add a, reg
            a.add([b, c, d, e, h, l, a, a][opcode - 0x80].value)
            
        case 0x86:  // add a, (hl)
            a.add(memory.get(hl))
            
        case 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8f:  // adc a, reg
            a.adc([b, c, d, e, h, l, a, a][opcode - 0x88].value)
            
        case 0x8e:  // adc a, (hl)
            a.adc(memory.get(hl))
            
        case 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x97:  // sub reg
            a.sub([b, c, d, e, h, l, a, a][opcode - 0x90].value)
            
        case 0x96:  // sub (hl)
            a.sub(memory.get(hl))
            
        case 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9f:  // sbc reg
            a.sbc([b, c, d, e, h, l, a, a][opcode - 0x98].value)
            
        case 0x9e:  // sbc a, (hl)
            a.sbc(memory.get(hl))
            
        case 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa7:  // and reg
            a.and([b, c, d, e, h, l, a, a][opcode - 0xa0])
            
        case 0xa6:  // and (hl)
            a.and(memory.get(hl))
            
        case 0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xaf:  // xor reg
            a.xor([b, c, d, e, h, l, a, a][opcode - 0xa8])
            
        case 0xae:  // xor (hl)
            a.xor(memory.get(hl))
            
        case 0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb5, 0xb7:  // or reg
            a.or([b, c, d, e, h, l, a, a][opcode - 0xb0])
            
        case 0xb6:  // or (hl)
            a.or(memory.get(hl))
            
        case 0xb8, 0xb9, 0xba, 0xbb, 0xbc, 0xbd, 0xbf:  // cp reg
            a.cp([b, c, d, e, h, l, a, a][opcode - 0xb8])
            
        case 0xbe:  // cp (hl)
            a.cp(memory.get(hl))
            
        case 0xc0:  // ret nz
            if Z80.f.value & Z80.zBit > 0 {
                normalFlow = false
            } else {
                pc = memory.pop()
                pc = pc &- 1
            }
            
        case 0xc1:  // pop bc
            bc.value = memory.pop()
            
        case 0xc2:  // jp nz, nnnn
            if Z80.f.value & Z80.zBit > 0 {
                normalFlow = false
            } else {
                pc = word16
                pc = pc &- 3
            }
            
        case 0xc3:  // jp nnnn
            pc = word16
            pc = pc &- 3
            
        case 0xc4:  // call nz, nn
            if Z80.f.value & Z80.zBit > 0 {
                normalFlow = false
            } else {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            }
            
        case 0xc5:  // push bc
            memory.push(bc)
            
        case 0xc6:  // add a, n
            a.add(first)
            
        case 0xc7:  // rst $00
            rst(0x0000)
            
        case 0xc8:  // ret z
            if Z80.f.value & Z80.zBit > 0 {
                pc = memory.pop()
                pc = pc &- 1
            } else {
                normalFlow = false
            }
            
        case 0xc9:  // ret
            pc = memory.pop()
            pc = pc &- 1
            
        case 0xca:  // jp z, nn
            if Z80.f.value & Z80.zBit > 0 {
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }
            
        case 0xcb:  // shouldn't happen
            break
            
        case 0xcc:  // call z, nn
            if Z80.f.value & Z80.zBit > 0 {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }
            
        case 0xcd:  // call nnnn
            memory.push(pc &+ 3)
            pc = word16
            pc = pc &- 3
            
        case 0xce:  // adc a, n
            a.adc(first)
            
        case 0xcf:  // rst $08
            rst(0x0008)
            
        case 0xd0:  // ret nc
            if Z80.f.value & Z80.cBit > 0 {
                normalFlow = false
            } else {
                pc = memory.pop()
                pc = pc &- 1
            }
            
        case 0xd1:  // pop de
            de.value = memory.pop()
            
        case 0xd2:  // jp nc, nn
            if Z80.f.value & Z80.cBit > 0 {
                normalFlow = false
            } else {
                pc = word16
                pc = pc &- 3
            }
            
        case 0xd3:  // out (n), a
            machine?.output(first, byte: a.value)
            
        case 0xd4:  // call nc, nn
            if Z80.f.value & Z80.cBit > 0 {
                normalFlow = false
            } else {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            }
            
        case 0xd5:  // push de
            memory.push(de)
            
        case 0xd6:  // sub n
            a.sub(first)
            
        case 0xd7:  // rst $10
            rst(0x0010)
            
        case 0xd8:  // ret c
            if Z80.f.value & Z80.cBit > 0 {
                pc = memory.pop()
                pc = pc &- 1
            } else {
                normalFlow = false
            }
            
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
            
        case 0xda:  // jp c, nn
            if Z80.f.value & Z80.cBit > 0 {
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }
            
        case 0xdb:  // in a, (n)
            a.value = machine?.input(a.value, low: first) ?? 0
            
        case 0xdc:  // call c, nn
            if Z80.f.value & Z80.cBit > 0 {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }
            
        case 0xdd:  // shouldn't happen
            break
            
        case 0xde:  // sbc a, n
            a.sbc(first)
            
        case 0xdf:  // rst 18
            rst(0x0018)
            
        case 0xe0:  // ret po
            if Z80.f.value & Z80.pvBit > 0 {
                normalFlow = false
            } else {
                pc = memory.pop()
                pc = pc &- 1
            }
            
        case 0xe1:  // pop hl
            hl.value = memory.pop()
            
        case 0xe2:  // jp po, nn
            if Z80.f.value & Z80.pvBit > 0 {
                normalFlow = false
            } else {
                pc = word16
                pc = pc &- 3
            }
            
        case 0xe3:  // ex (sp), hl
            let savesp = Z80.sp &+ 1
            let byte1 = h.value
            let byte2 = l.value
            l.value = memory.get(Z80.sp)
            h.value = memory.get(savesp)
            memory.set(Z80.sp, byte: byte2)
            memory.set(savesp, byte: byte1)
            
        case 0xe4:  // call po, nn
            if Z80.f.value & Z80.pvBit > 0 {
                normalFlow = false
            } else {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            }
            
        case 0xe5:  // push hl
            memory.push(hl)
            
        case 0xe6:  // and n
            a.and(first)
            
        case 0xe7:  // rst 20
            rst(0x0020)
            
        case 0xe8:  // ret pe
            if Z80.f.value & Z80.pvBit > 0 {
                pc = memory.pop()
                pc = pc &- 1
            } else {
                normalFlow = false
            }
            
        case 0xe9:  // jp (hl)
            pc = hl.value
            pc = pc &- 1
            
        case 0xea:  // jp pe, nn
            if Z80.f.value & Z80.pvBit > 0 {
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }        
            
        case 0xeb:  // ex de, hl
            let temp = de.value
            de.value = hl.value
            hl.value = temp
            
        case 0xec:  // call pe, nn
            if Z80.f.value & Z80.pvBit > 0 {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }
            
        case 0xed:  // shouldn't happen
            break
            
        case 0xee:  // xor n
            a.xor(first)
            
        case 0xef:  // rst 28
            rst(0x0028)
            
        case 0xf0:  // ret p
            if Z80.f.value & Z80.sBit > 0 {
                normalFlow = false
            } else {
                pc = memory.pop()
                pc = pc &- 1
            }
            
        case 0xf1:  // pop af
            af.value = memory.pop()
            
        case 0xf2:  // jp p, nn
            if Z80.f.value & Z80.sBit > 0 {
                normalFlow = false
            } else {
                pc = word16
                pc = pc &- 3
            }
            
        case 0xf3:  // di
            interrupts = false
            iff1 = 0
            iff2 = 2
            
        case 0xf4:  // call p, nn
            if Z80.f.value & Z80.sBit > 0 {
                normalFlow = false
            } else {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            }
            
        case 0xf5:  // push af
            memory.push(af)
            
        case 0xf6:  // or n
            a.or(first)
            
        case 0xf7:  // rst 30
            rst(0x0030)
            
        case 0xf8:  // ret m
            if Z80.f.value & Z80.sBit > 0 {
                pc = memory.pop()
                pc = pc &- 1
            } else {
                normalFlow = false
            }
            
        case 0xf9:  // ld sp, hl
            Z80.sp = hl.value
            
        case 0xfa:  // jp m, nn
            if Z80.f.value & Z80.sBit > 0 {
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }
            
        case 0xfb:  // ei
            interrupts = true
            iff1 = 1
            iff2 = 1
            
        case 0xfc:  // call m, nn
            if Z80.f.value & Z80.sBit > 0 {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }
            
        case 0xfd:  // shouldn't happen
            break
            
        case 0xfe:  // cp n
            a.cp(first)
            
        case 0xff:  // rst 38
            rst(0x0038)
            
        default:
            throw NSError(domain: "z80 unprefixed", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }                
        
        pc = pc &+ instruction.length
        
        incCounters(normalFlow ? instruction.tStates : instruction.altTStates)        
        r.inc()
    }
    
    final func setRelativePC(_ byte: UInt8) {
        pc = byte > 127 ? pc &- (UInt16(256) - UInt16(byte)) : pc &+ UInt16(byte)
    }
    
    final func rst(_ address: UInt16) {
        memory.push(pc &+ 1)
        pc = address
        pc = pc &- 1
    }
}
