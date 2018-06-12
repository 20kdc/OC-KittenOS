#!/bin/sh

# This is released into the public domain.
# No warranty is provided, implied or otherwise.

rm code/data/app-claw/*
lua claw/clawconv.lua code/data/app-claw/ < claw/code-claw.lua > /dev/null
rm code.tar
# Hey, look behind you, there's nothing to see here.
# ... ok, are they seriously all named "Mann"?
tar --owner=gray:0 --group=mann:0 -cf code.tar code
lua heroes.lua `wc -c code.tar` | lua com2/bonecrunch.lua > inst.lua
echo -n "--[[" >> inst.lua
cat com2/code.tar.bd >> inst.lua
echo -n "]]" >> inst.lua

stat repobuild/data/app-claw && rm -rf repobuild
mkdir repobuild
cp -r code/* repobuild/
cp -r repository/* repobuild/
cp inst.lua repobuild/
lua claw/clawconv.lua repobuild/data/app-claw/ < claw/code-claw.lua > repobuild/data/app-claw/local.c2l
lua claw/clawconv.lua repobuild/data/app-claw/ < claw/repo-claw.lua >> repobuild/data/app-claw/local.c2l
