//
//  ZilogZ80.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

protocol Processor: AnyObject {
    
    func start()
    func pause()
    func unpause()
    func incCounters(_ amount: UInt32)
    
    var counter:    UInt32 { get set }
    var machine:    Spectrum! { get set }
    var lateFrames: Int { get }
}

// swiftlint:disable:next type_body_length
class ZilogZ80 : Processor {
    
    // Main registers as inline stored properties
    var regA: UInt8 = 0
    var regB: UInt8 = 0
    var regC: UInt8 = 0
    var regD: UInt8 = 0
    var regE: UInt8 = 0
    var regH: UInt8 = 0
    var regL: UInt8 = 0
    
    // Flags register - static so Memory can access it without a Z80 reference
    // (there's only ever one Z80 instance)
    static var regF: UInt8 = 0
    var regF: UInt8 {
        @inline(__always) get { return ZilogZ80.regF }
        @inline(__always) set { ZilogZ80.regF = newValue }
    }
    
    // Index register high/low for temporary IX/IY decomposition
    var ixyh: UInt8 = 0
    var ixyl: UInt8 = 0
    
    // Computed register pairs
    var af: UInt16 {
        @inline(__always) get { return (UInt16(regA) << 8) | UInt16(regF) }
        @inline(__always) set { regA = UInt8(newValue >> 8); regF = UInt8(newValue & 0xff) }
    }
    
    var hl: UInt16 {
        @inline(__always) get { return (UInt16(regH) << 8) | UInt16(regL) }
        @inline(__always) set { regH = UInt8(newValue >> 8); regL = UInt8(newValue & 0xff) }
    }
    
    var bc: UInt16 {
        @inline(__always) get { return (UInt16(regB) << 8) | UInt16(regC) }
        @inline(__always) set { regB = UInt8(newValue >> 8); regC = UInt8(newValue & 0xff) }
    }
    
    var de: UInt16 {
        @inline(__always) get { return (UInt16(regD) << 8) | UInt16(regE) }
        @inline(__always) set { regD = UInt8(newValue >> 8); regE = UInt8(newValue & 0xff) }
    }
    
    var ixy: UInt16 {
        @inline(__always) get { return (UInt16(ixyh) << 8) | UInt16(ixyl) }
        @inline(__always) set { ixyh = UInt8(newValue >> 8); ixyl = UInt8(newValue & 0xff) }
    }
    
    var ix: UInt16 = 0
    var iy: UInt16 = 0
    
    // SP is static so Memory can access it for push/pop without a Z80 reference
    static var sp: UInt16 = 0
    var sp: UInt16 {
        @inline(__always) get { return ZilogZ80.sp }
        @inline(__always) set { ZilogZ80.sp = newValue }
    }
    var pc: UInt16 = 0
    
    var regR: UInt8 = 0
    
    var i:    UInt8 = 0
    var iff1: UInt8 = 0
    var iff2: UInt8 = 0
    
    var machine: Spectrum!
    var memory:  Memory
    
    var exaf: UInt16 = 0
    var exhl: UInt16 = 0
    var exbc: UInt16 = 0
    var exde: UInt16 = 0
    
    var counter:       UInt32 = 0    
    
    var paused:        Bool = false
    var lastFrame:     TimeInterval = 0
    let frameTime:     TimeInterval = 1 / 50.0      // pal refresh rate = 50Hz
    var lateFrames:    Int = 0
    var interrupts:    Bool = false
    var halted:        Bool = false
    var interruptMode: UInt8 = 0
    var running:       Bool = false
    
    static let cBit:     UInt8 = 1 << 0
    static let nBit:     UInt8 = 1 << 1
    static let pvBit:    UInt8 = 1 << 2
    static let threeBit: UInt8 = 1 << 3
    static let hBit:     UInt8 = 1 << 4
    static let fiveBit:  UInt8 = 1 << 5
    static let zBit:     UInt8 = 1 << 6
    static let sBit:     UInt8 = 1 << 7
    
    static var sz53pvTable: [UInt8] = []
    static var sz53Table:   [UInt8] = []
    static var parityBit:   [UInt8] = []
    
    static let halfCarryAdd:  [UInt8] = [0, 1 << 4, 1 << 4, 1 << 4, 0, 0, 0, 1 << 4]
    static let halfCarrySub:  [UInt8] = [0, 0, 1 << 4, 0, 1 << 4, 0, 1 << 4, 1 << 4]
    static let overFlowAdd:   [UInt8] = [0, 0, 0, 1 << 2, 1 << 2, 0, 0, 0]
    static let overFlowSub:   [UInt8] = [0, 1 << 2, 0, 0, 0, 0, 1 << 2, 0]

    // Pre-extracted timing data (fix 7: avoids String refcounting from Instruction struct)
    let unprefixedTstates    = UnsafeMutablePointer<UInt32>.allocate(capacity: 256)
    let unprefixedAltTstates = UnsafeMutablePointer<UInt32>.allocate(capacity: 256)
    let unprefixedLength     = UnsafeMutablePointer<UInt16>.allocate(capacity: 256)
    let cbTstates            = UnsafeMutablePointer<UInt32>.allocate(capacity: 256)
    let cbLength             = UnsafeMutablePointer<UInt16>.allocate(capacity: 256)
    let ddTstates            = UnsafeMutablePointer<UInt32>.allocate(capacity: 256)
    let ddLength             = UnsafeMutablePointer<UInt16>.allocate(capacity: 256)
    let edTstates            = UnsafeMutablePointer<UInt32>.allocate(capacity: 256)
    let edLength             = UnsafeMutablePointer<UInt16>.allocate(capacity: 256)
    
    init(memory: Memory) {
        self.memory = memory
        
        parseInstructions()
        calculateTables()
        
        sp = 0xffff
        pc = 0x0000
        iff1 = 0
        iff2 = 0
    }
    
    func dumpReg() {
        print("af: ", String(af, radix: 16, uppercase: true))
        print("bc: ", String(bc, radix: 16, uppercase: true))
        print("de: ", String(de, radix: 16, uppercase: true))
        print("hl: ", String(hl, radix: 16, uppercase: true))
        print("ix: ", String(ix, radix: 16, uppercase: true))
        print("iy: ", String(iy, radix: 16, uppercase: true))
        print("sp: ", String(sp, radix: 16, uppercase: true))
    }
    
    func start() {
        var opCode: UInt8
        var byte1:  UInt8
        var byte2:  UInt8
        var byte3:  UInt8
        
        running = true
        
        while running {
            
            if !paused {
                if counter >= machine.ticksPerFrame {
                    serviceInterrupts()
                } else {
                    opCode = memory.get(pc)
                    
                    // When halted, the Z80 repeatedly executes NOPs (4 T-states each)
                    // without reading additional bytes. Skip the eager operand reads.
                    if halted {
                        incCounters(4)
                        incR()
                        machine.tick()
                        continue
                    }
                    
                    switch opCode {
                        
                    case 0xcb:
                        byte1 = memory.get(pc &+ 1)
                        cbprefix(opcode: byte1)
                        
                    case 0xed:
                        byte1 = memory.get(pc &+ 1)
                        byte2 = memory.get(pc &+ 2)
                        byte3 = memory.get(pc &+ 3)
                        edprefix(opcode: byte1, first: byte2, second: byte3)
                        
                    case 0xdd, 0xfd:
                        byte1 = memory.get(pc &+ 1)
                        byte2 = memory.get(pc &+ 2)
                        byte3 = memory.get(pc &+ 3)
                        
                        let activeRegPair = opCode == 0xdd ? ix : iy
                        ixy = activeRegPair
                        
                        if byte1 == 0xcb {
                            ddcbprefix(opcode: byte3, first: byte2)
                        } else {
                            ddprefix(opcode: byte1, first: byte2, second: byte3)
                        }
                        
                        if opCode == 0xdd {
                            ix = ixy
                        } else {
                            iy = ixy
                        }
                        
                    default:
                        // Only read operand bytes that the instruction actually needs.
                        // Length 1: no operands, length 2: one byte, length 3: two bytes.
                        let len = unprefixedLength[Int(opCode)]
                        if len >= 2 {
                            byte1 = memory.get(pc &+ 1)
                            if len >= 3 {
                                byte2 = memory.get(pc &+ 2)
                            } else {
                                byte2 = 0
                            }
                        } else {
                            byte1 = 0
                            byte2 = 0
                        }
                        unprefixed(opcode: opCode, first: byte1, second: byte2)
                    }
                }
                
                machine.tick()
            }
        }
    }
    
    final func pause() {
        paused = true
        Thread.sleep(forTimeInterval: 0.1)
    }
    
    final func unpause() {
        counter = 0
        paused = false

        if !running {
            DispatchQueue.global(qos: .userInitiated).async {
                self.start()
            }
        }
    }
    
    @inline(__always) final func incCounters(_ amount: UInt32) {
        counter += amount        
        machine.ula += amount
    }
    
    final func parseInstructions() {
        guard let path = Bundle.main.path(forResource: "z80ops", ofType: "json"),
            let json = try? String.init(contentsOfFile: path),
            let data = json.data(using: .utf8) else {
            fatalError("Could not locate or read z80ops.json instruction timing data")
        }

        struct Instruction: Codable {
            var opcode: String
            var tstates: UInt32
            var alttstates: UInt32
            var length: UInt16
        }
        struct Instructions: Codable {
            var unprefixed: [Instruction]
            var edprefix:   [Instruction]
            var ddprefix:   [Instruction]
            var cbprefix:   [Instruction]
        }

        let instructionSet: Instructions
        do {
            instructionSet = try JSONDecoder().decode(Instructions.self, from: data)
        } catch {
            fatalError("Could not parse z80ops.json: \(error)")
        }

        guard instructionSet.unprefixed.count >= 256,
            instructionSet.cbprefix.count >= 256,
            instructionSet.ddprefix.count >= 256,
            instructionSet.edprefix.count >= 256 else {
            fatalError("z80ops.json does not contain full 256-entry instruction tables")
        }

        // Extract timing data into flat arrays
        for i in 0..<256 {
            unprefixedTstates[i]    = instructionSet.unprefixed[i].tstates
            unprefixedAltTstates[i] = instructionSet.unprefixed[i].alttstates
            unprefixedLength[i]     = instructionSet.unprefixed[i].length
            cbTstates[i]            = instructionSet.cbprefix[i].tstates
            cbLength[i]             = instructionSet.cbprefix[i].length
            ddTstates[i]            = instructionSet.ddprefix[i].tstates
            ddLength[i]             = instructionSet.ddprefix[i].length
            edTstates[i]            = instructionSet.edprefix[i].tstates
            edLength[i]             = instructionSet.edprefix[i].length
        }
    }

    func calculateTables() {
        for ii in 0...255 {
            ZilogZ80.sz53Table.append(UInt8(ii) & (ZilogZ80.threeBit | ZilogZ80.fiveBit | ZilogZ80.sBit))
            var j = UInt(ii)
            var parity:UInt8 = 0
            for _ in 0...7 {
                parity = parity ^ UInt8(j) & 1
                j = j >> 1
            }
            
            if parity == 0 {
                ZilogZ80.parityBit.append(0)
            } else {
                ZilogZ80.parityBit.append(ZilogZ80.pvBit)
            }
            
            ZilogZ80.sz53pvTable.append(ZilogZ80.sz53Table[ii] | ZilogZ80.parityBit[ii])
        }
        
        ZilogZ80.sz53Table[0]   = ZilogZ80.sz53Table[0]   | ZilogZ80.zBit
        ZilogZ80.sz53pvTable[0] = ZilogZ80.sz53pvTable[0] | ZilogZ80.zBit
    }
    
    final func serviceInterrupts() {
        let timeNow = Date.timeIntervalSinceReferenceDate
        let thisFrameTime = timeNow - lastFrame
        
        if thisFrameTime <= frameTime {
            lastFrame += frameTime
            Thread.sleep(forTimeInterval: frameTime - thisFrameTime)
        } else {
            lateFrames += 1
            lastFrame = timeNow
        }
        
        counter -= machine.ticksPerFrame
        machine.ula = counter
        machine.videoRow = 0
        
        if interrupts {
            interrupts = false
            
            if halted {
                pc = pc &+ 1
                halted = false
            }
            
            memory.push(pc)
            incR()
            iff1 = 0
            iff2 = 0
            
            if interruptMode < 2 {
                pc = 0x0038
                incCounters(13)
            } else {
                let vector = (UInt16(i) << 8) | 0xff
                let loByte = memory.get(vector)
                let hiByte = memory.get(vector &+ 1)
                pc = (UInt16(hiByte) << 8) | UInt16(loByte)
                incCounters(19)
            }
        }
    }
    
    // MARK: - Refresh register
    
    @inline(__always) final func incR() {
        regR = (regR & 0x80) | ((regR &+ 1) & 0x7f)
    }
    
    // MARK: - Register value by index (replaces array literal pattern)
    
    @inline(__always) final func regByIndex(_ index: UInt8) -> UInt8 {
        switch index {
        case 0: return regB
        case 1: return regC
        case 2: return regD
        case 3: return regE
        case 4: return regH
        case 5: return regL
        case 6: return memory.get(hl)  // (HL) - should not be called for index 6 in register-only ops
        case 7: return regA
        default: return 0
        }
    }
    
    @inline(__always) final func setRegByIndex(_ index: UInt8, value: UInt8) {
        switch index {
        case 0: regB = value
        case 1: regC = value
        case 2: regD = value
        case 3: regE = value
        case 4: regH = value
        case 5: regL = value
        case 6: memory.set(hl, byte: value)  // (HL)
        case 7: regA = value
        default: break
        }
    }
    
    // MARK: - Register operations (formerly on Register class)
    
    @inline(__always) final func regInc(_ value: UInt8) -> UInt8 {
        let result = value &+ 1
        regF = (regF & ZilogZ80.cBit) | (result == 0x80 ? ZilogZ80.pvBit : 0) | (result & 0x0f > 0 ? 0 : ZilogZ80.hBit) | ZilogZ80.sz53Table[result]
        return result
    }
    
    @inline(__always) final func regDec(_ value: UInt8) -> UInt8 {
        regF = (regF & ZilogZ80.cBit) | (value & 0x0f > 0 ? 0 : ZilogZ80.hBit) | ZilogZ80.nBit
        let result = value &- 1
        regF |= (result == 0x7f ? ZilogZ80.pvBit : 0) | ZilogZ80.sz53Table[result]
        return result
    }
    
    @inline(__always) final func regRlc(_ value: UInt8) -> UInt8 {
        let result = (value << 1) | (value >> 7)
        regF = (result & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[result]
        return result
    }
    
    @inline(__always) final func regRrc(_ value: UInt8) -> UInt8 {
        let f = value & ZilogZ80.cBit
        let result = (value >> 1) | (value << 7)
        regF = f | ZilogZ80.sz53pvTable[result]
        return result
    }
    
    @inline(__always) final func regRl(_ value: UInt8) -> UInt8 {
        let rltemp = value
        let result = (value << 1) | (regF & ZilogZ80.cBit)
        regF = (rltemp >> 7) | ZilogZ80.sz53pvTable[result]
        return result
    }
    
    @inline(__always) final func regRr(_ value: UInt8) -> UInt8 {
        let rrtemp = value
        let result = (value >> 1) | (regF << 7)
        regF = (rrtemp & ZilogZ80.cBit) | ZilogZ80.sz53pvTable[result]
        return result
    }
    
    @inline(__always) final func regSla(_ value: UInt8) -> UInt8 {
        regF = value >> 7
        let result = value << 1
        regF |= ZilogZ80.sz53pvTable[result]
        return result
    }
    
    @inline(__always) final func regSra(_ value: UInt8) -> UInt8 {
        regF = value & ZilogZ80.cBit
        let result = (value & 0x80) | (value >> 1)
        regF |= ZilogZ80.sz53pvTable[result]
        return result
    }
    
    @inline(__always) final func regSrl(_ value: UInt8) -> UInt8 {
        regF = value & ZilogZ80.cBit
        let result = value >> 1
        regF |= ZilogZ80.sz53pvTable[result]
        return result
    }
    
    @inline(__always) final func regBit(_ number: UInt8, value: UInt8) {
        regF = (regF & ZilogZ80.cBit) | ZilogZ80.hBit | (value & (ZilogZ80.threeBit | ZilogZ80.fiveBit))
        if value & (1 << number) == 0 {
            regF |= ZilogZ80.pvBit | ZilogZ80.zBit
        }
        if number == 7 && (value & 0x80) > 0 {
            regF |= ZilogZ80.sBit
        }
    }
    
    // MARK: - Accumulator operations (formerly on Accumulator class)
    
    @inline(__always) final func aluAdd(_ amount: UInt8) {
        let addtemp = UInt16(regA) &+ UInt16(amount)
        let part1 = (regA & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = UInt8(addtemp & 0x88) >> 1
        let lookup = part1 | part2 | part3
        regA = UInt8(addtemp & 0xff)
        regF = (addtemp & 0x100 > 0 ? ZilogZ80.cBit : 0) | ZilogZ80.halfCarryAdd[UInt8(lookup & 0xff) & 0x07] | ZilogZ80.overFlowAdd[UInt8(lookup & 0xff) >> 4] | ZilogZ80.sz53Table[regA]
    }
    
    @inline(__always) final func aluAdc(_ amount: UInt8) {
        let adctemp: UInt16 = UInt16(regA) &+ UInt16(amount) &+ UInt16(regF & ZilogZ80.cBit)
        let part1 = (regA & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = (adctemp & 0x88) >> 1
        let lookup = part1 | part2 | UInt8(part3)
        regA = UInt8(adctemp & 0xff)
        regF = (adctemp & 0x100 > 0 ? ZilogZ80.cBit : 0) | ZilogZ80.halfCarryAdd[lookup & 0x07] | ZilogZ80.overFlowAdd[lookup >> 4] | ZilogZ80.sz53Table[regA]
    }
    
    @inline(__always) final func aluSub(_ amount: UInt8) {
        let subTemp = UInt16(regA) &- UInt16(amount)
        let part1 = (regA & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = UInt8(subTemp & 0x88) >> 1
        let lookup = part1 | part2 | part3
        regA = UInt8(subTemp & 0xff)
        let part4 = subTemp & 0x100 > 0 ? ZilogZ80.cBit : 0
        let part5 = ZilogZ80.halfCarrySub[lookup & 0x07]
        let part6 = ZilogZ80.overFlowSub[lookup >> 4]
        let part7 = ZilogZ80.sz53Table[regA]
        regF = part4 | ZilogZ80.nBit | part5 | part6 | part7
    }
    
    @inline(__always) final func aluSbc(_ amount: UInt8) {
        let sbctemp = UInt16(regA) &- UInt16(amount) &- UInt16(regF & ZilogZ80.cBit)
        let part1 = (regA & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = (sbctemp & 0x88) >> 1
        let lookup = part1 | part2 | UInt8(part3)
        regA = UInt8(sbctemp & 0xff)
        regF = (sbctemp & 0x100 > 0 ? ZilogZ80.cBit : 0) | ZilogZ80.nBit | ZilogZ80.halfCarrySub[lookup & 0x07] | ZilogZ80.overFlowSub[lookup >> 4] | ZilogZ80.sz53Table[regA]
    }
    
    @inline(__always) final func aluAnd(_ amount: UInt8) {
        regA = regA & amount
        regF = ZilogZ80.hBit | ZilogZ80.sz53pvTable[regA]
    }
    
    @inline(__always) final func aluXor(_ amount: UInt8) {
        regA = regA ^ amount
        regF = ZilogZ80.sz53pvTable[regA]
    }
    
    @inline(__always) final func aluOr(_ amount: UInt8) {
        regA = regA | amount
        regF = ZilogZ80.sz53pvTable[regA]
    }
    
    @inline(__always) final func aluCp(_ amount: UInt8) {
        let cpTemp: UInt16 = UInt16(regA) &- UInt16(amount)
        let part1 = (regA & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = UInt8(cpTemp & 0x88) >> 1
        let lookup = part1 | part2 | part3
        let part4 = cpTemp & 0x100 > 0 ? ZilogZ80.cBit : (cpTemp > 0 ? 0 : ZilogZ80.zBit)
        let part5 = ZilogZ80.halfCarrySub[lookup & 0x07]
        let part6 = ZilogZ80.overFlowSub[lookup >> 4]
        let part7 = amount & (ZilogZ80.threeBit | ZilogZ80.fiveBit) | (UInt8(cpTemp & 0xff) & ZilogZ80.sBit)
        regF = part4 | ZilogZ80.nBit | part5 | part6 | part7
    }
    
    @inline(__always) final func aluRlca() {
        regA = (regA << 1) | (regA >> 7)
        regF = (regF & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (regA & (ZilogZ80.cBit | ZilogZ80.threeBit | ZilogZ80.fiveBit))
    }
    
    @inline(__always) final func aluRrca() {
        regF = (regF & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (regA & ZilogZ80.cBit)
        regA = (regA >> 1) | (regA << 7)
        regF |= (regA & (ZilogZ80.threeBit | ZilogZ80.fiveBit))
    }
    
    @inline(__always) final func aluRla() {
        let rlatemp = regA
        regA = (regA << 1) | (regF & ZilogZ80.cBit)
        regF = (regF & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (regA & (ZilogZ80.threeBit | ZilogZ80.fiveBit)) | (rlatemp >> 7)
    }
    
    @inline(__always) final func aluRra() {
        let rratemp = regA
        regA = (regA >> 1) | (regF << 7)
        regF = (regF & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (regA & (ZilogZ80.threeBit | ZilogZ80.fiveBit)) | (rratemp & ZilogZ80.cBit)
    }
    
    @inline(__always) final func aluCpl() {
        regA = regA ^ 0xff
        regF = (regF & (ZilogZ80.cBit | ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (regA & (ZilogZ80.threeBit | ZilogZ80.fiveBit)) | (ZilogZ80.nBit | ZilogZ80.hBit)
    }
    
    @inline(__always) final func aluNeg() {
        let byte = regA
        regA = 0
        aluSub(byte)
    }
    
    final func aluDaa() {
        var rmeml: UInt8 = 0
        var rmemh = regF & ZilogZ80.cBit
        
        if (regF & ZilogZ80.hBit > 0) || (regA & 0x0f > 9) {
            rmeml = 6
        }
        
        if (rmemh > 0) || (regA > 0x99) {
            rmeml |= 0x60
        }
        
        if regA > 0x99 {
            rmemh = 1
        }
        
        if regF & ZilogZ80.nBit > 0 {
            if ((regF & ZilogZ80.hBit) > 0) && ((regA & 0x0f) < 6) {
                rmemh |= ZilogZ80.hBit
            }
            aluSub(rmeml)
        } else {
            if ((regA & 0x0f) > 9) {
                rmemh |= ZilogZ80.hBit
            }
            aluAdd(rmeml)
        }
        
        regF = (regF & ~(ZilogZ80.cBit | ZilogZ80.pvBit | ZilogZ80.hBit)) | rmemh | ZilogZ80.parityBit[regA]
    }
    
    // MARK: - 16-bit ALU operations (formerly on RegisterPair class)
    
    @inline(__always) final func addHL(_ amount: UInt16) {
        let temp: UInt32 = UInt32(hl) &+ UInt32(amount)
        let part1 = (hl & 0x0800) >> 11
        let part2 = (amount & 0x0800) >> 10
        let part3 = (UInt16(temp & 0xffff) & 0x0800) >> 9
        let lookup = UInt8(part1) | UInt8(part2) | UInt8(part3)
        hl = UInt16(temp & 0xffff)
        regF = (regF & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (temp & 0x10000 > 0 ? ZilogZ80.cBit : 0) | (UInt8((temp & 0xff00) >> 8) & (ZilogZ80.threeBit | ZilogZ80.fiveBit)) | ZilogZ80.halfCarryAdd[lookup]
    }
    
    @inline(__always) final func adcHL(_ amount: UInt16) {
        let add16temp: UInt32 = UInt32(hl) + UInt32(amount) + UInt32(regF & ZilogZ80.cBit)
        let lookup = ((hl & 0x8800) >> 11) | ((amount & 0x8800) >> 10) | ((UInt16(add16temp & 0xffff) & 0x8800) >> 9)
        hl = UInt16(add16temp & 0xffff)
        let part1 = (add16temp & 0x10000) > 0 ? ZilogZ80.cBit : 0
        let part2 = ZilogZ80.overFlowAdd[UInt8(lookup & 0xff) >> 4]
        let part3 = regH & (ZilogZ80.threeBit | ZilogZ80.fiveBit | ZilogZ80.sBit)
        regF = part1 | part2 | part3 | ZilogZ80.halfCarryAdd[UInt8(lookup & 0xff) & 0x07] | (hl > 0 ? 0 : ZilogZ80.zBit)
    }
    
    @inline(__always) final func sbcHL(_ amount: UInt16) {
        let sub16temp: UInt32 = UInt32(hl) &- UInt32(amount) &- UInt32(regF & ZilogZ80.cBit)
        let lookup = ((hl & 0x8800) >> 11) | ((amount & 0x8800) >> 10) | ((UInt16(sub16temp & 0xffff) & 0x8800) >> 9)
        hl = UInt16(sub16temp & 0xffff)
        let part1 = (sub16temp & 0x10000 > 0 ? ZilogZ80.cBit : 0)
        let part2 = ZilogZ80.overFlowSub[UInt8(lookup & 0xff) >> 4]
        let part3 = regH & (ZilogZ80.threeBit | ZilogZ80.fiveBit | ZilogZ80.sBit)
        regF = part1 | ZilogZ80.nBit | part2 | part3 | ZilogZ80.halfCarrySub[UInt8(lookup & 0xff) & 0x07] | (hl > 0 ? 0 : ZilogZ80.zBit)
    }
    
    @inline(__always) final func addIXY(_ amount: UInt16) {
        let temp: UInt32 = UInt32(ixy) &+ UInt32(amount)
        let part1 = (ixy & 0x0800) >> 11
        let part2 = (amount & 0x0800) >> 10
        let part3 = (UInt16(temp & 0xffff) & 0x0800) >> 9
        let lookup = UInt8(part1) | UInt8(part2) | UInt8(part3)
        ixy = UInt16(temp & 0xffff)
        regF = (regF & (ZilogZ80.pvBit | ZilogZ80.zBit | ZilogZ80.sBit)) | (temp & 0x10000 > 0 ? ZilogZ80.cBit : 0) | (UInt8((temp & 0xff00) >> 8) & (ZilogZ80.threeBit | ZilogZ80.fiveBit)) | ZilogZ80.halfCarryAdd[lookup]
    }
}
