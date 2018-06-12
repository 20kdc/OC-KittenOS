-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-batmon: Still not batman.
-- Port of the original 'batmon.lua' from KittenOS Legacy.
local window = neo.requireAccess("x.neo.pub.window", "window")(10, 2)

-- OCE/s, OCE at last check, uptime of last check
local lastChange, lastValue, lastTimer = 0
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
  lastChange = (nv - lastValue) / (os.uptime() - lastTimer)
 end
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
