-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- app-batmon: Still not batman.
-- Port of the original 'batmon.lua' from KittenOS Legacy.
local window = neo.requireAccess("x.neo.pub.window", "window")(10, 2)

-- OCE/s, OCE at last check, uptime of last timer set, uptime of last check
local lastChange, lastValue, lastTimer, lpTimer = 0
local usage = {
 "[####]:",
 "[###:]:",
 "[### ]:",
 "[##: ]:",
 "[##  ]:",
 "[#:  ]:",
 "[#   ]:",
 "[:   ]:",
 "[    ]:",
 "WARNING"
}
local function getText(y)
 if y == 2 then
  if not lastChange then
   return "Wait..."
  end
  local ind = "Dc. "
  local wc = lastChange
  local wv = os.energy()
  if wc > 0 then
   wc = -wc
   wv = os.maxEnergy() - wv
   ind = "Ch. "
  end
  local m = math.floor((wv / -wc) / 60)
  return ind .. m .. "m"
 end
 local dec = os.energy() / os.maxEnergy()
 -- dec is from 0 to 1.
 local potential = math.floor(dec * #usage)
 if potential < 0 then potential = 1 end
 if potential >= #usage then potential = #usage - 1 end
 return usage[#usage - potential]
end
local function update()
 local nv = os.energy()
 if lastValue then
  lastChange = (nv - lastValue) / (os.uptime() - lpTimer)
 end
 lpTimer = os.uptime()
 lastValue = nv
 lastTimer = os.uptime() + 10
 if lastChange then
  if lastChange > 10 then
   lastTimer = lastTimer - 9
  end
 end
 neo.scheduleTimer(lastTimer)
 window.setSize(10, 2)
end
update()
while true do
 local ev, a, b, c = coroutine.yield()
 if ev == "x.neo.pub.window" then
  if b == "close" then
   return
  elseif b == "line" then
   local tx = getText(c):sub(1, 10)
   window.span(1, c, tx .. (" "):rep(10 - #tx), 0xFFFFFF, 0)
  end
 elseif ev == "k.timer" then
  update()
 end
end
