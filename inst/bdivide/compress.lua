-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- PREPROC (r9 edition): preprocess input to be 7-bit

local frw = require("libs.frw")

local
-- SHARED WITH DECOMPRESSION ENGINE
function p(x, y)
 if x == 126 then
  return string.char(y), 3
 elseif x == 127 then
  return string.char(128 + y), 3
 elseif x >= 32 then
  return string.char(x), 2
 elseif x == 31 then
  return "\n", 2
 elseif x == 30 then
  return "\x00", 2
 end
 return string.char(("enart"):byte(x % 5 + 1), ("ndtelh"):byte((x - x % 5) / 5 + 1)), 2
end

local preprocParts = {}
local preprocMaxLen = 0
for i = 0, 127 do
 for j = 0, 127 do
  local d, l = p(i, j)
  if d then
   preprocMaxLen = math.max(preprocMaxLen, #d)
   l = l - 1
   if (not preprocParts[d]) or (#preprocParts[d] > l) then
    if l == 2 then
     preprocParts[d] = string.char(i, j)
    else
     preprocParts[d] = string.char(i)
    end
   end
  end
 end
end

local function preprocWithPadding(blk, p)
 local out = ""
 local needsPadding = false
 while blk ~= "" do
  p(blk)
  local len = math.min(preprocMaxLen, #blk)
  while len > 0 do
   local seg = blk:sub(1, len)
   if preprocParts[seg] then
    out = out .. preprocParts[seg]
    needsPadding = #preprocParts[seg] < 2
    blk = blk:sub(#seg + 1)
    break
   end
   len = len - 1
  end
  assert(len ~= 0)
 end
 -- This needsPadding bit is just sort of quickly added in
 --  to keep this part properly maintained
 --  even though it might never get used
 if needsPadding then
  return out .. "\x00"
 end
 return out
end

local bdCore = require("bdivide.core")

return function (data, lexCrunch)
 io.stderr:write("preproc: ")
 local pi = frw.progress()
 local function p(b)
  pi(1 - (#b / #data))
 end
 data = preprocWithPadding(data, p)
 io.stderr:write("\nbdivide: ")
 pi = frw.progress()
 data = bdCore.bdividePad(bdCore.bdivide(data, p))
 io.stderr:write("\n")
 return lexCrunch.process(frw.read("bdivide/instdeco.lua"), {}), data
end
