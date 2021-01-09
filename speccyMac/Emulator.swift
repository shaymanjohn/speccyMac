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

        machine.emulatorView = view as? EmulatorInputView
        machine.emulatorScreen = emulatorScreen
        machine.lateLabel = lateLabel_x
        
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
