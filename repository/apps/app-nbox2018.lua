-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- app-nbox2018.lua : NODEBOX 2018
-- Authors: 20kdc

-- Current layout
--  12345678901234567890123456789012345678901234567890
-- 1                |                |                
-- 2                |                | 3d 32x32 panel 
-- 3                |                |                
-- 4                |                |                
-- 5                |                |                
-- 6                |                |                
-- 7                |                |                
-- 8                |                |                
-- 9-XY Ortho-ACTIV-+-XZ Ortho-ACTIV-+-ST:OFF-+-FILE:-
--10This was the story of someone cal|ABCDEFGH|F1 New 
--11led Stanley. Stanley got very cro|IJKLMNOP|F3 Load
--12ss because someone else used his |QRSTUVWX|F4 Save
--13name for a game. Stanley's silly.|YZ[\]^_`|TAB ST.

-- F-Key uses:
-- F1: New [Global]
-- F3: Load [Global]
-- F4: Save [Global]
-- F5: RotL [Global]
-- F6: RotR [Global]
-- F7: FileStats [None ?Selected]
-- F8: Print [Global]
-- F9: Texture [None +Selected]
-- F10: Tint [None +Selected]
-- F11: 
-- F12: 

-- program start

local icecap = neo.requireAccess("x.neo.pub.base", "filedialogs")
local window = neo.requireAccess("x.neo.pub.window", "window")(50, 13)
local fmttext = require("fmttext")
local braille = require("braille")

-- [true] = {["A"] = {
--  tex = "",
--  -- numbers are 0 to 15:
--  minX = 0, minY = 0, minZ = 0,
--  maxX = 16, maxY = 16, maxZ = 16,
--  rgb = 0xFFFFFF
-- }}
local boxes = {
 [true] = {},
 [false] = {}
}
local redstone = false
local button = false
local fileLabel = "NB2018"
local fileTooltip = ""

-- program

local xyz = false
local state = false

local rotation = 0

local cx, cy, cz = 1, 1, 1
local cursorBlink = false

local selectedBox

local tintDigi = 0
local fstatSwap = false

-- minX/minY/minZ are +1 from the usual values
-- tex/rgb are defaults until edited
-- maxX/maxY/maxZ only present after 2nd point placed
-- final corrections performed on submission to boxes table
local workingOnBox = nil

local function runField(tx, l, r)
 return l .. fmttext.pad(unicode.safeTextFormat(tx), 31, false, true, true) .. r
end
local function actField(tx, ka, kc)
 if kc == 211 or ka == 8 then
  tx = unicode.sub(tx, 1, unicode.len(tx) - 1)
 elseif ka >= 32 then
  tx = tx .. unicode.char(ka)
 end
 return tx
end

local programState = "none"
-- ["state"] = {lines, keydown, clipboard}
local programStates = {
 none = {
  function (miText, mxText)
   -- This state handles both box selected & box not selected,
   --  because the box can get deselected out of program control
   if selectedBox then
    local targetBox = boxes[state][selectedBox]
    return {
     "'" .. selectedBox .. "' " .. targetBox.tex,
     "Tint #" .. string.format("%06x", targetBox.rgb),
     "Enter deselects, Delete deletes.",
     "F9 and F10 change texture/tint."
    }
   end
   local str = string.format("%02i, %02i, %02i", cx, cy, cz)
   return {
    "No selection. " .. str,
    "Enter starts a new box, while the",
    " box's letter selects. Rotate w/ ",
    " F5/F6, F7 for stats, F8 prints. "
   }
  end,
  function (ka, kc)
   if ka == 13 then
    if selectedBox then
     selectedBox = nil
    else
     -- Beginning box!
     workingOnBox = {
      minX = cx,
      minY = cy,
      minZ = cz,
      tex = "stone",
      rgb = 0xFFFFFF
     }
     programState = "point2"
    end
   elseif kc == 65 then
    -- FStats
    fstatSwap = false
    programState = "fstats"
   elseif kc == 67 then
    -- Texture
    if selectedBox then programState = "texture" end
   elseif kc == 68 then
    -- Tint
    if selectedBox then tintDigi = 1 programState = "tint" end
   elseif ka == 127 or ka == 8 then
    -- Delete
    if selectedBox then
     boxes[state][selectedBox] = nil
     selectedBox = nil
    end
   else
    local cc = unicode.char(ka):upper()
    if boxes[state][cc] then
     selectedBox = cc
    end
   end
  end,
  function (text)
  end
 },
 point2 = {
  function (miText, mxText)
   return {
    "Placing Point 2:" .. miText .. "/" .. mxText,
    "Enter confirms.",
    "Arrows move 2nd point.",
    "Delete/Backspace cancels."
   }
  end,
  function (ka, kc)
   if ka == 127 or ka == 8 then
    workingOnBox = nil
    programState = "none"
   elseif ka == 13 then
    workingOnBox.maxX = cx
    workingOnBox.maxY = cy
    workingOnBox.maxZ = cz
    local ch = 65
    while boxes[state][string.char(ch)] do
     ch = ch + 1
    end
    local ax, ay, az = workingOnBox.minX, workingOnBox.minY, workingOnBox.minZ
    local bx, by, bz = workingOnBox.maxX, workingOnBox.maxY, workingOnBox.maxZ
    workingOnBox.minX = math.min(ax, bx) - 1
    workingOnBox.minY = math.min(ay, by) - 1
    workingOnBox.minZ = math.min(az, bz) - 1
    workingOnBox.maxX = math.max(ax, bx)
    workingOnBox.maxY = math.max(ay, by)
    workingOnBox.maxZ = math.max(az, bz)
    selectedBox = string.char(ch)
    boxes[state][selectedBox] = workingOnBox
    workingOnBox = nil
    programState = "texture"
   end
  end,
  function (text)
  end
 },
 texture = {
  function (miText, mxText)
   local targetBox = boxes[state][selectedBox]
   return {
    "Texturing. Type or paste texture ",
    " ID. Pasting replaces contents.  ",
    runField(targetBox.tex, "[", "]"),
    "Enter confirms. \"\" is invisible."
   }
  end,
  function (ka, kc)
   local targetBox = boxes[state][selectedBox]
   if ka == 13 then
    programState = "none"
   else
    targetBox.tex = actField(targetBox.tex, ka, kc)
   end
  end,
  function (text)
   boxes[state][selectedBox].tex = text
  end
 },
 tint = {
  function (miText, mxText)
   local targetBox = boxes[state][selectedBox]
   local a = "#"
   local b = " "
   local rgb = targetBox.rgb
   local div = 0x100000
   for i = 1, 6 do
    a = a .. string.format("%01x", math.floor(rgb / div) % 16)
    if tintDigi == i then
     b = b .. "^"
    else
     b = b .. " "
    end
    div = math.floor(div / 16)
   end
   return {
    "Tinting. Enter 6 hex digits,     ",
    " which are 0 to 9, and A to F.   ",
    a,
    b
   }
  end,
  function (ka, kc)
   local targetBox = boxes[state][selectedBox]
   local shifts = {
    20,
    16,
    12,
    8,
    4,
    0
   }
   local hexChars = {
    [48] = 0, [65] = 10, [97] = 10,
    [49] = 1, [66] = 11, [98] = 11,
    [50] = 2, [67] = 12, [99] = 12,
    [51] = 3, [68] = 13, [100] = 13,
    [52] = 4, [69] = 14, [101] = 14,
    [53] = 5, [70] = 15, [102] = 15,
    [54] = 6,
    [55] = 7,
    [56] = 8,
    [57] = 9,
   }
   if hexChars[ka] then
    local shift = math.floor(2^shifts[tintDigi])
    local low = targetBox.rgb % shift
    local high = math.floor(targetBox.rgb / (shift * 16)) * (shift * 16)
    targetBox.rgb = low + high + (hexChars[ka] * shift)
    tintDigi = 1 + (tintDigi or 1)
    if tintDigi == 7 then
     tintDigi = nil
     programState = "none"
    end
   end
  end,
  function (text)
  end
 },
 fstats = {
  function (miText, mxText)
   local aa, ab = "[", "]"
   local ba, bb = " ", " "
   if fstatSwap then
    aa, ab = " ", " "
    ba, bb = "[", "]"
   end
   return {
    runField(fileLabel, aa, ab),
    runField(fileTooltip, ba, bb),
    "Redstone (F9): " .. ((redstone and "Y") or "N") .. " Button (F10): " .. ((button and "Y") or "N"),
    "Enter to confirm."
   }
  end,
  function (ka, kc)
   if kc == 67 then
    redstone = not redstone
   elseif kc == 68 then
    button = not button
   elseif ka == 13 then
    fstatSwap = not fstatSwap
    if not fstatSwap then
     programState = "none"
    end
   elseif fstatSwap then
    fileTooltip = actField(fileTooltip, ka, kc)
   else
    fileLabel = actField(fileLabel, ka, kc)
   end
  end,
  function (text)
  end
 }
}

local function onRect(x, y, minX, minY, maxX, maxY)
 -- Lines
 if x == minX then
  return y >= minY and y <= maxY
 elseif x == maxX then
  return y >= minY and y <= maxY
 elseif y == minY then
  return x >= minX and x <= maxX
 elseif y == maxY then
  return x >= minX and x <= maxX
 end
 return false
end

local function getPixel(x, y, p)
 -- the reason is obvious for plane1, but less so for plane2
 -- just consider that without this, the top of the screen would be facing you, but X would remain your left/right
 y = 17 - y
 if p == 1 then
  if x == cx and y == cy then
   return cursorBlink
  end
 else
  if x == cx and y == cz then
   return cursorBlink
  end
 end
 if workingOnBox then
  local minX, minY, minZ = workingOnBox.minX, workingOnBox.minY, workingOnBox.minZ
  local maxX, maxY, maxZ = cx, cy, cz
  if workingOnBox.maxX then
   maxX, maxY, maxZ = workingOnBox.maxX, workingOnBox.maxY, workingOnBox.maxZ
  end
  minX, maxX = math.min(minX, maxX), math.max(minX, maxX)
  minY, maxY = math.min(minY, maxY), math.max(minY, maxY)
  minZ, maxZ = math.min(minZ, maxZ), math.max(minZ, maxZ)
  if p == 1 then
   if onRect(x, y, minX, minY, maxX, maxY) then
    return cursorBlink
   end
  else
   if onRect(x, y, minX, minZ, maxX, maxZ) then
    return cursorBlink
   end
  end
 end
 for k, v in pairs(boxes[state]) do
  if (not selectedBox) or (k == selectedBox) then
   if p == 1 then
    if onRect(x, y, v.minX + 1, v.minY + 1, v.maxX, v.maxY) then
     return true
    end
   else
    if onRect(x, y, v.minX + 1, v.minZ + 1, v.maxX, v.maxZ) then
     return true
    end
   end
  end
 end
 return false
end

local function get3DPixel(xo, yo)
 local function inLine(xa, ya, xb, yb)
  xa, ya, xb, yb = math.floor(xa), math.floor(ya), math.floor(xb), math.floor(yb)
  local xd = math.abs(xa - xb)
  local yd = math.abs(ya - yb)
  if xd > yd then
   local point = math.abs(xo - xa) / xd
   local cast = math.floor((point * (0.99 + yb - ya)) + ya)
   if cast ~= yo then
    return false
   end
  elseif yd ~= 0 then
   local point = math.abs(yo - ya) / yd
   local cast = math.floor((point * (0.99 + xb - xa)) + xa)
   if cast ~= xo then
    return false
   end
  end
  -- clipping
  return
   xo >= math.min(xa, xb) and
   xo <= math.max(xa, xb) and
   yo >= math.min(ya, yb) and
   yo <= math.max(ya, yb)
 end
 local cacheX = {}
 local cacheY = {}
 local function rotate(x, y)
  if rotation == 0 then return x, y end
  x = x - 16
  y = y - 16
  local a = -rotation * 3.14159 / 8
  local xBX, xBY = math.cos(a), math.sin(a)
  local yBX, yBY = -xBY, xBX
  local xo = (xBX * x) + (yBX * y)
  local yo = (xBY * x) + (yBY * y)
  return xo + 16, yo + 16
 end
 local function point3(ax, ay, az)
  ax, az = rotate(ax, az)
  local k = ax .. "_" .. ay .. "_" .. az
  if cacheX[k] then return cacheX[k], cacheY[k] end
  local ox = 16
  local oy = 15.5
  oy = oy - (ay / 2)
  ox = ox + (ax / 2)
  ox = ox - (az / 2)
  oy = oy + (ax / 4)
  oy = oy + (az / 4)
  cacheX[k] = ox
  cacheY[k] = oy
  return ox, oy
 end
 local function in3Line(ax, ay, az, bx, by, bz)
  local sc = 1.9
  ax, ay = point3(ax * sc, ay * sc, az * sc)
  bx, by = point3(bx * sc, by * sc, bz * sc)
  return inLine(ax, ay, bx, by)
 end
 local function inShape(ax, ay, az, bx, by, bz)
  return
   in3Line(ax, ay, az, bx, ay, az) or
   in3Line(ax, ay, az, ax, ay, bz) or
   in3Line(bx, ay, az, bx, ay, bz) or
   in3Line(ax, ay, bz, bx, ay, bz) or

   in3Line(ax, ay, az, ax, by, az) or
   in3Line(ax, ay, bz, ax, by, bz) or
   in3Line(bx, ay, az, bx, by, az) or
   in3Line(bx, ay, bz, bx, by, bz) or

   in3Line(ax, by, az, bx, by, az) or
   in3Line(ax, by, az, ax, by, bz) or
   in3Line(bx, by, az, bx, by, bz) or
   in3Line(ax, by, bz, bx, by, bz)
 end
 for k, v in pairs(boxes[state]) do
  if (not selectedBox) or (k == selectedBox) then
   if inShape(16 - v.minZ, v.minY, 16 - v.minX, 16 - v.maxZ, v.maxY, 16 - v.maxX) then
    return true
   end
  end
 end
 return false
end
local function render(line, doBraille)
 if line < 9 then
  local textA, textB = "", ""
  local bo = (line - 1) * 2
  for i = 1, 16 do
   for p = 1, 2 do
    local pxH, pxL = getPixel(i, bo + 1, p), getPixel(i, bo + 2, p)
    local tx
    if pxH then
     if pxL then
      tx = "█"
     else
      tx = "▀"
     end
    else
     if pxL then
      tx = "▄"
     else
      tx = " "
     end
    end
    if p == 1 then
     textA = textA .. tx
    else
     textB = textB .. tx
    end
   end
  end
  window.span(1, line, textA .. "|" .. textB .. "|", 0, 0xFFFFFF)
  if doBraille then
   braille.calcLine(35, line, 16, window.span, function (xo, yo)
    if get3DPixel(xo, yo + ((line - 1) * 4)) then
     return 255, 255, 255
    else
     return 0, 0, 0
    end 
   end, nil)
  end
 elseif line == 9 then
  local sts = "ON "
  if not state then
   sts = "OFF"
  end
  -- Bit odd, but makes sense in the end
  local actA = "-----"
  local actB = "-----"
  if not xyz then
   actA = "Space"
  else
   actB = "Space"
  end
  window.span(1, line, "-XY Ortho-" .. actA .. "-+-XZ Ortho-" .. actB .. "-+-ST:" .. sts .. "-+-FILE:-", 0, 0xFFFFFF)
 elseif line > 9 then
  local mix, miy, miz = cx, cy, cz
  local mxx, mxy, mxz = cx, cy, cz
  if workingOnBox then
   if workingOnBox.maxX then
    local ax, ay, az = workingOnBox.minX, workingOnBox.minY, workingOnBox.minZ
    local bx, by, bz = workingOnBox.maxX, workingOnBox.maxY, workingOnBox.maxZ
    mix = math.min(ax, bx)
    miy = math.min(ay, by)
    miz = math.min(az, bz)
    mxx = math.max(ax, bx)
    mxy = math.max(ay, by)
    mxz = math.max(az, bz)
   else
    local ax, ay, az = workingOnBox.minX, workingOnBox.minY, workingOnBox.minZ
    mix = math.min(ax, cx)
    miy = math.min(ay, cy)
    miz = math.min(az, cz)
    mxx = math.max(ax, cx)
    mxy = math.max(ay, cy)
    mxz = math.max(az, cz)
   end
  end
  local miText = mix .. "," .. miy .. "," .. miz
  local mxText = mxx .. "," .. mxy .. "," .. mxz
  local text = programStates[programState][1](miText, mxText)
  local menu = {
   "|        |F1 New ",
   "|        |F3 Load",
   "|        |F4 Save",
   "|        |TAB ST."
  }
  for i = 1, 4 do
   text[i] = fmttext.pad(text[i], 33, true, true) .. menu[i]
  end
  window.span(1, line, text[line - 9] or "", 0, 0xFFFFFF)
  for i = 1, 8 do
   local boxId = string.char(i + ((line - 10) * 8) + 64)
   if boxes[state][boxId] then
    if selectedBox == boxId then
     window.span(34 + i, line, boxId, 0xFFFFFF, 0)
    else
     window.span(34 + i, line, boxId, 0, 0xFFFFFF)
    end
   end
  end
 end
end
local function refresh(n3d)
 for i = 1, 14 do
  render(i, not n3d)
 end
end

local function reset()
 boxes = {[true] = {}, [false] = {}}
 state = false
 rotation = 0
 selectedBox = nil
 xyz = false
 cx, cy, cz = 1, 1, 1
 workingOnBox = nil
 programState = "none"
end

local function loadObj(obj)
 fileLabel = obj.label or ""
 fileTooltip = obj.tooltip or ""
 redstone = obj.emitRedstone or false
 button = obj.buttonMode or false
 local advances = {
  [false] = 65,
  [true] = 65
 }
 for k, v in ipairs(obj.shapes) do
  local vs = v.state or false
  boxes[vs][string.char(advances[vs])] = {
   minX = v[1],
   minY = v[2],
   minZ = v[3],
   maxX = v[4],
   maxY = v[5],
   maxZ = v[6],
   tex = v.texture or "",
   rgb = v.tint or 0xFFFFFF
  }
  advances[vs] = advances[vs] + 1
 end
end
local function exportBoxes(shapes, st)
 local order = {}
 for k, v in pairs(boxes[st]) do
  table.insert(order, k)
 end
 table.sort(order)
 for _, kv in ipairs(order) do
  local v = boxes[st][kv]
  local tint = v.rgb
  if tint == 0xFFFFFF then
   tint = nil
  end
  table.insert(shapes, {
   v.minX,
   v.minY,
   v.minZ,
   v.maxX,
   v.maxY,
   v.maxZ,
   texture = v.tex,
   state = st,
   tint = tint
  })
 end
end
local function makeObj()
 local tbl = {
  label = fileLabel,
  tooltip = fileTooltip,
  emitRedstone = redstone,
  buttonMode = button,
  shapes = {
  }
 }
 exportBoxes(tbl.shapes, false)
 exportBoxes(tbl.shapes, true)
 return tbl
end

local lastFile = nil
local function waitForDialog(handle)
 lastFile = nil
 while true do
  local event, b, c, d = coroutine.yield()
  if event == "k.timer" then
   neo.scheduleTimer(os.uptime() + 0.5)
  end
  if event == "x.neo.pub.window" then
   if b == "close" then
    return true
   end
  end
  if event == "x.neo.pub.base" then
   if b == "filedialog" then
    if c == handle then
     lastFile = d
     return
    end
   end
  end
 end
end

neo.scheduleTimer(os.uptime())
while true do
 local event, a, b, c, d, e = coroutine.yield()
 if event == "k.timer" then
  neo.scheduleTimer(os.uptime() + 0.5)
  cursorBlink = not cursorBlink
  refresh(true)
 end
 if event == "x.neo.pub.window" then
  if b == "line" then
   render(c, true)
  end
  if b == "clipboard" then
   if workingOnBox and workingOnBox.maxX then
    workingOnBox.tex = tostring(c)
    b = "key"
    c = 13
    d = 0
    e = true
   end
  end
  if b == "key" then
   if e then
    --neo.emergency("key " .. tostring(c) .. " " .. tostring(d))
    if d == 59 then
     reset()
     refresh()
    elseif d == 61 then
     -- F3 Load
     local handle = icecap.showFileDialogAsync(false)
     if waitForDialog(handle) then return end
     if lastFile then
      reset()
      local obj = require("serial").deserialize("return " .. lastFile.read("*a"))
      loadObj(obj)
      refresh()
      lastFile.close()
     end
    elseif d == 62 then
     -- F4 Save
     local handle = icecap.showFileDialogAsync(true)
     if waitForDialog(handle) then return end
     if lastFile then
      lastFile.write(require("serial").serialize(makeObj()):sub(8))
      lastFile.close()
     end
    elseif d == 63 then
     rotation = rotation + 1
     refresh()
    elseif d == 64 then
     rotation = rotation - 1
     refresh()
    elseif d == 66 then
     -- F8 Print
     neo.executeAsync("app-nprt2018", makeObj())
    elseif c == 9 then
     state = not state
     selectedBox = nil
     -- we can safely switch between states
     --  while working on a box
     refresh()
    elseif d == 203 then
     cx = math.max(1, cx - 1)
     refresh(true)
    elseif d == 200 then
     if not xyz then
      cy = math.min(16, cy + 1)
     else
      cz = math.min(16, cz + 1)
     end
     refresh(true)
    elseif d == 205 then
     cx = math.min(16, cx + 1)
     refresh(true)
    elseif d == 208 then
     if not xyz then
      cy = math.max(1, cy - 1)
     else
      cz = math.max(1, cz - 1)
     end
     refresh(true)
    else
     if c == 32 then
      xyz = not xyz
     end
     local oldSB = selectedBox
     programStates[programState][2](c, d)
     refresh((c ~= 13) and (oldSB == selectedBox))
    end
   end
  end
  if b == "close" then
   return
  end
 end
end
