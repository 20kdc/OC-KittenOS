-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- s-icecap : Responsible for x.neo.pub API, crash dialogs, and security policy that isn't "sys- has ALL access, anything else has none"
--            In general, this is what userspace will be interacting with in some way or another to get stuff done

local settings = neo.requireAccess("x.neo.sys.manage", "security sysconf access")

local fs = neo.requireAccess("c.filesystem", "file managers")

local donkonitDFProvider = neo.requireAccess("r.neo.pub.base", "creating basic NEO APIs")

local targsDH = {} -- data disposal

local todo = {}

local onEverest = {}
local everestWindows = {}

local nexus

local function resumeWF(...)
 local ok, e = coroutine.resume(...)
 if not ok then
  e = tostring(e)
  neo.emergency(e)
  nexus.startDialog(e, "ice")
 end
 return ok
end

nexus = {
 createNexusThread = function (f, ...)
  local t = coroutine.create(f)
  if not resumeWF(t, ...) then return end
  local early = neo.requestAccess("x.neo.pub.window")
  if early then
   onEverest[#onEverest] = nil
   resumeWF(t, early)
  end
  return function ()
   for k, v in ipairs(onEverest) do
    if v == t then
     table.remove(onEverest, k)
     return
    end
   end
  end
 end,
 create = function (w, h, t)
  local thr = coroutine.running()
  table.insert(onEverest, thr)
  local everest = coroutine.yield()
  local dw = everest(w, h, title)
  everestWindows[dw.id] = thr
  return dw
 end,
 startDialog = function (tx, ti)
  local fmt = require("fmttext")
  local txl = fmt.fmtText(unicode.safeTextFormat(tx), 40)
  fmt = nil
  nexus.createNexusThread(function ()
   local w = nexus.create(40, #txl, ti)
   while true do
    local ev, a = coroutine.yield()
    if ev == "line" then
     w.span(1, a, txl[a], 0xFFFFFF, 0)
    elseif ev == "close" then
     w.close()
     return
    end
   end
  end)
 end,
 close = function (wnd)
  wnd.close()
  everestWindows[wnd.id] = nil
 end
}

donkonitDFProvider(function (pkg, pid, sendSig)
 local prefixNS = "data/" .. pkg
 local prefixWS = "data/" .. pkg .. "/"
 fs.primary.makeDirectory(prefixNS)
 local openHandles = {}
 targsDH[pid] = function ()
  for k, v in pairs(openHandles) do
   v()
  end
 end
 return {
  showFileDialogAsync = function (forWrite)
   -- Not hooked into the event API, so can't safely interfere
   -- Thus, this is async and uses a return event.
   local tag = {}
   neo.scheduleTimer(0)
   table.insert(todo, function ()
    -- sys-filedialog is yet another "library to control memory usage".
    local closer = require("sys-filedialog")(event, nexus, function (res) openHandles[tag] = nil sendSig("filedialog", tag, res) end, fs, pkg, forWrite)
    openHandles[tag] = closer
   end)
   return tag
  end,
  -- Paths must begin with / implicitly
  list = function (path)
   if type(path) ~= "string" then error("Expected path to be string") end
   path = prefixNS .. path
   neo.ensurePath(path, prefixWS)
   if path:sub(#path, #path) ~= "/" then error("Expected / at end") end
   return fs.primary.list(path:sub(1, #path - 1))
  end,
  makeDirectory = function (path)
   if type(path) ~= "string" then error("Expected path to be string") end
   path = prefixNS .. path
   neo.ensurePath(path, prefixWS)
   if path:sub(#path, #path) == "/" then error("Expected no / at end") end
   return fs.primary.makeDirectory(path)
  end,
  rename = function (path1, path2)
   if type(path1) ~= "string" then error("Expected path to be string") end
   if type(path2) ~= "string" then error("Expected path to be string") end
   path1 = prefixNS .. path1
   path2 = prefixNS .. path2
   neo.ensurePath(path1, prefixWS)
   neo.ensurePath(path2, prefixWS)
   if path:sub(#path1, #path1) == "/" then error("Expected no / at end") end
   if path:sub(#path2, #path2) == "/" then error("Expected no / at end") end
   return fs.primary.rename(path1, path2)
  end,
  open = function (path, mode)
   if type(path) ~= "string" then error("Expected path to be string") end
   if type(mode) ~= "boolean" then error("Expected mode to be boolean (writing)") end
   path = prefixNS .. path
   neo.ensurePath(path, prefixWS)
   if path:sub(#path, #path) == "/" then error("Expected no / at end") end
   local fw, closer = require("sys-filewrap")(fs.primary, path, mode)
   local oc = fw.close
   fw.close = function ()
    oc()
    openHandles[fw] = nil
   end
   openHandles[fw] = closer
   return fw
  end,
  remove = function (path)
   if type(path) ~= "string" then error("Expected path to be string") end
   path = prefixNS .. path
   neo.ensurePath(path, prefixWS)
   if path:sub(#path, #path) == "/" then error("Expected no / at end") end
   return fs.primary.remove(path)
  end,
  stat = function (path)
   if type(path) ~= "string" then error("Expected path to be string") end
   path = prefixNS .. path
   neo.ensurePath(path, prefixWS)
   if path:sub(#path, #path) == "/" then error("Expected no / at end") end
   if not fs.primary.exists(path) then return nil end
   return {
    fs.primary.isDirectory(path),
    fs.primary.size(path),
    fs.primary.lastModified(path)
   }
  end,
  -- getLabel/setLabel have nothing to do with this
  spaceUsed = fs.primary.spaceUsed,
  spaceTotal = fs.primary.spaceTotal,
  isReadOnly = fs.primary.isReadOnly
 }
end)

-- Connect in security policy now
local rootAccess = neo.requireAccess("k.root", "installing GUI integration")
local backup = rootAccess.securityPolicyINIT or rootAccess.securityPolicy
rootAccess.securityPolicyINIT = backup
rootAccess.securityPolicy = function (pid, proc, perm, req)
 if neo.dead then
  return backup(pid, proc, perm, req)
 end
 local def = proc.pkg:sub(1, 4) == "sys-"
 local secpol, err = require("sys-secpolicy")
 if not secpol then
  -- Failsafe.
  neo.emergency("Used fallback policy because of load-err: " .. err)
  req(def)
  return
 end
 -- Push to ICECAP thread to avoid deadlock b/c wrong event-pull context
 neo.scheduleTimer(0)
 table.insert(todo, function ()
  local ok, err = pcall(secpol, nexus, settings, proc.pkg, pid, perm, req)
  if not ok then
   neo.emergency("Used fallback policy because of run-err: " .. err)
   req(def)
  end
 end)
end

while true do
 local ev = {coroutine.yield()}
 if ev[1] == "k.procdie" then
  local _, pkg, pid, reason = table.unpack(ev)
  if targsDH[pid] then
   targsDH[pid]()
  end
  targsDH[pid] = nil
  if reason then
   nexus.startDialog(string.format("%s/%i died:\n%s", pkg, pid, reason), "error")
  end
 elseif ev[1] == "k.timer" then
  local nt = todo
  todo = {}
  for _, v in ipairs(nt) do
   local ok, e = pcall(v)
   if not ok then
    nexus.startDialog(tostring(e), "terr")
   end
  end
 elseif ev[1] == "k.registration" then
  if ev[2] == "x.neo.pub.window" then
   local nt = onEverest
   onEverest = {}
   for _, v in ipairs(nt) do
    coroutine.resume(v, neo.requestAccess("x.neo.pub.window"))
   end
  end
 elseif ev[1] == "x.neo.pub.window" then
  local v = everestWindows[ev[2]]
  if v then
   resumeWF(v, table.unpack(ev, 3))
   if coroutine.status(v) == "dead" then
    everestWindows[ev[2]] = nil
   end
  end
 end
end
