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

    let ticksPerFrame: UInt32 = 69888

    var clicks: UInt8 = 0

    var ula:      UInt32 = 0
    var videoRow: UInt16 = 0

    // Contended memory delay table - indexed by T-state within frame
    let contentionTable = UnsafeMutablePointer<UInt8>.allocate(capacity: 69888)

    weak var emulatorView:   EmulatorInputView?
    weak var metalView:      MetalScreenView?

    let attributeAddress: UInt16 = 22528

    var flashCounter = 0
    var invertFlashColours = false
    var borderColourIndex: UInt8 = 7

    let beeper = AudioStreamer()

    // Tape playback engine (feeds the EAR bit during LOAD).
    let tapeDeck = TapeDeck()

    // Last processor counter seen by tick(), used to advance the tape deck.
    private var lastTapeCounter: UInt32 = 0

    let colours = UnsafeMutablePointer<UInt32>.allocate(capacity: 16)

    // Precalculated screen and attribute rows
    let screenRowAddress    = UnsafeMutablePointer<UInt16>.allocate(capacity: 192)
    let attributeRowAddress = UnsafeMutablePointer<UInt16>.allocate(capacity: 24)

    // Screen image (written by emulation thread)
    let screenBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 32 * 192)

    // Attribute image - save colour per row (not 8 rows) to allow hi-colour effects
    // (written by emulation thread)
    let colourBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 32 * 192)

    // Snapshots of screen/colour buffers for rendering (copied at frame end, read by main thread)
    let screenSnapshot = UnsafeMutablePointer<UInt8>.allocate(capacity: 32 * 192)
    let colourSnapshot = UnsafeMutablePointer<UInt8>.allocate(capacity: 32 * 192)
    
    // Border colour per line (written by emulation thread)
    let borderBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
    
    // Snapshot of border buffer for rendering (copied at frame end, read by main thread)
    let borderSnapshot = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)

    // Per-output-row border colour index (288 rows), rebuilt each frame and
    // handed to the GPU. Maps each of the 288 output scanlines to a border colour.
    let borderLine = UnsafeMutablePointer<UInt8>.allocate(capacity: 288)

    // Whether the palette has been uploaded to the Metal view yet.
    private var paletteUploaded = false

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
            let tstate = processor.counter < ticksPerFrame ? processor.counter : processor.counter &- ticksPerFrame
            let delay = UInt32(contentionTable[Int(tstate)])
            processor.incCounters(delay)
        } else if isULAPort {
            // Non-contended address but ULA port: contention occurs 1 T-state later
            let t = processor.counter + 1
            let tstate = t < ticksPerFrame ? t : t &- ticksPerFrame
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

        // Upload the 16-entry palette to the GPU once (the Metal view is wired
        // after this object is constructed, so do it lazily on first frame).
        if !paletteUploaded, let view = metalView {
            view.setPalette(colours)
            paletteUploaded = true
        }

        // Build the per-output-row border colour index (288 rows).
        // Layout matches the original CPU renderer:
        //   top border    rows 0..47    -> borderSnapshot[row + 16]
        //   screen area   rows 48..239  -> borderSnapshot[screenRow + 53]
        //   bottom border rows 240..287 -> borderSnapshot[row + 256]
        for row in 0..<48 {
            borderLine[row] = borderSnapshot[row + 16] & 0x07
        }
        for screenRow in 0..<192 {
            borderLine[screenRow + 48] = borderSnapshot[screenRow + 53] & 0x07
        }
        for row in 0..<48 {
            borderLine[row + 240] = borderSnapshot[row + 256] & 0x07
        }

        // Hand the raw Spectrum data to the GPU; the shader expands pixels,
        // resolves ink/paper/bright/flash, and fills the border.
        metalView?.updateFrame(screen: screenSnapshot,
                               attributes: colourSnapshot,
                               borderLines: borderLine,
                               invertFlash: invertFlashColours)
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

            // Inject the tape EAR input on bit 6 so the ROM loader can read it.
            if tapeDeck.currentLevel {
                byte |= 0x40
            } else {
                byte &= ~0x40
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

    @inline(__always) func tick() {
        if tapeDeck.isActive {
            // Mix the tape EAR level into bit 6 so loading is audible (the ULA
            // routes the tape signal through the speaker on real hardware).
            let beep = tapeDeck.currentLevel ? (clicks | 0x40) : clicks
            beeper.updateSample(processor.counter, beep: beep)

            // Advance the tape by the T-states consumed since the last tick.
            // counter normally increases; at a frame boundary it drops when
            // serviceInterrupts subtracts ticksPerFrame. Only advance on the
            // normal forward case and resync on a wrap (avoids underflow traps).
            let now = processor.counter
            if now >= lastTapeCounter {
                let delta = now - lastTapeCounter
                if delta > 0 {
                    tapeDeck.advance(delta)
                }
            }
            lastTapeCounter = now
        } else {
            beeper.updateSample(processor.counter, beep: clicks)
            lastTapeCounter = processor.counter
        }

        if ula >= 224 {
            borderBuffer[Int(videoRow)] = borderColourIndex
                
            switch videoRow {
            case 64...255:
                captureRow(videoRow - 64)

            case 311:
                soundFrameCompleted()
                // Snapshot buffers before dispatching (emulation thread will overwrite them)
                for i in 0..<312 {
                    borderSnapshot[i] = borderBuffer[i]
                }
                for i in 0..<(32 * 192) {
                    screenSnapshot[i] = screenBuffer[i]
                    colourSnapshot[i] = colourBuffer[i]
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

        let ext = gameUrl.pathExtension.lowercased()
        let type = SupportedGameTypes.allCases.first { $0.rawValue == ext }

        if type?.isTape == true {
            // Tape: reset to the BASIC prompt and load the tape into the deck.
            // The user presses Play and types LOAD "" to start loading.
            if let data = try? Data(contentsOf: gameUrl),
               let pulses = TapLoader.pulses(from: data) {
                tapeDeck.load(pulses: pulses)
                processor.reset()
                videoRow = 0
                ula = 0
                lastTapeCounter = 0
                processor.counter = 0
                processor.unpause()
            } else {
                tapeLoadFailed(gameUrl)
            }
            return
        }

        if let z80 = processor as? ZilogZ80,
            Loader(gameUrl, z80: z80) != nil {
            videoRow = 0
            ula = 0
            processor.counter = 0
            processor.unpause()
        } else {
            tapeLoadFailed(gameUrl)
        }
    }

    private func tapeLoadFailed(_ gameUrl: URL) {
        let alert = NSAlert()
        alert.messageText = "Couldn't load:\n\n\(gameUrl)"
        alert.runModal()
    }

    // MARK: - Tape transport

    var tapeLoaded: Bool { tapeDeck.hasTape }
    var tapePlaying: Bool { tapeDeck.isPlaying }

    func playTape() {
        tapeDeck.play()
    }

    func stopTape() {
        tapeDeck.stop()
    }
}
