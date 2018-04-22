-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-slaunch: searching launcher
local event = require("event")(neo)
local neoux, err = require("neoux")
if not neoux then error(err) end
neoux = neoux(event, neo)

local running = true

local buttons = {}
local appNames = neo.listApps()
local searchTerm = ""

function searchApps(str)
 local rt = {}
 for k,v in ipairs(appNames) do
  if v:sub(1, 4) == "app-" then
   if v:find(str) then
    rt[#rt+1] = v
    neo.emergency(v)
   end
  end
 end
 return rt
end

function genWindow(apps)
 local wwidth, wheight, wcontents = 1, 1, {}
 for k,v in pairs(apps) do
  appname = v:sub(5)
  if appname:len()+2 > wwidth then
   wwidth = appname:len()+2
  end
  table.insert(wcontents, neoux.tcbutton(1, wheight+1, appname, function(w)
   local pid, err = neo.executeAsync(v)
   if not pid then
    neoux.startDialog(tostring(err), "launchErr")
   else
    w.close()
    running = false
   end
  end))
  wheight = wheight + 1
 end
 wwidth = math.max(wwidth, 11)
 table.insert(wcontents,1,neoux.tcfield(1,1,wwidth,function(nv)
  if not nv then return searchTerm end
  searchTerm = nv
  local sapps = searchApps(searchTerm)
  local fwwidth, fwheight, fwcontents = genWindow(sapps)
  window.reset(fwwidth, fwheight, nil, neoux.tcwindow(fwwidth, fwheight, fwcontents, function(w)
   w.close()
   running = false
  end, 0xFFFFFF, 0))
 end))
 return wwidth, wheight, wcontents
end

wwidth, wheight, wcontents = genWindow(searchApps(searchTerm))
window = neoux.create(wwidth, wheight, nil, neoux.tcwindow(wwidth, wheight, wcontents, function (w)
 w.close()
 running = false
end, 0xFFFFFF, 0))

while running do
 event.pull()
end
