-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-tapedeck.lua : Computronics Tape interface.
-- Added note: Computerized record discs aren't available, so it can't be called vinylscratch.
-- Authors: 20kdc

local tapes = {}
for v in neo.requireAccess("c.tape_drive", "tapedrives").list() do
 table.insert(tapes, v)
end

local event = require("event")(neo)
local neoux = require("neoux")(event, neo)

-- There's no way to get these, so they get reset
local pcvals = {vol = 100, spd = 100}
local function pcbox(x, y, low, high, id, fun)
 return neoux.tcfield(x, y, 5, function (tx)
  if tx then
   pcvals[id] = math.min(math.max(0, math.floor(tonumber(tx) or 0)), high)
   fun(math.max(pcvals[id], low) / 100)
  end
  return tostring(pcvals[id])
 end)
end

local window
local running = true
local focused = true

local updateTick

local function genPlayer(inst)
 local cachedLabel = inst.getLabel() or ""
 local cachedState = inst.getState()
 local function pausePlay()
  if inst.getState() == "PLAYING" then
   inst.stop()
  else
   inst.play()
  end
  window.reset(genPlayer(inst))
 end
 -- Common code for reading/writing tapes.
 -- Note that it tries to allow playback to resume later.
 local function rwButton(mode)
  local fh = neoux.fileDialog(mode)
  if not fh then return end
  inst.stop()
  local sp = inst.getPosition()
  local tapeSize = inst.getSize()
  inst.seek(-tapeSize)
  local tapeReadBuf = 8192
  local tapePos = 0
  while tapePos < tapeSize do
   if mode then
    local data = inst.read(tapeReadBuf)
    if not data then break end
    tapePos = tapePos + tapeReadBuf
    local res, ifo = fh.write(data)
    if not res then
     neoux.startDialog(tostring(ifo), "issue")
     break
    end
   else
    local data = fh.read(tapeReadBuf)
    if not data then break end
    tapePos = tapePos + #data
    inst.write(data)
   end
  end
  inst.seek(-tapeSize)
  inst.seek(sp)
  fh.close()
 end
 local elems = {
  {
   x = 1,
   y = 5,
   w = 20,
   h = 1,
   selectable = true,
   line = function (w, x, y, lined, bg, fg, selected)
    local lx = ""
    local pos = inst.getPosition()
    if inst.isReady() then
     -- Show a bar
     local tick = inst.getSize() / 13
     for i = 1, 13 do
      local alpos = (tick * i) - (tick / 2)
      if pos > alpos then
       lx = lx .. "="
      else
       lx = lx .. "-"
      end
     end
    else
     lx = "NO TAPE HERE."
    end
    local sec = pos / 4096
    lx = lx .. string.format(" %03i:%02i", math.floor(sec / 60), math.floor(sec) % 60)
    if selected then bg, fg = fg, bg end
    window.span(x, y, lx, bg, fg)
   end,
   key = function (w, update, a, b, c, kf)
    local amount = 40960
    if kf.shift or kf.rshift then
     amount = amount * 24
    end
    if c then
     if a == 32 then
      pausePlay()
     elseif b == 203 then
      inst.seek(-amount)
      update()
      return true
     elseif b == 205 then
      inst.seek(amount)
      update()
      return true
     end
    end
   end
  },
  neoux.tcrawview(14, 3, {
   "% Vol. ",
   "% Speed"
  }),
  pcbox(9, 3, 0, 100, "vol", inst.setVolume),
  pcbox(9, 4, 25, 200, "spd", inst.setSpeed),
  neoux.tcbutton(1, 3, "{", function (w)
   inst.seek(-inst.getSize())
  end),
  neoux.tcbutton(5, 3, "}", function (w)
   inst.seek(inst.getSize())
  end),
  neoux.tcbutton(1, 4, ((inst.getState() == "PLAYING") and "Pause") or "Play", function (w)
   pausePlay()
  end),
  -- R/W buttons
  neoux.tcbutton(1, 2, "Read", function (w)
   rwButton(true)
  end),
  neoux.tcbutton(8, 2, "Write", function (w)
   rwButton(false)
  end),
  neoux.tcfield(1, 1, 20, function (tx)
   if tx then
    inst.setLabel(tx)
    cachedLabel = tx
   end
   return cachedLabel
  end)
 }
 updateTick = function ()
  local lcl = cachedLabel
  cachedLabel = inst.getLabel() or ""
  elems[1].update(window)
  if inst.getState() ~= cachedState then
   window.reset(genPlayer(inst))
  elseif lcl ~= cachedLabel then
   elems[#elems].update(window)
  end
 end
 local n = neoux.tcwindow(20, 5, elems, function (w)
  updateTick = nil
  running = false
  w.close()
 end, 0xFFFFFF, 0)
 return 20, 5, inst.address, function (a, ...)
  if a == "focus" then
   focused = (...) or true
  end
  return n(a, ...)
 end
end
local function genList()
 local elems = {}
 for k, v in ipairs(tapes) do
  elems[k] = neoux.tcbutton(1, k, v.address, function (w)
   window.reset(genPlayer(v))
  end)
 end
 tapes = nil
 return 40, #elems, "choose", neoux.tcwindow(40, #elems, elems, function (w)
  running = false
  w.close()
 end, 0xFFFFFF, 0)
end


window = neoux.create(genList())

-- Timer for time update
local function tick()
 if updateTick then
  updateTick()
 end
 event.runAt(os.uptime() + ((focused and 1) or 10), tick)
end
event.runAt(0, tick)

while running do
 event.pull()
end
