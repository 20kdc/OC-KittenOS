-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- claw: assistant to app-claw
-- should only ever be one app-claw at a time
local lock = false
return function ()
 if lock then
  error("libclaw safety lock in use")
 end
 lock = true
 local sourceList = {}
 local sources = {}
 --              1              2          3           4                5           6
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
 local remove, installTo
 -- NOTE: Functions in this must return something due to the checked-call wrapper,
 --        but should all use error() for consistency.
 -- Operations
 installTo = function (dstName, pkg, srcName, checked, yielder)
  local installed = {pkg}
  local errs = {}
  if srcName == dstName then
   error("Invalid API use")
  end
  -- preliminary checks
  if checked then
   for _, v in ipairs(sources[srcName][3][pkg].deps) do
    if not sources[dstName][3][v] then
     if not sources[srcName][3][v] then
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
  if sources[dstName][3][pkg] then
   for _, v in ipairs(sources[dstName][3][pkg].files) do
    ignFiles[v] = true
   end
  end
  for _, v in ipairs(sources[srcName][3][pkg].files) do
   if not ignFiles[v] then
    if sources[dstName][2][3](v) then
     table.insert(errs, v .. " already exists (corrupt system?)")
    end
   end
  end
  if #errs > 0 then
   error(table.concat(errs))
  end
  for _, v in ipairs(sources[srcName][3][pkg].dirs) do
   sources[dstName][2][2](v)
   if not sources[dstName][2][4](v) then
    error("Unable to create directory " .. v)
   end
  end
  for _, v in ipairs(sources[srcName][3][pkg].files) do
   local ok, r = sources[srcName][1](v, sources[dstName][2][1](v .. ".claw-tmp"))
   if ok then
    yielder()
   else
    -- Cleanup...
    for _, v in ipairs(sources[srcName][3][pkg].files) do
     sources[dstName][2][5](v .. ".claw-tmp")
    end
    error(r)
   end
  end
  -- PAST THIS POINT, ERRORS CORRUPT!
  sources[dstName][3][pkg] = nil
  saveInfo(dstName)
  for k, _ in pairs(ignFiles) do
   yielder()
   sources[dstName][2][5](k)
  end
  for _, v in ipairs(sources[srcName][3][pkg].files) do
   yielder()
   sources[dstName][2][6](v .. ".claw-tmp", v)
  end
  sources[dstName][3][pkg] = sources[srcName][3][pkg]
  saveInfo(dstName)
  return true
 end
 remove = function (dstName, pkg, checked)
  if checked then
   local errs = {}
   for dpsName, dpsV in pairs(sources[dstName][3]) do
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
  for _, v in ipairs(sources[dstName][3][pkg].files) do
   sources[dstName][2][5](v)
  end
  sources[dstName][3][pkg] = nil
  saveInfo(dstName)
  return true
 end
 return {
  -- Gets the latest info, or if given a source just gives that source's info.
  -- Do not modify output.
  getInfo = function (pkg, source, oldest)
   if source then return sources[source][3][pkg] end
   local bestI = {
    v = -1,
    desc = "An unknown package.",
    deps = {}
   }
   if oldest then bestI.v = 10000 end
   for _, v in pairs(sources) do
    if v[3][pkg] then
     if ((not oldest) and (v[3][pkg].v > bestI.v)) or (oldest and (v[3][pkg].v > bestI.v)) then
      bestI = v[3][pkg]
     end
    end
   end
   return bestI
  end,
  -- Provides an ordered list of sources, with writable.
  -- Do not modify output.
  getSources = function ()
   return sourceList
  end,
  -- NOTE: If a source is writable, it's added anyway despite any problems.
  addSource = function (name, src, dst)
   local ifo = ""
   local ifok, e = src("data/app-claw/local.lua", function (t)
    ifo = ifo .. (t or "")
    return true
   end)
   ifo = ifok and require("serial").deserialize(ifo)
   if not (dst or ifo) then return false, e end
   table.insert(sourceList, {name, not not dst})
   sources[name] = {src, dst, ifo or {}}
   return not not ifo, e or "local.lua parse error"
  end,
  remove = remove,
  installTo = installTo,

  -- Gets a total list of packages, as a table of strings. You can modify output.
  getList = function ()
   local n = {}
   local seen = {}
   for k, v in pairs(sources) do
    for kb, vb in pairs(v[3]) do
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
