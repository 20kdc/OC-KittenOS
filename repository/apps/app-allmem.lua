-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

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
