#!/bin/sh

# Copyright (C) 2018-2021 by KittenOS NEO contributors
#
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
# THIS SOFTWARE.

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
lua build.lua `git status --porcelain=2 --branch | grep branch.oid | grep -E -o "[0-9a-f]*$" -` ../code.tar $* > ../inst.lua
lua status.lua ../inst.lua
cd ..

# Common Repository Setup Code
./package-repo.sh inst.lua
