-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- PREPROC (r9 edition): preprocess input to be 7-bit

local
-- SHARED WITH DECOMPRESSION ENGINE
function p(x, y)
 if x == 126 then
  if y >= 32 then
   return ({
    -- Before adding to this, check how installer size is changed.
    "\x7E", "\x7F"
   })[y - 31], 3
  end
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
 return string.char(("enart"):byte(x % 5 + 1), ("ndtelh"):byte(math.floor(x / 5) + 1)), 2
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

local function preproc(blk)
 local out = ""
 while blk ~= "" do
  local len = math.min(preprocMaxLen, #blk)
  while len > 0 do
   local seg = blk:sub(1, len)
   if preprocParts[seg] then
    out = out .. preprocParts[seg]
    blk = blk:sub(#seg + 1)
    break
   end
   len = len - 1
  end
  assert(len ~= 0)
 end
 return out
end

-- BDIVIDE r5 edition
-- Algorithm simplified for smaller implementation and potentially better compression
-- format:
-- 0-127 for constants
-- <128 + (length - 4)>, <position high>, <position low>
-- Position is where in the window it was found, minus 1.
-- windowSize must be the same between the encoder and decoder,
--  and is the amount of data preserved after cropping.
local function bdivide(blk)
 local out = ""

 local windowSize = 0x10000
 local windowData = ("\x00"):rep(windowSize)

 local function crop(data)
  windowData = (windowData .. data):sub(-windowSize)
 end

 while blk ~= "" do
  local bestData = blk:sub(1, 1)
  local bestRes = bestData
  for lm = 0, 127 do
   local al = lm + 4
   local pfx = blk:sub(1, al)
   if #pfx ~= al then
    break
   end
   local p = windowData:find(pfx, 1, true)
   if not p then
    break
   end
   local pm = p - 1
   local thirdByte = pm % 256
   -- anti ']'-corruption helper
   if thirdByte ~= 93 then
    bestData = string.char(128 + lm, math.floor(pm / 256), thirdByte)
    bestRes = pfx
   end
  end
  -- ok, encode!
  out = out .. bestData
  crop(bestRes)
  blk = blk:sub(#bestRes + 1)
 end
 return out
end

return function (data)
 data = preproc(data)
 io.stderr:write("---\n")
 data = bdivide(data)
 return data
end
