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
    var memory = [UInt8](repeating: 0, count: 65536)
    
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
    
    final func get(_ address: UInt16) -> UInt8 {
        return memory[address]
    }
    
    final func get(_ regPair: RegisterPair) -> UInt8 {
        return memory[regPair.value]
    }
    
    final func set(_ address: UInt16, byte: UInt8) {
        if address >= romSize {
            memory[Int(address)] = byte
        }
    }
    
    final func set(_ address: UInt16, reg: Register) {
        set(address, byte: reg.value)
    }
    
    final func set(_ address: UInt16, regPair: RegisterPair) {
        set(address, byte: regPair.lo.value)
        set(address &+ 1, byte: regPair.hi.value)
    }
    
    final func inc(_ address: UInt16) {
        var value = get(address)
        value = value &+ 1
        Z80.f.value = (Z80.f.value & Z80.cBit) | (value == 0x80 ? Z80.pvBit : 0) | (value & 0x0f > 0 ? 0 : Z80.hBit) | Z80.sz53Table[value]
        
        set(address, byte: value)
    }
    
    final func dec(_ address: UInt16) {
        var value = get(address)
        
        Z80.f.value = (Z80.f.value & Z80.cBit) | (value & 0x0f > 0 ? 0 : Z80.hBit ) | Z80.nBit
        value = value &- 1
        Z80.f.value |= (value == 0x7f ? Z80.pvBit : 0) | Z80.sz53Table[value]
        
        set(address, byte: value)
    }
    
    final func pop() -> UInt16 {
        let lo = get(Z80.sp)
        Z80.sp = Z80.sp &+ 1
        let hi = get(Z80.sp)
        Z80.sp = Z80.sp &+ 1
        
        return UInt16(hi) << 8 | UInt16(lo)
    }
    
    final func push(_ regPair: RegisterPair) {
        Z80.sp = Z80.sp &- 1
        set(Z80.sp, byte: regPair.hi.value)
        Z80.sp = Z80.sp &- 1
        set(Z80.sp, byte: regPair.lo.value)
    }
    
    final func push(_ word: UInt16) {
        Z80.sp = Z80.sp &- 1
        set(Z80.sp, byte: UInt8((word & 0xff00) >> 8))
        Z80.sp = Z80.sp &- 1
        set(Z80.sp, byte: UInt8((word & 0x00ff)))
    }
    
    final func indexSet(_ num: Int, baseAddress: UInt16, offset: UInt8) {
        let address = offset > 127 ? baseAddress  - (UInt16(256) - UInt16(offset)) : baseAddress + UInt16(offset)
        
        var byte = get(address)
        byte = byte | (1 << num)
        set(address, byte: byte)
    }
    
    final func indexRes(_ num: Int, baseAddress: UInt16, offset: UInt8) {
        let address = offset > 127 ? baseAddress  - (UInt16(256) - UInt16(offset)) : baseAddress + UInt16(offset)
        
        var byte = get(address)
        byte = byte & ~(1 << num)
        set(address, byte: byte)
    }
    
    final func indexBit(_ num: Int, baseAddress: UInt16, offset: UInt8) {
        let address = offset > 127 ? baseAddress  - (UInt16(256) - UInt16(offset)) : baseAddress + UInt16(offset)
        
        let value = get(address)
        
        Z80.f.value = (Z80.f.value & Z80.cBit ) | Z80.hBit | ((value >> 8) & (Z80.threeBit | Z80.fiveBit))
        
        if value & (1 << num) == 0 {
            Z80.f.value |= Z80.pvBit | Z80.zBit
        }
        
        if num == 7 && (value & 0x80) > 0 {
            Z80.f.value |= Z80.sBit
        }
    }
    
    final func rl(_ address: UInt16) {
        var byte = get(address)
        
        let rltemp = byte
        byte = (byte << 1) | (Z80.f.value & Z80.cBit)
        Z80.f.value = (rltemp >> 7) | Z80.sz53pvTable[(byte)]
        
        set(address, byte: byte)
    }
}
