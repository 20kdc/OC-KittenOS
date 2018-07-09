-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- s-donkonit : config, shutdown, screens

local donkonitSPProvider = neo.requireAccess("r.neo.sys.manage", "creating NEO core APIs") -- Restrict to s-
-- Doesn't matter what calls this service, because there's a mutex here.
local donkonitRDProvider = neo.requireAccess("r.neo.sys.screens", "creating NEO core APIs")
local glacierDCProvider = neo.requireAccess("r.neo.pub.globals", "creating NEO core APIs")

local shutdownFin = neo.requireAccess("k.computer", "shutting down").shutdown
local primary = neo.requireAccess("c.filesystem", "settings I/O").primary
local gpus = neo.requireAccess("c.gpu", "screen control").list
local screens = neo.requireAccess("c.screen", "screen control").list
neo.requireAccess("s.h.component_added", "HW management")
neo.requireAccess("s.h.component_removed", "HW management")

-- keys are pids
local targs = {} -- settings notify targs
local targsDC = {} -- displaycontrol settings notify targs
local targsSD = {} -- shutdown notify targs
local targsST = {} -- saving throws

local targsRD = {} -- pid->{sendSig,dead}

-- screen address -> {gpu, monitor}
local monitorMap = {}

local shuttingDown = false
local shutdownMode = false

-- needs improvements
local settings = {
 -- The list of settings is here:
 -- password
 password = "",
 ["pub.clipboard"] = "",
 ["sys-init.shell"] = "sys-everest",
 ["sys-everest.launcher"] = "app-launcher",
 ["run.sys-icecap"] = "yes",
 -- scr.w/h/d/t.<uuid>
}

local function loadSettings()
 pcall(function ()
  local fw = require("sys-filewrap").create
  local se = require("serial").deserialize
  local st = fw(primary, "data/sys-glacier/sysconf.lua", false)
  local cfg = st.read("*a")
  st.close()
  st = nil
  fw = nil
  cfg = se(cfg)
  for k, v in pairs(cfg) do
   if type(k) == "string" then
    if type(v) == "string" then
     settings[k] = v
    end
   end
  end
 end)
end

local function saveSettings()
 local fw = require("sys-filewrap").create
 local se = require("serial").serialize
 primary.makeDirectory("data/sys-glacier")
 local st = fw(primary, "data/sys-glacier/sysconf.lua", true)
 st.write(se(settings))
 st.close()
end

-- [i] = screenProxy
local monitorPool = {}
-- [screenAddr] = {gpu, claimedLoseCallback}
local monitorClaims = {}
-- [gpuAddr] = monitorAddr
local currentGPUBinding = {}
-- [gpuAddr] = userCount
local currentGPUUsers = {}

-- Thanks to Skye for this design!
local keyboardMonCacheK, keyboardMonCacheV = nil

local function announceFreeMonitor(address, except)
 for k, v in pairs(targsRD) do
  if k ~= except then
   v[1]("available", address)
  end
 end
end

local function sRattle(name, val)
 for _, v in pairs(targs) do
  v("set_setting", name, val)
 end
 if name:sub(1, 4) == "scr." or name:sub(1, 4) == "pub." then
  for k, v in pairs(targsDC) do
   v("set_setting", name, val)
  end
 end
end

-- Settings integration w/ monitors
local function getMonitorSettings(a)
 local w = tonumber(settings["scr.w." .. a]) or 80
 local h = tonumber(settings["scr.h." .. a]) or 25
 local d = tonumber(settings["scr.d." .. a]) or 8
 local t = ((settings["scr.t." .. a] == "yes") and "yes") or "no"
 w, h, d = math.floor(w), math.floor(h), math.floor(d)
 return w, h, d, t
end

-- Settings API

local mBase = {
 getSetting = function (name)
  neo.ensureType(name, "string")
  return settings[name]
 end,
 listSettings = function ()
  local s = {}
  for k, v in pairs(settings) do
   table.insert(s, k)
  end
  return s
 end,
 delSetting = function (name)
  neo.ensureType(name, "string")
  local val = nil
  if name == "password" or name == "pub.clipboard" then val = "" end
  settings[name] = val
  sRattle(name, val)
  pcall(saveSettings)
 end,
 setSetting = function (name, val)
  neo.ensureType(name, "string")
  neo.ensureType(val, "string")
  settings[name] = val
  -- NOTE: Either a monitor is under application control,
  --  or it's not under any control.
  -- Monitor settings are applied on the transition to control.
  sRattle(name, val)
  pcall(saveSettings)
 end,
 shutdown = function (reboot)
  neo.ensureType(reboot, "boolean")
  if shuttingDown then return end
  shuttingDown = true
  shutdownMode = reboot
  local counter = 0
  neo.scheduleTimer(os.uptime() + 5) -- in case the upcoming code fails in some way
  for f, v in pairs(targsSD) do
   counter = counter + 1
   v("shutdown", reboot, function ()
    counter = counter - 1
    if counter == 0 then
     shutdownFin(shutdownMode)
    end
   end)
  end
  if counter == 0 then
   shutdownFin(shutdownMode)
  end
  -- donkonit will shutdown when the timer is hit.
 end
}

donkonitSPProvider(function (pkg, pid, sendSig)
 targs[pid] = sendSig
 local n = {
  registerForShutdownEvent = function ()
   targsSD[pid] = sendSig
  end,
  registerSavingThrow = function (st)
   neo.ensureType(st, "function")
   targsST[pid] = st
  end
 }
 return setmetatable(n, {
  __index = mBase,
  __metatable = 0
 })
end)

donkonitRDProvider(function (pkg, pid, sendSig)
 local claimed = {}
 targsRD[pid] = {sendSig, function ()
  for k, v in pairs(claimed) do
   -- Nothing to really do here
   v(false)
  end
 end}
 return {
  getMonitorByKeyboard = function (kb)
   if keyboardMonCacheK == kb then
    return keyboardMonCacheV
   end
   for v in screens() do
    for _, v2 in ipairs(v.getKeyboards()) do
     if v2 == kb then
      keyboardMonCacheK, keyboardMonCacheV = kb, v.address
      return v.address
     end
    end
   end
  end,
  getClaimable = function ()
   local c = {}
   -- do we have gpu?
   if not gpus()() then return c end
   for _, v in ipairs(monitorPool) do
    table.insert(c, v.address)
   end
   return c
  end,
  claim = function (...) -- see sys-gpualloc
   return require("sys-gpualloc")(
    gpus, screens,
    getMonitorSettings, settings, sRattle, saveSettings,
    announceFreeMonitor, pid, claimed, sendSig,
    monitorClaims, monitorPool, currentGPUUsers, currentGPUBinding,
    ...)
  end,
  disclaim = function (address)
   if not address then error("Cannot disclaim nothing.") end
   if claimed[address] then
    claimed[address](false)
   end
  end
 }
end)

-- -- The actual initialization
loadSettings()
local function rescanDevs()
 monitorPool = {}
 currentGPUBinding = {}
 currentGPUUsers = {}
 keyboardMonCacheK, keyboardMonCacheV = nil, nil
 for k, v in pairs(monitorClaims) do
  v[2](true)
 end
 monitorClaims = {}
 for m in screens() do
  table.insert(monitorPool, m)
  if gpus()() then
   announceFreeMonitor(m.address)
  end
 end
end
rescanDevs()

-- Save any settings made during the above (or just the language)
pcall(saveSettings)
-- --

glacierDCProvider(function (pkg, pid, sendSig)
 targsDC[pid] = sendSig
 local function sWrap(f)
  return function (s, ...)
   return f("pub." .. s, ...)
  end
 end
 return {
  getKnownMonitors = function ()
   local tbl = {}
   -- yes, this should work fine so long as GMS is the *last* one #luaquirks
   for k, v in ipairs(monitorPool) do
    tbl[k] = {v.address, false, getMonitorSettings(v.address)}
   end
   for k, v in pairs(monitorClaims) do
    table.insert(tbl, {k, true, getMonitorSettings(k)})
   end
   return tbl
  end,
  changeMonitorSetup = function (ma, w, h, d, t)
   neo.ensureType(ma, "string")
   neo.ensureType(w, "number")
   neo.ensureType(h, "number")
   neo.ensureType(d, "number")
   neo.ensureType(t, "string")
   w = math.floor(w)
   h = math.floor(h)
   d = math.floor(d)
   if t ~= "yes" then t = "no" end
   if w < 1 then error("Invalid width") end
   if h < 1 then error("Invalid height") end
   if d < 1 then error("Invalid depth") end
   w, h, d = tostring(w), tostring(h), tostring(d)
   settings["scr.w." .. ma] = w
   settings["scr.h." .. ma] = h
   settings["scr.d." .. ma] = d
   settings["scr.t." .. ma] = t
   sRattle("scr.w." .. ma, w)
   sRattle("scr.h." .. ma, h)
   sRattle("scr.d." .. ma, d)
   sRattle("scr.t." .. ma, t)
   pcall(saveSettings)
  end,
  forceRescan = rescanDevs,
  -- NOTE: "pub." prefixed version of functions in sys.manage
  getSetting = sWrap(mBase.getSetting),
  delSetting = sWrap(mBase.delSetting),
  setSetting = sWrap(mBase.setSetting)
 }
end)

-- main loop

while true do
 local s = {coroutine.yield()}
 if s[1] == "k.timer" then
  -- always shutdown
  shutdownFin(shutdownMode)
 end
 if s[1] == "h.component_added" or s[1] == "h.component_removed" then
  -- Anything important?
  if s[3] == "gpu" or s[3] == "screen" then
   rescanDevs()
  end
 end
 if s[1] == "k.procdie" then
  targs[s[3]] = nil
  targsDC[s[3]] = nil
  targsSD[s[3]] = nil
  if targsST[s[3]] then
   if s[4] then
    coroutine.resume(coroutine.create(targsST[s[3]]))
   end
  end
  targsST[s[3]] = nil
  if targsRD[s[3]] then
   targsRD[s[3]][2]()
  end
 end
end
