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
    var keyboard:      [UInt16]? { get }
}

struct colour {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

class Spectrum: NSViewController {
    
    @IBOutlet weak var spectrumScreen: NSImageView!
    @IBOutlet weak var lateLabel: NSTextField!
    
    var z80: Z80!
    var border: UInt8 = 0
    var clicksCount: UInt32 = 0
    
    let colourSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue).union(CGBitmapInfo())
    
    // bmp pool to render image
    var bmpData = [UInt32](repeating: 0, count: 32 * 8 * 24 * 8)
    
    // precalculated screen and attribute rows
    var screenRowAddress    = [UInt16](repeating: 0, count: 192)
    var attributeRowAddress = [UInt16](repeating: 0, count: 24)
    
    // Screen image and saved version
    var screenCopy = [UInt8](repeating: 0, count: 32 * 192)
    var screenCopySave = [UInt8](repeating: 255, count: 32 * 192)
    
    // Attribute image and saved version
    var colourCopy = [UInt8](repeating: 0, count: 32 * 192)
    var colourCopySave = [UInt8](repeating: 255, count: 32 * 192)
    
    var keysDown: [UInt16 : Bool] = [:]
    
    var provider: CGDataProvider!
    
    let colourTable = [colour(r: 0x00, g: 0x00, b: 0x00), colour(r: 0x00, g: 0x00, b: 0xcd), colour(r: 0xcd, g: 0x00, b: 0x00), colour(r: 0xcd, g: 0x00, b: 0xcd),
                       colour(r: 0x00, g: 0xcd, b: 0x00), colour(r: 0x00, g: 0xcd, b: 0xcd), colour(r: 0xcd, g: 0xcd, b: 0x00), colour(r: 0xcd, g: 0xcd, b: 0xcd),
                       colour(r: 0x00, g: 0x00, b: 0x00), colour(r: 0x00, g: 0x00, b: 0xff), colour(r: 0xff, g: 0x00, b: 0x00), colour(r: 0xff, g: 0x00, b: 0xff),
                       colour(r: 0x00, g: 0xff, b: 0x00), colour(r: 0x00, g: 0xff, b: 0xff), colour(r: 0xff, g: 0xff, b: 0x00), colour(r: 0xff, g: 0xff, b: 0xff)]
    
//    const UInt16 keyTable[] = {
//    0xf701, 0xf702, 0xf704, 0xf708, 0xf710, 0xef10, 0xef08, 0xef04, 0xef02, 0xef01,
//    0xfb01, 0xfb02, 0xfb04, 0xfb08, 0xfb10, 0xdf10, 0xdf08, 0xdf04, 0xdf02, 0xdf01,
//    0xfd01, 0xfd02, 0xfd04, 0xfd08, 0xfd10, 0xbf10, 0xbf08, 0xbf04, 0xbf02, 0xbf01,
//    0xfe01, 0xfe02, 0xfe04, 0xfe08, 0xfe10, 0x7f10, 0x7f08, 0x7f04, 0x7f02, 0x7f01,
//    0xff0a, 0xff08, 0xff09, 0xff02, 0xff01, 0xff06, 0xff04, 0xff05, 0xff10
//    };
    
    var colours = [UInt32](repeating: 0, count: 16)
    
    let memory = Memory("48.rom")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // allows us to use NSView for border colour
        self.view.wantsLayer = true
        
        // Spectrum colour pallette
        var colourIndex = 0
        for colour in colourTable {
            let rComp = UInt32(colour.r) << 8
            let gComp = UInt32(colour.g) << 16
            let bComp = UInt32(colour.b) << 24
            colours[colourIndex] = rComp | gComp | bComp | UInt32(0xff)
            colourIndex = colourIndex + 1
        }
        
        // Precalculate screen and colour rows
        var rowNum = 0
        for row in 0..<24 {
            for pixelRow in 0..<8 {
                let dataByteHigh = 0x40 | (row & 0x18) | (pixelRow % 8)
                let dataByteLow  = ((row & 0x7) << 5)
                
                let address:UInt16 = UInt16((dataByteHigh) << 8) + UInt16(dataByteLow)
                screenRowAddress[rowNum] = address
                
                rowNum = rowNum + 1
            }
            
            attributeRowAddress[row] = 22528 + (32 * UInt16(row))
        }
        
        // Used in bitmap generator
        provider = CGDataProvider(dataInfo: nil, data: bmpData, size: 4, releaseData: {
            (info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) -> () in
        })!
        
        z80 = Z80(memory: memory)
        z80.machine = self
        
        DispatchQueue.global().async {
            self.z80.start()
        }
        
        let allGames = ["manic.sna", "aticatac.sna", "brucelee.sna",
                        "deathchase.sna", "JetPac.sna", "monty.sna",
                        "spacies.sna", "thehobbit.sna", "testz80.sna",
                        "jetsetw.sna", "techted.sna", "uridium.sna",
                        "testz80.sna"]
        
        var gameIndex = Int(arc4random() % UInt32(allGames.count))
        gameIndex = 0
        
        loadGame(allGames[gameIndex], z80: z80)
    }
}

func loadGame(_ game: String, z80: Z80) {
    z80.paused = true
    
    Thread.sleep(forTimeInterval: 0.01)
    
    if let _ = Loader(game, z80: z80) {
        print("loaded \(game)")
    } else {
        print("couldnt load \(game)")
    }
    
    z80.paused = false
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
    
    var keyboard: [UInt16]? {
        get {
            let downKeys = Array((view as! SpectrumView).keysDown.filter{key in key.value == true}.keys)
            if downKeys.count > 0 {
                return downKeys         // first convert here into machine value
            }
            
            return nil
        }
    }
    
    var borderColour: UInt8 {
        get {
            return border
        }
        
        set {
            border = newValue
            let colour = colourTable[newValue & 0x07]
            
            DispatchQueue.main.async {
                self.view.layer?.backgroundColor = CGColor(red: CGFloat(colour.r) / 255.0, green: CGFloat(colour.g) / 255.0, blue: CGFloat(colour.b) / 255.0, alpha: 1)
            }
        }
    }
    
    final func captureRow(_ row: UInt16) {
        var pixelAddress  = screenRowAddress[row]
        var colourAddress = attributeRowAddress[row >> 3]
        
        var index = Int(row << 5)
        for _ in 0..<32 {
            screenCopy[index] = memory.get(pixelAddress)
            colourCopy[index] = memory.get(colourAddress)
            
            pixelAddress = pixelAddress + 1
            colourAddress = colourAddress + 1
            index = index + 1
        }
    }
    
    final func refreshScreen() {        
        
        self.lateLabel.stringValue = "\(z80.lateFrames)"
        var bmpIndex = 0
        
        for index in 0..<192 * 32 {
            let byte   = screenCopy[index]
            let colour = colourCopy[index]
            
//            if byte != screenCopySave[index] || colour != colourCopySave[index] {
//                screenCopySave[index] = byte
//                colourCopySave[index] = colour
            
                let ink   = colours[colour & 0x07]
                let paper = colours[(colour & 0x38) >> 3]                
            
                bmpData[bmpIndex + 0] = (byte & 0x80) > 0 ? ink : paper
                bmpData[bmpIndex + 1] = (byte & 0x40) > 0 ? ink : paper
                bmpData[bmpIndex + 2] = (byte & 0x20) > 0 ? ink : paper
                bmpData[bmpIndex + 3] = (byte & 0x10) > 0 ? ink : paper
                bmpData[bmpIndex + 4] = (byte & 0x08) > 0 ? ink : paper
                bmpData[bmpIndex + 5] = (byte & 0x04) > 0 ? ink : paper
                bmpData[bmpIndex + 6] = (byte & 0x02) > 0 ? ink : paper
                bmpData[bmpIndex + 7] = (byte & 0x01) > 0 ? ink : paper
//            }
            
            bmpIndex = bmpIndex + 8
        }
        
        if let image = CGImage(width: 256, height: 192, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1024, space: colourSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
            spectrumScreen.image = NSImage(cgImage: image, size: .zero)
        }
    }
}

