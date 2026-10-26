//
//  AYChip.swift
//  speccyMac
//
//  AY-3-8912 programmable sound generator, as used by the 128K Spectrum.
//  Three square-wave tone channels, a noise generator, a shared envelope
//  generator, and a per-channel mixer. Driven by register writes via the
//  128K's I/O ports (0xFFFD register select, 0xBFFD data write) and rendered
//  into the audio frame buffer each frame.
//
//  The chip is clocked at half the CPU clock: 3.5469 MHz / 2 ≈ 1.7734 MHz.
//

import Foundation

final class AYChip {

    // 16 registers (0-15). Only the low bits of several are significant.
    private var registers = [UInt8](repeating: 0, count: 16)
    private var selectedRegister: Int = 0

    // Tone generators: 12-bit period counters and square-wave output state.
    private var toneCounter = [Int](repeating: 0, count: 3)
    private var toneState   = [Bool](repeating: false, count: 3)

    // Noise generator: period counter, 17-bit LFSR, output bit.
    private var noiseCounter = 0
    private var noiseRNG: UInt32 = 1
    private var noiseState = false

    // Envelope generator.
    private var envCounter = 0
    private var envStep = 0          // 0...15 position in the ramp
    private var envHolding = false
    private var envValue = 0         // current 0...15 envelope amplitude

    // Volume lookup: AY uses a roughly logarithmic DAC. 16 levels (0...1).
    private static let volumeTable: [Float] = {
        var table = [Float](repeating: 0, count: 16)
        // Standard AY/YM approximation: each step ~ +3dB.
        var level: Float = 1.0
        for i in stride(from: 15, through: 1, by: -1) {
            table[i] = level
            level /= 1.4125   // ~ -3dB per step
        }
        table[0] = 0
        return table
    }()

    func reset() {
        for i in 0..<16 { registers[i] = 0 }
        selectedRegister = 0
        for i in 0..<3 { toneCounter[i] = 0; toneState[i] = false }
        noiseCounter = 0
        noiseRNG = 1
        noiseState = false
        envCounter = 0
        envStep = 0
        envHolding = false
        envValue = 0
    }

    // MARK: - Register access (from the 128K I/O ports)

    func selectRegister(_ value: UInt8) {
        selectedRegister = Int(value & 0x0f)
    }

    func writeData(_ value: UInt8) {
        let reg = selectedRegister
        registers[reg] = value
        // Writing the envelope shape (reg 13) restarts the envelope.
        if reg == 13 {
            envStep = 0
            envHolding = false
            updateEnvelopeValue()
        }
    }

    func readData() -> UInt8 {
        return registers[selectedRegister]
    }

    // MARK: - Register helpers

    private func tonePeriod(_ ch: Int) -> Int {
        let lo = Int(registers[ch * 2])
        let hi = Int(registers[ch * 2 + 1] & 0x0f)
        let p = (hi << 8) | lo
        return p == 0 ? 1 : p
    }

    private var noisePeriod: Int {
        let p = Int(registers[6] & 0x1f)
        return p == 0 ? 1 : p
    }

    private var envelopePeriod: Int {
        let p = Int(registers[11]) | (Int(registers[12]) << 8)
        return p == 0 ? 1 : p
    }

    // Channel amplitude register (8/9/10): bit 4 selects envelope mode.
    private func channelLevel(_ ch: Int) -> Float {
        let reg = registers[8 + ch]
        if reg & 0x10 != 0 {
            return AYChip.volumeTable[envValue]
        } else {
            return AYChip.volumeTable[Int(reg & 0x0f)]
        }
    }

    // MARK: - Envelope

    private func updateEnvelopeValue() {
        // Envelope shape bits (reg 13): continue, attack, alternate, hold.
        let shape = registers[13] & 0x0f
        let attack = (shape & 0x04) != 0
        envValue = attack ? envStep : (15 - envStep)
    }

    private func clockEnvelope() {
        if envHolding { return }

        envCounter += 1
        if envCounter < envelopePeriod { return }
        envCounter = 0

        envStep += 1
        if envStep > 15 {
            let shape = registers[13] & 0x0f
            let cont = (shape & 0x08) != 0
            let hold = (shape & 0x01) != 0
            let alternate = (shape & 0x02) != 0

            if !cont {
                // Non-continuing shapes decay once then sit at 0.
                envStep = 15
                envHolding = true
                envValue = 0
                return
            }

            if hold {
                envStep = 15
                envHolding = true
                // On hold, value freezes at the end of the (possibly alternated) ramp.
                let attack = (shape & 0x04) != 0
                envValue = (attack != alternate) ? 15 : 0
                return
            }

            // Continuing, not holding: wrap and optionally alternate direction.
            envStep = 0
            if alternate {
                // Flip the attack direction by toggling bit 2 of the shape's effect.
                registers[13] ^= 0x04
            }
        }
        updateEnvelopeValue()
    }

    // MARK: - Rendering

    /// Render `count` audio samples into `buffer`, advancing the chip by
    /// `ayClocksPerSample` AY clock cycles per sample. The channel outputs are
    /// summed and scaled, then ADDED to the existing buffer contents so the AY
    /// mixes with the beeper.
    func render(into buffer: UnsafeMutablePointer<Float>, count: Int, ayClocksPerSample: Float) {
        var clockAccumulator: Float = 0
        for i in 0..<count {
            // Read the mixer each sample; games update it mid-frame.
            let mixer = registers[7]
            clockAccumulator += ayClocksPerSample
            var cycles = Int(clockAccumulator)
            clockAccumulator -= Float(cycles)

            // Advance the generators by `cycles` AY clocks. Tone/noise counters
            // tick every 16 AY clocks on real hardware; fold that factor into
            // the period comparisons by dividing the elapsed clocks.
            while cycles > 0 {
                let step = min(cycles, 16)
                cycles -= step

                for ch in 0..<3 {
                    toneCounter[ch] += step
                    let period = tonePeriod(ch) * 16
                    if toneCounter[ch] >= period {
                        toneCounter[ch] -= period
                        toneState[ch].toggle()
                    }
                }

                noiseCounter += step
                let nperiod = noisePeriod * 16
                if noiseCounter >= nperiod {
                    noiseCounter -= nperiod
                    // 17-bit LFSR, taps at bits 0 and 3.
                    let bit = (noiseRNG ^ (noiseRNG >> 3)) & 1
                    noiseRNG = (noiseRNG >> 1) | (bit << 16)
                    noiseState = (noiseRNG & 1) != 0
                }

                clockEnvelope()
            }

            // Mix the three channels through the mixer. For each channel, the
            // output is high when both its tone AND noise gates allow it. A set
            // mixer bit DISABLES that source (active-low).
            var level: Float = 0
            for ch in 0..<3 {
                let toneDisabled  = (mixer & (1 << ch)) != 0
                let noiseDisabled = (mixer & (1 << (ch + 3))) != 0
                let tone  = toneDisabled  ? true : toneState[ch]
                let noise = noiseDisabled ? true : noiseState
                if tone && noise {
                    level += channelLevel(ch)
                }
            }

            // Scale: three channels at full volume sum to 3.0. Divide to keep
            // headroom and scale to roughly the beeper's level so the AY is
            // clearly audible when mixed in.
            buffer[i] += (level / 3.0) * 0.5
        }
    }
}
