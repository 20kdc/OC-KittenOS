-- OmniTerm: multi-driver terminal
-- Has RPC (lets apps use OmniTerm as a helper. Protocol commands are "msg", "join".),
--     Echo (test),
-- 

local table, unicode, math, proc, lang = A.request("table", "unicode", "math", "proc", "lang")

local app = {}
local termWidth = 25
-- console buffer cannot scroll left/right
local consoleBuffer = lang.getTable()
if not consoleBuffer then
 consoleBuffer = {
 --1234512345123451234512345
  "OmniTerm Interfaces:",
  "rpc:<appId>  |RPC",
  "tun:<CA>     |Linked Card",
  "net:<RA>:<pt>|Net.Card",
 --Broadcast (hopefully obvious?)
  "net:<pt>     |Net.Card-BC",
 --Allows talking with MineOS Chat... in theory...
  "moschat:<RA> |MineOS Chat",
  "componentlist|Components.",
  "lua          |Lua console",
  "Exit with Ctrl-W."
 }
end

local prevLine = ""
local lineBuffer = ""
local function incomingSubLine(txt)
 for i = 1, #consoleBuffer - 1 do
  consoleBuffer[i] = consoleBuffer[i + 1]
 end
 consoleBuffer[#consoleBuffer] = txt
end
local function incomingLine(txt)
 txt = unicode.safeTextFormat(txt)
 -- Note: >2 wide characters can *stay away*. Well away.
 -- The result will always leave a 1-char gap at the end of a line,
 -- which suffices to allow wide characters to work properly.
 while unicode.len(txt) > termWidth do
  incomingSubLine(unicode.sub(txt, 1, termWidth - 1))
  txt = " " .. unicode.sub(txt, termWidth)
 end
 incomingSubLine(txt)
end
local function outgoingLine(txt)
end
local function driverShutdown()
end
-- Driver utils
local function parseAddrPort(id)
 if id:match("[a-f0-9%-]+:[0-9]+") ~= id then
  error("Bad Syntax (<proto>:<hw-addr>:<port>)")
 end
 local addr = id:match("[a-f0-9%-]+")
 local port = tonumber(id:match(":[0-9]+"):sub(2))
 return addr, port
end
local drivers = {
 -- rpc:appID
 rpc = function (id)
  proc.sendRPC(id, "join")
  app.rpc = function (srcP, srcD, cmd, txt)
   if srcD == id then
    if cmd == "msg" then
     incomingLine(tostring(txt))
     A.timer(0.01)
    end
   end
  end
  outgoingLine = function (txt)
   proc.sendRPC(id, "msg", txt)
  end
 end,
 -- tun:<addr>
 tun = function (id)
  local cT = A.request("c.tunnel")
  local tunnel = nil
  if id ~= "" then
   for v in cT.list() do
    if v.address:sub(1, id:len()) == id then tunnel = v end
   end
  end
  if not tunnel then error("Couldn't find that tunnel.") end
  app.event = function (...)
   local ev = {...}
   if ev[1] == "modem_message" then
    if ev[2] == tunnel.address then
     incomingLine(tostring(ev[6]))
     return true
    end
   end
  end
  outgoingLine = function (txt)
   tunnel.send(txt)
  end
 end,
 -- net:targetAddr:port
 -- Uses all modems to send to a target. (Tunnels do not count.)
 net = function (id)
  local addr = nil
  local port = tonumber(id)
  if not port then
   addr, port = parseAddrPort(id)
  end
  local cM = A.request("c.modem")
  for v in cM.list() do
   v.open(port)
   if v.isWireless() then
    -- Probably not the best, but it'll do until a proper strength controller is written.
    -- I don't know if it's set to full strength by default, and that's critical!
    v.setStrength(400)
   end
  end
  app.event = function (...)
   local a = {...}
   if a[1] == "modem_message" then
    if (a[3] == addr) or (not addr) then
     if a[4] == port then
      incomingLine(tostring(a[6]))
     end
    end
   end
   return true
  end
  outgoingLine = function (txt)
   for v in cM.list() do
    if addr then
     v.send(addr, port, txt)
    else
     v.broadcast(port, txt)
    end
   end
  end
 end,
 -- moschat:<address>
 -- Allows basic communication with MineOS Chat systems, in theory.
 -- In practice? This is untested against real MineOS.
 moschat = function (id)
  local port = 899 -- MOSChat port
  local cM = A.request("c.modem")
  for v in cM.list() do
   v.open(port)
  end
  app.event = function (...)
   local a = {...}
   if a[1] == "modem_message" then
    if a[3] == id then
     if a[4] == port then
      if a[6] == "HereIsMessageToYou" then
       incomingLine(tostring(a[8]))
      end
     end
    end
   end
   return true
  end
  outgoingLine = function (txt)
   for v in cM.list() do
    v.send(id, port, "HereIsMessageToYou", nil, txt)
   end
  end
 end,
 -- echo:postfix
 -- Echoes back any line sent, plus a postfix.
 echo = function (id)
  outgoingLine = function (txt)
   incomingLine(txt .. id)
  end
 end,
 -- componentlist
 -- Used to list components
 -- Useful because OpenComputers cuts off text,
 --  which is really bad when you need the *whole* ID...
 --  >.< like when doing anything involving networking.
 componentlist = function (id)
  local stat = A.request("stat")
  outgoingLine = function (txt)
   incomingLine("Components [" .. txt .. "]:")
   for ad, tp in stat.componentList() do
    if tp == txt then
     incomingLine(ad)
    end
   end
  end
 end,
 lua = function (id)
  local root = A.request("root")
  incomingLine("Lua Console")
  outgoingLine = function (txt)
   local r, re = pcall(function ()
    local f, fe = load(txt, nil, root)
    if not f then error(fe) end
    return f()
   end)
   incomingLine(tostring(re))
  end
 end
}
local hasDriver = false
local function typedLine(txt)
 if not hasDriver then
  -- Initialize driver
  local dname = txt:match("^[^:]+")
  if not dname then
   incomingLine("You must specify what to connect to.")
   return
  end
  if not drivers[dname] then
   incomingLine("No such driver '" .. dname .. "'")
   return
  end
  txt = txt:sub(dname:len() + 2)
  incomingLine("Connecting with driver '" .. dname .. "'")
  local ok, err = pcall(drivers[dname], txt)
  if not ok then
   incomingLine("Error: " .. err)
  else
   local a = ""
   for i = 1, termWidth do a = a .. "-" end
   incomingLine(a)
   hasDriver = true
  end
 else
  incomingLine(txt)
  outgoingLine(txt)
 end
end

-- triggered by drivers that can't directly cause redraws
function app.update()
 return true
end

function app.get_ch(x, y)
 local l, lp = consoleBuffer[y], 0
 if y == #consoleBuffer + 1 then
  lp = unicode.len(lineBuffer) - math.floor(termWidth / 2)
  if lp < 1 then lp = 1 end
  l, lp = unicode.safeTextFormat(lineBuffer, lp)
  lp = lp - 1
 end
 return unicode.sub(l, x + lp, x + lp)
end

local ctrlFlag = false
function app.key(ka, kc, down)
 if kc == 29 then
  ctrlFlag = down
  return false
 end
 if ctrlFlag then
  if down then
   if kc == 17 then -- W
    driverShutdown()
    A.die()
   end
  end
  return false
 end
 if down then
  if kc == 200 then
   lineBuffer = prevLine
   return true
  end
  if ka ~= 0 then
   if ka == 13 then
    prevLine = lineBuffer
    typedLine(lineBuffer)
    lineBuffer = ""
    return true
   else
    if ka == 8 then
     lineBuffer = unicode.sub(lineBuffer, 1, unicode.len(lineBuffer) - 1)
     return true
    else
     lineBuffer = lineBuffer .. unicode.char(ka)
     return true
    end
   end
  end
 end
end

return app, termWidth, #consoleBuffer + 1