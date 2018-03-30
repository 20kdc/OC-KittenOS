-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-claw: Package manager.

-- libs & such
local event = require("event")(neo)
local neoux, err = require("neoux")
if not neoux then error(err) end
neoux = neoux(event, neo)
local claw = require("claw")()

local source = "http://20kdc.duckdns.org/neo/"
local disks = neo.requireAccess("c.filesystem", "searching disks for packages")
local primaryDisk = disks.primary
local primaryINet = neo.requestAccess("c.internet")
if primaryINet then primaryINet = primaryINet.list()() end

--

local function yielder()
 -- slightly dangerous, but what can we do?
 pcall(event.sleepTo, os.uptime() + 0.05)
end

local function download(url, cb)
 if not primaryINet then return nil, "no internet" end
 local req, err = primaryINet.request(source .. url)
 if not req then
  cb(nil)
  return nil, "dlR/" .. tostring(err)
 end
 -- OpenComputers#535
 req.finishConnect()
 while true do
  local n, n2 = req.read(neo.readBufSize)
  local o, r = cb(n)
  if not o then
   req.close()
   return nil, r
  end
  if not n then
   req.close()
   if n2 then
    return nil, n2
   else
    break
   end
  else
   if n == "" then
    yielder()
   end
  end
 end
 return true
end

local function fsSrc(disk)
 return function (url, cb)
  local h, e = disk.open(url, "rb")
  if not h then cb(nil) return nil, tostring(e) end
  local c = ""
  while c do
   c = disk.read(h, neo.readBufSize)
   local o, r = cb(c)
   if not o then return nil, r end
  end
  disk.close(h)
  return true
 end
end

local function fsDst(disk)
 return {function (url)
  local h, e = disk.open(url, "wb")
  if not h then return nil, tostring(e) end
  return function (d)
   local ok, r = true
   if d then
    ok, r = disk.write(h, d)
   else
    disk.close(h)
   end
   if not ok then return nil, tostring(r) end
   return true
  end
 end, disk.makeDirectory, disk.exists, disk.isDirectory, disk.remove, disk.rename}
end

local function checked(...)
 local res, res2, err = pcall(...)
 if not res then
  neoux.startDialog(tostring(res2), "error!", true)
 elseif not res2 then
  neoux.startDialog(tostring(err), "failed!", true)
 else
  return res2
 end
end

-- Beginning Of The App (well, the actual one)

local genCurrent, genPrimary, genPackage, primaryWindow
local windows = 1

-- primary
local primarySearchTx = ""
local primaryPage = 1
local primaryList = {}
local primaryNextMinus = false

-- package
local packageLock = nil
local packageId = "FIXME"


local function describe(pkg)
 local weHave = claw.getInfo(pkg, "local")
 local theyHave = claw.getInfo(pkg, "local")
 local someoneHas = claw.getInfo(pkg, nil, true)
 if weHave then
  if theyHave.v > weHave.v then
   return pkg .. " [v" .. weHave.v .. "!]"
  end
  if someoneHas.v < weHave.v then
   return pkg .. " (v" .. weHave.v .. ") R<"
  end
  return pkg .. " (v" .. weHave.v .. ")"
 end
 return pkg
end

local function primaryWindowRegenCore()
 local gen, gens = genCurrent()
 return 25, 12, "claw", neoux.tcwindow(25, 12, gen, function (w)
   w.close()
   windows = windows - 1
  end, 0xFF8F00, 0, gens)
end
local function primaryWindowRegen()
 primaryWindow.reset(primaryWindowRegenCore())
end

-- Use all non-primary filesystems
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
   local ok, r = claw.addSource(nam, fsSrc(v), (not v.isReadOnly()) and fsDst(v))
   if not ok and nam == "local" then
    claw.unlock()
    error(r)
   end
  end
 end
end

if primaryINet then
 checked(claw.addSource, "inet", download)
end

primaryList = claw.getList()

-- Sections

function genPrimary()
 local minus = (primaryNextMinus and 3) or nil
 primaryNextMinus = false
 local pgs = 10
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
 for i = 1, pgs do
  local ent = primaryList[base + i]
  if ent then
   local enttx = describe(ent)
   table.insert(elems, neoux.tcbutton(1, i + 1, unicode.safeTextFormat(enttx), function (w)
    packageId = ent
    genCurrent = genPackage
    primaryWindowRegen()
   end))
  end
 end
 table.insert(elems, neoux.tcfield(1, 12, 16, function (s)
  if s then primarySearchTx = s end
  return primarySearchTx
 end))
 table.insert(elems, neoux.tcbutton(17, 12, "Search!", function (w)
  local n = {}
  for _, v in ipairs(claw.getList()) do
   for i = 1, #v do
    if v:sub(i, i + #primarySearchTx - 1) == primarySearchTx then
     table.insert(n, v)
     break
    end
   end
  end
  primaryPage = 1
  primaryList = n
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
   function ()
    if packageLock then return end
    packageLock = ""
    checked(claw.remove, src, packageId, true)
    packageLock = nil
    primaryWindowRegen()
   end
  })
 end
 if srcI and ((not lclI) or (lclI.v < srcI.v))  then
  table.insert(buttons, {
   "Get",
   function ()
    if packageLock then return end
    packageLock = "installing from " .. src
    primaryWindowRegen()
    checked(claw.installTo, "local", packageId, src, true, yielder)
    packageLock = nil
    primaryWindowRegen()
   end
  })
 end
 if srcW and lclI and not srcI then
  table.insert(buttons, {
   "All",
   function ()
    if packageLock then return end
    packageLock = "storing w/ dependencies at " .. src
    primaryWindowRegen()
    checked(claw.installTo, src, packageId, "local", true, yielder)
    packageLock = nil
    primaryWindowRegen()
   end
  })
  table.insert(buttons, {
   "Put",
   function ()
    if packageLock then return end
    packageLock = "storing at " .. src
    primaryWindowRegen()
    checked(claw.installTo, src, packageId, "local", false, yielder)
    packageLock = nil
    primaryWindowRegen()
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
 local info = claw.getInfo(packageId)
 local infoL = claw.getInfo(packageId, "local")
 local elems = {
  neoux.tcrawview(1, 1, neoux.fmtText(unicode.safeTextFormat(packageId .. "\n" .. info.desc .. "\nv" .. info.v .. " deps " .. table.concat(info.deps, ", ")), 25)),
  neoux.tcbutton(20, 1, "Back", function ()
   if packageLock then return end
   genCurrent = genPrimary
   primaryWindowRegen()
  end)
 }
 local srcs = claw.getSources()
 for k, v in ipairs(srcs) do
  local lI = claw.getInfo(packageId, v[1])
  local row = 12 + k - #srcs
  local pfx = "      "
  if lI then
   pfx = "v" .. string.format("%04i", lI.v) .. " "
  end
  table.insert(elems, neoux.tcrawview(1, row, {neoux.pad(pfx .. v[1], 14, false, true)}))
  local col = 26
  for _, bv in ipairs(packageGetBB(v[1], infoL, lI, v[2])) do
   local b = neoux.tcbutton(col, row, bv[1], bv[2])
   col = col - b.w
   b.x = col
   table.insert(elems, b)
  end
 end
 return elems
end

--

genCurrent = genPrimary
primaryWindow = neoux.create(primaryWindowRegenCore())

while windows > 0 do
 event.pull()
end
claw.unlock()
