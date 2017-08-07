//
//  Z80+core.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
    
    final func setRelativePC(_ byte: UInt8) {
        if byte & 0x80 > 0 {
            pc = pc - (256 - UInt16(byte))
        } else {
            pc = pc + UInt16(byte)
        }
    }
    
    final func rst(_ address: UInt16) {
        memory.push(pc &+ 1)
        pc = address
        pc = pc &- 1
    }
    
    final func portOut(_ port: UInt8, byte: UInt8) {
        if port == 0xfe {
            machine?.borderColour = byte & 0x07
            
            if byte & 0x10 > 0 {
                if let clicks = machine?.clickCount {
                    machine!.clickCount = clicks + 1
                }
            }
        }
    }
    
}
