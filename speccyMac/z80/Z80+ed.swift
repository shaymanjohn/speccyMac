//
//  Z80+ed.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension ZilogZ80 {
    
// swiftlint:disable cyclomatic_complexity
    final func edprefix(opcode: UInt8, first: UInt8, second: UInt8) {
        
        let word16 = (UInt16(second) << 8) | UInt16(first)

        switch opcode {
            
        case 0x00:  // nop
            break
            
        case 0x42:  // sbc hl, bc
            sbcHL(bc)
            
        case 0x43:  // ld (nnnn), bc
            memory.set(word16, byte: regC)
            memory.set(word16 &+ 1, byte: regB)
            
        case 0x44:  // neg
            aluNeg()
            
        case 0x47:  // ld i, a
            i = regA
            
        case 0x4a:  // adc hl, bc
            adcHL(bc)
            
        case 0x4b:  // ld bc, (nnnn)
            regC = memory.get(word16)
            regB = memory.get(word16 &+ 1)
            
        case 0x4d:  // reti
            pc = memory.pop()
            pc = pc &- 2
            
        case 0x4f:  // ld r, a
            regR = regA
            
        case 0x50:  // in d, (c)
            machine.contendIO(bc)
            regD = machine.input(regB, low: regC)
            regF = (regF & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[regD]
            
        case 0x51: // out (c), d
            machine.contendIO(bc)
            machine.output(bc, byte: regD)

        // in/out for the remaining registers (B, C, H, L). These were missing
        // and are needed by AY music players that select registers with e.g.
        // `OUT (C),B` - without them the register-select is silently dropped.
        case 0x40:  // in b, (c)
            machine.contendIO(bc)
            regB = machine.input(regB, low: regC)
            regF = (regF & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[regB]

        case 0x41:  // out (c), b
            machine.contendIO(bc)
            machine.output(bc, byte: regB)

        case 0x48:  // in c, (c)
            machine.contendIO(bc)
            regC = machine.input(regB, low: regC)
            regF = (regF & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[regC]

        case 0x49:  // out (c), c
            machine.contendIO(bc)
            machine.output(bc, byte: regC)

        case 0x60:  // in h, (c)
            machine.contendIO(bc)
            regH = machine.input(regB, low: regC)
            regF = (regF & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[regH]

        case 0x61:  // out (c), h
            machine.contendIO(bc)
            machine.output(bc, byte: regH)

        case 0x68:  // in l, (c)
            machine.contendIO(bc)
            regL = machine.input(regB, low: regC)
            regF = (regF & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[regL]

        case 0x69:  // out (c), l
            machine.contendIO(bc)
            machine.output(bc, byte: regL)
            
        case 0x52:  // sbc hl, de
            sbcHL(de)
            
        case 0x53:  // ld (nnnn), de
            memory.set(word16, byte: regE)
            memory.set(word16 &+ 1, byte: regD)
            
        case 0x46:  // im 0
            interruptMode = 0

        case 0x56:  // im 1
            interruptMode = 1
            
        case 0x57:  // ld a, i
            regA = i
            
        case 0x58:  // in e, (c)
            machine.contendIO(bc)
            regE = machine.input(regB, low: regC)
            regF = (regF & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[regE]

        case 0x59:  // out (c), e
            // Was MISSING. Cybernoid's 128K AY player selects the AY register
            // with `OUT (C),E` (ED 59); without this the register-select was
            // silently dropped and all music data landed in register 14,
            // leaving the mixer muted -> total silence.
            machine.contendIO(bc)
            machine.output(bc, byte: regE)
            
        case 0x5a:  // adc hl, de
            adcHL(de)
            
        case 0x5b:  // ld de, (nnnn)
            regE = memory.get(word16)
            regD = memory.get(word16 &+ 1)
            
        case 0x5e:  // im 2
            interruptMode = 2
            
        case 0x5f:  // ld a, r
            let rval = regR
            incR()
            incR()
            regA = regR
            regR = rval
            regF = (regF & ZilogZ80.cBit) | ZilogZ80.sz53Table[regA] | (iff2 > 0 ? ZilogZ80.pvBit : 0)            
            
        case 0x62:  // sbc hl, hl
            sbcHL(hl)
            
        case 0x67:  // rrd
            let byte = memory.get(hl)
            memory.set(hl, byte: (regA << 4) | (byte >> 4))
            regA = (regA & 0xf0) | (byte & 0x0f)
            regF = (regF & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[regA]                        
            
        case 0x6a:  // adc hl, hl
            adcHL(hl)
            
        case 0x6f:  // rld
            let byte = memory.get(hl)
            memory.set(hl, byte: (byte << 4) | (regA & 0x0f))
            regA = (regA & 0xf0) | (byte >> 4)
            regF = (regF & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[regA]
            
        case 0x72:  // sbc hl, sp
            sbcHL(sp)
            
        case 0x73:  // ld (nn), sp
            memory.set(word16, byte: UInt8(sp & 0xff))
            memory.set(word16 &+ 1, byte: UInt8(sp >> 8))
            
        case 0x78:  // in a, (c)
            machine.contendIO(bc)
            regA = machine.input(regB, low: regC)
            regF = (regF & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[regA]
            
        case 0x79:  // out (c), a
            machine.contendIO(bc)
            machine.output(bc, byte: regA)
            
        case 0x7a:  // adc hl, sp
            adcHL(sp)
            
        case 0x7b:  // ld sp, (nn)
            let lo = memory.get(word16)
            let hi = memory.get(word16 &+ 1)
            sp = (UInt16(hi) << 8) | UInt16(lo)
            
        case 0xa0:  // ldi
            var temp = memory.get(hl)
            bc = bc &- 1
            memory.set(de, byte: temp)
            de = de &+ 1
            hl = hl &+ 1
            temp = temp &+ regA
            regF = (regF & (ZilogZ80.cBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (bc > 0 ? ZilogZ80.pvBit : 0) | (temp & ZilogZ80.threeBit) | ((temp & 0x02) > 0 ? ZilogZ80.fiveBit : 0)
            
        case 0xa8:  // ldd
            var temp = memory.get(hl)
            bc = bc &- 1
            memory.set(de, byte: temp)
            de = de &- 1
            hl = hl &- 1
            temp = temp &+ regA
            regF = (regF & (ZilogZ80.cBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (bc > 0 ? ZilogZ80.pvBit : 0) | (temp & ZilogZ80.threeBit) | ((temp & 0x02) > 0 ? ZilogZ80.fiveBit : 0)            
            
        case 0xb0:  // ldir
            var val = memory.get(hl)
            memory.set(de, byte: val)
            bc = bc &- 1
            
            val = val &+ regA
            regF = (regF & (ZilogZ80.cBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (bc > 0 ? ZilogZ80.pvBit : 0) | (val & ZilogZ80.threeBit) | ((val & 0x02) > 0 ? ZilogZ80.fiveBit : 0)
            
            if bc > 0 {
                pc = pc &- 2
                incCounters(5)
            }
            
            de = de &+ 1
            hl = hl &+ 1
            
        case 0xa1:  // cpi
            cpBlock(increment: true, repeating: false)

        case 0xa9:  // cpd
            cpBlock(increment: false, repeating: false)

        case 0xb1:  // cpir
            cpBlock(increment: true, repeating: true)

        case 0xb9:  // cpdr
            cpBlock(increment: false, repeating: true)
            
        case 0xb8:  // lddr
            var val = memory.get(hl)
            memory.set(de, byte: val)
            bc = bc &- 1
            
            val = val &+ regA
            regF = (regF & (ZilogZ80.cBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (bc > 0 ? ZilogZ80.pvBit : 0) | (val & ZilogZ80.threeBit) | ((val & 0x02) > 0 ? ZilogZ80.fiveBit : 0)
            
            if bc > 0 {
                pc = pc &- 2
                incCounters(5)
            }
            
            hl = hl &- 1
            de = de &- 1

        case 0xa2:  // ini
            inBlock(increment: true, repeating: false)

        case 0xaa:  // ind
            inBlock(increment: false, repeating: false)

        case 0xb2:  // inir
            inBlock(increment: true, repeating: true)

        case 0xba:  // indr
            inBlock(increment: false, repeating: true)

        case 0xa3:  // outi
            outBlock(increment: true, repeating: false)

        case 0xab:  // outd
            outBlock(increment: false, repeating: false)

        case 0xb3:  // otir
            outBlock(increment: true, repeating: true)

        case 0xbb:  // otdr
            outBlock(increment: false, repeating: true)
            
        default:
            logUnhandledOpcode(prefix: "ED ", opcode: opcode)
        }        
        
        pc = pc &+ edLength[Int(opcode)]        
        incCounters(edTstates[Int(opcode)])
        
        incR()
        incR()
    }

    /// Shared implementation of the block-input instructions INI/IND (single
    /// step) and INIR/INDR (repeating). Reads a byte from port (C), stores it at
    /// (HL), decrements B, then moves HL in the given direction. Flag behaviour
    /// follows the documented Z80 model (see Fuse / "The Undocumented Z80").
    private func inBlock(increment: Bool, repeating: Bool) {
        machine.contendIO(bc)
        let value = machine.input(regB, low: regC)
        memory.set(hl, byte: value)

        regB = regB &- 1
        hl = increment ? (hl &+ 1) : (hl &- 1)

        // For IN block ops the carry/half-carry term uses (C +/- 1).
        let cAdjust = increment ? (regC &+ 1) : (regC &- 1)
        let k = UInt16(value) &+ UInt16(cAdjust)

        var flags = ZilogZ80.sz53Table[regB]                 // S, Z, 5, 3 from B
        if value & 0x80 != 0 { flags |= ZilogZ80.nBit }       // N = bit 7 of the data
        if k > 0xff { flags |= ZilogZ80.hBit | ZilogZ80.cBit }
        flags |= ZilogZ80.parityBit[Int((UInt8(k & 0x07)) ^ regB)]
        regF = flags

        // INIR/INDR repeat while B != 0. The edTstates base for these opcodes is
        // already the repeating cost (21), so re-execute by backing PC up without
        // adding the extra 5 T-states that the LDIR-family (base 16) needs.
        if repeating && regB != 0 {
            pc = pc &- 2
        }
    }

    /// Shared implementation of the block-output instructions OUTI/OUTD (single
    /// step) and OTIR/OTDR (repeating). Reads (HL), decrements B, outputs the
    /// byte to port (C), then moves HL in the given direction. Flag behaviour
    /// follows the documented Z80 model (see Fuse / "The Undocumented Z80").
    private func outBlock(increment: Bool, repeating: Bool) {
        let value = memory.get(hl)
        regB = regB &- 1
        machine.contendIO(bc)
        machine.output(bc, byte: value)

        hl = increment ? (hl &+ 1) : (hl &- 1)

        // For OUT block ops the carry/half-carry term uses L (after HL moved).
        let k = UInt16(value) &+ UInt16(regL)

        var flags = ZilogZ80.sz53Table[regB]                 // S, Z, 5, 3 from B
        if value & 0x80 != 0 { flags |= ZilogZ80.nBit }       // N = bit 7 of the data
        if k > 0xff { flags |= ZilogZ80.hBit | ZilogZ80.cBit }
        flags |= ZilogZ80.parityBit[Int((UInt8(k & 0x07)) ^ regB)]
        regF = flags

        // OTIR/OTDR repeat while B != 0. The edTstates base for these opcodes is
        // already the repeating cost (21), so re-execute by backing PC up without
        // adding the extra 5 T-states that the LDIR-family (base 16) needs.
        if repeating && regB != 0 {
            pc = pc &- 2
        }
    }

    /// Shared implementation of the block-compare instructions CPI/CPD (single
    /// step) and CPIR/CPDR (repeating). Compares A with (HL), then moves HL by
    /// one in the given direction and decrements BC. Flags match the existing
    /// CPIR/CPDR handling. When `repeating` and neither BC==0 nor a match, the
    /// instruction re-executes (PC backed up by 2) with the extra 5 T-states.
    private func cpBlock(increment: Bool, repeating: Bool) {
        let val = memory.get(hl)
        var temp = regA &- val
        let lookup = ((regA & 0x08) >> 3) | ((val & 0x08) >> 2) | ((temp & 0x08) >> 1)

        bc = bc &- 1
        regF = (regF & ZilogZ80.cBit) | (bc > 0 ? (ZilogZ80.pvBit | ZilogZ80.nBit) : ZilogZ80.nBit) | ZilogZ80.halfCarrySub[lookup] | (temp > 0 ? 0 : ZilogZ80.zBit) | (temp & ZilogZ80.sBit)

        if regF & ZilogZ80.hBit > 0 {
            temp = temp &- 1
        }

        regF |= (temp & ZilogZ80.threeBit) | ((temp & 0x02) > 0 ? ZilogZ80.fiveBit : 0)

        if repeating && (regF & (ZilogZ80.pvBit | ZilogZ80.zBit)) == ZilogZ80.pvBit {
            pc = pc &- 2
            incCounters(5)
        }

        hl = increment ? (hl &+ 1) : (hl &- 1)
    }
}
