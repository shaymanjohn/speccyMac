//
//  Z80+core.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
    
    final func setRelativePC(_ byte: UInt8) {
        pc = byte > 127 ? pc &- (UInt16(256) - UInt16(byte)) : pc &+ UInt16(byte)
    }
    
    final func rst(_ address: UInt16) {
        memory.push(pc &+ 1)
        pc = address
        pc = pc &- 1
    }
    
    final func portOut(_ port: UInt8, byte: UInt8) {
        if port == 0xfe {
            machine?.borderColour = byte & 0x07
            
            if byte & 0x10 > 0 {
                if let clicks = machine?.clickCount {
                    machine!.clickCount = clicks + 1
                }
            }
        }
    }
    
    final func portIn(reg: Register, high: UInt8, low: UInt8) {
        var byte: UInt8 = 0x00
        
        if low == 0xfe{            // keyboard
            var keys: Array<UInt8> = [0xbf, 0xbf, 0xbf, 0xbf, 0xbf, 0xbf, 0xbf, 0xbf]
            
            if let keysDown = machine?.keysDown, keysDown.count > 0 {
                for key in keysDown {
                    let row: UInt8 = UInt8(key >> 8)
                    let val: UInt8 = UInt8(key & 0xff)

                    if let keyNum = [0xfe, 0xfd, 0xfb, 0xf7, 0xef, 0xdf, 0xbf, 0x7f].index(of: row) {
                        var thisKey: UInt8 = keys[keyNum]
                        thisKey &= ~val
                        keys[keyNum] = thisKey
                    }
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
                var bit:UInt8 = 0x01
                for loop in 0..<8 {
                    if value & bit > 0 {
                        byte = byte & keys[loop]
                    }
                    bit = bit << 1
                }
            }
//            if byte != 0xbf {
//                log = true
//            }
        } else if low == 0x1f {     // kempston
            byte = machine?.padDown ?? 0x00
        } else if low == 0xff {     // video beam
            if (videoRow < 64) || (videoRow > 255) {
                byte = 0xff
            } else {
                if (ula >= 24) && (ula <= 152) {
                    let rowNum = videoRow - 64
                    let attribAddress = 22528 + ((rowNum >> 3) << 5)
                    let col = UInt16((ula - 24) >> 2)
                    byte = memory.get(attribAddress + col)
                } else {
                    byte = 0xff
                }
            }
        } else {
            byte = 0xff
        }
        
        Z80.f.value = (Z80.f.value & Z80.cBit) | Z80.sz53pvTable[byte]
        reg.value = byte
    }
    
}
