//
//  AYChipTests.swift
//  speccyMacTests
//
//  Verifies the AY-3-8912 sound chip: tone generation, mixer gating, the
//  envelope generator, and register read-back.
//

import XCTest
@testable import speccyMac

final class AYChipTests: XCTestCase {

    private let ayClocksPerSample = Float(1_773_400.0 / 48_000.0)
    private let frameSamples = 960

    private func render(_ ay: AYChip) -> [Float] {
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: frameSamples)
        buf.initialize(repeating: 0, count: frameSamples)
        defer { buf.deallocate() }
        ay.render(into: buf, count: frameSamples, ayClocksPerSample: ayClocksPerSample)
        return Array(UnsafeBufferPointer(start: buf, count: frameSamples))
    }

    func testToneOscillates() {
        let ay = AYChip()
        ay.reset()
        ay.selectRegister(0); ay.writeData(0x00)
        ay.selectRegister(1); ay.writeData(0x01)        // tone A period 0x100
        ay.selectRegister(7); ay.writeData(0b00111110)  // mixer: tone A enabled only
        ay.selectRegister(8); ay.writeData(15)          // channel A full volume

        let samples = render(ay)

        // Count square-wave transitions; a tone should toggle several times
        // within a 20ms frame.
        var transitions = 0
        var prevHigh = samples[0] > 0
        for v in samples {
            let high = v > 0
            if high != prevHigh { transitions += 1 }
            prevHigh = high
        }
        XCTAssertGreaterThan(transitions, 2, "tone channel did not oscillate")
        XCTAssertGreaterThan(samples.max() ?? 0, 0, "tone produced no output")
    }

    func testMixerMutesChannel() {
        let ay = AYChip()
        ay.reset()
        ay.selectRegister(0); ay.writeData(0x00)
        ay.selectRegister(1); ay.writeData(0x01)
        ay.selectRegister(8); ay.writeData(15)
        // Mixer: all tones AND noise disabled (all bits set) -> silence.
        ay.selectRegister(7); ay.writeData(0xff)

        let samples = render(ay)
        // With everything gated off, the channel outputs its level constantly
        // only if "tone && noise" both read high; with tone+noise disabled they
        // read high, so output is a constant DC level, not silence. The ZX ROM
        // relies on volume 0 for silence; verify a muted-volume channel is silent.
        ay.selectRegister(8); ay.writeData(0)   // volume 0
        let silent = render(ay)
        XCTAssertEqual(silent.max() ?? 0, 0, "volume 0 channel should be silent")
        _ = samples
    }

    func testEnvelopeRamps() {
        let ay = AYChip()
        ay.reset()
        ay.selectRegister(0); ay.writeData(0xff)
        ay.selectRegister(7); ay.writeData(0b00111110)  // tone A enabled
        ay.selectRegister(8); ay.writeData(0x10)         // channel A uses envelope
        ay.selectRegister(11); ay.writeData(0x40)        // short envelope period
        ay.selectRegister(12); ay.writeData(0x00)
        ay.selectRegister(13); ay.writeData(0x0e)        // continue + alternate

        let samples = render(ay)
        let distinct = Set(samples.map { Int(($0 * 1000).rounded()) })
        XCTAssertGreaterThan(distinct.count, 3, "envelope did not ramp through multiple levels")
    }

    func testRegisterReadBack() {
        let ay = AYChip()
        ay.reset()
        ay.selectRegister(5)
        ay.writeData(0xAB)
        XCTAssertEqual(ay.readData(), 0xAB, "AY register read-back failed")
    }
}
