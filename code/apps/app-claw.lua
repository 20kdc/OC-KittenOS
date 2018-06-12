-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-claw: Package manager.

local ldrPkg, _, tgtPkg = ...

-- libs & such
local event = require("event")(neo)
local neoux = require("neoux")(event, neo)

local primaryINet = neo.requestAccess("c.internet")
if primaryINet then primaryINet = primaryINet.list()() end

--

local function readFile(src, url, ocb)
 local buf = ""
 local function cb(data)
  if not data then
   ocb(buf)
  else
   buf = buf .. data
   buf = buf:gsub("[^\n]*\n", function (t)
    ocb(t:sub(1, -2))
    return ""
   end)
  end
 end
 if type(src) == "string" then
  assert(primaryINet, "no internet")
  local req, err = primaryINet.request(src .. url)
  assert(req, err)
  -- OpenComputers#535
  req.finishConnect()
  while true do
   local n, n2 = req.read(neo.readBufSize)
   cb(n)
   if not n then
    req.close()
    if n2 then
     error(n2)
    else
     cb(nil)
     break
    end
   else
    if n == "" then
     -- slightly dangerous, but what can we do?
     pcall(event.sleepTo, os.uptime() + 0.05)
    end
   end
  end
 else
  if url == "data/app-claw/local.c2l" then
   for _, v in ipairs(src.list("data/app-claw/")) do
    ocb(v)
   end
   return
  end
  local h, e = src.open(url, "rb")
  assert(h, e)
  repeat
   local c = src.read(h, neo.readBufSize)
   cb(c)
  until not c
  src.close(h)
 end
end

-- Sources

local sources = {}
local sourceList = {}
-- Use all non-primary filesystems
local disks = neo.requireAccess("c.filesystem", "searching disks for packages")
local primaryDisk = disks.primary
for pass = 1, 3 do
 for v in disks.list() do
  local nam = nil
  if v == primaryDisk then
   nam = (pass == 1) and "local"
  elseif v == disks.temporary then
   nam = (pass == 2) and "ramfs"
  elseif pass == 3 then
   nam = v.address
  end
  if nam then
   sources[nam] = v
   table.insert(sourceList, nam)
  end
 end
end

-- No longer needed
disks = nil

if primaryINet then
 sources["inet"] = "http://20kdc.duckdns.org/neo/"
 table.insert(sourceList, "inet")
end

-- List scanning for package window

local function scanList(content)
 local lst = {}
 local lst2 = {}
 for k, v in pairs(sources) do
  local ok, err = pcall(readFile, v, "data/app-claw/local.c2l", function (l)
   if l:sub(-4) == ".c2p" then
    local lt, ltv = l:sub(1, -5)
    ltv = lt:match("%.[0-9]+$")
    if ltv and l:find(content, 1, true) then
     lt = lt:sub(1, -(#ltv + 1))
     lst2[lt] = true
    end
   end
  end)
  if (not ok) and ((k == "inet") or (k == "local")) then
   neoux.startDialog(tostring(err), k)
  end
 end
 for k, v in pairs(lst2) do
  table.insert(lst, k)
 end
 table.sort(lst)
 return lst
end

-- Beginning Of The App (well, the actual one)

local genCurrent, genPrimary, genPackage, primaryWindow
local running = true

-- primary
local primarySearchTx = ""
local primaryPage = 1
local primaryList = scanList("")
local primaryNextMinus = false

-- package
local packageLock = nil
local packageId = "FIXME"

local function describe(pkgs)
 local lowestV, highestV, myV = {}, {}, {}
 for pk, pv in ipairs(pkgs) do
  lowestV[pk] = math.huge
  highestV[pk] = -math.huge
 end
 for k, v in pairs(sources) do
  pcall(readFile, v, "data/app-claw/local.c2l", function (l)
   local lp = l:match("%.[0-9]+%.c2p$")
   for pk, pkg in ipairs(pkgs) do
    if lp and l:sub(1, -(#lp + 1)) == pkg then
     local v = tonumber(lp:sub(2, -5))
     if k == "local" then
      myV[pk] = v
     end
     lowestV[pk] = math.min(lowestV[pk], v)
     highestV[pk] = math.max(highestV[pk], v)
    end
   end
  end)
 end
 for pk, pkg in ipairs(pkgs) do
  if lowestV[pk] == math.huge then 
   pkgs[pk] = pkg .. " (ERR)"
  elseif myV[pk] then
   if highestV[pk] > myV[pk] then
    pkgs[pk] = pkg .. " [v" .. myV[pk] .. "!]"
   elseif lowestV[pk] < myV[pk] then
    pkgs[pk] = pkg .. " (v" .. myV[pk] .. ") R<"
   else
    pkgs[pk] = pkg .. " (v" .. myV[pk] .. ")"
   end
  end
 end
end

local function primaryWindowRegenCore()
 local gen, gens = genCurrent()
 return 25, 14, "claw", neoux.tcwindow(25, 14, gen, function (w)
   w.close()
   running = false
  end, 0xFF8F00, 0, gens)
end
local function primaryWindowRegen()
 primaryWindow.reset(primaryWindowRegenCore())
end

-- Sections

function genPrimary()
 local minus = (primaryNextMinus and 3) or nil
 primaryNextMinus = false
 local pgs = 12
 local pages = math.ceil(#primaryList / pgs)
 local elems = {
  neoux.tcbutton(23, 1, "+", function (w)
   if primaryPage < pages then
    primaryPage = primaryPage + 1
    primaryWindowRegen()
   end
  end),
  neoux.tcrawview(4, 1, {neoux.pad(primaryPage .. " / " .. pages, 19, true, true)}),
  neoux.tcbutton(1, 1, "-", function (w)
   if primaryPage > 1 then
    primaryNextMinus = true
    primaryPage = primaryPage - 1
    primaryWindowRegen()
   end
  end)
 }
 local base = (primaryPage - 1) * pgs
 local pkgs = {}
 for i = 1, pgs do
  local ent = primaryList[base + i]
  if ent then
   pkgs[i] = ent
  end
 end
 describe(pkgs)
 for i = 1, pgs do
  local ent = primaryList[base + i]
  if ent then
   local enttx = pkgs[i]
   table.insert(elems, neoux.tcbutton(1, i + 1, unicode.safeTextFormat(enttx), function (w)
    -- FREE UP MEMORY NOW
    elems = {}
    w.reset(25, 14, "claw", function (ev)
     if ev == "close" then
      w.close()
      running = false
     end
    end)
    packageId = ent
    genCurrent = genPackage
    primaryWindowRegen()
   end))
  end
 end
 table.insert(elems, neoux.tcfield(1, 14, 16, function (s)
  if s then primarySearchTx = s end
  return primarySearchTx
 end))
 table.insert(elems, neoux.tcbutton(17, 14, "Search!", function (w)
  primaryPage = 1
  primaryList = scanList(primarySearchTx)
  primaryWindowRegen()
 end))
 return elems, minus
end

--

local function packageGetBB(src, lclI, srcI, srcW)
 local buttons = {}
 if srcI and srcW then
  table.insert(buttons, {
   "Del",
   function (w)
    w.close()
    running = false
    neo.executeAsync("svc-app-claw-worker", sources[src], packageId, nil, src == "local")
   end
  })
 end
 if srcI and ((not lclI) or (lclI < srcI))  then
  table.insert(buttons, {
   "Get",
   function (w)
    w.close()
    running = false
    neo.executeAsync("svc-app-claw-worker", sources["local"], packageId, sources[src], true)
   end
  })
 end
 if srcW and lclI and not srcI then
  table.insert(buttons, {
   "All",
   function (w)
    w.close()
    running = false
    neo.executeAsync("svc-app-claw-worker", sources[src], packageId, sources["local"], true)
   end
  })
  table.insert(buttons, {
   "Put",
   function (w)
    w.close()
    running = false
    neo.executeAsync("svc-app-claw-worker", sources[src], packageId, sources["local"], false)
   end
  })
 end
 return buttons
end

function genPackage()
 if packageLock then
  return {neoux.tcrawview(1, 1, neoux.fmtText(unicode.safeTextFormat(packageId .. "\n" .. packageLock), 25))}
 end
 -- concept:
 -- mtd              <back>
 -- Multi-Track Drifting
 --
 -- local v20   <del> <run>
 -- inet v21         <pull>
 -- dir v22   <pull> <push>
 -- crockett         <push>
 local sourceVers = {}
 local c2pSrc = "local"
 local c2pVer = -1
 for k, v in pairs(sources) do
  local ok, err = pcall(readFile, v, "data/app-claw/local.c2l", function (l)
   local lp = l:match("%.[0-9]+%.c2p$")
   if lp and l:sub(1, -(#lp + 1)) == packageId then
    sourceVers[k] = tonumber(lp:sub(2, -5))
    if c2pVer < sourceVers[k] then
     c2pSrc = k
     c2pVer = sourceVers[k]
    end
   end
  end)
 end
 if sourceVers["local"] then
  c2pSrc = "local"
  c2pVer = sourceVers["local"]
 end
 local text = ""
 local ok = pcall(readFile, sources[c2pSrc], "data/app-claw/" .. packageId .. "." .. c2pVer .. ".c2p", function (l)
  text = text .. l .. "\n"
 end)
 if not ok then
  text = packageId .. "\nUnable to read v" .. c2pVer .. " c2p from: " .. c2pSrc
 end
 local elems = {
  neoux.tcrawview(1, 1, neoux.fmtText(unicode.safeTextFormat(text), 25)),
  neoux.tcbutton(20, 1, "Back", function ()
   if packageLock then return end
   genCurrent = genPrimary
   primaryWindowRegen()
  end)
 }
 for k, v in ipairs(sourceList) do
  local row = 14 + k - #sourceList
  local pfx = "      "
  if sourceVers[v] then
   pfx = "v" .. string.format("%04i", sourceVers[v]) .. " "
  end
  table.insert(elems, neoux.tcrawview(1, row, {neoux.pad(pfx .. v, 14, false, true)}))
  local col = 26
  local srcW = type(sources[v]) ~= "string"
  for _, bv in ipairs(packageGetBB(v, sourceVers["local"], sourceVers[v], srcW)) do
   local b = neoux.tcbutton(col, row, bv[1], bv[2])
   col = col - b.w
   b.x = col
   table.insert(elems, b)
  end
 end
 return elems
end

--

if ldrPkg == "svc-app-claw-worker" and tgtPkg then
 packageId = tgtPkg
 genCurrent = genPackage
else
 genCurrent = genPrimary
end
primaryWindow = neoux.create(primaryWindowRegenCore())

while running do
 event.pull()
end
