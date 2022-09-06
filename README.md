# blueberry

Blueberry is yet another attempt at creating a functioning operating system.

This time, I have adopted the approach of writing highly commented code in an almost narrative style. In my opinion, this improves the understandability of large projects vastly and is severely underrated.

# Building

Blueberry is built using GNU Make. It probably will not work outside of a Linux environment. I know for a fact that it works on WSL since that is the primary environment I develop in.

You will need a couple dependencies, excluding tools found in util-linux:
* exfat-utils
* nasm
* a cross compiler targeting `i686-elf`

You can either search for prebuilt cross-compiler binaries for your host architecture or follow [this guide](https://wiki.osdev.org/GCC_Cross-Compiler) to build your own. 

Here's a description of all the make targets.
* `image`: build a flat disk image
* `clean`: nuke all build files
* `cleanup-disk`: clean up loopback devices and mounts

# Running

The system can be booted in QEMU with

```
qemu-system-i386 -drive file=disk.img,format=raw
```