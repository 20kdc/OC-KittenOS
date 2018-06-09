#!/bin/sh

# This is released into the public domain.
# No warranty is provided, implied or otherwise.

rm code.tar
# Hey, look behind you, there's nothing to see here.
# ... ok, are they seriously all named "Mann"?
tar --owner=gray:0 --group=mann:0 -cf code.tar code
lua heroes.lua `wc -c code.tar` | lua com2/bonecrunch.lua > inst.lua
echo -n "--[[" >> inst.lua
cat com2/code.tar.bd >> inst.lua
echo -n "]]" >> inst.lua

stat repobuild/data/app-claw/local.lua && rm -rf repobuild
mkdir repobuild
cp -r code/* repobuild/
cp -r repository/* repobuild/
cp inst.lua repobuild/
lua clawmerge.lua repository/data/app-claw/local.lua code/data/app-claw/local.lua > repobuild/data/app-claw/local.lua
