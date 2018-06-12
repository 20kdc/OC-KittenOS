-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- svc-app-claw-worker: Who stays stays. Who goes goes.

local callerPkg, _, destProx, packageId, downloadSrc, checked = ...
if callerPkg ~= "app-claw" then error("Internal process for app-claw's bidding.") end
-- This 'mutex' remains active as long as the process does.
neo.requireAccess("r.svc.app-claw-worker", "CLAW mutex")

local function wrapLines(ocb)
 local buf = ""
 return function (data)
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
end

local function download(url, cb, src)
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
     neo.scheduleTimer(os.uptime() + 0.05)
     while true do
      local res = coroutine.yield()
      if res == "k.timer" then break end
     end
    end
   end
  end
 else
  local h, e = src.open(url, "rb")
  assert(h, e)
  repeat
   local c = src.read(h, neo.readBufSize)
   cb(c)
  until not c
  src.close(h)
 end
end

local opInstall, opRemove

function opInstall(packageId, checked)
 local gback = {} -- the ultimate strategy
 download("data/app-claw/" .. packageId .. ".c2x", wrapLines(function (l)
  if l:sub(1, 1) == "?" and checked then
   if not destProx.exists("data/app-claw/" .. l:sub(2) .. ".c2x") then
    opInstall(l:sub(2), true)
   end
  elseif l:sub(1, 1) == "+" then
   table.insert(gback, l:sub(2))
  elseif l:sub(1, 1) == "/" then
   destProx.makeDirectory(l)
   assert(destProx.isDirectory(l), "unable to create dir " .. l)
  end
 end), downloadSrc)
 for _, v in ipairs(gback) do
  local f = destProx.open(v .. ".C2T", "wb")
  assert(f, "unable to create download file")
  local ok, err = pcall(download, v, function (b)
   assert(destProx.write(f, b or ""), "unable to save data")
  end, downloadSrc)
  assert(ok, err)
  destProx.close(f)
 end
 -- CRITICAL SECTION --
 if destProx.exists("data/app-claw/" .. packageId .. ".c2x") then
  opRemove(packageId, false)
 end
 for _, v in ipairs(gback) do
  if destProx.exists(v) then
   for _, v in ipairs(gback) do
    destProx.remove(v .. ".C2T")
   end
   error("file conflict: " .. v)
  end
 end
 for _, v in ipairs(gback) do
  destProx.rename(v .. ".C2T", v)
 end
end

function opRemove(packageId, checked)
 if checked then
  local dependents = {}
  for _, pidf in ipairs(destProx.list("data/app-claw/")) do
   if pidf:sub(-4) == ".c2x" then
    local pid = pidf:sub(1, -5)
    download("data/app-claw/" .. pidf, wrapLines(function (l)
     if l == "?" .. packageId then
      table.insert(dependents, pid)
     end
    end), destProx)
   end
  end
  assert(not dependents[1], "Cannot remove " .. packageId .. ", required by:\n" .. table.concat(dependents, ", "))
 end
 local rmSchedule = {}
 download("data/app-claw/" .. packageId .. ".c2x", wrapLines(function (l)
  if l:sub(1, 1) == "+" then
   table.insert(rmSchedule, l:sub(2))
  end
 end), destProx)
 for _, v in ipairs(rmSchedule) do
  destProx.remove(v)
 end
end

local ok, err
if downloadSrc then
 ok, err = pcall(opInstall, packageId, checked)
else
 ok, err = pcall(opRemove, packageId, checked)
end
fsProxy = nil
downloadSrc = nil
neo.executeAsync("app-claw", packageId)
if not ok then
 error(err)
end
