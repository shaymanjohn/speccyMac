//
//  Z80+dd.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
    
    final func ddprefix(opcode: UInt8, first: UInt8, second: UInt8) -> Bool {
        var success = true
        
        let word16 = (UInt16(second) << 8) + UInt16(first)
        let instruction = self.ddprefixedOps[Int(opcode)]
        
        let offset = UInt16(first)
        
        //        let hexPc = String(self.pc, radix: 16, uppercase: true)
        //        let hexOp = String(opcode, radix: 16, uppercase: false)
        //        print("\(hexPc) \(hexOp) \(instruction.opCode)")
        
        switch opcode {
            
        case 0x21:
            self.ixy = word16
            
        case 0x35:
            //            let paired = Int(self.ixy + offset)
            //            self.byteDec(paired)
            print("offset \(offset)")
            
        default:
            success = false
            let hex = String(opcode, radix: 16, uppercase: true)
            let hexPc = String(self.pc, radix: 16, uppercase: true)
            print("\(hexPc) ddprefix \(hex) unknown, operation \(instruction.opCode)")
        }
        
        self.pc = self.pc + instruction.length
        
        let ts = instruction.tStates
        self.incCounters(amount: UInt16(ts))
        
        self.incR()
        self.incR()
        
        return success
    }
}
