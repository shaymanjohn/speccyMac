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
        
        var normalFlow = true
        let word16 = (UInt16(second) << 8) + UInt16(first)
        
        let instruction = self.unprefixedOps[Int(opcode)]
        
        switch opcode {
            
        case 0x00:  // nop
            break
            
        case 0x01:  // ld bc, nnnn
            self.bc = word16
            
        case 0x02:  // ld (bc), a
            memory.set(self.bc, byte: self.a)
            
        case 0x03:  // inc bc
            self.bc = self.bc &+ 1
            
        case 0x04:  // inc b
            self.b = byteInc(self.b)
            
        case 0x10:  // djnz nn
            self.b = self.b &- 1
            if self.b > 0 {
                setRelativePC(first)
            } else {
                normalFlow = false
            }
            
        case 0x11:  // ld de, nnnn
            self.de = word16
            
        case 0x19:  // add hl, de
            self.hl = self.hl &+ self.de
            
        case 0x1d:  // dec e
            self.e = byteDec(self.e)
            
        case 0x20:  // jr nz, nn
            if self.f & self.zBit > 0 {
                normalFlow = false
            } else {
                if first > 127 {
                    let npc = Int(self.pc) - (256 - Int(first))
                    self.pc = UInt16(npc)
                } else {
                    self.pc = self.pc &+ UInt16(first)
                }
            }
            
        case 0x21:  // ld hl, nnnn
            self.hl = word16
            
        case 0x22:  // ld (nnnn), hl
            memory.set(word16, byte: self.l)
            memory.set(word16 &+ 1, byte: self.h)
            
        case 0x23:  // inc hl
            self.hl = self.hl &+ 1
            
        case 0x28:  // jr z, nn
            if self.f & self.zBit > 0 {
                if first > 127 {
                    let npc = Int(self.pc) - (256 - Int(first))
                    self.pc = UInt16(npc)
                } else {
                    self.pc = self.pc &+ UInt16(first)
                }
            } else {
                normalFlow = false
            }
            
        case 0x2a:  // ld hl, (nnnn)
            self.l = memory.get(word16)
            self.h = memory.get(word16 &+ 1)
            
        case 0x2b:  // dec hl
            self.hl = self.hl &- 1
            
        case 0x30:  // jr nc, nn
            if self.f & self.cBit > 0 {
                normalFlow = false
            } else {
                if first > 127 {
                    let npc = Int(self.pc) - (256 - Int(first))
                    self.pc = UInt16(npc)
                } else {
                    self.pc = self.pc &+ UInt16(first)
                }
            }
            
        case 0x32:  // ld (nnnn), a
            memory.set(word16, byte: self.a)
            
        case 0x35:  // dec (hl)
            let val = memory.get(self.hl)
            memory.set(self.hl, byte: byteDec(val))
            
        case 0x36:  // ld (hl), n
            memory.set(self.hl, byte: first)
            
        case 0x3e:  // ld a, n
            self.a = first
            
        case 0x47:  // ld b, a
            self.b = self.a
            
        case 0x62:  // ld h, d
            self.h = self.d
            
        case 0x6b:  // ld l, e
            self.l = self.e
            
        case 0xa7:  // and a
            self.f = self.f & 0xfc
            
        case 0xaf:  // xor a
            self.xor(register: self.a)
            
        case 0xbc:  // cp h
            self.compare(register: self.h)
            
        case 0xc3:  // jp nnnn
            self.pc = word16
            self.pc = self.pc - 3
            
        case 0xd3:  // out (n), a
            self.out(port:first, register:self.a)
            
        case 0xd9:  // exx
            var temp:UInt16 = self.bc
            self.bc = self.exbc
            self.exbc = temp
            
            temp = self.de
            self.de = self.exde
            self.exde = temp
            
            temp = self.hl
            self.hl = self.exhl
            self.exhl = temp
            
        case 0xeb:  // ex de, hl
            let temp = self.de
            self.de = self.hl
            self.hl = temp
            
        case 0xf3:  // di
            self.interrupts = false
            self.iff1 = 0
            self.iff2 = 0
            
        case 0xf9:  // ld sp, hl
            self.sp = self.hl
            
        case 0xfb:  // ei
            self.interrupts = true
            self.iff1 = 1
            self.iff2 = 1
            
        default:
            throw NSError(domain: "ed", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode])
        }
        
        print(String(self.pc, radix: 16), instruction.opCode)
        
        self.pc = self.pc + instruction.length
        
        if normalFlow == true {
            let ts = instruction.tStates
            self.incCounters(amount: UInt16(ts))
        } else {
            let ts = instruction.altTStates
            self.incCounters(amount: UInt16(ts))
        }
        
        self.incR()
    }
}
