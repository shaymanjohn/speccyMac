//
//  Z80+core.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
    
    @inline(__always) func inc(_ byte: UInt8) -> UInt8 {
        let thisByte = byte &+ 1
        f = (f & cBit) | (thisByte == 0x80 ? pvBit : 0) | thisByte & 0x0f > 0 ? 0 : hBit | sz53Table[thisByte]
        return thisByte
    }
    
    @inline(__always) func dec(_ byte: UInt8) -> UInt8 {        
        f = (f & cBit) | (byte & 0x0f > 0 ? 0 : hBit ) | nBit
        let thisByte = byte &- 1
        f |= (thisByte == 0x7f ? pvBit : 0) | sz53Table[thisByte]
        return thisByte
    }
    
    @inline(__always) func add(_ byte: UInt8) {
        let addTemp = UInt16(a) + UInt16(byte)

        let part1 = (a & 0x88) >> 3
        let part2 = (byte & 0x88) >> 2
        let part3 = UInt8((addTemp & 0x88) >> 1)
        
        let lookup = part1 | part2 | part3
        
        a = UInt8(addTemp & 0xff)
        
        let part4 = addTemp & 0x100 > 0 ? cBit : 0
        let part5 = halfCarryAdd[lookup & 0x07]
        let part6 = overFlowAdd[lookup >> 4]
        let part7 = sz53Table[a]
        
        f = part4 | part5 | part6 | part7
    }
    
    @inline(__always) func sub(_ byte: UInt8) {
        let subTemp = UInt16(a) - UInt16(byte)
        
        let part1 = (a & 0x88) >> 3
        let part2 = (byte & 0x88) >> 2
        let part3 = UInt8((subTemp & 0x88) >> 1)
        
        let lookup = part1 | part2 | part3
        
        a = UInt8(subTemp & 0xff)
        
        let part4 = subTemp & 0x100 > 0 ? cBit : 0
        let part5 = halfCarrySub[lookup & 0x07]
        let part6 = overFlowSub[lookup >> 4]
        let part7 = sz53Table[a]
        
        f = part4 | nBit | part5 | part6 | part7
    }
    
    @inline(__always) func addc(_ byte: UInt8) {
        let addcTemp = UInt16(a) + UInt16(byte) + UInt16(f & cBit)
        
        let part1 = (a & 0x88) >> 3
        let part2 = (byte & 0x88) >> 2
        let part3 = UInt8((addcTemp & 0x88) >> 1)
        
        let lookup = part1 | part2 | part3
        
        a = UInt8(addcTemp & 0xff)
        
        let part4 = addcTemp & 0x100 > 0 ? cBit : 0
        let part5 = halfCarryAdd[lookup & 0x07]
        let part6 = overFlowAdd[lookup >> 4]
        let part7 = sz53Table[a]
        
        f = part4 | part5 | part6 | part7
    }
    
    @inline(__always) func subc(_ byte: UInt8) {
        let subcTemp = UInt16(a) - UInt16(byte) - UInt16(f & cBit)
        
        let part1 = (a & 0x88) >> 3
        let part2 = (byte & 0x88) >> 2
        let part3 = UInt8((subcTemp & 0x88) >> 1)
        
        let lookup = part1 | part2 | part3
        
        a = UInt8(subcTemp & 0xff)
        
        let part4 = subcTemp & 0x100 > 0 ? cBit : 0
        let part5 = halfCarrySub[lookup & 0x07]
        let part6 = overFlowSub[lookup >> 4]
        let part7 = sz53Table[a]
        
        f = part4 | nBit | part5 | part6 | part7
    }
    
    @inline(__always) func wordsubc(_ word: UInt16) {
        print("stub: wordsubc")
    }
    
    @inline(__always) func wordaddc(_ word: UInt16) {
        print("stub: wordaddc")
    }
    
    @inline(__always) func and(_ byte: UInt8) {
        a = a & byte
        f = hBit | sz53pvTable[a]
    }
    
    @inline(__always) func xor(_ byte: UInt8) {
        a = a ^ byte
        f = sz53pvTable[a]
    }
    
    @inline(__always) func or(_ byte: UInt8) {
        a = a | byte
        f = sz53pvTable[a]
    }
    
    @inline(__always) func compare(_ byte: UInt8) {
        var cpTemp: UInt16 = 0
        
        if byte > a {
            cpTemp = UInt16(byte) - UInt16(a)
            cpTemp = (65535 - cpTemp) + 1
        } else {
            cpTemp = UInt16(a) - UInt16(byte)
        }
        
        let part1 = (a & 0x88) >> 3
        let part2 = (byte & 0x88) >> 2
        let part3 = (cpTemp & 0x88) >> 1
        
        let lookup = part1 | part2 | UInt8(part3)
        
        let part4 = cpTemp & 0x100 > 0 ? cBit : (cpTemp > 0 ? 0 : zBit)
        let part5 = halfCarrySub[lookup & 0x07]
        let part6 = overFlowSub[lookup >> 4]
        let part7 = byte & (threeBit | fiveBit) | (UInt8(cpTemp & 0xff) & sBit)
        
        f = part4 | nBit | part5 | part6 | part7
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
    
    @inline(__always) func rlc(_ byte: UInt8) -> UInt8 {
        let val = (byte << 1) | (byte >> 7)
        f = (val & cBit) | sz53pvTable[val]
        return val
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
        let val: UInt32 = UInt32(hl) + UInt32(word)
        let part1 = (hl & 0x0800) >> 11
        let part2 = (word & 0x0800) >> 10
        let part3 = (val & 0x0800) >> 9
        
        let lookup = UInt8(part1) | UInt8(part2) | UInt8(part3)
        
        hl = UInt16(val & 0xffff)
        
        f = (f & (pvBit | zBit | sBit)) | (val & 0x10000 > 0 ? cBit : 0) | (UInt8((val >> 8)) & (threeBit | fiveBit)) | halfCarryAdd[lookup];
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
        f = (f & cBit) | sz53pvTable[byte]
        return UInt8(byte)
    }
    
}
