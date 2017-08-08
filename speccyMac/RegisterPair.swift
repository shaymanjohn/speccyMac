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
    
    var value: UInt16 {
        get {
            return (UInt16(hi.value) << 8) | UInt16(lo.value)
        }
        
        set {
            hi.value = UInt8(newValue >> 8)
            lo.value = UInt8(newValue & 0xff)
        }
    }
    
    init(hi: Register, lo: Register) {
        self.hi = hi
        self.lo = lo
    }
    
    final func inc() {
        value = value &+ 1
    }
    
    final func dec() {
        value = value &- 1
    }
    
    final func add(_ amount: UInt16) {
        let temp: UInt32 = UInt32(value) + UInt32(amount)
        let part1 = (value & 0x0800) >> 11
        let part2 = (amount & 0x0800) >> 10
        let part3 = (temp & 0x0800) >> 9
        
        let lookup = UInt8(part1) | UInt8(part2) | UInt8(part3)
        
        value = UInt16(temp & 0xffff)
        
        Z80.f.value = (Z80.f.value & (Z80.pvBit | Z80.zBit | Z80.sBit)) | (temp & 0x10000 > 0 ? Z80.cBit : 0) | (UInt8((temp & 0xff00 >> 8)) & (Z80.threeBit | Z80.fiveBit)) | Z80.halfCarryAdd[lookup]
    }
    
    final func sbc(_ regPair: RegisterPair) {
        let sub16temp: UInt32 = UInt32(value) &- UInt32(regPair.value) &- UInt32((Z80.f.value & Z80.cBit))
        let lookup = ((value & 0x8800) >> 11) | ((regPair.value & 0x8800) >> 10) | ((UInt16(sub16temp & 0xffff) & 0x8800) >> 9)
        value = UInt16(sub16temp & 0xffff)
        
        let part1 = (sub16temp & 0x10000 > 0 ? Z80.cBit : 0) | Z80.nBit
        let part2 = Z80.overFlowSub[UInt8(lookup & 0xff) >> 4]
        let part3 = hi.value & (Z80.threeBit | Z80.fiveBit | Z80.sBit)
        Z80.f.value = part1 | part2 | part3 | Z80.halfCarrySub[lookup&0x07] | (value > 0 ? 0 : Z80.zBit)
    }
}
