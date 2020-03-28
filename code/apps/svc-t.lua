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

local id = "svc.t/" .. rW() .. rW() .. rW() .. rW()
local closeNow = false

local tReg = neo.requireAccess("r." .. id, "registration")

-- unicode.safeTextFormat'd lines
local console = {}
for i = 1, 14 do
 console[i] = (" "):rep(40)
end

local l15 = ""
--++++++++++++++++++++++++++++++++++++++++

-- sW must not go below 3.
-- sH must not go below 2.
local sW, sH = 40, 15
local windows = neo.requireAccess("x.neo.pub.window", "windows")
local window = windows(sW, sH, title)

local function fmtLine(s)
 s = unicode.safeTextFormat(s)
 local l = unicode.len(s)
 return unicode.sub(s .. (" "):rep(sW - l), -sW)
end

local function line(i)
 if i ~= sH then
  assert(console[i], "console" .. i)
  window.span(1, i, fmtLine(console[i]), 0xFFFFFF, 0)
 else
  window.span(1, i, fmtLine(l15), 0, 0xFFFFFF)
 end
end

local function incoming(s)
 local function shift(f)
  for i = 1, #console - 1 do
   console[i] = console[i + 1]
  end
  console[#console] = f
 end
 -- Need to break this safely.
 shift("")
 for i = 1, unicode.len(s) do
  local ch = unicode.sub(s, i, i)
  if unicode.wlen(console[#console] .. ch) > sW then
   shift(" ")
  end
  console[#console] = console[#console] .. ch
 end
 for i = 1, #console do
  line(i)
 end
end

local sendSigs = {}

local function submitLine()
 for _, v in pairs(sendSigs) do
  v("line", l15)
 end
 l15 = ""
 line(sH)
end

local function clipEnt(tx)
 tx = tx:gsub("\r", "")
 local ci = tx:find("\n") or (#tx + 1)
 tx = tx:sub(1, ci - 1)
 l15 = l15 .. tx
 line(sH)
end

do
 tReg(function (_, pid, sendSig)
  sendSigs[pid] = sendSig
  return {
   id = "x." .. id,
   pid = neo.pid,
   line = function (text)
    incoming(tostring(text))
   end
  }
 end)

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
while not closeNow do
 local e = {coroutine.yield()}
 if e[1] == "k.procdie" then
  sendSigs[e[3]] = nil
 elseif e[1] == "x.neo.pub.window" then
  if e[3] == "close" then
   break
  elseif e[3] == "clipboard" then
   clipEnt(e[4])
  elseif e[3] == "key" then
   if e[5] == 29 or e[5] == 157 then
    control = e[6]
   elseif e[6] then
    if not control then
     if e[4] == 8 or e[4] == 127 then
      l15 = unicode.sub(l15, 1, -2)
     elseif e[4] == 13 then
      submitLine()
     elseif e[4] >= 32 then
      l15 = l15 .. unicode.char(e[4])
     end
     line(sH)
    elseif e[5] == 203 and sW > 8 then
     sW = sW - 1
     window.setSize(sW, sH)
    elseif e[5] == 200 and sH > 2 then
     sH = sH - 1
     table.remove(console, 1)
     window.setSize(sW, sH)
    elseif e[5] == 205 then
     sW = sW + 1
     window.setSize(sW, sH)
    elseif e[5] == 208 then
     sH = sH + 1
     table.insert(console, 1, "")
     window.setSize(sW, sH)
    end
   end
  elseif e[3] == "line" then
   line(e[4])
  end
 end
end
