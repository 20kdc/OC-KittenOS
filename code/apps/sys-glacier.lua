-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- s-donkonit : config, shutdown, screens

local donkonitSPProvider = neo.requireAccess("r.neo.sys.manage", "creating NEO core APIs") -- Restrict to s-
-- Doesn't matter what calls this service, because there's a mutex here.
local donkonitRDProvider = neo.requireAccess("r.neo.sys.screens", "creating NEO core APIs")
local glacierDCProvider = neo.requireAccess("r.neo.pub.globals", "creating NEO core APIs")

local computer = neo.requireAccess("k.computer", "shutting down")
local fs = neo.requireAccess("c.filesystem", "settings I/O")
local gpus = neo.requireAccess("c.gpu", "screen control")
local screens = neo.requireAccess("c.screen", "screen control")
neo.requireAccess("s.h.component_added", "HW management")
neo.requireAccess("s.h.component_removed", "HW management")

local function shutdownFin(reboot)
 -- any final actions donkonit needs to take here
 computer.shutdown(reboot)
end

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
  local st = fw(fs.primary, "data/sys-glacier/sysconf.lua", false)
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
 fs.primary.makeDirectory("data/sys-glacier")
 local st = fw(fs.primary, "data/sys-glacier/sysconf.lua", true)
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

-- Thanks to Skye for this!
local keyboardMonCacheK, keyboardMonCacheV = nil

local function announceFreeMonitor(address, except)
 for k, v in pairs(targsRD) do
  if k ~= except then
   v[1]("available", address)
  end
 end
end

local function getGPU(monitor)
 local bestG, bestStats = nil, {-math.huge, -math.huge, -math.huge}
 currentGPUBinding = {}
 for v in gpus.list() do
  v.bind(monitor.address, false)
  local w, h = v.maxResolution()
  local quality = w * h * v.maxDepth()
  local users = (currentGPUUsers[v.address] or 0)
  local gquality = 0
  for scr in screens.list() do
   v.bind(scr.address, false)
   w, h = v.maxResolution()
   local squality = w * h * v.maxDepth()
   gquality = math.max(gquality, squality)
  end
  local stats = {quality, -users, -gquality}
  for i = 1, #stats do
   if stats[i] > bestStats[i] then
    bestG = v
    bestStats = stats
    break
   elseif stats[i] < bestStats[i] then
    break
   end
  end
 end
 if bestG then
  neo.emergency("glacier bound " .. monitor.address .. " to " .. bestG.address)
 else
  neo.emergency("glacier failed to bind " .. monitor.address)
 end
 return bestG
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
local function setupMonitor(gpu, monitor)
 monitor.setPrecise(true)
 monitor.turnOn()
 gpu.bind(monitor.address, false)
 currentGPUBinding[gpu.address] = monitor.address
 local maxW, maxH = gpu.maxResolution()
 local maxD = gpu.maxDepth()
 local w, h, d, t = getMonitorSettings(monitor.address)
 w, h, d = math.min(w, maxW), math.min(h, maxH), math.min(d, maxD)
 if monitor.setTouchModeInverted then
  monitor.setTouchModeInverted(t == "yes")
 else
  t = "no"
 end
 settings["scr.w." .. monitor.address] = tostring(w)
 settings["scr.h." .. monitor.address] = tostring(h)
 settings["scr.d." .. monitor.address] = tostring(d)
 settings["scr.t." .. monitor.address] = t
 sRattle("scr.w." .. monitor.address, tostring(w))
 sRattle("scr.h." .. monitor.address, tostring(h))
 sRattle("scr.d." .. monitor.address, tostring(d))
 sRattle("scr.t." .. monitor.address, t)
 gpu.setResolution(w, h)
 gpu.setDepth(d)
 pcall(saveSettings)
end

donkonitSPProvider(function (pkg, pid, sendSig)
 targs[pid] = sendSig
 return {
  listSettings = function ()
   local s = {}
   for k, v in pairs(settings) do
    table.insert(s, k)
   end
   return s
  end,
  -- NOTE: REPLICATED IN GB
  getSetting = function (name)
   neo.ensureType(name, "string")
   return settings[name]
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
  --
  registerForShutdownEvent = function ()
   targsSD[pid] = sendSig
  end,
  registerSavingThrow = function (st)
   neo.ensureType(st, "function")
   targsST[pid] = st
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
      shutdownFin(reboot)
     end
    end)
   end
   if counter == 0 then
    shutdownFin(reboot)
   end
   -- donkonit will shutdown when the timer is hit.
  end
 }
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
   for v in screens.list() do
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
   if not gpus.list()() then return c end
   for _, v in ipairs(monitorPool) do
    table.insert(c, v.address)
   end
   return c
  end,
  claim = function (address)
   neo.ensureType(address, "string")
   for k, v in ipairs(monitorPool) do
    if v.address == address then
     local gpu = getGPU(v)
     if gpu then
      setupMonitor(gpu, v)
      gpu = gpu.address
      currentGPUBinding[gpu] = address
      currentGPUUsers[gpu] = (currentGPUUsers[gpu] or 0) + 1
      local disclaimer = function (wasDevLoss)
       -- we lost it
       monitorClaims[address] = nil
       claimed[address] = nil
       if not wasDevLoss then
        currentGPUUsers[gpu] = currentGPUUsers[gpu] - 1
        table.insert(monitorPool, v)
        announceFreeMonitor(address, pid)
       else
        sendSig("lost", address)
       end
      end
      claimed[address] = disclaimer
      monitorClaims[address] = {gpu, disclaimer}
      table.remove(monitorPool, k)
      return function ()
       for v in gpus.list() do
        if v.address == gpu then
         local didBind = false
         if currentGPUBinding[gpu] ~= address then
          v.bind(address, false)
          didBind = true
         end
         currentGPUBinding[gpu] = address
         return v, didBind
        end
       end
      end, v
     end
    end
   end
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
 local hasGPU = gpus.list()()
 for k, v in pairs(monitorClaims) do
  v[2](true)
 end
 monitorClaims = {}
 for m in screens.list() do
  table.insert(monitorPool, m)
  if hasGPU then
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
  getSetting = function (name)
   neo.ensureType(name, "string")
   return settings["pub." .. name]
  end,
  delSetting = function (name)
   neo.ensureType(name, "string")
   local val = nil
   if name == "clipboard" then val = "" end
   settings["pub." .. name] = val
   sRattle("pub." .. name, val)
   pcall(saveSettings)
  end,
  setSetting = function (name, val)
   neo.ensureType(name, "string")
   neo.ensureType(val, "string")
   settings["pub." .. name] = val
   sRattle("pub." .. name, val)
   pcall(saveSettings)
  end
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
