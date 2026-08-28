//
//  Z80+unprefixed.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension ZilogZ80 {
    
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable file_length
    final func unprefixed(opcode: UInt8, first: UInt8, second: UInt8) {
        
        var normalFlow = true
        let word16 = (UInt16(second) << 8) | UInt16(first)

        switch opcode {
            
        case 0x00:  // nop
            break
            
        case 0x01:  // ld bc, nnnn
            bc = word16
            
        case 0x02:  // ld (bc), a
            memory.set(bc, byte: regA)
            
        case 0x03:  // inc bc
            bc = bc &+ 1
            
        case 0x04:  // inc b
            regB = regInc(regB)
            
        case 0x05:  // dec b
            regB = regDec(regB)
            
        case 0x06:  // ld b, n
            regB = first
            
        case 0x07:  // rlca
            aluRlca()
            
        case 0x08:  // ex af, af'
            let temp = af
            af = exaf
            exaf = temp
            
        case 0x09:  // add hl, bc
            addHL(bc)
            
        case 0x0a:  // ld a, (bc)
            regA = memory.get(bc)
            
        case 0x0b:  // dec bc
            bc = bc &- 1
            
        case 0x0c:  // inc c
            regC = regInc(regC)
            
        case 0x0d:  // dec c
            regC = regDec(regC)
            
        case 0x0e:  // ld c, n
            regC = first
            
        case 0x0f:  // rrca
            aluRrca()
            
        case 0x10:  // djnz nn
            regB = regB &- 1
            if regB > 0 {
                setRelativePC(first)
            } else {
                normalFlow = false
            }
            
        case 0x11:  // ld de, nnnn
            de = word16
            
        case 0x12:  // ld (de), a
            memory.set(de, byte: regA)
            
        case 0x13:  // inc de
            de = de &+ 1
            
        case 0x14:  // inc d
            regD = regInc(regD)
            
        case 0x15:  // dec d
            regD = regDec(regD)
            
        case 0x16:  // ld d, n
            regD = first
            
        case 0x17:  // rla
            aluRla()
            
        case 0x18:  // jr d
            setRelativePC(first)
            
        case 0x19:  // add hl, de
            addHL(de)
            
        case 0x1a:  // ld a, (de)
            regA = memory.get(de)
            
        case 0x1b:  // dec de
            de = de &- 1
            
        case 0x1c:  // inc e
            regE = regInc(regE)
            
        case 0x1d:  // dec e
            regE = regDec(regE)
            
        case 0x1e:  // ld e, n
            regE = first
            
        case 0x1f:  // rra
            aluRra()
            
        case 0x20:  // jr nz, nn
            if regF & ZilogZ80.zBit > 0 {
                normalFlow = false
            } else {
                setRelativePC(first)
            }
            
        case 0x21:  // ld hl, nnnn
            hl = word16
            
        case 0x22:  // ld (nnnn), hl
            memory.set(word16, byte: regL)
            memory.set(word16 &+ 1, byte: regH)
            
        case 0x23:  // inc hl
            hl = hl &+ 1
            
        case 0x24:  // inc h
            regH = regInc(regH)
            
        case 0x25:  // dec h
            regH = regDec(regH)
            
        case 0x26:  // ld h, n
            regH = first
            
        case 0x27:  // daa
            aluDaa()
            
        case 0x28:  // jr z, nn
            if regF & ZilogZ80.zBit > 0 {
                setRelativePC(first)
            } else {
                normalFlow = false
            }
            
        case 0x29:  // add hl, hl
            addHL(hl)
            
        case 0x2a:  // ld hl, (nnnn)
            regL = memory.get(word16)
            regH = memory.get(word16 &+ 1)
            
        case 0x2b:  // dec hl
            hl = hl &- 1
            
        case 0x2c:  // inc l
            regL = regInc(regL)
            
        case 0x2d:  // dec l
            regL = regDec(regL)
            
        case 0x2e:  // ld l, n
            regL = first
            
        case 0x2f:  // cpl
            aluCpl()
            
        case 0x30:  // jr nc, nn
            if regF & ZilogZ80.cBit > 0 {
                normalFlow = false
            } else {
                setRelativePC(first)
            }
            
        case 0x31:  // ld sp, nn
            sp = word16
            
        case 0x32:  // ld (nnnn), a
            memory.set(word16, byte: regA)
            
        case 0x33:  // inc sp
            sp = sp &+ 1
            
        case 0x34:  // inc (hl)
            memory.inc(hl)
            
        case 0x35:  // dec (hl)
            memory.dec(hl)
            
        case 0x36:  // ld (hl), n
            memory.set(hl, byte: first)
            
        case 0x37:  // scf
            regF &= ZilogZ80.zBit | ZilogZ80.sBit | ZilogZ80.pvBit
            regF |= (regA & (ZilogZ80.threeBit | ZilogZ80.fiveBit))
            regF |= ZilogZ80.cBit
            
        case 0x38:  // jr c, nn
            if regF & ZilogZ80.cBit > 0 {
                setRelativePC(first)
            } else {
                normalFlow = false
            }
            
        case 0x39:  // add hl, sp
            addHL(sp)
            
        case 0x3a:  // ld a, (nn)
            regA = memory.get(word16)
            
        case 0x3b:  // dec sp
            sp = sp &- 1
            
        case 0x3c:  // inc a
            regA = regInc(regA)
            
        case 0x3d:  // dec a
            regA = regDec(regA)
            
        case 0x3e:  // ld a, n
            regA = first
            
        case 0x3f:  // ccf
            regF = (regF & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | ((regF & ZilogZ80.cBit) > 0 ? ZilogZ80.hBit : ZilogZ80.cBit) | (regA & (ZilogZ80.threeBit | ZilogZ80.fiveBit))
            
        // LD register-to-register block (0x40-0x7f)
        case 0x40: break  // ld b, b
        case 0x41: regB = regC
        case 0x42: regB = regD
        case 0x43: regB = regE
        case 0x44: regB = regH
        case 0x45: regB = regL
        case 0x46: regB = memory.get(hl)
        case 0x47: regB = regA
            
        case 0x48: regC = regB
        case 0x49: break  // ld c, c
        case 0x4a: regC = regD
        case 0x4b: regC = regE
        case 0x4c: regC = regH
        case 0x4d: regC = regL
        case 0x4e: regC = memory.get(hl)
        case 0x4f: regC = regA
            
        case 0x50: regD = regB
        case 0x51: regD = regC
        case 0x52: break  // ld d, d
        case 0x53: regD = regE
        case 0x54: regD = regH
        case 0x55: regD = regL
        case 0x56: regD = memory.get(hl)
        case 0x57: regD = regA
            
        case 0x58: regE = regB
        case 0x59: regE = regC
        case 0x5a: regE = regD
        case 0x5b: break  // ld e, e
        case 0x5c: regE = regH
        case 0x5d: regE = regL
        case 0x5e: regE = memory.get(hl)
        case 0x5f: regE = regA
            
        case 0x60: regH = regB
        case 0x61: regH = regC
        case 0x62: regH = regD
        case 0x63: regH = regE
        case 0x64: break  // ld h, h
        case 0x65: regH = regL
        case 0x66: regH = memory.get(hl)
        case 0x67: regH = regA
            
        case 0x68: regL = regB
        case 0x69: regL = regC
        case 0x6a: regL = regD
        case 0x6b: regL = regE
        case 0x6c: regL = regH
        case 0x6d: break  // ld l, l
        case 0x6e: regL = memory.get(hl)
        case 0x6f: regL = regA
            
        case 0x70: memory.set(hl, byte: regB)
        case 0x71: memory.set(hl, byte: regC)
        case 0x72: memory.set(hl, byte: regD)
        case 0x73: memory.set(hl, byte: regE)
        case 0x74: memory.set(hl, byte: regH)
        case 0x75: memory.set(hl, byte: regL)
            
        case 0x76:  // halt
            halted = true
            pc = pc &- 1
            
        case 0x77: memory.set(hl, byte: regA)
            
        case 0x78: regA = regB
        case 0x79: regA = regC
        case 0x7a: regA = regD
        case 0x7b: regA = regE
        case 0x7c: regA = regH
        case 0x7d: regA = regL
        case 0x7e: regA = memory.get(hl)
        case 0x7f: break  // ld a, a
            
        // ALU operations on registers
        case 0x80: aluAdd(regB)
        case 0x81: aluAdd(regC)
        case 0x82: aluAdd(regD)
        case 0x83: aluAdd(regE)
        case 0x84: aluAdd(regH)
        case 0x85: aluAdd(regL)
        case 0x86: aluAdd(memory.get(hl))
        case 0x87: aluAdd(regA)
            
        case 0x88: aluAdc(regB)
        case 0x89: aluAdc(regC)
        case 0x8a: aluAdc(regD)
        case 0x8b: aluAdc(regE)
        case 0x8c: aluAdc(regH)
        case 0x8d: aluAdc(regL)
        case 0x8e: aluAdc(memory.get(hl))
        case 0x8f: aluAdc(regA)
            
        case 0x90: aluSub(regB)
        case 0x91: aluSub(regC)
        case 0x92: aluSub(regD)
        case 0x93: aluSub(regE)
        case 0x94: aluSub(regH)
        case 0x95: aluSub(regL)
        case 0x96: aluSub(memory.get(hl))
        case 0x97: aluSub(regA)
            
        case 0x98: aluSbc(regB)
        case 0x99: aluSbc(regC)
        case 0x9a: aluSbc(regD)
        case 0x9b: aluSbc(regE)
        case 0x9c: aluSbc(regH)
        case 0x9d: aluSbc(regL)
        case 0x9e: aluSbc(memory.get(hl))
        case 0x9f: aluSbc(regA)
            
        case 0xa0: aluAnd(regB)
        case 0xa1: aluAnd(regC)
        case 0xa2: aluAnd(regD)
        case 0xa3: aluAnd(regE)
        case 0xa4: aluAnd(regH)
        case 0xa5: aluAnd(regL)
        case 0xa6: aluAnd(memory.get(hl))
        case 0xa7: aluAnd(regA)
            
        case 0xa8: aluXor(regB)
        case 0xa9: aluXor(regC)
        case 0xaa: aluXor(regD)
        case 0xab: aluXor(regE)
        case 0xac: aluXor(regH)
        case 0xad: aluXor(regL)
        case 0xae: aluXor(memory.get(hl))
        case 0xaf: aluXor(regA)
            
        case 0xb0: aluOr(regB)
        case 0xb1: aluOr(regC)
        case 0xb2: aluOr(regD)
        case 0xb3: aluOr(regE)
        case 0xb4: aluOr(regH)
        case 0xb5: aluOr(regL)
        case 0xb6: aluOr(memory.get(hl))
        case 0xb7: aluOr(regA)
            
        case 0xb8: aluCp(regB)
        case 0xb9: aluCp(regC)
        case 0xba: aluCp(regD)
        case 0xbb: aluCp(regE)
        case 0xbc: aluCp(regH)
        case 0xbd: aluCp(regL)
        case 0xbe: aluCp(memory.get(hl))
        case 0xbf: aluCp(regA)
            
        case 0xc0:  // ret nz
            if regF & ZilogZ80.zBit > 0 {
                normalFlow = false
            } else {
                pc = memory.pop()
                pc = pc &- 1
            }
            
        case 0xc1:  // pop bc
            bc = memory.pop()
            
        case 0xc2:  // jp nz, nnnn
            if regF & ZilogZ80.zBit > 0 {
                normalFlow = false
            } else {
                pc = word16
                pc = pc &- 3
            }
            
        case 0xc3:  // jp nnnn
            pc = word16
            pc = pc &- 3
            
        case 0xc4:  // call nz, nn
            if regF & ZilogZ80.zBit > 0 {
                normalFlow = false
            } else {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            }
            
        case 0xc5:  // push bc
            memory.push(bc)
            
        case 0xc6:  // add a, n
            aluAdd(first)
            
        case 0xc7:  // rst $00
            rst(0x00)
            
        case 0xc8:  // ret z
            if regF & ZilogZ80.zBit > 0 {
                pc = memory.pop()
                pc = pc &- 1
            } else {
                normalFlow = false
            }
            
        case 0xc9:  // ret
            pc = memory.pop()
            pc = pc &- 1
            
        case 0xca:  // jp z, nn
            if regF & ZilogZ80.zBit > 0 {
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }
            
        case 0xcc:  // call z, nn
            if regF & ZilogZ80.zBit > 0 {
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
            aluAdc(first)
            
        case 0xcf:  // rst $08
            rst(0x08)
            
        case 0xd0:  // ret nc
            if regF & ZilogZ80.cBit > 0 {
                normalFlow = false
            } else {
                pc = memory.pop()
                pc = pc &- 1
            }
            
        case 0xd1:  // pop de
            de = memory.pop()
            
        case 0xd2:  // jp nc, nn
            if regF & ZilogZ80.cBit > 0 {
                normalFlow = false
            } else {
                pc = word16
                pc = pc &- 3
            }
            
        case 0xd3:  // out (n), a
            machine.contendIO(UInt16(regA) << 8 | UInt16(first))
            machine.output(first, byte: regA)
            
        case 0xd4:  // call nc, nn
            if regF & ZilogZ80.cBit > 0 {
                normalFlow = false
            } else {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            }
            
        case 0xd5:  // push de
            memory.push(de)
            
        case 0xd6:  // sub n
            aluSub(first)
            
        case 0xd7:  // rst $10
            rst(0x10)
            
        case 0xd8:  // ret c
            if regF & ZilogZ80.cBit > 0 {
                pc = memory.pop()
                pc = pc &- 1
            } else {
                normalFlow = false
            }
            
        case 0xd9:  // exx
            var temp = bc
            bc = exbc
            exbc = temp
            
            temp = de
            de = exde
            exde = temp
            
            temp = hl
            hl = exhl
            exhl = temp
            
        case 0xda:  // jp c, nn
            if regF & ZilogZ80.cBit > 0 {
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }
            
        case 0xdb:  // in a, (n)
            machine.contendIO(UInt16(regA) << 8 | UInt16(first))
            regA = machine.input(regA, low: first)
            regF = (regF & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[regA]
            
        case 0xdc:  // call c, nn
            if regF & ZilogZ80.cBit > 0 {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }
            
        case 0xde:  // sbc a, n
            aluSbc(first)
            
        case 0xdf:  // rst 18
            rst(0x18)
            
        case 0xe0:  // ret po
            if regF & ZilogZ80.pvBit > 0 {
                normalFlow = false
            } else {
                pc = memory.pop()
                pc = pc &- 1
            }
            
        case 0xe1:  // pop hl
            hl = memory.pop()
            
        case 0xe2:  // jp po, nn
            if regF & ZilogZ80.pvBit > 0 {
                normalFlow = false
            } else {
                pc = word16
                pc = pc &- 3
            }
            
        case 0xe3:  // ex (sp), hl
            let savesp = sp &+ 1
            let byte1 = regH
            let byte2 = regL
            regL = memory.get(sp)
            regH = memory.get(savesp)
            memory.set(sp, byte: byte2)
            memory.set(savesp, byte: byte1)
            
        case 0xe4:  // call po, nn
            if regF & ZilogZ80.pvBit > 0 {
                normalFlow = false
            } else {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            }
            
        case 0xe5:  // push hl
            memory.push(hl)
            
        case 0xe6:  // and n
            aluAnd(first)
            
        case 0xe7:  // rst 20
            rst(0x20)
            
        case 0xe8:  // ret pe
            if regF & ZilogZ80.pvBit > 0 {
                pc = memory.pop()
                pc = pc &- 1
            } else {
                normalFlow = false
            }
            
        case 0xe9:  // jp (hl)
            pc = hl
            pc = pc &- 1
            
        case 0xea:  // jp pe, nn
            if regF & ZilogZ80.pvBit > 0 {
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }        
            
        case 0xeb:  // ex de, hl
            let temp = de
            de = hl
            hl = temp
            
        case 0xec:  // call pe, nn
            if regF & ZilogZ80.pvBit > 0 {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }
            
        case 0xee:  // xor n
            aluXor(first)
            
        case 0xef:  // rst 28
            rst(0x28)
            
        case 0xf0:  // ret p
            if regF & ZilogZ80.sBit > 0 {
                normalFlow = false
            } else {
                pc = memory.pop()
                pc = pc &- 1
            }
            
        case 0xf1:  // pop af
            af = memory.pop()
            
        case 0xf2:  // jp p, nn
            if regF & ZilogZ80.sBit > 0 {
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
            if regF & ZilogZ80.sBit > 0 {
                normalFlow = false
            } else {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            }
            
        case 0xf5:  // push af
            memory.push(af)
            
        case 0xf6:  // or n
            aluOr(first)
            
        case 0xf7:  // rst 30
            rst(0x30)
            
        case 0xf8:  // ret m
            if regF & ZilogZ80.sBit > 0 {
                pc = memory.pop()
                pc = pc &- 1
            } else {
                normalFlow = false
            }
            
        case 0xf9:  // ld sp, hl
            sp = hl
            
        case 0xfa:  // jp m, nn
            if regF & ZilogZ80.sBit > 0 {
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
            if regF & ZilogZ80.sBit > 0 {
                memory.push(pc &+ 3)
                pc = word16
                pc = pc &- 3
            } else {
                normalFlow = false
            }            
            
        case 0xfe:  // cp n
            aluCp(first)
            
        case 0xff:  // rst 38
            rst(0x38)
            
        default:
            break
        }                
        
        pc = pc &+ unprefixedLength[Int(opcode)]

        incCounters(normalFlow ? unprefixedTstates[Int(opcode)] : unprefixedAltTstates[Int(opcode)])        
        incR()
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
