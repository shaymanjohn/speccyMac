//
//  Z80Loader.swift
//  speccyMac
//
//  Created by hippietrail on 20/08/2022.
//

import Foundation

// all z80 files have this header
struct V1Header {
    var a: UInt8 = 0
    var f: UInt8 = 0
    var bc: UInt16 = 0
    var hl: UInt16 = 0
    var pc: UInt16 = 0
    var sp: UInt16 = 0
    var i: UInt8 = 0
    var r: UInt8 = 0
    var flags1: UInt8 = 0
    var de: UInt16 = 0
    var exbc: UInt16 = 0
    var exde: UInt16 = 0
    var exhl: UInt16 = 0
    var exa: UInt8 = 0
    var exf: UInt8 = 0
    var iy: UInt16 = 0
    var ix: UInt16 = 0
    var iff: UInt8 = 0
    var iff2: UInt8 = 0
    var flags2: UInt8 = 0
}

class Z80Loader: GameLoaderProtocol {
    
    let z80: ZilogZ80
    
    required init(z80: ZilogZ80) {
        self.z80 = z80
    }
    
    func load(data: Data) -> Bool {
        // if we need to view the data bytes in the debugger
        print((data as NSData).bytes)

        let v1HeaderLen: UInt16 = 30
        if data.count < v1HeaderLen {
            print(".z80 file too short")
            return false
        }

        var v1: V1Header = V1Header()
        v1.a = data[0]
        v1.f = data[1]
        v1.bc = UInt16(data[2]) + (UInt16(data[3]) << 8)
        v1.hl = UInt16(data[4]) + (UInt16(data[5]) << 8)
        v1.pc = UInt16(data[6]) + (UInt16(data[7]) << 8)
        v1.sp = UInt16(data[8]) + (UInt16(data[9]) << 8)
        v1.i = data[10]
        v1.r = data[11]
        v1.flags1 = data[12]
        v1.de = UInt16(data[13]) + (UInt16(data[14]) << 8)
        v1.exbc = UInt16(data[15]) + (UInt16(data[16]) << 8)
        v1.exde = UInt16(data[17]) + (UInt16(data[18]) << 8)
        v1.exhl = UInt16(data[19]) + (UInt16(data[20]) << 8)
        v1.exa = data[21]
        v1.exf = data[22]
        v1.iy = UInt16(data[23]) + (UInt16(data[24]) << 8)
        v1.ix = UInt16(data[25]) + (UInt16(data[26]) << 8)
        v1.iff = data[27]
        v1.iff2 = data[28]
        v1.flags2 = data[29]

        // file format quirks
        v1.r = (v1.r & 0x7f) | (v1.flags1 << 7)
        if v1.flags1 == 255 { v1.flags1 = 1 }

        if (v1.pc != 0) {
            print(".z80 version 1 file")

            // compressed files should never be longer than compressed, which are 49182 bytes
            if data.count > (48 * 1024) + v1HeaderLen {
                print(" file too long")
                return false
            }

            let isCompressed = v1.flags1 & (1 << 5) != 0
            print("  \(!isCompressed ? "un" : "")compressed data")


            // prepare CPU and hardware

            z80.i = v1.i

            z80.exhl = v1.exhl
            z80.exde = v1.exde
            z80.exbc = v1.exbc
            z80.exaf = (UInt16(v1.exa) << 8) + UInt16(v1.exf)

            z80.hl.value = v1.hl
            z80.de.value = v1.de
            z80.bc.value = v1.bc
            z80.iy = v1.iy
            z80.ix = v1.ix

            // z80[27] =  sna[19].00001000
            if v1.iff != 0 {
                z80.interrupts = true
                z80.iff1 = 1
                z80.iff2 = 1
            } else {
                z80.interrupts = false
                z80.iff1 = 0
                z80.iff2 = 0
            }

            z80.r.value = v1.r

            z80.af.value = (UInt16(v1.a) << 8) + UInt16(v1.f)
            ZilogZ80.sp = v1.sp

            // sna[25].00000011 = z80[29].00000011
            z80.interruptMode = v1.flags2 & 0x03
            // sna[26].00000111 = z80[12].00001110
            z80.machine?.output(0xfe, byte: (v1.flags1 >> 1) & 0x07)

            // prepare ram

            let ram = z80.memory.romSize
            let ramlen = 64 * 1024 // can change if 16k support is added
            let datlen: UInt16 = UInt16(data.count) - v1HeaderLen
            var i: UInt16 = v1HeaderLen
            var o: UInt16 = 0

            var loop = true
            while loop {
                let left = datlen - i // TODO can overflow?
                if left == 0 {
                    print("    end of data")
                    break
                }
                if UInt(ram) + UInt(o) >= ramlen {
                    print("    end of ram")
                    return false
                }

                let b = data[Int(i)]

                if isCompressed && b == 0x00 && left >= 4 && data[Int(i + 1)] == 0xed
                    && data[Int(i + 2)] == 0xed && data[Int(i + 3)] == 0x00 {
                    print("    data terminator")
                    loop = false
                    i += 4
                } else if isCompressed && b == 0xed && left >= 4 && data[Int(i + 1)] == 0xed {
                    let n = data[Int(i + 2)]
                    let v = data[Int(i + 3)]

                    for _ in 0..<n {
                        z80.memory.set(ram + o, byte:v)

                        o += 1
                    }
                    i += 4
                } else {
                    z80.memory.set(ram + o, byte:b)

                    i += 1
                    o += 1
                }
            }

            // start CPU

            z80.pc = v1.pc

            return true
        } else {
            print(".z80 version 2 or 3 file")

            return false
        }
    }
}
