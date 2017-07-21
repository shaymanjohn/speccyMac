//
//  Z80+dd.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
    
    final func ddprefix(opcode: UInt8, first: UInt8, second: UInt8) throws {
        
        let word16 = (UInt16(second) << 8) + UInt16(first)
        let instruction = self.ddprefixedOps[Int(opcode)]
        
        let offset = UInt16(first)
        
        switch opcode {
            
        case 0x21:
            self.ixy = word16
            
        case 0x35:
            //            let paired = Int(self.ixy + offset)
            //            self.byteDec(paired)
            print("offset \(offset)")
            
        default:
            throw NSError(domain: "ed", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode])
        }
        
        self.pc = self.pc + instruction.length
        
        let ts = instruction.tStates
        self.incCounters(amount: UInt16(ts))
        
        self.incR()
        self.incR()
    }
}
