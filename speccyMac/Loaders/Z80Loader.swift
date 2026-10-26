//
//  Z80Loader.swift
//  speccyMac
//
//  Created by hippietrail on 20/08/2022.
//

import Foundation

// all z80 files have this header
struct V1Header {
    var a: UInt8 = 0
    var f: UInt8 = 0
    var bc: UInt16 = 0
    var hl: UInt16 = 0
    var pc: UInt16 = 0
    var sp: UInt16 = 0
    var i: UInt8 = 0
    var r: UInt8 = 0
    var flags1: UInt8 = 0
    var de: UInt16 = 0
    var exbc: UInt16 = 0
    var exde: UInt16 = 0
    var exhl: UInt16 = 0
    var exa: UInt8 = 0
    var exf: UInt8 = 0
    var iy: UInt16 = 0
    var ix: UInt16 = 0
    var iff: UInt8 = 0
    var iff2: UInt8 = 0
    var flags2: UInt8 = 0
}

// Extended header that follows the 30-byte v1 header in v2/v3 files.
// The length word at offset 30 distinguishes the versions:
//   23      -> version 2
//   54 / 55 -> version 3
struct ExtendedHeader {
    var length: UInt16 = 0      // additional header length (not counting these 2 bytes)
    var pc: UInt16 = 0          // real PC lives here in v2/v3
    var hardwareMode: UInt8 = 0 // machine type
}

class Z80Loader: GameLoaderProtocol {
    
    let z80: ZilogZ80
    
    required init(z80: ZilogZ80) {
        self.z80 = z80
    }
    
    func load(data: Data) -> Bool {

        let v1HeaderLen: UInt16 = 30
        if data.count < v1HeaderLen {
            print(".z80 file too short")
            return false
        }

        var v1: V1Header = V1Header()
        v1.a = data[0]
        v1.f = data[1]
        v1.bc = UInt16(data[2]) + (UInt16(data[3]) << 8)
        v1.hl = UInt16(data[4]) + (UInt16(data[5]) << 8)
        v1.pc = UInt16(data[6]) + (UInt16(data[7]) << 8)
        v1.sp = UInt16(data[8]) + (UInt16(data[9]) << 8)
        v1.i = data[10]
        v1.r = data[11]
        v1.flags1 = data[12]
        v1.de = UInt16(data[13]) + (UInt16(data[14]) << 8)
        v1.exbc = UInt16(data[15]) + (UInt16(data[16]) << 8)
        v1.exde = UInt16(data[17]) + (UInt16(data[18]) << 8)
        v1.exhl = UInt16(data[19]) + (UInt16(data[20]) << 8)
        v1.exa = data[21]
        v1.exf = data[22]
        v1.iy = UInt16(data[23]) + (UInt16(data[24]) << 8)
        v1.ix = UInt16(data[25]) + (UInt16(data[26]) << 8)
        v1.iff = data[27]
        v1.iff2 = data[28]
        v1.flags2 = data[29]

        // file format quirks: a stored value of 255 must be treated as 1
        // *before* interpreting any of its bits (bit 0 = R high bit,
        // bits 1-3 = border colour, bit 5 = compressed flag).
        if v1.flags1 == 255 { v1.flags1 = 1 }
        v1.r = (v1.r & 0x7f) | (v1.flags1 << 7)

        // Registers common to all versions come from the v1 header.
        loadCommonRegisters(v1)

        if (v1.pc != 0) {
            print(".z80 version 1 file")

            // compressed files should never be longer than compressed, which are 49182 bytes
            if data.count > (48 * 1024) + v1HeaderLen {
                print(" file too long")
                return false
            }

            let isCompressed = v1.flags1 & (1 << 5) != 0
            print("  \(!isCompressed ? "un" : "")compressed data")

            z80.interruptMode = v1.flags2 & 0x03
            z80.machine.output(0xfe, byte: (v1.flags1 >> 1) & 0x07)

            // prepare ram

            let ram = z80.memory.romSize
            let ramBytes = 48 * 1024        // 49152 bytes of RAM in a 48K v1 image
            let fileLen = data.count
            var from: Int = Int(v1HeaderLen)
            var to: Int = 0

            var loop = true
            while loop {
                let left = fileLen - from
                if left <= 0 {
                    break
                }
                // RAM is full - decompression complete
                if to >= ramBytes {
                    break
                }

                let byte = data[from]

                if isCompressed && byte == 0x00 && left >= 4 && data[from + 1] == 0xed
                    && data[from + 2] == 0xed && data[from + 3] == 0x00 {
                    loop = false
                    from += 4
                } else if isCompressed && byte == 0xed && left >= 4 && data[from + 1] == 0xed {
                    let length = data[from + 2]
                    let value = data[from + 3]

                    for _ in 0..<length {
                        if to >= ramBytes {
                            return false        // run would overflow RAM
                        }
                        z80.memory.set(ram + UInt16(to), byte: value)
                        to += 1
                    }
                    from += 4
                } else {
                    z80.memory.set(ram + UInt16(to), byte: byte)

                    from += 1
                    to += 1
                }
            }

            z80.pc = v1.pc

            return true
        } else {
            return loadV2V3(data: data, v1: v1)
        }
    }

    // MARK: - Version 2 / 3

    private func loadV2V3(data: Data, v1: V1Header) -> Bool {
        let v1HeaderLen = 30

        // We need at least the 2-byte extended-header length word.
        if data.count < v1HeaderLen + 2 {
            print(".z80 v2/v3 file too short")
            return false
        }

        var ext = ExtendedHeader()
        ext.length = UInt16(data[v1HeaderLen]) + (UInt16(data[v1HeaderLen + 1]) << 8)

        switch ext.length {
        case 23:
            print(".z80 version 2 file")
        case 54, 55:
            print(".z80 version 3 file")
        default:
            print(".z80 unknown extended header length \(ext.length)")
            return false
        }

        // Extended header body starts right after the length word.
        let extStart = v1HeaderLen + 2
        let extEnd = extStart + Int(ext.length)
        if data.count < extEnd {
            print(".z80 extended header truncated")
            return false
        }

        ext.pc = UInt16(data[extStart]) + (UInt16(data[extStart + 1]) << 8)
        ext.hardwareMode = data[extStart + 2]

        // Only 48K machines are emulated. Reject obvious 128K images so we
        // don't silently load something that won't run correctly.
        //   v2: modes 3+ are 128K;  v3: modes 4+ are 128K.
        let is128K: Bool
        if ext.length == 23 {
            is128K = ext.hardwareMode >= 3
        } else {
            is128K = ext.hardwareMode >= 4
        }
        if is128K {
            print(".z80 128K images are not supported")
            return false
        }

        z80.interruptMode = v1.flags2 & 0x03
        z80.machine.output(0xfe, byte: (v1.flags1 >> 1) & 0x07)

        // Memory page blocks follow the extended header.
        var offset = extEnd

        while offset + 3 <= data.count {
            let blockLen = Int(data[offset]) + (Int(data[offset + 1]) << 8)
            let pageNumber = data[offset + 2]
            offset += 3

            // A length of 0xFFFF means 16384 uncompressed bytes (no RLE).
            let uncompressed = blockLen == 0xFFFF

            // Map the Spectrum page number onto a 48K address. Pages other
            // than these belong to ROM or to 128K banks we don't model.
            let pageBase: UInt16?
            switch pageNumber {
            case 4:  pageBase = 0x8000
            case 5:  pageBase = 0x4000
            case 8:  pageBase = 0xC000
            default: pageBase = nil
            }

            let byteCount = uncompressed ? 0x4000 : blockLen
            if offset + byteCount > data.count {
                print(".z80 page block truncated")
                return false
            }

            if let base = pageBase {
                if uncompressed {
                    for jx in 0..<0x4000 {
                        z80.memory.set(base + UInt16(jx), byte: data[offset + jx])
                    }
                } else {
                    decompressPage(data: data, from: offset, length: blockLen, base: base)
                }
            }

            offset += byteCount
        }

        z80.pc = ext.pc

        return true
    }

    // Decompress a single 16K page block (RLE, no end marker) into RAM
    // starting at `base`. Writes are clamped to the 16K page.
    private func decompressPage(data: Data, from: Int, length: Int, base: UInt16) {
        var src = from
        let end = from + length
        var to = 0

        while src < end && to < 0x4000 {
            let left = end - src
            let byte = data[src]

            if byte == 0xed && left >= 4 && data[src + 1] == 0xed {
                let runLength = Int(data[src + 2])
                let value = data[src + 3]

                for _ in 0..<runLength {
                    if to >= 0x4000 { break }
                    z80.memory.set(base + UInt16(to), byte: value)
                    to += 1
                }
                src += 4
            } else {
                z80.memory.set(base + UInt16(to), byte: byte)
                src += 1
                to += 1
            }
        }
    }

    // MARK: - Shared register setup

    // Load the CPU registers that are identical across all .z80 versions
    // (everything in the 30-byte v1 header except PC, interrupt mode and
    // the border colour, which differ or are handled per-version).
    private func loadCommonRegisters(_ v1: V1Header) {
        z80.i = v1.i

        z80.exhl = v1.exhl
        z80.exde = v1.exde
        z80.exbc = v1.exbc
        z80.exaf = (UInt16(v1.exa) << 8) + UInt16(v1.exf)

        z80.hl = v1.hl
        z80.de = v1.de
        z80.bc = v1.bc
        z80.iy = v1.iy
        z80.ix = v1.ix

        if v1.iff != 0 {
            z80.interrupts = true
            z80.iff1 = 1
            z80.iff2 = 1
        } else {
            z80.interrupts = false
            z80.iff1 = 0
            z80.iff2 = 0
        }

        z80.regR = v1.r

        z80.af = (UInt16(v1.a) << 8) + UInt16(v1.f)
        ZilogZ80.sp = v1.sp
    }
}
