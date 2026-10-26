//
//  Spectrum128Tests.swift
//  speccyMacTests
//
//  Verifies the 128K machine: banked memory, 0x7FFD paging decode, dual ROM,
//  and 128K .z80 / .szx snapshot loading.
//

import XCTest
import zlib
@testable import speccyMac

class Spectrum128Tests: XCTestCase {

    var spectrum: Spectrum128!
    var z80: ZilogZ80 { spectrum.processor as! ZilogZ80 }

    override func setUp() {
        super.setUp()
        CPUStateLock.lock.lock()
        spectrum = Spectrum128()
        spectrum.processor.machine = spectrum
        ZilogZ80.regF = 0
        ZilogZ80.sp = 0
    }

    override func tearDown() {
        spectrum = nil
        CPUStateLock.lock.unlock()
        super.tearDown()
    }

    // MARK: - Memory / paging

    func testMemoryIsBanked() {
        XCTAssertTrue(spectrum.memory.banked, "128K memory should be banked")
    }

    // Regression: the ED-prefixed OUT (c),r opcodes for B/C/H/L were missing,
    // so AY music players that select a register with e.g. `OUT (C),H` had the
    // select silently dropped and all data landed in register 14 (total
    // silence). Verify `OUT (C),H` (ED 61) reaches the AY register-select.
    func testOutCRSelectsAYRegister() {
        // Seed register 3 with a known value via the normal path.
        spectrum.output(0xfffd, byte: 3)
        spectrum.output(0xbffd, byte: 0xAA)

        // Select register 3 using OUT (C),H: BC = 0xFFFD (AY select port),
        // H = 3 (the register number). Port and value are independent here.
        z80.regB = 0xFF
        z80.regC = 0xFD
        z80.regH = 3
        z80.edprefix(opcode: 0x61, first: 0, second: 0)   // OUT (C),H

        // A data write must now land in register 3, overwriting 0xAA.
        spectrum.output(0xbffd, byte: 0x55)

        // Read register 3 back.
        spectrum.output(0xfffd, byte: 3)
        XCTAssertEqual(spectrum.input(0xff, low: 0xfd), 0x55,
                       "OUT (C),H did not select the AY register (write landed elsewhere)")
    }

    func testBankSelectAt0xC000() {
        let mem = spectrum.memory

        // Write a marker into bank 3 directly, then page it in at 0xC000.
        mem.ramBank(3)![0] = 0xAB
        mem.ramBank(6)![0] = 0xCD

        // 0x7FFD bits 0-2 select the bank at 0xC000.
        spectrum.output(0x7ffd, byte: 0x03)   // bank 3
        XCTAssertEqual(mem.get(0xC000), 0xAB, "bank 3 not paged in")

        spectrum.output(0x7ffd, byte: 0x06)   // bank 6
        XCTAssertEqual(mem.get(0xC000), 0xCD, "bank 6 not paged in")
    }

    func testWriteThroughPagedBank() {
        let mem = spectrum.memory
        spectrum.output(0x7ffd, byte: 0x01)   // bank 1 at 0xC000
        mem.set(0xC000, byte: 0x7E)
        XCTAssertEqual(mem.ramBank(1)![0], 0x7E, "write did not reach bank 1")
    }

    func testRomSelect() {
        let mem = spectrum.memory
        // Both 128K ROMs begin 0xF3 (DI) at 0x0000, so compare at 0x0001 where
        // they differ. Confirm the byte changes when switching ROM via bit 4,
        // and that ROM stays write-protected.
        spectrum.output(0x7ffd, byte: 0x00)   // ROM 0
        let rom0Byte = mem.get(0x0001)
        spectrum.output(0x7ffd, byte: 0x10)   // ROM 1
        let rom1Byte = mem.get(0x0001)
        XCTAssertNotEqual(rom0Byte, rom1Byte, "ROM did not switch")

        // ROM must stay read-only.
        mem.set(0x0001, byte: rom1Byte &+ 1)
        XCTAssertEqual(mem.get(0x0001), rom1Byte, "ROM should be write-protected")
    }

    func testPagingLock() {
        let mem = spectrum.memory
        mem.ramBank(2)![0] = 0x11
        mem.ramBank(4)![0] = 0x22

        spectrum.output(0x7ffd, byte: 0x02)          // bank 2
        XCTAssertEqual(mem.get(0xC000), 0x11)

        // Set the lock bit (bit 5) while selecting bank 4.
        spectrum.output(0x7ffd, byte: 0x04 | 0x20)   // bank 4 + lock
        XCTAssertEqual(mem.get(0xC000), 0x22, "bank 4 should have paged in before lock")

        // Further paging writes must be ignored.
        spectrum.output(0x7ffd, byte: 0x02)          // try bank 2 again
        XCTAssertEqual(mem.get(0xC000), 0x22, "paging should be locked")
    }

    // MARK: - 128K .z80 loading

    func testLoad128KZ80() {
        var bytes = [UInt8](repeating: 0, count: 30)
        // v1 header, PC = 0 -> v2/v3.
        bytes[6] = 0; bytes[7] = 0
        bytes[12] = 0x00   // flags1

        // Extended header length 23 (v2).
        bytes.append(23); bytes.append(0)
        var ext = [UInt8](repeating: 0, count: 23)
        ext[0] = 0x00; ext[1] = 0xC0    // real PC = 0xC000
        ext[2] = 4                      // hardware mode 4 = 128K (v2)
        ext[3] = 0x00                   // last 0x7FFD write
        bytes.append(contentsOf: ext)

        // One page block: page 8 (-> RAM bank 5) uncompressed, filled 0x5A.
        bytes.append(0xFF); bytes.append(0xFF)   // length 0xFFFF = uncompressed
        bytes.append(8)                          // page 8 -> bank 5
        bytes.append(contentsOf: [UInt8](repeating: 0x5A, count: 0x4000))

        let ok = Z80Loader(z80: z80).load(data: Data(bytes))
        XCTAssertTrue(ok, "128K .z80 load failed")
        XCTAssertEqual(z80.pc, 0xC000, "PC wrong")
        XCTAssertEqual(spectrum.memory.ramBank(5)![0], 0x5A, "page 8 not loaded into bank 5")
        XCTAssertEqual(spectrum.memory.ramBank(5)![0x3FFF], 0x5A, "page 8 end wrong")
    }

    func testLoad128KZ80RejectedOn48K() {
        // Build the same 128K image and try to load it on a 48K machine.
        var bytes = [UInt8](repeating: 0, count: 30)
        bytes.append(23); bytes.append(0)
        var ext = [UInt8](repeating: 0, count: 23)
        ext[2] = 4
        bytes.append(contentsOf: ext)

        let spectrum48 = Spectrum()
        spectrum48.processor.machine = spectrum48
        let z48 = spectrum48.processor as! ZilogZ80
        XCTAssertFalse(Z80Loader(z80: z48).load(data: Data(bytes)),
                       "128K image should be rejected by a 48K machine")
    }

    // MARK: - 128K .szx loading

    private func appendDWord(_ a: inout [UInt8], _ v: UInt32) {
        a.append(UInt8(v & 0xff)); a.append(UInt8((v>>8)&0xff))
        a.append(UInt8((v>>16)&0xff)); a.append(UInt8((v>>24)&0xff))
    }
    private func chunk(_ id: String, _ body: [UInt8]) -> [UInt8] {
        var c = Array(id.utf8); appendDWord(&c, UInt32(body.count)); c.append(contentsOf: body); return c
    }

    func testLoad128KSZX() {
        // Header: ZXST, major 1, minor 4, machineId 2 (128K).
        var file: [UInt8] = [0x5A,0x58,0x53,0x54, 1,4,2,0]

        // Z80R with PC = 0xC000.
        var z80r = [UInt8](repeating: 0, count: 37)
        z80r[22] = 0x00; z80r[23] = 0xC0   // PC
        z80r[28] = 1                       // IM 1
        file.append(contentsOf: chunk("Z80R", z80r))

        // RAMP for bank 7 (shadow screen), uncompressed, filled 0x3C.
        var ramp: [UInt8] = [0x00, 0x00, 7]   // flags=0 (uncompressed), pageNo=7
        ramp.append(contentsOf: [UInt8](repeating: 0x3C, count: 0x4000))
        file.append(contentsOf: chunk("RAMP", ramp))

        // SPCR: border 2, 0x7FFD = 0x08 (shadow screen on).
        file.append(contentsOf: chunk("SPCR", [2, 0x08, 0, 0, 0, 0, 0, 0]))

        let ok = SZXLoader(z80: z80).load(data: Data(file))
        XCTAssertTrue(ok, "128K .szx load failed")
        XCTAssertEqual(z80.pc, 0xC000, "PC wrong")
        XCTAssertEqual(spectrum.memory.ramBank(7)![0], 0x3C, "bank 7 not loaded")
        XCTAssertEqual(spectrum.memory.ramBank(7)![0x3FFF], 0x3C, "bank 7 end wrong")
    }
}
