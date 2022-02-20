# SpeccyMac

ZX Spectrum emulator for macOS (currently 48K only), written in Swift 5.

Requires Xcode 13 to build.

Please see issues to check known problems. Please raise more if yours isn't there.

Collaborators welcomed.

![ScreenShot](https://user-images.githubusercontent.com/622889/29965616-351e1960-8f06-11e7-81e5-813cc66977b0.png)

## Performance

* Pretty good when running a release build (quite a bit slower on a debug build).
* Sound tends to be a bit scratchy, don't know why yet.
* Kempston joystick is emulated on cursor keys and tilde (key between shift and Z) to fire.

## Lots of things still to do

* Joypad support
* Hi-res border
* Check all timings
* Contended memory
* Add zip support
* Add Z80 file support
* Add TZX/SZX file support
* 128K mode
* AY sounds
* Lots more unit tests

## Acknowledgements

* All included games have distribution permitted, see: http://worldofspectrum.org/archive.html
* AudioStreamer code by jmayoralas, https://github.com/jmayoralas/Sems
* F-register look up tables from Fuse, http://fuse-emulator.sourceforge.net/
