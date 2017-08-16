//
//  EmulatorView.swift
//  speccyMac
//
//  Created by John Ward on 08/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

class EmulatorView: NSView {
    
    var keysDown: [UInt16] = []
    
    private var keyStates: [UInt16 : Bool] = [:] {
        didSet {
            keysDown = Array(keyStates.filter{key in key.value == true}.keys)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override var acceptsFirstResponder : Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        keyStates[event.keyCode] = true
    }
    
    override func keyUp(with event: NSEvent) {
        keyStates[event.keyCode] = false
    }
    
    override func flagsChanged(with event: NSEvent) {
        if let state = keyStates[event.keyCode] {
            keyStates[event.keyCode] = !state
        } else {
            keyStates[event.keyCode] = true
        }
    }
    
}
