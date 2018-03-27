-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- 'neolithic': Text Editor
-- This was textedit (femto) from KittenOS 'ported' to NEO.
-- It also has fixes for bugs involving wide text, and runs faster due to the chars -> lines change.

local lines = {
 "Neolithic: Text Editor",
 "F3, F4, F1: Load, Save, New",
 "F5, F6, ^←: Copy, Paste, Delete Line",
 -- These two are meant to replace similar functionality in GNU Nano
 --  (which I consider the best console text editor out there - Neolithic is an *imitation* and a poor one at that),
 --  except fixing a UI flaw by instead making J responsible for resetting the append flag,
 --  so the user can more or less arbitrarily mash together lines
 "F7: Reset 'append' flag for Cut Lines",
 "F8: Cut Line(s)",
 "^<arrows>: Resize Win",
 "'^' is Control.",
 "Wide text & clipboard supported.",
 "Ｆｏｒ ｅｘａｍｐｌｅ， ｔｈｉｓ．",
}

-- If replicating Nano's clipboard :
-- Nano starts off in a "replace" mode,
--  and then after an action occurs switches to "append" until *any cursor action is performed*.
-- The way I have things setup is that you perform J then K(repeat) *instead*, which means you have to explicitly say "destroy current clipboard".

local event = require("event")(neo)
local clipsrc = neo.requireAccess("x.neo.pub.globals", "clipboard")

local cursorX = 1
local cursorY = math.ceil(#lines / 2)
local cFlash = true
local ctrlFlag = false
local dialogLock = false
local appendFlag = false
local sW, sH = 37, #lines + 2
local windows = neo.requestAccess("x.neo.pub.window")
local window = windows(sW, sH)
local flush

local function splitCur()
 local s = lines[cursorY]
 local st = unicode.sub(s, 1, cursorX - 1)
 local en = unicode.sub(s, cursorX)
 return st, en
end

local function clampCursorX()
 local s = lines[cursorY]
 if unicode.len(s) < (cursorX - 1) then
  cursorX = unicode.len(s) + 1
  return true
 end
 return false
end

local cbs = {}

local function fileDialog(writing, callback)
 local tag = neo.requestAccess("x.neo.pub.base").showFileDialogAsync(writing)
 local f
 function f(_, evt, tag2, res)
  if evt == "filedialog" then
   if tag == tag2 then
    local ok, e = pcall(callback, res)
    if not ok then
     e = unicode.safeTextFormat(tostring(e))
     local wnd = windows(unicode.len(e), 1, "ERROR")
     cbs[wnd.id] = {
      wnd.close,
      wnd.span,
      e
     }
    end
    event.ignore(f)
   end
  end
 end
 event.listen("x.neo.pub.base", f)
end

-- Save/Load
local function startSave()
 dialogLock = true
 fileDialog(true, function (res)
  dialogLock = false
  if res then
   for k, v in ipairs(lines) do
    if k ~= 1 then
     res.write("\n" .. v)
    else
     res.write(v)
    end
   end
   res.close()
  end
 end)
end

local function startLoad()
 dialogLock = true
 fileDialog(false, function (res)
  dialogLock = false
  if res then
   lines = {}
   local lb = ""
   while true do
    local l = res.read(64)
    if not l then
     table.insert(lines, lb)
     cursorX = 1
     cursorY = 1
     res.close()
     flush()
     return
    end
    local lp = l:find("\n")
    while lp do
     lb = lb .. l:sub(1, lp - 1)
     table.insert(lines, lb)
     lb = ""
     l = l:sub(lp + 1)
     lp = l:find("\n")
    end
    lb = lb .. l
   end
  end
 end)
end

local function getline(y)
 -- do rY first since unw
 -- only requires that
 -- horizontal stuff be
 -- messed with...
 -- ...thankfully
 local rY = (y + cursorY) - math.ceil(sH / 2)

 -- rX is difficult!
 local rX = 1
 local Xthold = math.max(1, math.floor(sW / 2) - 1)
 local _, cursorXP = unicode.safeTextFormat(lines[cursorY], cursorX)
 rX = (math.max(0, math.floor(cursorXP / Xthold) - 1) * Xthold) + 1
 local line = lines[rY]
 if not line then
  return ("¬"):rep(sW)
 end
 line = unicode.safeTextFormat(line)
 -- <alter RX here by 1 if needed>
 local tl = unicode.sub(line, rX, rX + sW - 1)
 cursorXP = (cursorXP - rX) + 1
 if cFlash then
  if rY == cursorY then
   if cursorXP >= 1 then
    if cursorXP <= sW then
     local start = unicode.sub(tl, 1, cursorXP - 1)
     local endx = unicode.sub(tl, cursorXP + 1)
     tl = start .. "_" .. endx
    end
   end
  end
 end
 while unicode.len(tl) < sW do
  tl = tl .. " "
 end
 return tl
end
local function delLine()
 local contents = lines[cursorY]
 if cursorY == #lines then
  if cursorY == 1 then
   lines[1] = ""
  else
   cursorY = cursorY - 1
   lines[#lines] = nil
  end
 else
  table.remove(lines, cursorY)
 end
 return contents
end
-- add a single character
local function putLetter(ch)
 if ch == "\r" then
  local a, b = splitCur()
  lines[cursorY] = a
  table.insert(lines, cursorY + 1, b)
  cursorY = cursorY + 1
  cursorX = 1
  return
 end
 local a, b = splitCur()
 a = a .. ch
 lines[cursorY] = a .. b
 cursorX = unicode.len(a) + 1
end
local function ev_key(ka, kc, down)
 if dialogLock then
  return false
 end
 if kc == 29 then
  ctrlFlag = down
  return false
 end
 -- Action keys
 if not down then return false end
 if ctrlFlag then
  -- Control Action Keys
  if kc == 200 then -- Up
   sH = sH - 1
   if sH == 0 then
    sH = 1
   end
   sW, sH = window.setSize(sW, sH)
  end
  if kc == 208 then -- Down
   sH = sH + 1
   sW, sH = window.setSize(sW, sH)
  end
  if kc == 203 then -- Left
   sW = sW - 1
   if sW == 0 then
    sW = 1
   end
   sW, sH = window.setSize(sW, sH)
  end
  if kc == 205 then -- Right
   sW = sW + 1
   sW, sH = window.setSize(sW, sH)
  end
  if kc == 14 then -- ^Backspace
   delLine()
   return true
  end
 else
  -- Non-Control Action Keys
  -- Basic Action Keys
  if kc == 200 or kc == 201 then -- Go up one - go up page
   local moveAmount = 1
   if kc == 201 then
    moveAmount = math.floor(sH / 2)
   end
   cursorY = cursorY - moveAmount
   if cursorY < 1 then
    cursorY = 1
   end
   clampCursorX()
   return true
  end
  if kc == 208 or kc == 209 then -- Go down one - go down page
   local moveAmount = 1
   if kc == 209 then
    moveAmount = math.floor(sH / 2)
   end
   cursorY = cursorY + moveAmount
   if cursorY > #lines then
    cursorY = #lines
   end
   clampCursorX()
   return true
  end
  if kc == 203 then
   if cursorX > 1 then
    cursorX = cursorX - 1
   else
    if cursorY > 1 then
     cursorY = cursorY - 1
     cursorX = unicode.len(lines[cursorY]) + 1
    else
     return false
    end
   end
   return true
  end
  if kc == 205 then
   cursorX = cursorX + 1
   if clampCursorX() then
    if cursorY < #lines then
     cursorY = cursorY + 1
     cursorX = 1
    end
   end
   return true
  end
  -- Extra Non-Control Keys
  if kc == 199 then
   cursorX = 1
   return true
  end
  if kc == 207 then
   cursorX = unicode.len(lines[cursorY]) + 1
   return true
  end
  -- Major Actions
  if kc == 59 then -- F1
   lines = {""}
   cursorX = 1
   cursorY = 1
   return true
  end
  if kc == 61 then -- F3
   startLoad()
  end
  if kc == 62 then -- F4
   startSave()
  end
  if kc == 63 then -- F5
   clipsrc.setSetting("clipboard", lines[cursorY])
  end
  if kc == 64 then -- F6
   local tx = clipsrc.getSetting("clipboard") or ""
   local txi = tx:find("\n")
   local nt = {}
   while txi do
    table.insert(nt, 1, tx:sub(1, txi - 1))
    tx = tx:sub(txi + 1)
    txi = tx:find("\n")
   end
   table.insert(lines, cursorY, tx)
   for _, v in ipairs(nt) do
    table.insert(lines, cursorY, v)
   end
   return true
  end
  if kc == 65 then -- F7
   appendFlag = false
  end
  if kc == 66 then -- F8
   if appendFlag then
    local base = clipsrc.getSetting("clipboard")
    clipsrc.setSetting("clipboard", base .. "\n" .. delLine())
   else
    clipsrc.setSetting("clipboard", delLine())
   end
   appendFlag = true
   return true
  end
 end
 -- Letters
 if ka ~= 0 then
  if ka == 8 then
   if cursorX == 1 then
    if cursorY == 1 then
     return false
    end
    local l = table.remove(lines, cursorY)
    cursorY = cursorY - 1
    cursorX = unicode.len(lines[cursorY]) + 1
    lines[cursorY] = lines[cursorY] .. l
   else
    local a, b = splitCur()
    a = unicode.sub(a, 1, unicode.len(a) - 1)
    lines[cursorY] = a.. b
    cursorX = cursorX - 1
   end
   return true
  end
  putLetter(unicode.char(ka))
  return true
 end
 return false
end

local function ev_clipboard(t)
 for i = 1, unicode.len(t) do
  local c = unicode.sub(t, i, i)
  if c ~= "\r" then
   if c == "\n" then
    c = "\r"
   end
   putLetter(c)
  end
 end
end

flush = function ()
 for i = 1, sH do
  window.span(1, i, getline(i), 0xFFFFFF, 0)
 end
end
local flash
flash = function ()
 cFlash = not cFlash
 -- reverse:
 --local rY = (y + cursorY) - math.ceil(sH / 2)
 local csY = math.ceil(sH / 2)
 window.span(1, csY, getline(csY), 0xFFFFFF, 0)
 event.runAt(os.uptime() + 0.5, flash)
end
event.runAt(os.uptime() + 0.5, flash)

while true do
 local e = {event.pull()}
 if e[1] == "x.neo.pub.window" then
  if e[2] == window.id then
   if e[3] == "touch" then
    -- reverse:
    --local rY = (y + cursorY) - math.ceil(sH / 2)
    local csY = math.ceil(sH / 2)
    local nY = math.max(1, math.min(#lines, (math.floor(e[5]) - csY) + cursorY))
    cursorY = nY
    clampCursorX()
    flush()
   end
   if e[3] == "key" then
    if ev_key(e[4], e[5], e[6]) then
     flush()
    end
   end
   if e[3] == "line" then
    window.span(1, e[4], getline(e[4]), 0xFFFFFF, 0)
   end
   if e[3] == "focus" then
    ctrlFlag = false
   end
   if e[3] == "close" then
    return
   end
   if e[3] == "clipboard" then
    ev_clipboard(e[4])
    flush()
   end
  elseif cbs[e[2]] then
   if e[3] == "line" then
    cbs[e[2]][2](1, 1, cbs[e[2]][3], 0, 0xFFFFFF)
   end
   if e[3] == "close" then
    cbs[e[2]][1]()
    cbs[e[2]] = nil
   end
  end
 end
end
