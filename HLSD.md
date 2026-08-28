# speccyMac - High Level System Design

## 1. Overview

speccyMac is a ZX Spectrum 48K emulator for macOS, written in Swift. It emulates the Zilog Z80 CPU, ULA (video/audio/keyboard), and contended memory timing to run original Spectrum software from `.sna` and `.z80` snapshot files.

The emulator targets cycle-accurate timing for the display area, enabling correct rendering of software that relies on precise beam-position timing (border effects, colour cycling, multicolour tricks).

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         macOS Application                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  AppDelegate                                                        │
│      │                                                              │
│      ▼                                                              │
│  Emulator (NSViewController) ──────── GameSelectViewController      │
│      │                                     (modal game picker)      │
│      ├── EmulatorInputView (keyboard)                               │
│      │        ▲ polled by Spectrum.input()                          │
│      │                                                              │
│      ├── EmulatorImageView (display + drag-drop)                    │
│      │        ▲ layer.contents set by Spectrum.frameCompleted()     │
│      │                                                              │
│      └── Machine / Spectrum (core emulation) ◄── Loader             │
│               │                                   ├── SNALoader     │
│               ├── ZilogZ80 (CPU)                  └── Z80Loader     │
│               ├── Memory (64KB)                                     │
│               └── AudioStreamer (beeper)                             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 3. Threading Model

| Thread | Responsibility |
|--------|---------------|
| Main thread | UI, keyboard events, frame rendering (CGImage to CALayer) |
| Emulation thread | Z80 execution loop, ULA tick, audio sample generation |
| Audio callback thread | Reads from ring buffer, fills AudioQueue buffers |

The emulation thread runs continuously at ~50Hz (PAL frame rate). Frame images are dispatched to the main thread via `DispatchQueue.main.async`. Audio is decoupled via a lock-free ring buffer.

## 4. Component Details

### 4.1 Emulator (View Controller)

**File:** `Emulator.swift`

The main coordinator. Creates the `Spectrum` instance, wires the input view and display layer, and starts emulation. Handles game selection (modal UI) and drag-and-drop loading.

### 4.2 Spectrum (Machine)

**File:** `Spectrum.swift`  
**Protocol:** `Machine`

The heart of the emulator. Owns the CPU, memory, and audio subsystem. Responsibilities:

- **Video timing:** Tracks the ULA counter and video row. After every Z80 instruction, `tick()` checks if a full scanline (224 T-states) has elapsed and captures screen data at the appropriate row.
- **Frame rendering:** At video row 311 (end of frame), renders a 320x288 pixel bitmap (256x192 screen + border) and pushes it to the display layer.
- **Keyboard I/O:** Reads from `EmulatorInputView.keysDown` and translates macOS key codes to Spectrum keyboard matrix via a lookup table.
- **Border colour:** Tracks `OUT 0xFE` writes for per-scanline border colour.
- **Contended memory:** Maintains a 69888-entry contention delay table. Contention is applied transparently by `Memory.get()`/`Memory.set()` for all accesses to 0x4000-0x7FFF.
- **I/O contention:** `contendIO()` adds extra wait states for port accesses based on the port address and ULA port status.

### 4.3 ZilogZ80 (Processor)

**Files:** `z80/ZilogZ80.swift`, `z80/Z80+unprefixed.swift`, `z80/Z80+cb.swift`, `z80/Z80+dd.swift`, `z80/Z80+ed.swift`, `z80/Z80+ddcb.swift`  
**Protocol:** `Processor`

A complete Z80 CPU implementation. Key design choices:

- **Registers** are stored as individual `UInt8`/`UInt16` properties (not arrays) for performance.
- **Flags register** is static so `Memory` can update flags directly (for INC/DEC (HL) etc.).
- **T-state timing** is loaded from `z80ops.json` into flat `UnsafeMutablePointer` arrays at startup for fast lookup.
- **Main loop** fetches opcodes, dispatches to prefix handlers, and calls `machine.tick()` after each instruction.
- **HALT handling** is done inline in the main loop — when halted, only reads PC (for contention), adds 4 T-states, increments R, and continues until an interrupt arrives.
- **Operand reads** are demand-driven: single-byte instructions don't read operands, avoiding spurious contention.

### 4.4 Memory

**File:** `Memory.swift`

A flat 64KB address space backed by `UnsafeMutablePointer<UInt8>`. Key features:

- **ROM protection:** Writes below `romSize` (16384 for 48K ROM) are silently ignored.
- **Contended access:** `get()` and `set()` check if the address is in the contended range (0x4000-0x7FFF) and apply a delay from the Spectrum's contention table before the access completes.
- **Compound operations:** Provides `inc()`, `dec()`, `push()`, `pop()`, and bit manipulation methods that combine read-modify-write with flag updates.

### 4.5 AudioStreamer

**File:** `AudioStreamer.swift`

Emulates the Spectrum's beeper (1-bit audio output) using Apple's AudioQueue API.

- **Sample rate:** 48kHz mono, Float32.
- **Frame-based writing:** `updateSample()` is called on every ULA tick. It calculates amplitude from the EAR/MIC bits of the last `OUT 0xFE` value and writes into a per-frame buffer at an offset proportional to the current T-state.
- **Ring buffer:** Completed frames are pushed into a 4-frame ring buffer. The audio callback thread reads from this ring.
- **Underrun handling:** On underrun, the last known sample is held (avoids pops). On overflow, frames are dropped (avoids blocking the emulation thread).

### 4.6 Input Handling

**File:** `EmulatorInputView.swift`

An `NSView` subclass that captures `keyDown`/`keyUp`/`flagsChanged` events. Maintains a `keysDown` array of currently-pressed macOS key codes, polled by `Spectrum.input()` whenever the Z80 reads port 0xFE.

The Spectrum class translates macOS key codes to the Spectrum's 8-row keyboard matrix using a 61-entry `keyMap` lookup table.

Kempston joystick is emulated on cursor keys + backtick (fire).

### 4.7 Display

**File:** `EmulatorImageView.swift`

An `NSImageView` subclass that hosts the rendering CALayer and accepts drag-and-drop of game files.

The rendering path:
1. During emulation, `captureRow()` copies pixel and attribute data from memory at the appropriate scanline.
2. At frame end, `frameCompleted()` renders a full 320x288 bitmap (32px border each side, 48px top/bottom) from the captured screen/colour/border buffers.
3. The resulting `CGImage` is assigned to the layer's `contents` property on the main thread.
4. The layer uses `.nearest` magnification for sharp pixel scaling.

### 4.8 Game Loading

**Files:** `Loader.swift`, `Loaders/GameLoaderProtocol.swift`, `Loaders/SNALoader.swift`, `Loaders/Z80Loader.swift`

A factory pattern with protocol-based loaders:

| Format | File | Notes |
|--------|------|-------|
| `.sna` | `SNALoader.swift` | 48K snapshots. PC recovered from stack. |
| `.z80` | `Z80Loader.swift` | Version 1 only. Supports RLE compression. |

Loading flow: pause CPU → create Loader → restore registers + RAM → reset video/audio state → unpause CPU.

## 5. Timing Model

### 5.1 Frame Structure (48K Spectrum)

| Parameter | Value |
|-----------|-------|
| T-states per scanline | 224 |
| Scanlines per frame | 312 |
| T-states per frame | 69888 |
| Frame rate | 50.08 Hz |
| Display area | Scanlines 64-255 (192 lines) |
| Contended area per line | First 128 T-states |

### 5.2 Contention Pattern

During the display area, memory accesses to 0x4000-0x7FFF are delayed by the ULA. The pattern repeats every 8 T-states:

```
T-state offset:  0  1  2  3  4  5  6  7
Delay added:     6  5  4  3  2  1  0  0
```

### 5.3 I/O Contention

| Port address in 0x4000-0x7FFF? | Low bit = 0 (ULA)? | Contention |
|:---:|:---:|---|
| Yes | Yes | Delay at current T-state |
| Yes | No | Delay at current T-state |
| No | Yes | Delay at T-state + 1 |
| No | No | None |

### 5.4 Frame Timing Synchronisation

The Z80 loop counts T-states. When `counter >= 69888`, the frame is complete:
1. Sleep to maintain 50Hz real-time.
2. Reset counter (preserving overshoot).
3. Reset video row to 0.
4. If interrupts enabled: push PC, jump to interrupt handler.

## 6. Data Flow

```
ROM file (48.rom) ──► Memory.init()
                          │
Game file (.sna/.z80) ──► Loader ──► Memory + Z80 registers
                                         │
                                         ▼
                    ┌─── Z80 main loop (background thread) ───┐
                    │                                          │
                    │  fetch opcode ──► decode ──► execute     │
                    │       │                         │        │
                    │       ▼                         ▼        │
                    │  Memory.get(pc)           Memory.get/set │
                    │  (contention applied)     (contention)   │
                    │       │                         │        │
                    │       ▼                         ▼        │
                    │  incCounters(tstates)    machine.tick()  │
                    │                              │           │
                    └──────────────────────────────┼───────────┘
                                                   │
                              ┌─────────────────────┼──────────────────┐
                              │                     │                   │
                              ▼                     ▼                   ▼
                     AudioStreamer           captureRow()          borderBuffer
                     .updateSample()        (scanline data)       (border colour)
                              │                     │                   │
                              ▼                     └───────┬───────────┘
                     Ring Buffer                            │
                              │                            ▼
                              ▼                    frameCompleted()
                     Audio callback              (main thread)
                     (AudioQueue)                       │
                              │                        ▼
                              ▼                  CGImage → CALayer
                         Speaker                   (display)
```

## 7. Key Design Decisions

1. **Single instruction granularity:** T-states are accumulated per instruction (not per micro-op). This is a pragmatic trade-off between accuracy and performance.

2. **Contention in Memory.get/set:** Rather than modifying every opcode handler, contention is applied transparently at the memory access level. This ensures all accesses to screen RAM are contended regardless of which instruction triggered them.

3. **Eager scanline capture:** Screen data is captured one scanline at a time as the ULA counter advances. This enables mid-frame screen changes to be visible (important for games that modify screen data between scanlines).

4. **Per-scanline border:** Border colour is recorded per video row, enabling multicolour border effects.

5. **Lock-free audio:** The ring buffer between emulation and audio threads avoids mutex contention in the hot loop. Frame drops are preferred over blocking.

6. **UnsafeMutablePointer throughout:** Memory, screen buffers, colour tables, and T-state arrays all use raw pointers for performance. The emulation loop executes millions of iterations per second; array bounds checking would be measurable overhead.

## 8. File Manifest

| File | Lines | Role |
|------|-------|------|
| `Spectrum.swift` | ~400 | Machine core, ULA, video, I/O, contention |
| `z80/ZilogZ80.swift` | ~670 | CPU core, registers, ALU, main loop |
| `z80/Z80+unprefixed.swift` | ~750 | Unprefixed opcode handlers |
| `z80/Z80+cb.swift` | ~340 | CB-prefix (bit/rotate) opcodes |
| `z80/Z80+dd.swift` | ~200 | DD/FD-prefix (IX/IY) opcodes |
| `z80/Z80+ed.swift` | ~210 | ED-prefix (extended) opcodes |
| `z80/Z80+ddcb.swift` | ~50 | DDCB/FDCB-prefix opcodes |
| `Memory.swift` | ~170 | 64KB RAM with contention |
| `AudioStreamer.swift` | ~230 | Beeper audio via AudioQueue |
| `Emulator.swift` | ~65 | Main view controller |
| `EmulatorInputView.swift` | ~50 | Keyboard capture |
| `EmulatorImageView.swift` | ~80 | Display + drag-drop |
| `Loader.swift` | ~50 | Game loading factory |
| `Loaders/SNALoader.swift` | ~60 | .sna format loader |
| `Loaders/Z80Loader.swift` | ~90 | .z80 v1 format loader |
| `GameSelectViewController.swift` | ~50 | Game selection UI |
| `Machine.swift` | ~60 | Machine protocol + extension |
| `Structs.swift` | ~55 | Colour, KeyMap, Game structs |
| `AppDelegate.swift` | ~30 | App lifecycle |

## 9. Limitations and Future Work

- **48K only:** No 128K paging or AY sound chip support.
- **Z80 v1 snapshots only:** V2/V3 .z80 files with 128K bank switching not supported.
- **No tape loading:** No TZX/TAP support; games must be pre-loaded snapshots.
- **Prefixed instruction contention:** ED/DD/FD prefix operand reads still occur eagerly (minor timing inaccuracy for code executing from contended RAM).
- **LDIR/LDDR contention:** Block transfer instructions don't apply per-iteration contention to intermediate addresses.
- **No snow effect:** The I-register display corruption on real hardware is not emulated.
