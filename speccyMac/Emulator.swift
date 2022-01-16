//
//  Emulator.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

class Emulator: NSViewController {
    
    @IBOutlet weak var emulatorScreen: EmulatorImageView!
    @IBOutlet weak var lateLabel:      NSTextField!
    
    let machine: Machine = Spectrum()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .left
        stack.distribution = .fillEqually
        stack.spacing = 0.0
        
        for _ in 0..<313 {
            let borderLine = NSView()
            borderLine.wantsLayer = true
            stack.addArrangedSubview(borderLine)
        }
        
        view.addSubview(stack, positioned: .below, relativeTo: emulatorScreen)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        machine.emulatorView = view as? EmulatorInputView
        machine.emulatorScreen = emulatorScreen
        machine.lateLabel = lateLabel
        machine.border = stack
        
        machine.start()
    }
    
    @IBAction func changeGame(_ sender: NSButton) {
        if let gameSelect = storyboard?.instantiateController(withIdentifier: "gameSelect") as? GameSelectViewController {
            gameSelect.machine = machine
            presentAsModalWindow(gameSelect)
        }
    }

    @IBAction func toggleMode(_ sender: NSButton) {
        emulatorScreen.changeImageMode()
    }
    
}
