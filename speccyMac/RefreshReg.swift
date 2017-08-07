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
        if value & 0x80 > 0 {
            var byte = value & 0x7f
            byte = byte &+ 1
            if byte == 128 {
                byte = 0
            }
            value = byte | 0x80
        } else {
            value = value &+ 1
            if value == 128 {
                value = 0
            }
        }
    }
    
}
