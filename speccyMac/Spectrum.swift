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
    
    var borderColour:  UInt8  { get set }
    var ticksPerFrame: UInt32 { get }
    var clickCount:    UInt32 { get set }
}

class Spectrum: NSViewController {
    
    @IBOutlet weak var spectrumScreen: NSImageView!
    
    var z80: Z80!
    var border: UInt8 = 0
    var clicksCount: UInt32 = 0
    
    let colourSpace = CGColorSpaceCreateDeviceRGB()
    
    var screenData = [UInt32](repeating: 0, count: 32 * 8 * 24 * 8)
    var provider: CGDataProvider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let callback: CGDataProviderReleaseDataCallback = {
            (info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) -> () in
        }
        provider = CGDataProvider(dataInfo: nil, data: screenData, size: 1024, releaseData: callback)!
        
        let memory = Memory("48.rom")
        z80 = Z80(memory: memory)
        z80.machine = self
        
        DispatchQueue.global(qos: .background).async {
            self.z80.start()
        }
        
        spectrumScreen.wantsLayer = true
        spectrumScreen.layer?.backgroundColor = NSColor.black.cgColor
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
            return clicksCount
        }
        set {
            clicksCount = newValue
        }
    }
    
    var ticksPerFrame: UInt32 {
        return 69888
    }
    
    var borderColour: UInt8 {
        get {
            return border
        }
        
        set {
            border = newValue
        }
    }
    
    final func refreshScreen() {
        for ix in 0..<screenData.count {
            screenData[ix] = UInt32(arc4random()%256)
        }
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).union(CGBitmapInfo())
        
        if let image = CGImage(width: 256, height: 192, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1024, space: colourSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
            spectrumScreen.image = NSImage(cgImage: image, size: .zero)
        }
    }
}

