#!/bin/sh

# This is released into the public domain.
# No warranty is provided, implied or otherwise.

rm code.tar
# Hey, look behind you, there's nothing to see here.
# ... ok, are they seriously all named "Mann"?
tar --owner=gray:0 --group=mann:0 -cf code.tar code
