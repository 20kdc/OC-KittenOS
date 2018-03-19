-- KittenOS N.E.O Kernel: "Tell Mettaton I said hi."
-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- NOTE: If it's not "local", it's because k.root ought to access it.
-- List of things that apply:
-- primaryDisk, timers, libraries, processes, accesses, wrapMeta,
--  distEvent, baseProcEnv, loadLibraryInner, retrieveAccess,
--  start

-- Debugging option, turns process errors into actual errors (!)
local criticalFailure = false
-- In case of OpenComputers configuration abnormality
local readBufSize = 2048

-- A function used for logging, usable by programs.
-- Comment this out if you don't want programs to have
--  access to ocemu's logger.
local emergencyFunction
local ocemu = component.list("ocemu", true)()
if ocemu then
 ocemu = component.proxy(ocemu)
 emergencyFunction = ocemu.log
end

primaryDisk = component.proxy(computer.getBootAddress())

timers = {}

libraries = {}
setmetatable(libraries, {
 __mode = "v"
})

-- proc.co = coroutine.create(appfunc)
-- proc.pkg = "pkg"
-- proc.access = {["perm"] = true, ...}
-- proc.denied = {["perm"] = true, ...}
-- proc.deathcbs = {function(), ...}
-- very slightly adjusted total CPU time
-- proc.cpuUsage
processes = {}
-- Maps registration-accesses to function(pkg, pid)
accesses = {}
local lastPID = 0

-- keys: <any>
-- sr.waiting: keys are PIDs, values are just "true"
-- sr.service: function()
-- sr.result: boolean
local outstandingSR = {}

-- Kernel global "idle time" counter, useful for accurate performance data
local idleTime = 0

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
   ignoreNext = unicode.charWidth(ch) ~= 1
   res = res .. ch
  else
   ignoreNext = false
  end
 end
 return res
end

local function loadfile(s, e)
 local h = primaryDisk.open(s)
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
 return nil, "File Unreadable"
end

local wrapMeta = nil
local uniqueNEOProtectionObject = {}
function wrapMeta(t)
 if type(t) == "table" then
  local t2 = {}
  setmetatable(t2, {
   __index = function (a, k) return wrapMeta(t[k]) end,
   __newindex = function (a, k, v) end,
   __pairs = function (a)
    return function (x, key)
     local k, v = next(t, k)
     if k then return k, wrapMeta(v) end
    end, {}, nil
   end,
   __ipairs = function (a)
    return function (x, key)
     key = key + 1
     if t[key] then
      return key, wrapMeta(t[key])
     end
    end, {}, 0
   end,
   __metatable = uniqueNEOProtectionObject
   -- Don't protect this table - it'll make things worse
  })
  return t2
 else
  return t
 end
end

local function ensureType(a, t)
 if type(a) ~= t then error("Invalid parameter, expected a " .. t) end
 if t == "table" then
  if getmetatable(a) then error("Invalid parameter, has metatable") end
 end
end

local function ensurePathComponent(s)
 if not s:match("^[a-zA-Z0-9_%-%+%,%#%~%@%'%;%[%]%(%)%&%%%$%! %=%{%}%^]+") then error("chars disallowed") end
 if s == "." then error("single dot disallowed") end
 if s == ".." then error("double dot disallowed") end
end

local function ensurePath(s, r)
 -- Filter filename for anything "worrying". Note / is allowed, see further filters
 if not s:match("^[a-zA-Z0-9_%-%+%,%#%~%@%'%;%[%]%(%)%&%%%$%! %=%{%}%^%/]+") then error("chars disallowed") end
 if s:sub(1, r:len()) ~= r then error("base disallowed") end
 if s:match("//") then error("// disallowed") end
 if s:match("^%.%./") then error("../ disallowed") end
 if s:match("/%.%./") then error("/../ disallowed") end
 if s:match("/%.%.$") then error("/.. disallowed") end
 if s:match("^%./") then error("./ disallowed") end
 if s:match("/%./") then error("/./ disallowed") end
 if s:match("/%.$") then error("/. disallowed") end
end

local wrapMath = wrapMeta(math)
local wrapTable = wrapMeta(table)
local wrapString = wrapMeta(string)
local wrapUnicode = wrapMeta(unicode)
local wrapCoroutine = wrapMeta(coroutine)
local wrapOs = wrapMeta({
  totalMemory = computer.totalMemory, freeMemory = computer.freeMemory,
  energy = computer.energy, maxEnergy = computer.maxEnergy,
  clock = os.clock, date = os.date, difftime = os.difftime,
  time = os.time, uptime = computer.uptime
 })

local distEvent = nil

-- Use with extreme care.
-- (A process killing itself will actually survive until the next yield... before any of the death events have run.)
local function termProc(pid, reason)
 if processes[pid] then
  -- Immediately prepare for GC, it's possible this is out of memory.
  -- If out of memory, then to reduce risk of memory leak by error, memory needs to be freed ASAP.
  -- Start by getting rid of all process data.
  local dcbs = processes[pid].deathcbs
  local pkg = processes[pid].pkg
  local usage = processes[pid].cpuUsage
  processes[pid] = nil
  -- This gets rid of a few more bits of data.
  for _, v in ipairs(dcbs) do
   v()
  end
  -- This finishes off that.
  dcbs = nil
  if reason and criticalFailure then
   error(tostring(reason)) -- This is a debugging aid to give development work an easy-to-get-at outlet. Icecap is for most cases
  end
  if reason and emergencyFunction then
   emergencyFunction("d1 " .. pkg .. "/" .. pid)
   emergencyFunction("d2 " .. reason)
  end
  -- And this is why it's important, because this generates timers.
  -- The important targets of these timers will delete even more data.
  distEvent(nil, "k.procdie", pkg, pid, reason, usage)
 end
end

local function execEvent(k, ...)
 if processes[k] then
  local v = processes[k]
  local timerA = computer.uptime()
  local r, reason = coroutine.resume(v.co, ...)
  -- Mostly reliable accounting
  v.cpuUsage = v.cpuUsage + (computer.uptime() - timerA)
  local dead = not r
  local hasReason = dead
  if not dead then
   if coroutine.status(v.co) == "dead" then
    dead = true
   end
  end
  if dead then
   if hasReason then
    reason = tostring(reason)
   else
    reason = nil
   end
   termProc(k, reason)
   return hasReason
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
  if (not v.access["s." .. s]) or v.access["k.root"] then
   return
  end
  -- Schedule a timer for "now"
  table.insert(timers, {computer.uptime(), function ()
   return execEvent(pid, s, table.unpack(ev))
  end})
  return
 end
 for k, v in pairs(processes) do
  distEvent(k, s, ...)
 end 
end

local loadLibraryInner = nil

function baseProcEnv()
 return {math = wrapMath,
  table = wrapTable,
  string = wrapString,
  unicode = wrapUnicode,
  coroutine = wrapCoroutine,
  os = wrapOs,
  -- Note raw-methods are gone - these can interfere with the metatable safeties.
  require = loadLibraryInner,
  assert = assert,     ipairs = ipairs,
  load = load,         next = next,
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
   local mt = getmetatable(n)
   if mt == uniqueNEOProtectionObject then error("NEO-Protected Object") end
   return rawset(t, i, v)
  end, rawget = rawget, rawlen = rawlen, rawequal = rawequal,
  neo = {
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
   listApps = function ()
    local n = primaryDisk.list("apps/")
    local n2 = {}
    for k, v in ipairs(n) do
     if v:sub(#v - 3) == ".lua" then
      table.insert(n2, v:sub(1, #v - 4))
     end
    end
    return n2
   end,
   listLibs = function ()
    local n = primaryDisk.list("libs/")
    local n2 = {}
    for k, v in ipairs(n) do
     if v:sub(#v - 3) == ".lua" then
      table.insert(n2, v:sub(1, #v - 4))
     end
    end
    return n2
   end,
   totalIdleTime = function () return idleTime end,
   ensurePath = ensurePath,
   ensurePathComponent = ensurePathComponent,
  }
 }
end

function loadLibraryInner(library)
 ensureType(library, "string")
 library = "libs/" .. library .. ".lua"
 ensurePath(library, "libs/")
 if libraries[library] then return libraries[library] end
 local l, r = loadfile(library, baseProcEnv())
 if l then
  local ok, al = pcall(l)
  if ok then
   libraries[library] = al
   return al
  else
   return nil, al
  end
 end
 return nil, r
end

function retrieveAccess(perm, pkg, pid)
 -- Return the access lib and the death callback.

 -- Access categories are sorted into:
 -- "c.<hw>":    Component
 -- "s.<event>": Signal receiver (with responsibilities for Security Request watchers)
 -- "s.k.<...>": Kernel stuff
 -- "s.k.securityrequest": !!! HAS SIDE EFFECTS !!!
 -- "s.h.<...>": Incoming HW messages
 -- "s.x.<endpoint>": This access is actually useless on it's own - it is given by x.<endpoint>

 -- "k.<x>":     Kernel
 -- "k.root":    _ENV (holy grail)
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
   primary = primaryDisk
   temporary = component.proxy(computer.tmpAddress())
  end
  return {
   list = function ()
    local i = component.list(t, true)
    return function ()
     local ii = i()
     if not ii then return nil end
     return component.proxy(ii)
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

local start = nil

function start(pkg, ...)
 ensureType(pkg, "string")
 ensurePathComponent(pkg .. ".lua")
 local args = {...}
 local proc = {}
 local pid = lastPID
 lastPID = lastPID + 1

 local function startFromUser(ipkg, ...)
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
  return start(ipkg, pkg, pid, ...)
 end

 local function osExecuteCore(handler, ...)
  local pid, err = startFromUser(...)
  while pid do
   local sig = {coroutine.yield()}
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
  local req = {}
  req.waiting = {}
  req.service = function ()
   if processes[pid] then
    local n = nil
    local n2 = nil
    if req.result then
     proc.access[perm] = true
     n, n2 = retrieveAccess(perm, pkg, pid)
     if n2 then
      table.insert(processes[pid].deathcbs, n2)
     end
    else
     proc.denied[perm] = true
    end
    distEvent(pid, "k.securityresponse", perm, n)
   end
  end
  req.result = (not proc.denied[perm]) or proc.access["k.root"]
  if proc.access["k.root"] or proc.access[perm] or proc.denied[perm] then
   -- Use cached result to prevent possible unintentional security service spam
   req.service()
   return
  end
  -- Anything with s.k.securityrequest access has the response function and thus the vote,
  --  but can't vote on itself for obvious reasons. Kernel judge is a fallback.
  local shouldKernelJudge = true
  for k, v in pairs(processes) do
   if v.access["s.k.securityrequest"] then
    shouldKernelJudge = false
    if k ~= pid then
     req.waiting[k] = true
     distEvent(k, "k.securityrequest", pkg, pid, perm, function (r)
      ensureType(r, "boolean")
      if not r then
       req.result = false
      end
      req.waiting[k] = nil
     end)
    end
   end
  end
  if shouldKernelJudge then
   -- Rather restrictive, but an important safety measure
   req.result = pkg:sub(1, 4) == "sys-"
   req.service()
  else
   table.insert(outstandingSR, req)
  end
 end
 local env = baseProcEnv()
 env.neo.pid = pid
 env.neo.executeAsync = startFromUser
 env.neo.execute = function (...)
  return osExecuteCore(function () end, ...)
 end
 env.neo.executeExt = osExecuteCore
 env.neo.requestAccessAsync = requestAccessAsync
 env.neo.requestAccess = function (perm, handler)
  requestAccessAsync(perm)
  if not handler then handler = function() end end
  while true do
   local n = {coroutine.yield()}
   if n[1] == "k.securityresponse" then
    -- Security response - if it involves the permission, then take it
    if n[2] == perm then return n[3] end
   end
   handler(table.unpack(n))
  end
 end
 env.neo.scheduleTimer = function (time)
  ensureType(time, "number")
  local tag = {}
  table.insert(timers, {time, function(ofs)
   return execEvent(pid, "k.timer", tag, time, ofs)
  end})
  return tag
 end

 local appfunc, r = loadfile("apps/" .. pkg .. ".lua", env)
 if not appfunc then
  return nil, r
 end
 proc.co = coroutine.create(appfunc)
 proc.pkg = pkg
 proc.access = {
  -- These permissions are the "critical set".
  ["s.k.securityresponse"] = true,
  ["s.k.timer"] = true,
  ["s.k.procnew"] = true,
  ["s.k.procdie"] = true,
  -- Used when a registration is updated, in particular, as this signifies "readiness"
  ["s.k.registration"] = true,
 }
 proc.denied = {}
 proc.deathcbs = {}
 proc.cpuUsage = 0
 -- Note the target process doesn't get the procnew (it's executed after it's creation)
 pcall(distEvent, nil, "k.procnew", pkg, pid)
 processes[pid] = proc
 -- For processes waiting on others, this at least tries to guarantee some safety.
 if criticalFailure then
  execEvent(pid, ...)
 else
  if not pcall(execEvent, pid, ...) then
   return nil, "neocore"
  end
 end
 return pid
end

-- Main Scheduling Loop --

local function processSRs()
 local didAnything = false
 for k, v in pairs(outstandingSR) do
  -- Outstanding security request handler.
  local actualWaitingCount = 0
  for k2, _ in pairs(v.waiting) do
   if not processes[k2] then
    v.waiting[k2] = nil
    v.result = false
   else
    actualWaitingCount = actualWaitingCount + 1
   end
  end
  if actualWaitingCount == 0 then
   -- Service the SR
   outstandingSR[k].service()
   outstandingSR[k] = nil
   didAnything = true
  end
 end
 return didAnything
end

-- The actual loop & initialization

if not start("sys-init") then error("Could not start sys-init") end
while true do
 local tmr = nil
 for i = 1, 16 do
  tmr = nil
  local now = computer.uptime()
  local breaking = false -- Used when a process dies - in this case it's assumed OC just did something drastic
  local didAnything = false
  local k = 1
  while timers[k] do
   local v = timers[k]
   if v[1] <= now then
    if v[2](now - v[1]) then
     breaking = true
     tmr = 0.05
     break
    end
    didAnything = true
    v = nil
   else
    if not tmr then
     tmr = v[1]
    else
     tmr = math.min(tmr, v[1])
    end
   end
   if v then
    k = k + 1
   else
    table.remove(timers, k)
   end
  end
  if breaking then break end
  didAnything = didAnything or processSRs()
  -- If the system didn't make any progress, then we're waiting for a signal (this includes timers)
  if not didAnything then break end
 end
 now = computer.uptime() -- the above probably took a while
 local dist = nil
 if tmr then
  dist = tmr - now
  if dist < 0.05 then dist = 0.05 end
 end
 local signal = {computer.pullSignal(dist)}
 idleTime = idleTime + (computer.uptime() - now)
 if signal[1] then
  distEvent(nil, "h." .. signal[1], select(2, table.unpack(signal)))
 end
end