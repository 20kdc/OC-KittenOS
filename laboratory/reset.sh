#!/bin/sh

# This is released into the public domain.
# No warranty is provided, implied or otherwise.

cp ocemu.cfg.default ocemu.cfg && rm -rf c1-sda c1-sdb
mkdir c1-sda c1-sdb
echo -n c1-sda > c1-eeprom/data.bin

./update.sh
