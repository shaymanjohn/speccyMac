//
//  Memory.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

class Memory {
    
    var romSize: UInt16 = 0
    let memory = UnsafeMutablePointer<UInt8>.allocate(capacity: 65536)
    
    // Back-reference to machine for contention (set after Spectrum init)
    weak var machine: Spectrum?

    init(_ rom: String) {
        for ix in 0..<65536 {
            memory[ix] = 0
        }
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
        if address >= 0x4000 && address <= 0x7FFF, let m = machine {
            let tstate = m.processor.counter % UInt32(m.ticksPerFrame)
            let delay = UInt32(m.contentionTable[Int(tstate)])
            if delay > 0 {
                m.processor.incCounters(delay)
            }
        }
        return memory[Int(address)]
    }
    
    @inline(__always) final func set(_ address: UInt16, byte: UInt8) {
        if address >= romSize {
            if address >= 0x4000 && address <= 0x7FFF, let m = machine {
                let tstate = m.processor.counter % UInt32(m.ticksPerFrame)
                let delay = UInt32(m.contentionTable[Int(tstate)])
                if delay > 0 {
                    m.processor.incCounters(delay)
                }
            }
            memory[Int(address)] = byte
        }
    }
    
    @inline(__always) final func inc(_ address: UInt16) {
        var value = get(address)
        value = value &+ 1
        ZilogZ80.regF = (ZilogZ80.regF & ZilogZ80.cBit) | (value == 0x80 ? ZilogZ80.pvBit : 0) | (value & 0x0f > 0 ? 0 : ZilogZ80.hBit) | ZilogZ80.sz53Table[value]
        
        set(address, byte: value)
    }
    
    @inline(__always) final func dec(_ address: UInt16) {
        var value = get(address)
        
        ZilogZ80.regF = (ZilogZ80.regF & ZilogZ80.cBit) | (value & 0x0f > 0 ? 0 : ZilogZ80.hBit ) | ZilogZ80.nBit
        value = value &- 1
        ZilogZ80.regF |= (value == 0x7f ? ZilogZ80.pvBit : 0) | ZilogZ80.sz53Table[value]
        
        set(address, byte: value)
    }    
    
    @inline(__always) final func pop() -> UInt16 {
        let lo = get(ZilogZ80.sp)
        let hi = get(ZilogZ80.sp &+ 1)
        ZilogZ80.sp = ZilogZ80.sp &+ 2
        
        return (UInt16(hi) << 8) | UInt16(lo)
    }
    
    @inline(__always) final func push(_ word: UInt16) {
        set(ZilogZ80.sp &- 1, byte: UInt8((word & 0xff00) >> 8))
        set(ZilogZ80.sp &- 2, byte: UInt8(word & 0x00ff))
        ZilogZ80.sp = ZilogZ80.sp &- 2
    }
    
    @inline(__always) final func indexSet(_ num: UInt8, address: UInt16) {
        var byte = get(address)
        byte = byte | (1 << num)
        set(address, byte: byte)
    }
    
    @inline(__always) final func indexRes(_ num: UInt8, address: UInt16) {
        var byte = get(address)
        byte = byte & ~(1 << num)
        set(address, byte: byte)
    }
    
    @inline(__always) final func indexBit(_ num: UInt8, address: UInt16) {
        let value = get(address)
        ZilogZ80.regF = (ZilogZ80.regF & ZilogZ80.cBit ) | ZilogZ80.hBit | ((value >> 8) & (ZilogZ80.threeBit | ZilogZ80.fiveBit))
        
        if value & (1 << num) == 0 {
            ZilogZ80.regF |= ZilogZ80.pvBit | ZilogZ80.zBit
        }
        
        if num == 7 && (value & 0x80) > 0 {
            ZilogZ80.regF |= ZilogZ80.sBit
        }
    }
    
    @inline(__always) final func sla(_ address: UInt16) {
        var value = get(address)
        ZilogZ80.regF = value >> 7
        value = value << 1
        ZilogZ80.regF |= ZilogZ80.sz53pvTable[value]
        set(address, byte: value)
    }
      
    @inline(__always) final func rl(_ address: UInt16) {
        var byte = get(address)
        
        let rltemp = byte
        byte = (byte << 1) | (ZilogZ80.regF & ZilogZ80.cBit)
        ZilogZ80.regF = (rltemp >> 7) | ZilogZ80.sz53pvTable[byte]
        
        set(address, byte: byte)
    }
    
    @inline(__always) final func rr(_ address: UInt16) {
        var byte = get(address)
        
        let rrtemp = byte
        byte = (byte >> 1) | (ZilogZ80.regF << 7)
        ZilogZ80.regF = (rrtemp & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[byte]
        
        set(address, byte: byte)
    }
    
    @inline(__always) final func sra(_ address: UInt16) {
        var value = get(address)
        ZilogZ80.regF = value & ZilogZ80.cBit
        value = (value & 0x80) | (value >> 1)
        ZilogZ80.regF |= ZilogZ80.sz53pvTable[value]
        set(address, byte: value)
    }
    
    @inline(__always) final func srl(_ address: UInt16) {
        var value = get(address)
        ZilogZ80.regF = value & ZilogZ80.cBit
        value = value >> 1
        ZilogZ80.regF |= ZilogZ80.sz53pvTable[value]
        set(address, byte: value)
    }
    
    @inline(__always) final func rrc(_ address: UInt16) {
        var value = get(address)
        ZilogZ80.regF = value & ZilogZ80.cBit
        value = (value >> 1) | (value << 7)
        ZilogZ80.regF |= ZilogZ80.sz53pvTable[value]
        set(address, byte: value)
    }
    
    @inline(__always) final func rlc(_ address: UInt16) {
        var value = get(address)
        value = (value << 1) | (value >> 7)
        ZilogZ80.regF = (value & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[value]
        set(address, byte: value)
    }
}
