# The Symbol Guide

The following prefixes are really special,
 and are lexcrunch's responsibility:

"$$THING" : These are defines.
"$Thing" : Writes a global into stream. If not already allocated, is allocated a global.

"$NT|THING" : Allocates THING from temp pool
"$DT|THING" : Returns temp THING to temp pool

"$NA|THING1|THING2" : Copies $THING2 to $THING1 in forwards table (not in backwards table)
"$DA|THING1" : Removes THING1 in forwards table.

"${" : Opens a frame.
"$}" : Closes a frame. (Attached temps are released.)
"$L|THING" : Allocates THING from temp pool, attaches to stack frame, writes to stream.

The rest are convention:
"$iThing" symbols are Installer Wrapper.
"$icThing" symbols are Installer Core.
"$dfThing" symbols are DEFLATE Engine.
"$bdThing" symbols are BDIVIDE Engine.

"$a0", "$a1", etc. are Local Symbols.
THESE ARE AN OLD MECHANISM, USE FRAMED TEMPS INSTEAD.
These are reserved only for use in locals.
(For loops count.)

"$lThing" symbols are used to name Local Symbols using aliases.

