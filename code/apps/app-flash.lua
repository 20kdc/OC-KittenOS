-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

local event = require("event")(neo)
local neoux = require("neoux")(event, neo)

local eeprom = neo.requireAccess("c.eeprom")

-- note: fun coincidence makes this exactly the right size
-- 1234567890123456789012345
-- ABCDEF12 Lua BIOS
-- <get><set> <data> <label>
-- 21FEDCBA Nuclear Disk
-- <get><set> <data> <label>

local running = true

local busy = false

local regenCore

local function regenLabeller(set, get, wd)
 local tx = get()
 return wd, 2, nil, neoux.tcwindow(wd, 1, {
  neoux.tcfield(1, 1, wd, function (nt)
   if nt then
    tx = nt
    set(nt)
   end
   return tx
  end)
 }, function (w)
  busy = false
  w.reset(regenCore())
 end, 0xFFFFFF, 0)
end

function regenCore()
 local elems = {}
 local l = 1
 for v in eeprom.list() do
  local lbl = unicode.safeTextFormat(v.getLabel())
  table.insert(elems, neoux.tcrawview(1, l, {
   require("fmttext").pad(v.address:sub(1, 8) .. " " .. lbl, 25, false, true)
  }))
  table.insert(elems, neoux.tcbutton(1, l + 1, "get", function (window)
   if busy then return end
   busy = true
   local fd = neoux.fileDialog(true)
   if not fd then busy = false return end
   fd.write(v.get())
   fd.close()
   busy = false
   neoux.startDialog("Got the data!", nil, true)
   window.reset(regenCore())
  end))
  table.insert(elems, neoux.tcbutton(6, l + 1, "set", function (window)
   if busy then return end
   busy = true
   local fd = neoux.fileDialog(false)
   if not fd then busy = false return end
   local eepromCode = fd.read("*a")
   fd.close()
   local wasOk, report = v.set(eepromCode)
   report = (wasOk and tostring(report)) or "Flash successful.\nI recommend relabelling the EEPROM."
   busy = false
   neoux.startDialog(report, nil, true)
   window.reset(regenCore())
  end))
  local function dHandler(set, get, wd)
   local setter = v[set]
   local getter = v[get]
   return function (window)
    if busy then return end
    busy = true
    window.reset(regenLabeller(setter, getter, wd))
   end
  end
  table.insert(elems, neoux.tcbutton(12, l + 1, "data", dHandler("setData", "getData", 38)))
  table.insert(elems, neoux.tcbutton(19, l + 1, "label", dHandler("setLabel", "getLabel", 18)))
  l = l + 2
 end
 return 25, l - 1, nil, neoux.tcwindow(25, l - 1, elems, function (w)
  w.close()
  running = false
 end, 0xFFFFFF, 0)
end

local window = neoux.create(regenCore())

while running do
 local s = {event.pull()}
 if (s[1] == "h.component_added" or s[1] == "h.component_removed") and busy then
  -- Anything important?
  if s[3] == "gpu" or s[3] == "screen" then
   window.reset(regenCore())
  end
 end
end
