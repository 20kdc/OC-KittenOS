#!/bin/sh

# This is released into the public domain.
# No warranty is provided, implied or otherwise.

cp ocemu.cfg.default ocemu.cfg && rm -rf c1-sda c1-sdb tmpfs
mkdir c1-sda c1-sdb
echo -n c1-sda > c1-eeprom/data.bin
cd ..
./package.sh $*
cp inst.lua laboratory/c1-sda/init.lua
