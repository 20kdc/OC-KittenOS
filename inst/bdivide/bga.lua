-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

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
