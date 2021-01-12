-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

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
