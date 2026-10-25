//
//  TzxLoader.swift
//  speccyMac
//
//  Parses the .tzx tape format and expands it into a pulse-duration list for
//  the TapeDeck, reusing the shared TapeTiming expansion helpers. A TZX file is
//  a 10-byte header ("ZXTape!" + 0x1A + version) followed by blocks, each
//  introduced by a one-byte ID.
//
//  Supported blocks: 0x10 standard data, 0x11 turbo data, 0x12 pure tone,
//  0x13 pulse sequence, 0x14 pure data, 0x20 pause. Metadata/other blocks with
//  a known length field are skipped. Unknown blocks abort parsing.
//

import Foundation

struct TzxLoader {

    /// Expand a .tzx file's bytes into a pulse-duration list (T-states).
    /// Returns nil if the header is invalid or an unknown block is hit before
    /// any pulses are produced.
    // swiftlint:disable:next cyclomatic_complexity
    static func pulses(from data: Data) -> [UInt32]? {
        let bytes = [UInt8](data)

        // Header: "ZXTape!" 0x1A, then major/minor version bytes.
        let magic: [UInt8] = Array("ZXTape!".utf8) + [0x1A]
        guard bytes.count >= 10, Array(bytes[0..<8]) == magic else {
            print("TZX: invalid header (expected \"ZXTape!\" signature).")
            return nil
        }

        var offset = 10
        var pulses: [UInt32] = []

        // Loop state (0x24/0x25): byte offset to jump back to, and reps left.
        var loopReturnOffset = 0
        var loopRemaining = 0

        while offset < bytes.count {
            let id = bytes[offset]
            offset += 1

            let ok: Bool
            switch id {
            case 0x10: ok = parseStandard(bytes, &offset, &pulses)
            case 0x11: ok = parseTurbo(bytes, &offset, &pulses)
            case 0x12: ok = parsePureTone(bytes, &offset, &pulses)
            case 0x13: ok = parsePulseSequence(bytes, &offset, &pulses)
            case 0x14: ok = parsePureData(bytes, &offset, &pulses)
            case 0x20: ok = parsePause(bytes, &offset, &pulses)

            case 0x24:   // Loop start: WORD repetitions
                if offset + 2 <= bytes.count {
                    let reps = Int(word(bytes, offset))
                    offset += 2
                    loopRemaining = max(0, reps - 1)
                    loopReturnOffset = offset
                    ok = true
                } else { ok = false }

            case 0x25:   // Loop end: jump back until reps exhausted
                if loopRemaining > 0 {
                    loopRemaining -= 1
                    offset = loopReturnOffset
                }
                ok = true

            case 0x21: ok = skip(bytes, &offset, lengthBytes: 1, extra: 0)   // Group start (name)
            case 0x22: ok = true                                            // Group end (no body)
            case 0x2A: ok = skipFixed(bytes, &offset, count: 4)             // Stop tape if 48K (DWORD)
            case 0x30: ok = skip(bytes, &offset, lengthBytes: 1, extra: 0)   // Text description
            case 0x31: ok = skipMessage(bytes, &offset)                      // Message (BYTE time + text)
            case 0x32: ok = skip(bytes, &offset, lengthBytes: 2, extra: 0)   // Archive info
            case 0x33: ok = skipHardware(bytes, &offset)                     // Hardware type
            case 0x34: ok = skipFixed(bytes, &offset, count: 8)             // Emulation info
            case 0x35: ok = skipCustom(bytes, &offset)                       // Custom info
            case 0x5A: ok = skipFixed(bytes, &offset, count: 9)             // Glue block

            default:
                // Unknown block: we can't know its length, so stop here.
                print(String(format: "TZX: unhandled block ID 0x%02X at offset %d — " +
                             "stopping after %d pulses (%d bytes parsed).",
                             id, offset - 1, pulses.count, offset - 1))
                return fallback(pulses)
            }

            if !ok {
                print(String(format: "TZX: truncated/malformed block ID 0x%02X at offset %d — " +
                             "stopping after %d pulses.", id, offset - 1, pulses.count))
                return fallback(pulses)
            }
        }

        return pulses.isEmpty ? nil : pulses
    }

    private static func fallback(_ pulses: [UInt32]) -> [UInt32]? {
        // Return whatever we managed to expand (nil if nothing).
        pulses.isEmpty ? nil : pulses
    }

    // MARK: - Little-endian readers

    private static func word(_ b: [UInt8], _ o: Int) -> UInt32 {
        UInt32(b[o]) | (UInt32(b[o + 1]) << 8)
    }

    private static func triple(_ b: [UInt8], _ o: Int) -> Int {
        Int(b[o]) | (Int(b[o + 1]) << 8) | (Int(b[o + 2]) << 16)
    }

    // MARK: - Block parsers (return false on truncation)

    /// 0x10: WORD pause(ms), WORD dataLength, data[].
    private static func parseStandard(_ b: [UInt8], _ o: inout Int, _ pulses: inout [UInt32]) -> Bool {
        guard o + 4 <= b.count else { return false }
        let pauseMs = word(b, o)
        let length = Int(word(b, o + 2))
        o += 4
        guard o + length <= b.count, length > 0 else { return false }
        let block = Array(b[o ..< o + length])
        o += length

        let flag = block[0]
        let pilotCount = flag < 0x80 ? TapeTiming.headerPilotCount
                                     : TapeTiming.dataPilotCount
        TapeTiming.appendPilotAndSync(pilotCount: pilotCount, to: &pulses)
        TapeTiming.appendData(block, zero: TapeTiming.zeroPulse,
                              one: TapeTiming.onePulse, to: &pulses)
        appendPause(ms: pauseMs, to: &pulses)
        return true
    }

    /// 0x11: pilot, sync1, sync2, zero, one (WORDs), pilotLen (WORD),
    /// usedBits (BYTE), pause (WORD), dataLength (3 bytes), data[].
    private static func parseTurbo(_ b: [UInt8], _ o: inout Int, _ pulses: inout [UInt32]) -> Bool {
        guard o + 18 <= b.count else { return false }
        let pilot = word(b, o)
        let sync1 = word(b, o + 2)
        let sync2 = word(b, o + 4)
        let zero = word(b, o + 6)
        let one = word(b, o + 8)
        let pilotLen = Int(word(b, o + 10))
        let usedBits = Int(b[o + 12])
        let pauseMs = word(b, o + 13)
        let length = triple(b, o + 15)
        o += 18
        guard o + length <= b.count, length > 0 else { return false }
        let block = Array(b[o ..< o + length])
        o += length

        for _ in 0..<pilotLen { pulses.append(pilot) }
        pulses.append(sync1)
        pulses.append(sync2)
        TapeTiming.appendData(block, zero: zero, one: one,
                              usedBitsInLastByte: usedBits == 0 ? 8 : usedBits,
                              to: &pulses)
        appendPause(ms: pauseMs, to: &pulses)
        return true
    }

    /// 0x12: WORD pulseLength, WORD pulseCount.
    private static func parsePureTone(_ b: [UInt8], _ o: inout Int, _ pulses: inout [UInt32]) -> Bool {
        guard o + 4 <= b.count else { return false }
        let pulseLength = word(b, o)
        let count = Int(word(b, o + 2))
        o += 4
        for _ in 0..<count { pulses.append(pulseLength) }
        return true
    }

    /// 0x13: BYTE count, then count WORDs of pulse lengths.
    private static func parsePulseSequence(_ b: [UInt8], _ o: inout Int, _ pulses: inout [UInt32]) -> Bool {
        guard o + 1 <= b.count else { return false }
        let count = Int(b[o]); o += 1
        guard o + count * 2 <= b.count else { return false }
        for _ in 0..<count {
            pulses.append(word(b, o)); o += 2
        }
        return true
    }

    /// 0x14: WORD zero, WORD one, BYTE usedBits, WORD pause, 3-byte length, data[].
    private static func parsePureData(_ b: [UInt8], _ o: inout Int, _ pulses: inout [UInt32]) -> Bool {
        guard o + 10 <= b.count else { return false }
        let zero = word(b, o)
        let one = word(b, o + 2)
        let usedBits = Int(b[o + 4])
        let pauseMs = word(b, o + 5)
        let length = triple(b, o + 7)
        o += 10
        guard o + length <= b.count, length > 0 else { return false }
        let block = Array(b[o ..< o + length])
        o += length

        TapeTiming.appendData(block, zero: zero, one: one,
                              usedBitsInLastByte: usedBits == 0 ? 8 : usedBits,
                              to: &pulses)
        appendPause(ms: pauseMs, to: &pulses)
        return true
    }

    /// 0x20: WORD pause(ms). 0 means "stop the tape"; we just emit the pause.
    private static func parsePause(_ b: [UInt8], _ o: inout Int, _ pulses: inout [UInt32]) -> Bool {
        guard o + 2 <= b.count else { return false }
        let pauseMs = word(b, o); o += 2
        appendPause(ms: pauseMs, to: &pulses)
        return true
    }

    // MARK: - Skipping metadata blocks

    private static func skip(_ b: [UInt8], _ o: inout Int, lengthBytes: Int, extra: Int) -> Bool {
        guard o + lengthBytes <= b.count else { return false }
        let length: Int
        if lengthBytes == 1 {
            length = Int(b[o])
        } else {
            length = Int(word(b, o))
        }
        o += lengthBytes + length + extra
        return o <= b.count
    }

    private static func skipHardware(_ b: [UInt8], _ o: inout Int) -> Bool {
        guard o + 1 <= b.count else { return false }
        let n = Int(b[o]); o += 1
        o += n * 3
        return o <= b.count
    }

    /// 0x31 Message: BYTE display-time, BYTE length, then `length` text bytes.
    private static func skipMessage(_ b: [UInt8], _ o: inout Int) -> Bool {
        guard o + 2 <= b.count else { return false }
        let length = Int(b[o + 1])
        o += 2 + length
        return o <= b.count
    }

    /// Advance past a fixed-size block body.
    private static func skipFixed(_ b: [UInt8], _ o: inout Int, count: Int) -> Bool {
        o += count
        return o <= b.count
    }

    /// 0x35 Custom info: 16-byte identifier + DWORD length + data.
    private static func skipCustom(_ b: [UInt8], _ o: inout Int) -> Bool {
        guard o + 20 <= b.count else { return false }
        let length = Int(word(b, o + 16)) | (Int(word(b, o + 18)) << 16)
        o += 20 + length
        return o <= b.count
    }

    // MARK: - Helpers

    private static func appendPause(ms: UInt32, to pulses: inout [UInt32]) {
        guard ms > 0 else { return }
        pulses.append(ms * TapeTiming.tStatesPerMs)
    }
}
