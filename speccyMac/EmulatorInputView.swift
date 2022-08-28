//
//  EmulatorView.swift
//  speccyMac
//
//  Created by John Ward on 08/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

class EmulatorInputView: NSView {
    
    var keysDown: [UInt16] = []    
    
    private var keyStates: [UInt16 : Bool] = [:] {
        didSet {
            keysDown = Array(keyStates.filter {key in key.value == true}.keys)
        }
    }
    
    override var acceptsFirstResponder : Bool {
        return true
    }
    
    func clearKeysWhenGettingFocus() {
        keyStates = [:]
    }
    
    override func keyDown(with event: NSEvent) {
        keyStates[event.keyCode] = true
    }
    
    override func keyUp(with event: NSEvent) {
        keyStates[event.keyCode] = false
    }
    
    override func flagsChanged(with event: NSEvent) {        
        if event.keyCode == 0 {
            return
        }

        if let state = keyStates[event.keyCode] {
            keyStates[event.keyCode] = !state
        } else {
            keyStates[event.keyCode] = true
        }
    }

}
