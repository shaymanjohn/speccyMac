//
//  SZXLoaderTests.swift
//  speccyMacTests
//
//  Verifies the ZX-State (.szx) snapshot loader.
//

import XCTest
import zlib
@testable import speccyMac

class SZXLoaderTests: XCTestCase {

    let spectrum = Spectrum()
    var z80: ZilogZ80 { spectrum.processor as! ZilogZ80 }

    override func setUp() {
        super.setUp()
        // The loader writes the border via z80.machine.output(...); Spectrum
        // only wires processor.machine inside start(), so set it here.
        spectrum.processor.machine = spectrum

        // ZilogZ80 keeps F and SP in static storage shared across the whole
        // test process, so a previous test can leave them dirty. Reset them so
        // assertions see only what this load wrote.
        ZilogZ80.regF = 0
        ZilogZ80.sp = 0
    }

    // MARK: - Builders

    private func appendWord(_ a: inout [UInt8], _ v: UInt16) {
        a.append(UInt8(v & 0xff)); a.append(UInt8(v >> 8))
    }

    private func appendDWord(_ a: inout [UInt8], _ v: UInt32) {
        a.append(UInt8(v & 0xff))
        a.append(UInt8((v >> 8) & 0xff))
        a.append(UInt8((v >> 16) & 0xff))
        a.append(UInt8((v >> 24) & 0xff))
    }

    /// 8-byte ZXST header for a 48K machine.
    private func header48K() -> [UInt8] {
        var h: [UInt8] = [0x5A, 0x58, 0x53, 0x54]   // "ZXST"
        h.append(1)   // major
        h.append(4)   // minor
        h.append(1)   // machineId = 48K
        h.append(0)   // flags
        return h
    }

    /// Wrap a chunk body with its 4-char id and 32-bit little-endian size.
    private func chunk(_ id: String, _ body: [UInt8]) -> [UInt8] {
        var c = Array(id.utf8)
        assert(c.count == 4)
        appendDWord(&c, UInt32(body.count))
        c.append(contentsOf: body)
        return c
    }

    /// A full 37-byte Z80R body with known register values.
    private func z80rBody() -> [UInt8] {
        var b: [UInt8] = []
        appendWord(&b, 0x1234)   // AF
        appendWord(&b, 0x5678)   // BC
        appendWord(&b, 0x9abc)   // DE
        appendWord(&b, 0xdef0)   // HL
        appendWord(&b, 0x1122)   // AF'
        appendWord(&b, 0x3344)   // BC'
        appendWord(&b, 0x5566)   // DE'
        appendWord(&b, 0x7788)   // HL'
        appendWord(&b, 0x99aa)   // IX
        appendWord(&b, 0xbbcc)   // IY
        appendWord(&b, 0x4321)   // SP
        appendWord(&b, 0x8000)   // PC
        b.append(0x07)           // I
        b.append(0x3f)           // R
        b.append(0x01)           // IFF1
        b.append(0x01)           // IFF2
        b.append(0x02)           // IM 2
        appendDWord(&b, 0)       // dwCyclesStart
        b.append(0)              // chHoldIntReqCycles
        b.append(0)              // chFlags
        appendWord(&b, 0)        // wMemPtr
        return b
    }

    /// zlib-compress a page using the system zlib (produces a full zlib stream).
    private func zlibCompress(_ bytes: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: bytes.count + 1024)
        var outLen = uLongf(out.count)
        let rc = bytes.withUnsafeBufferPointer { src in
            compress(&out, &outLen, src.baseAddress, uLong(bytes.count))
        }
        precondition(rc == Z_OK, "test zlib compress failed")
        return Array(out[0..<Int(outLen)])
    }

    // MARK: - Tests

    func testLoadBasicSnapshot() {
        var file = header48K()
        file.append(contentsOf: chunk("Z80R", z80rBody()))

        // Compressed RAM page 5 (-> 0x4000), filled with 0xAB.
        var ramp5: [UInt8] = []
        appendWord(&ramp5, 0x0001)              // wFlags: compressed
        ramp5.append(5)                         // page 5
        ramp5.append(contentsOf: zlibCompress(Array(repeating: 0xAB, count: 0x4000)))
        file.append(contentsOf: chunk("RAMP", ramp5))

        // Uncompressed RAM page 0 (-> 0xC000), filled with 0x5A.
        var ramp0: [UInt8] = []
        appendWord(&ramp0, 0x0000)              // wFlags: not compressed
        ramp0.append(0)                         // page 0
        ramp0.append(contentsOf: Array(repeating: 0x5A, count: 0x4000))
        file.append(contentsOf: chunk("RAMP", ramp0))

        // Border colour 5 via SPCR.
        let spcr: [UInt8] = [5, 0, 0, 0, 0, 0, 0, 0]
        file.append(contentsOf: chunk("SPCR", spcr))

        let ok = SZXLoader(z80: z80).load(data: Data(file))
        XCTAssertTrue(ok, "szx load returned false")

        // Registers
        XCTAssertEqual(z80.af, 0x1234, "AF wrong")
        XCTAssertEqual(z80.bc, 0x5678, "BC wrong")
        XCTAssertEqual(z80.de, 0x9abc, "DE wrong")
        XCTAssertEqual(z80.hl, 0xdef0, "HL wrong")
        XCTAssertEqual(z80.exaf, 0x1122, "AF' wrong")
        XCTAssertEqual(z80.exbc, 0x3344, "BC' wrong")
        XCTAssertEqual(z80.exde, 0x5566, "DE' wrong")
        XCTAssertEqual(z80.exhl, 0x7788, "HL' wrong")
        XCTAssertEqual(z80.ix, 0x99aa, "IX wrong")
        XCTAssertEqual(z80.iy, 0xbbcc, "IY wrong")
        XCTAssertEqual(ZilogZ80.sp, 0x4321, "SP wrong")
        XCTAssertEqual(z80.pc, 0x8000, "PC wrong")
        XCTAssertEqual(z80.i, 0x07, "I wrong")
        XCTAssertEqual(z80.regR, 0x3f, "R wrong")
        XCTAssertEqual(z80.interruptMode, 2, "IM wrong")
        XCTAssertTrue(z80.interrupts, "interrupts should be enabled")

        // Decompressed page 5 at 0x4000.
        XCTAssertEqual(z80.memory.get(0x4000), 0xAB, "page 5 start wrong")
        XCTAssertEqual(z80.memory.get(0x7FFF), 0xAB, "page 5 end wrong")

        // Uncompressed page 0 at 0xC000.
        XCTAssertEqual(z80.memory.get(0xC000), 0x5A, "page 0 start wrong")
        XCTAssertEqual(z80.memory.get(0xFFFF), 0x5A, "page 0 end wrong")

        // Border from SPCR.
        XCTAssertEqual(spectrum.borderColourIndex, 5, "border wrong")
    }

    func testUnknownChunksAreSkipped() {
        var file = header48K()
        // An unknown chunk before the registers should be skipped, not fatal.
        file.append(contentsOf: chunk("CRTR", Array(repeating: 0x00, count: 40)))
        file.append(contentsOf: chunk("ZZZZ", [1, 2, 3, 4, 5]))
        file.append(contentsOf: chunk("Z80R", z80rBody()))

        let ok = SZXLoader(z80: z80).load(data: Data(file))
        XCTAssertTrue(ok, "load should succeed despite unknown chunks")
        XCTAssertEqual(z80.pc, 0x8000, "PC wrong after skipping unknown chunks")
    }

    func testBadMagicRejected() {
        var file = header48K()
        file[0] = 0x00   // corrupt the magic
        file.append(contentsOf: chunk("Z80R", z80rBody()))
        XCTAssertFalse(SZXLoader(z80: z80).load(data: Data(file)), "bad magic should fail")
    }

    func testUnsupportedMachineRejected() {
        var file = header48K()
        file[6] = 2      // machineId = 128K
        file.append(contentsOf: chunk("Z80R", z80rBody()))
        XCTAssertFalse(SZXLoader(z80: z80).load(data: Data(file)), "128K should be rejected")
    }

    func testMissingRegistersRejected() {
        // Header only, no Z80R chunk.
        let file = header48K()
        XCTAssertFalse(SZXLoader(z80: z80).load(data: Data(file)), "missing Z80R should fail")
    }
}
