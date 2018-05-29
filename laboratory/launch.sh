#!/bin/sh

# This is released into the public domain.
# No warranty is provided, implied or otherwise.

XPWD=`pwd`
export XPWD

cd "$OCEMU/src"
./boot.lua "$XPWD"
