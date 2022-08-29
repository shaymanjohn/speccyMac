//
//  Machine.swift
//  speccyMac
//
//  Created by John Ward on 20/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation
import Cocoa

protocol Machine : AnyObject {
    
    func start()
    func tick()
    
    func loadGame(_ gameUrl: String)
    
    func input(_ high: UInt8, low: UInt8) -> UInt8
    func output(_ port: UInt8, byte: UInt8)
    
    func reportProblem(_ error: Error)
    
    var processor: Processor { get }
    var memory:    Memory { get }
    
    var ula:      UInt32 { get set }
    var videoRow: UInt16 { get set }
    
    var ticksPerFrame: Int { get }
    
    var games: [Game] { get }
    var clicks: UInt8 { get }
    
    var emulatorScreen: NSImageView? { get set }
    var emulatorView:   EmulatorInputView? { get set }
    var lateLabel:      NSTextField? { get set }
    var border:         NSStackView? { get set }
}

extension Machine {
    
    func start() {
        processor.machine = self
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.processor.start()
        }
    }
    
    func reportProblem(_ error: Error) {        
        let err = error as NSError
        
        if let instruction = err.userInfo["instruction"] as? String,
            let opcode = err.userInfo["opcode"] as? String {
            
            let alert = NSAlert()
            alert.messageText = "Unemulated Instruction:\n\n\(instruction)\nInstruction number: \(opcode)\nSection: \(err.domain)"
            alert.runModal()
        }
    }
}
