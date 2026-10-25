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
    
    @IBOutlet weak var emulatorScreen: NSImageView!
    @IBOutlet weak var displayModeControl: NSSegmentedControl!

    private var metalView: MetalScreenView!

    let machine: Machine = Spectrum()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Black background around the emulator image
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.gray.cgColor

        // Replace the storyboard image view's content with a Metal-backed view
        // pinned to the same frame. The emulator uploads frames to this view.
        let metal = MetalScreenView(frame: emulatorScreen.bounds, device: nil)
        metal.translatesAutoresizingMaskIntoConstraints = false
        metal.dragDelegate = self
        emulatorScreen.addSubview(metal)
        NSLayoutConstraint.activate([
            metal.leadingAnchor.constraint(equalTo: emulatorScreen.leadingAnchor),
            metal.trailingAnchor.constraint(equalTo: emulatorScreen.trailingAnchor),
            metal.topAnchor.constraint(equalTo: emulatorScreen.topAnchor),
            metal.bottomAnchor.constraint(equalTo: emulatorScreen.bottomAnchor)
        ])
        metalView = metal

        machine.emulatorView = view as? EmulatorInputView
        machine.metalView = metal

        // The control sits over the dark letterboxed Metal view; give it an
        // opaque backing so unselected segment labels stay legible.
        displayModeControl.wantsLayer = true
        displayModeControl.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        displayModeControl.layer?.cornerRadius = 6

        machine.start()
    }
    
    @IBAction func changeGame(_ sender: NSButton) {
        if let gameSelect = storyboard?.instantiateController(withIdentifier: "gameSelect") as? GameSelectViewController {
            gameSelect.machine = machine
            presentAsModalWindow(gameSelect)
        }
    }

    @IBAction func changeDisplayMode(_ sender: NSSegmentedControl) {
        let mode = MetalScreenView.DisplayMode(rawValue: sender.selectedSegment) ?? .crisp
        metalView.setDisplayMode(mode)
    }
    
    func loadGame(_ fileURL: URL) {
        machine.loadGame(fileURL)
    }
}
