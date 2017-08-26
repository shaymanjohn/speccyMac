//
//  Machine.swift
//  speccyMac
//
//  Created by John Ward on 20/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation
import Cocoa

protocol Machine : class {
    
    func start()
    func refreshScreen()
    func playSound()
    
    func loadGame(_ game: String)
    func captureRow(_ row: UInt16)
    
    func input(_ high: UInt8, low: UInt8) -> UInt8
    func output(_ port: UInt8, byte: UInt8)
    
    var processor: Processor { get }
    var memory:    Memory { get }
    
    var ticksPerFrame:   UInt32 { get }
    var audioPacketSize: UInt32 { get }
    
    var games: [Game] { get }
    
    weak var emulatorScreen: NSImageView?  { get set }
    weak var emulatorView:   EmulatorInputView? { get set }
    weak var lateLabel:      NSTextField?  { get set }
}

extension Machine {
    
    func start() {
        processor.machine = self
        
        DispatchQueue.global().async {
            self.processor.start()
        }
    }
}
