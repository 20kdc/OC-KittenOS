#!/bin/sh

# This is released into the public domain.
# No warranty is provided, implied or otherwise.

stat repobuild/data/app-claw/local.lua && rm -rf repobuild
mkdir repobuild
cp -r code/* repobuild/
cp -r repository/* repobuild/
cp inst-gold.lua repobuild/inst.lua
lua claw/clawconv.lua repobuild/data/app-claw/ < claw/code-claw.lua > repobuild/data/app-claw/local.c2l
lua claw/clawconv.lua repobuild/data/app-claw/ < claw/repo-claw.lua >> repobuild/data/app-claw/local.c2l
