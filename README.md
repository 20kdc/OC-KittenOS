# KittenOS NEO (pre-release)

As per usual, no warranty, not my responsibility if this breaks, or if you somehow try to run it on an actual (non-OpenComputers) computer.

The first commit is after I got the installer working again after the new compression system (BDIVIDE).

That's what the "SYSTEM HEROES" thing is about.

## Known Issues (That Aren't KittenOS NEO's Fault)

Touch calibration could be off if the setPrecise support mess didn't work properly.

Wide character support *may* encounter issues due to performance-saving tricks in some old OC versions. The 1.12.2 version being used at LimboCon doesn't have the issue, so it's been dealt with. Point is, not a KittenOS NEO bug if it happens.

## Known Issues (That Are KittenOS NEO's Fault But Aren't Really Fixable)

Having a window around that uses the palette-setting interface can cause funky graphical issues on
 a window that does not receive or lose focus when the palette changes.
The alternative is rerendering all windows on palette change, or attempting to detect this particular case.
This isn't very fast, so the graphics corruption is considered worth it.
Critical UI gets protected from this by having a set of 4 reserved colours,
 but this can't be expanded without hurting Tier 2 systems.

If you move a window over another window, that window has to rerender. The alternative is buffering the window. Since memory is a concern, that is not going to happen. Some windows are more expensive to render than others (`klogo` tries to use less RAM if the system is 192K, at the expense of disk access) - move the most expensive window out of the way, since once a window is top-most, moving it around is usually "free".

If the system runs out of memory, the kernel could crash, or alternatively the system goes into a limbo state. You're more or less doomed. Given that almost everything in Lua causes a memory allocation, I'm not exactly sure how I'd be supposed to fix this properly.

Any situation where the system fails to boot *may* be fixable with Safe Mode.
This includes if you copied a sufficiently large bit of text into the persistent clipboard, and now Icecap or Everest won't start.
The catch is, it wipes your settings. As the settings are always in RAM, and contain just about every *fixable* thing that can break your boot,
 nuking them should bring you to defaults.

And finally, just because a system can multitask somewhat on 192K doesn't mean it can do the impossible regarding memory usage.
Lesson learned: Cleaner design -> Higher memory usage.
So anyone who wants the design to be made even cleaner should probably reread this paragraph.
(In R0, editing the kernel causes 192K systems to fail to open filedialogs. I've fixed this in R1.)

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

