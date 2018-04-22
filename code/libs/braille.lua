-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- Braille Converter & NeoUX component
-- While the Neoux part isn't OS-independent,
--  the converter itself is. Enjoy.

-- Braille Neoux Component Callbacks :
--  selectable (boolean)
--  key(window, update, a, c, d, keyFlags)
--  touch(window, update, x, y, button)
--  drag(window, update, x, y, button)
--  drop(window, update, x, y, button)
--  scroll(window, update, x, y, button)
--  clipboard(window, update, contents)
--  get(window, x, y, bg, fg, selected) -> r,g,b (REQUIRED)
-- REMINDER:
-- 03
-- 14
-- 25
-- 67
local function dotDist(ra, ga, ba, rb, gb, bb)
 local dR, dG, dB = math.abs(ra - rb)^2, math.abs(ga - gb)^2, math.abs(ba - bb)^2
 return (dR * 0.2126) + (dG * 0.7152) + (dB * 0.0722)
end
local function ditherResult(pos, pos2, luma)
 local res = false
 if luma >= 217 then
  res = true
 elseif luma >= 158 then
  res = not pos2
 elseif luma >= 96 then
  res = pos
 elseif luma >= 32 then
  res = pos2
 end
 return res
end
local function dotGet(p, ra, ga, ba, rb, gb, bb, rc, gc, bc, pos, pos2, col)
 if not col then
  -- Use our own magic
  local luma = (ra * 0.299) + (ga * 0.587) + (ba * 0.114)
  return (ditherResult(pos, pos2, luma) and p) or 0
 end
 local distA = dotDist(ra, ga, ba, rb, gb, bb)
 local distB = dotDist(ra, ga, ba, rc, gc, bc)
 local distAB = dotDist(rb, gb, bb, rc, gc, bc)
 local distC = dotDist(ra, ga, ba, (rb + rc) / 2, (gb + gc) / 2, (bb + bc) / 2)
 if (distC / 2) < math.min(distA, distB) then
  return (ditherResult(pos, pos2, (distA / math.max(distA, distB, 0.1)) * 255) and p) or 0
 end
 return ((distB < distA) and p) or 0
end
local function cTransform(core)
 return function (window, update, x, y, xI, yI, blah)
  x = (x * 2) + math.ceil(xI - 0.5)
  y = (y * 4) + math.ceil((yI - 0.25) * 4)
  core(window, update, x, y, blah)
 end
end
local function colourize(mark, ...)
 local t = {...}
 local bCR = 0
 local bCG = 0
 local bCB = 0
 if not mark then
  local nLuma = -1
  for i = 1, #t do
   local luma = (t[i][1] * 0.299) + (t[i][2] * 0.587) + (t[i][3] * 0.114)
   if luma > nLuma then
    bCR, bCG, bCB = table.unpack(t[i])
    nLuma = luma
   end
  end
  return bCR, bCG, bCB
 else
  local bCTS = math.huge
  for i = 1, #t do
   local ts = -dotDist(mark[1], mark[2], mark[3], table.unpack(t[i]))
   if ts < bCTS then
    bCR = t[i][1]
    bCG = t[i][2]
    bCB = t[i][3]
    bCTS = ts
   end
  end
 end
 return bCR, bCG, bCB
end
local function packRGB(r, g, b)
 return (r * 65536) + (g * 256) + b
end
-- span is a NeoUX-like span function (x, y, str, bg, fg)
-- x, y are character-cell start coordinates for this.
-- w is character-cell count.
-- colour is nil to disable colour,
-- otherwise the colour-change threshold (best 0)
-- get is a function r,g,b = get(xo, yo)
-- NOTE: xo/yo are 0-based!
local function calcLine(x, y, w, span, get, colour)
 local str = ""
 -- *g* : actual colour com.
 -- *g  : RGB mirror of colour
 local bgR, bgG, bgB = 0, 0, 0
 local fgR, fgG, fgB = 255, 255, 255
 local bg = 0
 local fg = 0xFFFFFF
 local ca = 0
 for p = 1, w do
  local i = 0x2800
  local xb = (p - 1) * 2
  local dot0R, dot0G, dot0B = get(xb + 0, 0)
  local dot1R, dot1G, dot1B = get(xb + 0, 1)
  local dot2R, dot2G, dot2B = get(xb + 0, 2)
  local dot3R, dot3G, dot3B = get(xb + 1, 0)
  local dot4R, dot4G, dot4B = get(xb + 1, 1)
  local dot5R, dot5G, dot5B = get(xb + 1, 2)
  local dot6R, dot6G, dot6B = get(xb + 0, 3)
  local dot7R, dot7G, dot7B = get(xb + 1, 3)
  if colour then
   local obgR, obgG, obgB = colourize(nil,
    {dot0R, dot0G, dot0B},
    {dot1R, dot1G, dot1B},
    {dot2R, dot2G, dot2B},
    {dot3R, dot3G, dot3B},
    {dot4R, dot4G, dot4B},
    {dot5R, dot5G, dot5B},
    {dot6R, dot6G, dot6B},
    {dot7R, dot7G, dot7B}
   )
   local ofgR, ofgG, ofgB = colourize({obgR, obgG, obgB},
    {dot0R, dot0G, dot0B},
    {dot1R, dot1G, dot1B},
    {dot2R, dot2G, dot2B},
    {dot3R, dot3G, dot3B},
    {dot4R, dot4G, dot4B},
    {dot5R, dot5G, dot5B},
    {dot6R, dot6G, dot6B},
    {dot7R, dot7G, dot7B}
   )
   if ((dotDist(obgR, obgG, obgB, bgR, bgG, bgB) > colour) and
      (dotDist(obgR, obgG, obgB, fgR, fgG, fgB) > colour)) or
      ((dotDist(ofgR, ofgG, ofgB, bgR, bgG, bgB) > colour) and
      (dotDist(ofgR, ofgG, ofgB, fgR, fgG, fgB) > colour)) then
    if ca ~= 0 then
     span(x, y, str, bg, fg)
     str = ""
    end
    x = x + ca
    ca = 0
    bg = packRGB(obgR, obgG, obgB)
    fg = packRGB(ofgR, ofgG, ofgB)
    bgR, bgG, bgB = obgR, obgG, obgB
    fgR, fgG, fgB = ofgR, ofgG, ofgB
   end
  end
  i = i + dotGet(1, dot0R, dot0G, dot0B, bgR, bgG, bgB, fgR, fgG, fgB, true, false, colour)
  i = i + dotGet(2, dot1R, dot1G, dot1B, bgR, bgG, bgB, fgR, fgG, fgB, false, false, colour)
  i = i + dotGet(4, dot2R, dot2G, dot2B, bgR, bgG, bgB, fgR, fgG, fgB, true, false, colour)
  i = i + dotGet(8, dot3R, dot3G, dot3B, bgR, bgG, bgB, fgR, fgG, fgB, false, false, colour)
  i = i + dotGet(16, dot4R, dot4G, dot4B, bgR, bgG, bgB, fgR, fgG, fgB, true, true, colour)
  i = i + dotGet(32, dot5R, dot5G, dot5B, bgR, bgG, bgB, fgR, fgG, fgB, false, false, colour)
  i = i + dotGet(64, dot6R, dot6G, dot6B, bgR, bgG, bgB, fgR, fgG, fgB, false, false, colour)
  i = i + dotGet(128, dot7R, dot7G, dot7B, bgR, bgG, bgB, fgR, fgG, fgB, true, true, colour)
  str = str .. unicode.char(i)
  ca = ca + 1
 end
 if str ~= "" then
  span(x, y, str, bg, fg)
 end
end

heldRef = {
 calcLine = calcLine,
 new = function (x, y, w, h, cbs, colour)
  local control
  control = {
   x = x,
   y = y,
   w = w,
   h = h,
   selectable = cbs.selectable,
   key = cbs.key,
   clipboard = cbs.clipboard,
   touch = cbs.touch and cTransform(cbs.touch),
   drag = cbs.drag and cTransform(cbs.drag),
   drop = cbs.drop and cTransform(cbs.drop),
   scroll = cbs.scroll and cTransform(cbs.scroll),
   line = function (window, x, y, iy, bg, fg, selected)
    local colour = colour
    local depth = window.getDepth()
    if depth <= 1 then
     colour = nil
    end
    calcLine(x, y, control.w, window.span, function (xb, yb)
     return cbs.get(window, xb + 1, yb + (iy * 4) - 3, bg, fg, selected, colour)
    end, colour)
   end,
  }
  return control
 end,
}
return heldRef
