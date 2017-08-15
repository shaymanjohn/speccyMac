//
//  Z80+ed.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
    
    final func edprefix(opcode: UInt8, first: UInt8, second: UInt8) throws {
        
        let word16 = (UInt16(second) << 8) | UInt16(first)
        let instruction = edprefixedOps[opcode]
//        log(instruction)

        switch opcode {
            
        case 0x00:  // nop
            break
            
        case 0x42:  // sbc hl, bc
            hl.sbc(bc)
            
        case 0x43:  // ld (nnnn), bc
            memory.set(word16, regPair: bc)
            
        case 0x44:  // neg
            a.neg()
            
        case 0x47:  // ld i, a
            i = a.value
            
        case 0x4b:  // ld bc, (nnnn)
            c.value = memory.get(word16)
            b.value = memory.get(word16 &+ 1)
            
        case 0x4d:  // reti
            pc = memory.pop()
            pc = pc &- 2
            
        case 0x4f:  // ld r, a
            r.value = a.value
            
        case 0x50:  // in d, (c)
            machine?.input(d, high: b.value, low: c.value)
            
        case 0x52:  // sbc hl, de
            hl.sbc(de)
            
        case 0x53:  // ld (nnnn), de
            memory.set(word16, regPair: de)
            
        case 0x56:  // im 1
            interruptMode = 1
            
        case 0x57:  // ld a, i
            a.value = i
            
        case 0x58:  // in e, (c)
            machine?.input(e, high: b.value, low: c.value)
            
        case 0x5a:  // adc hl, de
            hl.adc(de.value)
            
        case 0x5b:  // le de, (nnnn)
            e.value = memory.get(word16)
            d.value = memory.get(word16 &+ 1)
            
        case 0x5e:  // im 2
            interruptMode = 2
            
        case 0x5f:  // ld a, r
            let rval = r.value
            r.inc()
            r.inc()
            a.value = r.value
            r.value = rval
            Z80.f.value = (Z80.f.value & Z80.cBit) | Z80.sz53Table[a.value] | (iff2 > 0 ? Z80.pvBit : 0)            
            
        case 0x62:  // sbc hl, hl
            hl.sbc(hl.value)
            
        case 0x67:  // rrd
            let byte = memory.get(hl)
            memory.set(hl.value, byte: (a.value << 4) | (byte >> 4))
            a.value = (a.value & 0xf0) | (byte & 0x0f)
            Z80.f.value = (Z80.f.value & Z80.cBit) | Z80.sz53pvTable[a.value]                        
            
        case 0x6a:  // adc hl, hl
            hl.adc(hl.value)
            
        case 0x6f:  // rld
            let byte = memory.get(hl)
            memory.set(hl.value, byte: (byte << 4) | (a.value & 0x0f))
            a.value = (a.value & 0xf0) | (byte >> 4)
            Z80.f.value = (Z80.f.value & Z80.cBit) | Z80.sz53pvTable[a.value]
            
        case 0x72:  // sbc hl, sp
            hl.sbc(Z80.sp)
            
        case 0x73:  // ld (nn), sp
            memory.set(word16, byte: UInt8(Z80.sp & 0xff))
            memory.set(word16 &+ 1, byte: UInt8(Z80.sp >> 8))
            
        case 0x78:  // in a, (c)
            machine?.input(a, high: b.value, low: c.value)
            
        case 0x79:  // out (c), a
            machine?.output(c.value, byte: a.value)
            
        case 0x7b:  // ld sp, (nn)
            let lo = memory.get(word16)
            let hi = memory.get(word16 &+ 1)
            Z80.sp = (UInt16(hi) << 8) | UInt16(lo)
            
        case 0xa0:  // ldi
            var temp = memory.get(hl)
            bc.value = bc.value &- 1
            memory.set(de.value, byte: temp)
            de.value = de.value &+ 1
            hl.value = hl.value &+ 1
            temp = temp &+ a.value
            Z80.f.value = (Z80.f.value & (Z80.cBit | Z80.zBit | Z80.sBit)) | (bc.value > 0 ? Z80.pvBit : 0) | (temp & Z80.threeBit) | ((temp & 0x02) > 0 ? Z80.fiveBit : 0)
            
        case 0xa8:  // ldd
            var temp = memory.get(hl)
            bc.value = bc.value &- 1
            memory.set(de.value, byte: temp)
            de.value = de.value &- 1
            hl.value = hl.value &- 1
            temp = temp &+ a.value
            Z80.f.value = (Z80.f.value & (Z80.cBit | Z80.zBit | Z80.sBit)) | (bc.value > 0 ? Z80.pvBit : 0) | (temp & Z80.threeBit) | ((temp & 0x02) > 0 ? Z80.fiveBit : 0)            
            
        case 0xb0:  // ldir
            var val = memory.get(hl)
            memory.set(de.value, byte: val)
            bc.value = bc.value &- 1
            
            val = val &+ a.value
            Z80.f.value = (Z80.f.value & (Z80.cBit | Z80.zBit | Z80.sBit)) | (bc.value > 0 ? Z80.pvBit : 0) | (val & Z80.threeBit) | ((val & 0x02) > 0 ? Z80.fiveBit : 0)
            
            if bc.value > 0 {
                pc = pc &- 2
                incCounters(5)
            }
            
            de.value = de.value &+ 1
            hl.value = hl.value &+ 1
            
        case 0xb1:  // cpir
            let val = memory.get(hl)
            var temp = a.value &- val
            let lookup = ((a.value & 0x08) >> 3) | ((val & 0x08) >> 2) | ((temp & 0x08) >> 1)

            bc.value = bc.value &- 1
            Z80.f.value = (Z80.f.value & Z80.cBit) | (bc.value > 0 ? (Z80.pvBit | Z80.nBit) : Z80.nBit) | Z80.halfCarrySub[lookup] | (temp > 0 ? 0 : Z80.zBit) | (temp & Z80.sBit)
            
            if Z80.f.value & Z80.hBit > 0 {
                temp = temp &- 1
            }
            
            Z80.f.value |= (temp & Z80.threeBit) | ((temp & 0x02) > 0 ? Z80.fiveBit : 0)
            
            if (Z80.f.value & (Z80.pvBit | Z80.zBit)) == Z80.pvBit {
                pc = pc &- 2
                incCounters(5)
            }
            hl.value = hl.value &+ 1
            
        case 0xb8:  // lddr
            var val = memory.get(hl)
            memory.set(de.value, byte: val)
            bc.value = bc.value &- 1
            
            val = val &+ a.value
            Z80.f.value = (Z80.f.value & (Z80.cBit | Z80.zBit | Z80.sBit)) | (bc.value > 0 ? Z80.pvBit : 0) | (val & Z80.threeBit) | ((val & 0x02) > 0 ? Z80.fiveBit : 0)
            
            if bc.value > 0 {
                pc = pc &- 2
                incCounters(5)
            }
            
            hl.value = hl.value &- 1
            de.value = de.value &- 1
            
        default:
            throw NSError(domain: "z80+ed", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }        
        
        pc = pc &+ instruction.length        
        incCounters(instruction.tStates)
        
        r.inc()
        r.inc()
    }
}
