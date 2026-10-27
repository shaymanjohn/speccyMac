//
//  BlockIOTests.swift
//  speccyMacTests
//
//  Covers the Z80 block input/output instructions that were surfaced as
//  unhandled opcodes:
//    INI  (ED A2), IND  (ED AA), INIR (ED B2), INDR (ED BA)
//    OUTI (ED A3), OUTD (ED AB), OTIR (ED B3), OTDR (ED BB)
//
//  The ULA's output() can't be read back, so the OUT tests verify the
//  architectural side effects (B, HL, flags, repeat). The IN tests also check
//  the byte stored at (HL): an unused port returns 0xFF on this machine.
//

import XCTest
@testable import speccyMac

final class BlockIOTests: XCTestCase {

    let spectrum = Spectrum()
    var z80: ZilogZ80 { spectrum.processor as! ZilogZ80 }

    private let base: UInt16 = 0x8000
    // A port whose low byte is not 0xFE/0x1F/0xFF, so input() returns 0xFF.
    private let unusedPortLow: UInt8 = 0x33

    override func setUp() {
        super.setUp()
        CPUStateLock.lock.lock()
        spectrum.processor.machine = spectrum
        ZilogZ80.regF = 0
        ZilogZ80.sp = 0
    }

    override func tearDown() {
        CPUStateLock.lock.unlock()
        super.tearDown()
    }

    private var zSet: Bool { z80.regF & ZilogZ80.zBit != 0 }
    private var nSet: Bool { z80.regF & ZilogZ80.nBit != 0 }

    // MARK: - OUTI / OUTD

    func testOUTIDecrementsBAndAdvancesHL() {
        z80.regB = 0x05
        z80.regC = unusedPortLow
        z80.hl = base
        spectrum.memory.set(base, byte: 0x3C)
        z80.pc = 0x9000

        z80.edprefix(opcode: 0xa3, first: 0, second: 0)   // OUTI

        XCTAssertEqual(z80.regB, 0x04, "OUTI must decrement B")
        XCTAssertEqual(z80.hl, base &+ 1, "OUTI must increment HL")
        XCTAssertFalse(zSet, "B is 4, Z must be clear")
        XCTAssertFalse(nSet, "N mirrors bit 7 of the data (0x3C); bit 7 is 0 so N must be clear")
    }

    func testOUTDDecrementsHL() {
        z80.regB = 0x02
        z80.regC = unusedPortLow
        z80.hl = base
        spectrum.memory.set(base, byte: 0x00)
        z80.pc = 0x9000

        z80.edprefix(opcode: 0xab, first: 0, second: 0)   // OUTD

        XCTAssertEqual(z80.regB, 0x01, "OUTD must decrement B")
        XCTAssertEqual(z80.hl, base &- 1, "OUTD must decrement HL")
    }

    func testOUTISetsZeroWhenBReachesZero() {
        z80.regB = 0x01
        z80.regC = unusedPortLow
        z80.hl = base
        spectrum.memory.set(base, byte: 0x10)
        z80.pc = 0x9000

        z80.edprefix(opcode: 0xa3, first: 0, second: 0)   // OUTI

        XCTAssertEqual(z80.regB, 0x00, "B must reach 0")
        XCTAssertTrue(zSet, "B == 0, Z must be set")
    }

    func testOTIRRepeatsUntilBIsZero() {
        z80.regB = 0x04
        z80.regC = unusedPortLow
        z80.hl = base
        for i in 0..<4 { spectrum.memory.set(base + UInt16(i), byte: UInt8(i)) }
        let startPC: UInt16 = 0x9000
        z80.pc = startPC

        // OTIR backs PC up by 2 each iteration until B == 0.
        var guardCount = 0
        repeat {
            z80.edprefix(opcode: 0xb3, first: 0, second: 0)   // OTIR
            guardCount += 1
            XCTAssert(guardCount < 100, "OTIR did not terminate")
        } while z80.regB != 0

        XCTAssertEqual(z80.regB, 0x00, "OTIR must run until B == 0")
        XCTAssertEqual(z80.hl, base &+ 4, "OTIR must advance HL by the block length")
    }

    // MARK: - INI / IND / INIR

    func testINIStoresPortByteAndAdvances() {
        z80.regB = 0x03
        z80.regC = unusedPortLow
        z80.hl = base
        spectrum.memory.set(base, byte: 0x00)
        z80.pc = 0x9000

        z80.edprefix(opcode: 0xa2, first: 0, second: 0)   // INI

        XCTAssertEqual(spectrum.memory.get(base), 0xFF, "INI must store the value read from the port")
        XCTAssertEqual(z80.regB, 0x02, "INI must decrement B")
        XCTAssertEqual(z80.hl, base &+ 1, "INI must increment HL")
        XCTAssertTrue(nSet, "data read 0xFF has bit 7 set, so N must be set")
    }

    func testINDDecrementsHL() {
        z80.regB = 0x02
        z80.regC = unusedPortLow
        z80.hl = base
        z80.pc = 0x9000

        z80.edprefix(opcode: 0xaa, first: 0, second: 0)   // IND

        XCTAssertEqual(z80.regB, 0x01, "IND must decrement B")
        XCTAssertEqual(z80.hl, base &- 1, "IND must decrement HL")
    }

    func testINIRFillsBlockAndTerminates() {
        z80.regB = 0x03
        z80.regC = unusedPortLow
        z80.hl = base
        for i in 0..<3 { spectrum.memory.set(base + UInt16(i), byte: 0x00) }
        z80.pc = 0x9000

        var guardCount = 0
        repeat {
            z80.edprefix(opcode: 0xb2, first: 0, second: 0)   // INIR
            guardCount += 1
            XCTAssert(guardCount < 100, "INIR did not terminate")
        } while z80.regB != 0

        XCTAssertEqual(z80.regB, 0x00, "INIR must run until B == 0")
        XCTAssertEqual(z80.hl, base &+ 3, "INIR must advance HL by the block length")
        for i in 0..<3 {
            XCTAssertEqual(spectrum.memory.get(base + UInt16(i)), 0xFF,
                           "INIR must store the port value into each cell")
        }
    }
}
