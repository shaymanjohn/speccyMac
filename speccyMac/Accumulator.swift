//
//  Accumulator.swift
//  speccyMac
//
//  Created by John Ward on 05/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

class Accumulator : Register {
    
    final func cpl() {
        value = value ^ 0xff
        Z80.f.value = (Z80.f.value & (Z80.cBit | Z80.pvBit | Z80.zBit | Z80.sBit)) | (value & (Z80.threeBit | Z80.fiveBit)) | (Z80.nBit | Z80.hBit)
    }
    
    final func add(_ amount: UInt8) {
        let addtemp = UInt16(value) + UInt16(amount)
        
        let part1 = UInt16((value & 0x88) >> 3)
        let part2 = UInt16((amount & 0x88) >> 2)
        let part3 = (addtemp & 0x88) >> 1
        let lookup = part1 | part2 | part3
        value = UInt8(addtemp & 0xff)        
        Z80.f.value = (addtemp & 0x100 > 0 ? Z80.cBit : 0 ) | Z80.halfCarryAdd[UInt8(lookup & 0xff) & 0x07] | Z80.overFlowAdd[UInt8(lookup & 0xff) >> 4] | Z80.sz53Table[value]
    }
    
    final func and(_ reg: Register) {
        value = value & reg.value
        Z80.f.value = Z80.hBit | Z80.sz53pvTable[value]
    }
    
    final func and(_ amount: UInt8) {
        value = value & amount
        Z80.f.value = Z80.hBit | Z80.sz53pvTable[value]
    }
    
    final func xor(_ reg: Register) {
        value = value ^ reg.value
        Z80.f.value = Z80.sz53pvTable[value]
    }
    
    final func xor(_ amount: UInt8) {
        value = value ^ amount
        Z80.f.value = Z80.sz53pvTable[value]
    }
    
    final func or(_ reg: Register) {
        value = value | reg.value
        Z80.f.value = Z80.sz53pvTable[value]
    }
    
    final func or(_ amount: UInt8) {
        value = value | amount
        Z80.f.value = Z80.sz53pvTable[value]
    }
    
    final func cp(_ reg: Register) {
        cp(reg.value)
    }
    
    final func cp(_ amount: UInt8) {
        var cpTemp: UInt16 = 0
        
        if amount > value {
            cpTemp = UInt16(amount) - UInt16(value)
            cpTemp = (65535 - cpTemp) &+ 1
        } else {
            cpTemp = UInt16(value) - UInt16(amount)
        }
        
        let part1 = (value & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = (cpTemp & 0x88) >> 1
        
        let lookup = part1 | part2 | UInt8(part3)
        
        let part4 = cpTemp & 0x100 > 0 ? Z80.cBit : (cpTemp > 0 ? 0 : Z80.zBit)
        let part5 = Z80.halfCarrySub[lookup & 0x07]
        let part6 = Z80.overFlowSub[lookup >> 4]
        let part7 = amount & (Z80.threeBit | Z80.fiveBit) | (UInt8(cpTemp & 0xff) & Z80.sBit)
        
        Z80.f.value = part4 | Z80.nBit | part5 | part6 | part7
    }
    
    final func sub(_ amount: UInt8) {
        let subTemp = UInt16(value) &- UInt16(amount)
        
        let part1 = (value & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = UInt8((subTemp & 0x88) >> 1)
        
        let lookup = part1 | part2 | part3
        
        value = UInt8(subTemp & 0xff)
        
        let part4 = subTemp & 0x100 > 0 ? Z80.cBit : 0
        let part5 = Z80.halfCarrySub[lookup & 0x07]
        let part6 = Z80.overFlowSub[lookup >> 4]
        let part7 = Z80.sz53Table[value]
        
        Z80.f.value = part4 | Z80.nBit | part5 | part6 | part7
    }
    
    final func rlca() {
        value = (value << 1) | (value >> 7)
        Z80.f.value = (Z80.f.value & (Z80.pvBit | Z80.zBit | Z80.sBit)) | (value & (Z80.cBit | Z80.threeBit | Z80.fiveBit))
    }
    
    final func rrca() {
        Z80.f.value = (Z80.f.value & (Z80.pvBit | Z80.zBit | Z80.sBit)) | (value & Z80.cBit)
        value = (value >> 1) | (value << 7)
        Z80.f.value |= (value & (Z80.threeBit | Z80.fiveBit))
    }
    
    final func rra() {
        let rratemp = value
        value = (value >> 1) | (Z80.f.value << 7)
        Z80.f.value = (Z80.f.value & (Z80.pvBit | Z80.zBit | Z80.sBit)) | (value & (Z80.threeBit | Z80.fiveBit)) | (rratemp & Z80.cBit)
    }
    
    final func rla() {
        let rlatemp = value
        value = (value << 1) | (Z80.f.value & Z80.cBit)
        Z80.f.value = (Z80.f.value & (Z80.pvBit | Z80.zBit | Z80.sBit)) | (value & (Z80.threeBit | Z80.fiveBit)) | (rlatemp >> 7)
    }
    
    final func adc(_ amount: UInt8) {
        let adctemp:UInt16 = UInt16(value) &+ UInt16(amount) &+ UInt16(Z80.f.value & Z80.cBit)
        let part1 = (value & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = (adctemp & 0x88) >> 1
        let lookup = part1 | part2 | UInt8(part3)
        
        value = UInt8(adctemp & 0xff)
        
        Z80.f.value = part1 | Z80.halfCarryAdd[lookup & 0x07] | Z80.overFlowAdd[lookup >> 4] | Z80.sz53Table[value]
    }
    
    final func sbc(_ amount: UInt8) {
        let sbctemp = UInt16(value) &- UInt16(amount) &- UInt16((Z80.f.value & Z80.cBit))
        let part1 = (value & 0x88 ) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = (sbctemp & 0x88) >> 1
        let lookup = part1 | part2 | UInt8(part3)
        
        value = UInt8(sbctemp & 0xff)
        
        Z80.f.value = (sbctemp & 0x100 > 0 ? Z80.cBit : 0 ) | Z80.nBit | Z80.halfCarrySub[lookup & 0x07] | Z80.overFlowSub[lookup >> 4] | Z80.sz53Table[value]
    }
    
    final func neg() {
        let byte = value
        value = 0
        sub(byte)
    }
    
    func daa() {
        print("stub daa")
    }
}
