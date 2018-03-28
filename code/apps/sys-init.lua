-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- s-bristol splash screen, login agent
-- Named to allude to Plymouth (splash screen used in some linux distros)

local callerPkg, callerPid, callerScr = ...

local gpuG, screen = nil, nil
local shutdownEmergency = neo.requestAccess("k.computer").shutdown
neo.requestAccess("s.h.key_down")

local scrW, scrH
local warnings = {
 "",
 "",
 ""
}

-- Attempts to call upon nsm for a safe shutdown
local function shutdown(reboot)
 local nsm = neo.requestAccess("x.neo.sys.manage")
 if nsm then
  nsm.shutdown(reboot)
  while true do
   coroutine.yield()
  end
 else
  shutdownEmergency(reboot)
 end
end

local function rstfbDraw(gpu)
 gpu.setBackground(0xFFFFFF)
 gpu.setForeground(0x000000)
end

local function basicDraw(gpu)
 scrW, scrH = gpu.getResolution()
 gpu.fill(1, 1, scrW, scrH, " ")
 gpu.set(2, 2, "KittenOS NEO")
end

local function advDraw(gpu)
 basicDraw(gpu)
 local usage = math.floor((os.totalMemory() - os.freeMemory()) / 1024)
 gpu.set(2, 3, "RAM Usage: " .. usage .. "K / " .. math.floor(os.totalMemory() / 1024) .. "K")
 for i = 1, #warnings do
  gpu.set(2, 6 + i, warnings[i])
 end
end

-- Callback setup by finalPrompt to disclaim the main monitor first
local performDisclaim = nil

local function retrieveNssMonitor(nss)
 gpuG = nil
 local subpool = {}
 while not gpuG do
  if performDisclaim then
   performDisclaim(true)
   performDisclaim = nil
  end
  -- nss available - this means the monitor pool is now ready.
  -- If no monitors are available, shut down now.
  -- NSS monitor pool output is smaller than, but similar to, Everest monitor data:
  -- {gpu, screenAddr}
  local pool = nss.getClaimable()
  while not pool[1] do
   coroutine.yield() -- wait for presumably a NSS notification
   pool = nss.getClaimable()
  end
  subpool = {}
  -- Specifies which element to elevate to top priority
  local optimalSwap = nil
  if screen then
   for k, v in ipairs(pool) do
    if v == screen then
     optimalSwap = k
     break
    end
   end
  end
  if optimalSwap then
   local swapA = pool[optimalSwap]
   pool[optimalSwap] = pool[1]
   pool[1] = swapA
  end
  for _, v in ipairs(pool) do
   local gpu = nss.claim(v)
   if gpu then
    local gcb = gpu()
    if gcb then
     table.insert(subpool, {gpu, v})
     gcb.setBackground(0x000020)
     local w, h = gcb.getResolution()
     gcb.fill(1, 1, w, h, " ")
    end
   end
  end
 
  if not subpool[1] then
   error("None of the GPUs we got were actually usable")
  end
  gpuG = subpool[1][1]
  screen = subpool[1][2]
 end
 -- done with search
 local gpu = gpuG()
 scrW, scrH = gpu.getResolution()
 rstfbDraw(gpu)
 gpu.fill(1, 1, scrW, scrH, " ")
 performDisclaim = function (full)
  nss.disclaim(subpool[1][2])
  if full then
   for _, v in ipairs(subpool) do
    nss.disclaim(v[2])
   end
  end
 end
 return gpu
end

local function sleep(t)
 neo.scheduleTimer(os.uptime() + t)
 while true do
  local ev = {coroutine.yield()}
  if ev[1] == "k.timer" then
   break
  end
  if ev[1] == "x.neo.sys.screens" then
   -- This implies we have and can use nss, but check anyway
   local nss = neo.requestAccess("x.neo.sys.screens")
   if nss then
    local gpu = retrieveNssMonitor(nss)
    basicDraw(gpu)
   end
  end
 end
end

local function finalPrompt()
 local nss = neo.requestAccess("x.neo.sys.screens")
 if nss then
  retrieveNssMonitor(nss)
 else
  error("no glacier to provide GPU for the prompt")
 end
 -- This is nsm's final chance to make itself available and thus allow the password to be set
 local nsm = neo.requestAccess("x.neo.sys.manage")
 local waiting = true
 local safeModeActive = false
 local password = ""
 if nsm then
  password = nsm.getSetting("password")
  if nsm.getSetting("sys-init.nologin") == "yes" then
   return false
  end
 end
 warnings[1] = "TAB to change option,"
 warnings[2] = "ENTER to select..."
 -- The actual main prompt loop
 while waiting do
  local gpu = gpuG()
  rstfbDraw(gpu)
  advDraw(gpu)
  local entry = ""
  local entry2 = ""
  local active = true
  local shButton = "<Shutdown>"
  local rbButton = "<Reboot>"
  local smButton = "<Safe Mode>"
  local pw = {function ()
     return "Password: " .. entry2
    end, function (key)
     if key >= 32 then
      entry = entry .. unicode.char(key)
      entry2 = entry2 .. "*"
     end
     if key == 13 then
      if entry == password then
       waiting = false
      else
       local gpu = gpuG()
       rstfbDraw(gpu)
       advDraw(gpu)
       sleep(1)
      end
      active = false
     end
    end, 2, 5, scrW - 2}
  if password == "" then
   pw = {function ()
     return "Log in..."
    end, function (key)
     if key == 13 then
      waiting = false
      active = false
     end
    end, 2, 5, scrW - 2}
  end
  local controls = {
   {function ()
     return shButton
    end, function (key)
     if key == 13 then
      local gpu = gpuG()
      rstfbDraw(gpu)
      basicDraw(gpu)
      gpu.set(2, 4, "Shutting down...")
      shutdown(false)
     end
    end, 2, scrH - 1, unicode.len(shButton)},
   {function ()
     return rbButton
    end, function (key)
     if key == 13 then
      local gpu = gpuG()
      rstfbDraw(gpu)
      basicDraw(gpu)
      gpu.set(2, 4, "Rebooting...")
      shutdown(true)
     end
    end, 3 + unicode.len(shButton), scrH - 1, unicode.len(rbButton)},
   {function ()
     return smButton
    end, function (key)
     if key == 13 then
      local gpu = gpuG()
      rstfbDraw(gpu)
      basicDraw(gpu)
      gpu.set(2, 4, "Login to activate Safe Mode.")
      sleep(1)
      gpu = gpuG()
      safeModeActive = true
      rstfbDraw(gpu)
      advDraw(gpu)
     end
    end, 4 + unicode.len(shButton) + unicode.len(rbButton), scrH - 1, unicode.len(smButton)},
   pw,
  }
  local control = #controls
  while active do
   local gpu = gpuG()
   for k, v in ipairs(controls) do
    if k == control then
     gpu.setBackground(0x000000)
     gpu.setForeground(0xFFFFFF)
    else
     gpu.setBackground(0xFFFFFF)
     gpu.setForeground(0x000000)
    end
    gpu.fill(v[3], v[4], v[5], 1, " ")
    gpu.set(v[3], v[4], v[1]())
   end
   -- event handling...
   local sig = {coroutine.yield()}
   if sig[1] == "x.neo.sys.screens" then
    -- We need to reinit screens no matter what.
    retrieveNssMonitor(nss)
   end
   if sig[1] == "h.key_down" then
    if sig[4] == 15 then
     -- this makes sense in context
     control = control % (#controls)
     control = control + 1
    else
     controls[control][2](sig[3])
    end
   end
  end
 end
 local gpu = gpuG()
 rstfbDraw(gpu)
 advDraw(gpu)
 return safeModeActive
end
local function postPrompt()
 local gpu = gpuG()
 local nsm = neo.requestAccess("x.neo.sys.manage")
 local sh = "sys-everest"
 warnings = {"Unable to get sys-init.shell due to no NSM, using sys-everest"}
 if nsm then
  sh = nsm.getSetting("sys-init.shell") or sh
  warnings = {"Starting "  .. sh}
 end
 rstfbDraw(gpu)
 advDraw(gpu)
 performDisclaim()
 neo.executeAsync(sh)
 sleep(0.5)
 for i = 1, 9 do
  local v = neo.requestAccess("x.neo.sys.session")
  sleep(0.5) -- Important timing - allows it to take the monitor
  if v then
   return
  end
 end
 -- ...oh. hope this works then?
 warnings = {"That wasn't a shell. Try Safe Mode."}
 rstfbDraw(gpu)
 advDraw(gpu)
 sleep(1)
 shutdown(true)
end

local function initializeSystem()
 -- System has just booted, bristol is in charge
 -- Firstly, since we don't know scrcfg, let's work out something sensible.
 -- Note that we should try to keep going with this if there's no reason to do otherwise.
 local gpuAc = neo.requestAccess("c.gpu")
 local screenAc = neo.requestAccess("c.screen")
 local gpu
 -- time to setup gpu/screen variables!
 if gpuAc and screenAc then
  local scrBestWHD = 0
  for s in screenAc.list() do
   for g in gpuAc.list() do
    g.bind(s.address, false)
    local whd = g.maxDepth()
    if whd > scrBestWHD then
     screen = s
     gpu = g
     scrBestWHD = whd
    end
   end
  end
 end
 if gpu then
  screen = screen.address
  gpu.bind(screen, true)
  local gW, gH = gpu.maxResolution()
  gW, gH = math.min(80, gW), math.min(25, gH)
  gpu.setResolution(gW, gH)
  pcall(gpu.setDepth, gpu.maxDepth()) -- can crash on OCEmu if done at the "wrong time"
  gpu.setForeground(0x000000)
 end
 local w = 1
 local steps = {
  "sys-glacier", -- (Glacier : Config, Screen, Power)
  -- Let that start, and system GC
  "WAIT",
  "WAIT",
  "WAIT",
  "WAIT",
  -- Start services
  "INJECT",
  -- extra GC time
  "WAIT",
  "WAIT",
  "WAIT",
  "WAIT",
  "WAIT",
  "WAIT",
  "WAIT"
 }
 local stepCount = #steps

 neo.scheduleTimer(os.uptime())
 while true do
  local ev = {coroutine.yield()}
  if ev[1] == "k.procnew" then
   table.insert(warnings, ev[2] .. "/" .. ev[3] .. " UP")
  end
  if ev[1] == "k.procdie" then
   table.insert(warnings, ev[2] .. "/" .. ev[3] .. " DOWN")
   table.insert(warnings, tostring(ev[4]))
  end
  if ev[1] == "k.timer" then
   if gpu then
    gpu.setForeground(0x000000)
    if w < stepCount then
     local n = math.floor((w / stepCount) * 255)
     gpu.setBackground((n * 0x10000) + (n * 0x100) + n)
    else
     gpu.setBackground(0xFFFFFF)
    end
    basicDraw(gpu)
   end
   if steps[w] then
    if steps[w] == "INJECT" then
     local nsm = neo.requestAccess("x.neo.sys.manage")
     if not nsm then
      table.insert(warnings, "Settings not available for INJECT.")
     else
      local nextstepsA = {}
      local nextstepsB = {}
      for _, v in ipairs(neo.listApps()) do
       if nsm.getSetting("run." .. v) == "yes" then
        if v:sub(1, 4) == "sys-" then
         table.insert(nextstepsA, v)
        else
         table.insert(nextstepsB, v)
        end
       end
      end
      for _, v in ipairs(nextstepsB) do
       table.insert(steps, w + 1, v)
      end
      for _, v in ipairs(nextstepsA) do
       table.insert(steps, w + 1, v)
      end
     end
    elseif steps[w] == "WAIT" then
    else
     local v, err = neo.executeAsync(steps[w])
     if not v then
      table.insert(warnings, steps[w] .. " STF")
      table.insert(warnings, err)
     end
    end
   else
    break
   end
   w = w + 1
   neo.scheduleTimer(os.uptime() + 0.049)
  end
 end
end
-- Actual sequence

if callerPkg ~= nil then
 screen = callerScr
 -- Skip to "System initialized" (Everest either logged off, or died & used a Saving Throw to restart)
else
 initializeSystem()
end
-- System initialized
if finalPrompt() then
 -- Safe Mode
 local gpu = gpuG()
 rstfbDraw(gpu)
 basicDraw(gpu)
 local nsm = neo.requestAccess("x.neo.sys.manage")
 if nsm then
  gpu.set(2, 4, "Rebooting for Safe Mode...")
  for _, v in ipairs(nsm.listSettings()) do
   if v ~= "password" then
    nsm.delSetting(v)
   end
  end
 else
  -- assume sysconf.lua did something very bad
  gpu.set(2, 4, "No NSM. Wiping configuration completely.")
  local fs = neo.requestAccess("c.filesystem")
  if not fs then
   gpu.set(2, 4, "Failed to get permission, you're doomed.")
  end
  fs.primary.remove("/data/sys-glacier/sysconf.lua")
 end
 -- Do not give anything a chance to alter the new configuration
 shutdownEmergency(true)
 return
end
postPrompt()
