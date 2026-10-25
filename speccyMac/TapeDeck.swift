//
//  TapeDeck.swift
//  speccyMac
//
//  Real-time tape playback engine. A tape is represented as a list of pulse
//  durations (in Z80 T-states); the EAR level alternates on each pulse. The
//  emulation thread advances the deck by the T-states consumed per instruction
//  and reads `currentLevel`, which is injected into the ULA's EAR bit. The UI
//  thread starts/stops playback and loads tapes.
//
//  This engine is format-agnostic: .tap and (later) .tzx loaders both expand
//  their blocks into the same pulse-duration list.
//

import Foundation

final class TapeDeck {

    // Guards the fields shared between the UI thread (play/stop/load) and the
    // emulation thread (advance/currentLevel). Playback is a simple cursor so
    // the critical sections are tiny.
    private let lock = NSLock()

    // Pulse durations in T-states. The level starts low and flips after each
    // pulse elapses.
    private var pulses: [UInt32] = []
    private var pulseIndex = 0
    private var remaining: UInt32 = 0
    private var level = false
    private var playing = false

    // Lock-free gate for the emulator hot path. Mirrors `playing`; a plain
    // Bool read is a benign race for a start/stop signal (worst case a one-
    // instruction lag), letting tick() avoid taking the lock when idle.
    private(set) var isActive = false

    // When true, long pulses (inter-block pauses) are shortened so fast loading
    // doesn't waste emulated seconds idling between blocks. Real data/pilot/sync
    // pulses are only a few thousand T-states, far below the threshold, so they
    // are never affected. Set by the machine when fast load is enabled.
    var clampLongPulses = false
    private let longPulseThreshold: UInt32 = 500_000   // pauses are ~3.5M
    private let clampedPauseLength: UInt32 = 200_000    // ~57ms

    /// Whether a tape is loaded and currently playing.
    var isPlaying: Bool {
        lock.lock(); defer { lock.unlock() }
        return playing
    }

    /// Whether any tape data is loaded.
    var hasTape: Bool {
        lock.lock(); defer { lock.unlock() }
        return !pulses.isEmpty
    }

    /// Current EAR input level (true = high). Read on the emulation thread.
    var currentLevel: Bool {
        lock.lock(); defer { lock.unlock() }
        return level
    }

    // MARK: - Loading / transport

    /// Load a new pulse list (from a .tap/.tzx loader). Stops any current play.
    func load(pulses: [UInt32]) {
        lock.lock()
        self.pulses = pulses
        pulseIndex = 0
        remaining = pulses.first ?? 0
        level = false
        playing = false
        isActive = false
        lock.unlock()
    }

    /// Start playback from the current position.
    func play() {
        lock.lock()
        if !pulses.isEmpty {
            playing = true
            isActive = true
        }
        lock.unlock()
    }

    /// Pause playback (position is retained).
    func stop() {
        lock.lock()
        playing = false
        isActive = false
        lock.unlock()
    }

    /// Rewind to the start of the tape.
    func rewind() {
        lock.lock()
        pulseIndex = 0
        remaining = pulses.first ?? 0
        level = false
        playing = false
        isActive = false
        lock.unlock()
    }

    // MARK: - Playback (emulation thread)

    /// Advance the tape by `tStates`. When a pulse elapses, the level flips and
    /// we move to the next pulse. At the end of the tape, playback stops.
    func advance(_ tStates: UInt32) {
        lock.lock()
        defer { lock.unlock() }

        guard playing else { return }

        var t = tStates
        while t > 0 {
            if pulseIndex >= pulses.count {
                // Reached the end of the tape.
                playing = false
                isActive = false
                return
            }

            if t < remaining {
                remaining -= t
                return
            }

            // Current pulse elapses; consume it, flip level, move to next.
            t -= remaining
            level.toggle()
            pulseIndex += 1
            if pulseIndex < pulses.count {
                var next = pulses[pulseIndex]
                if clampLongPulses && next > longPulseThreshold {
                    next = clampedPauseLength
                }
                remaining = next
            } else {
                remaining = 0
            }
        }
    }
}
