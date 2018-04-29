# KittenOS NEO

As per usual, no warranty, not my responsibility if this breaks, or if you somehow try to run it on an actual (non-OpenComputers) computer.

## Description

At least in theory: "efficient. multi-tasking. clean. security-oriented".

KittenOS NEO is an OpenComputers operating system designed for Tier 1 hardware.

This means, among other things, it has an operating overhead limit of 192KiB in os.totalMemory() units, on 32-bit or 64-bit runtimes (given the default scale value).

Unlike the original KittenOS (now in the "legacy" branch), it is also designed with some attempt at cleanliness.

## User Guide

It is recommended that you take out your OpenComputers CPU, and shift-right-click until it says "Architecture: Lua 5.3", if possible.

Then simply download the installer from inst.lua here, rename it to "init.lua" and put it on a blank disk.

Finally, remove all other disks and reboot.

KittenOS NEO will install itself.

(This does not account for custom EEPROMs.)

NOTE: Attempting to run the KittenOS NEO installer as a program in an OS will fail,
 giving you instructions as shown here.

## Authors & Licensing

Disclaimer: I Am Not A Lawyer. I probably screwed something up in this.

It would be really nice if, if I have screwed up, that you tell me how.

Preferably with a solution that fits the technological constraints.

Licensing in this project is rather fluid,
 but everything in code/ is unconditionally under the following license:

    This is released into the public domain.
    No warranty is provided, implied or otherwise.

This will be referred to as "Public Domain".

It should be considered equivalent to CC0, and this is the intent,
 but it is smaller, which is somewhat important when optimizing for size.

At this time, the majority of the code/ folder is by 20kdc, but exceptions may occur.

These exceptions will be documented below, and must be for a PR affecting code/ to be accepted:

```
No exceptions exist at this time.
```

The repository folder is much more complex, as the structure represents places in a running system,
 so licensing information cannot be directly bundled with the files that require it.

The contents of the repository/docs/licensing files represent a "full text" for a given license,
 used in order to ensure legal compliance with a given license's "distribute with the program" clauses.

It is assumed that this is sufficient.

A separate package is used for each license such that the user must go out of their way to not download the license.

The limitations of OpenComputers affect the available choices here, and having separate license copies for each package is not an available choice.

Nor is having a separate license package for each individual license, unless you would prefer an unbrowsable repository.

The contents of the repository/docs/repoauthors folder
 is a human-readable per-package manifest of all files and their 
 licenses.

If you find this uncompliant with the license of a package,
 please request the removal of the affected packages.

## About NOTE-TO-MS.asc

It exists because it needs to exist.
It does not represent the opinions of those who have contributed to the repository,
 only those of the person who digitally signed it (20kdc).

## Known Issues (That Aren't KittenOS NEO's Fault)

Touch calibration could be off if the setPrecise support mess didn't work properly.

Wide character support *may* encounter issues due to performance-saving tricks (?) in some old OC versions.

The 1.12.2 version being used at LimboCon doesn't have the issue, so it's been dealt with. Point is, not a KittenOS NEO bug if it happens.

## Known Issues (That Are KittenOS NEO's Fault But Aren't Really Fixable)

Having a window around that uses the palette-setting interface can cause funky graphical issues on
 a window that does not receive or lose focus when the palette changes.
The alternative is rerendering all windows on palette change, or attempting to detect this particular case.
This isn't very fast, so the graphics corruption is considered worth it.
Critical UI gets protected from this by having a set of 4 reserved colours,
 but this can't be expanded without hurting Tier 2 systems.

If you move a window over another window, that window has to rerender. The alternative is buffering the window. Since memory is a concern, that is not going to happen. Some windows are more expensive to render than others (`klogo` tries to use less RAM if the system is 192K, at the expense of disk access) - move the most expensive window out of the way, since once a window is top-most, moving it around is usually "free".

If the system runs out of memory, the kernel could crash, or alternatively the system goes into a limbo state. You're more or less doomed.
Given that almost everything in Lua causes a memory allocation, I'm not exactly sure how I'd be supposed to fix this properly.

Any situation where the system fails to boot *may* be fixable with Safe Mode.
This includes if you copied a sufficiently large bit of text into the persistent clipboard, and now Icecap or Everest won't start.
The catch is, it wipes your settings. As the settings are always in RAM, and contain just about every *fixable* thing that can break your boot,
 nuking them should bring you to defaults.

And finally, just because a system can multitask somewhat on 192K doesn't mean it can do the impossible regarding memory usage.
Lesson learned: Cleaner design -> Higher memory usage.
So anyone who wants the design to be made even cleaner should probably reread this paragraph.
(In R0, editing the kernel causes 192K systems to fail to open filedialogs. I've fixed this in R1.
 I don't know if I've screwed this up in R2, because all this focus on usability improvements has probably gone back a step regarding memory use.)

## Policy regarding updates

KittenOS NEO's installer, including the full KittenOS NEO base operating system, is 65536 bytes or below.

As the installer must be loaded in full into RAM, this is not negotiable.

If it can't be kept this way with the current compressor, then a better compressor will have to be made.

Frankly I don't even know what policy after that ought to be.

## Building

The tools are meant for internal use, so are thus designed to run on some generic Unix.

The tools that I haven't gotten rid of are the ones that still work properly.

Firstly, for an uncompressed installer (just to test installer basecode), you use `mkucinst.lua`.

Secondly, for a compressed installer, you use `package.sh`.

That rebuilds `code.tar` and `inst.lua`, and also prepares the final structure of the repository to upload.

