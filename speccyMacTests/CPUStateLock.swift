//
//  CPUStateLock.swift
//  speccyMacTests
//
//  ZilogZ80 stores the F and SP registers in process-global `static` storage
//  (the emulator assumes a single CPU). XCTest runs test classes in parallel
//  workers, so two tests that each drive the CPU/loaders would otherwise race
//  on that shared state. Tests that read those registers take this lock for
//  the duration of the test body to serialise access.
//

import Foundation

enum CPUStateLock {
    static let lock = NSRecursiveLock()

    /// Run `body` while holding the shared CPU-state lock.
    static func withLock(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body()
    }
}
