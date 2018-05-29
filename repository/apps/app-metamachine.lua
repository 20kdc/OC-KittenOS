-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-metamachine.lua : Virtual Machine
-- Authors: 20kdc

local loaderPkg, loaderPid, vmName = ...

local icecap = neo.requireAccess("x.neo.pub.base", "fs")

local libVGPU = require("metamachine-vgpu")

local vmBaseCoroutineWrap
local vmComponent, vmComputer, vmOs
local vmEnvironment
local vmSelfdestruct = false
local vmSuperVM = true
local signalStack = {}
local postVMRList = {}

-- File structure:
-- vm-* : Virtual machine configuration
-- vm-

local vmConfiguration = {
 -- true : Physical
 -- {type, ...} : Virtual
 -- NOTE : The following rules are set.
 -- k-computer always exists
 -- k-gpu always exists
 -- k-log always exists
 -- k-tmpfs always exists in non-Super VMs
 ["world"] = {"filesystem", "/", false},
 ["eeprom"] = {"eeprom", "/confboot.lua", "/confdata.bin", "Configurator", true},
 ["screen"] = {"screen", "configurator", 50, 15, 8}
}

if vmName then
 neo.ensurePathComponent("vm-" .. vmName)
 vmSuperVM = false
 local f = icecap.open("/vm-" .. vmName, false)
 vmConfiguration = require("serial").deserialize(f.read("*a"))
 f.close()
 if not vmConfiguration then error("The VM configuration was unloadable.") end
 vmConfiguration["k-tmpfs"] = {"filesystem", "/vt-" .. vmName .. "/", false}
end

local function clone(t)
 if type(t) == "table" then
  local b = {}
  for k, v in pairs(t) do
   b[k] = v
  end
  return b
 end
 return t
end

-- by window ID = {address, internal}
local screensInt = {
}
-- by component address = callback
local screensAll = {
}

local tmpAddress = "k-tmpfs"
local passthroughs = {}
local components = {
 ["k-computer"] = {
  type = "computer",
  beep = function ()
  end,
  start = function ()
   return false
  end,
  stop = function ()
   vmSelfdestruct = true
   coroutine.yield(0.05)
  end,
  isRunning = function ()
   return true
  end,
  getProgramLocations = function ()
   -- Entries of {"file", "lootdisk"}
   return {}
  end
 },
 ["k-gpu"] = libVGPU.newGPU(screensAll),
 ["k-log"] = {
  type = "ocemu",
  log = neo.emergency
 }
}
-- Clones of components made on-demand.
local proxies = {}
setmetatable(proxies, {__mode = "v"})

vmComponent = {
 list = function (filter, exact)
  -- This is an iterator :(
  local t = {}
  for k, v in pairs(components) do
   local ok = false
   if filter then
    if v.type == filter or ((not exact) and v.type:match(filter, 1, true)) then
     ok = true
    end
   else
    ok = true
   end
   if ok then
    table.insert(t, {k, v.type})
   end
  end
  return function ()
   local tr1 = table.remove(t, 1)
   if not tr1 then return end
   return table.unpack(tr1)
  end, 9, nil
 end,
 invoke = function (com, me, ...)
  if not components[com] then error("no component " .. com) end
  if not components[com][me] then error("no method " .. com .. "." .. me) end
  return components[com][me](...)
 end,
 proxy = function (com)
  if not components[com] then
   return nil, "no such component"
  end
  local p = proxies[com]
  if p then return p end
  p = clone(components[com])
  p.address = com
  p.fields = {}
  p.slot = 0
  proxies[com] = p
  return p
 end,
 type = function (com)
  if not components[com] then
   return nil, "no such component"
  end
  return components[com].type
 end,
 methods = function (com)
  local mt = {}
  for k, v in pairs(components[address]) do
   if type(v) == "function" then
    mt[k] = true
   end
  end
  return mt
 end,
 fields = function (com)
  -- This isn't actually supported,
  --  because fields are bad-sec nonsense.
  -- Luckily, everybody knows this, so nobody uses them.
  return {}
 end,
 doc = function (address, method)
  if not components[address] then
   error("No such component " .. address)
  end
  if not components[address][method] then
   error("No such method " .. method)
  end
  return tostring(components[address][method])
 end
}

-- Prepare configured components
local insertionCallbacks = {
 ["screen"] = function (address, title, w, h, d)
  local activeLines = {}
  local scrW = neo.requireAccess("x.neo.pub.window", "primary window")(w, h, title)
  local gpuC, scrI, scrC
  gpuC, scrI, scrC = libVGPU.newBuffer(scrW, {address .. "-kb"}, w, h, function (nw, nh)
   table.insert(signalStack, {"screen_resized", address, nw, nh})
  end, function (l)
   if activeLines[l] then
    return
   end
   activeLines[l] = true
   table.insert(postVMRList, function ()
    scrI.line(l)
    activeLines = {}
   end)
  end)
  components[address] = scrC
  components[address .. "-kb"] = {type = "keyboard"}
  screensInt[scrW.id] = {address, scrI}
  screensAll[address] = gpuC
 end,
 ["eeprom"] = function (address, boot, data, name, ro)
  local codeSize = 4096
  local dataSize = 256
  local function getCore(fd)
   local f = icecap.open(fd, false)
   if not f then return "" end
   local contents = f.read("*a")
   f.close()
   return contents
  end
  local function setCore(fd, size, contents)
   checkArg(1, contents, "string")
   if #contents > size then return nil, "too large" end
   if ro then
    return nil, "storage is readonly"
   end
   local f = icecap.open(fd, true)
   if not f then return nil, "storage is readonly" end
   f.write(contents)
   f.close()
   return true
  end
  components[address] = {
   type = "eeprom",
   get = function ()
    return getCore(boot)
   end,
   set = function (contents)
    return setCore(boot, codeSize, contents)
   end,
   makeReadonly = function ()
    ro = true
    return true
   end,
   getChecksum = function ()
    return "00000000"
   end,
   getSize = function ()
    return codeSize
   end,
   getDataSize = function ()
    return dataSize
   end,
   getData = function ()
    return getCore(data)
   end,
   setData = function ()
    return setCore(data, dataSize, contents)
   end
  }
 end,
 ["filesystem"] = function (address, path, ro)
  components[address] = require("metamachine-vfs")(icecap, address, path, ro)
 end
}

for k, v in pairs(vmConfiguration) do
 if type(v) == "string" then
  local root = neo.requireAccess("k.root", "component passthrough")
  local ty = root.component.type(k)
  if ty then
   passthroughs[k] = true
   components[k] = root.component.proxy(k)
   if ty == "screen" then
    -- Need to ensure the screen in question is for the taking
    local div = neo.requireAccess("x.neo.sys.session", "ability to divorce screens")
    div.disclaimMonitor(k)
    local div2 = neo.requireAccess("x.neo.sys.screens", "ability to claim screens")
    screensAll[k] = div2.claim(k)
    assert(screensAll[k], "Hardware screen " .. k .. " unavailable.")
   end
  end
 else
  assert(insertionCallbacks[v[1]], "Cannot insert virtual " .. v[1])
  insertionCallbacks[v[1]](k, table.unpack(v, 2))
 end
end

vmOs = clone(os)

vmComputer = {}
vmComputer.shutdown = function (...)
 vmSelfdestruct = true
 coroutine.yield(0.05)
end
vmComputer.pushSignal = function (...)
 table.insert(signalStack, {...})
end
vmComputer.pullSignal = function (time)
 if not signalStack[1] then
  if type(time) == "number" then
   time = time + os.uptime()
   coroutine.yield(time)
   if not signalStack[1] then
    return
   end
  else
   while not signalStack[1] do
    coroutine.yield(math.huge)
   end
  end
 end
 return table.unpack(table.remove(signalStack, 1))
end

vmComputer.totalMemory = os.totalMemory
vmOs.totalMemory = nil
vmComputer.freeMemory = os.freeMemory
vmOs.freeMemory = nil
vmComputer.energy = os.energy
vmOs.energy = nil
vmComputer.maxEnergy = os.maxEnergy
vmOs.maxEnergy = nil
vmComputer.uptime = os.uptime
vmOs.uptime = nil
vmComputer.address = os.address
vmOs.address = nil

vmComputer.isRobot = function ()
 return false
end
vmComputer.address = function ()
 return "k-computer"
end
vmComputer.tmpAddress = function ()
 return tmpAddress
end

vmComputer.getBootAddress = function ()
 return "k-eeprom"
end
vmComputer.setBootAddress = function ()
end
vmComputer.users = function ()
 return {}
end
vmComputer.addUser = function ()
 return false, "user support not available"
end
vmComputer.removeUser = function ()
 return false, "user support not available"
end
vmComputer.beep = function (...)
 return vmComponent.invoke("k-computer", "beep", ...)
end
vmComputer.getDeviceInfo = function (...)
 return vmComponent.invoke("k-computer", "getDeviceInfo", ...)
end
vmComputer.getProgramLocations = function (...)
 return vmComponent.invoke("k-computer", "getProgramLocations", ...)
end
vmComputer.getArchitectures = function (...)
 return vmComponent.invoke("k-computer", "getArchitectures", ...)
end
vmComputer.getArchitecture = function (...)
 return vmComponent.invoke("k-computer", "getArchitecture", ...)
end
vmComputer.setArchitecture = function (...)
 return vmComponent.invoke("k-computer", "setArchitecture", ...)
end

vmUnicode = clone(unicode)
vmUnicode.safeTextSupport = nil
vmUnicode.undoSafeTextSupport = nil

vmEnvironment = {
 _VERSION = _VERSION,
 component = vmComponent,
 computer = vmComputer,
 table = clone(table),
 math = clone(math),
 string = clone(string),
 unicode = vmUnicode,
 -- Scheme here:
 -- A yield's first argument is nil for an actual yield,
 --  or the time to add a timer at (math.huge if no timeout) for a pullSignal.
 -- This is not exactly the same, but is very similar, to that of machine.lua,
 --  differing mainly in how pullSignal timeout scheduling occurs.
 coroutine = {
  yield = function (...)
   return coroutine.yield(nil, ...)
  end,
  -- The way this is defined by machine.lua makes it true even when it arguably shouldn't be. Oh well.
  isyieldable = coroutine.isyieldable,
  status = coroutine.status,
  create = function (f)
   return coroutine.create(function (...)
    return nil, f(...)
   end)
  end,
  running = coroutine.running,
  wrap = function (f)
   local pf = coroutine.wrap(function (...)
    return nil, f(...)
   end)
   return function (...)
    local last = {...}
    while true do
     local tabpack = {pf(table.unpack(last))}
     if not tabpack[1] then
      return table.unpack(tabpack, 2)
     end
     last = {coroutine.yield(tabpack[1])}
    end
   end
  end,
  resume = function (co, ...)
   local last = {...}
   while true do
    local tabpack = {coroutine.resume(co, table.unpack(last))}
    if not tabpack[1] then
     neo.emergency(co, table.unpack(tabpack))
     return table.unpack(tabpack)
    elseif not tabpack[2] then
     return tabpack[1], table.unpack(tabpack, 3)
    end
    last = {coroutine.yield(tabpack[2])}
   end
  end
 },
 os = vmOs,
 debug = clone(debug),
 bit32 = clone(bit32),
 utf8 = clone(utf8),
 assert = assert,
 ipairs = ipairs,
 next = next,
 load = function (a, b, c, d)
  if rawequal(d, nil) then
   d = vmEnvironment
  end
  return load(a, b, c, d)
 end,

 pairs = pairs,       pcall = function (...)
  local r = {pcall(...)}
  if not r[1] then
   neo.emergency("pcall error:", table.unpack(r, 2))
  end
  return table.unpack(r)
 end,
 xpcall = xpcall,     select = select,
 type = type,         error = error,
 tonumber = tonumber, tostring = tostring,

 setmetatable = setmetatable, getmetatable = getmetatable,
 rawset = rawset, rawget = rawget,
 rawlen = rawlen, rawequal = rawequal,
 checkArg = checkArg
}
vmEnvironment._G = vmEnvironment

if vmSuperVM then
 vmEnvironment._MMstartVM = function (vmName)
  neo.executeAsync("app-metamachine", vmName)
 end
 vmEnvironment._MMserial = function (...)
  return require("serial").serialize(...)
 end
 vmEnvironment._MMdeserial = function (...)
  return require("serial").deserialize(...)
 end
 vmEnvironment.print = neo.emergency
 local root = neo.requestAccess("k.root")
 if root then
  vmEnvironment._MMcomList = root.component.list
 else
  vmEnvironment._MMcomList = function ()
   return function ()
   end
  end
 end
end

-- bootstrap

vmBaseCoroutineWrap = coroutine.wrap(function ()
 vmBaseCoroutine = coroutine.running()
 local eepromAddress = vmComponent.list("eeprom")()
 if not eepromAddress then
  error("No EEPROM")
 end
 local code = vmComponent.invoke(eepromAddress, "get")
 local res, f = load(code, "=eeprom", "t", vmEnvironment)
 if not res then
  error(f)
 else
  res()
 end
end)

while ((not vmBaseCoroutine) or (coroutine.status(vmBaseCoroutine) ~= "dead")) and not vmSelfdestruct do
 local details = {vmBaseCoroutineWrap()}
 while postVMRList[1] do
  table.remove(postVMRList, 1)()
 end
 if details[1] then
  local checkTimer = nil
  if details[1] ~= math.huge then
   checkTimer = neo.scheduleTimer(details[1])
   --neo.emergency("metamachine timer " .. details[1])
  else
   --neo.emergency("metamachine HANG")
  end
  while true do
   local ev = {coroutine.yield()}
   if ev[1] == "k.timer" then
    if ev[2] == checkTimer then
     break
    end
   elseif ev[1]:sub(1, 2) == "h." then
    if passthroughs[ev[2]] then
     ev[1] = ev[1]:sub(3)
     table.insert(signalStack, ev)
     break
    end
   elseif ev[1] == "x.neo.pub.window" then
    local id = ev[2]
    if ev[3] == "key" then
     if ev[6] then
      table.insert(signalStack, {"key_down", screensInt[id][1] .. "-kb", ev[4], ev[5], "neo"})
     else
      table.insert(signalStack, {"key_up", screensInt[id][1] .. "-kb", ev[4], ev[5], "neo"})
     end
     break
    elseif ev[3] == "line" then
     screensInt[id][2].line(ev[4])
    elseif ev[3] == "touch" or ev[3] == "drag" or ev[3] == "drop" or ev[3] == "scroll" then
     local x = ev[4]
     local y = ev[5]
     if screensInt[id][2].precise then
      x = (x - 1) + ev[6]
      y = (y - 1) + ev[7]
     end
     table.insert(signalStack, {ev[3], screensInt[id][1], x, y, ev[8], "neo"})
     break
    elseif ev[3] == "close" then
     return
    end
   end
  end
 else
  error("Yield in root coroutine")
 end
end
