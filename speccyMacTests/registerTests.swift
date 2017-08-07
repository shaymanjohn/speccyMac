//
//  registerTests.swift
//  speccyMacTests
//
//  Created by John Ward on 06/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import XCTest
@testable import speccyMac

class registerTests: XCTestCase {
 
    let reg = Register()
    
    override func setUp() {
        super.setUp()
        
        let _ = Z80(memory: Memory("48.rom"))
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testInc() {
        reg.value = 100
        reg.inc()
        XCTAssert(reg.value == 101, "Value not incremented from 100 to 101")
    }
    
    func testIncWrap() {
        reg.value = 255
        reg.inc()
        XCTAssert(reg.value == 0, "Value not incremented from 255 to 0")
    }
    
    func testDec() {
        reg.value = 100
        reg.dec()
        
        XCTAssert(reg.value == 99, "Value not deccremented from 100 to 99")
    }
    
    func testDecWrap() {
        reg.value = 0
        reg.dec()
        XCTAssert(reg.value == 255, "Value not deccremented from 0 to 255")
    }
    
    func testRlcNoCarry() {
        reg.value = 0x40
        reg.rlc()
        XCTAssert(reg.value == 0x80, "Value after rlc not 0x80")
    }
    
    func testRlcCarry() {
        reg.value = 0xc0
        reg.rlc()
        XCTAssert(reg.value == 0x81, "Value after rlc not 0x81")
    }
    
    func testBit() {
        let reg = Register()
        reg.value = 0x01
        
        reg.bit(0)
        XCTAssert(Z80.f.value & Z80.zBit == 0, "Bit test failed")
        
        reg.value = 0x00
        reg.bit(0)
        XCTAssert(Z80.f.value & Z80.zBit != 0, "Bit test failed")
    }

}
