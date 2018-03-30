-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-control: Settings changer
local settings = neo.requireAccess("x.neo.sys.manage", "management")
local globals = neo.requireAccess("x.neo.pub.globals", "gbm")

local event = require("event")(neo)
local neoux, err = require("neoux")
if not neoux then error(err) end
neoux = neoux(event, neo)

local running = true

local mainGen
local currentGen
local window

local function returner()
 currentGen = mainGen
 window.reset(currentGen())
end

local function scrGen()
 local tx = {}
 local elems = {
 }
 local y = 1
 for k, v in ipairs(globals.getKnownMonitors()) do
  table.insert(tx, v[1]:sub(1, 16) .. "..." )
  table.insert(tx, "")
  table.insert(elems, neoux.tcbutton(21, y, "max", function (w)
   globals.changeMonitorSetup(v[1], 320, 200, 32, v[6])
   globals.forceRescan()
  end))
  local cw, ch = v[3], v[4]
  table.insert(elems, neoux.tcfield(1, y + 1, 5, function (tx)
   if tx then cw = math.max(0, math.floor(tonumber(tx) or 0)) end
   return tostring(cw)
  end))
  table.insert(elems, neoux.tcfield(6, y + 1, 5, function (tx)
   if tx then ch = math.max(0, math.floor(tonumber(tx) or 0)) end
   return tostring(ch)
  end))
  table.insert(elems, neoux.tcbutton(12, y + 1, "set", function (w)
   globals.changeMonitorSetup(v[1], math.max(cw, 1), math.max(ch, 1), v[5], v[6])
   globals.forceRescan()
  end))
  local nx = 8
  if v[5] == 8 then
   nx = 4
  elseif v[5] == 4 then
   nx = 1
  end
  table.insert(elems, neoux.tcbutton(18, y + 1, v[5] .. "b", function (w)
   globals.changeMonitorSetup(v[1], v[3], v[4], nx, v[6])
   globals.forceRescan()
  end))
  local tm = "ti"
  local to = "yes"
  if v[6] == "yes" then
   tm = "TI"
   to = "no"
  end
  table.insert(elems, neoux.tcbutton(22, y + 1, tm, function (w)
   globals.changeMonitorSetup(v[1], v[3], v[4], v[5], to)
   globals.forceRescan()
  end))
  y = y + 2
 end
 table.insert(elems, neoux.tcrawview(1, 1, tx))
 return 25, #tx, nil, neoux.tcwindow(25, #tx, elems, returner, 0xFFFFFF, 0)
end
local function logGen()
 local computer = neo.requireAccess("k.computer", "user management")
 local tx = {
   "Password:",
   " (Keep blank to disable.)",
   "MC Usernames Allowed:"
 }
 local users = table.pack(computer.users())
 for k, v in ipairs(users) do
  tx[k + 3] = " " .. v
 end
 local workingName = ""
 return 25, #tx + 1, nil, neoux.tcwindow(25, #tx + 1, {
  neoux.tcrawview(1, 1, tx),
  neoux.tcfield(11, 1, 15, function (str)
   if str then
    settings.setSetting("password", str)
   end
   return settings.getSetting("password")
  end),
  neoux.tcfield(1, #tx + 1, 19, function (str)
   workingName = str or workingName
   return workingName
  end),
  neoux.tcbutton(20, #tx + 1, "+", function (w)
   local ok, err = computer.addUser(workingName)
   if not ok then
    neoux.startDialog(err)
   end
   w.reset(logGen())
  end),
  neoux.tcbutton(23, #tx + 1, "-", function (w)
   computer.removeUser(workingName)
   w.reset(logGen())
  end),
 }, returner, 0xFFFFFF, 0)
end

local advPage = 1
local advPlusH = false

local function advAsker(info, def, r, parent)
 info = unicode.safeTextFormat(info)
 return function ()
  return 25, 2, nil, neoux.tcwindow(25, 2, {
   neoux.tcrawview(1, 1, {info}),
   neoux.tcfield(1, 2, 25, function (tx)
    def = tx or def
    return def
   end)
  }, function (w)
   r(def)
   currentGen = parent
   w.reset(parent())
  end, 0xFFFFFF, 0)
 end
end

local function advGen()
 local set = settings.listSettings()
 table.sort(set)

 -- things get complicated here...
 local pages = math.max(1, math.ceil(#set / 7))
 advPage = math.max(1, math.min(advPage, pages))
 local elems = {
  neoux.tcbutton(23, 1, "+", function (w)
   advPage = advPage + 1
   w.reset(advGen())
  end),
  neoux.tcrawview(4, 1, {neoux.pad(advPage .. " / " .. pages, 14, true, true)}),
  neoux.tcbutton(1, 1, "-", function (w)
   advPage = advPage - 1
   advPlusH = true
   w.reset(advGen())
  end),
  neoux.tcbutton(18, 1, "add", function (w)
   currentGen = advAsker("setting ID", "my.setting", function (r)
    settings.setSetting(r, "")
   end, currentGen)
   w.reset(currentGen())
  end),
 }
 local ofs = (advPage - 1) * 7
 for i = 1, 7 do
  local s = set[i + ofs]
  if s then
   local tx = s .. "=" .. (settings.getSetting(s) or "")
   table.insert(elems, neoux.tcbutton(1, i + 1, unicode.sub(unicode.safeTextFormat(tx), 1, 20), function (w)
    currentGen = advAsker(s .. ":", settings.getSetting(s) or "", function (r)
     settings.setSetting(s, r)
    end, currentGen)
    w.reset(currentGen())
   end))
   table.insert(elems, neoux.tcbutton(23, i + 1, "-", function (w)
    settings.delSetting(s)
   end))
  end
 end
 local ph
 if advPlusH then
  advPlusH = false
  ph = 3
 end
 return 25, 8, nil, neoux.tcwindow(25, 8, elems, returner, 0xFFFFFF, 0, ph)
end

function mainGen()
 return 25, 8, nil, neoux.tcwindow(25, 8, {
  neoux.tcbutton(1, 1, "Screens", function (window)
   currentGen = scrGen
   window.reset(currentGen())
  end),
  neoux.tcrawview(2, 2, {
   "Size, depth, touchmode."
  }),
  neoux.tcbutton(1, 3, "Login & Access", function (window)
   currentGen = logGen
   window.reset(currentGen())
  end),
  neoux.tcrawview(2, 4, {
   "Allowed users, password."
  }),
  neoux.tcbutton(1, 5, "Advanced Settings", function (window)
   advPage = 1
   currentGen = advGen
   window.reset(currentGen())
  end),
  neoux.tcrawview(2, 6, {
   "The raw settings data."
  }),
  neoux.tchdivider(1, 7, 25),
  neoux.tcbutton(1, 8, "Relog", function (window)
   neo.requireAccess("x.neo.sys.session", "Everest session").endSession(true)
  end),
  neoux.tcbutton(8, 8, "Reboot", function (window)
   settings.shutdown(true)
  end),
  neoux.tcbutton(16, 8, "Shutdown", function (window)
   settings.shutdown(false)
  end),
 }, function ()
  window.close()
  running = false
 end, 0xFFFFFF, 0)
end

currentGen = mainGen

window = neoux.create(currentGen())

while running do
 local src, id, k, v = event.pull()
 if src == "x.neo.sys.manage" then
  if id == "set_setting" then
   window.reset(currentGen())
  end
 end
end
