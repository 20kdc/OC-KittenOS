#!/bin/sh

# This is released into the public domain.
# No warranty is provided, implied or otherwise.

rm code/data/app-claw/*
mkdir -p code/data/app-claw
lua claw/clawconv.lua code/data/app-claw/ < claw/code-claw.lua > /dev/null
rm code.tar
# Hey, look behind you, there's nothing to see here.
# ... ok, are they seriously all named "Mann"?
cd code
tar --mtime=0 --owner=gray:0 --group=mann:0 -cf ../code.tar .
cd ..

# Solely for ensuring that a -gold.lua file can be checked before being pushed to repository.
echo -n "-- KOSNEO inst. " > inst.lua
git status --porcelain=2 --branch | grep branch.oid >> inst.lua
echo "-- This is released into the public domain." >> inst.lua
echo "-- No warranty is provided, implied or otherwise." >> inst.lua

# The Installer Creator
cd inst
lua build.lua $1 ../code.tar >> ../inst.lua
cd ..

# Common Repository Setup Code
./package-repo.sh inst.lua
