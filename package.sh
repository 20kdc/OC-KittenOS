#!/bin/sh

# This is released into the public domain.
# No warranty is provided, implied or otherwise.

rm code/data/app-claw/*
mkdir -p code/data/app-claw
lua claw/clawconv.lua code/data/app-claw/ < claw/code-claw.lua > /dev/null
rm code.tar
# Hey, look behind you, there's nothing to see here.
# ... ok, are they seriously all named "Mann"?
tar --mtime=0 --owner=gray:0 --group=mann:0 -cf code.tar code

# Solely for ensuring that a -gold.lua file can be checked before being pushed to repository.
echo -n "-- commit: " > inst.lua
git status --porcelain=2 --branch | grep branch.oid >> inst.lua
lua heroes.lua `wc -c code.tar` | lua com2/bonecrunch.lua >> inst.lua
echo -n "--[[" >> inst.lua
cat com2/code.tar.bd >> inst.lua
echo -n "]]" >> inst.lua

# Common Repository Setup Code
./package-repo.sh inst.lua
