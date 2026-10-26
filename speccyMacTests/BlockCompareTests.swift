//
//  BlockCompareTests.swift
//  speccyMacTests
//
//  Verifies the ED block-compare instructions CPI (A1), CPD (A9) and
//  CPDR (B9). CPDR was surfaced as an unhandled opcode by the emulator's
//  new unhandled-instruction logging; CPI/CPD are its close relatives.
//

import XCTest
@testable import speccyMac

final class BlockCompareTests: XCTestCase {

    // A 48K Spectrum is enough: these opcodes only touch A, HL, BC, F and RAM.
    let spectrum = Spectrum()
    var z80: ZilogZ80 { spectrum.processor as! ZilogZ80 }

    // RAM scratch area (above the ROM, in the normally-mapped 0x4000 bank).
    private let base: UInt16 = 0x8000

    override func setUp() {
        super.setUp()
        CPUStateLock.lock.lock()
        spectrum.processor.machine = spectrum
        // F and SP live in shared static storage; reset so prior tests can't
        // pollute these assertions.
        ZilogZ80.regF = 0
        ZilogZ80.sp = 0
        for i in 0..<8 { spectrum.memory.set(base + UInt16(i), byte: UInt8(0x11 * (i + 1))) }
        // bytes: 8000=11 8001=22 8002=33 8003=44 8004=55 8005=66 8006=77 8007=88
    }

    override func tearDown() {
        CPUStateLock.lock.unlock()
        super.tearDown()
    }

    private var zSet: Bool { z80.regF & ZilogZ80.zBit != 0 }
    private var pvSet: Bool { z80.regF & ZilogZ80.pvBit != 0 }

    func testCPIAdvancesAndMatches() {
        z80.regA = 0x33
        z80.hl = base            // (HL)=0x11, no match
        z80.bc = 8
        z80.regF = 0
        z80.edprefix(opcode: 0xa1, first: 0, second: 0)   // CPI
        XCTAssertEqual(z80.hl, base + 1, "CPI must increment HL")
        XCTAssertEqual(z80.bc, 7, "CPI must decrement BC")
        XCTAssertFalse(zSet, "0x11 != 0x33, Z must be clear")
        XCTAssertTrue(pvSet, "BC still non-zero, PV must be set")

        z80.regA = 0x22          // now (HL)=0x22 at base+1
        z80.regF = 0
        z80.edprefix(opcode: 0xa1, first: 0, second: 0)   // CPI
        XCTAssertTrue(zSet, "0x22 == 0x22, Z must be set")
        XCTAssertEqual(z80.hl, base + 2, "CPI must increment HL again")
    }

    func testCPDDecrementsAndMatches() {
        z80.regA = 0x55
        z80.hl = base + 4        // (HL)=0x55, match
        z80.bc = 8
        z80.regF = 0
        z80.edprefix(opcode: 0xa9, first: 0, second: 0)   // CPD
        XCTAssertTrue(zSet, "0x55 == 0x55, Z must be set")
        XCTAssertEqual(z80.hl, base + 3, "CPD must decrement HL")
        XCTAssertEqual(z80.bc, 7, "CPD must decrement BC")
    }

    func testCPDRSearchesBackwardToMatch() {
        // Search backward from base+7 for 0x22 (at base+1). Drive CPDR until it
        // terminates the way hardware does: a match (Z set) or BC == 0.
        z80.regA = 0x22
        z80.hl = base + 7
        z80.bc = 8
        z80.regF = 0

        var steps = 0
        repeat {
            z80.edprefix(opcode: 0xb9, first: 0, second: 0)   // CPDR
            steps += 1
        } while !zSet && z80.bc != 0 && steps < 16

        XCTAssertTrue(zSet, "CPDR must stop with Z set on the matching byte 0x22")
        // Matched at base+1; CPD decrements HL after the compare, so HL = base.
        XCTAssertEqual(z80.hl, base, "HL should point one below the match")
        // 7 compares (base+7 down to base+1): BC 8 -> 1.
        XCTAssertEqual(z80.bc, 1, "BC should reflect the bytes scanned")
    }

    func testCPIRSearchesForwardToMatch() {
        // Search forward from base for 0x44 (at base+3). Drive CPIR until a
        // match (Z set) or BC == 0. Covers the CPIR path now that it shares
        // cpBlock with CPI/CPD/CPDR.
        z80.regA = 0x44
        z80.hl = base
        z80.bc = 8
        z80.regF = 0

        var steps = 0
        repeat {
            z80.edprefix(opcode: 0xb1, first: 0, second: 0)   // CPIR
            steps += 1
        } while !zSet && z80.bc != 0 && steps < 16

        XCTAssertTrue(zSet, "CPIR must stop with Z set on the matching byte 0x44")
        // Matched at base+3; CPI increments HL after the compare, so HL = base+4.
        XCTAssertEqual(z80.hl, base + 4, "HL should point one past the match")
        XCTAssertEqual(z80.bc, 4, "BC should reflect the bytes scanned")
    }

    func testCPDRTerminatesWhenBCReachesZero() {
        // No match anywhere; CPDR must stop when BC hits 0 (PV clear).
        z80.regA = 0xEE          // not present in the buffer
        z80.hl = base + 7
        z80.bc = 8
        z80.regF = 0

        var steps = 0
        repeat {
            z80.edprefix(opcode: 0xb9, first: 0, second: 0)
            steps += 1
        } while !zSet && z80.bc != 0 && steps < 32

        XCTAssertEqual(z80.bc, 0, "CPDR must run until BC == 0 when there is no match")
        XCTAssertFalse(pvSet, "PV must be clear once BC reaches 0")
    }
}
