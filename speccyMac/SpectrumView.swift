//
//  SpectrumView.swift
//  speccyMac
//
//  Created by John Ward on 08/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

class SpectrumView: NSView {
    
    var keysDown: [UInt16 : Bool] = [:]

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override var acceptsFirstResponder : Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        keysDown[event.keyCode] = true        
    }
    
    override func keyUp(with event: NSEvent) {
        keysDown[event.keyCode] = false
    }
    
    override func flagsChanged(with event: NSEvent) {
        if let state = keysDown[event.keyCode] {
            keysDown[event.keyCode] = !state
        } else {
            keysDown[event.keyCode] = true
        }
    }
    
}
