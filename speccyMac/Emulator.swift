//
//  Emulator.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

class Emulator: NSViewController {
    
    @IBOutlet weak var emulatorScreen: NSImageView!
    @IBOutlet weak var lateLabel:      NSTextField!
    
    var machine: Machine!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.view.wantsLayer = true
                
        machine = Spectrum()
        machine.emulatorView = self.view as? EmulatorView
        machine.emulatorScreen = self.emulatorScreen
        machine.lateLabel = self.lateLabel
        
        self.machine.start()
    }
    
    @IBAction func changeGame(_ sender: NSButton) {
        
        if let gameSelect = self.storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "gameSelect")) as? GameSelectViewController {
            gameSelect.machine = machine
            self.presentViewControllerAsModalWindow(gameSelect)
        }
    }
}
