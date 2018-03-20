-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- Used by filedialog to provide a sane relative environment.
-- Essentially, the filedialog is just a 'thin' UI wrapper over this.
-- Returns the root node.

local function dialog(name, parent)
 return {
  name = name,
  list = function () return {{"Back", function () return nil, parent end}} end,
  unknownAvailable = false,
  selectUnknown = function (text) end   
 }
end

local getFsNode, getRoot
local setupCopyNode
function setupCopyNode(parent, myRoot, op, complete)
 local function handleResult(aRes, res)
  if aRes then
   return complete(res)
  else
   return nil, setupCopyNode(parent, res, op, complete)
  end
 end
 return {
  name = "(" .. op .. ") " .. myRoot.name,
  list = function ()
   local l = {}
   table.insert(l, {"Cancel Operation: " .. op, function ()
    return false, parent
   end})
   for _, v in ipairs(myRoot.list()) do
    table.insert(l, {v[1], function ()
     return handleResult(v[2]())
    end})
   end
   return l
  end,
  unknownAvailable = myRoot.unknownAvailable,
  selectUnknown = function (tx)
   return handleResult(myRoot.selectUnknown(tx))
  end
 }
end
local function setupCopyVirtualEnvironment(fs, parent, fwrap)
 if not fwrap then
  return false, dialog("Could not open source", parent)
 end
 local myRoot = getRoot(fs, true)
 -- Setup wrapping node
 return setupCopyNode(parent, myRoot, "Copy", function (fwrap2)
  if not fwrap2 then
   return false, dialog("Could not open dest.", parent)
  end
  local data = fwrap.read(neo.readBufSize)
  while data do
   fwrap2.write(data)
   data = fwrap.read(neo.readBufSize)
  end
  fwrap.close()
  fwrap2.close()
  return false, dialog("Completed copy.", parent)
 end)
end
getFsNode = function (fs, parent, fsc, path, mode)
 local va = fsc.address:sub(1, 4)
 if path:sub(#path, #path) == "/" then
  local t
  local confirmedDel = false
  t = {
   name = "DIR : " .. va .. path,
   list = function ()
    local n = {}
    n[1] = {"..", function ()
     return nil, parent
    end}
    for k, v in ipairs(fsc.list(path)) do
     local nm = "[F] " .. v
     local fp = path .. v
     if fsc.isDirectory(fp) then
      nm = "[D] " .. v
     end
     n[k + 1] = {nm, function () return nil, getFsNode(fs, t, fsc, fp, mode) end}
    end
    local delText = "Delete"
    if confirmedDel then
     delText = "Delete <ARMED>"
    end
    if path ~= "/" then
     table.insert(n, {delText, function ()
      if not confirmedDel then
       confirmedDel = true
       return nil, t
      end
      fsc.remove(path)
      return nil, dialog("Done.", parent)
     end})
    end
    table.insert(n, {"Mk. Directory", function ()
     return nil, {
      name = "MKDIR...",
      list = function () return {} end,
      unknownAvailable = true,
      selectUnknown = function (text)
       fsc.makeDirectory(path .. text)
       return nil, dialog("Done!", t)
      end
     }
    end})
    return n
   end,
   unknownAvailable = mode ~= nil,
   selectUnknown = function (text)
    return true, require("sys-filewrap")(fsc, path .. text, mode)
   end
  }
  return t
 end
 return {
  name = "FILE: " .. va .. path,
  list = function ()
   local n = {}
   table.insert(n, {"Back", function ()
    return nil, parent
   end})
   if mode ~= nil then
    table.insert(n, {"Open", function ()
     return true, require("sys-filewrap")(fsc, path, mode)
    end})
   end
   table.insert(n, {"Copy", function ()
    return nil, setupCopyVirtualEnvironment(fs, parent, require("sys-filewrap")(fsc, path, false))
   end})
   table.insert(n, {"Delete", function ()
    fsc.remove(path)
    return nil, dialog("Done.", parent)
   end})
   return n
  end,
  unknownAvailable = false,
  selectUnknown = function (text) end
 }
end
function getRoot(fs, mode)
 local t
 t = {
  name = "DRVS:",
  list = function ()
   local l = {}
   for fsi in fs.list() do
    local id = fsi.getLabel()
    if not id then
     id = " Disk"
    else
     id = ":" .. id
    end
    if fsi == fs.primary then
     id = "NEO" .. id
    elseif fsi == fs.temporary then
     id = "RAM" .. id
    end
    local used, total = fsi.spaceUsed(), fsi.spaceTotal()
    local amount = string.format("%02i", math.ceil((used / total) * 100))
    local mb = math.floor(total / (1024 * 1024))
    if fsi.isReadOnly() then
     id = amount .. "% RO " .. mb .. "M " .. id
    else
     id = amount .. "% RW " .. mb .. "M " .. id
    end
    table.insert(l, {fsi.address:sub(1, 4) .. ": " .. id, function ()
     return nil, getFsNode(fs, t, fsi, "/", mode)
    end})
   end
   return l
  end,
  unknownAvailable = false,
  selectUnknown = function (text) end
 }
 return t
end
return getRoot
