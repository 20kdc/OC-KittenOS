-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-nbox2018.lua : NODEBOX 2018
-- Authors: 20kdc

-- program start

local window = neo.requireAccess("x.neo.pub.window", "window")(40, 13)

-- ["A"] = {
--  tex = "",
--  -- numbers are 0 to 15:
--  minX = 0, minY = 0, minZ = 0,
--  maxX = 0, maxY = 0, maxZ = 0
-- }
local boxes = {
 ["A"] = {},
 ["B"] = {},
 ["C"] = {},
 ["D"] = {},
 ["E"] = {},
 ["F"] = {},
 ["G"] = {},
 ["H"] = {},
 ["I"] = {},
}

local selectedBox

local workingOnBox = false
local workingOnBoxSt2 = nil
local workingOnBoxSt3 = nil

local function cirno(line)
 if line < 9 then
  local textA, textB = "", ""
  for i = 1, 16 do
   -- ▄▀█ and space
   textA = textA .. "▄"
   textB = textB .. "▄"
  end
  window.span(1, line, "|" .. textA .. "|" .. textB .. "|     ", 0, 0xFFFFFF)
  for i = 1, 5 do
   local boxId = string.char(i + ((line - 1) * 5) + 64)
   if boxes[boxId] then
    if selectedBox == boxId then
     window.span(35 + i, line, boxId, 0xFFFFFF, 0)
    else
     window.span(35 + i, line, boxId, 0, 0xFFFFFF)
    end
   end
  end
 elseif line == 9 then
  window.span(1, line, "+XZ Ortho--------+XY Ortho-----+-+Boxes", 0, 0xFFFFFF)
 elseif line > 9 then
  local text = {
   "Nothing selected.               |F1 New ",
   "Enter starts a new box, while   |F3 Load",
   " the A-Z keys select a box that |F4 Save",
   " is already on the board.       |F5 XYXZ"
  }
  if selectedBox then
   text = {
    "Box " .. selectedBox .. " selected.                |F1 New ",
    "Enter deselects the box, while  |F3 Load",
    " Delete deletes the box, and the|F4 Save",
    " A-Z keys select another box.   |F5 XYXZ"
   }
  elseif workingOnBox then
   if not workingOnBoxSt1 then
    text = {
     "Creating box: Placing Point A.  |F1 New ",
     "Arrows to move around. Use F5 to|F3 Load",
     " swap from XY to XZ or back.    |F4 Save",
     "Enter confirms, Delete cancels. |F5 XYXZ"
    }
   elseif not workingOnBoxSt2 then
    text = {
     "Creating box: Placing Point B.  |F1 New ",
     "Arrows to move around. Use F5 to|F3 Load",
     " swap from XY to XZ or back.    |F4 Save",
     "Enter confirms, Delete cancels. |F5 XYXZ"
    }
   else
    local tex = require("fmttext").pad(unicode.safeTextFormat(workingOnBoxSt2.tex), 30, false, true)
    text = {
     "Box Texture Entry: Type & press |F1 New ",
     " Enter to confirm, or use the   |F3 Load",
     " out-of-game clipboard.         |F4 Save",
     "[" .. tex .. "]|F5 XYXZ"
    }
   end
  end
  window.span(1, line, text[line - 9] or "", 0, 0xFFFFFF)
 end
end
local function refresh()
 for i = 1, 14 do
  cirno(i)
 end
end

while true do
 local event, a, b, c, d, e = coroutine.yield()
 if event == "x.neo.pub.window" then
  if b == "line" then
   cirno(c)
  end
  if b == "key" then
   if e then
    workingOnBox = not workingOnBox
    refresh()
   end
  end
  if b == "close" then
   return
  end
 end
end
