-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-allmem.lua : Memory usage tester
-- Authors: 20kdc

local value, w = 0
-- Use an event to cleanup load costs
-- We don't care about this event
neo.scheduleTimer(0)
coroutine.yield()

-- Run memory test
pcall(function ()
 local data = ""
 while true do
  data = data .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1)
  -- NOTE: we do not #data outside because that would allow it to live too long
  value = value + 16
 end
end)

value = math.floor(value / 102.4) / 10

value = tostring(value) .. "KiB remaining"
w = neo.requireAccess("x.neo.pub.window", "Windowing")(#value, 1)
while true do
 local ev, a, b = coroutine.yield()
 if ev == "x.neo.pub.window" then
  if b == "line" then
   w.span(1, 1, value, 0xFFFFFF, 0)
  elseif b == "close" then
   w.close()
   return
  end
 end
end
