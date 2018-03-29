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
local xlb = 1
local yp = 1
local appNames = neo.listApps()
for k, v in ipairs(appNames) do
 if v:sub(1, 4) == "app-" then
  local vs = unicode.safeTextFormat(v)
  local vl = unicode.len(vs) + xlb + 1
  if xlen < vl then
   xlen = vl
  end
  table.insert(buttons, neoux.tcbutton(xlb, yp, vs, function (w)
   -- Button pressed.
   local pid, err = neo.executeAsync(v)
   if not pid then
    neoux.startDialog(tostring(err), "launchErr")
   else
    w.close()
    running = false
   end
  end))
  yp = yp + 1
  if yp == 16 then
   yp = 1
   xlb = xlen + 1
  end
 end
end

neoux.create(xlen, math.min(15, #buttons), nil, neoux.tcwindow(xlen, math.min(15, #buttons), buttons, function (w)
 w.close()
 running = false
end, 0xFFFFFF, 0))

while running do
 event.pull()
end
