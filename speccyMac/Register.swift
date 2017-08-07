//
//  Register.swift
//  speccyMac
//
//  Created by John Ward on 05/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

class Register {
    
    var value: UInt8 = 0
    
    final func inc() {
        value = value &+ 1        
        Z80.f.value = (Z80.f.value & Z80.cBit) | (value == 0x80 ? Z80.pvBit : 0) | value & 0x0f > 0 ? 0 : Z80.hBit | Z80.sz53Table[value]
    }
    
    final func dec() {
        Z80.f.value = (Z80.f.value & Z80.cBit) | (value & 0x0f > 0 ? 0 : Z80.hBit ) | Z80.nBit
        value = value &- 1
        Z80.f.value |= (value == 0x7f ? Z80.pvBit : 0) | Z80.sz53Table[value]
    }
    
    final func rlc() {
        value = (value << 1) | (value >> 7)
        Z80.f.value = (value & Z80.cBit) | Z80.sz53pvTable[value]
    }
    
    final func bit(_ number: UInt8) {
        Z80.f.value = (Z80.f.value & Z80.cBit) | Z80.hBit | ( value & ( Z80.threeBit | Z80.fiveBit))
        if value & (1 << number) == 0 {
            Z80.f.value |= Z80.pvBit | Z80.zBit
        }
        
        if number == 7 && (value & 0x80) > 0 {
            Z80.f.value |= Z80.sBit
        }
    }
    
    final func srl() {
        Z80.f.value = value & Z80.cBit
        value = value >> 1
        Z80.f.value |= Z80.sz53pvTable[value]
    }
    
    final func portIn(_ high: UInt8, low: UInt8) {
        let byte: UInt8 = 0x01
        Z80.f.value = (Z80.f.value & Z80.cBit) | Z80.sz53pvTable[byte]
        value = byte
    }
    
    final func sla() {
        Z80.f.value = value >> 7
        value = value << 1
        Z80.f.value |= Z80.sz53pvTable[value]
    }
    
    final func rr() {
        let rrtemp = value
        value = (value >> 1) | (Z80.f.value << 7)
        Z80.f.value = (rrtemp & Z80.cBit) | Z80.sz53pvTable[value]
    }
    
    final func set(_ bit: UInt8) {
        value |= (1 << bit)
    }
    
    final func rrc() {
        Z80.f.value = value & Z80.cBit
        value = (value >> 1) | (value << 7)
        Z80.f.value |= Z80.sz53pvTable[value]
    }
}
