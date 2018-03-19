-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- s-icecap : Responsible for x.neo.pub API, crash dialogs, and security policy that isn't "sys- has ALL access, anything else has none"
--            In general, this is what userspace will be interacting with in some way or another to get stuff done

local event = require("event")(neo)
local neoux, err = require("neoux")
if not neoux then error(err) end -- This app is basically neoux's testcase
neoux = neoux(event, neo)

local settings = neo.requireAccess("x.neo.sys.manage", "security sysconf access")

local fs = neo.requireAccess("c.filesystem", "file managers")

local donkonitDFProvider = neo.requireAccess("r.neo.pub.base", "creating basic NEO APIs")

local targsDH = {} -- data disposal

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
   event.runAt(0, function ()
    -- sys-filedialog is yet another "library to control memory usage".
    local closer = require("sys-filedialog")(event, neoux, function (res) openHandles[tag] = nil sendSig("filedialog", tag, res) end, fs, pkg, forWrite)
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
rootAccess.securityPolicy = function (pid, proc, req)
 if neo.dead then
  return backup(pid, proc, req)
 end
 req.result = proc.pkg:sub(1, 4) == "sys-"
 local secpol, err = require("sys-secpolicy")
 if not secpol then
  -- Failsafe.
  neo.emergency("Used fallback policy because of load-err: " .. err)
  req.service()
  return
 end
 -- Push to ICECAP thread to avoid deadlock on neoux b/c wrong event-pull context
 event.runAt(0, function ()
  local ok, err = pcall(secpol, neoux, settings, proc.pkg, pid, req.perm, function (r)
   req.result = r
   req.service()
  end)
  if not ok then
   neo.emergency("Used fallback policy because of run-err: " .. err)
   req.service()
  end
 end)
end

event.listen("k.procdie", function (evt, pkg, pid, reason)
 if targsDH[pid] then
  targsDH[pid]()
 end
 targsDH[pid] = nil
 if reason then
  -- Process death logging in console (for lifecycle dbg)
  -- neo.emergency(n[2])
  -- neo.emergency(n[4])
  neoux.startDialog(string.format("%s/%i died:\n%s", pkg, pid, reason), "error")
 end
end)

while true do
 event.pull()
end
