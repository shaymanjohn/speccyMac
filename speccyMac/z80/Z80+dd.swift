//
//  Z80+dd.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension ZilogZ80 {
    
// swiftlint:disable cyclomatic_complexity
    final func ddprefix(opcode: UInt8, first: UInt8, second: UInt8) throws {
        
        let word16 = (UInt16(second) << 8) | UInt16(first)
        let instruction = instructionSet.ddprefix[opcode]
        
        let offsetAddress = first > 127 ? ixy &- (UInt16(256) - UInt16(first)) : ixy &+ UInt16(first)
        
        switch opcode {            
            
        case 0x09:  // add ix, bc
            addIXY(bc)
            
        case 0x19:  // add ix, de
            addIXY(de)
            
        case 0x21:  // ld ixy, nnnn
            ixy = word16
            
        case 0x22:  // ld (nn), ix
            memory.set(word16, byte: ixyl)
            memory.set(word16 &+ 1, byte: ixyh)
            
        case 0x23:  // inc ixy
            ixy = ixy &+ 1
            
        case 0x24:  // inc ixh
            ixyh = regInc(ixyh)
            
        case 0x25:  // dec ixh
            ixyh = regDec(ixyh)
            
        case 0x26:  // ld ixh, n
            ixyh = first
            
        case 0x29:  // add ix, ix
            addIXY(ixy)
            
        case 0x2a:  // ld ix, (nn)
            ixyl = memory.get(word16)
            ixyh = memory.get(word16 &+ 1)
            
        case 0x2b:  // dec ixy
            ixy = ixy &- 1
            
        case 0x2d:  // dec ixl
            ixyl = regDec(ixyl)
            
        case 0x2e:  // ld ixl, n
            ixyl = first
            
        case 0x34:  // inc (ix+d)
            memory.inc(offsetAddress)
            
        case 0x35:  // dec (ixy + d)
            memory.dec(offsetAddress)
            
        case 0x36:  // ld (ix+d), n
            memory.set(offsetAddress, byte: second)
            
        case 0x39:  // add ix, sp
            addIXY(sp)
            
        case 0x3f:  //
            regF = (regF & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | ((regF & ZilogZ80.cBit) > 0 ? ZilogZ80.hBit : ZilogZ80.cBit) | (regA & (ZilogZ80.threeBit | ZilogZ80.fiveBit))
            
        case 0x44:  // ld b, ixh
            regB = ixyh
            
        case 0x46:  // ld b, (ix+d)
            regB = memory.get(offsetAddress)
            
        case 0x4d:  // ld c, ixl
            regC = ixyl
            
        case 0x4e:  // ld c, (ix+d)
            regC = memory.get(offsetAddress)
            
        case 0x54:  // ld d, ixh
            regD = ixyh
            
        case 0x56:  // ld d, (ix+d)
            regD = memory.get(offsetAddress)
            
        case 0x5d:  // ld e, ixl
            regE = ixyl
            
        case 0x5e:  // ld e, (ix+d)
            regE = memory.get(offsetAddress)
            
        case 0x66:  // ld h, (ix+d)
            regH = memory.get(offsetAddress)
            
        case 0x67:  // ld ixh, a
            ixyh = regA
            
        case 0x68:  // ld ixl, b
            ixyl = regB
            
        case 0x69:  // ld ixl, c
            ixyl = regC
            
        case 0x6e:  // ld l, (ix+d)
            regL = memory.get(offsetAddress)
            
        case 0x6f:  // ld ixl, a
            ixyl = regA
            
        case 0x70:  // ld (ix+d), b
            memory.set(offsetAddress, byte: regB)
            
        case 0x71:  // ld (ix+d), c
            memory.set(offsetAddress, byte: regC)
            
        case 0x72:  // ld (ix+d), d
            memory.set(offsetAddress, byte: regD)
            
        case 0x73:  // ld (ix+d), e
            memory.set(offsetAddress, byte: regE)
            
        case 0x74:  // ld (ix+d), h
            memory.set(offsetAddress, byte: regH)
            
        case 0x75:  // ld (ix+d), l
            memory.set(offsetAddress, byte: regL)
            
        case 0x77:  // ld (ix+d), a
            memory.set(offsetAddress, byte: regA)
            
        case 0x7c:  // ld a, ixh
            regA = ixyh
            
        case 0x7d:  // ld a, ixl
            regA = ixyl
            
        case 0x7e:  // ld a, (ix+d)
            regA = memory.get(offsetAddress)
            
        case 0x86:  // add a, (ix + d)
            aluAdd(memory.get(offsetAddress))
            
        case 0x8e:  // adc a, (ix + d)
            aluAdc(memory.get(offsetAddress))
            
        case 0x96:  // sub a, (ix + d)
            aluSub(memory.get(offsetAddress))
            
        case 0xa6:  // and (ix+d)
            aluAnd(memory.get(offsetAddress))
            
        case 0xae:  // xor (ix+d)
            aluXor(memory.get(offsetAddress))
            
        case 0xb6:  // or (ix+d)
            aluOr(memory.get(offsetAddress))
            
        case 0xbe:  // cp (ix + d)
            aluCp(memory.get(offsetAddress))
            
        case 0xcd:  // call nnnn
            memory.push(pc &+ 4)
            pc = word16
            pc = pc &- 4
            
        case 0xe1:  // pop ixy
            ixy = memory.pop()
            
        case 0xe5:  // push ixy
            memory.push(ixy)
            
        case 0xe9:  // jp (ix)
            pc = ixy
            pc = pc &- 2
            
        case 0xf9:  // ld sp, ix
            sp = ixy
            
        default:
            throw NSError(domain: "z80+dd", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opcode, "pc" : pc])
        }        
        
        pc = pc &+ instruction.length        
        incCounters(instruction.tstates)
        
        incR()
        incR()
    }
}
