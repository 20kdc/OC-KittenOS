-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

local bga = {}

local str = io.read("*a")

for i = 1, #str - 1 do
 local bg = str:sub(i, i + 1)
 bga[bg] = (bga[bg] or 0) + 1
end

local first = {}
local second = {}

local mode = ...

for k, v in pairs(bga) do
 if mode == "combined" then
  print(string.format("%08i: %02x%02x : %s", v, k:byte(1), k:byte(2), k))
 end
 first[k:sub(1, 1)] = (first[k:sub(1, 1)] or 0) + v
 second[k:sub(1, 1)] = (second[k:sub(1, 1)] or 0) + v
end

for k, v in pairs(first) do
 if mode == "first" then
  print(string.format("%08i: %s", v, k))
 end
end

for k, v in pairs(second) do
 if mode == "second" then
  print(string.format("%08i: %s", v, k))
 end
end
