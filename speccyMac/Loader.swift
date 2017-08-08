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
                        sna(data)
                        
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
        
        i = data[0]
        
        exhl = (UInt16(data[2]) << 8) + UInt16(data[1])
        exde = (UInt16(data[4]) << 8) + UInt16(data[3])
        exbc = (UInt16(data[6]) << 8) + UInt16(data[5])
        exaf = (UInt16(data[8]) << 8) + UInt16(data[7])
        
        hl = (UInt16(data[10]) << 8) + UInt16(data[9])
        de = (UInt16(data[12]) << 8) + UInt16(data[11])
        bc = (UInt16(data[14]) << 8) + UInt16(data[13])
        iy = (UInt16(data[16]) << 8) + UInt16(data[15])
        ix = (UInt16(data[18]) << 8) + UInt16(data[17])
        
        if data[19] & 0x04 > 0 {
            interrupts = true
        } else {
            interrupts = false
        }
        
        r = data[20]
        
        af = (UInt16(data[22]) << 8) + UInt16(data[21])
        sp = (UInt16(data[24]) << 8) + UInt16(data[23])
        
        interruptMode = data[25]
        borderColour = data[26]
        
        let start = memory.romSize
        
        for jx in 0..<data.count - 27 {
            memory.set(start + UInt16(jx), byte: data[jx + 27])
        }
        
        let lo = memory.get(sp)
        sp = sp &+ 1
        let hi = memory.get(sp)
        sp = sp &+ 1
        
        pc = (UInt16(hi) << 8) + UInt16(lo)
        
        memory.set(sp &- 1, byte: 0)
        memory.set(sp &- 2, byte: 0)
        
        print("game loaded!")
    }
}
