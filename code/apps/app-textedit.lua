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
 --  except fixing a UI flaw by instead adding a visible way to reset the append flag,
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

local clipsrc = neo.requireAccess("x.neo.pub.globals", "clipboard")
local windows = neo.requireAccess("x.neo.pub.window", "windows")
local files = neo.requireAccess("x.neo.pub.base", "files").showFileDialogAsync

local lineEdit = require("lineedit")

local cursorX = 1
local cursorY = math.ceil(#lines / 2)
local ctrlFlag, appendFlag
local dialogLock = false
local sW, sH = 37, #lines + 2
local window = windows(sW, sH)
local filedialog = nil
local flush

local cbs = {}

local function fileDialog(writing, callback)
 filedialog = function (res)
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
 end
 files(writing)
end

-- Save/Load
local function startSave()
 dialogLock = true
 fileDialog(true, function (res)
  dialogLock = false
  local x = ""
  if res then
   for k, v in ipairs(lines) do
    if k ~= 1 then
     x = x .. "\n"
    end
    x = x .. v
    while #x >= neo.readBufSize do
     res.write(x:sub(1, neo.readBufSize))
     x = x:sub(neo.readBufSize + 1)
    end
   end
   res.write(x)
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
    local l = res.read(neo.readBufSize)
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
 local cLine, cursorXP = unicode.safeTextFormat(lines[cursorY], cursorX)
 rX = (math.max(0, math.floor(cursorXP / Xthold) - 1) * Xthold) + 1
 local line = lines[rY]
 if not line then
  return ("¬"):rep(sW)
 end
 line = unicode.safeTextFormat(line)
 return lineEdit.draw(sW, line, rY == cursorY and cursorXP, rX)
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
local function key(ks, kc, down)
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
   return false
  elseif kc == 208 then -- Down
   sH = sH + 1
   sW, sH = window.setSize(sW, sH)
   return false
  elseif kc == 203 then -- Left
   sW = sW - 1
   if sW == 0 then
    sW = 1
   end
   sW, sH = window.setSize(sW, sH)
   return false
  elseif kc == 205 then -- Right
   sW = sW + 1
   sW, sH = window.setSize(sW, sH)
   return false
  elseif kc == 14 then -- ^Backspace
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
   cursorX = lineEdit.clamp(lines[cursorY], cursorX)
   return true
  elseif kc == 208 or kc == 209 then -- Go down one - go down page
   local moveAmount = 1
   if kc == 209 then
    moveAmount = math.floor(sH / 2)
   end
   cursorY = cursorY + moveAmount
   if cursorY > #lines then
    cursorY = #lines
   end
   cursorX = lineEdit.clamp(lines[cursorY], cursorX)
   return true
  end
  -- Major Actions
  if kc == 59 then -- F1
   lines = {""}
   cursorX = 1
   cursorY = 1
   return true
  elseif kc == 61 then -- F3
   startLoad()
   return false
  elseif kc == 62 then -- F4
   startSave()
   return false
  elseif kc == 63 then -- F5
   clipsrc.setSetting("clipboard", lines[cursorY])
   return false
  elseif kc == 64 then -- F6
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
  elseif kc == 65 then -- F7
   appendFlag = false
   return false
  elseif kc == 66 then -- F8
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
 -- LEL Keys
 local lT, lC, lX = lineEdit.key(ks, kc, lines[cursorY], cursorX)
 if lT then
  lines[cursorY] = lT
 end
 if lC then
  cursorX = lC
 end
 if lX == "l<" and cursorY > 1 then
  cursorY = cursorY - 1
  cursorX = unicode.len(lines[cursorY]) + 1
 elseif lX == "l>" and cursorY < #lines then
  cursorY = cursorY + 1
  cursorX = 1
 elseif lX == "w<" and cursorY ~= 1 then
  local l = table.remove(lines, cursorY)
  cursorY = cursorY - 1
  cursorX = unicode.len(lines[cursorY]) + 1
  lines[cursorY] = lines[cursorY] .. l
 elseif lX == "w>" and cursorY ~= #lines then
  local l = table.remove(lines, cursorY)
  cursorX = unicode.len(l) + 1
  lines[cursorY] = l .. lines[cursorY]
 elseif lX == "nl" then
  local line = lines[cursorY]
  lines[cursorY] = unicode.sub(line, 1, cursorX - 1)
  table.insert(lines, cursorY + 1, unicode.sub(line, cursorX))
  cursorX = 1
  cursorY = cursorY + 1
 end
 return true
end

flush = function ()
 for i = 1, sH do
  window.span(1, i, getline(i), 0xFFFFFF, 0)
 end
end

while true do
 local e = {coroutine.yield()}
 if e[1] == "x.neo.pub.window" then
  if e[2] == window.id then
   if e[3] == "line" then
    window.span(1, e[4], getline(e[4]), 0xFFFFFF, 0)
   elseif filedialog then
   elseif e[3] == "touch" then
    -- reverse:
    --local rY = (y + cursorY) - math.ceil(sH / 2)
    local csY = math.ceil(sH / 2)
    local nY = math.max(1, math.min(#lines, (math.floor(e[5]) - csY) + cursorY))
    cursorY = nY
    cursorX = lineEdit.clamp(lines[cursorY], cursorX)
    flush()
   elseif e[3] == "key" then
    if key(e[4] ~= 0 and unicode.char(e[4]), e[5], e[6]) then
     flush()
    end
   elseif e[3] == "focus" then
    ctrlFlag = false
   elseif e[3] == "close" then
    return
   elseif e[3] == "clipboard" then
    local t = e[4]
    for i = 1, unicode.len(t) do
     local c = unicode.sub(t, i, i)
     if c ~= "\r" then
      if c == "\n" then
       c = "\r"
      end
      key(c, 0, true)
     end
    end
    flush()
   end
  elseif cbs[e[2]] then
   if e[3] == "line" then
    cbs[e[2]][2](1, 1, cbs[e[2]][3], 0, 0xFFFFFF)
   elseif e[3] == "close" then
    cbs[e[2]][1]()
    cbs[e[2]] = nil
   end
  end
 elseif e[1] == "x.neo.pub.base" and e[2] == "filedialog" and filedialog then
  filedialog(e[4])
  filedialog = nil
 end
end
