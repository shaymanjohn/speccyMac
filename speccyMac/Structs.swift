//
//  Structs.swift
//  speccyMac
//
//  Created by John Ward on 16/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

struct colour {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

struct keyboardMap {
    let macKeycode: UInt16
    let spectrumCode: UInt16
}

struct keyMap {
    let macKey: UInt16
    let machineKey: UInt16
}
