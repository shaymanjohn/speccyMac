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
        ZilogZ80.f.value = (ZilogZ80.f.value & ZilogZ80.cBit) | (value == 0x80 ? ZilogZ80.pvBit : 0) | (value & 0x0f > 0 ? 0 : ZilogZ80.hBit) | ZilogZ80.sz53Table[value]
    }
    
    final func dec() {
        ZilogZ80.f.value = (ZilogZ80.f.value & ZilogZ80.cBit) | (value & 0x0f > 0 ? 0 : ZilogZ80.hBit) | ZilogZ80.nBit
        value = value &- 1
        ZilogZ80.f.value |= (value == 0x7f ? ZilogZ80.pvBit : 0) | ZilogZ80.sz53Table[value]
    }
    
    final func rlc() {
        value = (value << 1) | (value >> 7)
        ZilogZ80.f.value = (value & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[value]
    }
    
    final func bit(_ number: UInt8) {
        ZilogZ80.f.value = (ZilogZ80.f.value & ZilogZ80.cBit) | ZilogZ80.hBit | ( value & ( ZilogZ80.threeBit | ZilogZ80.fiveBit))
        if value & (1 << number) == 0 {
            ZilogZ80.f.value |= ZilogZ80.pvBit | ZilogZ80.zBit
        }
        
        if number == 7 && (value & 0x80) > 0 {
            ZilogZ80.f.value |= ZilogZ80.sBit
        }
    }
    
    final func srl() {
        ZilogZ80.f.value = value & ZilogZ80.cBit
        value = value >> 1
        ZilogZ80.f.value |= ZilogZ80.sz53pvTable[value]
    }
    
    final func sla() {
        ZilogZ80.f.value = value >> 7
        value = value << 1
        ZilogZ80.f.value |= ZilogZ80.sz53pvTable[value]
    }
    
    final func rr() {
        let rrtemp = value
        value = (value >> 1) | (ZilogZ80.f.value << 7)
        ZilogZ80.f.value = (rrtemp & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[value]
    }
    
    final func rl() {
        let rltemp = value
        value = (value << 1) | (ZilogZ80.f.value & ZilogZ80.cBit)
        ZilogZ80.f.value = (rltemp >> 7) | ZilogZ80.sz53pvTable[value]
    }
    
    final func set(_ bit: UInt8) {
        value |= (1 << bit)
    }
    
    final func res(_ bit: UInt8) {
        value &= ~(1 << bit)
    }
    
    final func rrc() {
        ZilogZ80.f.value = value & ZilogZ80.cBit
        value = (value >> 1) | (value << 7)
        ZilogZ80.f.value |= ZilogZ80.sz53pvTable[value]
    }
    
    final func sra() {
        ZilogZ80.f.value = value & ZilogZ80.cBit
        value = (value & 0x80) | (value >> 1)
        ZilogZ80.f.value |= ZilogZ80.sz53pvTable[value]
    }
}
