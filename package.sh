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

# The Installer Creator
cd inst
lua build.lua $1 ../code.tar `git status --porcelain=2 --branch | grep branch.oid | grep -E -o "[0-9a-f]*$" -` > ../inst.lua
lua verify.lua $1 ../code.tar
cd ..

# Common Repository Setup Code
./package-repo.sh inst.lua
