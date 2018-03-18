-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-pass: The password setter
local settings = neo.requestAccess("x.neo.sys.manage")
if not settings then error("no management") return end

local event = require("event")(neo)
local neoux, err = require("neoux")
if not neoux then error(err) end
neoux = neoux(event, neo)

local running = true

local pw = settings.getSetting("password")
neoux.create(20, 2, nil, neoux.tcwindow(20, 2, {
 neoux.tcfield(1, 1, 12, function (set)
  if not set then
   return pw
  end
  pw = set
 end),
 neoux.tcbutton(13, 1, "set PW", function (w)
  settings.setSetting("password", pw)
  w.close()
  running = false
 end),
 neoux.tcbutton(1, 2, "log out", function (w)
  w.close()
  running = false
  local session = neo.requestAccess("x.neo.sys.session")
  if not session then return end
  session.endSession(true)
 end),
 neoux.tcbutton(11, 2, "shutdown", function (w)
  w.close()
  running = false
  settings.shutdown(false)
 end)
}, function (w)
 w.close()
 running = false
end, 0xFFFFFF, 0))

while running do
 event.pull()
end
