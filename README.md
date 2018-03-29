# KittenOS NEO (pre-release)

As per usual, no warranty, not my responsibility if this breaks, or if you somehow try to run it on an actual (non-OpenComputers) computer.

The first commit is after I got the installer working again after the new compression system (BDIVIDE).

That's what the "SYSTEM HEROES" thing is about.

## Description

At least in theory: "efficient. multi-tasking. clean. security-oriented".

KittenOS NEO is an OpenComputers operating system designed for Tier 1 hardware.

This means, among other things, it has an operating overhead limit of 192KiB real-world (on 32-bit or 64-bit).

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

Everything following is completely a draft. This is more like a guideline rather than actual policy.

All kernel or security-critical `sys-` process bugs will cause an installer update.

Other bugs will merely result in an updated copy in the repository.

This copy will be copied to installer code if and only if another condition requires the installer code be updated.

The code in the `code/` folder is the code meant for the installer.

Non-installer code is in the `repository/`, and thus accessible via CLAW.

As HTTPS is not used for this due to various weirdness that occurs when I try, I'm hosting the repository and `inst.lua` at `http://20kdc.duckdns.org/neo`.

Requests for additional features in system APIs will NOT cause an installer update.

## Building

The tools are meant for internal use, so are thus designed to run on some generic Unix.

The tools that I haven't gotten rid of are the ones that still work properly.

Firstly, for an uncompressed installer (just to test installer basecode), you use `mkucinst.lua`.

This kind of has some overlap with `package.sh` so that needs to be dealt with at some point.

Secondly, for a compressed installer, you use `package.sh` to rebuild `code.tar`, then use something along the lines of:

    lua heroes.lua `wc -c code.tar` > inst.lua

This will build the compressed installer.

## Kernel Architecture

KittenOS NEO is an idea of what a Lua-based efficient microkernel might look like.

Scheduling is based entirely around uptime and timers,
 which cause something to be executed at a given uptime.

That said, for a microkernel it's still a bit larger than I'd have hoped.

If anyone has any ideas, put them in an issue? If they're not too damaging, I'll use the saved space to add a thank-you-note to them in the kernel.

## Installer Architecture

The installer is split into a generic TAR extractor frontend `insthead.lua` and a replacable compression backend (written in by relevant tools - in current versions, `heroes.lua` is where it starts).

There was more details on this but the details changed.

## License

    This is released into the public domain.
    No warranty is provided, implied or otherwise.

