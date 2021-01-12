-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

local event = require("event")(neo)
local neoux = require("neoux")(event, neo)
local braille = require("braille")
local bmp = require("bmp")
local file = neoux.fileDialog(false)

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

local function decodeRGB(rgb, igp, col)
 local r, g, b = math.floor(rgb / 65536) % 256, math.floor(rgb / 256) % 256, rgb % 256
 -- the new KittenOS NEO logo is 'sensitive' to dithering, so disable it
 if not col then
  -- ...and the palette is a bit odd, oh well
  if math.max(r, g, b) < 0xC0 then
   return 0, 0, 0
  end
  return 255, 255, 255
 end
 return r, g, b
end

local bW, bH = math.ceil(bitmap.width / 2), math.ceil(bitmap.height / 4)

local fp = neoux.tcwindow(bW, bH, {
 braille.new(1, 1, bW, bH, {
  selectable = true,
  get = function (window, x, y, bg, fg, selected, colour)
   if x > bitmap.width then return 0, 0, 0 end
   if y > bitmap.height then return 0, 0, 0 end
   if bitmap.ignoresPalette then
    return decodeRGB(bitmap.getPixel(x - 1, y - 1, 0), true, colour)
   end
   return decodeRGB(bitmap.getPalette(bitmap.getPixel(x - 1, y - 1, 0)), false, colour)
  end
 }, 1)
}, function (w)
 w.close()
 running = false
end, 0xFFFFFF, 0)

neoux.create(bW, bH, nil, function (w, t, r, ...)
 if t == "focus" then
  if r and not bitmap.ignoresPalette then
   local pal = {}
   for i = 0, math.min(15, bitmap.paletteCol - 1) do
    pal[i + 1] = bitmap.getPalette(i)
   end
   w.recommendPalette(pal)
  end
 end
 return fp(w, t, r, ...)
end)

while running do
 event.pull()
end
