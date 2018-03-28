-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

local event = require("event")(neo)
local neoux = require("neoux")(event, neo)
local braille = require("braille")
local icecap = neo.requireAccess("x.neo.pub.base", "loadimg")
local qt = icecap.open("/logo.data", false)

local lc = {}
local lcdq = {}
local queueSize = 4
if os.totalMemory() > (256 * 1024) then
 queueSize = 40
end
for i = 1, queueSize do
 lcdq[i] = 0
end
local function getLine(y)
 if not lc[y] then
  local idx = (y - 1) * 120
  qt.seek("set", idx)
  if lcdq[1] then
   lc[table.remove(lcdq, 1)] = nil
  end
  table.insert(lcdq, y)
  lc[y] = qt.read(120) or ""
 end
 return lc[y]
end

local running = true

neoux.create(20, 10, nil, neoux.tcwindow(20, 10, {
 braille.new(1, 1, 20, 10, {
  selectable = true,
  get = function (window, x, y, bg, fg, selected, colour)
   local data = getLine(y)
   local idx = ((x - 1) * 3) + 1
   return data:byte(idx) or 255, data:byte(idx + 1) or 0, data:byte(idx + 2) or 255
  end
 }, 1)
}, function (w)
 w.close()
 running = false
end, 0xFFFFFF, 0))

while running do
 event.pull()
end
