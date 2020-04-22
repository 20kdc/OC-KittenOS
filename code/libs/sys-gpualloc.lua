-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

return function (
 gpus, screens,
 getMonitorSettings, settings, sRattle, saveSettings,
 announceFreeMonitor, pid, claimed, sendSig,
 monitorClaims, monitorPool, currentGPUUsers, currentGPUBinding,
 address
)
 neo.ensureType(address, "string")
 for k, monitor in ipairs(monitorPool) do
  if monitor.address == address then
   -- find GPU
   local gpu, bestStats = nil, {-math.huge, -math.huge, -math.huge}
   for a, _ in pairs(currentGPUBinding) do
    currentGPUBinding[a] = nil
   end
   for v in gpus() do
    v.bind(monitor.address, false)
    local w, h = v.maxResolution()
    local quality = w * h * v.maxDepth()
    local users = (currentGPUUsers[v.address] or 0)
    local gquality = 0
    for scr in screens() do
     v.bind(scr.address, false)
     w, h = v.maxResolution()
     local squality = w * h * v.maxDepth()
     gquality = math.max(gquality, squality)
    end
    local stats = {quality, -users, -gquality}
    for i = 1, #stats do
     if stats[i] > bestStats[i] then
      gpu = v
      bestStats = stats
      break
     elseif stats[i] < bestStats[i] then
      break
     end
    end
   end
   -- setup monitor
   if gpu then
    monitor.setPrecise(true)
    monitor.turnOn()
    gpu.bind(address, false)
    currentGPUBinding[gpu.address] = address
    local maxW, maxH = gpu.maxResolution()
    local maxD = gpu.maxDepth()
    local w, h, d, t = getMonitorSettings(address)
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
    -- finish up
    gpu = gpu.address
    currentGPUUsers[gpu] = (currentGPUUsers[gpu] or 0) + 1
    local disclaimer = function (wasDevLoss)
     -- we lost it
     monitorClaims[address] = nil
     claimed[address] = nil
     if not wasDevLoss then
      currentGPUUsers[gpu] = currentGPUUsers[gpu] - 1
      table.insert(monitorPool, monitor)
      announceFreeMonitor(address, pid)
     else
      sendSig("lost", address)
     end
    end
    claimed[address] = disclaimer
    monitorClaims[address] = {gpu, disclaimer}
    table.remove(monitorPool, k)
    return function ()
     for v in gpus() do
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
    end, monitor
   end
  end
 end
end

