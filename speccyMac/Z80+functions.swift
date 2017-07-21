//
//  Z80+functions.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
    
    @inline(__always) func byteInc(_ byte: UInt8) -> UInt8 {
        
        let thisByte = byte &+ 1
        
        self.f = (self.f & cBit) | (byte == 0x80 ? pvBit : 0) | thisByte & 0x0f > 0 ? hBit : 0 | sz53Table[Int(thisByte)]
        
        return thisByte
    }
    
    @inline(__always) func byteDec(_ byte: UInt8) -> UInt8 {
        
        self.f = (self.f & cBit) | (byte & 0x0f > 0 ? 0 : hBit ) | nBit
        let thisByte = byte &- 1
        self.f |= (byte == 0x7f ? pvBit : 0) | sz53Table[Int(thisByte)]
        
        return thisByte
    }
    
    @inline(__always) func setRelativePC(_ byte: UInt8) {
        let offset: UInt16 = byte > 127 ? UInt16(byte) : 256 - UInt16(byte)
        self.pc = self.pc + offset
    }
    
    @inline(__always) func byteAdd(_ byte: UInt8) {
        let addTemp = UInt16(self.a) + UInt16(byte)

        let part1 = (self.a & 0x88) >> 3
        let part2 = (byte & 0x88) >> 2
        let part3 = UInt8((addTemp & 0x88) >> 1)
        
        let lookup = part1 | part2 | part3
        
        self.a = UInt8(addTemp & 0xff)
        
        let part4 = addTemp & 0x100 > 0 ? cBit : 0
        let part5 = halfCarryAdd[Int(lookup & 0x07)]
        let part6 = overFlowAdd[Int(lookup >> 4)]
        let part7 = sz53Table[Int(self.a)]
        
        self.f = part4 | part5 | part6 | part7
    }
    
    @inline(__always) func push(registerPair: UInt16) {
        self.sp = self.sp &- 1
        memory.set(self.sp, byte: UInt8(UInt16(registerPair) >> 8))
        self.sp = self.sp &- 1
        memory.set(self.sp, byte: UInt8(registerPair & 0x00ff))
    }
    
    @inline(__always) func incR() {
        if self.r > 127 {
            var byte = self.r & 0x7f
            byte = byte + 1
            if byte == 128 {
                byte = 0
            }
            self.r = byte | 0x80
        } else {
            self.r = self.r + 1
            if self.r == 128 {
                self.r = 0
            }
        }
    }
    
    @inline(__always) func compare(register: UInt8) {
        let cpTemp = Int(self.a) - Int(register)
        
        if cpTemp == 0 {
            self.f = self.f | self.zBit
        } else {
            self.f = self.f & 0xbf
        }
    }
    
    @inline(__always) func xor(register: UInt8) {
        self.a = self.a ^ register
        self.f = self.sz53pvTable[Int(self.a)]
    }
    
    @inline(__always) func out(port: UInt8, register: UInt8) {
        if port == 0xfe {
            screen?.borderColour = register & 0x07
            
            if register & 0x10 > 0 {
                self.clicksCount = self.clicksCount + 1
            }
        }
    }
    
}
