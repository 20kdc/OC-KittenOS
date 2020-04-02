-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- svc-t.lua : terminal

local _, _, retTbl, title = ...

assert(retTbl, "need to alert creator")

if title ~= nil then
 assert(type(title) == "string", "title must be string")
end

local function rW()
 return string.format("%04x", math.random(0, 65535))
end

local id = "neo.pub.t/" .. rW() .. rW() .. rW() .. rW()
local closeNow = false

-- Terminus Registration State --

local tReg = neo.requireAccess("r." .. id, "registration")
local sendSigs = {}

-- Display State --
-- unicode.safeTextFormat'd lines.
-- The size of this must not go below 1.
local console = {}
-- This must not go below 3.
local conW = 40
local conCX, conCY = 1, 1
local conCV = false
for i = 1, 14 do
 console[i] = (" "):rep(conW)
end

-- Line Editing State --
-- Nil if line editing is off.
-- In this case, the console height
--  must be adjusted accordingly.
local leText = ""
-- These are NOT nil'd out,
--  particularly not the history buffer.
local leCX = 1
local leHistory = {
 -- Size = history buffer size
 "", "", "", ""
}
local function cycleHistoryUp()
 local backupFirst = leHistory[1]
 for i = 1, #leHistory - 1 do
  leHistory[i] = leHistory[i + 1]
 end
 leHistory[#leHistory] = backupFirst
end
local function cycleHistoryDown()
 local backup = leHistory[1]
 for i = 2, #leHistory do
  backup, leHistory[i] = leHistory[i], backup
 end
 leHistory[1] = backup
end

-- Window --

local window = neo.requireAccess("x.neo.pub.window", "window")(conW, #console + 1, title)

-- Core Terminal Functions --

local function setSize(w, h)
 conW = w
 while #console < h do
  table.insert(console, "")
 end
 while #console > h do
  table.remove(console, 1)
 end
 for i = 1, #console do
  console[i] = unicode.sub(console[i], 1, w) .. (" "):rep(w - unicode.len(console[i]))
 end
 if leText then
  window.setSize(w, h + 1)
 else
  window.setSize(w, h)
 end
 conCX, conCY = 1, h
end

local function setLineEditing(state)
 if state and not leText then
  leText = ""
  leCX = 1
  setSize(conW, #console)
 elseif leText and not state then
  leText = nil
  setSize(conW, #console)
 end
end

local function draw(i)
 if console[i] then
  window.span(1, i, console[i], 0, 0xFFFFFF)
  if i == conCY and conCV then
   window.span(conCX, i, unicode.sub(console[i], conCX, conCX), 0xFFFFFF, 0)
  end
 elseif leText then
  window.span(1, i, require("lineedit").draw(conW, unicode.safeTextFormat(leText, leCX)), 0xFFFFFF, 0)
 end
end
local function drawDisplay()
 for i = 1, #console do draw(i) end
end

-- Terminal Visual --

local function consoleSD()
 for i = 1, #console - 1 do
  console[i] = console[i + 1]
 end
 console[#console] = (" "):rep(conW)
end
local function consoleSU()
 local backup = (" "):rep(conW)
 for i = 1, #console do
  backup, console[i] = console[i], backup
 end
end

local function writeFF()
 if conCY ~= #console then
  conCY = conCY + 1
 else
  consoleSD()
 end
end

local function writeData(data)
 -- handle data until completion
 while #data > 0 do
  local char = unicode.sub(data, 1, 1)
  data = unicode.sub(data, 2)
  -- handle character
  if char == "\t" then
   -- not ideal, but allowed
   char = " "
  end
  if char == "\r" then
   conCX = 1
  elseif char == "\n" then
   conCX = 1
   writeFF()
  elseif char == "\a" then
   -- Bell (er...)
  elseif char == "\b" then
   conCX = math.max(1, conCX - 1)
  elseif char == "\v" or char == "\f" then
   writeFF()
  else
   local charL = unicode.wlen(char)
   if (conCX + charL - 1) > conW then
    conCX = 1
    writeFF()
   end
   local spaces = (" "):rep(charL - 1)
   console[conCY] = unicode.sub(console[conCY], 1, conCX - 1) .. char .. spaces .. unicode.sub(console[conCY], conCX + charL)
   conCX = conCX + charL
   -- Cursor can be (intentionally!) off-screen here
  end
 end
end

local function writeANSI(s)
 -- This supports just about enough to get by.
 if s == "c" then
  for i = 1, #console do
   console[i] = (" "):rep(conW)
  end
  conCX, conCY = 1, 1
  return
 end
 local pfx = s:sub(1, 1)
 local cmd = s:sub(#s)
 if pfx == "[" then
  local np = tonumber(s:sub(2, -2)) or 1
  if cmd == "H" or cmd == "f" then
   local p = s:find(";")
   if not p then
    conCX, conCY = 1, 1
   else
    conCY = tonumber(s:sub(2, p - 1)) or 1
    conCX = tonumber(s:sub(p + 1, -2)) or 1
   end
  elseif cmd == "K" then
   console[conCY] = unicode.sub(console[conCY], 1, conCX - 1) .. (" "):rep(1 + conW - conCX)
  elseif cmd == "A" then
   conCY = conCY - np
  elseif cmd == "B" then
   conCY = conCY + np
  elseif cmd == "C" then
   conCX = conCX + np
  elseif cmd == "D" then
   conCX = conCX - np
  elseif cmd == "S" then
   for i = 1, np do
    consoleSU()
   end
  elseif cmd == "T" then
   for i = 1, np do
    consoleSD()
   end
  end
 end
 conCX = math.min(math.max(math.floor(conCX), 1), conW)
 conCY = math.min(math.max(math.floor(conCY), 1), #console)
end

-- The Terminus --

local tvBuildingCmd = ""
local tvBuildingUTF = ""
local tvSubnegotiation = false
local function incoming(s)
 tvBuildingCmd = tvBuildingCmd .. s
 -- Flush Cmd
 while #tvBuildingCmd > 0 do
  if tvBuildingCmd:byte() == 255 then
   -- It's a command. Uhoh.
   if #tvBuildingCmd < 2 then break end
   local cmd = tvBuildingCmd:byte(2)
   local param = tvBuildingCmd:byte(3)
   local cmdLen = 2
   -- Command Lengths
   if cmd >= 251 and cmd <= 254 then cmdLen = 3 end
   if #tvBuildingCmd < cmdLen then break end
   if cmd == 240 then
    -- SE
    tvSubnegotiation = false
   elseif cmd == 250 then
    -- SB
    tvSubnegotiation = true
   elseif cmd == 251 and param == 1 then
    -- WILL ECHO (respond with DO ECHO, disable line editing)
    -- test using io.write("\xFF\xFB\x01")
    for _, v in pairs(sendSigs) do
     v("telnet", "\xFF\xFD\x01")
    end
    setLineEditing(false)
   elseif cmd == 252 and param == 1 then
    -- WON'T ECHO (respond with DON'T ECHO, enable line editing)
    for _, v in pairs(sendSigs) do
     v("telnet", "\xFF\xFE\x01")
    end
    setLineEditing(true)
   elseif cmd == 251 or cmd == 252 then
    -- WILL/WON'T (x) (respond with DON'T (X))
    local res = "\xFF\xFE" .. string.char(param)
    for _, v in pairs(sendSigs) do
     v("telnet", res)
    end
   elseif cmd == 253 or cmd == 254 then
    -- DO/DON'T (x) (respond with WON'T (X))
    local res = "\xFF\xFC" .. string.char(param)
    for _, v in pairs(sendSigs) do
     v("telnet", res)
    end
   elseif cmd == 255 then
    if not tvSubnegotiation then
     tvBuildingUTF = tvBuildingUTF .. "\xFF"
    end
   end
   tvBuildingCmd = tvBuildingCmd:sub(cmdLen + 1)
  else
   if not tvSubnegotiation then
    tvBuildingUTF = tvBuildingUTF .. tvBuildingCmd:sub(1, 1)
   end
   tvBuildingCmd = tvBuildingCmd:sub(2)
  end
 end
 -- Flush UTF/Display
 while #tvBuildingUTF > 0 do
  local head = tvBuildingUTF:byte()
  local len = 1
  local handled = false
  if head == 27 then
   local h2 = tvBuildingUTF:byte(2)
   if h2 == 91 then
    for i = 3, #tvBuildingUTF do
     local cmd = tvBuildingUTF:byte(i)
     if cmd >= 0x40 and cmd <= 0x7E then
      writeANSI(tvBuildingUTF:sub(2, i))
      len = i
      handled = true
      break
     end
    end
   elseif h2 then
    len = 2
    writeANSI(tvBuildingUTF:sub(2, 2))
    handled = true
   end
   if not handled then break end
  end
  if not handled then
   if head < 192 then
    len = 1
   elseif head < 224 then
    len = 2
   elseif head < 240 then
    len = 3
   elseif head < 248 then
    len = 4
   elseif head < 252 then
    len = 5
   elseif head < 254 then
    len = 6
   end
   if #tvBuildingUTF < len then
    break
   end
   -- verified one full character...
   writeData(tvBuildingUTF:sub(1, len))
  end
  tvBuildingUTF = tvBuildingUTF:sub(len + 1)
 end
end

do
 tReg(function (_, pid, sendSig)
  sendSigs[pid] = sendSig
  return {
   id = "x." .. id,
   pid = neo.pid,
   write = function (text)
    incoming(tostring(text))
    drawDisplay()
   end
  }
 end, true)

 if retTbl then
  coroutine.resume(coroutine.create(retTbl), {
   access = "x." .. id,
   close = function ()
    closeNow = true
    neo.scheduleTimer(0)
   end
  })
 end
end

local control = false

local function key(a, c)
 if control then
  if c == 203 and conW > 8 then
   setSize(conW - 1, #console)
   return
  elseif c == 200 and #console > 1 then
   setSize(conW, #console - 1)
   return
  elseif c == 205 then
   setSize(conW + 1, #console)
   return
  elseif c == 208 then
   setSize(conW, #console + 1)
   return
  end
 end
 -- so with the reserved ones dealt with...
 if not leText then
  -- Line Editing not active.
  -- For now support a bare minimum.
  for _, v in pairs(sendSigs) do
   if control then
    if a == 99 then
     v("telnet", "\xFF\xF4")
    end
   elseif a == "\r" then
    v("data", "\r\n")
   elseif a then
    v("data", a)
   end
  end
 elseif not control then
  -- Line Editing active and control isn't involved
  if c == 200 or c == 208 then
   -- History cursor up (history down)
   leText = leHistory[#leHistory]
   leCX = unicode.len(leText) + 1
   if c == 208 then
    cycleHistoryUp()
   else
    cycleHistoryDown()
   end
   return
  end
  local lT, lC, lX = require("lineedit").key(a, c, leText, leCX)
  leText = lT or leText
  leCX = lC or leCX
  if lX == "nl" then
   cycleHistoryUp()
   leHistory[#leHistory] = leText
   -- the whole thing {
   local fullText = leText .. "\r\n"
   writeData(fullText)
   drawDisplay()
   for _, v in pairs(sendSigs) do
    v("data", fullText)
   end
   -- }
   leText = ""
   leCX = 1
  end
 end
end

while not closeNow do
 local e = {coroutine.yield()}
 if e[1] == "k.procdie" then
  sendSigs[e[3]] = nil
 elseif e[1] == "x.neo.pub.window" then
  if e[3] == "close" then
   break
  elseif e[3] == "clipboard" then
   for i = 1, unicode.len(e[4]) do
    local c = unicode.sub(e[4], i, i)
    if c ~= "\r" then
     if c == "\n" then
      c = "\r"
     end
     key(c, 0)
    end
   end
   draw(#console + 1)
  elseif e[3] == "key" then
   if e[5] == 29 or e[5] == 157 then
    control = e[6]
   elseif e[6] then
    key(e[4] ~= 0 and unicode.char(e[4]), e[5])
    draw(#console + 1)
   end
  elseif e[3] == "line" then
   draw(e[4])
  end
 end
end
