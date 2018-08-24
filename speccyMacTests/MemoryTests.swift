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

    let memory = Memory("48.rom")
    
    override func setUp() {
        let _ = ZilogZ80(memory: memory)
        
        super.setUp()
    }
    
    override func tearDown() {
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
        let _ = ZilogZ80(memory: memory)
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
