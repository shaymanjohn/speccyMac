//
//  Loader.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

class Loader {
    
    var af: UInt16 = 0
    var hl: UInt16 = 0
    var bc: UInt16 = 0
    var de: UInt16 = 0
    
    var exaf: UInt16 = 0
    var exhl: UInt16 = 0
    var exbc: UInt16 = 0
    var exde: UInt16 = 0
    
    var sp: UInt16 = 0
    var pc: UInt16 = 0
    
    var ix: UInt16 = 0
    var iy: UInt16 = 0
    
    var r: UInt8 = 0
    var i: UInt8 = 0
    
    var interrupts:    Bool  = false
    var interruptMode: UInt8 = 0
    
    var borderColour: UInt8 = 0
    
    var memory: Memory!
    
    init?(_ game: String, memory: Memory) {
        
        self.memory = memory
        
        var gameType = (game as NSString).pathExtension.lowercased()
        
        if gameType == "zip" {
            gameType = "zip"
        }
        
        if let gameUrl = Bundle.main.url(forResource: game, withExtension: "") {
            let gameData: Data?
            
            do {
                try gameData = Data.init(contentsOf: gameUrl)
                
                if let data = gameData {
                    switch gameType {
                        
                    case "sna":
                        self.sna(data)
                        
                    default:
                        print("Unhandled game type: \(gameType)")
                        return nil
                    }
                }
            } catch {
                print("Couldn't get data from \(game)")
                return nil
            }
        }
    }
    
    func sna(_ data: Data) {
        if data.count > (48 * 1024) + 27 {
            print("Not a 48k image")
            return
        }
        
        self.i = data[0]
        
        self.exhl = (UInt16(data[2]) << 8) + UInt16(data[1])
        self.exde = (UInt16(data[4]) << 8) + UInt16(data[3])
        self.exbc = (UInt16(data[6]) << 8) + UInt16(data[5])
        self.exaf = (UInt16(data[8]) << 8) + UInt16(data[7])
        
        self.hl = (UInt16(data[10]) << 8) + UInt16(data[9])
        self.de = (UInt16(data[12]) << 8) + UInt16(data[11])
        self.bc = (UInt16(data[14]) << 8) + UInt16(data[13])
        self.iy = (UInt16(data[16]) << 8) + UInt16(data[15])
        self.ix = (UInt16(data[18]) << 8) + UInt16(data[17])
        
        if data[19] & 0x04 > 0 {
            self.interrupts = true
        } else {
            self.interrupts = false
        }
        
        self.r = data[20]
        
        self.af = (UInt16(data[22]) << 8) + UInt16(data[21])
        self.sp = (UInt16(data[24]) << 8) + UInt16(data[23])
        
        self.interruptMode = data[25]
        self.borderColour = data[26]
        
        let start = self.memory.romSize;
        
        for jx in 0..<data.count - 27 {
            self.memory.set(start + UInt16(jx), byte: data[jx + 27])
        }
        
        let lo = self.memory.get(self.sp);
        self.sp = self.sp + 1;
        let hi = self.memory.get(self.sp);
        self.sp = self.sp + 1;
        
        self.pc = (UInt16(hi) << 8) + UInt16(lo);
        
        self.memory.set(self.sp - 1, byte: 0)
        self.memory.set(self.sp - 2, byte: 0)
        
        print("game loaded!")
    }
}
