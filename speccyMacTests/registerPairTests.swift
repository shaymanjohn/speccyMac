//
//  registerPairTests.swift
//  speccyMacTests
//
//  Created by John Ward on 06/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import XCTest
@testable import speccyMac

class registerPairTests: XCTestCase {

    var z80: Z80 = Z80(memory: Memory("48.rom"))
    
    override func setUp() {
        super.setUp()
        
        z80 = Z80(memory: Memory("48.rom"))
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testValueChangeUpdatesRegisters() {
        z80.hl.value = 0x1020
        
        XCTAssert(z80.h.value == 0x10, "h not set by value change")
        XCTAssert(z80.l.value == 0x20, "l not set by value change")
    }
    
    func testRegisterChangeUpdatesValue() {
        z80.h.value = 0x30
        z80.l.value = 0x40
        
        XCTAssert(z80.hl.value == 0x3040, "Setting registers does not update register pair")
    }
    
    func testAddNoWrap() {
        z80.hl.value = 0x1000
        z80.hl.add(0x1000)
        XCTAssert(z80.hl.value == 0x2000, "reg pair add no wrap failed")
    }
    
    func testAddWithWrap() {
        z80.hl.value = 0xffff
        z80.hl.add(0x0002)
        XCTAssert(z80.hl.value == 0x0001, "reg pair add with wrap failed")
    }
    
    func testAddNegative() {
        z80.hl.value = 0xffff
        z80.hl.add(0xffff)
        XCTAssert(z80.hl.value == 0xfffe, "reg pair add with negative failed")
    }
    
    func testSbcNoCarry() {
        z80.hl.value = 1234
        
        let d = Register()
        let e = Register()
        let otherPair = RegisterPair(hi: d, lo: e)
        otherPair.value = 5
        
        Z80.f.value = 0
        
        z80.hl.sbc(otherPair)
        XCTAssert(z80.hl.value == 1229, "sbc no carry failed, producing result \(z80.hl.value)")
    }
    
    func testSbcNoCarryNegative() {
        z80.hl.value = 0x2345
        
        let d = Register()
        let e = Register()
        let otherPair = RegisterPair(hi: d, lo: e)
        otherPair.value = 0xffff
        
        Z80.f.value = 0
        
        z80.hl.sbc(otherPair)
        XCTAssert(z80.hl.value == 0x2346, "sbc no carry negative failed, producing result \(z80.hl.value)")
    }
    
    func testSbcCarry() {
        z80.hl.value = 0x2345
        
        let d = Register()
        let e = Register()
        let otherPair = RegisterPair(hi: d, lo: e)
        otherPair.value = 0x0004
        
        Z80.f.value = Z80.cBit
        
        z80.hl.sbc(otherPair)
        XCTAssert(z80.hl.value == 0x2340, "sbc no carry failed, producing result \(z80.hl.value)")
    }
    
    func testSbcCarryNegative() {
        z80.hl.value = 2001
        
        let d = Register()
        let e = Register()
        let otherPair = RegisterPair(hi: d, lo: e)
        otherPair.value = 0xffff
        
        Z80.f.value = Z80.cBit
        
        z80.hl.sbc(otherPair)
        XCTAssert(z80.hl.value == 2001, "sbc no carry negative failed, producing result \(z80.hl.value)")
    }

}
