-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- svc-ghostie.lua : Ghostie the test ghost!
-- Authors: 20kdc

-- Since this should expect to be started on-demand,
--  take precautions here.
-- Specifically, register as soon as possible.
-- While not required, security dialogs can cause a timeout.

local ic = neo.requireAccess("x.neo.pub.base", "to lock x.svc.ghostie")
ic.lockPerm("x.svc.ghostie")

local r = neo.requireAccess("r.svc.ghostie", "ghost registration")

local waiting = 0

r(function (pkg, pid, sendSig)
 -- just totally ignore the details
 return function ()
  neo.scheduleTimer(os.uptime() + 5 + (math.random() * 10))
  waiting = waiting + 1
 end
end)

local computer = neo.requireAccess("k.computer", "scare system")

while true do
 local ev = coroutine.yield()
 if ev == "k.timer" then
  -- boo!
  computer.beep(440, 1)
  waiting = waiting - 1
  if waiting == 0 then
   return
  end
 end
end
