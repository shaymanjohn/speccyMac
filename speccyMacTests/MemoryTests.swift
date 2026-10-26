//
//  memoryTests.swift
//  speccyMacTests
//
//  Created by John Ward on 06/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import XCTest
@testable import speccyMac

class MemoryTests: XCTestCase {

    // Use a full Spectrum so `memory.machine` is wired up. Memory.get/set apply
    // contention for addresses in 0x4000-0x7FFF and force-unwrap `machine`, so a
    // bare Memory (without a machine) crashes on any contended access.
    let spectrum = Spectrum()
    var memory: Memory { spectrum.memory }

    override func setUp() {
        super.setUp()
        CPUStateLock.lock.lock()
    }
    
    override func tearDown() {
        CPUStateLock.lock.unlock()
        super.tearDown()
    }

    func testCantWriteToRom() {
        let a = memory.get(0)
        let b = 255 - a
        memory.set(0, byte: b)
        
        XCTAssert(memory.get(0) != b, "can write to rom")
    }
    
    func testCanWriteToRam() {
        let a = memory.get(16384)
        let b = 255 - a
        memory.set(16384, byte: b)
        
        XCTAssert(memory.get(16384) == b, "cant write to ram")
    }
    
    func testPushAndPop() {
        ZilogZ80.sp = 32768
        
        memory.push(5678)
        let value = memory.pop()
        
        XCTAssert(value == 5678, "pop after push failed, value return \(value)")
    }
    
    func testInc() {
        memory.set(32768, byte: 0xff)
        memory.inc(32768)
        XCTAssert(memory.get(32768) == 0, "memory inc failed")
    }

}
