#!/bin/sh

# This is released into the public domain.
# No warranty is provided, implied or otherwise.

# Package repository using supplied inst.lua (use inst-gold.lua for repository branch)

stat repobuild/data/app-claw && rm -rf repobuild
mkdir repobuild
cp -r code/* repobuild/
cp -r repository/* repobuild/
cp $1 repobuild/
lua claw/clawconv.lua repobuild/data/app-claw/ < claw/code-claw.lua > repobuild/data/app-claw/local.c2l
lua claw/clawconv.lua repobuild/data/app-claw/ < claw/repo-claw.lua >> repobuild/data/app-claw/local.c2l
