//
//  Emulator.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

protocol DragDelegate: AnyObject {
    func loadGame(_ fileUrl: URL)
}

class Emulator: NSViewController, DragDelegate {
    
    @IBOutlet weak var emulatorScreen: EmulatorImageView!
    
    let machine: Machine = Spectrum()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        emulatorScreen.dragDelegate = self
        
        // Black background around the emulator image
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.gray.cgColor
        
        // Use the image view's layer directly for pixel rendering
        emulatorScreen.wantsLayer = true
        emulatorScreen.layer?.contentsGravity = .resizeAspect
        emulatorScreen.layer?.magnificationFilter = .nearest

        machine.emulatorView = view as? EmulatorInputView
        machine.screenLayer = emulatorScreen.layer
        
        machine.start()
    }
    
    @IBAction func changeGame(_ sender: NSButton) {
        if let gameSelect = storyboard?.instantiateController(withIdentifier: "gameSelect") as? GameSelectViewController {
            gameSelect.machine = machine
            presentAsModalWindow(gameSelect)
        }
    }

    @IBAction func toggleMode(_ sender: NSButton) {
        if let layer = emulatorScreen.layer {
            if layer.magnificationFilter == .nearest {
                layer.magnificationFilter = .linear
            } else {
                layer.magnificationFilter = .nearest
            }
        }
    }
    
    func loadGame(_ fileURL: URL) {
        machine.loadGame(fileURL)
    }
}
