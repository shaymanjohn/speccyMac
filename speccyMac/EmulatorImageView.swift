//
//  EmulatorImageView.swift
//  speccyMac
//
//  Created by John Ward on 26/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

class EmulatorImageView: NSImageView {

    var modeIndex = 0
    let allImageModes: [NSImageInterpolation] = [.none, .low] //, .medium, .high]

    override func draw(_ dirtyRect: NSRect) {

        NSGraphicsContext.current?.imageInterpolation = allImageModes[modeIndex]
        super.draw(dirtyRect)
    }

    func changeImageMode() {

        modeIndex += 1
        if modeIndex > allImageModes.count - 1 {
            modeIndex = 0
        }
    }
    
}
