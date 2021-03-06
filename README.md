# SpeccyMac
ZX Spectrum emulator for OSX (currently 48K only), written in Swift 5

Requires Xcode 11 to build

Please see issues to check known problems. Please raise more if yours isn't there.

Collaborators welcomed.

![ScreenShot](https://user-images.githubusercontent.com/622889/29965616-351e1960-8f06-11e7-81e5-813cc66977b0.png)

Performance:<br>
Pretty good when running a release build (quite a bit slower on a debug build).<br>
Sound tends to be a bit scratchy, don't know why yet.

Kempston joystick is emulated on cursor keys and tilde (key between shift and Z) to fire

Lots of things still to do:<br>
Joypad support<br>
Hi-res border<br>
Check all timings<br>
Contended memory<br>
Add zip support<br>
Add Z80 file support<br>
Add TZX/SZX file support<br>
128K mode<br>
AY sounds<br>
Lots more unit tests<br>
<br>
All included games have distribution permitted, see: http://worldofspectrum.org/archive.html<br>

# Acknowledgements
AudioStreamer code by jmayoralas, https://github.com/jmayoralas/Sems<br>
F-register look up tables from Fuse, http://fuse-emulator.sourceforge.net/
