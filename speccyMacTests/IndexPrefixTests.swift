//
//  IndexPrefixTests.swift
//  speccyMacTests
//
//  Verifies DD/FD-prefixed opcodes that were surfaced as unhandled by the
//  emulator's unhandled-instruction logging:
//   - DD/FD 2C : INC IXL/IYL (a documented-undocumented instruction)
//   - DD/FD F8 : RET M preceded by an ineffective index prefix. On real
//                hardware the prefix acts as a NOP and the opcode executes
//                in its normal, unprefixed form.
//

import XCTest
@testable import speccyMac

final class IndexPrefixTests: XCTestCase {

    let spectrum = Spectrum()
    var z80: ZilogZ80 { spectrum.processor as! ZilogZ80 }

    private let base: UInt16 = 0x8000

    override func setUp() {
        super.setUp()
        CPUStateLock.lock.lock()
        spectrum.processor.machine = spectrum
        // F and SP live in shared static storage; reset so prior tests can't
        // pollute these assertions.
        ZilogZ80.regF = 0
        ZilogZ80.sp = 0
    }

    override func tearDown() {
        CPUStateLock.lock.unlock()
        super.tearDown()
    }

    // MARK: - INC IXL (DD 2C)

    func testIncIXLIncrementsLowByte() {
        z80.ixy = 0x1234            // ixyh=0x12, ixyl=0x34
        z80.pc = base
        z80.ddprefix(opcode: 0x2c, first: 0, second: 0)

        XCTAssertEqual(z80.ixy, 0x1235, "INC IXL must increment only the low byte")
        // ddprefix advances PC by the instruction length (DD + opcode = 2).
        XCTAssertEqual(z80.pc, base &+ 2, "INC IXL must advance PC past both bytes")
    }

    func testIncIXLWrapsLowByteWithoutTouchingHighByte() {
        z80.ixy = 0x12ff            // ixyl = 0xff
        z80.pc = base
        z80.ddprefix(opcode: 0x2c, first: 0, second: 0)

        XCTAssertEqual(z80.ixy, 0x1200, "INC IXL must wrap the low byte without carrying into the high byte")
    }

    // MARK: - Ineffective prefix: DD F8 (acts as RET M)

    func testDDF8IsHandledAsIneffectivePrefix() {
        // Opcode stream: DD F8 at `base`.
        spectrum.memory.set(base, byte: 0xdd)
        spectrum.memory.set(base &+ 1, byte: 0xf8)
        z80.pc = base

        z80.ddprefix(opcode: 0xf8, first: 0, second: 0)

        // The prefix is consumed (1 byte) so the main fetch loop re-reads the
        // F8 opcode unprefixed. PC must therefore point at the F8 byte, never
        // the unhandled-opcode default.
        XCTAssertEqual(z80.pc, base &+ 1, "DD prefix before RET M must be consumed as a single NOP-like byte")
    }
}
