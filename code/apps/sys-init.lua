-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- s-bristol splash screen, login agent
-- Named to allude to Plymouth (splash screen used in some linux distros)

local callerPkg, callerPid, callerScr = ...

local shutdownEmergency = neo.requestAccess("k.computer").shutdown
neo.requestAccess("s.h.key_down")
neo.requestAccess("s.h._kosneo_syslog")

-- gpuG/performDisclaim are GPU management, while screen is used for prioritization
local gpuG, performDisclaim, screen = nil
local scrW, scrH = 1, 1
local nssInst

local console = {}
local helpActive = false
local buttonsActive = false

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

local function basicDraw(bg)
 local gpu = gpuG()
 pcall(gpu.setBackground, bg or 0xFFFFFF)
 pcall(gpu.setForeground, 0x000000)
 local ok, sw, sh = pcall(gpu.getResolution)
 if not ok then return end
 scrW, scrH = sw, sh
 pcall(gpu.fill, 1, 1, scrW, scrH, " ")
 pcall(gpu.set, 2, 2, "KittenOS NEO")
 local usage = math.floor((os.totalMemory() - os.freeMemory()) / 1024)
 pcall(gpu.set, 2, 3, "RAM Usage: " .. usage .. "K / " .. math.floor(os.totalMemory() / 1024) .. "K")
 local cut = 7
 if buttonsActive then cut = 9 end
 local areaSize = scrH - cut
 local n2 = 0
 if helpActive then
  if _VERSION == "Lua 5.2" then
   table.insert(console, "WARNING: Lua 5.2 memory usage issue!")
   table.insert(console, "Shift-right-click while holding the CPU/APU.")
   n2 = 2
  end
  table.insert(console, "TAB to change option, ENTER to select.")
  n2 = n2 + 1
 end
 for i = 1, areaSize do
  pcall(gpu.set, 2, 6 + i, console[#console + i - areaSize] or "")
 end
 for i = 1, n2 do
  table.remove(console, #console)
 end
 return gpu
end

local function consoleEventHandler(ev)
 if ev[1] == "h._kosneo_syslog" then
  local text = ""
  for i = 3, #ev do
   if i ~= 3 then text = text .. " " end
   text = text .. tostring(ev[i])
  end
  table.insert(console, text)
 end
end

-- Attempts to get an NSS monitor with a priority list of screens
local function retrieveNssMonitor(...)
 local spc = {...}
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
  local pool = nssInst.getClaimable()
  while not pool[1] do
   -- wait for presumably a NSS notification
   consoleEventHandler({coroutine.yield()})
   pool = nssInst.getClaimable()
  end
  subpool = {}
  -- Specifies which element to elevate to top priority
  local optimalSwap = nil
  local optimal = #spc + 1
  if screen then
   for k, v in ipairs(pool) do
    for k2, v2 in ipairs(spc) do
     if v == v2 and optimal > k2 then
      optimalSwap, optimal = k, k2
      break
     end
    end
   end
  end
  if optimalSwap then
   local swapA = pool[optimalSwap]
   pool[optimalSwap] = pool[1]
   pool[1] = swapA
  end
  for _, v in ipairs(pool) do
   local gpu = nssInst.claim(v)
   if gpu then
    local gcb = gpu()
    if gcb then
     pcall(function ()
      gcb.setBackground(0x000020)
      local w, h = gcb.getResolution()
      gcb.fill(1, 1, w, h, " ")
      table.insert(subpool, {gpu, v})
     end)
    end
   end
  end
  if subpool[1] then
   gpuG, screen = table.unpack(subpool[1])
  end
 end
 -- done with search
 performDisclaim = function (full)
  nssInst.disclaim(subpool[1][2])
  if full then
   for _, v in ipairs(subpool) do
    nssInst.disclaim(v[2])
   end
  end
 end
end

local function sleep(t)
 neo.scheduleTimer(os.uptime() + t)
 while true do
  local ev = {coroutine.yield()}
  consoleEventHandler(ev)
  if ev[1] == "k.timer" then
   break
  end
  if ev[1] == "x.neo.sys.screens" then
   retrieveNssMonitor(screen)
   basicDraw()
  end
 end
end

local function alert(s)
 console = {s}
 helpActive, buttonsActive = false, false
 basicDraw()
 sleep(1)
 buttonsActive = true
end

local function finalPrompt()
 nssInst = neo.requestAccess("x.neo.sys.screens")
 if not nssInst then
  console = {"sys-glacier not available"}
  basicDraw()
  error("no nssInst")
 end
 retrieveNssMonitor()
 helpActive, buttonsActive = true, true
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
 -- The actual main prompt loop
 while waiting do
  local entry = ""
  local entry2 = ""
  local active = true
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
       alert("Incorrect password")
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
     return "<Shutdown>"
    end, function (key)
     if key == 13 then
      alert("Shutting down...")
      shutdown(false)
     end
    end, 2, scrH - 1, 10},
   {function ()
     return "<Reboot>"
    end, function (key)
     if key == 13 then
      alert("Rebooting...")
      shutdown(true)
     end
    end, 13, scrH - 1, 8},
   {function ()
     return "<Safe Mode>"
    end, function (key)
     if key == 13 then
      safeModeActive = true
      alert("Login to activate Safe Mode.")
     end
    end, 22, scrH - 1, 11},
   pw,
  }
  local control = #controls
  local lastKeyboard
  while active do
   local gpu = basicDraw()
   if gpu then
    for k, v in ipairs(controls) do
     if k == control then
      pcall(gpu.setBackground, 0x000000)
      pcall(gpu.setForeground, 0xFFFFFF)
     else
      pcall(gpu.setBackground, 0xFFFFFF)
      pcall(gpu.setForeground, 0x000000)
     end
     pcall(gpu.fill, v[3], v[4], v[5], 1, " ")
     pcall(gpu.set, v[3], v[4], v[1]())
    end
   end
   -- event handling...
   local sig = {coroutine.yield()}
   consoleEventHandler(sig)
   if sig[1] == "x.neo.sys.screens" then
    -- We need to reinit screens no matter what.
    retrieveNssMonitor(screen)
    active = false
   end
   if sig[1] == "h.key_down" then
    if sig[2] ~= lastKeyboard then
     lastKeyboard = sig[2]
     local nScreen = nssInst.getMonitorByKeyboard(lastKeyboard)
     if nScreen and nScreen ~= screen then
      neo.emergency("new primary:", nScreen)
      retrieveNssMonitor(nScreen, screen)
      active = false
     end
    end
    if sig[4] == 15 then
     -- this makes sense in context
     control = control % #controls
     control = control + 1
    else
     controls[control][2](sig[3])
    end
   end
  end
 end
 helpActive, buttonsActive = false, false
 return safeModeActive
end
local function postPrompt()
 local nsm = neo.requestAccess("x.neo.sys.manage")
 local sh = "sys-everest"
 console = {"Unable to get shell (no sys-glacier)"}
 if nsm then
  sh = nsm.getSetting("sys-init.shell") or sh
  console = {"Starting "  .. sh}
 end
 basicDraw()
 performDisclaim()
 neo.executeAsync(sh)
 -- There's a delay here to allow taking the monitor.
 sleep(0.5)
 for i = 1, 9 do
  local v = neo.requestAccess("x.neo.sys.session")
  sleep(0.5) -- Important timing - allows it to take the monitor
  if v then
   return
  end
 end
 -- ...oh. hope this works then?
 console = {"x.neo.sys.session not found, try Safe Mode."}
 retrieveNssMonitor(screen)
 basicDraw()
 sleep(1)
 shutdown(true)
end

local function initializeSystem()
 -- System has just booted, bristol is in charge
 -- No screen configuration, so just guess.
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
  pcall(gpu.setResolution, gW, gH)
  pcall(gpu.setDepth, gpu.maxDepth()) -- can crash on OCEmu if done at the "wrong time"
 end
 -- Setup the new GPU provider
 gpuG = function () return gpu end
 -- 
 local w = 1
 local steps = {"sys-glacier"}
 for i = 1, 4 do table.insert(steps, "WAIT") end
 table.insert(steps, "INJECT")
 for i = 1, 8 do table.insert(steps, "WAIT") end

 local stepCount = #steps

 neo.scheduleTimer(os.uptime())
 while true do
  local ev = {coroutine.yield()}
  consoleEventHandler(ev)
  if ev[1] == "k.timer" then
   if gpu then
    local bg = 0xFFFFFF
    if w < stepCount then
     local n = math.floor((w / stepCount) * 255)
     bg = (n * 0x10000) + (n * 0x100) + n
    end
    basicDraw(bg)
   end
   if steps[w] then
    if steps[w] == "INJECT" then
     local nsm = neo.requestAccess("x.neo.sys.manage")
     if not nsm then
      table.insert(console, "Settings not available for INJECT.")
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
      neo.emergency("failed start:", steps[w])
      neo.emergency(err)
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
 local nsm = neo.requestAccess("x.neo.sys.manage")
 if nsm then
  console = {"Rebooting for Safe Mode..."}
  basicDraw()
  for _, v in ipairs(nsm.listSettings()) do
   if v ~= "password" then
    nsm.delSetting(v)
   end
  end
 else
  -- assume sysconf.lua did something very bad
  console = {"No NSM. Wiping configuration completely."}
  local fs = neo.requestAccess("c.filesystem")
  if not fs then
   table.insert(console, "Failed to get permission, you're doomed.")
  else
   fs.primary.remove("/data/sys-glacier/sysconf.lua")
  end
  basicDraw()
 end
 -- Do not give anything a chance to alter the new configuration
 shutdownEmergency(true)
 return
end
postPrompt()
