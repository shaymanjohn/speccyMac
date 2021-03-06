//
//  RegisterPair.swift
//  speccyMac
//
//  Created by John Ward on 05/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

class RegisterPair {
    
    let hi: Register
    let lo: Register
    
    final var value: UInt16 {
        @inline(__always) get {
            return (UInt16(hi.value) << 8) | UInt16(lo.value)
        }
        
        @inline(__always) set {
            hi.value = UInt8(newValue >> 8)
            lo.value = UInt8(newValue & 0xff)
        }
    }
    
    init(hi: Register, lo: Register) {
        self.hi = hi
        self.lo = lo
        
        value = 0xffff
    }
    
    final func add(_ amount: UInt16) {
        let temp: UInt32 = UInt32(value) &+ UInt32(amount)
        let part1 = (value & 0x0800) >> 11
        let part2 = (amount & 0x0800) >> 10
        let part3 = (temp & 0x0800) >> 9
        
        let lookup = UInt8(part1) | UInt8(part2) | UInt8(part3)
        
        value = UInt16(temp & 0xffff)
        
        ZilogZ80.f.value = (ZilogZ80.f.value & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (temp & 0x10000 > 0 ? ZilogZ80.cBit : 0) | (UInt8((temp & 0xff00) >> 8) & (ZilogZ80.threeBit | ZilogZ80.fiveBit)) | ZilogZ80.halfCarryAdd[lookup]
    }    
    
    final func adc(_ amount: UInt16) {
        let add16temp: UInt32 = UInt32(value) + UInt32(amount) + UInt32(ZilogZ80.f.value & ZilogZ80.cBit)
        let lookup = ((value & 0x8800) >> 11) | ((amount & 0x8800) >> 10) | ((UInt16(add16temp & 0xffff) & 0x8800) >> 9)
        value = UInt16(add16temp & 0xffff)
        
        let part1 = (add16temp & 0x10000) > 0 ? ZilogZ80.cBit : 0
        let part2 = ZilogZ80.overFlowAdd[UInt8(lookup & 0xff) >> 4]
        let part3 = hi.value & (ZilogZ80.threeBit | ZilogZ80.fiveBit | ZilogZ80.sBit)
        ZilogZ80.f.value = part1 | part2 | part3 | ZilogZ80.halfCarryAdd[UInt8(lookup & 0xff) & 0x07] | (value > 0 ? 0 : ZilogZ80.zBit)
    }
    
    final func sbc(_ regPair: RegisterPair) {
        sbc(regPair.value)
    }
        
    final func sbc(_ amount: UInt16) {
        let sub16temp: UInt32 = UInt32(value) &- UInt32(amount) &- UInt32(ZilogZ80.f.value & ZilogZ80.cBit)
        let lookup = ((value & 0x8800) >> 11) | ((amount & 0x8800) >> 10) | ((UInt16(sub16temp & 0xffff) & 0x8800) >> 9)
        value = UInt16(sub16temp & 0xffff)
        
        let part1 = (sub16temp & 0x10000 > 0 ? ZilogZ80.cBit : 0)
        let part2 = ZilogZ80.overFlowSub[UInt8(lookup & 0xff) >> 4]
        let part3 = hi.value & (ZilogZ80.threeBit | ZilogZ80.fiveBit | ZilogZ80.sBit)
        ZilogZ80.f.value = part1 | ZilogZ80.nBit | part2 | part3 | ZilogZ80.halfCarrySub[UInt8(lookup & 0xff) & 0x07] | (value > 0 ? 0 : ZilogZ80.zBit)
    }
}
