//
//  z80defines.h
//  ioSpeccy
//
//  Created by John Ward on 15/12/2013.
//  Copyright (c) 2013 karmatoad. All rights reserved.
//

#ifndef ioSpeccy_z80defines_h
#define ioSpeccy_z80defines_h

const UInt8 overflow_add_table[] = {0, 0, 0, PV_BIT, PV_BIT, 0, 0, 0};
const UInt8 overflow_sub_table[] = {0, PV_BIT, 0, 0, 0, 0, PV_BIT, 0};

const UInt8 halfcarry_add_table[] = {0, H_BIT, H_BIT, H_BIT, 0, 0, 0, H_BIT};
const UInt8 halfcarry_sub_table[] = {0, 0, H_BIT, 0, H_BIT, 0, H_BIT, H_BIT};

#define ByteInc(byte)\
{\
    byte++;\
    _f = (_f & C_BIT) | (byte == 0x80 ? PV_BIT : 0) | (byte & 0x0f ? 0 : H_BIT) | sz53Table[byte];\
}

#define ByteDec(byte)\
{\
    _f = (_f & C_BIT) | (byte &0x0f ? 0 : H_BIT ) | N_BIT;\
    byte--;\
    _f |= (byte == 0x7f ? PV_BIT : 0) | sz53Table[byte];\
}

#define ByteAdd(byte)\
{\
    UInt16 addtemp = _a + byte;\
    UInt8 lookup = ((_a & 0x88) >> 3) | ((byte & 0x88) >> 2) | ((addtemp & 0x88) >> 1);\
    _a = addtemp;\
    _f = (addtemp & 0x100 ? C_BIT : 0 ) | halfcarry_add_table[lookup & 0x07] | overflow_add_table[lookup >> 4] | sz53Table[_a];\
}

#define ByteSub(byte)\
{\
    UInt16 subtemp = _a - byte;\
    UInt8 lookup = ((_a & 0x88) >> 3) | ((byte & 0x88) >> 2) | ((subtemp & 0x88 ) >> 1);\
    _a = subtemp;\
    _f = (subtemp & 0x100 ? C_BIT : 0 ) | N_BIT | halfcarry_sub_table[lookup & 0x07] | overflow_sub_table[lookup >> 4] | sz53Table[_a];\
}

#define ByteAddCarry(byte)\
{\
    UInt16 adctemp = _a + byte + (_f & C_BIT);\
    UInt8 lookup = ((_a & 0x88) >> 3) | ((byte & 0x88) >> 2) | ((adctemp & 0x88) >> 1);\
    _a = adctemp;\
    _f = (adctemp & 0x100 ? C_BIT : 0) | halfcarry_add_table[lookup & 0x07] | overflow_add_table[lookup >> 4] | sz53Table[_a];\
}

#define ByteSubCarry(byte)\
{\
    UInt16 sbctemp = _a - byte - (_f & C_BIT);\
    UInt8 lookup = ((_a & 0x88 ) >> 3) | ((byte & 0x88) >> 2) | ((sbctemp & 0x88) >> 1);\
    _a = sbctemp;\
    _f = (sbctemp & 0x100 ? C_BIT : 0 ) | N_BIT | halfcarry_sub_table[lookup & 0x07] | overflow_sub_table[lookup >> 4] | sz53Table[_a];\
}

#define WordSubCarry(word)\
{\
    UInt32 sub16temp = _hl - word - (_f & C_BIT);\
    UInt8 lookup = ((_hl & 0x8800) >> 11) | ((word & 0x8800) >> 10) | ((sub16temp & 0x8800) >> 9);\
    _hl = sub16temp;\
    _f = (sub16temp & 0x10000 ? C_BIT : 0) | N_BIT | overflow_sub_table[lookup >> 4] | (_h & (THREE_BIT | FIVE_BIT | S_BIT )) | halfcarry_sub_table[lookup&0x07] | (_hl ? 0 : Z_BIT);\
}

#define WordAddCarry(word)\
{\
    UInt32 add16temp = _hl + word + (_f & C_BIT);\
    UInt8 lookup = ((_hl & 0x8800) >> 11) | ((word & 0x8800) >> 10) | ((add16temp & 0x8800) >> 9);\
    _hl = add16temp;\
    _f = (add16temp & 0x10000 ? C_BIT : 0 ) | overflow_add_table[lookup >> 4] | (_h & (THREE_BIT | FIVE_BIT | S_BIT) ) | halfcarry_add_table[lookup & 0x07]| (_hl ? 0 : Z_BIT );\
}

#define ByteAnd(byte)\
{\
    _a &= byte;\
    _f = H_BIT | sz53pvTable[_a];\
}

#define ByteXor(byte)\
{\
    _a ^= byte;\
    _f = sz53pvTable[_a];\
}

#define ByteOr(byte)\
{\
    _a |= byte;\
    _f = sz53pvTable[_a];\
}

#define ByteCompare(byte)\
{\
    UInt16 cptemp = _a - byte;\
    UInt8 lookup = ((_a & 0x88) >> 3) | ((byte & 0x88) >> 2) | ((cptemp & 0x88) >> 1);\
    _f = (cptemp & 0x100 ? C_BIT : (cptemp ? 0 : Z_BIT)) | N_BIT | halfcarry_sub_table[lookup & 0x07] | overflow_sub_table[lookup >> 4] | (byte & ( THREE_BIT | FIVE_BIT)) | (cptemp & S_BIT);\
}

#define SetMemory(address, byte)\
if (address > ROM_END) {\
    memory[address] = byte;\
}

#define Pop(regPair)\
{\
    regPair.Byte.lo = memory[_sp++];\
    regPair.Byte.hi = memory[_sp++];\
}

#define Push(regPair)\
{\
    _sp--;\
    SetMemory(_sp, ((regPair) >> 8));\
    _sp--;\
    SetMemory(_sp, regPair);\
}

#define Rlc(register)\
{\
    register = (register << 1) | (register >> 7); \
    _f = (register & C_BIT) | sz53pvTable[register];\
}

#define Rrc(register)\
{\
    _f = register & C_BIT;\
    register = (register >> 1) | (register << 7);\
    _f |= sz53pvTable[register];\
}

#define Add16(word)\
{\
    UInt32 temp = _hl + word;\
    UInt8 lookup = ((_hl & 0x0800) >> 11) | ((word & 0x0800) >> 10) | ((temp & 0x0800) >> 9);\
    _hl = temp;\
    _f = (_f & (PV_BIT | Z_BIT | S_BIT)) | (temp & 0x10000 ? C_BIT : 0) | ((temp >> 8) & (THREE_BIT | FIVE_BIT)) | halfcarry_add_table[lookup];\
}

#define SetRelativePc(byte)\
{\
    _pc+=(signed char)byte;\
}

#define Rl(byte)\
{\
    UInt8 rltemp = byte;\
    byte = (byte << 1) | (_f & C_BIT);\
    _f = (rltemp >> 7) | sz53pvTable[(byte)];\
}

#define Rr(byte)\
{\
    UInt8 rrtemp = byte;\
    byte = (byte >> 1) | (_f << 7);\
    _f = (rrtemp & C_BIT) | sz53pvTable[byte];\
}

#define Rlca \
{\
    _a = (_a << 1) | (_a >> 7);\
    _f = (_f & (PV_BIT | Z_BIT | S_BIT)) | (_a & (C_BIT | THREE_BIT | FIVE_BIT));\
}

#define Rrca \
{\
    _f = (_f & (PV_BIT | Z_BIT | S_BIT)) | (_a & C_BIT);\
    _a = (_a >> 1) | (_a << 7);\
    _f |= (_a & (THREE_BIT | FIVE_BIT));\
}

#define Rla \
{\
    UInt8 rlatemp = _a;\
    _a = (_a << 1) | (_f & C_BIT);\
    _f = (_f & (PV_BIT | Z_BIT | S_BIT)) | (_a & (THREE_BIT | FIVE_BIT)) | (rlatemp >> 7);\
}

#define Rra \
{\
    UInt8 rratemp = _a;\
    _a = (_a >> 1) | (_f << 7);\
    _f = (_f & (PV_BIT | Z_BIT | S_BIT)) | (_a & (THREE_BIT | FIVE_BIT)) | (rratemp & C_BIT);\
}

#define Sla(byte)\
{\
    _f = byte >> 7;\
    byte <<= 1;\
    _f |= sz53pvTable[byte];\
}

#define Sls(byte)\
{\
    _f = byte >> 7;\
    byte <<= 1;\
    byte |= 0x01;\
    _f |= sz53pvTable[byte];\
}

#define Srl(byte)\
{\
    _f = byte & C_BIT;\
    byte >>= 1;\
    _f |= sz53pvTable[byte];\
}

#define Sra(byte)\
{\
    _f = byte & C_BIT;\
    byte = (byte & 0x80) | (byte >> 1);\
    _f |= sz53pvTable[byte];\
}

#define Bit(num, byte)\
{\
    _f = (_f & C_BIT ) | H_BIT | ( byte & ( THREE_BIT | FIVE_BIT));\
    if (!(byte & (0x01 << num))) {\
        _f |= PV_BIT | Z_BIT;\
    }\
    if (num == 7 && (byte & 0x80)) {\
        _f |= S_BIT; \
    }\
}

#define Res(num, byte)\
{\
    byte &= ~(1 << num);\
}

#define Set(num, byte)\
{\
    byte |= (1 << num);\
}

#define IndexAdd(word)\
{\
    UInt32 add16temp = _ixy + word;\
    UInt8 lookup = ((_ixy & 0x0800) >> 11) | ((word & 0x0800) >> 10) | ((add16temp & 0x0800) >> 9);\
    _ixy = add16temp;\
    _f = (_f & (PV_BIT | Z_BIT | S_BIT)) | (add16temp & 0x10000 ? C_BIT : 0 ) | ((add16temp >> 8) & (THREE_BIT | FIVE_BIT)) | halfcarry_add_table[lookup];\
}

#define IncR \
{\
    if (r & 0x80) {\
        UInt8 byte = r & 0x7f;\
        byte++;\
        if (byte == 0x80) {\
            byte = 0;\
        }\
        r = byte | 0x80;\
    } else {\
        r++;\
        if (r & 0x80) {\
            r = 0;\
        }\
    }\
}

#define IndexBit(num, offs)\
{\
    UInt8 value = memory[offs];\
    _f = (_f & C_BIT ) | H_BIT | ((offs >> 8) & (THREE_BIT | FIVE_BIT));\
    if (!(value & (0x01 << num))) {\
        _f |= PV_BIT | Z_BIT;\
    }\
    if (num == 7 && (value & 0x80)) {\
        _f |= S_BIT;\
    }\
    IncCounters(20);\
}

#define IndexRes(num, offs)\
{\
    UInt8 byte = memory[offs];\
    byte &= ~(0x01 << num);\
    SetMemory(offs, byte)\
    IncCounters(23);\
}

#define IndexSet(num, offs)\
{\
    UInt8 byte = memory[offs];\
    byte |= (0x01 << num);\
    SetMemory(offs, byte)\
    IncCounters(23);\
}

#define xOut(high, low)\
{\
    if (high == 0xfe) {\
        _borderColour = low & 0x07;\
        if (low & 0x10) {\
            if (!beep) {\
                beep = true;\
                clicksCount++;\
            }\
        } else {\
            if (beep) {\
                beep = false;\
                clicksCount++;\
            }\
        }\
    }\
}

#define xxOut(high, low)\
{\
    if (high == 0xfe) {\
        _borderColour = low & 0x07;\
        if (low & 0x10) {\
            if (!beep) {\
                beep = true;\
                clicksCount++;\
            }\
        } else {\
            beep = false;\
        }\
    }\
}

#define Out(high, low)\
{\
    if (high == 0xfe) {\
        _borderColour = low & 0x07;\
        if (low & 0x10) {\
            clicksCount++;\
        }\
    }\
}

#define In(oper, high, low)\
{\
    UInt8 byte = 0x00;\
    if (low == 0xfe) {\
        switch (high) {\
            case 0xfe:\
                byte = keys[0];\
                break;\
            case 0xfd:\
                byte = keys[1];\
                break;\
            case 0xfb:\
                byte = keys[2];\
                break;\
            case 0xf7:\
                byte = keys[3];\
                break;\
            case 0xef:\
                byte = keys[4];\
                break;\
            case 0xdf:\
                byte = keys[5];\
                break;\
            case 0xbf:\
                byte = keys[6];\
                break;\
            case 0x7f:\
                byte = keys[7];\
                break;\
            case 0x7e:\
                byte = keys[0] & keys[7];\
                break;\
            case 0x00:\
                byte = keys[0] & keys[1] & keys[2] & keys[3] & keys[4] & keys[5] & keys[6] & keys[7];\
                break;\
            default: {\
                byte = KEY_DEF;\
                UInt8 value = high ^ 0xff;\
                UInt8 bit = 0x01;\
                for (uint loop = 0; loop < 8; loop++) {\
                    if (value & bit) {\
                        byte = byte & keys[loop];\
                    }\
                bit <<= 1;\
                }\
            }\
            break;\
        }\
    } else if (low == 0x1f) {\
        byte = kempston;\
    } else if (low == 0xff) {\
        if ((videoRow < 64) || (videoRow > 255)) {\
            byte = 0xff;\
        } else {\
            if ((ula >= 24) && (ula <= 152)) {\
                UInt16 rowNum = videoRow - 64;\
                UInt16 attribAddress = ATTRIBUTES + ((rowNum >> 3) << 5);\
                UInt16 col = (ula - 24) >> 2;\
                byte = memory[attribAddress + col];\
            } else {\
                byte = 0xff;\
            }\
        }\
    } else {\
        byte = 0xff;\
    }\
    _f = (_f & C_BIT) | sz53pvTable[byte];\
    oper = byte;\
}

#define IncCounters(value)\
    counter += value;\
    ula += value;\
    soundCounter += value;\

#endif








