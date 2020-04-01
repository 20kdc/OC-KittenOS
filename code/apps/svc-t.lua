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
 elseif leText then
  window.span(1, i, require("lineedit").draw(conW, unicode.safeTextFormat(leText, leCX)), 0xFFFFFF, 0)
 end
end
local function drawDisplay()
 for i = 1, #console do draw(i) end
end

-- Terminal Visual --

local function writeFF()
 if conCY ~= #console then
  conCY = conCY + 1
 else
  for i = 1, #console - 1 do
   console[i] = console[i + 1]
  end
  console[#console] = (" "):rep(conW)
 end
end

local function writeData(data)
 -- handle data until completion
 while #data > 0 do
  local char = unicode.sub(data, 1, 1)
  data = unicode.sub(data, 2)
  -- handle character
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
  end
 end
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
 -- Flush UTF
 while #tvBuildingUTF > 0 do
  local head = tvBuildingUTF:byte()
  local len = 1
  if head >= 192 and head < 224 then len = 2 end
  if head >= 224 and head < 240 then len = 3 end
  if head >= 240 and head < 248 then len = 4 end
  if head >= 248 and head < 252 then len = 5 end
  if head >= 252 and head < 254 then len = 6 end
  if #tvBuildingUTF < len then break end
  -- verified one full character...
  local char = tvBuildingUTF:sub(1, len)
  tvBuildingUTF = tvBuildingUTF:sub(len + 1)
  writeData(char)
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

local function key(a, c)
 if not leText then
  for _, v in pairs(sendSigs) do
   if a == "\r" then
    v("data", "\r\n")
   elseif a then
    v("data", a)
   end
  end
 else
  -- Line Editing active
  if c == 200 or c == 208 then
   -- History cursor up (history down)
   leText = leHistory[#leHistory]
   leCX = unicode.len(leText)
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

local control = false
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
    if not control then
     key(e[4] ~= 0 and unicode.char(e[4]), e[5])
     draw(#console + 1)
    elseif e[5] == 203 and sW > 8 then
     setSize(conW - 1, #console)
    elseif e[5] == 200 and #console > 1 then
     setSize(conW, #console - 1)
    elseif e[5] == 205 then
     setSize(conW + 1, #console)
    elseif e[5] == 208 then
     setSize(conW, #console + 1)
    end
   end
  elseif e[3] == "line" then
   draw(e[4])
  end
 end
end
