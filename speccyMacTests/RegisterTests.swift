//
//  registerTests.swift
//  speccyMacTests
//
//  Created by John Ward on 06/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import XCTest
@testable import speccyMac

class RegisterTests: XCTestCase {

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
        z80.b.value = 0x01
        z80.b.bit(0)
        XCTAssert(Z80.f.value & Z80.zBit == 0, "Bit test failed")
        
        z80.b.value = 0x00
        z80.b.bit(0)
        XCTAssert(Z80.f.value & Z80.zBit != 0, "Bit test failed")
    }
    
    func testSrl() {
        z80.b.value = 0xff
        
        Z80.f.value = 0
        z80.b.srl()
        
        XCTAssert(z80.b.value == 0x7f, "srl failed")
        XCTAssert(Z80.f.value & Z80.cBit > 0, "srl failed")
        
        z80.b.value = 0xfe
        z80.b.srl()
        XCTAssert(z80.b.value == 0x7f, "srl failed")
        XCTAssert(Z80.f.value & Z80.cBit == 0, "srl failed")
    }
    
    func testSla() {
        z80.b.value = 0xff
        
        Z80.f.value = 0
        z80.b.sla()
        
        XCTAssert(z80.b.value == 0xfe, "sla failed")
        XCTAssert(Z80.f.value & Z80.cBit > 0, "sla failed")
        
        z80.b.value = 0x7f
        z80.b.sla()
        XCTAssert(z80.b.value == 0xfe, "sla failed")
        XCTAssert(Z80.f.value & Z80.cBit == 0, "sla failed")
    }
    
    func testRr() {
        let c = Z80.f.value & Z80.cBit
        z80.b.value = 0xff
        z80.b.rr()
        XCTAssert(z80.b.value == 0x7f | (c << 7), "rr failed")
    }
    
    func testRl() {
        let c = Z80.f.value & Z80.cBit
        z80.b.value = 0xff
        z80.b.rl()
        XCTAssert(z80.b.value == 0xfe | c, "rl failed")
    }
    
    func testSet() {
        z80.b.value = 0x00
        z80.b.set(0)
        XCTAssert(z80.b.value == 0x01, "set failed")
        
        z80.b.set(7)
        XCTAssert(z80.b.value == 0x81, "set failed")
    }
    
    func testRrc() {
        z80.b.value = 0x03
        z80.b.rrc()
        XCTAssert(z80.b.value == 0x81, "rrc failed")
    }

}
