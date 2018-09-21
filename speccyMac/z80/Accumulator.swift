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
        ZilogZ80.f.value = (ZilogZ80.f.value & (ZilogZ80.cBit | ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (value & (ZilogZ80.threeBit | ZilogZ80.fiveBit)) | (ZilogZ80.nBit | ZilogZ80.hBit)
    }
    
    final func add(_ amount: UInt8) {
        let addtemp = UInt16(value) &+ UInt16(amount)
        
        let part1 = (value & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = UInt8(addtemp & 0x88) >> 1
        let lookup = part1 | part2 | part3
        value = UInt8(addtemp & 0xff)
        ZilogZ80.f.value = (addtemp & 0x100 > 0 ? ZilogZ80.cBit : 0 ) | ZilogZ80.halfCarryAdd[UInt8(lookup & 0xff) & 0x07] | ZilogZ80.overFlowAdd[UInt8(lookup & 0xff) >> 4] | ZilogZ80.sz53Table[value]
    }
    
    final func and(_ reg: Register) {
        value = value & reg.value
        ZilogZ80.f.value = ZilogZ80.hBit | ZilogZ80.sz53pvTable[value]
    }
    
    final func and(_ amount: UInt8) {
        value = value & amount
        ZilogZ80.f.value = ZilogZ80.hBit | ZilogZ80.sz53pvTable[value]
    }
    
    final func xor(_ reg: Register) {
        value = value ^ reg.value
        ZilogZ80.f.value = ZilogZ80.sz53pvTable[value]
    }
    
    final func xor(_ amount: UInt8) {
        value = value ^ amount
        ZilogZ80.f.value = ZilogZ80.sz53pvTable[value]
    }
    
    final func or(_ reg: Register) {
        value = value | reg.value
        ZilogZ80.f.value = ZilogZ80.sz53pvTable[value]
    }
    
    final func or(_ amount: UInt8) {
        value = value | amount
        ZilogZ80.f.value = ZilogZ80.sz53pvTable[value]
    }
    
    final func cp(_ reg: Register) {
        cp(reg.value)
    }
    
    final func cp(_ amount: UInt8) {
        let cpTemp: UInt16 = UInt16(value) &- UInt16(amount)
        
        let part1 = (value & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = UInt8(cpTemp & 0x88) >> 1
        
        let lookup = part1 | part2 | part3
        
        let part4 = cpTemp & 0x100 > 0 ? ZilogZ80.cBit : (cpTemp > 0 ? 0 : ZilogZ80.zBit)
        let part5 = ZilogZ80.halfCarrySub[lookup & 0x07]
        let part6 = ZilogZ80.overFlowSub[lookup >> 4]
        let part7 = amount & (ZilogZ80.threeBit | ZilogZ80.fiveBit) | (UInt8(cpTemp & 0xff) & ZilogZ80.sBit)
        
        ZilogZ80.f.value = part4 | ZilogZ80.nBit | part5 | part6 | part7
    }
    
    final func sub(_ amount: UInt8) {
        let subTemp = UInt16(value) &- UInt16(amount)
        
        let part1 = (value & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = UInt8(subTemp & 0x88) >> 1
        
        let lookup = part1 | part2 | part3
        
        value = UInt8(subTemp & 0xff)
        
        let part4 = subTemp & 0x100 > 0 ? ZilogZ80.cBit : 0
        let part5 = ZilogZ80.halfCarrySub[lookup & 0x07]
        let part6 = ZilogZ80.overFlowSub[lookup >> 4]
        let part7 = ZilogZ80.sz53Table[value]
        
        ZilogZ80.f.value = part4 | ZilogZ80.nBit | part5 | part6 | part7
    }
    
    final func rlca() {
        value = (value << 1) | (value >> 7)
        ZilogZ80.f.value = (ZilogZ80.f.value & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (value & (ZilogZ80.cBit | ZilogZ80.threeBit | ZilogZ80.fiveBit))
    }
    
    final func rrca() {
        ZilogZ80.f.value = (ZilogZ80.f.value & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (value & ZilogZ80.cBit)
        value = (value >> 1) | (value << 7)
        ZilogZ80.f.value |= (value & (ZilogZ80.threeBit | ZilogZ80.fiveBit))
    }
    
    final func rra() {
        let rratemp = value
        value = (value >> 1) | (ZilogZ80.f.value << 7)
        ZilogZ80.f.value = (ZilogZ80.f.value & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (value & (ZilogZ80.threeBit | ZilogZ80.fiveBit)) | (rratemp & ZilogZ80.cBit)
    }
    
    final func rla() {
        let rlatemp = value
        value = (value << 1) | (ZilogZ80.f.value & ZilogZ80.cBit)
        ZilogZ80.f.value = (ZilogZ80.f.value & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (value & (ZilogZ80.threeBit | ZilogZ80.fiveBit)) | (rlatemp >> 7)
    }
    
    final func adc(_ amount: UInt8) {
        let adctemp:UInt16 = UInt16(value) &+ UInt16(amount) &+ UInt16(ZilogZ80.f.value & ZilogZ80.cBit)
        let part1 = (value & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = (adctemp & 0x88) >> 1
        let lookup = part1 | part2 | UInt8(part3)
        
        value = UInt8(adctemp & 0xff)
        
        ZilogZ80.f.value = (adctemp & 0x100 > 0 ? ZilogZ80.cBit : 0) | ZilogZ80.halfCarryAdd[lookup & 0x07] | ZilogZ80.overFlowAdd[lookup >> 4] | ZilogZ80.sz53Table[value]
    }
    
    final func sbc(_ amount: UInt8) {
        let sbctemp = UInt16(value) &- UInt16(amount) &- UInt16((ZilogZ80.f.value & ZilogZ80.cBit))
        let part1 = (value & 0x88 ) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = (sbctemp & 0x88) >> 1
        let lookup = part1 | part2 | UInt8(part3)
        
        value = UInt8(sbctemp & 0xff)
        
        ZilogZ80.f.value = (sbctemp & 0x100 > 0 ? ZilogZ80.cBit : 0 ) | ZilogZ80.nBit | ZilogZ80.halfCarrySub[lookup & 0x07] | ZilogZ80.overFlowSub[lookup >> 4] | ZilogZ80.sz53Table[value]
    }
    
    final func neg() {
        let byte = value
        value = 0
        sub(byte)
    }
    
    func daa() {
        var rmeml: UInt8 = 0
        var rmemh = ZilogZ80.f.value & ZilogZ80.cBit
        
        if (ZilogZ80.f.value & ZilogZ80.hBit > 0) || (value & 0x0f > 9) {
            rmeml = 6
        }
        
        if (rmemh > 0) || (value > 0x99) {
            rmeml |= 0x60
        }
        
        if value > 0x99 {
            rmemh = 1
        }
        
        if ZilogZ80.f.value & ZilogZ80.nBit > 0 {
            if ((ZilogZ80.f.value & ZilogZ80.hBit) > 0) && ((value & 0x0f) < 6) {
                rmemh |= ZilogZ80.hBit
            }
            sub(rmeml)
        } else {
            if ((value & 0x0f) > 9) {
                rmemh |= ZilogZ80.hBit
            }
            add(rmeml)
        }
        
        ZilogZ80.f.value = (ZilogZ80.f.value & ~(ZilogZ80.cBit | ZilogZ80.pvBit | ZilogZ80.hBit)) | rmemh | ZilogZ80.parityBit[value]
    }    
}
