//
//  Memory.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

// @inline(__always) 

class Memory {
    
    var romSize: UInt16 = 0
    var memory = ContiguousArray<UInt8>(repeating: 0, count: 65536)

    init(_ rom: String) {
        
        if let romUrl = Bundle.main.url(forResource: rom, withExtension: "") {
            let romData: Data?
            
            do {
                try romData = Data.init(contentsOf: romUrl)
                
                if let data = romData {
                    romSize = UInt16(data.count)
                    
                    for ix in 0..<data.count {
                        memory[ix] = data[ix]
                    }
                }
            } catch {
                print("Couldn't get data from \(rom)")
            }
        } else {
            print("Couldn't find rom \(rom)")
        }
    }
    
    @inline(__always) final func get(_ address: UInt16) -> UInt8 {
        return memory[address]
    }
    
    @inline(__always) final func get(_ regPair: RegisterPair) -> UInt8 {
        return memory[regPair.value]
    }
    
    @inline(__always) final func set(_ address: UInt16, byte: UInt8) {
        if address >= romSize {
            memory[Int(address)] = byte
        }
    }
    
    @inline(__always) final func set(_ address: UInt16, reg: Register) {
        if address >= romSize {
            memory[Int(address)] = reg.value
        }
    }
    
    @inline(__always) final func set(_ address: UInt16, regPair: RegisterPair) {
        set(address, byte: regPair.lo.value)
        set(address &+ 1, byte: regPair.hi.value)
    }
    
    final func inc(_ address: UInt16) {
        var value = get(address)
        value = value &+ 1
        ZilogZ80.f.value = (ZilogZ80.f.value & ZilogZ80.cBit) | (value == 0x80 ? ZilogZ80.pvBit : 0) | (value & 0x0f > 0 ? 0 : ZilogZ80.hBit) | ZilogZ80.sz53Table[value]
        
        set(address, byte: value)
    }
    
    final func dec(_ address: UInt16) {
        var value = get(address)
        
        ZilogZ80.f.value = (ZilogZ80.f.value & ZilogZ80.cBit) | (value & 0x0f > 0 ? 0 : ZilogZ80.hBit ) | ZilogZ80.nBit
        value = value &- 1
        ZilogZ80.f.value |= (value == 0x7f ? ZilogZ80.pvBit : 0) | ZilogZ80.sz53Table[value]
        
        set(address, byte: value)
    }    
    
    final func pop() -> UInt16 {
        let lo = get(ZilogZ80.sp)
        let hi = get(ZilogZ80.sp + 1)
        ZilogZ80.sp = ZilogZ80.sp &+ 2
        
        return (UInt16(hi) << 8) | UInt16(lo)
    }
    
    final func push(_ regPair: RegisterPair) {
        set(ZilogZ80.sp &- 1, byte: regPair.hi.value)
        set(ZilogZ80.sp &- 2, byte: regPair.lo.value)
        ZilogZ80.sp = ZilogZ80.sp &- 2
    }
    
    final func push(_ word: UInt16) {
        set(ZilogZ80.sp &- 1, byte: UInt8((word & 0xff00) >> 8))
        set(ZilogZ80.sp &- 2, byte: UInt8(word & 0x00ff))
        ZilogZ80.sp = ZilogZ80.sp &- 2
    }
    
    final func indexSet(_ num: UInt8, address: UInt16) {
        var byte = get(address)
        byte = byte | (1 << num)
        set(address, byte: byte)
    }
    
    final func indexRes(_ num: UInt8, address: UInt16) {
        var byte = get(address)
        byte = byte & ~(1 << num)
        set(address, byte: byte)
    }
    
    final func indexBit(_ num: UInt8, address: UInt16) {
        let value = get(address)
        ZilogZ80.f.value = (ZilogZ80.f.value & ZilogZ80.cBit ) | ZilogZ80.hBit | ((value >> 8) & (ZilogZ80.threeBit | ZilogZ80.fiveBit))
        
        if value & (1 << num) == 0 {
            ZilogZ80.f.value |= ZilogZ80.pvBit | ZilogZ80.zBit
        }
        
        if num == 7 && (value & 0x80) > 0 {
            ZilogZ80.f.value |= ZilogZ80.sBit
        }
    }
    
    final func sla(_ regPair: RegisterPair) {
        var value = get(regPair.value)
        ZilogZ80.f.value = value >> 7
        value = value << 1
        ZilogZ80.f.value |= ZilogZ80.sz53pvTable[value]
        set(regPair.value, byte: value)
    }
      
    final func rl(_ regPair: RegisterPair) {
        var byte = get(regPair.value)
        
        let rltemp = byte
        byte = (byte << 1) | (ZilogZ80.f.value & ZilogZ80.cBit)
        ZilogZ80.f.value = (rltemp >> 7) | ZilogZ80.sz53pvTable[byte]
        
        set(regPair.value, byte: byte)
    }
    
    final func rr(_ regPair: RegisterPair) {
        var byte = get(regPair.value)
        
        let rrtemp = byte
        byte = (byte >> 1) | (ZilogZ80.f.value << 7)
        ZilogZ80.f.value = (rrtemp & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[byte]
        
        set(regPair.value, byte: byte)
    }
    
    final func sra(_ address: UInt16) {
        var value = get(address)
        ZilogZ80.f.value = value & ZilogZ80.cBit
        value = (value & 0x80) | (value >> 1)
        ZilogZ80.f.value |= ZilogZ80.sz53pvTable[value]
        set(address, byte: value)
    }
    
    final func srl(_ regPair: RegisterPair) {
        var value = get(regPair.value)
        ZilogZ80.f.value = value & ZilogZ80.cBit
        value = value >> 1
        ZilogZ80.f.value |= ZilogZ80.sz53pvTable[value]
        set(regPair.value, byte: value)
    }
    
    final func rrc(_ address: UInt16) {
        var value = get(address)
        ZilogZ80.f.value = value & ZilogZ80.cBit
        value = (value >> 1) | (value << 7)
        ZilogZ80.f.value |= ZilogZ80.sz53pvTable[value]
        set(address, byte: value)
    }
    
    final func rlc(_ address: UInt16) {
        var value = get(address)
        value = (value << 1) | (value >> 7)
        ZilogZ80.f.value = (value & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[value]
        set(address, byte: value)
    }
}
