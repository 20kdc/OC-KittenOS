-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

local event = require("event")(neo)
local neoux = require("neoux")(event, neo)
local braille = require("braille")
local bmp = require("bmp")
local icecap = neo.requireAccess("x.neo.pub.base", "loadimg")
local file = icecap.open("/logo.bmp", false)

local header = file.read(bmp.headerMinSzBMP)
local palette = ""

local lcBase = bmp.headerMinSzBMP
local palBase = bmp.headerMinSzBMP
local lcWidth = 1

local lc = {}
local lcdq = {}
local queueSize = 4
if os.totalMemory() > (256 * 1024) then
 queueSize = 40
end
for i = 1, queueSize do
 lcdq[i] = 0
end
local function getLine(y)
 if not lc[y] then
  local idx = y * lcWidth
  file.seek("set", lcBase + idx - 1)
  if lcdq[1] then
   lc[table.remove(lcdq, 1)] = nil
  end
  table.insert(lcdq, y)
  lc[y] = file.read(lcWidth)
 end
 return lc[y]
end

local bitmap = bmp.connect(function (i)
 if i >= palBase then
  local v = palette:byte(i + 1 - palBase)
  if v then
   return v
  end
 end
 if i >= lcBase then
  local ld = getLine(math.floor((i - lcBase) / lcWidth))
  i = ((i - lcBase) % lcWidth) + 1
  return ld:byte(i) or 0
 end
 return header:byte(i) or 0
end)

file.seek("set", bitmap.paletteAddress - 1)
palette = file.read(bitmap.paletteCol * 4)
palBase = bitmap.paletteAddress
lcBase = bitmap.dataAddress
lcWidth = bitmap.dsSpan

local running = true

local function decodeRGB(rgb, igp)
 if igp and bitmap.bpp > 24 then
  rgb = math.floor(rgb / 256)
 end
 return math.floor(rgb / 65536) % 256, math.floor(rgb / 256) % 256, rgb % 256
end

local bW, bH = math.ceil(bitmap.width / 2), math.ceil(bitmap.height / 4)
neoux.create(bW, bH, nil, neoux.tcwindow(bW, bH, {
 braille.new(1, 1, bW, bH, {
  selectable = true,
  get = function (window, x, y, bg, fg, selected, colour)
   if bitmap.ignoresPalette then
    return decodeRGB(bitmap.getPixel(x - 1, y - 1, 0), true)
   end
   return decodeRGB(bitmap.getPalette(bitmap.getPixel(x - 1, y - 1, 0)), false)
  end
 }, 1)
}, function (w)
 w.close()
 running = false
end, 0xFFFFFF, 0))

while running do
 event.pull()
end
