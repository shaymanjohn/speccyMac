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
        z80.regA = 100
        z80.aluCpl()
        XCTAssert(z80.regA == 155, "cpl failed with value \(z80.regA)")
    }
    
    func testAnd() {
        z80.regA = 0x08
        z80.aluAnd(0x01)
        XCTAssert(z80.regA == 0, "and failed")
        
        z80.regA = 0xff
        z80.aluAnd(0x0f)
        XCTAssert(z80.regA == 0x0f, "and failed")
    }

    func testAddValueNoWrap() {
        z80.regA = 100
        z80.aluAdd(50)
        XCTAssert(z80.regA == 150, "add no wrap failed with value \(z80.regA)")
    }
    
    func testAddValueWithWrap() {
        z80.regA = 255
        z80.aluAdd(5)
        XCTAssert(z80.regA == 4, "add with wrap failed with value \(z80.regA)")
    }
    
    func testAddNegative() {
        z80.regA = 200
        z80.aluAdd(255)
        XCTAssert(z80.regA == 199, "add negative failed with value \(z80.regA)")
    }
    
    func testNeg() {
        z80.regA = 1
        z80.aluNeg()
        XCTAssert(z80.regA == 0xff, "neg failed")
    }
    
}
