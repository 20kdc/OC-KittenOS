# KittenOS: A graphical OpenComputers OS that runs light.

## Why?
Because OpenOS needs *two* Tier 1 memory chips to run a text editor,
 in a basic console environment that reminds me of DOS more than a Unix,
 despite the inspirations.
This OS only needs one Tier 1 memory chip - that's 192KiB...

## Couldn't save a file from a text editor on a 192KiB system.

Switch to Lua 5.3 - Lua 5.2 has a nasty habit of leaking a big chunk of memory.

Given this hasn't happened with Lua 5.3, I can only guess this is an issue with 5.2.

(Tested on OpenComputers 1.6.0.7-rc.1 on Minecraft 1.7.10.
 Judging by the "collectgarbage" call in machine.lua,
 they may have the same problem???)

## Why the complicated permissions and sandboxing?

Because I wanted to try out some security ideas, like not letting 
 applications access files unless the user explicitly authorizes access 
 to that file. Aka "ransomware prevention".

Yes, I know it uses memory, but I actually had *too much* memory.

## Why is the kernel so big and yet in one file?

File overhead is one of the things I suspect caused OpenOS's bloat.
(It helps that writing the kernel like this reduces boot time -
 only one file has to be loaded for the system to boot.
 More files are required to use some functions which are used relatively 
  rarely - like the file manager - as a tradeoff on memory.)

## Why does get_ch exist? Why not use a window buffer?

Because memory.
This way, 80x25 and 160x50 should use around about the same amount of memory.
It also fit nicely with the way only sections of the screen are drawn.

## Why do the window titlebars look inverted on Tier 3 hardware, but not Tier 2?

There was a bit of value trickery required to get the same general effect on all 3 tiers.

## Why do I have to return true in so many functions if I want a redraw?

Because if you redraw all the time, you use more energy.

(Though energy's really a secondary priority to memory, costs resources
 all the same.)

## Why aren't (partial redraws/GPU copys/GPU copys for moving windows) supported?

They didn't seem to be a requirement once I optimized the GPU call count.

If the system had still been running slow after that, I'd have done it.

## Why does the text editor use up so much (energy/time)?

The text editor is probably one of the bigger windows in KittenOS.
Try making it smaller with the controls it gives.

## What's "lineclip"?

A poor excuse for a clipboard.
You don't need to interact with it,
 though *Shift-C* on it kills it (thus clearing the clipboard).

## Why is *Shift-C* used everywhere to safely close things?

Because Enter is used as an action button, Escape's right out,
 Delete's probably missing on keyboards by now,
 *Ctrl-C* is also copy, and anything with Alt in it
 is supposed to be a Window Manager trap.

## Why is there no "kill it" button?

I'm sticking it here so that people don't make using this a habit -
 so that application developers can do something before app death.

If you must ask, *Alt-C* will kill the currently focused app.

## An app infinite-looped / ate memory and the system died.

Yep. There isn't much of a way to protect against memory-eaters.
On the other hand, you do know not to start that app again, and it 
 didn't get a chance to do harm.

## Isn't building a window manager into the OS kind of, uh, monolithic?

Given the inaccuracies relative to real computers anyway,
 I think of it as that OpenComputers itself is the kernel,
 but it can only handle a single task, written in Lua,
 so people build on top of it to make an interface.

(And given the memory limitations, having a cooperatively multitasking 
 microkernel which then gives all it's capabilities to the window 
 manager would succeed only in complicating things and then using all 
 memory, in that precise order.
 This way accomplishes the same thing, and it's simpler.)

## How's multilingual support?

Multilingual support exists, but the languages are Pirate and English.
Most applications are bare-bones enough that they don't have any strings
 that need to be translated - I consider this a plus.

The infrastructure for a system language exists, but is not really in use.
(This includes the installer copying language files for the selected language,
 but the only thing with a language selector at the moment is the installer.
 Language selection is performed by editing the "language" file
  at the drive root and rebooting, or switching language during install.)

The infrastructure is quite minimal so as not to bloat the system too badly -
 it's up to the applications to decide how to implement multi-language support,
 but the system can load files from lang/<language>/<pkg>.lua to aid in this.
 (Why loading files? To avoid having every single language loaded at once.
  Why loading Lua files? To avoid making this feature bloat the system.)

As for the issue of wide characters (Chinese/Japanese/Korean support):

Wide characters are supported in all supplied apps that handle text,
 including the text editor -
 the helper API function unicode.safeTextFormat should make these things easier.

(safeTextFormat is allowed to rearrange the text however it needs to for 
 display - this leaves the possibility of RTL layout open.)
