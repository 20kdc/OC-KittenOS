-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-launcher: The launcher
local event = require("event")(neo)
local neoux, err = require("neoux")
if not neoux then error(err) end -- This app is basically neoux's testcase
neoux = neoux(event, neo)

local running = true

local buttons = {}
local xlen = 0
local appNames = neo.listApps()
for k, v in ipairs(appNames) do
 if v:sub(1, 4) == "app-" then
  local vl = unicode.len(v)
  if xlen < vl then
   xlen = vl
  end
  table.insert(buttons, neoux.tcbutton(1, #buttons + 1, v, function (w)
   -- Button pressed.
   local pid, err = neo.executeAsync(v)
   if not pid then
    neoux.startDialog(tostring(err), "launchErr")
   else
    w.close()
    running = false
   end
  end))
 end
end

neoux.create(xlen + 2, #buttons, nil, neoux.tcwindow(xlen + 2, #buttons, buttons, function (w)
 w.close()
 running = false
end, 0xFFFFFF, 0))

while running do
 event.pull()
end
