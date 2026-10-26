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

    // Banked backing for 128K. The 64KB address space is divided into four
    // 16KB slots. `slotBase[slot]` points at the first byte of whatever bank
    // (ROM or RAM) is currently mapped into that slot; `slotWritable[slot]`
    // is false for ROM. For 48K these simply point into the flat `memory`
    // buffer above, so get/set behave exactly as before.
    //
    // Resolving the base pointer per slot keeps the hot path to a shift, a
    // mask and one indirect load/store even when banking is active.
    private var slotBase: [UnsafeMutablePointer<UInt8>]
    private var slotWritable: [Bool]

    // Separate 16KB banks used only in banked (128K) mode. 8 RAM banks + up
    // to 2 ROM banks. Allocated lazily by configureBanked().
    private var ramBanks: [UnsafeMutablePointer<UInt8>] = []
    private var romBanks: [UnsafeMutablePointer<UInt8>] = []

    /// True once configureBanked() has set up 128K banking.
    private(set) var banked = false

    // Back-reference to machine for contention (set after Spectrum init).
    // unowned(unsafe) avoids retain/release and optional-unwrap overhead in the hot path.
    unowned(unsafe) var machine: Spectrum!

    init(_ rom: String) {
        for ix in 0..<65536 {
            memory[ix] = 0
        }

        // Point the four slots into the flat buffer. For 48K this is the
        // whole story; 128K reconfigures the slots in configureBanked().
        slotBase = [memory, memory + 0x4000, memory + 0x8000, memory + 0xC000]
        slotWritable = [true, true, true, true]

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

        // Reflect the loaded ROM in the slot write-protect flags (slot 0 is
        // ROM on a 48K machine).
        if romSize > 0 {
            slotWritable[0] = false
        }
    }

    // MARK: - 128K banking

    /// Switch Memory into banked (128K) mode with the given ROM images.
    /// `roms` must contain the 16KB ROM banks (ROM 0 = 128K editor,
    /// ROM 1 = 48K BASIC). Eight 16KB RAM banks are allocated and zeroed.
    /// After this call, use setPaging() to select the active banks.
    func configureBanked(roms: [[UInt8]]) {
        romBanks = roms.map { romImage in
            let p = UnsafeMutablePointer<UInt8>.allocate(capacity: 0x4000)
            p.initialize(repeating: 0, count: 0x4000)
            for ix in 0..<min(0x4000, romImage.count) { p[ix] = romImage[ix] }
            return p
        }
        ramBanks = (0..<8).map { _ in
            let p = UnsafeMutablePointer<UInt8>.allocate(capacity: 0x4000)
            p.initialize(repeating: 0, count: 0x4000)
            return p
        }
        banked = true
        romSize = 0x4000   // slot 0 is a 16KB ROM
        // Default 128K paging: ROM 0, RAM bank 0 at the top, screen = bank 5.
        setPaging(romBank: 0, highBank: 0)
    }

    /// Map the banks for 128K. Slots 1 and 2 are always RAM banks 5 and 2;
    /// slot 0 is the selected ROM; slot 3 is the selected RAM bank.
    func setPaging(romBank: Int, highBank: Int) {
        guard banked else { return }
        slotBase[0] = romBanks[min(romBank, romBanks.count - 1)]
        slotBase[1] = ramBanks[5]
        slotBase[2] = ramBanks[2]
        slotBase[3] = ramBanks[min(highBank, 7)]
        slotWritable = [false, true, true, true]
    }

    /// Direct access to a RAM bank's bytes (used by snapshot loaders to splat
    /// page data into a specific bank regardless of current paging).
    func ramBank(_ index: Int) -> UnsafeMutablePointer<UInt8>? {
        guard banked, index >= 0, index < ramBanks.count else { return nil }
        return ramBanks[index]
    }

    /// Zero every RAM bank (used on a 128K reset so a previously loaded game
    /// can't leave stale data in banks that aren't currently paged in).
    func clearAllBanks() {
        guard banked else { return }
        for bank in ramBanks {
            bank.update(repeating: 0, count: 0x4000)
        }
    }
    
    @inline(__always) final func get(_ address: UInt16) -> UInt8 {
        if address >= 0x4000 && address <= 0x7FFF {
            let m = machine!
            let tstate = m.processor.counter < m.ticksPerFrame ? m.processor.counter : m.processor.counter &- m.ticksPerFrame
            let delay = UInt32(m.contentionTable[Int(tstate)])
            if delay > 0 {
                m.processor.incCounters(delay)
            }
        }
        return slotBase[Int(address >> 14)][Int(address & 0x3FFF)]
    }
    
    @inline(__always) final func set(_ address: UInt16, byte: UInt8) {
        let slot = Int(address >> 14)
        if slotWritable[slot] {
            if address >= 0x4000 && address <= 0x7FFF {
                let m = machine!
                let tstate = m.processor.counter < m.ticksPerFrame ? m.processor.counter : m.processor.counter &- m.ticksPerFrame
                let delay = UInt32(m.contentionTable[Int(tstate)])
                if delay > 0 {
                    m.processor.incCounters(delay)
                }
            }
            slotBase[slot][Int(address & 0x3FFF)] = byte
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
