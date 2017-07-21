//
//  ViewController.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

protocol Screen : class {
    func refreshScreen()
    
    var borderColour: UInt8 {get set}
}

class Spectrum: NSViewController {
    
    var z80: Z80!
    var border: UInt8 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let memory = Memory("48.rom")
        z80 = Z80(memory: memory)
        z80.screen = self
        
//        loadGame("manic.sna")
        
        DispatchQueue.global(qos: .background).async {
            self.z80.start()
        }
    }
    
    func loadGame(_ game: String) {
        z80.pause()
        z80.loadGame(game)
        z80.unpause()
    }

}

extension Spectrum : Screen {
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

