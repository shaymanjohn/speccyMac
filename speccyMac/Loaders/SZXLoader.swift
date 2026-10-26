//
//  SZXLoader.swift
//  speccyMac
//
//  Loads ZX-State (.szx) snapshots - the modern chunked snapshot format used
//  by Spectaculator, Fuse and others. Spec: https://www.spectaculator.com/docs/zx-state/
//
//  Unlike .z80/.sna (fixed-offset headers), an .szx file is an 8-byte header
//  followed by a sequence of length-prefixed chunks. Each chunk has a 4-char
//  ASCII id and a 32-bit little-endian size, so unknown chunks can be skipped.
//  This loader handles the chunks needed for a 48K machine: Z80R (registers),
//  RAMP (16K RAM pages, optionally zlib-compressed) and SPCR (ULA/border).
//

import Foundation
import zlib   // system zlib on Apple platforms - provides uncompress()

class SZXLoader: GameLoaderProtocol {

    let z80: ZilogZ80

    required init(z80: ZilogZ80) {
        self.z80 = z80
    }

    // Machine ids from the spec (only the ones we care about here).
    private enum MachineID {
        static let zx16k: UInt8 = 0
        static let zx48k: UInt8 = 1
    }

    func load(data: Data) -> Bool {
        // --- File header (8 bytes) ---
        // DWORD magic "ZXST", BYTE major, BYTE minor, BYTE machineId, BYTE flags.
        if data.count < 8 {
            print(".szx file too short")
            return false
        }

        if data[0] != 0x5A || data[1] != 0x58 || data[2] != 0x53 || data[3] != 0x54 {
            print(".szx bad magic (expected ZXST)")
            return false
        }

        let machineId = data[6]
        if machineId != MachineID.zx16k && machineId != MachineID.zx48k {
            print(".szx only 16K/48K machines are supported (machineId=\(machineId))")
            return false
        }

        // --- Walk the chunks ---
        var offset = 8
        var sawRegisters = false

        while offset + 8 <= data.count {
            // Chunk id (4 ASCII bytes) + 32-bit little-endian size.
            let id = chunkID(data, offset)
            let size = Int(readDWord(data, offset + 4))
            let bodyStart = offset + 8

            if bodyStart + size > data.count {
                print(".szx chunk \(id) truncated")
                return false
            }

            switch id {
            case "Z80R":
                if !loadZ80Regs(data, at: bodyStart, size: size) { return false }
                sawRegisters = true
            case "RAMP":
                if !loadRamPage(data, at: bodyStart, size: size) { return false }
            case "SPCR":
                loadSpecRegs(data, at: bodyStart, size: size)
            default:
                // Unknown / unneeded chunk - skip it. This is what keeps the
                // format forward compatible.
                break
            }

            offset = bodyStart + size
        }

        if !sawRegisters {
            print(".szx missing Z80R register chunk")
            return false
        }

        return true
    }

    // MARK: - Chunk handlers

    // ZXSTZ80REGS: AF,BC,DE,HL, AF',BC',DE',HL', IX,IY,SP,PC (words), then
    // I, R, IFF1, IFF2, IM (bytes), dwCyclesStart, chHoldIntReqCycles,
    // chFlags, wMemPtr. We only need the registers and interrupt state.
    private func loadZ80Regs(_ data: Data, at base: Int, size: Int) -> Bool {
        // Need at least up to IM (offset 25) to be useful.
        if size < 26 {
            print(".szx Z80R chunk too small")
            return false
        }

        let af  = readWord(data, base + 0)
        let bc  = readWord(data, base + 2)
        let de  = readWord(data, base + 4)
        let hl  = readWord(data, base + 6)
        let af1 = readWord(data, base + 8)
        let bc1 = readWord(data, base + 10)
        let de1 = readWord(data, base + 12)
        let hl1 = readWord(data, base + 14)
        let ix  = readWord(data, base + 16)
        let iy  = readWord(data, base + 18)
        let sp  = readWord(data, base + 20)
        let pc  = readWord(data, base + 22)
        let i    = data[base + 24]
        let r    = data[base + 25]
        let iff1 = size > 26 ? data[base + 26] : 0
        let iff2 = size > 27 ? data[base + 27] : 0
        let im   = size > 28 ? data[base + 28] : 1

        // SZX stores each pair as a 16-bit word: high byte is the first
        // register (A, B, D, H...), low byte the second (F, C, E, L...).
        // The emulator's af/bc/... setters already treat the word that way.
        z80.af = af
        z80.bc = bc
        z80.de = de
        z80.hl = hl
        z80.exaf = af1
        z80.exbc = bc1
        z80.exde = de1
        z80.exhl = hl1
        z80.ix = ix
        z80.iy = iy
        ZilogZ80.sp = sp
        z80.pc = pc

        z80.i = i
        z80.regR = r

        z80.iff1 = iff1 != 0 ? 1 : 0
        z80.iff2 = iff2 != 0 ? 1 : 0
        z80.interrupts = iff1 != 0
        z80.interruptMode = im & 0x03

        return true
    }

    // ZXSTRAMPAGE: WORD wFlags (bit0 = zlib compressed), BYTE chPageNo,
    // then the (optionally compressed) 16K page data.
    private func loadRamPage(_ data: Data, at base: Int, size: Int) -> Bool {
        if size < 3 {
            print(".szx RAMP chunk too small")
            return false
        }

        let flags = readWord(data, base)
        let pageNo = data[base + 2]
        let compressed = (flags & 0x0001) != 0

        // Map the 48K pages onto Spectrum addresses. Other pages belong to
        // ROM or 128K banks we don't model, so skip them.
        let pageBase: UInt16
        switch pageNo {
        case 5: pageBase = 0x4000
        case 2: pageBase = 0x8000
        case 0: pageBase = 0xC000
        default: return true   // ignore non-48K pages, not an error
        }

        let payloadStart = base + 3
        let payloadLen = size - 3

        let pageBytes: [UInt8]
        if compressed {
            guard let inflated = inflate(data, at: payloadStart,
                                         length: payloadLen, expected: 0x4000) else {
                print(".szx failed to inflate RAM page \(pageNo)")
                return false
            }
            pageBytes = inflated
        } else {
            if payloadLen < 0x4000 {
                print(".szx uncompressed RAM page \(pageNo) too small")
                return false
            }
            pageBytes = Array(data[payloadStart..<payloadStart + 0x4000])
        }

        for jx in 0..<0x4000 {
            z80.memory.set(pageBase + UInt16(jx), byte: pageBytes[jx])
        }

        return true
    }

    // ZXSTSPECREGS: BYTE chBorder, chPaging, chPaging2, chFe, 4 reserved.
    private func loadSpecRegs(_ data: Data, at base: Int, size: Int) {
        guard size >= 1 else { return }
        let border = data[base] & 0x07
        z80.machine.output(0xfe, byte: border)
    }

    // MARK: - Reading helpers

    private func chunkID(_ data: Data, _ offset: Int) -> String {
        let bytes = (0..<4).map { data[offset + $0] }
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private func readWord(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func readDWord(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    // Inflate a zlib stream (SZX uses full zlib streams, not raw DEFLATE) using
    // the system zlib's uncompress(). `expected` is the known decompressed size.
    private func inflate(_ data: Data, at start: Int, length: Int, expected: Int) -> [UInt8]? {
        let input = Array(data[start..<start + length])
        var output = [UInt8](repeating: 0, count: expected)
        var outLen = uLongf(expected)

        let rc = input.withUnsafeBufferPointer { src in
            uncompress(&output, &outLen, src.baseAddress, uLong(length))
        }

        if rc != Z_OK || Int(outLen) != expected {
            print(".szx inflate failed (rc=\(rc), produced \(outLen) of \(expected))")
            return nil
        }
        return output
    }
}
