-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-kmt.lua : just a utility now
-- Authors: 20kdc

local inet = neo.requireAccess("c.internet", "internet").list()()

local _, _, termId = ...
local ok = pcall(function ()
 assert(string.sub(termId, 1, 12) == "x.neo.pub.t/")
end)

local termClose

if not ok then
 termId = nil
 assert(neo.executeAsync("svc-t", function (res)
  termId = res.access
  termClose = res.close
  neo.scheduleTimer(0)
 end, "kmt"))
 while true do
  if coroutine.yield() == "k.timer" then break end
 end
end
local term = neo.requireAccess(termId, "terminal")

term.write([[
┎┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┒
┋         ┃ ╱  ┃╲    ╱┃  ▀▀┃▀▀         ┋
┋         ┃╳   ┃ ╲  ╱ ┃    ┃           ┋
┋         ┃ ╲  ┃  ╲╱  ┃    ┃           ┋
┋                                      ┋
┋      KittenOS NEO MUD Terminal       ┋
┖┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┚
export TERM=ansi-generic <- IMPORTANT!!!
Enter target server:port...
]])

local targetBuffer = ""

neo.scheduleTimer(0)
while true do
 local e = {coroutine.yield()}
 if e[1] == "k.timer" then
  while tcp do
   local b, e = tcp.read(neo.readBufSize)
   if not b then
    if e then
     term.write("\nkmt: " .. tostring(e) .. "\n")
     tcp.close()
     tcp = nil
    end
   elseif b == "" then
    break
   else
    term.write(b)
   end
  end
  neo.scheduleTimer(os.uptime() + 0.049)
 elseif e[1] == "k.procdie" then
  if e[3] == term.pid then
   break
  end
 elseif e[1] == termId then
  if targetBuffer and e[2] == "data" then
   targetBuffer = targetBuffer .. e[3]:gsub("\r", "")
   local p = targetBuffer:find("\n")
   if p then
    local ok, res, rer = pcall(inet.connect, targetBuffer:sub(1, p - 1))
    targetBuffer = targetBuffer:sub(p + 1):gsub("\n", "\r\n")
    if not ok then
     -- Likes to return this kind
     term.write("kmt: " .. tostring(res) .. "\n")
    elseif not res then
     -- Could theoretically return this kind
     term.write("kmt: " .. tostring(rer) .. "\n")
    else
     -- Hopefully this kind
     term.write("kmt: Connecting...\n")
     tcp = res
     tcp.write(targetBuffer)
     targetBuffer = nil
    end
   end
  elseif tcp and e[2] == "data" or e[2] == "telnet" then
   tcp.write(e[3])
  end
 end
end

if tcp then
 tcp.close()
end

