//
//  Spectrum.swift
//  speccyMac
//
//  Created by John Ward on 16/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

class Spectrum: Machine {
    
    func refreshScreen() {
        
    }
    
    func captureRow(_ row: UInt16) {
        
    }
    
    func input(_ high: UInt8, low: UInt8) -> UInt8 {
        return 0
    }
    
    func output(_ port: UInt8, byte: UInt8) {
        
    }
    
    func playSound() {
        
    }
    
    var ticksPerFrame: UInt32 = 0
    
    var audioPacketSize: UInt32 = 0
    
    
}
