//
//  ViewController.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

protocol Machine : class {
    func refreshScreen()
    
    var borderColour:  UInt8 { get set }
    var ticksPerFrame: UInt32 { get }
    var clickCount: UInt32 { get set }
}

class Spectrum: NSViewController {
    
    @IBOutlet weak var spectrumScreen: NSImageView!
    
    var z80: Z80!
    var border: UInt8 = 0
    var clicksCount: UInt32 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let memory = Memory("48.rom")
        z80 = Z80(memory: memory)
        z80.machine = self
        
        DispatchQueue.global(qos: .background).async {
            self.z80.start()
        }
        
        self.spectrumScreen.wantsLayer = true
        self.spectrumScreen.layer?.backgroundColor = NSColor.black.cgColor
    }
    
    func loadGame(_ game: String) {
        z80.pause()
        z80.loadGame(game)
        z80.unpause()
    }

}

extension Spectrum : Machine {
    var clickCount: UInt32 {
        get {
            return self.clicksCount
        }
        set {
            self.clicksCount = newValue
        }
    }
    
    var ticksPerFrame: UInt32 {
        return 69888
    }
    
    var borderColour: UInt8 {
        get {
            return self.border
        }
        
        set {
            self.border = newValue
        }
    }
    
    func refreshScreen() {
        print("refreshing screen")
    }
}

