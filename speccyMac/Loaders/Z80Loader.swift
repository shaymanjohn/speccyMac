//
//  Z80Loader.swift
//  speccyMac
//
//  Created by hippietrail on 20/08/2022.
//

import Foundation

class Z80Loader: GameLoaderProtocol {
    
    let z80: ZilogZ80
    
    required init(z80: ZilogZ80) {
        self.z80 = z80
    }
    
    func load(data: Data) -> Bool {
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
        v1.bcp = UInt16(data[15]) + (UInt16(data[16]) << 8)
        v1.dep = UInt16(data[17]) + (UInt16(data[18]) << 8)
        v1.hlp = UInt16(data[19]) + (UInt16(data[20]) << 8)
        v1.ap = data[21]
        v1.fp = data[22]
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

            let isCompressed = v1.flags1 & (1 << 5) != 0
            print("  \(!isCompressed ? "un" : "")compressed data")

            // prepare CPU and hardware
            z80.i = v1.i

            z80.exhl = v1.hlp
            z80.exde = v1.dep
            z80.exbc = v1.bcp
            z80.exaf = UInt16(v1.ap) + (UInt16(v1.fp) << 8)

            z80.hl.value = v1.hl
            z80.de.value = v1.de
            z80.bc.value = v1.bc
            z80.iy = v1.iy
            z80.ix = v1.ix

            // sna[19].00010000 = z80[29].00000001
            if v1.flags2 & 0x04 > 0 {
                z80.interrupts = true
            } else {
                z80.interrupts = false
            }

            z80.r.value = v1.r

            z80.af.value = UInt16(v1.a) + (UInt16(v1.f) << 8)
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
                let left = datlen - i
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
            let lo = z80.memory.get(ZilogZ80.sp)
            ZilogZ80.sp = ZilogZ80.sp &+ 1
            let hi = z80.memory.get(ZilogZ80.sp)
            ZilogZ80.sp = ZilogZ80.sp &+ 1

            z80.pc = (UInt16(hi) << 8) + UInt16(lo)

            z80.memory.set(ZilogZ80.sp &- 1, byte: 0)
            z80.memory.set(ZilogZ80.sp &- 2, byte: 0)

            return true
        } else {
            print(".z80 version 2 or 3 file")

            var v2: V2Header = V2Header()

            v2.length = UInt16(data[30]) + (UInt16(data[31]) << 8)
            v2.pc = UInt16(data[32]) + (UInt16(data[33]) << 8)

            print("  header length", v2.length, "+ 30 =", v1HeaderLen + v2.length, "offset:", String(format :"%02Xh", v1HeaderLen + v2.length))

            if v2.length == 23 {
                print("    version 2")
            } else if v2.length == 54 {
                print("    version 3 (short)")
            } else if v2.length == 55 {
                print("    version 3 (long)")
            } else {
                print("    invalid!")
                return false
            }

            print("      compressed & chunked data")
        }

        return false
    }
}

extension Z80Loader {
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
        var bcp: UInt16 = 0
        var dep: UInt16 = 0
        var hlp: UInt16 = 0
        var ap: UInt8 = 0
        var fp: UInt8 = 0
        var iy: UInt16 = 0
        var ix: UInt16 = 0
        var iff: UInt8 = 0
        var iff2: UInt8 = 0
        var flags2: UInt8 = 0
    }

    // z80 version 2 files have these fields following the first header
    struct V2Header {
        var length: uint16 = 0
        var pc: uint16 = 0
        var hardwareMode: uint8 = 0
        var l7ffd: uint8 = 0
        var if1: uint8 = 0
        var remu: uint8 = 0
        var lfffd: uint8 = 0
        var ay = [uint8](repeating: 0, count: 16)
    }

    // z80 version 3 files have these fields following the first two headers
    struct V3Header {
        var lowT: uint16 = 0
        var highT: uint8 = 0
        var flagQl: uint8 = 0
        var mgtrom: uint8 = 0
        var multiface: uint8 = 0
        var rams0: uint8 = 0
        var rams1: uint8 = 0
        var keyboard = [uint8](repeating: 0, count: 10)
        var keys = [uint8](repeating: 0, count: 10)
        var mgtType: uint8 = 0
        var discipleI: uint8 = 0
        var discipleF: uint8 = 0

        // this field is only present if v2.length is long enough
        var l11fd: uint8 = 0
    }
}
