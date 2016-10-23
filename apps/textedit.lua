-- 'Femto': Text Editor
-- Formatting proc. for
-- this file is the def.
-- size of a textedit win
local lang,
      table,
      unicode,
      math,
      proc =
 A.request("lang",
           "table",
           "unicode",
           "math",
           "proc")
local lines = {
 "Femto: Text Editor",
 "^W : Close, ^S : Save",
 "^A : Load , ^Q : New.",
 "^C : Copy Line,",
 "^V : Paste Line",
 "^<arrows>: Resize Win",
 "'^' is Control.",
 "Now with wide text!",
 "Ｙａｙ！"
}
local linesTranslated =
 lang.getTable()
if linesTranslated then
 lines = linesTranslated
end

local cursorX = 1
local cursorY = 1
local cFlash = true
local ctrlFlag = false
local sW, sH = 25, 8

local app = {}

local function splitCur()
 local s = lines[cursorY]
 local st = unicode.sub
  (s, 1, cursorX - 1)
 local en = unicode.sub
  (s, cursorX)
 return st, en
end

local function
 clampCursorX()
 local s = lines[cursorY]
 if unicode.len(s) <
  (cursorX - 1) then
  cursorX =
   unicode.len(s) + 1
  return true
 end
 return false
end

-- Save/Load
local function save()
 ctrlFlag = false
 local txt =
  A.openfile("text", "w")
 if txt then
  for k, v in
   ipairs(lines) do
   if k ~= 1 then
    txt.write("\n" .. v)
   else
    txt.write(v)
   end
  end
  txt.close()
 end
end
local function load()
 ctrlFlag = false
 local txt =
  A.openfile("text", "r")
 if txt then
  lines = {}
  local lb = ""
  while true do
   local l = txt.read(64)
   if not l then
    table.insert
     (lines, lb)
    cursorX = 1
    cursorY = 1
    txt.close()
    return
   end
   local lp =
    l:find("\n")
   while lp do
    lb = lb .. l:sub(1,
     lp - 1)
    table.insert
     (lines, lb)
    lb = ""
    l = l:sub(lp + 1)
    lp = l:find("\n")
   end
   lb = lb .. l
  end
 end
end

function app.get_ch(x, y)
 -- do rY first since unw
 -- only requires that
 -- horizontal stuff be
 -- messed with...
 -- ...thankfully
 local rY = (y + cursorY)
  - math.floor(sH / 2)

 -- rX is difficult!
 local rX = 1
 local Xthold =
  math.floor(sW / 2)
 if cursorX > Xthold then
  rX = rX + (cursorX -
   Xthold)
 end
 local line = lines[rY]
 if not line then return
  "¬" end
 local _, cursorXP =
  unicode.safeTextFormat(
  line, cursorX)
 line, rX =
  unicode.safeTextFormat(
  line, rX)

 -- 1-based cambias stuff
 rX = rX + (x - 1)
 if rX == cursorXP then
  if rY == cursorY then
   if cFlash then
    return "_"
   end
  end
 end
 return unicode.sub(line,
  rX, rX)
end
-- communicate with the
-- "lineclip" clipboard,
-- for inter-window copy
function lineclip(c, m)
 for _, v in
  ipairs(proc.listApps())
  do
  if v[2] == "lineclip"
   then
   return proc.sendRPC(
    v[1], c, m)
  end
 end
 local aid = A.launchApp(
  "lineclip")
 ctrlFlag = false
 if aid then return
  proc.sendRPC(aid, c, m)
 end
 return ""
end
-- add a single character
function putLetter(ch)
 if ch == "\r" then
  local a, b = splitCur()
  lines[cursorY] = a
  table.insert(lines,
   cursorY + 1, b)
  cursorY = cursorY + 1
  cursorX = 1
  return
 end
 local a, b = splitCur()
 a = a .. ch
 lines[cursorY] = a .. b
 cursorX =
  unicode.len(a) + 1
end
function app.key(ka, kc,
 down)
 if kc == 29 then
  ctrlFlag = down
  return false
 end
 if ctrlFlag then
  if not down then
   return false end
  if kc == 17 -- W
   then A.die() end
  if kc == 200 then
   sH = sH - 1
   if sH == 0 then
    sH = 1 end
   A.resize(sW, sH)
  end
  if kc == 208 then
   sH = sH + 1
   A.resize(sW, sH)
  end
  if kc == 203 then
   sW = sW - 1
   if sW == 0 then
    sW = 1 end
   A.resize(sW, sH)
  end
  if kc == 205 then
   sW = sW + 1
   A.resize(sW, sH)
  end
  if kc == 31 -- S
   then return save() end
  if kc == 30 -- A
   then return load() end
  if kc == 16 -- Q
   then lines = {""}
   cursorX = 1
   cursorY = 1
   return true end
  if kc == 46 -- C
   then lineclip("copy",
    lines[cursorY]) end
  if kc == 47 then -- V
   table.insert(lines,
    cursorY,
    lineclip("paste"))
   return true
  end
  return false
 end
 -- action keys
 if not down then
  return false
 end
 if kc == 200
  or kc == 201 then
  local moveAmount = 1
  if kc == 201 then
   moveAmount =
    math.floor(sH / 2)
  end
  cursorY = cursorY -
   moveAmount
  if cursorY < 1 then
   cursorY = 1 end
  clampCursorX()
  return true
 end
 if kc == 208
  or kc == 209 then
  local moveAmount = 1
  if kc == 209 then
   moveAmount =
    math.floor(sH / 2)
  end
  cursorY = cursorY +
   moveAmount
  if cursorY> #lines then
   cursorY = #lines end
  clampCursorX()
  return true
 end
 if kc == 203 then
  if cursorX > 1 then
   cursorX = cursorX - 1
  else
   if cursorY > 1 then
    cursorY = cursorY - 1
    cursorX = unicode.len
     (lines[cursorY]) + 1
   else
    return false
   end
  end
  return true
 end
 if kc == 205 then
  cursorX = cursorX + 1
  if clampCursorX() then
   if cursorY < #lines
    then
    cursorY = cursorY + 1
    cursorX = 1
   end
  end
  return true
 end
 if kc == 199 then
  cursorX = 1
  return true
 end
 if kc == 207 then
  cursorX = unicode.len(
   lines[cursorY]) + 1
  return true
 end
 if ka == 8 then
  if cursorX == 1 then
   if cursorY == 1 then
    return false
   end
   local l = table.remove
    (lines, cursorY)
   cursorY = cursorY - 1
   cursorX = unicode.len(
    lines[cursorY]) + 1
   lines[cursorY] =
    lines[cursorY] .. l
  else
   local a, b =splitCur()
   a = unicode.sub(a, 1,
    unicode.len(a) - 1)
   lines[cursorY] = a.. b
   cursorX = cursorX - 1
  end
  return true
 end
 if ka ~= 0 then
  putLetter
   (unicode.char(ka))
  return true
 end
 return false
end
function app.clipboard(t)
 for i = 1,
  unicode.len(t) do
  local c =
   unicode.sub(t, i, i)
  if c ~= "\r" then
   if c == "\n" then
    c = "\r"
   end
   putLetter(c)
  end
 end
 return true
end
function app.update()
 cFlash = not cFlash
 A.timer(0.5)
 return true
end
return app, sW, sH