//
//  RefreshReg.swift
//  speccyMac
//
//  Created by John Ward on 06/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

class RefreshReg {
    
    var value: UInt8 = 0
    
    final func inc() {
        let highBit = value & 0x80
        
        value = value & 0x7f
        value += 1
        if value == 128 {
            value = 0
        }
        
        value = value | highBit
    }
    
}
