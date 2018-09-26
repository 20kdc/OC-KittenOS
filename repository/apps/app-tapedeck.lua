-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-tapedeck.lua : Computronics Tape interface.
-- Added note: Computerized record discs aren't available, so it can't be called vinylscratch.
-- Authors: 20kdc

local tapes = {}
for v in neo.requireAccess("c.tape_drive", "tapedrives").list() do
 table.insert(tapes, v)
end

local tapeRate = 4096

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

local downloadCancelled = false

local genPlayer -- used to return to player

local function genDownloading(inst)
 local lclLabelText = {"downloading..."}
 local lclLabel = neoux.tcrawview(1, 1, lclLabelText)
 local thr = {
  "/",
  "-",
  "\\",
  "|"
 }
 local thri = 0
 updateTick = function ()
  lclLabelText[1] = "downloading... " .. (inst.getPosition() / (1024 * 1024)) .. "MB " .. thr[(thri % #thr) + 1]
  thri = thri + 1
  lclLabel.update(window)
 end
 return 40, 1, nil, neoux.tcwindow(40, 1, {
  lclLabel
 }, function (w)
  downloadCancelled = true
 end, 0xFFFFFF, 0)
end

local function doINetThing(inet, url, inst)
 inet = inet.list()()
 assert(inet, "No available card")
 inst.stop()
 inst.seek(-inst.getSize())
 downloadCancelled = false
 downloadPercent = 0
 window.reset(genDownloading(inst))
 local req = assert(inet.request(url))
 req.finishConnect()
 local tapePos = 0
 local tapeSize = inst.getSize()
 while (not downloadCancelled) and tapePos < tapeSize do
  local n, n2 = req.read(neo.readBufSize)
  if not n then
   if n2 then
    req.close()
    error(n2)
   end
   break
  elseif n == "" then
   event.sleepTo(os.uptime() + 0.05)
  else
   inst.write(n)
   tapePos = tapePos + #n
  end
 end
 req.close()
 inst.seek(-inst.getSize())
end

local function genWeb(inst)
 updateTick = nil
 local url = ""
 local lockout = false
 return 40, 3, nil, neoux.tcwindow(40, 3, {
  neoux.tcrawview(1, 1, {"URL to write to tape?"}),
  neoux.tcfield(1, 2, 40, function (t)
   url = t or url
   return url
  end),
  neoux.tcbutton(1, 3, "Download & Write", function (w)
   lockout = true
   local inet = neo.requestAccess("c.internet")
   lockout = false
   if inet then
    local ok, err = pcall(doINetThing, inet, url, inst)
    if not ok then
     neoux.startDialog("Couldn't download: " .. tostring(err), "error")
    end
   end
   w.reset(genPlayer(inst))
  end)
 }, function (w)
  w.reset(genPlayer(inst))
 end, 0xFFFFFF, 0)
end

-- The actual main UI --
genPlayer = function (inst)
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
  local tapePos = 0
  while tapePos < tapeSize do
   if mode then
    local data = inst.read(neo.readBufSize)
    if not data then break end
    tapePos = tapePos + #data
    local res, ifo = fh.write(data)
    if not res then
     neoux.startDialog(tostring(ifo), "issue")
     break
    end
   else
    local data = fh.read(neo.readBufSize)
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
  neoux.tcrawview(1, 1, {
   "Label:",
   "Contents:"
  }),
  neoux.tcfield(7, 1, 34, function (tx)
   if tx then
    inst.setLabel(tx)
    cachedLabel = tx
   end
   return cachedLabel
  end),
  {
   x = 1,
   y = 5,
   w = 40,
   h = 1,
   selectable = true,
   line = function (w, x, y, lined, bg, fg, selected)
    local lx = ""
    local pos = inst.getPosition()
    local sz = inst.getSize()
    if inst.isReady() then
     -- Show a bar
     local tick = sz / 23
     for i = 1, 23 do
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
    local sec = pos / tapeRate
    local secz = sz / tapeRate
    lx = lx .. string.format(" %03i:%02i / %03i:%02i ",
     math.floor(sec / 60), math.floor(sec) % 60,
     math.floor(secz / 60), math.floor(secz) % 60)
    if selected then bg, fg = fg, bg end
    window.span(x, y, lx, bg, fg)
   end,
   key = function (w, update, a, b, c, kf)
    local amount = tapeRate * 10
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
  neoux.tcrawview(33, 3, {
   "% Volume"
  }),
  neoux.tcrawview(20, 3, {
   "% Speed"
  }),
  pcbox(15, 3, 25, 200, "spd", inst.setSpeed),
  pcbox(28, 3, 0, 100, "vol", inst.setVolume),
  neoux.tcrawview(1, 4, {
   "Seeker: use ◃/▹ (shift goes faster)"
  }),
  neoux.tcbutton(1, 3, "«", function (w)
   inst.seek(-inst.getSize())
  end),
  neoux.tcbutton(11, 3, "»", function (w)
   inst.seek(inst.getSize())
  end),
  neoux.tcbutton(4, 3, ((inst.getState() == "PLAYING") and "Pause") or "Play", function (w)
   pausePlay()
  end),
  -- R/W buttons
  neoux.tcbutton(11, 2, "Read", function (w)
   rwButton(true)
  end),
  neoux.tcbutton(17, 2, "Write", function (w)
   rwButton(false)
  end),
  neoux.tcbutton(24, 2, "Write From Web", function (w)
   w.reset(genWeb(inst))
  end)
 }
 updateTick = function ()
  local lcl = cachedLabel
  cachedLabel = inst.getLabel() or ""
  elems[3].update(window)
  if inst.getState() ~= cachedState then
   window.reset(genPlayer(inst))
  elseif lcl ~= cachedLabel then
   elems[2].update(window)
  end
 end
 local n = neoux.tcwindow(40, 5, elems, function (w)
  updateTick = nil
  running = false
  w.close()
 end, 0xFFFFFF, 0)
 return 40, 5, inst.address, function (a, ...)
  if a == "focus" then
   focused = (...) or true
  end
  return n(a, ...)
 end
end
local function genList()
 local elems = {}
 for k, v in ipairs(tapes) do
  elems[k] = neoux.tcbutton(1, k, v.address:sub(1, 38), function (w)
   window.reset(genPlayer(v))
  end)
 end
 tapes = nil
 return 40, #elems, nil, neoux.tcwindow(40, #elems, elems, function (w)
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
