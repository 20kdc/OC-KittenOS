-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- lucaboot.lua : Fake EEPROM for VM.
-- Authors: 20kdc

-- LUCcABOOT v0
-- awful name I know

local eprox = component.proxy(component.list("eeprom", true)())
computer.getBootAddress = eprox.getData
computer.setBootAddress = eprox.setData
eprox = nil

local logo = {
 "               ⣀▄⣀               ",
 "           ⣀▄⠶▀⠉ ⠉█⠶▄⣀           ",
 "       ⣀▄⠶▀⠉     ◢◤  ⠉▀⠶▄⣀       ",
 "   ⣀▄⠶▀⠉        ◢◤       ⠉▀⠶▄⣀   ",
 " ◢⠿⣭⣀      meta ◯ machine   ⣀⣭⠿◣ ",
 " █  ⠉▀⠶▄⣀      ◢◤       ⣀▄⠶▀⠉  █ ",
 " █      ⠉▀⠶▄⣀ ◢◤    ⣀▄⠶▀⠉  ⣀▄⠶ █ ",
 " █⣀         ⠉▀⠿▄▄▄⠶▀⠉      ⠉  ⣀█ ",
 "  ⠉▀⠶▄⣀         █         ⣀▄⠶▀⠉  ",
 "      ⠉▀⠶▄⣀     █     ⣀▄⠶▀⠉      ",
 "          ⠉▀⠶▄⣀ █ ⣀▄⠶▀⠉          ",
 "              ⠉▀▀▀⠉              ", -- 12
 "  metamachine virtual computing  ",
 " Press F3 to enter boot manager. ",
 "                                 "
}
local gpuA = component.list("gpu", true)()
local screenA = component.list("screen", true)()
local bootManager = false
if gpuA and screenA then
 local gpuP = component.proxy(gpuA)
 gpuP.bind(screenA)
 gpuP.setResolution(33, 15)
 local targetUptime = computer.uptime()
 for j = 0, 10 do
  targetUptime = targetUptime + 0.1
  local ej = j
  if j > 5 then
   -- 5 * 50 = 250
   ej = 5 - (j - 5)
   ej = ej * 50
  elseif j == 5 then
   targetUptime = targetUptime + 4
   ej = 255
  else
   ej = ej * 50
  end
  gpuP.setForeground(ej + (ej * 0x100) + (ej * 0x10000))
  gpuP.setBackground(0)
  for i = 1, #logo do
   gpuP.set(1, i, logo[i])
  end
  while true do
   local tl = targetUptime - computer.uptime()
   if tl <= 0.01 then break end
   local v = {computer.pullSignal(tl)}
   if v[1] == "key_down" then
    if v[4] == 61 then
     -- boot manager
     bootManager = true
     logo[14] = "  - Entering boot manager now. -  "
     break
    end
   end
  end
 end
 gpuP.setForeground(0xFFFFFF)
 gpuP.setBackground(0)
 local selY = 1
 while bootManager do
  gpuP.fill(1, 1, 33, 15, " ")
  local y = 1
  local mapping = {}
  for a in component.list("filesystem", true) do
   local pfx = " "
   if selY == y then
    pfx = ">"
   end
   if computer.getBootAddress() == a then
    pfx = pfx .. "*"
   else
    pfx = pfx .. " "
   end
   mapping[y] = a
   gpuP.set(1, y, pfx .. a .. ":" .. (component.invoke(a, "getLabel") or ""))
   y = y + 1
  end
  while true do
   local v = {computer.pullSignal()}
   if v[1] == "key_down" then
    if v[4] == 200 then
     selY = math.max(1, selY - 1)
     break
    elseif v[4] == 208 then
     selY = math.min(selY + 1, y - 1)
     break
    elseif v[3] == 13 then
     computer.setBootAddress(mapping[selY] or "")
     bootManager = nil
     break
    end
   end
  end
 end
end
local lr = "(no inits)"
local function boot(fsa)
 local dat = component.proxy(fsa)
 local fh = dat.open("/init.lua", "rb")
 if fh then
  local ttl = ""
  while true do
   local chk = dat.read(fh, 2048)
   if not chk then break end
   ttl = ttl .. chk
  end
  local fn, r = load(ttl, "=init.lua", "t")
  if not fn then
   lr = r
   dat.close(fh)
  else
   dat.close(fh)
   computer.setBootAddress(fsa)
   fn()
   error("Returned from init")
  end
 end
end
if component.type(computer.getBootAddress()) then
 boot(computer.getBootAddress())
end
for a in component.list("filesystem", true) do
 boot(a)
end
error("No available operating systems. " .. lr)

