//
//  Structs.swift
//  speccyMac
//
//  Created by John Ward on 16/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

struct colour {
    
    let hex: UInt32
    
    let r: UInt8
    let g: UInt8
    let b: UInt8
    
    let rf: CGFloat
    let gf: CGFloat
    let bf: CGFloat
            
    init(_ hex: UInt32) {
        self.hex = hex
        
        r = UInt8((hex & 0xff0000) >> 16)
        g = UInt8((hex & 0x00ff00) >> 8)
        b = UInt8(hex & 0x000ff)
        
        rf = CGFloat(r) / 255.0
        gf = CGFloat(g) / 255.0
        bf = CGFloat(b) / 255.0
    }
}

struct keyboardMap {
    let macKeycode: UInt16
    let spectrumCode: UInt16
}

struct keyMap {
    let macKey: UInt16
    let machineKey: UInt16
}

struct Game {
    let file: String
    let name: String
}
