//
//  Loader.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

class Loader {
    
    var z80: Z80
    
    init?(_ game: String, z80: Z80) {
        
        self.z80 = z80
        
        let gameType = (game as NSString).pathExtension.lowercased()
//        if gameType == "zip" {
//            gameType = "zip"
//        }
        
        if let gameUrl = Bundle.main.url(forResource: game, withExtension: "") {
            let gameData: Data?
            
            do {
                try gameData = Data.init(contentsOf: gameUrl)
                
                var valid = false
                
                if let data = gameData {
                    switch gameType {
                        
                    case "sna":
                        valid = loadSna(data)
                        
                    default:
                        return nil
                    }
                }
                
                if !valid {
                    return nil
                }
                
                z80.counter = 0
                z80.lateFrames = 0
                z80.halted = false
                z80.ula = 0
                z80.videoRow = 0
                
                if z80.interrupts {
                    z80.iff1 = 1
                    z80.iff2 = 1
                } else {
                    z80.iff1 = 0
                    z80.iff2 = 0
                }
                
            // Sound vars
                //            clicksCount = 0;
                //            beep = false;
                //            soundCounter = 0;
                //            bufferIndex = 0;
                
                //            kempston = 0;
                
            } catch {
                return nil
            }
        }
    }
    
    func loadSna(_ data: Data) -> Bool {
        if data.count > (48 * 1024) + 27 {
            print("Not a 48k image")
            return false
        }
        
        z80.i = data[0]
        
        z80.exhl = (UInt16(data[2]) << 8) + UInt16(data[1])
        z80.exde = (UInt16(data[4]) << 8) + UInt16(data[3])
        z80.exbc = (UInt16(data[6]) << 8) + UInt16(data[5])
        z80.exaf = (UInt16(data[8]) << 8) + UInt16(data[7])
        
        z80.hl.value = (UInt16(data[10]) << 8) + UInt16(data[9])
        z80.de.value = (UInt16(data[12]) << 8) + UInt16(data[11])
        z80.bc.value = (UInt16(data[14]) << 8) + UInt16(data[13])
        z80.iy = (UInt16(data[16]) << 8) + UInt16(data[15])
        z80.ix = (UInt16(data[18]) << 8) + UInt16(data[17])
        
        if data[19] & 0x04 > 0 {
            z80.interrupts = true
        } else {
            z80.interrupts = false
        }
        
        z80.r.value = data[20]
        
        z80.af.value = (UInt16(data[22]) << 8) + UInt16(data[21])
        Z80.sp = (UInt16(data[24]) << 8) + UInt16(data[23])
        
        z80.interruptMode = data[25]
        z80.machine?.output(0xfe, byte: data[26])
        
        let start = z80.memory.romSize
        
        for jx in 0..<data.count - 27 {
            z80.memory.set(start + UInt16(jx), byte: data[jx + 27])
        }
        
        let lo = z80.memory.get(Z80.sp)
        Z80.sp = Z80.sp &+ 1
        let hi = z80.memory.get(Z80.sp)
        Z80.sp = Z80.sp &+ 1
        
        z80.pc = (UInt16(hi) << 8) + UInt16(lo)
        
        z80.memory.set(Z80.sp &- 1, byte: 0)
        z80.memory.set(Z80.sp &- 2, byte: 0)
        
        return true
    }
}
