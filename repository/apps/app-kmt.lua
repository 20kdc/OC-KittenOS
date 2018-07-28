-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-kmt.lua : LC emergency plan
-- Authors: 20kdc

local lcOverride = false
local l15 = "20kdc.duckdns.org:8888"

-- unicode.safeTextFormat'd lines
local console = {
 "┎┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┒",
 "┋         ┃ ╱  ┃╲    ╱┃  ▀▀┃▀▀         ┋",
 "┋         ┃╳   ┃ ╲  ╱ ┃    ┃           ┋",
 "┋         ┃ ╲  ┃  ╲╱  ┃    ┃           ┋",
 "┋                                      ┋",
 "┋      KittenOS NEO MUD Terminal       ┋",
 "┖┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┚",
 ":Type text, Enter key sends.",
 ":'>' is 'from you', '<' 'to you'.",
 ":':' is 'internal message'.",
 ":Control-Arrows resizes window.",
-- ":F5/F6 copies/pastes current line.",
 ":",
 ":",
 ":Enter target server:port",
 -- 14
}
--++++++++++++++++++++++++++++++++++++++++

-- sW must not go below 3.
-- sH must not go below 2.
local sW, sH = 40, 15
local inet = neo.requireAccess("c.internet", "internet").list()()
local windows = neo.requireAccess("x.neo.pub.window", "windows")
local window = windows(sW, sH)

local tcp = nil
local dummyTcp = {read = function() return "" end, write = function() end, close = function() end}
local tcpBuf = ""

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

local function submitLine()
 incoming(">" .. l15)
 if not tcp then
  tcp = inet.connect(l15)
  if not tcp then
   incoming(":The connection could not be created.")
   tcp = dummyTcp
  else
   if not tcp.finishConnect() then
    incoming(":Warning: finishConnect = false")
   end
   neo.scheduleTimer(os.uptime() + 0.1)
  end
 else
  -- PRJblackstar doesn't need \r but others might
  tcp.write(l15 .. "\r\n")
 end
 l15 = ""
 line(sH)
end

if lcOverride then
 submitLine()
end

local function clipEnt(tx)
 tx = tx:gsub("\r", "")
 local ci = tx:find("\n") or (#tx + 1)
 tx = tx:sub(1, ci - 1)
 l15 = tx
 line(sH)
end

local control = false
while true do
 local e = {coroutine.yield()}
 if e[1] == "k.timer" then
  while true do
   local b, e = tcp.read(1)
   if not b then
    if e then
     incoming(":Warning: " .. e)
     tcp.close()
     tcp = dummyTcp
    end
    break
   elseif b == "" then
    break
   elseif b ~= "\r" then
    if b == "\n" then
     incoming("<" .. tcpBuf)
     tcpBuf = ""
    else
     tcpBuf = tcpBuf .. b
    end
   end
  end
  neo.scheduleTimer(os.uptime() + 0.1)
 elseif e[1] == "x.neo.pub.window" then
  if e[3] == "close" then
   if tcp then
    tcp.close()
   end
   return
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
