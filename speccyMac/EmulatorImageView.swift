//
//  EmulatorImageView.swift
//  speccyMac
//
//  Created by John Ward on 26/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

class EmulatorImageView: NSImageView {

    override func draw(_ dirtyRect: NSRect) {
        
        NSGraphicsContext.current?.imageInterpolation = .none   // none, low, medium, high        
        super.draw(dirtyRect)
    }
    
}
