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
    
    var r: UInt8 {
        return UInt8((hex & 0xff0000) >> 16)
    }
    
    var g: UInt8 {
        return UInt8((hex & 0x00ff00) >> 8)
    }
    
    var b: UInt8 {
        return UInt8(hex & 0x000ff)
    }
    
    var rf: CGFloat {
        return CGFloat(r) / 255.0
    }
    
    var gf: CGFloat {
        return CGFloat(g) / 255.0
    }
    
    var bf: CGFloat {
        return CGFloat(b) / 255.0
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
