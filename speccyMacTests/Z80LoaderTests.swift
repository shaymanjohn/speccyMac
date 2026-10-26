//
//  Z80LoaderTests.swift
//  speccyMacTests
//
//  Verifies the v2/v3 .z80 snapshot loading added to Z80Loader.
//

import XCTest
@testable import speccyMac

class Z80LoaderTests: XCTestCase {

    // A full Spectrum wires up memory.machine (needed for Memory.set
    // contention and the loader's output(0xfe,...) border write).
    let spectrum = Spectrum()
    var z80: ZilogZ80 { spectrum.processor as! ZilogZ80 }

    override func setUp() {
        super.setUp()
        // Spectrum only wires processor.machine inside start(); the loader
        // writes the border via z80.machine.output(...), so set it here.
        spectrum.processor.machine = spectrum
    }

    // MARK: - Helpers

    /// Little-endian 16-bit append.
    private func appendWord(_ array: inout [UInt8], _ value: UInt16) {
        array.append(UInt8(value & 0xff))
        array.append(UInt8(value >> 8))
    }

    /// Build the 30-byte v1 header shared by all versions. PC is forced to 0
    /// so the loader treats the image as v2/v3 and reads the real PC from the
    /// extended header.
    private func makeV1Header() -> [UInt8] {
        var h = [UInt8](repeating: 0, count: 30)

        h[0] = 0x12                 // A
        h[1] = 0x34                 // F
        h[2] = 0x56; h[3] = 0x78    // BC = 0x7856
        h[4] = 0x9a; h[5] = 0xbc    // HL = 0xbc9a
        h[6] = 0x00; h[7] = 0x00    // PC = 0 -> v2/v3
        h[8] = 0x21; h[9] = 0x43    // SP = 0x4321
        h[10] = 0x07                // I
        h[11] = 0x3f                // R (bit 7 comes from flags1 bit 0)

        // flags1: bit 0 = R high bit (0 here), bits 1-3 = border colour.
        // Border = 5 (cyan) -> bits 1-3 = 0b101 -> value 0b1010 = 0x0a.
        h[12] = 0x0a

        h[13] = 0xde; h[14] = 0xf0  // DE = 0xf0de
        h[15] = 0x11; h[16] = 0x22  // BC' = 0x2211
        h[17] = 0x33; h[18] = 0x44  // DE' = 0x4433
        h[19] = 0x55; h[20] = 0x66  // HL' = 0x6655
        h[21] = 0x77                // A'
        h[22] = 0x88                // F'
        h[23] = 0x99; h[24] = 0xaa  // IY = 0xaa99
        h[25] = 0xbb; h[26] = 0xcc  // IX = 0xccbb
        h[27] = 0x01                // IFF1 (interrupts enabled)
        h[28] = 0x01                // IFF2

        // flags2: bits 0-1 = interrupt mode. IM 2 -> 0x02.
        h[29] = 0x02

        return h
    }

    // MARK: - Tests

    func testLoadVersion2() {
        var bytes = makeV1Header()

        // Extended header: length word = 23 marks a v2 file.
        appendWord(&bytes, 23)

        // 23-byte extended body. Real PC at offset 0-1, hardware mode at 2.
        var ext = [UInt8](repeating: 0, count: 23)
        ext[0] = 0x00; ext[1] = 0x80    // real PC = 0x8000
        ext[2] = 0                      // hardware mode 0 = 48K
        bytes.append(contentsOf: ext)

        // One memory page block for page 5 (maps to 0x4000).
        // Payload is RLE-compressed: a run of 10 x 0xAB, then a literal 0xCD.
        // Encoded run: ED ED 0A AB. Literal: CD.
        let payload: [UInt8] = [0xed, 0xed, 0x0a, 0xab, 0xcd]
        appendWord(&bytes, UInt16(payload.count))   // block length
        bytes.append(5)                             // page number 5 -> 0x4000
        bytes.append(contentsOf: payload)

        let loader = Z80Loader(z80: z80)
        let ok = loader.load(data: Data(bytes))
        XCTAssertTrue(ok, "v2 load returned false")

        // Registers
        XCTAssertEqual(z80.af, 0x1234, "AF wrong")
        XCTAssertEqual(z80.bc, 0x7856, "BC wrong")
        XCTAssertEqual(z80.hl, 0xbc9a, "HL wrong")
        XCTAssertEqual(z80.de, 0xf0de, "DE wrong")
        XCTAssertEqual(z80.ix, 0xccbb, "IX wrong")
        XCTAssertEqual(z80.iy, 0xaa99, "IY wrong")
        XCTAssertEqual(ZilogZ80.sp, 0x4321, "SP wrong")
        XCTAssertEqual(z80.i, 0x07, "I wrong")

        // Shadow registers
        XCTAssertEqual(z80.exbc, 0x2211, "BC' wrong")
        XCTAssertEqual(z80.exde, 0x4433, "DE' wrong")
        XCTAssertEqual(z80.exhl, 0x6655, "HL' wrong")
        XCTAssertEqual(z80.exaf, 0x7788, "AF' wrong")

        // PC comes from the extended header, not the v1 header.
        XCTAssertEqual(z80.pc, 0x8000, "PC not taken from extended header")

        // Interrupt mode from flags2 bits 0-1.
        XCTAssertEqual(z80.interruptMode, 2, "interrupt mode wrong")
        XCTAssertTrue(z80.interrupts, "interrupts should be enabled")
        XCTAssertEqual(z80.iff1, 1, "iff1 wrong")

        // R register: low 7 bits of stored R (0x3f) | (flags1 bit0 << 7) = 0x3f.
        XCTAssertEqual(z80.regR, 0x3f, "R wrong")

        // Border colour written via output(0xfe,...) = (flags1 >> 1) & 7 = 5.
        XCTAssertEqual(spectrum.borderColourIndex, 5, "border colour wrong")

        // Decompressed page 5 contents at 0x4000.
        for offset in 0..<10 {
            XCTAssertEqual(z80.memory.get(0x4000 + UInt16(offset)), 0xab,
                           "RLE run byte \(offset) wrong")
        }
        XCTAssertEqual(z80.memory.get(0x4000 + 10), 0xcd, "literal byte wrong")
    }

    func testLoadVersion3() {
        var bytes = makeV1Header()

        // Extended header length 54 marks a v3 file.
        appendWord(&bytes, 54)
        var ext = [UInt8](repeating: 0, count: 54)
        ext[0] = 0x00; ext[1] = 0xc0    // real PC = 0xc000
        ext[2] = 0                      // hardware mode 0 = 48K
        bytes.append(contentsOf: ext)

        // Uncompressed page block for page 8 (maps to 0xC000): length 0xFFFF.
        appendWord(&bytes, 0xFFFF)
        bytes.append(8)
        bytes.append(contentsOf: [UInt8](repeating: 0x5a, count: 0x4000))

        let loader = Z80Loader(z80: z80)
        let ok = loader.load(data: Data(bytes))
        XCTAssertTrue(ok, "v3 load returned false")

        XCTAssertEqual(z80.pc, 0xc000, "PC not taken from v3 extended header")
        XCTAssertEqual(z80.memory.get(0xC000), 0x5a, "uncompressed page start wrong")
        XCTAssertEqual(z80.memory.get(0xFFFF), 0x5a, "uncompressed page end wrong")
    }

    func test128KImageRejected() {
        var bytes = makeV1Header()

        // v2 header but hardware mode 3 => 128K, which is unsupported.
        appendWord(&bytes, 23)
        var ext = [UInt8](repeating: 0, count: 23)
        ext[0] = 0x00; ext[1] = 0x80
        ext[2] = 3                      // 128K
        bytes.append(contentsOf: ext)

        let loader = Z80Loader(z80: z80)
        XCTAssertFalse(loader.load(data: Data(bytes)), "128K image should be rejected")
    }
}
