-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-nbox2018.lua : NODEBOX 2018
-- Authors: 20kdc

-- program start

local holos = neo.requestAccess("c.hologram")
local icecap = neo.requireAccess("x.neo.pub.base", "filedialogs")
local window = neo.requireAccess("x.neo.pub.window", "window")(40, 13)

local xyz = false
local state = false
local redstone = false
local button = false
local fileLabel = "NB2018"
local fileTooltip = nil

local cx, cy, cz = 1, 1, 1
local cursorBlink = false

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

local selectedBox

local workingOnBox = nil

local programState = "none"
-- ["state"] = {lines, key, clipboard}
local programStates = {
 ["none"] = {
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
 if p == 1 then
  -- plane 1 uses inverted Y
  y = 17 - y
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

local function render(line)
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
  if line < 7 then
   window.span(1, line, "|" .. textA .. "|" .. textB .. "|     ", 0, 0xFFFFFF)
  else
   if line == 7 then
    window.span(1, line, "|" .. textA .. "|" .. textB .. "|F6/F7", 0, 0xFFFFFF)
   elseif line == 8 then
    local rs = "R0"
    local bm = "B0"
    if redstone then
     rs = "R1"
    end
    if button then
     bm = "B1"
    end
    window.span(1, line, "|" .. textA .. "|" .. textB .. "|" .. rs .. " " .. bm, 0, 0xFFFFFF)
   end
  end
  for i = 1, 5 do
   local boxId = string.char(i + ((line - 1) * 5) + 64)
   if boxes[state][boxId] then
    if selectedBox == boxId then
     window.span(35 + i, line, boxId, 0xFFFFFF, 0)
    else
     window.span(35 + i, line, boxId, 0, 0xFFFFFF)
    end
   end
  end
 elseif line == 9 then
  local sts = "ON "
  if not state then
   sts = "OFF"
  end
  local actA = "---"
  local actB = "---"
  if not xyz then
   actA = "ACT"
  else
   actB = "ACT"
  end
  window.span(1, line, "+XY Ortho-" .. actA .. "----+XZ Ortho-" .. actB .. "--+-+S:" .. sts, 0, 0xFFFFFF)
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
  local text = {
   "Nothing selected. " .. miText,
   "Enter starts a new box, while   |F3 Load",
   " a box can be selected by its   |F4 Save",
   " key. To print, press F8.       |F5 XYXZ"
  }
  if selectedBox then
   text = {
    "'" .. selectedBox .. "' " .. boxes[state][selectedBox].tex,
    require("fmttext").pad("Tint #" .. string.format("%08x", workingOnBox.rgb), 32, false, true) .. "|F3 Load",
    "Enter deselects, Delete deletes,|F4 Save",
    " and the A-Z keys still select. |F5 XYXZ"
   }
  elseif workingOnBox then
   if not workingOnBox.maxX then
    text = {
     "Creating: " .. miText .. "/" .. mxText,
     "Arrows to move around. Use F5 to|F3 Load",
     " swap from XY to XZ or back.    |F4 Save",
     "Enter confirms, Delete cancels. |F5 XYXZ"
    }
   else
    local tex = require("fmttext").pad(unicode.safeTextFormat(workingOnBox.tex), 30, false, true)
    text = {
     "Box Texture Entry: " .. miText .. "/" .. mxText,
     " Press Enter to confirm texture,|F3 Load",
     " or paste out-of-game clipboard.|F4 Save",
     "[" .. tex .. "]|F5 XYXZ"
    }
   end
  end
  text[1] = require("fmttext").pad(text[1], 32, true, true) .. "|F1 New "
  window.span(1, line, text[line - 9] or "", 0, 0xFFFFFF)
 end
end
local function refresh()
 for i = 1, 14 do
  render(i)
 end
end

local function reset()
 boxes = {[true] = {}, [false] = {}}
 state = false
 selectedBox = nil
 xyz = false
 cx, cy, cz = 1, 1, 1
 workingOnBox = nil
end

local function loadObj(obj)
 fileLabel = obj.label
 fileTooltip = obj.tooltip
 redstone = obj.emitRedstone
 button = obj.buttonMode
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
   tex = v.texture,
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
   v.minX,
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
  refresh()
 end
 if event == "x.neo.pub.window" then
  if b == "line" then
   render(c)
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
     -- Load
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
     -- Save
     local handle = icecap.showFileDialogAsync(true)
     if waitForDialog(handle) then return end
     if lastFile then
      lastFile.write(require("serial").serialize(makeObj()):sub(8))
      lastFile.close()
     end
    elseif d == 63 then
     xyz = not xyz
     refresh()
    elseif d == 64 then
     redstone = not redstone
     refresh()
    elseif d == 65 then
     button = not button
     refresh()
    elseif d == 66 then
     -- Print
     neo.executeAsync("app-nprt2018", makeObj())
    elseif c == 9 then
     state = not state
     selectedBox = nil
     -- we can safely switch between states
     --  while working on a box
     refresh()
    elseif d == 203 then
     cx = math.max(1, cx - 1)
     refresh()
    elseif d == 200 then
     if not xyz then
      cy = math.min(16, cy + 1)
     else
      cz = math.max(1, cz - 1)
     end
     refresh()
    elseif d == 205 then
     cx = math.min(16, cx + 1)
     refresh()
    elseif d == 208 then
     if not xyz then
      cy = math.max(1, cy - 1)
     else
      cz = math.min(16, cz + 1)
     end
     refresh()
    elseif c == 13 then
     if not selectedBox then
      if not workingOnBox then
       workingOnBox = {
        minX = cx,
        minY = cy,
        minZ = cz,
        tex = "diamond_block",
        rgb = 0xFFFFFF
       }
      elseif not workingOnBox.maxX then
       workingOnBox.maxX = cx
       workingOnBox.maxY = cy
       workingOnBox.maxZ = cz
      else
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
      end
     else
      selectedBox = nil
     end
     refresh()
    else
     if workingOnBox then
      if not workingOnBox.maxX then
       if c == 8 or c == 127 then
        workingOnBox = nil
       end
      else
       if c >= 32 then
        workingOnBox.tex = workingOnBox.tex .. unicode.char(c)
       elseif c == 8 or c == 127 then
        workingOnBox.tex = unicode.sub(workingOnBox.tex, 1, unicode.len(workingOnBox.tex) - 1)
       end
      end
      refresh()
     elseif c == 8 or c == 127 then
      if selectedBox then
       boxes[state][selectedBox] = nil
       selectedBox = nil
       refresh()
      end
     else
      local cc = unicode.char(c):upper()
      if boxes[state][cc] then
       selectedBox = cc
      end
      refresh()
     end
    end
   end
  end
  if b == "close" then
   return
  end
 end
end
