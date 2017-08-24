//
//  Spectrum.swift
//  speccyMac
//
//  Created by John Ward on 16/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation
import Cocoa

class Spectrum: Machine {
    
    var processor: Processor
    var memory:    Memory
    
    var ticksPerFrame:   UInt32 = 69888
    var audioPacketSize: UInt32 = 79
    
    weak var emulatorView:   EmulatorView?
    weak var emulatorScreen: NSImageView?
    weak var lateLabel:      NSTextField?
    
    let brightBit: UInt8 = 0x40
    let flashBit:  UInt8 = 0x80
    let attributeAddress: UInt16 = 22528
    
    var clickCount: UInt32 = 0
    
    var provider: CGDataProvider!
    let colourSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo  = CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue).union(CGBitmapInfo())
    
    var flashCounter = 0
    var invertFlashColours = false
    var borderColourIndex: UInt8
    var borderColour: colour!
    
    var colours = [UInt32](repeating: 0, count: 16)
    
    // Precalculated screen and attribute rows
    var screenRowAddress    = [UInt16](repeating: 0, count: 192)
    var attributeRowAddress = [UInt16](repeating: 0, count: 24)
    
    // Screen image
    var screenBuffer = [UInt8](repeating: 0, count: 32 * 192)
    
    // Attribute image - save colour per row (not 8 rows) to allow hi-colour effects
    var colourBuffer = [UInt8](repeating: 0, count: 32 * 192)
    
    // Bmp pool to render image
    var bmpData = [UInt32](repeating: 0, count: 32 * 8 * 192)
    
    // 8 Spectrum RGB values, plus addition 8 for bright mode.
    let colourTable = [colour(0x000000), colour(0x0000cd), colour(0xcd0000), colour(0xcd00cd),
                       colour(0x00cd00), colour(0x00cdcd), colour(0xcdcd00), colour(0xcdcdcd),
                       colour(0x000000), colour(0x0000ff), colour(0xff0000), colour(0xff00ff),
                       colour(0x00ff00), colour(0x00ffff), colour(0xffff00), colour(0xffffff)]
    
    // Mac key code to spectrum key code
    let keyMap: [UInt16] = [0xfd01, 0xfd02, 0xfd04, 0xfd08, 0xbf10, 0xfd10, 0xfe02, 0xfe04, 0xfe08, 0xfe10,
                            0x0000, 0x7f10, 0xfb01, 0xfb02, 0xfb04, 0xfb08, 0xdf10, 0xfb10, 0xf701, 0xf702,
                            0xf704, 0xf708, 0xef10, 0xf710, 0x0000, 0xef02, 0xef08, 0x0000, 0xef04, 0xef01,
                            0x0000, 0xdf02, 0xdf08, 0x0000, 0xdf04, 0xdf01, 0xbf01, 0xbf02, 0xbf08, 0x0000,
                            0xbf04, 0x0000, 0x0000, 0x7f02, 0x0000, 0x7f08, 0x7f04, 0x0000, 0x0000, 0x7f01,
                            0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0xfe01, 0x0000, 0x0000, 0x0000,
                            0xfe01]
    
    var games = [Game(file: "manic.sna", name: "Manic Miner"),
                 Game(file: "aticatac.sna", name: "Atic Atac"),
                 Game(file: "brucelee.sna", name: "Bruce Lee"),
                 Game(file: "deathchase.sna", name: "3D Deathchase"),
                 Game(file: "JetPac.sna", name: "Jetpac"),
                 Game(file: "monty.sna", name: "Wanted: Monty Mole"),
                 Game(file: "spacies.sna", name: "Space Invaders (unfinished)"),
                 Game(file: "thehobbit.sna", name: "The Hobbit"),
                 Game(file: "jetsetw.sna", name: "Jet Set Willy"),
                 Game(file: "techted.sna", name: "Technician Ted"),
                 Game(file: "uridium.sna", name: "Uridium"),
                 Game(file: "cobra.sna", name: "Cobra"),
                 Game(file: "cybernoid1.sna", name: "Cybernoid"),
                 Game(file: "cybernoid2.sna", name: "Cybernoid 2"),
                 Game(file: "dynadan.sna", name: "Dynamite Dan"),
                 Game(file: "greenberet.sna", name: "Green Beret"),
                 Game(file: "headoverheels.sna", name: "Head Over Heels"),
                 Game(file: "hypersports.sna", name: "Hypersports"),
                 Game(file: "JetMan.sna", name: "Lunar Jetman"),
                 Game(file: "sabre.sna", name: "Sabre Wulf"),
                 Game(file: "starquake.sna", name: "Starquake"),
                 Game(file: "chuckie.sna", name: "Chuckie Egg"),
                 Game(file: "batty.sna", name: "Batty"),
                 Game(file: "testz80.sna", name: "Z80 test")
    ]
    
    init() {
        memory = Memory("48.rom")
        processor = Z80(memory: memory)
        
        // Populate colour tables
        for (colourIndex, colour) in colourTable.enumerated() {
            let rComp = UInt32(colour.r) << 8
            let gComp = UInt32(colour.g) << 16
            let bComp = UInt32(colour.b) << 24
            colours[colourIndex] = rComp | gComp | bComp | UInt32(0xff)
        }
        
        
        
        // Precalculate screen and colour row addresses
        var rowNum = 0
        for row in 0..<24 {
            for pixelRow in 0..<8 {
                let dataByteHigh = 0x40 | (row & 0x18) | (pixelRow % 8)
                let dataByteLow  = ((row & 0x7) << 5)
                
                let address:UInt16 = UInt16((dataByteHigh) << 8) + UInt16(dataByteLow)
                screenRowAddress[rowNum] = address

                rowNum = rowNum + 1
            }
            
            attributeRowAddress[row] = attributeAddress + (32 * UInt16(row))
        }
        
        borderColourIndex = 255
        
        provider = CGDataProvider(dataInfo: nil, data: bmpData, size: 4, releaseData: {
            (info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) -> () in
        })!        
    }
    
    final func captureRow(_ row: UInt16) {
        var pixelAddress  = screenRowAddress[row]
        var colourAddress = attributeRowAddress[row >> 3]
        
        var index = Int(row << 5)
        for _ in 0..<32 {
            screenBuffer[index] = memory.get(pixelAddress)
            colourBuffer[index] = memory.get(colourAddress)
            
            pixelAddress  = pixelAddress + 1
            colourAddress = colourAddress + 1
            index = index + 1
        }
    }
    
    final func refreshScreen() {
        if processor.lateFrames > 1 {
            self.lateLabel?.stringValue = "Late \(processor.lateFrames)"
            self.lateLabel?.isHidden = false
        } else {
            self.lateLabel?.isHidden = true
        }
        
        self.emulatorView?.layer?.backgroundColor = CGColor(red: borderColour.rf, green: borderColour.gf, blue: borderColour.bf, alpha: 1.0)
        
        flashCounter = flashCounter + 1
        if flashCounter == 16 {
            invertFlashColours = !invertFlashColours
            flashCounter = 0
        }
        
        var bmpIndex = 0
        
        for index in 0..<192 * 32 {
            let byte      = screenBuffer[index]
            let attribute = colourBuffer[index]
            
            let colourOffset:UInt8 = attribute & brightBit > 0 ? 8 : 0
            
            var ink   = colours[(attribute & 0x07) + colourOffset]
            var paper = colours[((attribute & 0x38) >> 3) + colourOffset]
            
            if attribute & flashBit > 0 && invertFlashColours {
                let temp = paper
                paper = ink
                ink = temp
            }
            
            bmpData[bmpIndex + 0] = (byte & 0x80) > 0 ? ink : paper
            bmpData[bmpIndex + 1] = (byte & 0x40) > 0 ? ink : paper
            bmpData[bmpIndex + 2] = (byte & 0x20) > 0 ? ink : paper
            bmpData[bmpIndex + 3] = (byte & 0x10) > 0 ? ink : paper
            bmpData[bmpIndex + 4] = (byte & 0x08) > 0 ? ink : paper
            bmpData[bmpIndex + 5] = (byte & 0x04) > 0 ? ink : paper
            bmpData[bmpIndex + 6] = (byte & 0x02) > 0 ? ink : paper
            bmpData[bmpIndex + 7] = (byte & 0x01) > 0 ? ink : paper
            
            bmpIndex = bmpIndex + 8
        }
        
        if let image = CGImage(width: 256, height: 192, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1024, space: colourSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
            emulatorScreen?.image = NSImage(cgImage: image, size: .zero)
        }
    }
    
    final func input(_ high: UInt8, low: UInt8) -> UInt8 {
        var byte: UInt8 = 0x00
        
        if low == 0xfe {            // keyboard port
            let downKeys = emulatorView?.keysDown ?? []            
            
            var keysDown: [UInt16] = []
            for key in downKeys {
                if key < keyMap.count  {
                    if keyMap[key] > 0 {
                        keysDown.append(keyMap[key])
                    }
                }
            }
            
            var keys: Array<UInt8> = [0xbf, 0xbf, 0xbf, 0xbf, 0xbf, 0xbf, 0xbf, 0xbf]
            
            for key in keysDown {
                let row: UInt8 = UInt8(key >> 8)
                let val: UInt8 = UInt8(key & 0xff)
                
                if let keyNum = [0xfe, 0xfd, 0xfb, 0xf7, 0xef, 0xdf, 0xbf, 0x7f].index(of: row) {
                    var thisKey: UInt8 = keys[keyNum]
                    thisKey &= ~val
                    keys[keyNum] = thisKey
                }
            }
            
            switch high {
            case 0xfe:
                byte = keys[0]
            case 0xfd:
                byte = keys[1]
            case 0xfb:
                byte = keys[2]
            case 0xf7:
                byte = keys[3]
            case 0xef:
                byte = keys[4]
            case 0xdf:
                byte = keys[5]
            case 0xbf:
                byte = keys[6]
            case 0x7f:
                byte = keys[7]
            case 0x7e:
                byte = keys[0] & keys[7]
            case 0x00:
                byte = keys[0] & keys[1] & keys[2] & keys[3] & keys[4] & keys[5] & keys[6] & keys[7]
            default:
                byte = 0xbf
                let value = high ^ 0xff
                var bit: UInt8 = 0x01
                
                for key in keys {
                    if value & bit > 0 {
                        byte = byte & key
                    }
                    bit = bit << 1
                }
            }
        } else if low == 0x1f {     // kempston port
            let downKeys = emulatorView?.keysDown ?? []
            
            let padKeys: [UInt16] = [124, 123, 125, 126, 50]  // cursor keys and ` (to the left of Z key)
            var bit: UInt8 = 0x01
            
            for key in padKeys {
                if downKeys.contains(key) {
                    byte |= bit
                }
                bit = bit << 1
            }
        } else if low == 0xff {     // video beam port
            byte = 0xff
            if processor.videoRow >= 64 && processor.videoRow <= 255 {
                if processor.ula >= 24 && processor.ula <= 152 {
                    let rowNum = processor.videoRow - 64
                    let attribAddress = self.attributeAddress + ((rowNum >> 3) << 5)
                    let col = (processor.ula - 24) >> 2
                    byte = memory.get(attribAddress + UInt16(col & 0xffff))
                }
            }
        } else {
            byte = 0xff
        }
        
        Z80.f.value = (Z80.f.value & Z80.cBit) | Z80.sz53pvTable[byte]
        return byte
    }
    
    final func output(_ port: UInt8, byte: UInt8) {
        if port == 0xfe {
            if borderColourIndex != (byte & 0x07) {
                borderColourIndex = byte & 0x07
                borderColour = colourTable[borderColourIndex]
            }
            
            if byte & 0x10 > 0 {
                clickCount = clickCount + 1
            }
        }
    }
    
    final func playSound() {
        if clickCount > 0 {
            clickCount = 0
        }
    }
    
    func loadGame(_ game: String) {
        processor.pause()
        
        if let _ = Loader(game, z80: processor as! Z80) {
            print("loaded \(game)")
            clickCount = 0
            processor.unpause()
        } else {
            print("couldnt load \(game)")
        }
    }
}
