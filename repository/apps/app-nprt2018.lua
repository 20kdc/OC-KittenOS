-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-nprt2018.lua : 3D printing application
-- Authors: 20kdc

local callerPkg, callerPid, sentModel = ...

local event = require("event")(neo)
local neoux = require("neoux")(event, neo)
local tp = neo.requireAccess("c.printer3d", "")
local running = true

local window, genCurrent

local function regen()
 window.reset(genCurrent())
end

local function runModel(mdl, printers, rep)
 if not mdl then return end
 for _, v in ipairs(printers) do
  v.reset()
  v.setLabel(mdl.label or "Block")
  v.setTooltip(mdl.tooltip or "A 3D-printed block.")
  v.setRedstoneEmitter(mdl.emitRedstore or false)
  v.setButtonMode(mdl.buttonMode or false)
  for _, vs in ipairs(mdl.shapes) do
   v.addShape(vs[1], vs[2], vs[3], vs[4], vs[5], vs[6], vs.texture or "", vs.state or false, vs.tint or 0xFFFFFF)
  end
  v.commit(rep)
 end
end

local function gaugeProgress(printers)
 local avg = 0
 local busy = false
 for _, v in ipairs(printers) do
  local state, substate = v.status()
  if state == "idle" then
   avg = avg + 100
  else
   busy = true
   avg = avg + substate
  end
 end
 if not busy then return end
 -- if busy, #printers cannot be 0
 return math.ceil(avg / #printers)
end

local function engagePS2(printers, rep)
 window.close()
 local model = sentModel
 if not model then
  local m = neoux.fileDialog(false)
  if m then
   model = require("serial").deserialize("return " .. m.read("*a"))
   m.close()
  end
 end
 if not model then
  genCurrent = genMain
  window = neoux.create(genCurrent())
  return
 end
 local percent = 0
 genCurrent = function ()
  local str = "Printing... " .. percent .. "%"
  local tx = "printing"
  return #str, 1, tx, function (w, ev, t)
   if ev == "close" then
    for _, v in ipairs(printers) do
     v.reset()
    end
   end
   if ev == "line" then
    if t == 1 then
     w.span(1, 1, str, 0xFFFFFF, 0)
    end
   end
  end
 end
 window = neoux.create(genCurrent())
 runModel(model, printers, rep)
 while true do
  percent = gaugeProgress(printers)
  if not percent then break end
  regen()
  event.sleepTo(os.uptime() + 1)
 end
 window.close()
 if sentModel then
  running = false
 else
  genCurrent = genMain
  window = neoux.create(genCurrent())
 end
end

function genMain()
 local rep = 1
 local elems = {
  neoux.tcrawview(1, 1, {
   "Repeats:        ",
   "Choose Printer: "
  }),
  neoux.tcfield(9, 1, 7, function (tx)
   if tx then rep = math.max(0, math.floor(tonumber(tx) or 0)) end
   return tostring(rep)
  end)
 }
 local max = 16
 local all = {}
 for v in tp.list() do
  table.insert(all, v)
  local us = unicode.safeTextFormat(v.address)
  table.insert(elems, neoux.tcbutton(1, #elems + 1, us, function (w)
   engagePS2({v}, rep)
  end))
  max = math.max(max, unicode.len(us) + 2)
 end
 table.insert(elems, neoux.tcbutton(1, #elems + 1, "All", function (w)
  engagePS2(all, rep)
 end))
 return max, #elems, nil, neoux.tcwindow(max, #elems, elems, function (w)
  running = false
  w.close()
 end, 0xFFFFFF, 0)
end

genCurrent = genMain

window = neoux.create(genCurrent())
while running do
 event.pull()
end
