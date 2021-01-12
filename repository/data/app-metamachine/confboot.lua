-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- confboot.lua : VM configuration program
-- Authors: 20kdc

-- _MMstartVM(name)
-- _MMcomList(...)
-- _MMserial(str)
-- _MMdeserial(str)
local screen = component.proxy(component.list("screen", true)())
local gpu = component.proxy(component.list("gpu", true)())
local fs = component.proxy("world")

screen.turnOn()
gpu.bind(screen.address)
gpu.setResolution(50, 15)
gpu.setForeground(0)
gpu.setBackground(0xFFFFFF)

local menu
local currentY

local currentVMId
local currentVM

local genMainMenu, genFSSelector, genEditor

function genFSSelector(cb)
 local fsName = ""
 menu = {
  {" - Select VFS -", function () end},
  {"Cancel", cb},
  {"New FS: ", function ()
   fs.makeDirectory("fs-" .. fsName)
   genFSSelector(cb)
  end, function (text)
   if text then fsName = text end
   return fsName
  end}
 }
 currentY = 2
 local fsl = fs.list("")
 table.sort(fsl)
 for k, v in ipairs(fsl) do
  if v:sub(#v) == "/" and v:sub(1, 3) == "fs-" then
   local id = v:sub(4, #v - 1)
   table.insert(menu, {id, function ()
    cb(id)
   end})
   table.insert(menu, {" Delete", function ()
    fs.remove("fs-" .. id)
    genFSSelector(cb)
   end})
  end
 end
end

local function doVMSave()
 local f = fs.open("vm-" .. currentVMId, "wb")
 if not f then error("VM Save failed...") end
 fs.write(f, _MMserial(currentVM))
 fs.close(f)
end

function genEditor()
 menu = {
--01234567890123456789012345678901234567890123456789
  {" - configuring VM: " .. currentVMId, function () end},
  {"Save & Return", function ()
   doVMSave()
   currentVM, currentVMId = nil
   genMainMenu()
  end},
  {"Save & Launch", function ()
   doVMSave()
   _MMstartVM(currentVMId)
   computer.shutdown()
  end},
  {"Delete", function ()
   fs.remove("vm-" .. currentVMId)
   currentVM, currentVMId = nil
   genMainMenu()
  end},
 } 
 currentY = 3
 for k, v in pairs(currentVM) do
  local v1 = tostring(v)
  if type(v) ~= "string" then
   v1 = "virt. ".. v[1]
  end
  table.insert(menu, {"Del. " .. v1 .. " " .. k, function ()
   currentVM[k] = nil
   genEditor()
  end})
 end
 if not currentVM["k-eeprom"] then
  table.insert(menu, {"+ Virtual EEPROM (R/W, preloaded w/ LUCcABOOT)...", function ()
   currentVM[currentVMId .. "-eeprom"] = {"eeprom", "/vc-" .. currentVMId .. ".lua", "/vd-" .. currentVMId .. ".bin", "VM BIOS", false}
   genEditor()
   -- do file copy now!
   local handleA = fs.open("/lucaboot.lua", "rb")
   local handleB = fs.open("/vc-" .. currentVMId .. ".lua", "wb")
   if not handleA then if handleB then fs.close(handleB) end return end
   if not handleB then fs.close(handleA) return end
   while true do
    local s = fs.read(handleA, 2048)
    if not s then break end
    fs.write(handleB, s)
   end
   fs.close(handleA)
   fs.close(handleB)
  end})
 end
 table.insert(menu, {"+ Virtual FS (R/W)...", function ()
  genFSSelector(function (fsa)
   if fsa then
    currentVM["fs-" .. fsa] = {"filesystem", "/fs-" .. fsa .. "/", false}
   end
   genEditor()
  end)
 end})
 table.insert(menu, {"+ Virtual FS (R/O)...", function ()
  genFSSelector(function (fsa)
   if fsa then
    currentVM[fsa .. "-fs"] = {"filesystem", fsa, true}
   end
   genEditor()
  end)
 end})
 local tx = {
  "+ Screen 50x15:",
  "+ Screen 80x24:",
  "+ Screen 160x49:"
 }
 local txw = {
  50,
  80,
  160
 }
 local txh = {
  15,
  24,
  49
 }
 for i = 1, 3 do
  local cName = currentVMId .. "-screen"
  local nt = 0
  while currentVM[cName] do
   nt = nt + 1
   cName = currentVMId .. "-" .. nt
  end
  table.insert(menu, {tx[i], function ()
   currentVM[cName] = {"screen", cName, txw[i], txh[i], 8}
   genEditor()
  end, function (text)
   if text then cName = text end
   return cName
  end})
 end
 for address, ty in _MMcomList("") do
  if (not currentVM[address]) and ty ~= "gpu" then
   table.insert(menu, {"+ Host " .. ty .. " " .. address, function ()
    currentVM[address] = ty
    genEditor()
   end})
  end
 end
end

function genMainMenu()
 local vmName = ""
 menu = {
--01234567890123456789012345678901234567890123456789
  {" - metamachine configurator -- use keyboard -   ", function () end},
  {"Shutdown", computer.shutdown},
  {"New VM: ", function ()
   local f = fs.open("vm-" .. vmName, "wb")
   if not f then return end
   fs.write(f, _MMserial({
    [vmName .. "-eeprom"] = {"eeprom", "/lucaboot.lua", "/vd-" .. vmName .. ".bin", "LUCcABOOT VM BIOS", true},
    [vmName .. "-screen"] = {"screen", vmName, 50, 15, 8}
   }))
   fs.close(f)
   genMainMenu()
  end, function (text)
   if text then vmName = text end
   return vmName
  end}
 }
 currentY = 3
 local fsl = fs.list("")
 table.sort(fsl)
 for k, v in ipairs(fsl) do
  if v:sub(#v) == "/" then
  elseif v:sub(1, 3) == "vm-" then
   local id = v:sub(4)
   table.insert(menu, #menu, {id, function ()
    local f = fs.open("vm-" .. id, "rb")
    if not f then return end
    local str = ""
    while true do
     local sb = fs.read(f, 2048)
     if not sb then break end
     str = str .. sb
    end
    currentVM = _MMdeserial(str) or {}
    fs.close(f)
    currentVMId = id
    genEditor()
   end})
  end
 end
end

----

genMainMenu()

local function draw()
 gpu.fill(1, 1, 50, 15, " ")
 local camera = math.max(0, math.min(math.floor(currentY - 7), #menu - 15))
 for i = 1, #menu do
  local pfx = "  "
  if currentY == i then
   pfx = "> "
  end
  local pox = ""
  if menu[i][3] then
   pox = menu[i][3]()
  end
  gpu.set(1, i - camera, pfx .. menu[i][1] .. pox)
 end
end

-- Final main loop.
draw()
while true do
 local t = {computer.pullSignal()}
 if t[1] == "key_down" then
  if t[4] == 200 then
   currentY = math.max(1, currentY - 1)
   draw()
  elseif t[4] == 208 then
   currentY = math.min(currentY + 1, #menu)
   draw()
  elseif t[3] == 13 then
   menu[currentY][2]()
   draw()
  elseif t[3] == 8 then
   local tx = menu[currentY][3]()
   menu[currentY][3](unicode.sub(tx, 1, unicode.len(tx) - 1))
   draw()
  elseif t[3] >= 32 then
   if menu[currentY][3] then
    menu[currentY][3](menu[currentY][3]() .. unicode.char(t[3]))
    draw()
   end
  end
 end
end
