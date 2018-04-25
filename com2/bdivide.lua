-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- BDIVIDE
-- format:
-- 0-127 for constants
-- <block + 128>, <(len - 3) * 2, + lowest bit is upper bit of position>, <position - 1>

io.write("\x00") -- initiation character

local blockCache = {}
local window = 0
local blockUse = 128
for i = 128, 128 + blockUse - 1 do
 blockCache[i] = ("\x00"):rep(512)
end

local function runBlock(blk)
 -- firstly, get current block index
 local blockIndex = window + 128
 window = (window + 1) % blockUse
 blockCache[blockIndex] = ""
 -- ok, now work on the problem
 local i = 1
 while i <= #blk do
  local bestData = blk:sub(i, i)
  local bestRes = bestData
  local bestScore = 1
  for bid = 128, 128 + blockUse - 1 do
   for lm = 0, 127 do
    local al = lm + 3
    local pfx = blk:sub(i, i + al - 1)
    if #pfx ~= al then
     break
    end
    local p = blockCache[bid]:find(pfx, 1, true)
    if not p then
     break
    end
    local score = al / 3
    if score > bestScore then
     bestData = string.char(bid) .. string.char((lm * 2) + math.floor((p - 1) / 256)) .. string.char((p - 1) % 256)
     bestRes = pfx
     bestScore = score
    end
   end
  end
  -- ok, encode!
  io.write(bestData)
  blockCache[blockIndex] = blockCache[blockIndex] .. bestRes
  i = i + #bestRes
 end
end

while 1 do
 local blkd = io.read(512)
 runBlock(blkd)
 if #blkd < 512 then
  return
 end
end
