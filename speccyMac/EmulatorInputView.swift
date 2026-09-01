//
//  EmulatorView.swift
//  speccyMac
//
//  Created by John Ward on 08/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

class EmulatorInputView: NSView {

    // keysDown is written on the main (UI) thread via keyDown/keyUp/flagsChanged
    // and read from the emulation thread (Spectrum.input). Access is guarded by
    // keysLock to avoid data races on the underlying Array.
    private let keysLock = NSLock()
    private var _keysDown: [UInt16] = []

    var keysDown: [UInt16] {
        keysLock.lock()
        defer { keysLock.unlock() }
        return _keysDown
    }

    private var keyStates: [UInt16 : Bool] = [:] {
        didSet {
            let snapshot = Array(keyStates.filter { key in key.value == true }.keys)
            keysLock.lock()
            _keysDown = snapshot
            keysLock.unlock()
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
