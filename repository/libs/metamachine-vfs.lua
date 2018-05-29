-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- metamachine-vgpu.lua : Virtual GPU library
-- Authors: 20kdc

return function (icecap, address, path, ro)
 if path ~= "/" then
  icecap.makeDirectory(path:sub(1, #path - 1))
 end
 local function resolvePath(p, post)
  local pth = {}
  local issue = false
  string.gsub(p, "[^\\/]+", function (str)
   if str == ".." then
    if not pth[1] then
     issue = true
    else
     table.remove(pth, #pth)
    end
   elseif str ~= "." then
    table.insert(pth, str)
   end
  end)
  if issue then
   return
  end
  local str = path
  if post then
   str = str:sub(1, #str - 1)
  end
  for k, v in ipairs(pth) do
   if k > 1 or post then
    str = str .. "/"
   end
   str = str .. v
  end
  return str
 end
 local function wrapThing(fn, post, roStop)
  -- If we're adding a "/", we get rid of the original "/".
  -- 
  local pofx = ""
  if post then
   pofx = "/"
  end
  return function (p)
   if ro and roStop then
    return false, "read-only filesystem"
   end
   p = resolvePath(p, post)
   if p then
    local nt = {pcall(fn, p .. pofx)}
    if nt[1] then
     return table.unpack(nt, 2)
    end
   end
   return nil, "no such file or directory"
  end
 end
 local function wrapStat(s)
  return wrapThing(function (px)
   local stat = icecap.stat(px)
   if stat then
    return stat[s]
   end
  end, false, false)
 end
 local handles = {}
 local lHandle = 0
 local modeMapping = {
  r = false,
  rb = false,
  w = true,
  wb = true,
  a = "append",
  ab = "append"
 }
 return {
  type = "filesystem",
  getLabel = function ()
   return "VFS"
  end,
  setLabel = function (label)
  end,
  isReadOnly = function ()
   return ro or icecap.isReadOnly()
  end,
  spaceUsed = function ()
   return icecap.spaceUsed()
  end,
  spaceTotal = function ()
   return icecap.spaceTotal()
  end,
  list = wrapThing(icecap.list, true, false),
  exists = wrapThing(function (px)
   if icecap.stat(px) then
    return true
   end
   return false
  end, false, false),
  isDirectory = wrapStat(1),
  size = wrapStat(2),
  lastModified = wrapStat(3),
  makeDirectory = wrapThing(icecap.makeDirectory, false, true),
  rename = function (a, b)
   if ro then return false, "read-only filesystem" end
   a = resolvePath(a)
   b = resolvePath(b)
   if not (a and b) then
    return nil, a
   end
   return icecap.rename(a, b)
  end,
  remove = wrapThing(icecap.remove, false, true),
  --
  open = function (p, mode)
   checkArg(1, p, "string")
   p = resolvePath(p)
   if not p then return nil, "failed to open" end
   if rawequal(mode, nil) then mode = "r" end
   if modeMapping[mode] == nil then
    error("unsupported mode " .. tostring(mode))
   end
   mode = modeMapping[mode]
   if (mode ~= false) and ro then return nil, "read-only filesystem" end
   lHandle = lHandle + 1
   handles[lHandle] = icecap.open(p, mode)
   if not handles[lHandle] then
    return nil, "failed to open"
   end
   return lHandle
  end,
  read = function (fh, len)
   checkArg(1, fh, "number")
   checkArg(2, len, "number")
   if not handles[fh] then return nil, "bad file descriptor" end
   if not handles[fh].read then return nil, "bad file descriptor" end
   return handles[fh].read(len)
  end,
  write = function (fh, data)
   checkArg(1, fh, "number")
   if not handles[fh] then return nil, "bad file descriptor" end
   if not handles[fh].write then return nil, "bad file descriptor" end
   return handles[fh].write(data)
  end,
  seek = function (fh, whence, point)
   checkArg(1, fh, "number")
   if not handles[fh] then return nil, "bad file descriptor" end
   if not handles[fh].seek then return nil, "bad file descriptor" end
   return handles[fh].seek(whence, point)
  end,
  close = function (fh)
   checkArg(1, fh, "number")
   if not handles[fh] then return nil, "bad file descriptor" end
   handles[fh].close()
   handles[fh] = nil
   return true
  end,
 }
end
