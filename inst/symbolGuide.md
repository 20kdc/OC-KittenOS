# The Symbol Guide

## lexCrunch commands

The following prefixes are really special,
 and are lexcrunch's responsibility:

"$$THING" : These are defines.
"$Thing" : Writes a global into stream. If not already allocated, is allocated a global.

"${" : Opens a frame.
"$}" : Closes a frame. (Attached temps are released.)
"$L|THING" : Allocates THING from temp pool, attaches to stack frame, writes to stream.
 Use inside a comment to erase the written symbol

## Conventions

The rest are convention:
"$iThing" symbols are Installer Wrapper.
"$icThing" symbols are Installer Core.
"$dfThing" symbols are DEFLATE Engine.
"$bdThing" symbols are BDIVIDE Engine.

"$a0", "$a1", etc. are Local Symbols.
DEPRECATED, THESE ARE AN OLD MECHANISM, USE FRAMED TEMPS INSTEAD.
These are reserved only for use in locals.
(For loops count.)

"$lThing" symbols are used to name Local Symbols using aliases.

NO THEY ARE NOW USED FOR ALL TEMPS, INCLUDING LOCAL SYMBOLS

