-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- s-donkonit : config, shutdown, screens

-- Doesn't matter what calls this service, because there's a mutex here.
local donkonitSPProvider = neo.requestAccess("r.neo.sys.manage") -- Restrict to s-
if not donkonitSPProvider then return end
local donkonitRDProvider = neo.requestAccess("r.neo.sys.screens")
if not donkonitRDProvider then return end

local computer = neo.requestAccess("k.computer")
local fs = neo.requestAccess("c.filesystem")
local gpus = neo.requestAccess("c.gpu")
local screens = neo.requestAccess("c.screen")
neo.requestAccess("s.h.component_added")
neo.requestAccess("s.h.component_removed")

local function shutdownFin(reboot)
 -- any final actions donkonit needs to take here
 computer.shutdown(reboot)
end

-- keys are pids
local targs = {} -- settings notify targs
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
 ["run.sys-everest"] = "yes",
 ["run.sys-icecap"] = "yes",
 -- scr.w/h/d.<uuid>
}

local function loadSettings()
 pcall(function ()
  local fw = require("sys-filewrap")
  local se = require("serial")
  local st = fw(fs.primary, "data/sys-glacier/sysconf.lua", false)
  local cfg = st.read("*a")
  st.close()
  st = nil
  fw = nil
  cfg = se.deserialize(cfg)
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
 local fw = require("sys-filewrap")
 local se = require("serial")
 fs.primary.makeDirectory("data/sys-glacier")
 local st = fw(fs.primary, "data/sys-glacier/sysconf.lua", true)
 st.write(se.serialize(settings))
 st.close()
end

-- Monitor management stuff
local monitorPool = {}
-- {gpu, claimedLoseCallback}
local monitorClaims = {}

local function announceFreeMonitor(address, except)
 for k, v in pairs(targsRD) do
  if k ~= except then
   v[1]("available", address)
  end
 end
end

local function getGPU(monitor)
 local bestG
 local bestD = 0
 for v in gpus.list() do
  v.bind(monitor.address)
  local d = v.maxDepth()
  if d > bestD then
   bestG = v
   bestD = d
  end
 end
 return bestG
end

local function setupMonitor(gpu, monitor)
 local maxW, maxH = gpu.maxResolution()
 local maxD = gpu.maxDepth()
 local w = tonumber(settings["scr.w." .. monitor.address]) or 80
 local h = tonumber(settings["scr.h." .. monitor.address]) or 25
 local d = tonumber(settings["scr.d." .. monitor.address]) or 8
 w, h, d = math.floor(w), math.floor(h), math.floor(d)
 w, h, d = math.min(w, maxW), math.min(h, maxH), math.min(d, maxD)
 settings["scr.w." .. monitor.address] = tostring(w)
 settings["scr.h." .. monitor.address] = tostring(h)
 settings["scr.d." .. monitor.address] = tostring(d)
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
  getSetting = function (name)
   if type(name) ~= "string" then error("Setting name must be string") end
   return settings[name]
  end,
  delSetting = function (name)
   if type(name) ~= "string" then error("Setting name must be string") end
   local val = nil
   if name == "password" then val = "" end
   settings[name] = val
   for _, v in pairs(targs) do
    v("set_setting", name, val)
   end
   pcall(saveSettings)
  end,
  setSetting = function (name, val)
   if type(name) ~= "string" then error("Setting name must be string") end
   if type(val) ~= "string" then error("Setting value must be string") end
   settings[name] = val
   for _, v in pairs(targs) do
    v("set_setting", name, val)
   end
   pcall(saveSettings)
   --saveSettings()
  end,
  registerForShutdownEvent = function ()
   targsSD[pid] = sendSig
  end,
  registerSavingThrow = function (st)
   if type(st) ~= "function" then error("Saving throw function must be a function") end
   targsST[pid] = st
  end,
  shutdown = function (reboot)
   if type(reboot) ~= "boolean" then error("Shutdown parameter must be a boolean (reboot)") end
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
   monitorClaims[k] = nil
   announceFreeMonitor(k, pid)
  end
 end}
 return {
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
   if type(address) ~= "string" then error("Address must be string.") end
   for k, v in ipairs(monitorPool) do
    if v.address == address then
     local gpu = getGPU(v)
     if gpu then
      setupMonitor(gpu, v)
      gpu = gpu.address
      local disclaimer = function (wasDevLoss)
       -- we lost it
       monitorClaims[address] = nil
       claimed[address] = nil
       if not wasDevLoss then
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
         local _, v2 = v.bind(address)
         if not v2 then
          return v
         else
          return
         end
        end
       end
      end
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
 local hasGPU = gpus.list()()
 for m in screens.list() do
  if monitorClaims[m.address] then
   monitorClaims[m.address][2](true)
  end
  table.insert(monitorPool, m)
  if hasGPU then
   announceFreeMonitor(m.address)
  end
 end
end
rescanDevs()

-- Save any settings made during the above (or just the language)
saveSettings()
-- --

while true do
 local s = {coroutine.yield()}
 if s[1] == "k.timer" then
  -- always shutdown
  shutdownFin(shutdownMode)
 end
 if s[1] == "h.component_added" then
  rescanDevs()
 end
 if s[1] == "h.component_removed" then
  rescanDevs()
 end
 if s[1] == "k.procdie" then
  targs[s[3]] = nil
  targsSD[s[3]] = nil
  if targsST[s[3]] then
   if s[4] then
    pcall(targsST[s[3]])
   end
  end
  targsST[s[3]] = nil
  if targsRD[s[3]] then
   targsRD[s[3]][2]()
  end
 end
end
