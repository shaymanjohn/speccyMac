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

        switch opcode {
            
        case 0x43:  // ld (nnnn), bc
            memory.set(word16, regPair: bc)
            
        case 0x47:  // ld i, a
            i = a.value
            
        case 0x4f:  // ld r, a
            r.value = a.value
            
        case 0x52:  // sbc hl, de
            hl.sbc(de)
            
        case 0x53:  // ld (nnnn), de
            memory.set(word16, regPair: de)
            
        case 0x56:  // im 1
            interruptMode = 1
            
        case 0x58:  // in e, (c)
            e.portIn(b.value, low: c.value)
            
        case 0x5b:  // le de, (nnnn)
            e.value = memory.get(word16)
            d.value = memory.get(word16 &+ 1)
            
        case 0x5e:  // im 2
            interruptMode = 2
            
        case 0x78:  // in a, (c)
            a.portIn(b.value, low: c.value)
            
        case 0x79:  // out (c), a
            portOut(c.value, byte:a.value)
            
        case 0xa0:  // ldi
            var temp = memory.get(hl)
            bc.dec()
            memory.set(de.value, byte: temp)
            de.inc()
            hl.inc()
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
            
            hl.value = hl.value &+ 1
            de.value = de.value &+ 1
            
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
        
//        print("\(pc) : \(instruction.opCode)")
        
        pc = pc &+ instruction.length        
        incCounters(instruction.tStates)
        
        r.inc()
        r.inc()
    }
}
