//
//  accumulatorTests.swift
//  speccyMacTests
//
//  Created by John Ward on 07/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import XCTest
@testable import speccyMac

class AccumulatorTests: XCTestCase {

    var z80 = ZilogZ80(memory: Memory("48.rom"))
    
    override func setUp() {        
        super.setUp()
        
        z80 = ZilogZ80(memory: Memory("48.rom"))
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testCpl() {
        z80.a.value = 100
        z80.a.cpl()
        XCTAssert(z80.a.value == 155, "cpl failed with value \(z80.a.value)")
    }
    
    func testAnd() {
        z80.a.value = 0x08
        z80.a.and(0x01)
        XCTAssert(z80.a.value == 0, "and failed")
        
        z80.a.value = 0xff
        z80.a.and(0x0f)
        XCTAssert(z80.a.value == 0x0f, "and failed")
    }

    func testAddValueNoWrap() {
        z80.a.value = 100
        z80.a.add(50)
        XCTAssert(z80.a.value == 150, "add no wrap failed with value \(z80.a.value)")
    }
    
    func testAddValueWithWrap() {
        z80.a.value = 255
        z80.a.add(5)
        XCTAssert(z80.a.value == 4, "add with wrap failed with value \(z80.a.value)")
    }
    
    func testAddNegative() {
        z80.a.value = 200
        z80.a.add(255)
        XCTAssert(z80.a.value == 199, "add negative failed with value \(z80.a.value)")
    }
    
    func testNeg() {
        z80.a.value = 1
        z80.a.neg()
        XCTAssert(z80.a.value == 0xff, "neg failed")
    }
    
}
