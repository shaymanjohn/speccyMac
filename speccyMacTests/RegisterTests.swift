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

    var z80: ZilogZ80 = ZilogZ80(memory: Memory("48.rom"))
    
    override func setUp() {
        super.setUp()
        
        z80 = ZilogZ80(memory: Memory("48.rom"))
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testInc() {
        z80.regB = 100
        z80.regB = z80.regInc(z80.regB)
        XCTAssert(z80.regB == 101, "Value not incremented from 100 to 101")
    }
    
    func testIncWrap() {
        z80.regB = 255
        z80.regB = z80.regInc(z80.regB)
        XCTAssert(z80.regB == 0, "Value not incremented from 255 to 0")
    }
    
    func testDec() {
        z80.regB = 100
        z80.regB = z80.regDec(z80.regB)
        
        XCTAssert(z80.regB == 99, "Value not deccremented from 100 to 99")
    }
    
    func testDecWrap() {
        z80.regB = 0
        z80.regB = z80.regDec(z80.regB)
        XCTAssert(z80.regB == 255, "Value not deccremented from 0 to 255")
    }
    
    func testRlcNoCarry() {
        z80.regB = 0x40
        z80.regB = z80.regRlc(z80.regB)
        XCTAssert(z80.regB == 0x80, "Value after rlc not 0x80")
    }
    
    func testRlcCarry() {
        z80.regB = 0xc0
        z80.regB = z80.regRlc(z80.regB)
        XCTAssert(z80.regB == 0x81, "Value after rlc not 0x81")
    }
    
    func testBit() {
        z80.regB = 0x01
        z80.regBit(0, value: z80.regB)
        XCTAssert(z80.regF & ZilogZ80.zBit == 0, "Bit test failed")
        
        z80.regB = 0x00
        z80.regBit(0, value: z80.regB)
        XCTAssert(z80.regF & ZilogZ80.zBit != 0, "Bit test failed")
    }
    
    func testSrl() {
        z80.regB = 0xff
        
        z80.regF = 0
        z80.regB = z80.regSrl(z80.regB)
        
        XCTAssert(z80.regB == 0x7f, "srl failed")
        XCTAssert(z80.regF & ZilogZ80.cBit > 0, "srl failed")
        
        z80.regB = 0xfe
        z80.regB = z80.regSrl(z80.regB)
        XCTAssert(z80.regB == 0x7f, "srl failed")
        XCTAssert(z80.regF & ZilogZ80.cBit == 0, "srl failed")
    }
    
    func testSla() {
        z80.regB = 0xff
        
        z80.regF = 0
        z80.regB = z80.regSla(z80.regB)
        
        XCTAssert(z80.regB == 0xfe, "sla failed")
        XCTAssert(z80.regF & ZilogZ80.cBit > 0, "sla failed")
        
        z80.regB = 0x7f
        z80.regB = z80.regSla(z80.regB)
        XCTAssert(z80.regB == 0xfe, "sla failed")
        XCTAssert(z80.regF & ZilogZ80.cBit == 0, "sla failed")
    }
    
    func testRr() {
        let c = z80.regF & ZilogZ80.cBit
        z80.regB = 0xff
        z80.regB = z80.regRr(z80.regB)
        XCTAssert(z80.regB == 0x7f | (c << 7), "rr failed")
    }
    
    func testRl() {
        let c = z80.regF & ZilogZ80.cBit
        z80.regB = 0xff
        z80.regB = z80.regRl(z80.regB)
        XCTAssert(z80.regB == 0xfe | c, "rl failed")
    }
    
    func testSet() {
        z80.regB = 0x00
        z80.regB |= (1 << 0)
        XCTAssert(z80.regB == 0x01, "set failed")
        
        z80.regB |= (1 << 7)
        XCTAssert(z80.regB == 0x81, "set failed")
    }
    
    func testRrc() {
        z80.regB = 0x03
        z80.regB = z80.regRrc(z80.regB)
        XCTAssert(z80.regB == 0x81, "rrc failed")
    }

}
