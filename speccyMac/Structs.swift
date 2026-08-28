//
//  Structs.swift
//  speccyMac
//
//  Created by John Ward on 16/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation
import CoreGraphics

struct Colour {
    
    let hex: UInt32
    
    let r: UInt8
    let g: UInt8
    let b: UInt8
    
    let rf: CGFloat
    let gf: CGFloat
    let bf: CGFloat
    
    let cgColour: CGColor
            
    init(_ hex: UInt32) {
        self.hex = hex
        
        r = UInt8((hex & 0xff0000) >> 16)
        g = UInt8((hex & 0x00ff00) >> 8)
        b = UInt8(hex & 0x000ff)
        
        rf = CGFloat(r) / 255.0
        gf = CGFloat(g) / 255.0
        bf = CGFloat(b) / 255.0
        
        cgColour = CGColor(red: rf * 0.95, green: gf * 0.95, blue: bf * 0.95, alpha: 1.0)
    }
}

struct KeyMap {
    let macKey: UInt16
    let machineKey: UInt16
}

struct Game {
    let file: String
    let name: String
}
