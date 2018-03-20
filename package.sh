#!/bin/sh

# This is released into the public domain.
# No warranty is provided, implied or otherwise.

echo "WARNING: This will rm -rf the 'work' folder."
# safety measure: unless we are likely in the right folder, DO NOT CONTINUE
git status && stat imitclaw.lua code/apps/sys-init.lua && rm -rf work work.tar
lua imitclaw.lua && tar -cf work.tar work
