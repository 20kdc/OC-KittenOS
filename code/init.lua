-- KittenOS N.E.O Kernel: "Tell Mettaton I said hi."
-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- NOTE: local is considered unnecessary in kernel since 21 March

-- In case of OpenComputers configuration abnormality
readBufSize = 2048

-- A function used for logging, usable by programs.
emergencyFunction = function (...)
 computer.pushSignal("_kosneo_syslog", "kernel", ...)
 if ocemu and ocemu.log then
  pcall(ocemu.log, ...)
 end
end
-- Comment this out if you don't want programs to have
--  access to ocemu's logger.
ocemu = (component.list("ocemu", true)()) or (component.list("sandbox", true)())
if ocemu then
 ocemu = component.proxy(ocemu)
end

-- It is a really bad idea to remove this.
-- If the code inside this block even executes, then removing it is a security risk.
if load(string.dump(function()end)) then
 emergencyFunction("detected bytecode access, preventing (only remove this block if you trust every app ever on your KittenOS NEO system)")
 local oldLoad = load
 load = function (c, n, m, ...)
  return oldLoad(c, n, "t", ...)
 end
end

primaryDisk = component.proxy(computer.getBootAddress())

-- {{time, func, arg1...}...}
timers = {}

libraries = {}
setmetatable(libraries, {__mode = "v"})

-- proc.co = coroutine.create(appfunc)
-- proc.pkg = "pkg"
-- proc.access = {["perm"] = true, ...}
-- proc.denied = {["perm"] = true, ...}
-- proc.deathCBs = {function(), ...}
-- very slightly adjusted total CPU time
-- proc.cpuUsage
processes = {}
-- Maps registration-accesses to function(pkg, pid)
accesses = {}
lastPID = 0

-- Kernel global "idle time" counter, useful for accurate performance data
idleTime = 0

-- This function is critical to wide text support.
function unicode.safeTextFormat(s, ptr)
 local res = ""
 if not ptr then ptr = 1 end
 local aptr = 1
 for i = 1, unicode.len(s) do
  local ch = unicode.sub(s, i, i)
  local ex = unicode.charWidth(ch)
  if i < ptr then
   aptr = aptr + ex
  end
  for j = 2, ex do
   ch = ch .. " "
  end
  res = res .. ch
 end
 return res, aptr
end

-- The issue with the above function, of course, is that in practice the GPU is a weird mess.
-- So this undoes the above transformation for feeding to gpu.set.
-- (In practice if safeTextFormat supports RTL, and that's a big "if", then this will not undo that.
--  The point is that this converts it into gpu.set format.)
function unicode.undoSafeTextFormat(s)
 local res = ""
 local ignoreNext = false
 for i = 1, unicode.len(s) do
  if not ignoreNext then
   local ch = unicode.sub(s, i, i)
   if unicode.charWidth(ch) ~= 1 then
    if unicode.sub(s, i + 1, i + 1) ~= " " then
     ch = " "
    else
     ignoreNext = true
    end
   end
   res = res .. ch
  else
   ignoreNext = false
  end
 end
 return res
end

function loadfile(s, e)
 local h, er = primaryDisk.open(s)
 if h then
  local ch = ""
  local c = primaryDisk.read(h, readBufSize)
  while c do
   ch = ch .. c
   c = primaryDisk.read(h, readBufSize)
  end
  primaryDisk.close(h)
  return load(ch, "=" .. s, "t", e)
 end
 return nil, tostring(er)
end

uniqueNEOProtectionObject = {}

wrapMetaCache = {}
setmetatable(wrapMetaCache, {__mode = "v"})

function wrapMeta(t)
 if type(t) == "table" then
  if wrapMetaCache[t] then
   return wrapMetaCache[t]
  end
  local t2 = {}
  wrapMetaCache[t] = t2
  setmetatable(t2, {
   __index = function (a, k) return wrapMeta(t[k]) end,
   __newindex = error,
   -- WTF
   __call = function (_, ...)
    return t(...)
   end,
   __pairs = function (a)
    return function (x, key)
     local k, v = next(t, k)
     if k then return k, wrapMeta(v) end
    end, 9, nil
   end,
   __ipairs = function (a)
    return function (x, key)
     key = key + 1
     if t[key] then
      return key, wrapMeta(t[key])
     end
    end, 9, 0
   end,
   __metatable = uniqueNEOProtectionObject
   -- Don't protect this table - it'll make things worse
  })
  return t2
 else
  return t
 end
end

function ensureType(a, t)
 if type(a) ~= t then error("Invalid parameter, expected a " .. t) end
 if t == "table" then
  if getmetatable(a) then error("Invalid parameter, has metatable") end
 end
end

function ensurePathComponent(s)
 if not string.match(s, "^[a-zA-Z0-9_%-%+%,%.%#%~%@%'%;%[%]%(%)%&%%%$%! %=%{%}%^]+$") then error("chars disallowed: " .. s) end
 if s == "." then error("single dot disallowed") end
 if s == ".." then error("double dot disallowed") end
end

function ensurePath(s, r)
 string.gsub(s, "[^/]+", ensurePathComponent)
 if s:sub(1, r:len()) ~= r then error("base disallowed") end
 if s:match("//") then error("// disallowed") end
end

-- Use with extreme care.
-- (A process killing itself will actually survive until the next yield... before any of the death events have run.)
function termProc(pid, reason)
 if processes[pid] then
  -- Immediately prepare for GC, it's possible this is out of memory.
  -- If out of memory, then to reduce risk of memory leak by error, memory needs to be freed ASAP.
  -- Start by getting rid of all process data.
  local dcbs = processes[pid].deathCBs
  local pkg = processes[pid].pkg
  local usage = processes[pid].cpuUsage
  processes[pid] = nil
  -- This gets rid of a few more bits of data.
  for _, v in ipairs(dcbs) do
   v()
  end
  -- This finishes off that.
  dcbs = nil
  if reason then
   emergencyFunction("d1 " .. pkg .. "/" .. pid)
   emergencyFunction("d2 " .. reason)
  end
  -- And this is why it's important, because this generates timers.
  -- The important targets of these timers will delete even more data.
  distEvent(nil, "k.procdie", pkg, pid, reason, usage)
 end
end

function execEvent(k, ...)
 if processes[k] then
  local v = processes[k]
  local timerA = computer.uptime()
  local r, reason = coroutine.resume(v.co, ...)
  -- Mostly reliable accounting
  v.cpuUsage = v.cpuUsage + (computer.uptime() - timerA)
  reason = ((not r) and tostring(reason)) or nil
  local dead = (not not reason) or coroutine.status(v.co) == "dead"
  if dead then
   termProc(k, reason)
   return not not reason
  end
 end
end

function distEvent(pid, s, ...)
 local ev = {...}
 if pid then
  local v = processes[pid]
  if not v then
   return
  end
  if not (s:sub(1, 2) == "k." or v.access["s." .. s] or v.access["k.root"]) then
   return
  end
  -- Schedule the timer to carry the event.
  table.insert(timers, {0, execEvent, pid, s, table.unpack(ev)})
 else
  for k, v in pairs(processes) do
   distEvent(k, s, ...)
  end 
 end
end

function lister(pfx)
 return function ()
  local n = primaryDisk.list(pfx)
  local n2 = {}
  for k, v in ipairs(n) do
   if v:sub(#v - 3) == ".lua" then
    table.insert(n2, v:sub(1, #v - 4))
   end
  end
  return n2
 end
end

function loadLibraryInner(library)
 ensureType(library, "string")
 library = "libs/" .. library .. ".lua"
 ensurePath(library, "libs/")
 if libraries[library] then return libraries[library] end
 emergencyFunction("loading " .. library)
 local l, r = loadfile(library, baseProcEnv())
 if l then
  local ok, al = pcall(l)
  if ok then
   al = wrapMeta(al)
   libraries[library] = al
   return al
  else
   return nil, al
  end
 end
 return nil, r
end

wrapMath = wrapMeta(math)
wrapTable = wrapMeta(table)
wrapString = wrapMeta(string)
wrapUnicode = wrapMeta(unicode)
wrapCoroutine = wrapMeta(coroutine)
-- inject stuff into os
os.totalMemory = computer.totalMemory
os.freeMemory = computer.freeMemory
os.energy = computer.energy
os.maxEnergy = computer.maxEnergy
os.uptime = computer.uptime
os.address = computer.address
wrapOs = wrapMeta(os)
wrapDebug = wrapMeta(debug)
wrapBit32 = wrapMeta(bit32)
wrapUtf8 = wrapMeta(utf8)

baseProcEnvCore = {
 _VERSION = _VERSION,
 math = wrapMath,
 table = wrapTable,
 string = wrapString,
 unicode = wrapUnicode,
 coroutine = wrapCoroutine,
 os = wrapOs,
 debug = wrapDebug,
 bit32 = wrapBit32,
 utf8 = wrapUtf8,
 require = loadLibraryInner,
 assert = assert,     ipairs = ipairs,
 load = load,
 next = function (t, k)
  local mt = getmetatable(t)
  if mt == uniqueNEOProtectionObject then error("NEO-Protected Object") end
  return next(t, k)
 end,
 pairs = pairs,       pcall = pcall,
 xpcall = xpcall,     select = select,
 type = type,         error = error,
 tonumber = tonumber, tostring = tostring,
 setmetatable = setmetatable, getmetatable = function (n)
  local mt = getmetatable(n)
  if mt == uniqueNEOProtectionObject then return "NEO-Protected Object" end
  return mt
 end,
 rawset = function (t, i, v)
  local mt = getmetatable(t)
  if mt == uniqueNEOProtectionObject then error("NEO-Protected Object") end
  return rawset(t, i, v)
 end, rawget = rawget, rawlen = rawlen, rawequal = rawequal,
}
baseProcNeo = {
 emergency = emergencyFunction,
 readBufSize = readBufSize,
 wrapMeta = wrapMeta,
 listProcs = function ()
  local n = {}
  for k, v in pairs(processes) do
   table.insert(n, {k, v.pkg, v.cpuUsage})
  end
  return n
 end,
 listApps = lister("apps/"),
 listLibs = lister("libs/"),
 usAccessExists = function (accessName)
  ensureType(accessName, "string")
  return not not accesses[accessName]
 end,
 totalIdleTime = function () return idleTime end,
 ensurePath = ensurePath,
 ensurePathComponent = ensurePathComponent,
 ensureType = ensureType
}

baseProcEnvMT = {
 __index = baseProcEnvCore,
 __metatable = uniqueNEOProtectionObject
}
baseProcNeoMT = {
 __index = baseProcNeo,
 __metatable = uniqueNEOProtectionObject
}

function baseProcEnv()
 local pe = setmetatable({}, baseProcEnvMT)
 pe.neo = setmetatable({}, baseProcNeoMT)
 pe._G = pe
 pe._ENV = pe
 return pe
end

-- These two are hooks for k.root level applications to change policy.
-- Only a k.root application is allowed to do this for obvious reasons.
function securityPolicy(pid, proc, perm, req)
 -- Important safety measure : only sys-* gets anything at first
 req(proc.pkg:sub(1, 4) == "sys-")
end
function runProgramPolicy(ipkg, pkg, pid, ...)
 -- VERY specific injunction here:
 -- non "sys-" apps NEVER start "sys-" apps
 -- This is part of the "default security policy" below:
 -- sys- has all access
 -- anything else has none
 if ipkg:sub(1, 4) == "sys-" then
  if pkg:sub(1, 4) ~= "sys-" then
   return nil, "non-sys app trying to start sys app"
  end
 end
 return true
end

function retrieveAccess(perm, pkg, pid)
 -- Return the access lib and the death callback.

 -- Access categories are sorted into:
 -- "c.<hw>":    Component
 -- "s.<event>": Signal receiver (with responsibilities for Security Request watchers)
 -- "s.k.<...>": Kernel stuff
 -- "s.k.procnew" : New process (pkg, pid, ppkg, ppid)
 -- "s.k.procdie" : Process dead (pkg, pid, reason, usage)
 -- "s.k.registration" : Registration of service alert ("x." .. etc)
 -- "s.k.deregistration" : Registration of service alert ("x." .. etc)
 -- "s.k.securityresponse" : Response from security policy (accessId, accessObj)
 -- "s.h.<...>": Incoming HW messages
 -- "s.x.<endpoint>": This access is actually useless on it's own - it is given by x.<endpoint>

 -- "k.<x>":     Kernel
 -- "k.root":    _ENV (holy grail), and indirectly security request control (which is basically equivalent to this)
 -- "k.computer":   computer

 -- "r.<endpoint>": Registration Of Service...
 -- "x.<endpoint>": Access Of Service (handled by r. & accesses table)
 if accesses[perm] then
  return accesses[perm](pkg, pid)
 end

 if perm == "k.root" then
  return _ENV
 end
 if perm == "k.computer" then
  return wrapMeta(computer)
 end
 if perm == "k.kill" then
  return function(npid)
   ensureType(npid, "number")
   termProc(npid, "Killed by " .. pkg .. "/" .. pid)
  end
 end
 if perm:sub(1, 2) == "s." then
  -- This is more of a "return success". Signal access is determined by the access/denied maps.
  return true
 end
 if perm:sub(1, 2) == "c." then
  -- Allows for simple "Control any of these connected to the system" APIs,
  --  for things the OS shouldn't be poking it's nose in.
  local primary = nil
  local temporary = nil
  local t = perm:sub(3)
  if t == "filesystem" then
   primary = wrapMeta(primaryDisk)
   temporary = wrapMeta(component.proxy(computer.tmpAddress()))
  end
  return {
   list = function ()
    local i = component.list(t, true)
    return function ()
     local ii = i()
     if not ii then return nil end
     return wrapMeta(component.proxy(ii))
    end
   end,
   primary = primary,
   temporary = temporary
  }
 end
 if perm:sub(1, 2) == "r." then
  local uid = "x" .. perm:sub(2)
  local sid = "s.x" .. perm:sub(2)
  if accesses[uid] then return nil end
  accesses[uid] = function (pkg, pid)
   return nil
  end
  return function (f)
   -- Registration function
   ensureType(f, "function")
   local accessObjectCache = {}
   accesses[uid] = function(pkg, pid)
    -- Basically, a per registration per process cache.
    -- This is a consistent yet flexible behavior.
    if accessObjectCache[pid] then
     return accessObjectCache[pid]
    end
    processes[pid].access[sid] = true
    local ok, a = pcall(f, pkg, pid, function (...)
     distEvent(pid, uid, ...)
    end)
    if ok then
     accessObjectCache[pid] = a
     return a, function ()
      accessObjectCache[pid] = nil
     end
    end
    -- returns nil and fails
   end
   -- Announce registration
   distEvent(nil, "k.registration", uid)
  end, function ()
   -- Registration becomes null (access is held but other processes cannot retrieve object)
   if accesses[uid] then
    distEvent(nil, "k.deregistration", uid)
   end
   accesses[uid] = nil
  end
 end
end

function start(pkg, ppkg, ppid, ...)
 local proc = {}
 local pid = lastPID
 lastPID = lastPID + 1

 local function startFromUser(ipkg, ...)
  ensureType(ipkg, "string")
  local ok, n = pcall(ensurePathComponent, ipkg .. ".lua")
  if not ok then return nil, n end
  local k, r = runProgramPolicy(ipkg, pkg, pid, ...)
  if k then
   return start(ipkg, pkg, pid, ...)
  else
   return k, r
  end
 end

 local function osExecuteCore(handler, ...)
  local pid, err = startFromUser(...)
  while pid do
   local sig = {coroutine.yield()}
   handler(table.unpack(sig))
   if sig[1] == "k.procdie" then
    if sig[3] == pid then
     return 0, sig[4]
    end
   end
  end
  return -1, err
 end

 local requestAccessAsync = function (perm)
  ensureType(perm, "string")
  -- Safety-checked, prepare security event.
  local req = function (res)
   if processes[pid] then
    local n = nil
    local n2 = nil
    if res then
     proc.access[perm] = true
     proc.denied[perm] = nil
     n, n2 = retrieveAccess(perm, pkg, pid)
     if n2 then
      table.insert(processes[pid].deathCBs, n2)
     end
    else
     proc.denied[perm] = true
    end
    distEvent(pid, "k.securityresponse", perm, n)
   end
  end
  -- outer security policy:
  if proc.access["k.root"] or proc.access[perm] or proc.denied[perm] then
   -- Use cached result to prevent possible unintentional security service spam
   req(proc.access["k.root"] or not proc.denied[perm])
   return
  end
  -- Denied goes to on to prevent spam
  proc.denied[perm] = true
  securityPolicy(pid, proc, perm, req)
 end
 local env = baseProcEnv()
 env.neo.pid = pid
 env.neo.pkg = pkg
 env.neo.executeAsync = startFromUser
 env.neo.execute = function (...)
  return osExecuteCore(function () end, ...)
 end
 env.neo.executeExt = osExecuteCore
 env.neo.requestAccessAsync = requestAccessAsync
 env.neo.requestAccess = function (perm, handler)
  requestAccessAsync(perm)
  handler = handler or function() end
  while true do
   local n = {coroutine.yield()}
   handler(table.unpack(n))
   if n[1] == "k.securityresponse" then
    -- Security response - if it involves the permission, then take it
    if n[2] == perm then return n[3] end
   end
  end
 end
 env.neo.requireAccess = function (perm, reason)
  -- Allows for hooking
  local res = env.neo.requestAccess(perm)
  if not res then error(pkg .. " needed " .. perm .. " for " .. (reason or "some reason")) end
  return res
 end
 env.neo.scheduleTimer = function (time)
  ensureType(time, "number")
  local tag = {}
  table.insert(timers, {time, execEvent, pid, "k.timer", tag, time})
  return tag
 end

 local appfunc, r = loadfile("apps/" .. pkg .. ".lua", env)
 if not appfunc then
  return nil, r
 end
 proc.co = coroutine.create(function (...) local r = {xpcall(appfunc, debug.traceback, ...)} if not r[1] then error(table.unpack(r, 2)) end return table.unpack(r, 2) end)
 proc.pkg = pkg
 proc.access = {}
 proc.denied = {}
 -- You are dead. Not big surprise.
 proc.deathCBs = {function () pcall(function () env.neo.dead = true end) end}
 proc.cpuUsage = 0
 -- Note the target process doesn't get the procnew (the dist occurs before it's creation)
 pcall(distEvent, nil, "k.procnew", pkg, pid, ppkg, ppid)
 processes[pid] = proc
 table.insert(timers, {0, execEvent, pid, ppkg, ppid, ...})
 return pid
end

-- Kernel Scheduling Loop --

if not start("sys-init") then error("Could not start sys-init") end

while true do
 local tmr = nil
 for i = 1, 16 do
  tmr = nil
  local now = computer.uptime()
  local didAnything = false -- for early exit
  local k = 1
  while timers[k] do
   local v = timers[k]
   if v[1] <= now then
    table.remove(timers, k)
    if v[2](table.unpack(v, 3)) then
     didAnything = false -- to break
     tmr = 0.05
     break
    end
    didAnything = true
   else
    if not tmr then
     tmr = v[1]
    else
     tmr = math.min(tmr, v[1])
    end
    k = k + 1
   end
  end
  if not didAnything then break end
 end
 now = computer.uptime() -- the above probably took a while
 local dist = tmr and math.max(0.05, tmr - now)
 local signal = {computer.pullSignal(dist)}
 idleTime = idleTime + (computer.uptime() - now)
 if signal[1] then
  distEvent(nil, "h." .. signal[1], select(2, table.unpack(signal)))
 end
end
