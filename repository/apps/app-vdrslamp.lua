-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- svc-vdrslamp.lua : Virtual Redstone Lamp
-- Authors: 20kdc

local vdev = neo.requireAccess("x.svc.virtudev", "lamp dev")

local evr = neo.requireAccess("x.neo.pub.window", "the lamp")
local wnd = evr(12, 6)

local bLine = (" "):rep(12)

local function blank()
 return 0
end

local total = 0

vdev.install({
 type = "redstone",
 address = "vdrslamp-" .. neo.pid,
 slot = 0,
 getWakeThreshold = blank,
 setWakeThreshold = blank,
 getInput = blank,
 getOutput = function (i)
  return total
 end,
 setOutput = function (i, v)
  total = v
  wnd.setSize(12, 6)
 end
})

while true do
 local e = {coroutine.yield()}
 if e[1] == "x.neo.pub.window" then
  if e[3] == "close" then
   -- the ignorance of unregistration is deliberate
   -- a working impl. will properly recover
   return
  elseif e[3] == "line" then
   local bg = 0xFFFFFF
   if total == 0 then bg = 0 end
   wnd.span(1, e[4], bLine, bg, bg)
  end
 end
end
