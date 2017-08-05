//
//  Z80+core.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
        
    @inline(__always) func add(_ byte: UInt8) {
        let addTemp = UInt16(a.value) + UInt16(byte)

        let part1 = (a.value & 0x88) >> 3
        let part2 = (byte & 0x88) >> 2
        let part3 = UInt8((addTemp & 0x88) >> 1)
        
        let lookup = part1 | part2 | part3
        
        a.value = UInt8(addTemp & 0xff)
        
        let part4 = addTemp & 0x100 > 0 ? Z80.cBit : 0
        let part5 = Z80.halfCarryAdd[lookup & 0x07]
        let part6 = Z80.overFlowAdd[lookup >> 4]
        let part7 = Z80.sz53Table[a.value]
        
        Z80.f.value = part4 | part5 | part6 | part7
    }
    
    @inline(__always) func addc(_ byte: UInt8) {
        let addcTemp = UInt16(a.value) + UInt16(byte) + UInt16(Z80.f.value & Z80.cBit)
        
        let part1 = (a.value & 0x88) >> 3
        let part2 = (byte & 0x88) >> 2
        let part3 = UInt8((addcTemp & 0x88) >> 1)
        
        let lookup = part1 | part2 | part3
        
        a.value = UInt8(addcTemp & 0xff)
        
        let part4 = addcTemp & 0x100 > 0 ? Z80.cBit : 0
        let part5 = Z80.halfCarryAdd[lookup & 0x07]
        let part6 = Z80.overFlowAdd[lookup >> 4]
        let part7 = Z80.sz53Table[a.value]
        
        Z80.f.value = part4 | part5 | part6 | part7
    }
    
    @inline(__always) func subc(_ byte: UInt8) {
        let subcTemp = UInt16(a.value) - UInt16(byte) - UInt16(Z80.f.value & Z80.cBit)
        
        let part1 = (a.value & 0x88) >> 3
        let part2 = (byte & 0x88) >> 2
        let part3 = UInt8((subcTemp & 0x88) >> 1)
        
        let lookup = part1 | part2 | part3
        
        a.value = UInt8(subcTemp & 0xff)
        
        let part4 = subcTemp & 0x100 > 0 ? Z80.cBit : 0
        let part5 = Z80.halfCarrySub[lookup & 0x07]
        let part6 = Z80.overFlowSub[lookup >> 4]
        let part7 = Z80.sz53Table[a.value]
        
        Z80.f.value = part4 | Z80.nBit | part5 | part6 | part7
    }
    
    @inline(__always) func wordsubc(_ word: UInt16) {
        print("stub: wordsubc")
    }
    
    @inline(__always) func wordaddc(_ word: UInt16) {
        print("stub: wordaddc")
    }
    
    @inline(__always) func pop() -> UInt16 {
        let lo = memory.get(sp)
        sp = sp &+ 1
        let hi = memory.get(sp)
        sp = sp &+ 1
        
        return UInt16(hi << 8) + UInt16(lo)
    }
    
    @inline(__always) func push(_ registerPair: UInt16) {
        sp = sp &- 1
        memory.set(sp, byte: UInt8(registerPair >> 8))
        sp = sp &- 1
        memory.set(sp, byte: UInt8(registerPair & 0xff))
    }
    
    final func push(_ regPair: RegisterPair) {
        sp = sp &- 1
        memory.set(sp, byte: regPair.hi.value)
        sp = sp &- 1
        memory.set(sp, byte: regPair.lo.value)
    }
    
    @inline(__always) func rlca() {
        print("stub: rlca")
    }
    
    @inline(__always) func rrc(_ byte: UInt8) -> UInt8 {
        print("stub: rrc")
        return byte
    }
    
    @inline(__always) func rrca() {
        print("stub: rrca")
    }
    
    @inline(__always) func add16(_ word: UInt16) {
        let val: UInt32 = UInt32(hl.value) + UInt32(word)
        let part1 = (hl.value & 0x0800) >> 11
        let part2 = (word & 0x0800) >> 10
        let part3 = (val & 0x0800) >> 9
        
        let lookup = UInt8(part1) | UInt8(part2) | UInt8(part3)
        
        hl.value = UInt16(val & 0xffff)
        
        Z80.f.value = (Z80.f.value & (Z80.pvBit | Z80.zBit | Z80.sBit)) | (val & 0x10000 > 0 ? Z80.cBit : 0) | (UInt8((val >> 8)) & (Z80.threeBit | Z80.fiveBit)) | Z80.halfCarryAdd[lookup];
    }
    
    @inline(__always) func setRelativePC(_ byte: UInt8) {
        if byte > 127 {
            pc = pc - (256 - UInt16(byte))
        } else {
            pc = pc + UInt16(byte)
        }
    }
    
    @inline(__always) func incR() {
        if r > 127 {
            var byte = r & 0x7f
            byte = byte + 1
            if byte == 128 {
                byte = 0
            }
            r = byte | 0x80
        } else {
            r = r + 1
            if r == 128 {
                r = 0
            }
        }
    }
    
    @inline(__always) func indexSet(_ num: Int, offset: UInt16) {
        var byte = memory.get(offset)
        byte = byte | (1 << num)
        memory.set(offset, byte: byte)
        incCounters(amount: 23)
    }
    
    @inline(__always) func rst(_ address: UInt16) {
        push(pc &+ 1)
        pc = address
        pc = pc &- 1
    }
    
    @inline(__always) func out(_ port: UInt8, byte: UInt8) {
        if port == 0xfe {
            machine?.borderColour = byte & 0x07
            
            if byte & 0x10 > 0 {
                if let clicks = machine?.clickCount {
                    machine!.clickCount = clicks + 1
                }
            }
        }
    }
    
    @inline(__always) func portIn(_ high: UInt8, low: UInt8) -> UInt8 {
        let byte = 0xff
        Z80.f.value = (Z80.f.value & Z80.cBit) | Z80.sz53pvTable[byte]
        return UInt8(byte)
    }
    
}
