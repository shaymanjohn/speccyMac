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

    var z80: Z80 = Z80(memory: Memory("48.rom"))
    
    override func setUp() {
        super.setUp()
        
        z80 = Z80(memory: Memory("48.rom"))
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testInc() {
        z80.b.value = 100
        z80.b.inc()
        XCTAssert(z80.b.value == 101, "Value not incremented from 100 to 101")
    }
    
    func testIncWrap() {
        z80.b.value = 255
        z80.b.inc()
        XCTAssert(z80.b.value == 0, "Value not incremented from 255 to 0")
    }
    
    func testDec() {
        z80.b.value = 100
        z80.b.dec()
        
        XCTAssert(z80.b.value == 99, "Value not deccremented from 100 to 99")
    }
    
    func testDecWrap() {
        z80.b.value = 0
        z80.b.dec()
        XCTAssert(z80.b.value == 255, "Value not deccremented from 0 to 255")
    }
    
    func testRlcNoCarry() {
        z80.b.value = 0x40
        z80.b.rlc()
        XCTAssert(z80.b.value == 0x80, "Value after rlc not 0x80")
    }
    
    func testRlcCarry() {
        z80.b.value = 0xc0
        z80.b.rlc()
        XCTAssert(z80.b.value == 0x81, "Value after rlc not 0x81")
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
