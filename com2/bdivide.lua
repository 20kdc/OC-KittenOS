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

io.write("\x00") -- initiation character

local blk = io.read("*a")
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
  bestData = string.char(128 + lm, math.floor(pm / 256), pm % 256)
  bestRes = pfx
 end
 -- ok, encode!
 io.write(bestData)
 crop(bestRes)
 blk = blk:sub(#bestRes + 1)
end

