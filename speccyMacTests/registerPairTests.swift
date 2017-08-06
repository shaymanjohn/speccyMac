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

    var regPair: RegisterPair!
    var h: Register?
    var l: Register?
    
    override func setUp() {
        super.setUp()
        
        let _ = Z80(memory: Memory("48.rom"))
        
        h = Register()
        l = Register()
        
        regPair = RegisterPair(hi: h!, lo: l!)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testValueChangeUpdatesRegisters() {
        regPair!.value = 0x1020
        
        XCTAssert(h!.value == 0x10, "h not set by value change")
        XCTAssert(l!.value == 0x20, "l not set by value change")
    }
    
    func testRegisterChangeUpdatesValue() {
        h!.value = 0x30
        l!.value = 0x40
        
        XCTAssert(regPair!.value == 0x3040, "Setting registers does not update register pair")
    }
    
    func testIncNoWrap() {
        regPair!.value = 0x1234
        regPair!.inc()
        
        XCTAssert(regPair?.value == 0x1235, "inc reg pair no wrap failed")
    }
    
    func testIncWrap() {
        regPair!.value = 0xffff
        regPair!.inc()
        
        XCTAssert(regPair?.value == 0x0000, "inc reg pair with wrap failed")
    }
    
    func testDecNoWrap() {
        regPair!.value = 0x1234
        regPair!.dec()
        
        XCTAssert(regPair?.value == 0x1233, "dec reg pair no wrap failed")
    }
    
    func testDecWrap() {
        regPair!.value = 0x0000
        regPair!.dec()
        
        XCTAssert(regPair?.value == 0xffff, "dec reg pair with wrap failed")
    }
    
    func testAddNoWrap() {
        regPair!.value = 0x1000
        regPair!.add(0x1000)
        XCTAssert(regPair!.value == 0x2000, "reg pair add no wrap failed")
    }
    
    func testAddWithWrap() {
        regPair!.value = 0xffff
        regPair!.add(0x0002)
        XCTAssert(regPair!.value == 0x0001, "reg pair add with wrap failed")
    }
    
    func testAddNegative() {
        regPair!.value = 0xffff
        regPair!.add(0xffff)
        XCTAssert(regPair!.value == 0xfffe, "reg pair add with negative failed")
    }
    
    func testSbcNoCarry() {
        regPair.value = 1234
        
        let d = Register()
        let e = Register()
        let otherPair = RegisterPair(hi: d, lo: e)
        otherPair.value = 5
        
        Z80.f.value = 0
        
        regPair.sbc(otherPair)
        XCTAssert(regPair.value == 1229, "sbc no carry failed, producing result \(regPair.value)")
    }
    
    func testSbcNoCarryNegative() {
        regPair.value = 0x2345
        
        let d = Register()
        let e = Register()
        let otherPair = RegisterPair(hi: d, lo: e)
        otherPair.value = 0xffff
        
        Z80.f.value = 0
        
        regPair.sbc(otherPair)
        XCTAssert(regPair.value == 0x2346, "sbc no carry negative failed, producing result \(regPair.value)")
    }
    
    func testSbcCarry() {
        regPair.value = 0x2345
        
        let d = Register()
        let e = Register()
        let otherPair = RegisterPair(hi: d, lo: e)
        otherPair.value = 0x0004
        
        Z80.f.value = Z80.cBit
        
        regPair.sbc(otherPair)
        XCTAssert(regPair.value == 0x2340, "sbc no carry failed, producing result \(regPair.value)")
    }
    
    func testSbcCarryNegative() {
        regPair.value = 2001
        
        let d = Register()
        let e = Register()
        let otherPair = RegisterPair(hi: d, lo: e)
        otherPair.value = 0xffff
        
        Z80.f.value = Z80.cBit
        
        regPair.sbc(otherPair)
        XCTAssert(regPair.value == 2001, "sbc no carry negative failed, producing result \(regPair.value)")
    }

}
