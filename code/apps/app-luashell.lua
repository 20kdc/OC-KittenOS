-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

local _, _, termId = ...
local ok = pcall(function ()
 assert(string.sub(termId, 1, 12) == "x.neo.pub.t/")
end)

local termClose

if not ok then
 termId = nil
 neo.executeAsync("svc-t", function (res)
  termId = res.access
  termClose = res.close
  neo.scheduleTimer(0)
 end, "luashell")
 while not termId do
  coroutine.yield()
 end
end
TERM = neo.requireAccess(termId, "terminal")

-- Using event makes it easier for stuff
--  within the shell to not spectacularly explode.
event = require("event")(neo)

local alive = true
event.listen("k.procdie", function (_, _, pid)
 if pid == TERM.pid then
  alive = false
 end
end)

TERM.write("KittenOS NEO Lua Shell\r\n")

print = function (...)
 local n = {}
 local s = {...}
 for i = 1, #s do
  local v = s[i]
  if v == nil then
   v = "nil"
  end
  table.insert(n, tostring(v))
 end
 TERM.write(table.concat(n, " ") .. "\r\n")
end

run = function (x, ...)
 local subPid = neo.executeAsync(x, ...)
 if not subPid then
  subPid = neo.executeAsync("sys-t-" .. x, TERM.id, ...)
 end
 if not subPid then
  subPid = neo.executeAsync("svc-t-" .. x, TERM.id, ...)
 end
 if not subPid then
  subPid = neo.executeAsync("app-" .. x, TERM.id, ...)
 end
 if not subPid then
  error("cannot find " .. x)
 end
 while true do
  local e = {event.pull()}
  if e[1] == "k.procdie" then
   if e[3] == subPid then
    return
   end
  end
 end
end

local ioBuffer = ""

io = {
 read = function ()
  while alive do
   local pos = ioBuffer:find("\n")
   if pos then
    local line = ioBuffer:sub(1, pos):gsub("\r", "")
    ioBuffer = ioBuffer:sub(pos + 1)
    return line
   end
   local e = {event.pull()}
   if e[1] == TERM.id then
    if e[2] == "data" then
     ioBuffer = ioBuffer .. e[3]
    end
   end
  end
 end,
 write = function (s) TERM.write(s) end
}

local originalOS = os
os = setmetatable({}, {
 __index = originalOS
})

os.exit = function ()
 alive = false
end

while alive do
 TERM.write("> ")
 local code = io.read()
 if code then
  local ok, err = pcall(function ()
   if code:sub(1, 1) == "=" then
    code = "return " .. code:sub(2)
   end
   print(assert(load(code))())
  end)
  if not ok then
   TERM.write(tostring(err) .. "\r\n")
  end
 end
end

if termClose then
 termClose()
end

