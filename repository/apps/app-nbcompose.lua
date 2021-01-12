-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- app-nbcompose.lua : Music!
-- Authors: 20kdc

local nb = neo.requireAccess("c.iron_noteblock", "noteblocks").list()()
local ic = neo.requireAccess("x.neo.pub.base", "fs")

local event = require("event")(neo)
local neoux = require("neoux")(event, neo)

local iTranslation = {
 [0] = 0, -- piano / air (def)
 4, -- double bass / wood (def)
 1, -- bass drum / stone (def)
 2, -- snare drum / sand (def)
 3,  -- click / glass (def)
-- JUST GIVE UP
 4, -- guitar / wool 
 5, -- flute / clay
 6, -- bell / gold
 6, -- chime / pice
 6, -- xylo / bone
}
local instKey = {
 [2] = 0,
 [3] = 1,
 [4] = 2,
 [5] = 3,
 [6] = 4,
 [144] = 5,
 [7] = 5,
 [8] = 6,
 [9] = 7,
 [10] = 8,
 [11] = 9
}
local noteKey = "1q2w3er5t6yu8i9o0pzsxdcvg"
-- Application State
local fileData
local uptime = os.uptime()
local songPosition = 0
local selectionL, selectionR = -8, -9
local running = true
local playing = false
local timerExistsFlag = false
local window
local defInst = 0
--
local tick -- Tick function for timer making

local file = require("knbs").new()
-- Window width is always 50. Height is layers + 3, for the top bar.

local theStatusBar, theNotePane, genMain

local function updateStatusAndPane()
 if theStatusBar.update then theStatusBar.update(window) end
 if theNotePane then
  for _, v in ipairs(theNotePane) do
   v.update(window)
  end
 end
end

local function commonKey(a, c, f)
 if a == 32 then
  playing = not playing
  theStatusBar.update(window)
  if playing then
   if not timerExistsFlag then
    uptime = os.uptime()
    event.runAt(uptime, tick)
    timerExistsFlag = true
   end
  end
 elseif a == 91 then
  selectionL = songPosition
  updateStatusAndPane()
 elseif a == 93 then
  selectionR = songPosition
  updateStatusAndPane()
 elseif c == 203 and (f.shift or f.rshift) then
  songPosition = 0
  updateStatusAndPane()
 elseif c == 205 and (f.shift or f.rshift) then
  songPosition = file.length
  updateStatusAndPane()
 elseif c == 203 then
  songPosition = math.max(0, songPosition - 1)
  updateStatusAndPane()
 elseif c == 205 then
  songPosition = songPosition + 1
  updateStatusAndPane()
 end
end

theStatusBar = {
 x = 1,
 y = 3,
 w = 50,
 h = 1,
 selectable = true,
 line = function (window, x, y, lined, bg, fg, selected)
  if selected then
   bg, fg = fg, bg
  end
  window.span(x, y, ((playing and "Playing") or "Paused") .. " (SPACE) ; " .. (songPosition + 1) .. "/" .. file.length .. " ([Shift-]←/→)", bg, fg)
 end,
 key = function (window, update, a, c, d, f)
  if not d then return end
  commonKey(a, c, f)
 end
}

local function genLayers()
 theStatusBar.update = nil
 theNotePane = nil
 local layers = {}
 for i = 1, file.height do
  local layer = i - 1
  table.insert(layers, neoux.tcfield(1, i + 1, 40, function (tx)
   file.layers[layer][1] = tx or file.layers[layer][1]
   return file.layers[layer][1]
  end))
  table.insert(layers, neoux.tcrawview(42, i + 1, {"Vol."}))
  table.insert(layers, neoux.tcfield(46, i + 1, 5, function (tx)
   if tx then
    file.layers[layer][2] = math.max(0, math.min(255, math.floor(tonumber(tx) or 0)))
   end
   return tostring(file.layers[layer][2])
  end))
 end
 return 50, file.height + 1, nil, neoux.tcwindow(50, file.height + 1, {
  neoux.tcbutton(1, 1, "Purge Extra Layers", function (w)
   local knbs = require("knbs")
   local layerCount = knbs.correctSongLH(file)
   knbs.resizeLayers(file, layerCount)
   w.reset(genLayers())
  end),
  neoux.tcbutton(21, 1, "Del.Last", function (w)
   require("knbs").resizeLayers(file, file.height - 1)
   w.reset(genLayers())
  end),
  neoux.tcbutton(31, 1, "Append", function (w)
   require("knbs").resizeLayers(file, file.height + 1)
   w.reset(genLayers())
  end),
  table.unpack(layers)
 }, function (w)
  w.reset(genMain())
 end, 0xFFFFFF, 0)
end
function genMain()
 theNotePane = {}
 for l = 1, file.height do
  local layer = l - 1
  theNotePane[l] = {
   x = 1,
   y = 3 + l,
   w = 50,
   h = 1,
   selectable = true,
   line = function (window, x, y, lined, bg, fg, selected)
    if selected then
     bg, fg = fg, bg
    end
    local text = ""
    for i = 1, 5 do
     local noteL, noteR = " ", " "
     local tick = songPosition + i - 3
     if songPosition == tick then
      noteL = "["
      noteR = "]"
     end
     if selectionR >= selectionL then
      if selectionL == tick then
       noteL = "{"
      end
      if selectionR == tick then
       noteR = "}"
      end
     end
     text = text .. noteL
     local fd = file.ticks[tick]
     fd = fd and fd[layer]
     if fd then
      text = text .. string.format("   %02i/%02i", fd[1], fd[2])
     else
      text = text .. "        "
     end
     text = text .. noteR
    end
    window.span(x, y, text, bg, fg)
   end,
   key = function (window, update, a, c, d, f)
    if not d then return end
    commonKey(a, c, f)
    if a == 8 then
     if file.ticks[songPosition] then
      file.ticks[songPosition][layer] = nil
      require("knbs").correctSongLH(file)
      update()
      theStatusBar.update(window)
     end
    elseif instKey[c] and (f.shift or f.rshift) then
     file.ticks[songPosition] = file.ticks[songPosition] or {}
     defInst = instKey[c]
     local nt = 45
     if file.ticks[songPosition][layer] then
      file.ticks[songPosition][layer][1] = defInst
      nt = file.ticks[songPosition][layer][2]
     end
     if nb then
      nb.playNote(iTranslation[defInst] or 0, nt - 33, file.layers[layer][2] / 100)
     end
     require("knbs").correctSongLH(file)
     update()
     theStatusBar.update(window)
    elseif a >= 0 and a < 256 and noteKey:find(string.char(a), 1, true) then
     file.ticks[songPosition] = file.ticks[songPosition] or {}
     local note = noteKey:find(string.char(a), 1, true) - 1
     file.ticks[songPosition][layer] = {defInst, note + 33}
     if nb then
      nb.playNote(iTranslation[defInst] or 0, note, file.layers[layer][2] / 100)
     end
     require("knbs").correctSongLH(file)
     update()
     theStatusBar.update(window)
    elseif a == 123 then
     if selectionR >= selectionL then
      local storage = {}
      for i = selectionL, selectionR do
       storage[i] = file.ticks[i] and file.ticks[i][layer] and {table.unpack(file.ticks[i][layer])}
      end
      for i = selectionL, selectionR do
       local p = songPosition + (i - selectionL)
       file.ticks[p] = file.ticks[p] or {}
       file.ticks[p][layer] = storage[i]
      end
      require("knbs").correctSongLH(file)
      update()
      theStatusBar.update(window)
     end
    end
   end
  }
 end
 -- We totally lie about the height here to tcwindow. "Bit of a cheat, but who's counting", anyone?
 -- It is explicitly documented that the width and height are for background drawing, BTW.
 return 50, file.height + 3, nil, neoux.tcwindow(50, 3, {
  neoux.tcfield(1, 1, 20, function (tx)
   file.name = tx or file.name
   return file.name
  end),
  neoux.tcfield(21, 1, 15, function (tx)
   file.transcriptor = tx or file.transcriptor
   return file.transcriptor
  end),
  neoux.tcfield(36, 1, 15, function (tx)
   file.songwriter = tx or file.songwriter
   return file.songwriter
  end),
  neoux.tcbutton(1, 2, "New", function (w)
   file = require("knbs").new()
   songPosition = 0
   playing = false
   window.reset(genMain())
  end),
  neoux.tcbutton(6, 2, "Load", function (w)
   neoux.fileDialog(false, function (f)
    if not f then return end
    file = nil
    file = require("knbs").deserialize(f.read("*a"))
    f.close()
    songPosition = 0
    playing = false
    window.reset(genMain())
   end)
  end),
  neoux.tcbutton(12, 2, "Save", function (w)
   neoux.fileDialog(true, function (f)
    if not f then return end
    require("knbs").serialize(file, f.write)
    f.close()
   end)
  end),
  neoux.tcbutton(18, 2, "Ds.L", function (w)
   neoux.fileDialog(false, function (f)
    if not f then return end
    file.description = f.read("*a")
    f.close()
   end)
  end),
  neoux.tcbutton(24, 2, "Ds.S", function (w)
   neoux.fileDialog(true, function (f)
    if not f then return end
    f.write(file.description)
    f.close()
   end)
  end),
  neoux.tcbutton(30, 2, "Layers", function (w)
   window.reset(genLayers())
  end),
  neoux.tcrawview(39, 2, {"cT/S"}),
  neoux.tcfield(43, 2, 8, function (tx)
   if tx then
    local txn = tonumber(tx) or 0
    file.tempo = math.min(math.max(0, math.floor(txn)), 65535)
   end
   return tostring(file.tempo)
  end),
  theStatusBar,
  table.unpack(theNotePane)
 }, function (w)
  w.close()
  running = false
 end, 0xFFFFFF, 0)
end

function tick()
 if playing then
  -- Stop the user from entering such a low tempo that stuff freezes by:
  -- 1. Stopping tempo from going too low to cause /0
  -- 2. Ensuring timer is at most 1 second away
  local temp = 1 / math.max(file.tempo / 100, 0.01)
  if os.uptime() >= uptime + temp then
   -- execute at this song position
   if file.ticks[songPosition] and nb then
    for i = 0, file.height - 1 do
     local tck = file.ticks[songPosition][i]
     if tck then
      nb.playNote(iTranslation[tck[1]] or 0, tck[2] - 33, file.layers[i][2] / 100)
     end
    end
   end
   songPosition = songPosition + 1
   if songPosition >= file.length then songPosition = 0 end
   updateStatusAndPane()
   uptime = uptime + temp
  end
  event.runAt(math.min(os.uptime() + 1, uptime + temp), tick)
 else
  timerExistsFlag = false
 end
end
window = neoux.create(genMain())
while running do event.pull() end
