-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-claw: Package manager.

-- HTTP-only because OCEmu SUCKS
local source = "http://20kdc.duckdns.org/neo/"

local primaryINet = neo.requestAccess("c.internet")
if primaryINet then primaryINet = primaryINet.list()() end

local function pkgExists(pkg, isApp)
 local b = {}
 if isApp then
  b = neo.listApps()
 else
  b = neo.listLibs()
 end
 for _, v in ipairs(b) do
  if v == pkg then return true end
 end
end

-- global app variables
-- elements:
-- {
--  description,
--  dlURL/nil,
--  localPath,
--  isApp,
-- }
local packages = {}
local packageList = {}
local libList = {} -- removed after scan
local windows = 1
local searchTx = ""
local primaryWindowRegen
--

local event = require("event")(neo)
local neoux, err = require("neoux")
if not neoux then error(err) end
neoux = neoux(event, neo)

local function download(url)
 if not primaryINet then return nil, "no internet" end
 local req, err = primaryINet.request(url)
 if not req then
  return nil, tostring(err)
 end
 local ok, err = req.finishConnect()
 if not req.finishConnect() then
  req.close()
  return nil, tostring(err)
 end
 local dt = ""
 while true do
  local n, n2 = req.read()
  if not n then
   req.close()
   if n2 then
    return nil, n2
   else
    break
   end
  else
   if n == "" then
    -- slightly dangerous, but what can we do?
    event.sleepTo(os.uptime() + 0.05)
   end
   dt = dt .. n
  end
 end
 req.close()
 return dt
end

local function readLocal()
 -- Read apps & libs
 local function isLua(v)
  if v:sub(#v - 3) == ".lua" then
   return v:sub(1, #v - 4)
  end
 end
 for _, pkg in ipairs(neo.listApps()) do
  table.insert(packageList, pkg)
  packages[pkg] = {
   "A pre-installed or self-written process.",
   nil,
   "apps/" .. pkg .. ".lua",
   true
  }
 end
 for _, pkg in ipairs(neo.listLibs()) do
  table.insert(libList, pkg)
  packages[pkg] = {
   "A pre-installed or self-written library.",
   nil,
   "libs/" .. pkg .. ".lua",
   false
  }
 end
end

local function getEntry(name, isApp)
 if packages[name] then
  if packages[name][4] ~= isApp then
   return
  end
 else
  local path = "libs/" .. name .. ".lua"
  if isApp then
   path = "apps/" .. name .. ".lua"
  end
  packages[name] = {"An unknown entry, lost to time.", nil, path, isApp}
  if isApp then
   table.insert(packageList, name)
  else
   table.insert(libList, name)
  end
 end
 return packages[name]
end

local function readWeb()
 local listData, err = download(source .. "list")
 if not listData then
  neoux.startDialog("Couldn't get web index: " .. err, "web", true)
  return
 end
 --neoux.startDialog(listData, "web", false)
 listData = (listData .. "\n"):gmatch(".-\n")
 local function listDataStrip()
  local l = listData()
  if not l then
   return
  end
  l = l:sub(1, #l - 1)
  return l
 end
 while true do
  local l = listDataStrip()
  if not l then return end
  if l == "end" then return end
  local ent = getEntry(l:sub(5), l:sub(1, 4) == "app ")
  if ent then
   ent[1] = listDataStrip() or "PARSE ERROR"
   ent[2] = source .. l:sub(5) .. ".lua"
  end
 end
end

readLocal()
if source then
 readWeb()
end

table.sort(packageList)
table.sort(libList)
for _, v in ipairs(libList) do
 table.insert(packageList, v)
end
libList = nil

local function startPackageWindow(pkg)
 windows = windows + 1
 local downloading = false
 local desc = packages[pkg][1]
 local isApp = packages[pkg][4]
 local isSysSvc = isApp and (pkg:sub(1, 4) == "sys-")
 local isSvc = isSysSvc or (isApp and (pkg:sub(1, 4) == "svc-"))
 local settings
 if isSvc then
  settings = neo.requestAccess("x.neo.sys.manage")
 end
 local function update(w)
  if downloading then return end
  downloading = true
  local fd = download(packages[pkg][2])
  local msg = "Success!"
  if fd then
   local primaryDisk = neo.requestAccess("c.filesystem").primary
   local f = primaryDisk.open(packages[pkg][3], "wb")
   primaryDisk.write(f, fd)
   primaryDisk.close(f)
  else
   msg = "Couldn't download."
  end
  w.close()
  windows = windows - 1
  primaryWindowRegen()
  -- Another event loop so the program won't exit too early.
  neoux.startDialog(msg, pkg, true)
  downloading = false
 end

 local elems = {
  neoux.tcrawview(1, 1, neoux.fmtText(unicode.safeTextFormat(desc), 30)),
 }
 -- {txt, run}
 local buttonbar = {}
 if pkgExists(pkg, isApp) then
  if isApp then
   if not isSvc then
    table.insert(buttonbar, {"Start", function (w)
     neo.executeAsync(pkg)
     w.close()
     windows = windows - 1
    end})
   else
    if not isSysSvc then
     table.insert(buttonbar, {"Start", function (w)
      neo.executeAsync(pkg)
      w.close()
      windows = windows - 1
     end})
    end
    if settings.getSetting("run." .. pkg) == "yes" then
     table.insert(buttonbar, {"Disable", function (w)
      settings.setSetting("run." .. pkg, "no")
      w.close()
      windows = windows - 1
     end})
    else
     table.insert(buttonbar, {"Enable", function (w)
      settings.setSetting("run." .. pkg, "yes")
      w.close()
      windows = windows - 1
     end})
    end
   end
  end
  if packages[pkg][2] then
   table.insert(buttonbar, {"Update", update})
  end
  table.insert(buttonbar, {"Delete", function (w)
   local primaryDisk = neo.requestAccess("c.filesystem").primary
   primaryDisk.remove(packages[pkg][3])
   w.close()
   windows = windows - 1
   primaryWindowRegen()
  end})
 else
  if packages[pkg][2] then
   table.insert(buttonbar, {"Install", update})
  end
 end
 local x = 1
 for _, v in ipairs(buttonbar) do
  local b = neoux.tcbutton(x, 10, v[1], v[2])
  x = x + (#v[1]) + 2
  table.insert(elems, b)
 end
 neoux.create(30, 10, pkg, neoux.tcwindow(30, 10, elems, function (w)
  w.close()
  windows = windows - 1
 end, 0xFFFFFF, 0))
end

local genwin, primaryWindow
local primaryWindowPage = 1
local primaryWindowList = packageList

function primaryWindowRegen()
 primaryWindow.reset(20, 8, genwin(primaryWindowPage, primaryWindowList))
end

genwin = function (page, efList)
 local pages = math.ceil(#efList / 6)
 local elems = {
  neoux.tcbutton(18, 1, "+", function (w)
   if page < pages then
    primaryWindowPage = page + 1
    primaryWindowRegen()
   end
  end),
  neoux.tcrawview(4, 1, {neoux.pad(page .. " / " .. pages, 14, true, true)}),
  neoux.tcbutton(1, 1, "-", function (w)
   if page > 1 then
    primaryWindowPage = page - 1
    primaryWindowRegen()
   end
  end)
 }
 local base = (page - 1) * 6
 for i = 1, 6 do
  local ent = efList[base + i]
  if ent then
   local enttx = ent
   if packages[ent][4] then
    enttx = "A " .. enttx
   else
    enttx = "L " .. enttx
   end
   if pkgExists(ent, packages[ent][4]) then
    if packages[ent][2] then
     enttx = "I" .. enttx
    else
     enttx = "i" .. enttx
    end
   else
    enttx = " " .. enttx
   end
   table.insert(elems, neoux.tcbutton(1, i + 1, unicode.safeTextFormat(enttx), function (w)
    -- Start a dialog
    startPackageWindow(ent)
   end))
  end
 end
 table.insert(elems, neoux.tcfield(1, 8, 11, function (s)
  if s then searchTx = s end
  return searchTx
 end))
 table.insert(elems, neoux.tcbutton(12, 8, "Search!", function (w)
  local n = {}
  for _, v in ipairs(packageList) do
   for i = 1, #v do
    if v:sub(i, i + #searchTx - 1) == searchTx then
     table.insert(n, v)
     break
    end
   end
  end
  primaryWindowPage = 1
  primaryWindowList = n
  primaryWindowRegen()
 end))
 return neoux.tcwindow(20, 8, elems, function (w)
  w.close()
  windows = windows - 1
 end, 0xFFFFFF, 0)
end

primaryWindow = neoux.create(20, 8, "claw", genwin(1, packageList))

while windows > 0 do
 event.pull()
end
