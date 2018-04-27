-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-launchbar: launchbar with application pinning

local event = require("event")(neo)
local neoux, err = require("neoux")
if not neoux then error(err) end
neoux = neoux(event, neo)

local running = true
local window

local pinned = {}
-- load pinned applications
local icecap = neo.requireAccess("x.neo.pub.base", "load pinned applications")
local w,f = pcall(icecap.open,"/pinned", false)

if w and f then
 local fcontent = f.read("*a")
 for s in fcontent:gmatch("[^\n]+") do
  for k,v in ipairs(neo.listApps()) do
   if v == s then
    pinned[#pinned+1] = s
   end
  end
 end
 f.close()
else
 pinned = {"app-control","app-taskmgr"}
end

local function savePinned() -- saves pinned applications
 local f=icecap.open("/pinned",true)
 if f then
  for k,v in pairs(pinned) do
   f.write(v.."\n")
  end
  f.close()
 end
end

local function isPinned(name)
 local bpinned = false
 for l,m in ipairs(pinned) do
  if m == name then bpinned = l end
 end
 return bpinned
end

local function genAppMenu(autoclose)
 local wwidth, wheight, wcontent = 1, 1, {}
 local applist = neo.listApps()
 for _,app in ipairs(applist) do
  if app:sub(1,4) == "app-" then
   local appname = app:sub(5)
   if appname:len()+2 > wwidth then
    wwidth = appname:len()+2
   end
   table.insert(wcontent,neoux.tcbutton(1, wheight, appname, function (w)
    local pid, err = neo.executeAsync(app)
    if not pid then
     neoux.startDialog(tostring(err), "launchErr")
    else
     if autoclose then
      w.close()
     end
    end
   end))
   wheight = wheight + 1
  end
 end
 local cy = 1
 for _, app in ipairs(applist) do
  if app:sub(1,4) == "app-" then
   local appname = app:sub(5)
   local pinicon = unicode.char(9633)
   if isPinned(app) then
    pinicon = unicode.char(9632)
   end
   table.insert(wcontent, neoux.tcbutton(wwidth+1, cy, pinicon, function(w)
    local bpinned = isPinned(app)
    if not bpinned then
     table.insert(pinned,app)
    else
     table.remove(pinned,bpinned)
    end
    local wc, mx = genLaunchBar()
    window.reset(mx, 1, nil, wc)
    local fwwidth, fwheight, fbuttons = genAppMenu()
    w.reset(fwwidth+3, fwheight, "apps", neoux.tcwindow(fwwidth+3, fwheight, fbuttons, function (w)
     w.close()
    end, 0xFFFFFF, 0))
    savePinned()
   end))
   cy = cy + 1
  end
 end
 return wwidth, wheight, wcontent
end

local function appMenu(autoclose)
 local wwidth, wheight, buttons = genAppMenu(autoclose)
 neoux.create(wwidth+3, wheight, "apps", neoux.tcwindow(wwidth+3, wheight, buttons, function (w)
  w.close()
 end, 0xFFFFFF, 0))
end

function genLaunchBar()
 local buttons = {}
 local mx = 1
 table.insert(buttons,neoux.tcbutton(mx, 1, "disks", function(w)
  neo.executeAsync("app-fm")
 end))
 mx = mx + 7
 table.insert(buttons,neoux.tcbutton(mx, 1, "apps", function(w)
  appMenu()
 end))
 mx = mx + 6
 for k,v in pairs(pinned) do
  local dstr = v:sub(5)
  table.insert(buttons,neoux.tcbutton(mx,1,dstr,function(w)
   neo.executeAsync(v)
  end))
  mx = mx + dstr:len() + 2
 end
 return neoux.tcwindow(mx, 1, buttons, function(w)
  w.close()
  running = false
 end, 0xFFFFFF, 0), mx
end

local wc, mx = genLaunchBar()
window = neoux.create(mx, 1, nil, wc)

while running do
 event.pull()
end
