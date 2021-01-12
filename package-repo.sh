#!/bin/sh

# Copyright (C) 2018-2021 by KittenOS NEO contributors
#
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
# THIS SOFTWARE.

# Package repository using supplied inst.lua (use inst-gold.lua for repository branch)

# this is a guard check to avoid removing repobuild if it's blatantly
#  not the actual repobuild directory (this is an rm -rf after all)
stat repobuild/data/app-claw 1>/dev/null 2>/dev/null && rm -rf repobuild

mkdir -p repobuild
cp -r code/* repobuild/
cp -r repository/* repobuild/
cp $1 repobuild/inst.lua
lua claw/clawconv.lua repobuild/data/app-claw/ < claw/code-claw.lua > repobuild/data/app-claw/local.c2l
lua claw/clawconv.lua repobuild/data/app-claw/ < claw/repo-claw.lua >> repobuild/data/app-claw/local.c2l
