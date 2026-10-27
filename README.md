# SpeccyMac

ZX Spectrum emulator for macOS written in Swift.

Please see issues to check known problems. Please raise more if yours isn't there.

Collaborators welcomed.

<img width="1092" height="1046" alt="Screenshot 2026-10-27 at 06 37 09" src="https://github.com/user-attachments/assets/3bc56b36-2c5b-4410-80fe-123f177c1137" />

## Notes

* Kempston joystick is emulated on cursor keys and tilde (key between shift and Z) to fire.

## Things still to do

* Mac joypad support

## Done

* Contended memory
- 128K support with AY
* Zip support
* Z80 file support (thanks to hippietrail)
* TAP and TZX tape loading (with fast load)
- SZX support
* Metal rendering with display modes (crisp / smooth / scanlines / CRT)

## Acknowledgements

* All included games have distribution permitted, see: http://worldofspectrum.org/archive.html
* AudioStreamer code by jmayoralas, https://github.com/jmayoralas/Sems
* F-register look up tables from Fuse, http://fuse-emulator.sourceforge.net/
