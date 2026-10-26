//
//  Spectrum128.swift
//  speccyMac
//
//  ZX Spectrum 128K machine. Subclasses the 48K Spectrum and adds:
//   - 32KB ROM in two 16KB banks (ROM 0 = 128K editor, ROM 1 = 48K BASIC)
//   - 128KB RAM in eight 16KB banks, paged via port 0x7FFD
//   - shadow screen (display bank 5 or 7, selected by 0x7FFD bit 3)
//
//  AY-3-8912 sound is stubbed for now (ports 0xFFFD/0xBFFD are accepted but
//  ignored) - see README "AY sounds" to-do.
//

import Foundation

final class Spectrum128: Spectrum {

    // Last value written to port 0x7FFD.
    private var port7ffd: UInt8 = 0

    // Once bit 5 of 0x7FFD is set, paging is locked until a hard reset. This
    // is how 128K software "becomes" a 48K machine (e.g. to run 48K games).
    private var pagingLocked = false

    // Which RAM bank the ULA displays: 5 (normal) or 7 (shadow).
    private var displayBank = 5

    // 128K runs a longer frame than the 48K machine.
    private let ticks128: UInt32 = 70908

    override init() {
        super.init()

        // Load the two 16KB ROM images and switch Memory into banked mode.
        let rom0 = Spectrum128.loadROM("128-0.rom")
        let rom1 = Spectrum128.loadROM("128-1.rom")
        memory.configureBanked(roms: [rom0, rom1])

        // 128K frame timing.
        ticksPerFrame = ticks128
        rebuildContentionTable()

        // Power-on paging: ROM 0, RAM bank 0 at 0xC000, normal screen.
        applyPaging(0x00)
    }

    /// Reset to power-on: unlock and restore default paging, wipe all RAM
    /// banks, then do the standard CPU/video reset so the 128K ROM reboots.
    override func resetMachine() {
        pagingLocked = false
        applyPaging(0x00)
        memory.clearAllBanks()
        super.resetMachine()
    }

    // MARK: - Paging

    /// Decode a write to the 128K memory paging port (0x7FFD) and reconfigure    /// the banks. No effect once paging is locked.
    private func applyPaging(_ value: UInt8) {
        if pagingLocked { return }

        port7ffd = value

        let highBank = Int(value & 0x07)         // bits 0-2: bank at 0xC000
        let romBank  = (value & 0x10) != 0 ? 1 : 0 // bit 4: ROM select
        displayBank  = (value & 0x08) != 0 ? 7 : 5 // bit 3: shadow screen

        memory.setPaging(romBank: romBank, highBank: highBank)

        if (value & 0x20) != 0 {                 // bit 5: lock paging
            pagingLocked = true
        }
    }

    // MARK: - I/O

    override func output(_ port: UInt16, byte: UInt8) {
        // 0x7FFD memory paging port: decoded when A1 and A15 are both 0.
        if (port & 0x8002) == 0 {
            applyPaging(byte)
            return
        }

        // AY-3-8912 sound (0xFFFD register select, 0xBFFD data write) - stubbed.
        if (port & 0xC002) == 0xC000 {
            // register select - ignored for now
            return
        }
        if (port & 0xC002) == 0x8000 {
            // data write - ignored for now
            return
        }

        // Otherwise fall through to the ULA (border/beeper) on even ports.
        super.output(port, byte: byte)
    }

    // MARK: - Screen

    // The 128K ULA shows either bank 5 (normal) or bank 7 (shadow). Bank 5 is
    // mapped at 0x4000 so the normal case uses the inherited capture; for the
    // shadow bank we read bank 7's bytes directly.
    override func captureRow(_ row: UInt16) {
        if displayBank == 5 {
            super.captureRow(row)
            return
        }

        guard let bank7 = memory.ramBank(7) else {
            super.captureRow(row)
            return
        }

        // screenRowAddress/attributeRowAddress hold absolute 0x4000-based
        // addresses; subtract 0x4000 to index into the 16KB bank directly.
        var pixelAddress  = Int(screenRowAddress[Int(row)]) - 0x4000
        var colourAddress = Int(attributeRowAddress[Int(row >> 3)]) - 0x4000

        let index = Int(row << 5)
        for ix in index..<index + 32 {
            screenBuffer[ix] = bank7[pixelAddress]
            colourBuffer[ix] = bank7[colourAddress]
            pixelAddress  += 1
            colourAddress += 1
        }
    }

    // MARK: - Helpers

    private static func loadROM(_ name: String) -> [UInt8] {
        guard let url = Bundle.main.url(forResource: name, withExtension: ""),
              let data = try? Data(contentsOf: url) else {
            print("Couldn't load ROM \(name)")
            return [UInt8](repeating: 0, count: 0x4000)
        }
        return [UInt8](data)
    }

    // Build a contention delay table sized for the 128K frame. The 128K ULA
    // uses the same 8-cycle contention pattern as the 48K but over a longer
    // frame (228 T-states per line, display starting one line later). This is
    // a close approximation; exact per-model timing can be refined later.
    private func rebuildContentionTable() {
        let pattern: [UInt8] = [6, 5, 4, 3, 2, 1, 0, 0]
        for i in 0..<Int(ticks128) {
            contentionTable[i] = 0
        }
        // 128K: 311 lines, display lines 63..254, 228 T-states per line.
        for line in 63..<255 {
            let lineStart = line * 228
            for col in 0..<128 {
                let idx = lineStart + col
                if idx < Int(ticks128) {
                    contentionTable[idx] = pattern[col % 8]
                }
            }
        }
    }
}
