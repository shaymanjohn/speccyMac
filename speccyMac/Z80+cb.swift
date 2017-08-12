//
//  Z80+cb.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Z80 {
    
    final func cbprefix(opcode: UInt8, first: UInt8, second: UInt8) throws {
        
        let instruction = cbprefixedOps[opcode]
        log(instruction)
        
        switch opcode {
            
        case 0x00:  // rlc b
            b.rlc()
            
        case 0x01:  // rlc c
            c.rlc()
            
        case 0x02:  // rlc d
            d.rlc()
            
        case 0x03:  // rlc e
            e.rlc()
            
        case 0x04:  // rlc h
            h.rlc()
            
        case 0x05:  // rlc l
            l.rlc()
            
        case 0x07:  // rlc a
            a.rlc()
            
        case 0x08:  // rrc b
            b.rrc()
            
        case 0x09:  // rrc c
            c.rrc()
            
        case 0x0a:  // rrc d
            d.rrc()
            
        case 0x0b:  // rrc e
            e.rrc()
            
        case 0x0c:  // rrc h
            h.rrc()
            
        case 0x0d:  // rrc l
            l.rrc()
            
        case 0x0f:  // rrc a
            a.rrc()
            
        case 0x10:  // rl b
            b.rl()
            
        case 0x11:  // rl c
            c.rl()
            
        case 0x12:  // rl d
            d.rl()
            
        case 0x13:  // rl e
            e.rl()
            
        case 0x14:  // rl h
            h.rl()
            
        case 0x15:  // rl l
            l.rl()
            
        case 0x16:  // rl (hl)
            memory.rl(hl)
            
        case 0x17:  // rl a
            a.rl()
            
        case 0x18:  // rr b
            b.rr()
            
        case 0x19:  // rr c
            c.rr()
            
        case 0x1a:  // rr d
            d.rr()
            
        case 0x1b:  // rr e
            e.rr()
            
        case 0x1c:  // rr h
            h.rr()
            
        case 0x1d:  // rr l
            l.rr()
            
        case 0x1e:  // rr (hl)
            memory.rr(hl)
            
        case 0x1f:  // rr a
            a.rr()
            
        case 0x20:  // sla b
            b.sla()
            
        case 0x21:  // sla c
            c.sla()
            
        case 0x22:  // sla d
            d.sla()
            
        case 0x23:  // sla e
            e.sla()
            
        case 0x24:  // sla h
            h.sla()
            
        case 0x25:  // sla l
            l.sla()
            
        case 0x27:  // sla a
            a.sla()
            
        case 0x28:  // sra b
            b.sra()
            
        case 0x29:  // sra c
            c.sra()
            
        case 0x2c:  // sra h
            h.sra()
            
        case 0x2f:  // sra a
            a.sra()

        case 0x38:  // srl b
            b.srl()
            
        case 0x39:  // srl c
            c.srl()
            
        case 0x3a:  // srl d
            d.srl()
            
        case 0x3b:  // srl e
            e.srl()
            
        case 0x3c:  // srl h
            h.srl()
            
        case 0x3d:  // srl l
            l.srl()
            
        case 0x3e:  // srl (hl)
            memory.srl(hl)
            
        case 0x3f:  // srl a
            a.srl()
            
        case 0x40:  // bit 0, b
            b.bit(0)
            
        case 0x41:  // bit 0, c
            c.bit(0)
            
        case 0x42:  // bit 0, d
            d.bit(0)
            
        case 0x43:  // bit 0, e
            e.bit(0)
            
        case 0x44:  // bit 0, h
            h.bit(0)
            
        case 0x45:  // bit 0, l
            l.bit(0)
            
        case 0x46:  // bit 0, (hl)
            memory.indexBit(0, address: hl.value)
            
        case 0x47:  // bit 0, a
            a.bit(0)
            
        case 0x48:  // bit 1, b
            b.bit(1)
            
        case 0x49:  // bit 1, c
            c.bit(1)
            
        case 0x4b:  // bit 1, e
            e.bit(1)
            
        case 0x4c:  // bit 1, h
            h.bit(1)
            
        case 0x4e:  // bit 1, (hl)
            memory.indexBit(1, address: hl.value)
            
        case 0x4f:  // bit 1, a
            a.bit(1)
            
        case 0x50:  // bit 2, b
            b.bit(2)

        case 0x51:  // bit 2, c
            c.bit(2)
            
        case 0x53:  // bit 2, e
            e.bit(2)
            
        case 0x56:  // bit 2, (hl)
            memory.indexBit(2, address: hl.value)
            
        case 0x57:  // bit 2, a
            a.bit(2)
            
        case 0x58:  // bit 3, b
            b.bit(3)
            
        case 0x59:  // bit 3, c
            c.bit(3)
            
        case 0x5a:  // bit 3, d
            d.bit(3)
            
        case 0x5b:  // bit 3, e
            e.bit(3)
            
        case 0x5c:  // bit 3, h
            h.bit(3)
            
        case 0x5d:  // bit 3, l
            l.bit(3)
            
        case 0x5e:  // bit 3, (hl)
            memory.indexBit(3, address: hl.value)
            
        case 0x5f:  // bit 3, a
            a.bit(3)
            
        case 0x61:  // bit 4, c
            c.bit(4)
            
        case 0x62:  // bit 4, d
            d.bit(4)
            
        case 0x63:  // bit 4, e
            e.bit(4)
            
        case 0x64:  // bit 4, h
            h.bit(4)
            
        case 0x66:  // bit 4, (hl)
            memory.indexBit(4, address: hl.value)
            
        case 0x67:  // bit 4, a
            a.bit(4)
            
        case 0x69:  // bit 5, c
            c.bit(5)
            
        case 0x6e:  // bit 5, (hl)
            memory.indexBit(5, address: hl.value)
            
        case 0x6f:  // bit 5, a
            a.bit(5)
            
        case 0x70:  // bit 6, b
            b.bit(6)
            
        case 0x71:  // bit 6, c
            c.bit(6)
            
        case 0x72:  // bit 6, d
            d.bit(6)
            
        case 0x77:  // bit 6, a
            a.bit(6)
            
        case 0x78:  // bit 7, b
            b.bit(7)
            
        case 0x79:  // bit 7, c
            c.bit(7)
            
        case 0x7a:  // bit 7, d
            d.bit(7)
            
        case 0x7b:  // bit 7, e
            e.bit(7)
            
        case 0x7c:  // bit 7, h
            h.bit(7)
            
        case 0x7e:  // bit 7, (hl)
            memory.indexBit(7, address: hl.value)
            
        case 0x7f:  // bit 7, a
            a.bit(7)
            
        case 0x80:  // res 0, b
            b.res(0)
            
        case 0x85:  // res 0, l
            l.res(0)
            
        case 0x86:  // res 0, (hl)
            memory.indexRes(0, address: hl.value)
            
        case 0x87:  // res 0, a
            a.res(0)
            
        case 0x8a:  // res 1, d
            d.res(1)
            
        case 0x8e:  // res 1, (hl)
            memory.indexRes(1, address: hl.value)
            
        case 0x8f: // res 1, a
            a.res(1)
            
        case 0x90: // res 2, b
            b.res(2)
            
        case 0x96:  // res 2, (hl)
            memory.indexRes(2, address: hl.value)
            
        case 0x97: // res 2, a
            a.res(2)
            
        case 0x98: // res 3, b
            b.res(3)
            
        case 0x9e:  // res 3, (hl)
            memory.indexRes(3, address: hl.value)
            
        case 0x9f: // res 3, a
            a.res(3)
            
        case 0xa0: // res 4, b
            b.res(4)
            
        case 0xa6: // res 4, (hl)
            memory.indexRes(4, address: hl.value)
            
        case 0xac: // res 5, h
            h.res(5)
            
        case 0xae: // res 5, (hl)
            memory.indexRes(5, address: hl.value)
            
        case 0xaf: // res 5, a
            a.res(5)
            
        case 0xb0: // res 6, b
            b.res(6)
            
        case 0xb6: // res 6, (hl)
            memory.indexRes(6, address: hl.value)
            
        case 0xb9: // res 7, c
            c.res(7)
            
        case 0xbb: // res 7, e
            e.res(7)
            
        case 0xbc: // res 7, h
            h.res(7)
            
        case 0xbd: // res 7, l
            l.res(7)
            
        case 0xbf: // res 7, a
            a.res(7)
            
        case 0xbe: // res 7, (hl)
            memory.indexRes(7, address: hl.value)
            
        case 0xc1:  // set 0, c
            c.set(0)
            
        case 0xc6: // set 0, (hl)
            memory.indexSet(0, address: hl.value)
            
        case 0xc7:  // set 0, a
            a.set(0)
            
        case 0xc9:  // set 1, c
            c.set(1)
            
        case 0xca:  // set 1, d
            d.set(1)
            
        case 0xce:  // set 1, (hl)
            memory.indexSet(1, address: hl.value)
            
        case 0xcf:  // set 1, a
            a.set(1)
            
        case 0xd0:  // set 2, b
            b.set(2)
            
        case 0xd1:  // set 2, c
            c.set(2)
            
        case 0xd3:  // set 2, e
            e.set(2)
            
        case 0xd9:  // set 3, c
            c.set(3)
            
        case 0xda:  // set 3, d
            d.set(3)
            
        case 0xdb:  // set 3, e
            e.set(3)
            
        case 0xe0:  // set 4, b
            b.set(4)
            
        case 0xe3:  // set 4, e
            e.set(4)
            
        case 0xd6:  // set 2, (hl)
            memory.indexSet(2, address: hl.value)
            
        case 0xd8:  // set 3, b
            b.set(3)
            
        case 0xde:  // set 3, (hl)
            memory.indexSet(3, address: hl.value)
            
        case 0xe6:  // set 4, (hl)
            memory.indexSet(4, address: hl.value)
            
        case 0xec: // set 5, h
            h.set(5)
            
        case 0xee:  // set 5, (hl)
            memory.indexSet(5, address: hl.value)
            
        case 0xf3: // set 6, e
            e.set(6)
            
        case 0xf4: // set 6, h
            h.set(6)
            
        case 0xf6: // set 6, (hl)
            memory.indexSet(6, address: hl.value)
            
        case 0xf7: // set 6, a
            a.set(6)
            
        case 0xfb: // set 7, e
            e.set(7)
            
        case 0xfc: // set 7, h
            h.set(7)
            
        case 0xfd: // set 7, l
            l.set(7)
            
        case 0xfe:  // set 7, (hl)
            memory.indexSet(7, address: hl.value)
            
        case 0xff: // set 7, a
            a.set(7)
            
        default:
            throw NSError(domain: "z80+cb", code: 1, userInfo: ["opcode" : String(opcode, radix: 16, uppercase: true), "instruction" : instruction.opCode, "pc" : pc])
        }        
        
        pc = pc &+ instruction.length        
        incCounters(instruction.tStates)
        
        r.inc()
        r.inc()
    }
}
