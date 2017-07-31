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

struct colour {
    let r: UInt32
    let g: UInt32
    let b: UInt32
}

class Spectrum: NSViewController {
    
    @IBOutlet weak var spectrumScreen: NSImageView!
    
    var z80: Z80!
    var border: UInt8 = 0
    var clicksCount: UInt32 = 0
    
    let colourSpace = CGColorSpaceCreateDeviceRGB()
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).union(CGBitmapInfo())
    
    var screenData = [UInt32](repeating: 0, count: 32 * 8 * 24 * 8)
    var provider: CGDataProvider!
    
    let colourTable = [colour(r: 0x00, g: 0x00, b: 0x00), colour(r: 0x00, g: 0x00, b: 0xcd), colour(r: 0xcd, g: 0x00, b: 0x00), colour(r: 0xcd, g: 0x00, b: 0xcd),
                       colour(r: 0x00, g: 0xcd, b: 0x00), colour(r: 0x00, g: 0xcd, b: 0xcd), colour(r: 0xcd, g: 0xcd, b: 0x00), colour(r: 0xcd, g: 0xcd, b: 0xcd),
                       colour(r: 0x00, g: 0x00, b: 0x00), colour(r: 0x00, g: 0x00, b: 0xff), colour(r: 0xff, g: 0x00, b: 0x00), colour(r: 0xff, g: 0x00, b: 0xff),
                       colour(r: 0x00, g: 0xff, b: 0x00), colour(r: 0x00, g: 0xff, b: 0xff), colour(r: 0xff, g: 0xff, b: 0x00), colour(r: 0xff, g: 0xff, b: 0xff)]
    
    var colours = [UInt32](repeating: 0, count: 16)
    
    let memory = Memory("48.rom")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var colourIndex = 0
        for colour in colourTable {
            let rComp = colour.r << 24
            let gComp = colour.g << 16
            let bComp = colour.b << 8
            colours[colourIndex] = rComp + gComp + bComp + UInt32(0xff)
            colourIndex = colourIndex + 1
        }
        
        let callback: CGDataProviderReleaseDataCallback = {
            (info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) -> () in
        }
        provider = CGDataProvider(dataInfo: nil, data: screenData, size: 1024, releaseData: callback)!
        
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
        
        var index = 0
        var screenIndex:UInt16 = 16384
        
        let ink   = colours[0]
        let paper = colours[15]
        
        for _ in 0..<6144 {
            let byte = memory.get(screenIndex)
            
            screenData[index + 0] = (byte & 0x80) > 0 ? ink : paper
            screenData[index + 1] = (byte & 0x40) > 0 ? ink : paper
            screenData[index + 2] = (byte & 0x20) > 0 ? ink : paper
            screenData[index + 3] = (byte & 0x10) > 0 ? ink : paper
            screenData[index + 4] = (byte & 0x08) > 0 ? ink : paper
            screenData[index + 5] = (byte & 0x04) > 0 ? ink : paper
            screenData[index + 6] = (byte & 0x02) > 0 ? ink : paper
            screenData[index + 7] = (byte & 0x01) > 0 ? ink : paper
                
            index = index + 8
            screenIndex = screenIndex + 1
        }
        
        if let image = CGImage(width: 256, height: 192, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1024, space: colourSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
            spectrumScreen.image = NSImage(cgImage: image, size: .zero)
        }
    }
}

