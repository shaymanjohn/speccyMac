//
//  TapLoader.swift
//  speccyMac
//
//  Parses the .tap tape format and expands it into a pulse-duration list for
//  the TapeDeck. A .tap file is a sequence of blocks, each a 2-byte
//  little-endian length followed by that many bytes. The first byte of a block
//  is the flag (0x00 = header, 0xFF = data); the last is an XOR checksum. All
//  of that is stored verbatim, so we simply emit pulses for every stored byte.
//
//  Blocks are expanded using the standard ROM loader timings. These same
//  timings are the defaults a TZX "standard speed" (0x10) block uses, so this
//  expansion is shared with the future TZX loader.
//

import Foundation

enum TapeTiming {
    // Standard ROM loader pulse lengths, in T-states.
    static let pilotPulse: UInt32 = 2168
    static let sync1: UInt32 = 667
    static let sync2: UInt32 = 735
    static let zeroPulse: UInt32 = 855
    static let onePulse: UInt32 = 1710
    static let headerPilotCount = 8063   // pilot pulses for a header block
    static let dataPilotCount = 3223     // pilot pulses for a data block
    static let pauseTStates: UInt32 = 3_500_000  // ~1s pause between blocks

    // T-states per millisecond (for converting pause fields).
    static let tStatesPerMs: UInt32 = 3500

    /// Append the data bytes of a block as pulses: each byte MSB first, two
    /// pulses per bit, using the supplied zero/one pulse lengths. `usedBits`
    /// limits how many top bits of the final byte are emitted (8 = all).
    static func appendData(_ block: [UInt8],
                           zero: UInt32,
                           one: UInt32,
                           usedBitsInLastByte: Int = 8,
                           to pulses: inout [UInt32]) {
        for (index, byte) in block.enumerated() {
            let bits = (index == block.count - 1) ? usedBitsInLastByte : 8
            var mask: UInt8 = 0x80
            for _ in 0..<bits {
                let pulse = (byte & mask) != 0 ? one : zero
                pulses.append(pulse)
                pulses.append(pulse)
                mask >>= 1
            }
        }
    }

    /// Append a pilot tone of `count` pulses followed by the two sync pulses,
    /// using standard timings.
    static func appendPilotAndSync(pilotCount: Int, to pulses: inout [UInt32]) {
        for _ in 0..<pilotCount {
            pulses.append(pilotPulse)
        }
        pulses.append(sync1)
        pulses.append(sync2)
    }
}

struct TapLoader {

    /// Expand a .tap file's bytes into a pulse-duration list (T-states).
    /// Returns nil if the data is malformed.
    static func pulses(from data: Data) -> [UInt32]? {
        var pulses: [UInt32] = []
        var offset = 0
        let bytes = [UInt8](data)

        while offset + 2 <= bytes.count {
            // Block length (little-endian).
            let length = Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
            offset += 2

            guard length > 0, offset + length <= bytes.count else {
                // Truncated or malformed block.
                return pulses.isEmpty ? nil : pulses
            }

            let block = bytes[offset ..< offset + length]
            offset += length

            appendBlock(Array(block), to: &pulses)
        }

        return pulses.isEmpty ? nil : pulses
    }

    /// Append the pilot + sync + data + pause pulses for one block.
    private static func appendBlock(_ block: [UInt8], to pulses: inout [UInt32]) {
        guard let flag = block.first else { return }

        // Header blocks (flag < 0x80) use a longer pilot tone.
        let pilotCount = flag < 0x80 ? TapeTiming.headerPilotCount
                                     : TapeTiming.dataPilotCount
        TapeTiming.appendPilotAndSync(pilotCount: pilotCount, to: &pulses)
        TapeTiming.appendData(block,
                              zero: TapeTiming.zeroPulse,
                              one: TapeTiming.onePulse,
                              to: &pulses)

        // Pause after the block (a single long pulse).
        pulses.append(TapeTiming.pauseTStates)
    }
}
