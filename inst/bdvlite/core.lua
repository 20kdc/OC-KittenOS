-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- BDIVIDE r5 edition
-- Algorithm simplified for smaller implementation and potentially better compression
-- format:
-- 0-127 for constants
-- <128 + (length - 4)>, <position high>, <position low>
-- Position is where in the window it was found, minus 1.
-- windowSize must be the same between the encoder and decoder,
--  and is the amount of data preserved after cropping.

local bdivCore = {}

function bdivCore.bdivide(blk, p)
 local out = ""

 local windowSize = 0x10000
 local windowData = ("\x00"):rep(windowSize)

 while blk ~= "" do
  p(blk)
  local bestData = blk:sub(1, 1)
  assert(blk:byte() < 128, "BDIVIDE does not handle 8-bit data")
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
   bestData = string.char(128 + lm, math.floor(pm / 256), thirdByte)
   bestRes = pfx
  end
  -- ok, encode!
  out = out .. bestData
  -- crop window
  windowData = (windowData .. bestRes):sub(-windowSize)
  blk = blk:sub(#bestRes + 1)
 end
 return out
end

-- Adds padding if required
function bdivCore.bdividePad(data)
 local i = 1
 -- Basically, if it ends on a literal,
 --  then the literal won't get read without two padding bytes.
 -- Otherwise (including if no data) it's fine.
 local needsPadding = false
 while i <= #data do
  if data:byte(i) > 127 then
   i = i + 3
   needsPadding = false
  else
   i = i + 1
   needsPadding = true
  end
 end
 if needsPadding then
  return data .. "\x00\x00"
 end
 return data
end

return bdivCore
