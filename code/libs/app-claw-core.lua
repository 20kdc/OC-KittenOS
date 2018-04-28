-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-claw-core: assistant to app-claw
-- should only ever be one app-claw at a time
-- USING THIS LIBRARY OUTSIDE OF APP-CLAW IS A BAD IDEA.
-- SO DON'T DO IT.

-- Also serves to provide a mutex.

local lock = false

return function ()
 if lock then
  error("libclaw safety lock in use")
 end
 lock = true
 local sourceList = {}
 local sources = {}
 --              1              2          3           4                5           6
 -- source ents: src            dst        index
 -- dst entries: writeFile(fn), mkdir(fn), exists(fn), isDirectory(fn), remove(fn), rename(fna, fnb)
 -- writeFile(fn) -> function (data/nil to close)
 local function saveInfo(dn)
  sources[dn][2][2]("data")
  sources[dn][2][2]("data/app-claw")
  local cb, _, r = sources[dn][2][1]("data/app-claw/local.lua")
  if not cb then return false, r end
  _, r = cb(require("serial").serialize(sources[dn][3]))
  if not _ then return false, r end
  _, r = cb(nil)
  if not _ then return false, r end
  return true
 end
 local remove, installTo, expandCSI, compressCSI
 local function expandS(v)
  return v:sub(2, v:byte(1) + 1), v:sub(v:byte(1) + 2)
 end
 local function expandT(v)
  local t = {}
  local n = v:byte(1)
  v = v:sub(2)
  for i = 1, n do
   t[i], v = expandS(v)
  end
  return t, v
 end
 local function compressT(x)
  local b = string.char(#x)
  for _, v in ipairs(x) do
   b = b .. string.char(#v) .. v
  end
  return b
 end
 local function expandCSI(v)
  local t = {}
  local k
  k, v = expandS(v)
  t.desc, v = expandS(v)
  t.v = (v:byte(1) * 256) + v:byte(2)
  v = v:sub(3)
  t.dirs, v = expandT(v)
  t.files, v = expandT(v)
  t.deps, v = expandT(v)
  return k, t, v
 end
 local function compressCSI(k, v)
  local nifo = string.char(#k) .. k
  nifo = nifo .. string.char(math.min(255, #v.desc)) .. v.desc:sub(1, 255)
  nifo = nifo .. string.char(math.floor(v.v / 256), v.v % 256)
  nifo = nifo .. compressT(v.dirs)
  nifo = nifo .. compressT(v.files)
  nifo = nifo .. compressT(v.deps)
  return nifo
 end
 local function findPkg(idx, pkg, del)
  del = del and ""
  idx = sources[idx][3]
  while #idx > 0 do
   local k, d
   k, d, idx = expandCSI(idx)
   if del then
    if k == pkg then
     return d, del .. idx
    end
    del = del .. compressCSI(k, d)
   else
    if k == pkg then return d end
   end
  end
 end
 -- NOTE: Functions in this must return something due to the checked-call wrapper,
 --        but should all use error() for consistency.
 -- Operations
 installTo = function (dstName, pkg, srcName, checked, yielder)
  local errs = {}
  if srcName == dstName then
   error("Invalid API use")
  end
  -- preliminary checks
  local srcPkg = findPkg(srcName, pkg, false)
  assert(srcPkg)
  if checked then
   for _, v in ipairs(srcPkg.deps) do
    if not findPkg(dstName, v) then
     if not findPkg(srcName, v) then
      table.insert(errs, pkg .. " depends on " .. v .. "\n")
     elseif #errs == 0 then
      installTo(dstName, v, srcName, checked, yielder)
     else
      table.insert(errs, pkg .. " depends on " .. v .. " (can autoinstall)\n")
     end
    end
   end
  end
  -- Files from previous versions to get rid of
  local ignFiles = {}
  local oldDst = findPkg(dstName, pkg)
  if oldDst then
   for _, v in ipairs(oldDst.files) do
    ignFiles[v] = true
   end
  end
  oldDst = nil
  for _, v in ipairs(srcPkg.files) do
   if not ignFiles[v] then
    if sources[dstName][2][3](v) then
     table.insert(errs, v .. " already exists (corrupt system?)")
    end
   end
  end
  if #errs > 0 then
   error(table.concat(errs))
  end
  for _, v in ipairs(srcPkg.dirs) do
   sources[dstName][2][2](v)
   if not sources[dstName][2][4](v) then
    error("Unable to create directory " .. v)
   end
  end
  for _, v in ipairs(srcPkg.files) do
   local tmpOut, r, ok = sources[dstName][2][1](v .. ".claw-tmp")
   ok = tmpOut
   if ok then
    ok, r = sources[srcName][1](v, tmpOut)
   end
   if ok then
    yielder()
   else
    -- Cleanup...
    for _, v in ipairs(srcPkg.files) do
     sources[dstName][2][5](v .. ".claw-tmp")
    end
    error(r)
   end
  end
  -- PAST THIS POINT, ERRORS CORRUPT!
  -- Remove package from DB
  local oldDst2, oldDst3 = findPkg(dstName, pkg, true)
  sources[dstName][3] = oldDst3 or sources[dstName][3]
  oldDst2, oldDst3 = nil
  saveInfo(dstName)
  -- Delete old files
  for k, _ in pairs(ignFiles) do
   yielder()
   sources[dstName][2][5](k)
  end
  -- Create new files
  for _, v in ipairs(srcPkg.files) do
   yielder()
   sources[dstName][2][6](v .. ".claw-tmp", v)
  end
  -- Insert into DB
  sources[dstName][3] = sources[dstName][3] .. compressCSI(pkg, srcPkg)
  saveInfo(dstName)
  return true
 end
 remove = function (dstName, pkg, checked)
  if checked then
   local errs = {}
   local buf = sources[dstName][3]
   while #buf > 0 do
    local dpsName, dpsV
    dpsName, dpsV, buf = expandCSI(buf)
    for _, v in ipairs(dpsV.deps) do
     if v == pkg then
      table.insert(errs, dpsName .. " depends on " .. pkg .. "\n")
     end
    end
   end
   if #errs > 0 then
    return nil, table.concat(errs)
   end
  end
  local dstPkg, nbuf = findPkg(dstName, pkg, true)
  assert(dstPkg, "Package wasn't installed")
  for _, v in ipairs(dstPkg.files) do
   sources[dstName][2][5](v)
  end
  sources[dstName][3] = nbuf
  saveInfo(dstName)
  return true
 end
 return {
  -- Gets the latest info, or if given a source just gives that source's info.
  -- Do not modify output.
  getInfo = function (pkg, source, oldest)
   if source then return findPkg(source, pkg) end
   local bestI = {
    v = -1,
    desc = "An unknown package.",
    deps = {}
   }
   if oldest then bestI.v = 10000 end
   for k, v in pairs(sources) do
    local pkgv = findPkg(k, pkg)
    if pkgv then
     if ((not oldest) and (pkgv.v > bestI.v)) or (oldest and (pkgv.v > bestI.v)) then
      bestI = pkgv
     end
    end
   end
   return bestI
  end,
  sources = sources,
  sourceList = sourceList,
  remove = remove,
  installTo = installTo,
  expandCSI = expandCSI,
  compressCSI = compressCSI,

  -- Gets a total list of packages, as a table of strings. You can modify output.
  getList = function ()
   local n = {}
   local seen = {}
   for k, v in pairs(sources) do
    local p3 = v[3]
    while #p3 > 0 do
     local kb, _, nx = expandCSI(p3)
     p3 = nx
     if not seen[kb] then
      seen[kb] = true
      table.insert(n, kb)
     end
    end
   end
   table.sort(n)
   return n
  end,
  unlock = function ()
   lock = false
  end
 }
end
