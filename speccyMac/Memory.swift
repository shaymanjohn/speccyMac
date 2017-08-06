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
    
    final func pop() -> UInt16 {
        let lo = get(Z80.sp)
        Z80.sp = Z80.sp &+ 1
        let hi = get(Z80.sp)
        Z80.sp = Z80.sp &+ 1
        
        return UInt16(hi << 8) | UInt16(lo)
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
}
