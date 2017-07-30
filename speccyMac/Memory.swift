//
//  Memory.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

class Memory {
    
    var romSize: UInt16 = 0
    var memory = [UInt8](repeating: 0, count: 65536)
    
    init(_ rom: String) {
        
        if let romUrl = Bundle.main.url(forResource: rom, withExtension: "") {
            let romData: Data?
            
            do {
                try romData = Data.init(contentsOf: romUrl)
                
                if let data = romData {
                    romSize = UInt16(data.count)
                    
                    for ix in 0..<data.count {
                        memory[ix] = data[ix]
                    }
                }
            } catch {
                print("Couldn't get data from \(rom)")
            }
        } else {
            print("Couldn't find rom \(rom)")
        }
    }
    
    @inline(__always) func get(_ address: UInt16) -> UInt8 {
        return memory[Int(address)]
    }
    
    @inline(__always) func set(_ address: UInt16, byte: UInt8) {
        if address >= romSize {
            memory[Int(address)] = byte
        }
    }
}
