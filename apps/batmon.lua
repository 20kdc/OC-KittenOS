local math, stat = A.request("math", "stat")
local app = {}
-- How much did energy change
--  over 1 second?
local lastChange = 0
local lastValue = nil
local lastTimer = nil
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
  local wv = stat.energy()
  if wc > 0 then
   wc = -wc
   wv = stat.maxEnergy() - wv
   ind = "Ch. "
  end
  local m = math.floor((wv / -wc) / 60)
  return ind .. m .. "m"
 end
 local dec = stat.energy() / stat.maxEnergy()
 -- dec is from 0 to 1.
 local potential = math.floor(dec * #usage)
 if potential < 0 then potential = 1 end
 if potential >= #usage then potential = #usage - 1 end
 return usage[#usage - potential]
end
function app.key(ka, kc, down)
 if down then
  if ka == ("C"):byte() then
   A.die()
   return false
  end
 end
end
function app.update()
 local nv = stat.energy()
 if lastValue then
  lastChange = (nv - lastValue) / lastTimer
 end
 lastValue = nv
 lastTimer = 10
 if lastChange then
  if lastChange > 10 then
   lastTimer = 1
  end
 end
 A.timer(lastTimer)
 return true
end
function app.get_ch(x, y)
 return getText(y):sub(x, x)
end
return app, 7, 2