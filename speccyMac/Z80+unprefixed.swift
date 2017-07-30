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
        
        let instruction = unprefixedOps[Int(opcode)]
        var normalFlow = true
        let word16 = (UInt16(second) << 8) + UInt16(first)
        
        switch opcode {
            
        case 0x00:  // nop
            break
            
        case 0x01:  // ld bc, nnnn
            bc = word16
            
        case 0x02:  // ld (bc), a
            memory.set(bc, byte: a)
            
        case 0x03:  // inc bc
            bc = bc &+ 1
            
        case 0x04:  // inc b
            b = inc(b)
            
        case 0x10:  // djnz nn
            b = b &- 1
            if b > 0 {
                setRelativePC(first)
            } else {
                normalFlow = false
            }
            
        case 0x11:  // ld de, nnnn
            de = word16
            
        case 0x19:  // add hl, de
            hl = hl &+ de
            
        case 0x1d:  // dec e
            e = dec(e)
            
        case 0x20:  // jr nz, nn
            if f & zBit > 0 {
                normalFlow = false
            } else {
                if first > 127 {
                    let npc = Int(pc) - (256 - Int(first))
                    pc = UInt16(npc)
                } else {
                    pc = pc &+ UInt16(first)
                }
            }
            
        case 0x21:  // ld hl, nnnn
            hl = word16
            
        case 0x22:  // ld (nnnn), hl
            memory.set(word16, byte: l)
            memory.set(word16 &+ 1, byte: h)
            
        case 0x23:  // inc hl
            hl = hl &+ 1
            
        case 0x28:  // jr z, nn
            if f & zBit > 0 {
                if first > 127 {
                    let npc = Int(pc) - (256 - Int(first))
                    pc = UInt16(npc)
                } else {
                    pc = pc &+ UInt16(first)
                }
            } else {
                normalFlow = false
            }
            
        case 0x2a:  // ld hl, (nnnn)
            l = memory.get(word16)
            h = memory.get(word16 &+ 1)
            
        case 0x2b:  // dec hl
            hl = hl &- 1
            
        case 0x30:  // jr nc, nn
            if f & cBit > 0 {
                normalFlow = false
            } else {
                if first > 127 {
                    let npc = Int(pc) - (256 - Int(first))
                    pc = UInt16(npc)
                } else {
                    pc = pc &+ UInt16(first)
                }
            }
            
        case 0x32:  // ld (nnnn), a
            memory.set(word16, byte: a)
            
        case 0x35:  // dec (hl)
            let val = memory.get(hl)
            memory.set(hl, byte: dec(val))
            
        case 0x36:  // ld (hl), n
            memory.set(hl, byte: first)
            
        case 0x3e:  // ld a, n
            a = first
            
        case 0x47:  // ld b, a
            b = a
            
        case 0x62:  // ld h, d
            h = d
            
        case 0x6b:  // ld l, e
            l = e
            
        case 0x7e:  // ld a, (hl)
            a = memory.get(hl)
            
        case 0xa7:  // and a
            f = f & 0xfc
            
        case 0xaf:  // xor a
            xor(byte: a)
            
        case 0xbc:  // cp h
            compare(byte: h)
            
        case 0xc3:  // jp nnnn
            pc = word16
            pc = pc &- 3
            
        case 0xc8:  // ret z
            if f & zBit > 0 {
                pc = pop(pc)
                pc = pc &- 1
            } else {
                normalFlow = false
            }
            
        case 0xcd:  // call nnnn
            push(registerPair: pc &+ 3)
            pc = word16
            pc = pc &- 3
            
        case 0xd0:  // ret nc
            if f & cBit > 0 {
                normalFlow = false
            } else {
                pc = pop(pc)
                pc = pc &- 1
            }
            
        case 0xd3:  // out (n), a
            out(port:first, byte:a)
            
        case 0xd9:  // exx
            var temp:UInt16 = bc
            bc = exbc
            exbc = temp
            
            temp = de
            de = exde
            exde = temp
            
            temp = hl
            hl = exhl
            exhl = temp
            
        case 0xdf:  // rst 18
            rst(0x0018)
            
        case 0xeb:  // ex de, hl
            let temp = de
            de = hl
            hl = temp
            
        case 0xf3:  // di
            interrupts = false
            iff1 = 0
            iff2 = 2
            
        case 0xf9:  // ld sp, hl
            sp = hl
            
        case 0xfb:  // ei
            interrupts = true
            iff1 = 1
            iff2 = 1
            
        case 0xfe:  // cp n
            compare(byte: first)
            
        case 0xff:  // rst 38
            rst(0x0038)
            
        default:
            throw NSError(domain: "z80 unprefixed", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }
        
//        print(String(pc, radix: 16), instruction.opCode)
        
        pc = pc + instruction.length
        
        if normalFlow == true {
            let ts = instruction.tStates
            incCounters(amount: UInt16(ts))
        } else {
            let ts = instruction.altTStates
            incCounters(amount: UInt16(ts))
        }
        
        incR()
    }
}
