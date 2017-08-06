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
    func captureRow(_ row: UInt16)
    
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
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue).union(CGBitmapInfo())
    
    var bmpData = [UInt32](repeating: 0, count: 32 * 8 * 24 * 8)
    
    var screenAddress = [UInt16](repeating: 0, count: 192)
    var attrAddress = [UInt16](repeating: 0, count: 192)
    
    var screenCopy = [UInt8](repeating: 0, count: 32 * 192)
    var screenCopySave = [UInt8](repeating: 255, count: 32 * 192)
    
    var colourCopy = [UInt8](repeating: 0, count: 32 * 192)
    var colourCopySave = [UInt8](repeating: 255, count: 32 * 192)
    
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
        
        provider = CGDataProvider(dataInfo: nil, data: bmpData, size: 1024, releaseData: callback)!
        
        z80 = Z80(memory: memory)
        z80.machine = self
        
        DispatchQueue.global(qos: .default).async {
            self.z80.start()
        }
        
        spectrumScreen.wantsLayer = true
        spectrumScreen.layer?.backgroundColor = NSColor.black.cgColor
        
        var rowNum = 0
        for row in 0..<24 {
            for pixelRow in 0..<8 {
                let dataByteHigh = 0x40 | (row & 0x18) | (pixelRow % 8);
                let dataByteLow  = ((row & 0x7) << 5);
                
                let address:UInt16 = UInt16((dataByteHigh << 8)) + UInt16(dataByteLow);
                screenAddress[rowNum] = address;
                attrAddress[rowNum] = UInt16(22580) + UInt16((32 * rowNum))
                
                rowNum = rowNum + 1
            }
        }
        
//        loadGame("manic.sna")
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
    
    final func captureRow(_ row: UInt16) {
        var pixelAddress = screenAddress[row]
        var colourAddress = attrAddress[row]
        
        var index = Int(row * 32)
        for _ in 0..<32 {
            screenCopy[index] = memory.get(pixelAddress)
            colourCopy[index] = memory.get(colourAddress)
            
            pixelAddress = pixelAddress + 1
            colourAddress = colourAddress + 1
            index = index + 1
        }
    }
    
    final func refreshScreen() {        
        
        var bmpIndex = 0
        
        for index in 0..<192 * 32 {
            let byte = screenCopy[index]
            let colour = colourCopy[index]
            
            if byte != screenCopySave[index] || colour != colourCopySave[index] {
                screenCopySave[index] = byte
                colourCopySave[index] = colour
                
                let ink = colours[colour & 0x07]
                let paper = colours[(colour & 0x38) >> 3]
                
                bmpData[bmpIndex + 0] = (byte & 0x80) > 0 ? ink : paper
                bmpData[bmpIndex + 1] = (byte & 0x40) > 0 ? ink : paper
                bmpData[bmpIndex + 2] = (byte & 0x20) > 0 ? ink : paper
                bmpData[bmpIndex + 3] = (byte & 0x10) > 0 ? ink : paper
                bmpData[bmpIndex + 4] = (byte & 0x08) > 0 ? ink : paper
                bmpData[bmpIndex + 5] = (byte & 0x04) > 0 ? ink : paper
                bmpData[bmpIndex + 6] = (byte & 0x02) > 0 ? ink : paper
                bmpData[bmpIndex + 7] = (byte & 0x01) > 0 ? ink : paper
            }
            
            bmpIndex = bmpIndex + 8
        }
        
        if let image = CGImage(width: 256, height: 192, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1024, space: colourSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
            spectrumScreen.image = NSImage(cgImage: image, size: .zero)
        }
    }
}

