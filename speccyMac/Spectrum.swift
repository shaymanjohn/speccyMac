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

    let ticksPerFrame: Int = 69888

    var clicks: UInt8 = 0

    var ula:      UInt32 = 0
    var videoRow: UInt16 = 0

    // Contended memory delay table - indexed by T-state within frame
    let contentionTable = UnsafeMutablePointer<UInt8>.allocate(capacity: 69888)

    weak var emulatorView:   EmulatorInputView?
    weak var screenLayer:    CALayer?

    let brightBit: UInt8 = 0x40
    let flashBit:  UInt8 = 0x80
    let attributeAddress: UInt16 = 22528

    let colourSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo  = CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue).union(CGBitmapInfo())
    var bitmapContext: CGContext!

    var flashCounter = 0
    var invertFlashColours = false
    var borderColourIndex: UInt8 = 7

    let beeper = AudioStreamer()

    let colours = UnsafeMutablePointer<UInt32>.allocate(capacity: 16)

    // Precalculated screen and attribute rows
    let screenRowAddress    = UnsafeMutablePointer<UInt16>.allocate(capacity: 192)
    let attributeRowAddress = UnsafeMutablePointer<UInt16>.allocate(capacity: 24)

    // Screen image
    let screenBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 32 * 192)

    // Attribute image - save colour per row (not 8 rows) to allow hi-colour effects
    let colourBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 32 * 192)
    
    // Border colour per line (written by emulation thread)
    let borderBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
    
    // Snapshot of border buffer for rendering (copied at frame end, read by main thread)
    let borderSnapshot = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)

    // Bmp pool to render image (320x288 = screen + border)
    // 32px border left/right, 48px border top/bottom
    let bmpData = UnsafeMutablePointer<UInt32>.allocate(capacity: 320 * 288)
    
    // Border dimensions
    let borderLeftPx = 32
    let borderTopLines = 48
    let borderBottomLines = 48
    let totalWidth = 320
    let totalHeight = 288

    // 8 Spectrum RGB values, plus addition 8 for bright mode.
    let colourTable = [Colour(0x000000), Colour(0x0000cd), Colour(0xcd0000), Colour(0xcd00cd),
                       Colour(0x00cd00), Colour(0x00cdcd), Colour(0xcdcd00), Colour(0xcdcdcd),
                       Colour(0x000000), Colour(0x0000ff), Colour(0xff0000), Colour(0xff00ff),
                       Colour(0x00ff00), Colour(0x00ffff), Colour(0xffff00), Colour(0xffffff)]

    // Mac key code to spectrum key code
    let keyMap: [UInt16] = [0xfd01, 0xfd02, 0xfd04, 0xfd08, 0xbf10, 0xfd10, 0xfe02, 0xfe04, 0xfe08, 0xfe10,
                            0x0000, 0x7f10, 0xfb01, 0xfb02, 0xfb04, 0xfb08, 0xdf10, 0xfb10, 0xf701, 0xf702,
                            0xf704, 0xf708, 0xef10, 0xf710, 0x0000, 0xef02, 0xef08, 0x0000, 0xef04, 0xef01,
                            0x0000, 0xdf02, 0xdf08, 0x0000, 0xdf04, 0xdf01, 0xbf01, 0xbf02, 0xbf08, 0x0000,
                            0xbf04, 0x0000, 0x0000, 0x7f02, 0x0000, 0x7f08, 0x7f04, 0x0000, 0x0000, 0x7f01,
                            0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0xfe01, 0x0000, 0x0000, 0x0000,
                            0xfe01]

    let games = [Game(file: "manic.sna", name: "Manic Miner"),
                 Game(file: "brucelee.sna", name: "Bruce Lee (.sna)"),
                 Game(file: "deathchase.sna", name: "Deathchase"),
                 Game(file: "monty.sna", name: "Wanted: Monty Mole"),
                 Game(file: "spacies.sna", name: "Space Invaders (unfinished)"),
                 Game(file: "thehobbit.sna", name: "The Hobbit"),
                 Game(file: "testz80.sna", name: "Z80 test"),
                 Game(file: "jetsetw.sna", name: "Jet Set Willy"),
                 Game(file: "techted.sna", name: "Technician Ted (.sna)"),
                 Game(file: "uridium.sna", name: "Uridium"),
                 Game(file: "cobra.sna", name: "Cobra"),
                 Game(file: "cybernoid1.sna", name: "Cybernoid"),
                 Game(file: "cybernoid2.sna", name: "Cybernoid 2"),
                 Game(file: "dynadan.sna", name: "Dynamite Dan"),
                 Game(file: "greenberet.sna", name: "Green Beret"),
                 Game(file: "headoverheels.sna", name: "Head Over Heels"),
                 Game(file: "hypersports.sna", name: "Hypersports"),
                 Game(file: "starquake.sna", name: "Starquake"),
                 Game(file: "chuckie.sna", name: "Chuckie Egg"),
                 Game(file: "batty.sna", name: "Batty"),
                 Game(file: "batman.sna", name: "Batman"),
                 
                 Game(file: "brucelee.z80", name: "Bruce Lee (.z80)"),      // v1 compressed
                 Game(file: "technted.z80", name: "Technician Ted (.z80)"), // v1 compressed
                 Game(file: "aquaplane.z80", name: "Aquaplane (.z80)")
    ]

    init() {
        memory = Memory("48.rom")
        processor = ZilogZ80(memory: memory)
        
        // Set back-reference so Memory can apply contention delays
        memory.machine = self

        // Populate colour tables
        for (colourIndex, colour) in colourTable.enumerated() {
            let rComp = UInt32(colour.r) << 8
            let gComp = UInt32(colour.g) << 16
            let bComp = UInt32(colour.b) << 24
            colours[colourIndex] = rComp | gComp | bComp | UInt32(0xff)
        }
        
        for ix in 0..<1024 {
            borderBuffer[ix] = 0
        }

        // Precalculate screen and colour row addresses
        var rowNum = 0
        for row in 0..<24 {
            for pixelRow in 0..<8 {
                let dataByteHigh = 0x40 | (row & 0x18) | (pixelRow % 8)
                let dataByteLow  = ((row & 0x7) << 5)

                let address:UInt16 = UInt16((dataByteHigh) << 8) + UInt16(dataByteLow)
                screenRowAddress[rowNum] = address

                rowNum += 1
            }

            attributeRowAddress[row] = attributeAddress + (32 * UInt16(row))
        }

        beeper.machine = self
        
        // Create bitmap context backed by bmpData (reused every frame)
        let contextInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
        bitmapContext = CGContext(data: UnsafeMutableRawPointer(bmpData), width: 320, height: 288,
                                  bitsPerComponent: 8, bytesPerRow: 320 * 4,
                                  space: colourSpace, bitmapInfo: contextInfo.rawValue)
        bitmapContext?.interpolationQuality = .none
        
        // Build contended memory delay table
        // 48K Spectrum: 312 scanlines per frame, 224 T-states per scanline = 69888 T-states/frame
        // Display area: scanlines 64-255 (192 lines)
        // Each display scanline: first 128 T-states are contended, remaining 96 are not
        // Contention pattern repeats every 8 T-states: 6, 5, 4, 3, 2, 1, 0, 0
        let contentionPattern: [UInt8] = [6, 5, 4, 3, 2, 1, 0, 0]
        
        for i in 0..<69888 {
            contentionTable[i] = 0
        }
        
        for line in 64..<256 {
            let lineStart = line * 224
            for col in 0..<128 {
                contentionTable[lineStart + col] = contentionPattern[col % 8]
            }
        }
        
        // Useful for slow machines, show how many late counts after 10 seconds elapsed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            print("Late count is \(self.processor.lateFrames)")
        }
    }
    
    // MARK: - Contended memory/IO
    
    /// Apply contention for I/O port access.
    /// This adds ONLY the extra contention wait states. The base I/O timing
    /// is already accounted for in the opcode's T-state count.
    ///
    /// On 48K Spectrum, I/O contention depends on whether the port address is
    /// in the contended range AND whether it's a ULA port (low bit = 0):
    ///
    /// Contended address + ULA port: C:1, C:3 pattern
    /// Contended address + non-ULA port: C:1, C:1, C:1, C:1 pattern
    /// Non-contended address + ULA port: N:1, C:3 pattern
    /// Non-contended address + non-ULA port: no contention
    ///
    /// Only the contention delays (C parts) are added here.
    @inline(__always) final func contendIO(_ port: UInt16) {
        let isContendedAddress = (port >= 0x4000 && port <= 0x7FFF)
        let isULAPort = (port & 1) == 0
        
        if isContendedAddress {
            // Contention at the current T-state position
            let delay = UInt32(contentionTable[Int(processor.counter % UInt32(ticksPerFrame))])
            processor.incCounters(delay)
        } else if isULAPort {
            // Non-contended address but ULA port: contention occurs 1 T-state later
            let tstate = (processor.counter + 1) % UInt32(ticksPerFrame)
            let delay = UInt32(contentionTable[Int(tstate)])
            processor.incCounters(delay)
        }
        // Non-contended + non-ULA: no contention
    }

    final func captureRow(_ row: UInt16) {
        var pixelAddress  = screenRowAddress[Int(row)]
        var colourAddress = attributeRowAddress[Int(row >> 3)]

        let index = Int(row << 5)
        for ix in index..<index+32 {
            screenBuffer[ix] = memory.get(pixelAddress)
            colourBuffer[ix] = memory.get(colourAddress)

            pixelAddress  += 1
            colourAddress += 1
        }
    }

    final func frameCompleted() {
        flashCounter += 1
        if flashCounter == 16 {
            invertFlashColours = !invertFlashColours
            flashCounter = 0
        }

        // Render full 320x288 image with border
        // Layout: 48 rows top border (videoRow 16..63), 192 rows screen (videoRow 64..255),
        //         48 rows bottom border (videoRow 256..303)
        // Each row: 32px left border + 256px screen + 32px right border = 320px
        
        var ink:   UInt32 = 0
        var paper: UInt32 = 0
        var temp:  UInt32 = 0
        var byte: UInt8 = 0
        var attribute: UInt8 = 0
        var colourOffset: UInt8 = 0
        
        // Top border (48 scanlines from videoRow 16..63)
        for row in 0..<borderTopLines {
            let borderColour = colours[Int(borderSnapshot[row + 16] & 0x07)]
            let rowStart = row * totalWidth
            for x in 0..<totalWidth {
                bmpData[rowStart + x] = borderColour
            }
        }
        
        // Main screen area (192 scanlines from videoRow 64..255)
        for screenRow in 0..<192 {
            let bitmapRow = screenRow + borderTopLines
            let rowStart = bitmapRow * totalWidth
            let borderColour = colours[Int(borderSnapshot[screenRow + 64] & 0x07)]
            
            // Left border
            for x in 0..<borderLeftPx {
                bmpData[rowStart + x] = borderColour
            }
            
            // Screen pixels
            let bufferRow = screenRow * 32
            for col in 0..<32 {
                byte      = screenBuffer[bufferRow + col]
                attribute = colourBuffer[bufferRow + col]
                
                colourOffset = attribute & brightBit > 0 ? 8 : 0
                ink   = colours[Int((attribute & 0x07) + colourOffset)]
                paper = colours[Int(((attribute & 0x38) >> 3) + colourOffset)]
                
                if invertFlashColours && (attribute & flashBit) > 0 {
                    temp = paper
                    paper = ink
                    ink = temp
                }
                
                let pixelStart = rowStart + borderLeftPx + (col * 8)
                bmpData[pixelStart + 0] = (byte & 0x80) > 0 ? ink : paper
                bmpData[pixelStart + 1] = (byte & 0x40) > 0 ? ink : paper
                bmpData[pixelStart + 2] = (byte & 0x20) > 0 ? ink : paper
                bmpData[pixelStart + 3] = (byte & 0x10) > 0 ? ink : paper
                bmpData[pixelStart + 4] = (byte & 0x08) > 0 ? ink : paper
                bmpData[pixelStart + 5] = (byte & 0x04) > 0 ? ink : paper
                bmpData[pixelStart + 6] = (byte & 0x02) > 0 ? ink : paper
                bmpData[pixelStart + 7] = (byte & 0x01) > 0 ? ink : paper
            }
            
            // Right border
            for x in (borderLeftPx + 256)..<totalWidth {
                bmpData[rowStart + x] = borderColour
            }
        }
        
        // Bottom border (48 scanlines from videoRow 256..303)
        for row in 0..<borderBottomLines {
            let borderColour = colours[Int(borderSnapshot[row + 256] & 0x07)]
            let rowStart = (row + borderTopLines + 192) * totalWidth
            for x in 0..<totalWidth {
                bmpData[rowStart + x] = borderColour
            }
        }

        if let image = bitmapContext.makeImage() {
            screenLayer?.contents = image
        }
    }

    func soundFrameCompleted() {
        beeper.endFrame()
    }

// swiftlint:disable cyclomatic_complexity
    final func input(_ high: UInt8, low: UInt8) -> UInt8 {
        var byte: UInt8 = 0x00

        if low == 0xfe {            // keyboard port
            let downKeys = emulatorView?.keysDown ?? []

            var keysDown: [UInt16] = []
            for key in downKeys {
                if key < keyMap.count && keyMap[key] > 0 {
                    keysDown.append(keyMap[key])
                }
            }

            var keys: [UInt8] = [0xbf, 0xbf, 0xbf, 0xbf, 0xbf, 0xbf, 0xbf, 0xbf]

            for key in keysDown {
                let row: UInt8 = UInt8(key >> 8)
                let val: UInt8 = UInt8(key & 0xff)

                if let keyNum = [0xfe, 0xfd, 0xfb, 0xf7, 0xef, 0xdf, 0xbf, 0x7f].firstIndex(of: row) {
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
            if videoRow >= 64 && videoRow <= 255 {
                if ula >= 24 && ula <= 152 {
                    let rowNum = videoRow - 64
                    let attribAddress = attributeAddress + ((rowNum >> 3) << 5)
                    let col = (ula - 24) >> 2
                    byte = memory.get(attribAddress + UInt16(col & 0xffff))
                }
            }
        } else {
            byte = 0xff
        }

        return byte
    }

    final func output(_ port: UInt8, byte: UInt8) {
        if port == 0xfe {
            borderColourIndex = byte & 0x07
            clicks = byte
        }
    }

    func tick() {
        beeper.updateSample(processor.counter, beep: clicks)

        if ula >= 224 {
            borderBuffer[Int(videoRow)] = borderColourIndex
                
            switch videoRow {
            case 64...255:
                captureRow(videoRow - 64)

            case 311:
                soundFrameCompleted()
                // Snapshot border buffer before dispatching (emulation thread will overwrite it)
                for i in 0..<312 {
                    borderSnapshot[i] = borderBuffer[i]
                }
                DispatchQueue.main.async {
                    self.frameCompleted()
                }

            default:
                break
            }

            ula -= 224
            videoRow += 1
        }
    }

    func loadGame(_ gameUrl: URL) {
        processor.pause()
        clicks = 0

        if let z80 = processor as? ZilogZ80,
            Loader(gameUrl, z80: z80) != nil {
            videoRow = 0
            ula = 0
            processor.counter = 0
            processor.unpause()
        } else {
            let alert = NSAlert()
            alert.messageText = "Couldn't load:\n\n\(gameUrl)"
            alert.runModal()
        }
    }
}
