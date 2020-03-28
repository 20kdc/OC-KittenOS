-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

local _, _, termId = ...
local ok = pcall(function ()
 assert(string.sub(termId, 1, 8) == "x.svc.t/")
end)
if not ok then
 termId = nil
 neo.executeAsync("svc-t", function (res)
  termId = res.access
  neo.scheduleTimer(0)
 end, "luashell")
 while not termId do
  coroutine.yield()
 end
end
TERM = neo.requireAccess(termId, "terminal")

TERM.line("KittenOS NEO Lua Shell")

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
 TERM.line(table.concat(n, " "))
end

local alive = true

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
  local e = {coroutine.yield()}
  if e[1] == "k.procdie" then
   if e[3] == TERM.pid then
    alive = false
    return
   elseif e[3] == subPid then
    return
   end
  end
 end
end

exit = function ()
 alive = false
end

while alive do
 local e = {coroutine.yield()}
 if e[1] == "k.procdie" then
  if e[3] == TERM.pid then
   alive = false
  end
 elseif e[1] == TERM.id then
  if e[2] == "line" then
   TERM.line("> " .. e[3])
   local ok, err = pcall(function ()
    if e[3]:sub(1, 1) == "=" then
     e[3] = "return " .. e[3]:sub(2)
    end
    print(assert(load(e[3]))())
   end)
   if not ok then
    TERM.line(tostring(err))
   end
  end
 end
end