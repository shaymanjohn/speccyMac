# 128K AY Sound — Debugging Handoff Notes

Status: **128K AY music is still silent.** Everything else about 128K works
(menu, paging, snapshot loading, cursor keys, reset, tape loading). Beeper
audio works on both 48K and 128K. All 53 unit tests pass.

## What works (confirmed)

- AY chip emulation (`AYChip.swift`): tone/noise/envelope/mixer all verified by
  unit tests (`AYChipTests`) and snippets.
- AY is wired into the audio path: `Spectrum128` owns the chip, `AudioStreamer`
  mixes it into each frame at `endFrame()`. Audio queue starts with `ay != nil`.
- The audio pipeline produces non-silent frames (beeper peak ~0.175 measured)
  and delivers them to the Metal/AudioQueue path.
- 128K I/O port decode (in `Spectrum128.output`) is correct and hardware-faithful:
  decode on A1=0 (`port & 0x0002 == 0`) then switch on A15/A14:
    - 0x4000 (A15=0,A14=1) -> paging (0x7FFD)
    - 0xC000 (A15=1,A14=1) -> AY register select (0xFFFD)
    - 0x8000 (A15=1,A14=0) -> AY data write (0xBFFD)
  (NOTE: an earlier rewrite that keyed off bit 0 broke paging entirely — the
  control ports are ODD. Reverted. Do not re-break this.)
- Added previously-MISSING Z80 opcodes in `Z80+ed.swift`: `IN/OUT (c),r` for
  B/C/H/L (`0x40/0x41/0x48/0x49/0x60/0x61/0x68/0x69`). Only D and A existed
  before. Cybernoid's player uses `OUT (C),A`/`OUT (C),L` etc. Regression test:
  `Spectrum128Tests.testOutCRSelectsAYRegister`.

## Key diagnostic findings (Cybernoid 128K, live)

The player's AY write routine (captured live) looks like:
    LD B,D      ; D = 0xFF  -> B = 0xFF  (select port high byte)
    LD A,n      ; n = register number
    OUT (C),A   ; ED 79: select register n on port 0xFFFD   (C = 0xFD)
    LD B,E      ; E = 0xBF  -> B = 0xBF  (data port high byte)
    OUT (C),L   ; ED 69: write data (L) on port 0xBFFD

Latest `DIAGSEL` capture CONFIRMS register selects now reach the AY correctly:
    DIAGSEL port=fffd selectByte=7  a=7     (mixer)
    DIAGSEL port=fffd selectByte=14 a=14    (keypad/IO port)
    ...
So selects on 0xFFFD now hit `ay.selectRegister`, and data on 0xBFFD hits
`ay.writeData`. The register latch should now track correctly.

## The remaining mystery

Despite selects + data now routing correctly, the user reports **still no sound**.
We have NOT yet re-confirmed the live AY register contents (mixer/volumes) after
the decode fix + opcode additions. The old "stuck at reg 14, mixer=0xFF, vol=0"
dumps were from BEFORE those fixes and are now stale.

## NEXT STEP (do this first)

Re-verify the LIVE AY register state after loading Cybernoid on 128K:
1. Launch with `attachDebugger: true`, or add a throttled dump in
   `AYChip.writeData` logging `registers[0...13]`.
2. Load Cybernoid 128K, let music "play".
3. Check: do registers 7 (mixer) and 8/9/10 (volumes) now hold real,
   changing values (mixer with some channels enabled = bits CLEARED; volumes
   non-zero)?

Branch on the result:
- **If mixer/volumes now have real values** -> the chip is being driven
  correctly and the bug is in `AYChip.render` (sound generation) or the mix
  level. Inspect `render()`: tone/noise period scaling (the `* 16` factors),
  the mixer polarity (set bit = DISABLE), and the output scaling
  (`(level / 3.0) * 0.5`). Consider that `channelLevel` returns 0 when volume
  is 0 — fine — but verify envelope-mode channels (reg bit 4 set) produce output.
- **If mixer/volumes are STILL 0 / 0xFF** -> selects are reaching the chip
  (per DIAGSEL) but data isn't landing in the selected register. Check for a
  select/data interleaving/ordering bug, or that `selectedRegister` isn't being
  reset between select and data (e.g. the 128K ROM interrupt keyscan selecting
  reg 14 between the player's select and data writes — the player runs with
  interrupts disabled, so confirm our interrupt isn't firing mid-sequence).

## Temporary diagnostics still in the tree (REMOVE when done)

- `Spectrum128.swift`:
    - `private var diagN = 0`
    - In `output()`, the AY-select branch has a `DIAGSEL` FileHandle log guarded
      by `diagN < 8`.
  Remove both and restore the plain select branch:
      case 0xC000:
          ay.selectRegister(byte)
          return

No other diagnostics remain (AYChip/AudioStreamer were cleaned).

## Files touched for AY work

- `AYChip.swift` (new) — the chip.
- `AudioStreamer.swift` — `ay` property + mix in `endFrame`.
- `Spectrum128.swift` — owns `ay`, routes 0xFFFD/0xBFFD, resets it; has the
  temporary DIAGSEL diagnostic.
- `Z80+ed.swift` — added the missing IN/OUT (c),r opcodes.
- `Spectrum.swift` — `input`/`output`/`captureRow`/`ticksPerFrame` de-finalised
  earlier for 128K.
- Tests: `AYChipTests.swift`, `Spectrum128Tests.testOutCRSelectsAYRegister`.

## Verify before shipping

- Remove the DIAGSEL diagnostic + `diagN`.
- `RunAllTests` should be 53/53.
- Confirm Cybernoid 128K actually produces audible AY music.
