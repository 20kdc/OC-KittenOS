-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

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
 end, "luashell"))
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

TERM.write([[
    KittenOS NEO Shell Usage Notes

Prefixing = is an alias for 'return '.
io.read(): Reads a line.
print: 'print with table dumping' impl.
TERM: Your terminal. (see us-termi doc.)
os.execute(): launch terminal apps!
tries '*', 'sys-t-*', 'svc-t-*', 'app-*'
 example: os.execute("luashell")
os.exit(): quit the shell
=listCmdApps(): -t- (terminal) apps
event: useful for setting up listeners
 without breaking shell functionality
]])

function listCmdApps()
 local apps = {}
 for _, v in ipairs(neo.listApps()) do
  if v:sub(4, 6) == "-t-" then
   table.insert(apps, v)
  end
 end
 return apps
end

local function vPrint(slike, ...)
 local s = {...}
 if #s > 1 then
  for i = 1, #s do
   if i ~= 1 then TERM.write("\t") end
   vPrint(slike, s[i])
  end
 elseif slike and type(s[1]) == "string" then
  TERM.write("\"" .. s[1] .. "\"")
 elseif type(s[1]) ~= "table" then
  TERM.write(tostring(s[1]))
 else
  TERM.write("{")
  for k, v in pairs(s[1]) do
   TERM.write("[")
   vPrint(true, k)
   TERM.write("] = ")
   vPrint(true, v)
   TERM.write(", ")
  end
  TERM.write("}")
 end
end

print = function (...)
 vPrint(false, ...)
 TERM.write("\r\n")
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

function os.exit()
 alive = false
end

function os.execute(x, ...)
 local subPid = neo.executeAsync(x, TERM.id, ...)
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

