//
//  registerPairTests.swift
//  speccyMacTests
//
//  Created by John Ward on 06/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import XCTest
@testable import speccyMac

class RegisterPairTests: XCTestCase {

    var z80: ZilogZ80 = ZilogZ80(memory: Memory("48.rom"))
    
    override func setUp() {
        super.setUp()
        
        z80 = ZilogZ80(memory: Memory("48.rom"))
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testValueChangeUpdatesRegisters() {
        z80.hl = 0x1020
        
        XCTAssert(z80.regH == 0x10, "h not set by value change")
        XCTAssert(z80.regL == 0x20, "l not set by value change")
    }
    
    func testRegisterChangeUpdatesValue() {
        z80.regH = 0x30
        z80.regL = 0x40
        
        XCTAssert(z80.hl == 0x3040, "Setting registers does not update register pair")
    }
    
    func testAddNoWrap() {
        z80.hl = 0x1000
        z80.addHL(0x1000)
        XCTAssert(z80.hl == 0x2000, "reg pair add no wrap failed")
    }
    
    func testAddWithWrap() {
        z80.hl = 0xffff
        z80.addHL(0x0002)
        XCTAssert(z80.hl == 0x0001, "reg pair add with wrap failed")
    }
    
    func testAddNegative() {
        z80.hl = 0xffff
        z80.addHL(0xffff)
        XCTAssert(z80.hl == 0xfffe, "reg pair add with negative failed")
    }
    
    func testSbcNoCarry() {
        z80.hl = 1234
        z80.regF = 0
        
        z80.sbcHL(5)
        XCTAssert(z80.hl == 1229, "sbc no carry failed, producing result \(z80.hl)")
    }
    
    func testSbcNoCarryNegative() {
        z80.hl = 0x2345
        z80.regF = 0
        
        z80.sbcHL(0xffff)
        XCTAssert(z80.hl == 0x2346, "sbc no carry negative failed, producing result \(z80.hl)")
    }
    
    func testSbcCarry() {
        z80.hl = 0x2345
        z80.regF = ZilogZ80.cBit
        
        z80.sbcHL(0x0004)
        XCTAssert(z80.hl == 0x2340, "sbc carry failed, producing result \(z80.hl)")
    }
    
    func testSbcCarryNegative() {
        z80.hl = 2001
        z80.regF = ZilogZ80.cBit
        
        z80.sbcHL(0xffff)
        XCTAssert(z80.hl == 2001, "sbc carry negative failed, producing result \(z80.hl)")
    }

}
