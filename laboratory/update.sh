#!/bin/sh

# This is released into the public domain.
# No warranty is provided, implied or otherwise.

cd ..
cp -r code/* laboratory/c1-sdb/
cp -r repository/* laboratory/c1-sdb/
lua claw/clawconv.lua laboratory/c1-sdb/data/app-claw/ < claw/code-claw.lua > /dev/null
lua claw/clawconv.lua laboratory/c1-sdb/data/app-claw/ < claw/repo-claw.lua >> /dev/null
cp -r laboratory/c1-sdb/* laboratory/c1-sda/
