-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- s-icecap : Responsible for x.neo.pub API, crash dialogs, and security policy that isn't "sys- has ALL access, anything else has none"
--            In general, this is what userspace will be interacting with in some way or another to get stuff done

local rootAccess = neo.requireAccess("k.root", "installing GUI integration")
local settings = neo.requireAccess("x.neo.sys.manage", "security sysconf access")
local donkonitDFProvider = neo.requireAccess("r.neo.pub.base", "creating basic NEO APIs")

local targsDH = {} -- data disposal

local todo = {}

-- Specific registration callbacks
local onReg = {}
local everestWindows = {}

local nexus

local theEventHandler

local function addOnReg(p, f)
 onReg[p] = onReg[p] or {}
 table.insert(onReg[p], f)
end

nexus = {
 create = function (w, h, t, c)
  local function cb()
   local e = neo.requestAccess("x.neo.pub.window", theEventHandler)
   if e then
    if onReg["x.neo.pub.window"] then
     neo.emergency("icecap nexus prereg issue")
     theEventHandler("k.registration", "x.neo.pub.window")
    end
    local dwo, dw = pcall(e, w, h, t)
    if not dwo then
     addOnReg("x.neo.pub.window", cb)
     return
    end
    c(dw)
    everestWindows[dw.id] = function (...)
     return c(dw, ...)
    end
   else
    addOnReg("x.neo.pub.window", cb)
   end
  end
  cb()
 end,
 windows = everestWindows,
 startDialog = function (tx, ti)
  local txl = require("fmttext").fmtText(unicode.safeTextFormat(tx), 40)
  nexus.create(40, #txl, ti, function (w, ev, a)
   if ev == "line" then
    if not pcall(w.span, 1, a, txl[a], 0xFFFFFF, 0) then
     everestWindows[w.id] = nil
    end
   elseif ev == "close" then
    w.close()
    everestWindows[w.id] = nil
   end
  end)
 end
}

local function getPfx(xd, pkg)
 -- This is to ensure the prefix naming scheme is FOLLOWED!
 -- sys- : System, part of KittenOS NEO and thus tries to present a "unified fragmented interface" in 'neo'
 -- app- : Application - these can have ad-hoc relationships. It is EXPECTED these have a GUI
 -- svc- : Service - Same as Application but with no expectation of desktop usability
 -- Libraries "have no rights" as they are essentially loadable blobs of Lua code.
 -- They have access via the calling program, and have a subset of the NEO Kernel API
  -- Apps can register with their own name, w/ details
 local pfx = nil
 if pkg:sub(1, 4) == "app-" then pfx = "app" end
 if pkg:sub(1, 4) == "svc-" then pfx = "svc" end
 if pfx then
  return xd .. pfx .. "." .. pkg:sub(5)
 end
end

local function splitAC(ac)
 local sb = ac:match("/[a-z0-9/%.]*$")
 if sb then
  return ac:sub(1, #ac - #sb), sb
 end
 return ac
end

donkonitDFProvider(function (pkg, pid, sendSig)
 local prefixNS = "data/" .. pkg
 local prefixWS = prefixNS .. "/"
 local fs = rootAccess.primaryDisk
 fs.makeDirectory(prefixNS)
 local openHandles = {}
 targsDH[pid] = function ()
  for k, v in pairs(openHandles) do
   v()
  end
 end
 return {
  showFileDialogAsync = function (forWrite, defName)
   if not rawequal(forWrite, nil) then
    require("sys-filewrap").ensureMode(forWrite)
   end
   if not rawequal(defName, nil) then
    defName = tostring(defName)
   end
   -- Not hooked into the event API, so can't safely interfere
   -- Thus, this is async and uses a return event.
   local tag = {}
   neo.scheduleTimer(0)
   table.insert(todo, function ()
    -- sys-filedialog is yet another "library to control memory usage".
    local closer = require("sys-filedialog")(event, nexus, function (res) openHandles[tag] = nil sendSig("filedialog", tag, res) end, neo.requireAccess("c.filesystem", "file managers"), pkg, forWrite, defName)
    openHandles[tag] = closer
   end)
   return tag
  end,
  myApi = getPfx("", pkg),
  lockPerm = function (perm)
   -- Are we allowed to?
   local permPfx, detail = splitAC(perm)
   if getPfx("x.", pkg) ~= permPfx then
    return false, "You don't own this permission."
   end
   local set = "perm|*|" .. perm
   if settings.getSetting(set) then
    -- Silently ignored, to stop apps trying to sense this & be annoying.
    -- The user is allowed to choose.
    -- You are only allowed to suggest.
    return true
   end
   settings.setSetting(set, "ask")
   return true
  end,
  -- Paths must begin with / implicitly
  list = function (path)
   neo.ensureType(path, "string")
   path = prefixNS .. path
   neo.ensurePath(path, prefixWS)
   if path:sub(#path, #path) ~= "/" then error("Expected / at end") end
   return fs.list(path:sub(1, #path - 1))
  end,
  makeDirectory = function (path)
   neo.ensureType(path, "string")
   path = prefixNS .. path
   neo.ensurePath(path, prefixWS)
   if path:sub(#path, #path) == "/" then error("Expected no / at end") end
   return fs.makeDirectory(path)
  end,
  rename = function (path1, path2)
   neo.ensureType(path1, "string")
   neo.ensureType(path2, "string")
   path1 = prefixNS .. path1
   path2 = prefixNS .. path2
   neo.ensurePath(path1, prefixWS)
   neo.ensurePath(path2, prefixWS)
   if path:sub(#path1, #path1) == "/" then error("Expected no / at end") end
   if path:sub(#path2, #path2) == "/" then error("Expected no / at end") end
   return fs.rename(path1, path2)
  end,
  open = function (path, mode)
   neo.ensureType(path, "string")
   -- mode verified by filewrap
   path = prefixNS .. path
   neo.ensurePath(path, prefixWS)
   if path:sub(#path, #path) == "/" then error("Expected no / at end") end
   local fw, closer = require("sys-filewrap").create(fs, path, mode)
   if not fw then return nil, closer end
   local oc = fw.close
   fw.close = function ()
    oc()
    openHandles[fw] = nil
   end
   openHandles[fw] = closer
   return fw
  end,
  remove = function (path)
   neo.ensureType(path, "string")
   path = prefixNS .. path
   neo.ensurePath(path, prefixWS)
   if path:sub(#path, #path) == "/" then error("Expected no / at end") end
   return fs.remove(path)
  end,
  stat = function (path)
   neo.ensureType(path, "string")
   path = prefixNS .. path
   neo.ensurePath(path, prefixWS)
   if path:sub(#path, #path) == "/" then error("Expected no / at end") end
   if not fs.exists(path) then return nil end
   return {
    fs.isDirectory(path),
    fs.size(path),
    fs.lastModified(path)
   }
  end,
  -- getLabel/setLabel have nothing to do with this
  spaceUsed = fs.spaceUsed,
  spaceTotal = fs.spaceTotal,
  isReadOnly = fs.isReadOnly
 }
end)

local function secPolicyStage2(pid, proc, perm, req)
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
  local fPerm = perm
  if fPerm:sub(1, 2) == "r." then
   fPerm = splitAC(fPerm)
  end
  local ok, err = pcall(secpol, nexus, settings, proc.pkg, pid, fPerm, req, getPfx("", proc.pkg))
  if not ok then
   neo.emergency("Used fallback policy because of run-err: " .. err)
   req(def)
  end
 end)
end

-- Connect in security policy now
local backup = rootAccess.securityPolicyINIT or rootAccess.securityPolicy
rootAccess.securityPolicyINIT = backup
rootAccess.securityPolicy = function (pid, proc, perm, req)
 if neo.dead then
  return backup(pid, proc, perm, req)
 end
 local function finish()
  secPolicyStage2(pid, proc, perm, req)
 end
 -- Do we need to start it?
 if perm:sub(1, 6) == "x.svc." and not neo.usAccessExists(perm) then
  local appAct = splitAC(perm:sub(7))
  -- Prepare for success
  onReg[perm] = onReg[perm] or {}
  local orp = onReg[perm]
  local function kme()
   if finish then
    finish()
    finish = nil
   end
  end
  table.insert(orp, kme)
  pcall(neo.executeAsync, "svc-" .. appAct)
  -- Fallback "quit now"
  local time = os.uptime() + 30
  neo.scheduleTimer(time)
  local f
  function f()
   if finish then
    if os.uptime() >= time then
     -- we've given up
     if onReg[perm] == orp then
      for k, v in ipairs(orp) do
       if v == kme then
        table.remove(orp, k)()
        break
       end
      end
     end
    else
     table.insert(todo, f)
    end
   end
  end
  table.insert(todo, f)
  return
 else
  finish()
 end
end

local function dcall(c, ...)
 local ok, e = pcall(...)
 if not ok then
  nexus.startDialog(tostring(e), c .. "err")
 end
end
function theEventHandler(...)
 local ev = {...}
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
   dcall("t", v)
  end
 elseif ev[1] == "k.registration" then
  if onReg[ev[2]] then
   local tmp = onReg[ev[2]]
   onReg[ev[2]] = nil
   for _, v in ipairs(tmp) do
    dcall("r", v)
   end
  end
 elseif ev[1] == "x.neo.pub.window" then
  local v = everestWindows[ev[2]]
  if v then
   dcall("w", v, table.unpack(ev, 3))
  end
 end
end

while true do
 theEventHandler(coroutine.yield())
end
