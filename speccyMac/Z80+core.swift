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
        f = (f & cBit) | (thisByte == 0x80 ? pvBit : 0) | thisByte & 0x0f > 0 ? hBit : 0 | sz53Table[Int(thisByte)]
        return thisByte
    }
    
    @inline(__always) func dec(_ byte: UInt8) -> UInt8 {
        
        f = (f & cBit) | (byte & 0x0f > 0 ? 0 : hBit ) | nBit
        let thisByte = byte &- 1
        f |= (byte == 0x7f ? pvBit : 0) | sz53Table[Int(thisByte)]
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
        let part5 = halfCarryAdd[Int(lookup & 0x07)]
        let part6 = overFlowAdd[Int(lookup >> 4)]
        let part7 = sz53Table[Int(a)]
        
        f = part4 | part5 | part6 | part7
    }
    
    @inline(__always) func setRelativePC(_ byte: UInt8) {
        let offset: UInt16 = byte > 127 ? UInt16(byte) : 256 - UInt16(byte)
        pc = pc + offset
    }
    
    @inline(__always) func push(_ registerPair: UInt16) {
        sp = sp &- 1
        memory.set(sp, byte: UInt8(UInt16(registerPair) >> 8))
        sp = sp &- 1
        memory.set(sp, byte: UInt8(registerPair & 0x00ff))
    }
    
    @inline(__always) func pop() -> UInt16 {
        let byte1 = memory.get(sp)
        sp = sp &+ 1
        let byte2 = memory.get(sp)
        sp = sp &+ 1
        
        return UInt16(byte1 << 8) + UInt16(byte2)
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
    
    @inline(__always) func compare(_ byte: UInt8) {
        let cpTemp = Int(a) - Int(byte)
        
        if cpTemp == 0 {
            f = f | zBit
        } else {
            f = f & 0xbf
        }
    }
    
    @inline(__always) func indexSet(_ num: Int, offset: UInt16) {
        var byte = memory.get(offset)
        byte = byte | (1 << num)
        memory.set(offset, byte: byte)
        incCounters(amount: 23)
    }
    
    @inline(__always) func or(_ byte: UInt8) {
        a = a | byte
        f = sz53pvTable[Int(a)]
    }
    
    @inline(__always) func xor(_ byte: UInt8) {
        a = a ^ byte
        f = sz53pvTable[Int(a)]
    }
    
    @inline(__always) func and(_ byte: UInt8) {
        a = a & byte
        f = hBit | sz53pvTable[Int(a)]
    }
    
    @inline(__always) func rlc(_ byte: UInt8) -> UInt8 {
        let val = (byte << 1) | (byte >> 7)
        f = (val & cBit) | sz53pvTable[Int(val)]
        return val
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
