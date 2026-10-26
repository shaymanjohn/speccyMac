# 128K AY Sound — RESOLVED

Status: **FIXED. 128K AY music confirmed audible in-game (Cybernoid 128K),
verified live with the debugger and by ear.** All AY unit tests pass.

## Root cause (the silence)

The Z80 opcode **`OUT (C),E` (ED 59) was not implemented.**

Cybernoid's 128K music player selects each AY register with `OUT (C),E`
(its inner loop: `LD BC,0xFFFD; OUT (C),E` to select register E, then
`LD BC,0xBFFD; OUT (C),A` to write the data). An earlier pass had added the
B/C/D/H/L/A variants of `OUT (C),r` but **missed E**. So every register-select
fell through `edprefix`'s `default: break` and was silently dropped. The data
writes (via the implemented `OUT (C),A`) then all landed in whatever register
was last successfully selected — **register 14** (selected by the ROM/keypad
input polling). The mixer (reg 7) therefore stayed at its power-on `0xFF`
(all channels disabled) and volumes stayed 0 -> total silence, even though the
player was running correctly and streaming valid music data every frame.

Fix: added `case 0x59` (OUT (C),E) in `Z80+ed.swift`. The z80ops.json timing
entry for 0x59 was already correct (length 2, 12 T-states).

How it was found: attached the debugger to the live in-game process, read the
AY state (`registers[7]=0xFF`, volumes 0, `selectedRegister=14` persistently),
set a breakpoint on `AYChip.writeData`, and from the emulated PC (0xEFBA, in the
paged bank) disassembled the player's write loop — which selects via `OUT (C),E`.

Regression test: `Spectrum128Tests.testOutCEViaSelectsAYRegister`.

## Also fixed along the way

1. **Build was broken.** The SwiftLint build phase treats a Cyclomatic
   Complexity violation as an *error*; `Z80Loader.loadV2V3` was over the limit.
   Fixed with `// swiftlint:disable:next cyclomatic_complexity` (same convention
   used on `edprefix`, `input`, etc.). Until this was fixed the project did not
   build at all.

2. **Tone pitch was an octave too low.** In `AYChip.render` the tone counter
   compared against `tonePeriod(ch) * 16`; the output toggles each period, and
   the note formula `f = clock / (16 * period)` is the toggle rate, so the
   threshold must be `period * 8`. Fixed. Verified period 0x00FC -> ~440Hz
   (was ~220Hz). Regression test: `testAYProducesAudibleTone`.

## Confirmed correct (do not "re-fix")

- AY chip (`AYChip.swift`): tone/noise/envelope/mixer.
- Wiring: `Spectrum128` owns the chip, assigns `beeper.ay`, and
  `beeper.endFrame()` mixes `ay.render(...)` every frame.
- 128K I/O decode in `Spectrum128.output` (0x7FFD paging, 0xFFFD AY select,
  0xBFFD AY data).
- IM2 interrupt handling (vectors correctly to the game's player).
- Tape loading of the 128K Cybernoid tap (loads fine).

## Tests

- `AYChipTests` — chip behaviour.
- `Spectrum128Tests.testOutCRSelectsAYRegister` — OUT (C),H selects AY register.
- `Spectrum128Tests.testOutCEViaSelectsAYRegister` — OUT (C),E selects AY register (this bug).
- `Spectrum128Tests.testAYProducesAudibleTone` — end-to-end audible + correct pitch.
- `Spectrum128Tests.testAYSurvivesTapeLoadReset` — AY stays wired after a tape-load reset.

All temporary diagnostics have been removed.
