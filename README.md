# KittenOS NEO
### efficient. multi-tasking. clean. security-oriented.

# WARNING! STATUS: UNSTABLE!

The first commit is after I got the installer working again after the new compression system (BDIVIDE).

The older compression systems (which are not compatible with `heroes.lua`) are kept in preSH.tar.gz in case you want to see how NOT to do things.

## Description

KittenOS NEO is an OpenComputers operating system designed for Tier 1 hardware.

This means, among other things, it has an operating overhead limit of 192KiB real-world (on 32-bit).

Unlike the original KittenOS (now in the "legacy" branch), it is also designed with some attempt at cleanliness.

## User Guide

It is recommended that you take out your OpenComputers CPU, and shift-right-click until it says "Architecture: Lua 5.3", if possible.

Then simply download the installer from inst.lua here, rename it to "init.lua" and put it on a blank disk.

Finally, remove all other disks and reboot.

KittenOS NEO will install itself.

(This does not account for custom EEPROMs.)

## Policy regarding updates

KittenOS NEO's installer, including the full KittenOS NEO base operating system, is 65536 bytes or below.

As the installer must be loaded in full into RAM, this is not negotiable.

If it can't be kept this way with the current compressor, then a better compressor will have to be made.

All kernel or security-critical `sys-` process bugs will cause an installer update.

Other bugs will merely result in an updated copy in the repository.

This copy will be copied to installer code if and only if another condition requires the installer code be updated.

The code in the `code/` folder is the code meant for the installer.

Non-installer code is in the `repository/`, (WORKING ON THIS) and thus accessible via CLAW.

(NOTE: HTTPS is not used for this due to OC/OCEmu issues.)

Requests for additional features in system APIs will NOT cause an installer update.

## Building

The tools are meant for internal use, so are thus designed to run on some generic Unix.

Firstly, you can create a "raw installer" (uncompressed) with `mkucinst.lua`.

This executes `tar -cf code.tar code`, which you will need to do in any case - the installer contains a compressed TAR.

Secondly, for a compressed installer, after creating the TAR, `symsear-st1.sh`, `symsear-st2.sh`, and `symsear-st4.sh` (st3 is executed by st2) are used.

## Kernel Architecture

KittenOS NEO is an idea of what a Lua-based efficient microkernel would look like.

Scheduling is based entirely around uptime and timers,
 which cause something to be executed at a given uptime.

## Installer Architecture

The installer is split into a generic TAR extractor frontend `insthead.lua` and a replacable compression backend (written in by relevant tools - in current versions, `heroes.lua` is where it starts).

There was more details on this but the details changed.

## License

    This is released into the public domain.
    No warranty is provided, implied or otherwise.

