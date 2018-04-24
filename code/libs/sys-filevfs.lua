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
function setupCopyNode(parent, myRoot, op, complete, impliedName)
 local function handleResult(aRes, res)
  if aRes then
   return complete(res, true)
  else
   return nil, setupCopyNode(parent, res, op, complete, impliedName)
  end
 end
 return {
  name = "(" .. op .. ") " .. myRoot.name,
  list = function ()
   local l = {}
   table.insert(l, {"Cancel Operation: " .. op, function ()
    complete(nil, false)
    return false, parent
   end})
   if impliedName and myRoot.unknownAvailable then
    table.insert(l, {"Implied: " .. impliedName, function ()
     return handleResult(myRoot.selectUnknown(impliedName))
    end})
   end
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
local function setupCopyVirtualEnvironment(fs, parent, fwrap, impliedName)
 if not fwrap then
  return false, dialog("Could not open source", parent)
 end
 local myRoot = getRoot(fs, true)
 -- Setup wrapping node
 return setupCopyNode(parent, myRoot, "Copy", function (fwrap2, intent)
  if not fwrap2 then
   fwrap.close()
   if intent then
    return false, dialog("Could not open dest.", parent)
   end
   return false, parent
  end
  local data = fwrap.read(neo.readBufSize)
  while data do
   fwrap2.write(data)
   data = fwrap.read(neo.readBufSize)
  end
  fwrap.close()
  fwrap2.close()
  return false, dialog("Completed copy.", parent)
 end, impliedName)
end
function getFsNode(fs, parent, fsc, path, mode)
 local va = fsc.address:sub(1, 4)
 local fscrw = not fsc.isReadOnly()
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
    if fscrw then
     if path ~= "/" then
      local delText = "Delete"
      if confirmedDel then
       delText = "Delete <ARMED>"
      end
      table.insert(n, {delText, function ()
       if not confirmedDel then
        confirmedDel = true
        return nil, t
       end
       fsc.remove(path)
       return nil, dialog("Done.", parent)
      end})
     else
      table.insert(n, {"Relabel Disk", function ()
       return nil, {
        name = "Disk Relabel...",
        list = function () return {{
         fsc.getLabel() or "Cancel",
         function ()
          return false, t
         end
        }} end,
        unknownAvailable = true,
        selectUnknown = function (tx)
         fsc.setLabel(tx)
         return false, t
        end
       }
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
    end
    return n
   end,
   unknownAvailable = (mode ~= nil) and ((mode == false) or fscrw),
   selectUnknown = function (text)
    local rt, re = require("sys-filewrap").create(fsc, path .. text, mode)
    if not rt then
     return false, dialog("Open Error: " .. tostring(re), parent)
    end
    return true, rt
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
    local tx = "Open"
    if mode == true then
     tx = "Save"
    elseif mode == "append" then
     tx = "Append"
    end
    if fscrw or mode == false then
     table.insert(n, {tx, function ()
      local rt, re = require("sys-filewrap").create(fsc, path, mode)
      if not rt then
       return false, dialog("Open Error: " .. tostring(re), parent)
      end
      return true, rt
     end})
    end
   end
   table.insert(n, {"Copy", function ()
    local rt, re = require("sys-filewrap").create(fsc, path, false)
    if not rt then
     return false, dialog("Open Error: " .. tostring(re), parent)
    end
    return nil, setupCopyVirtualEnvironment(fs, parent, rt, path:match("[^/]*$") or "")
   end})
   if fscrw then
    table.insert(n, {"Delete", function ()
     fsc.remove(path)
     return nil, dialog("Done.", parent)
    end})
   end
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
    if fsi == fs.primary then
     id = "NEO" .. ((id and (":" .. id)) or " Disk")
    elseif fsi == fs.temporary then
     id = "RAM" .. ((id and (" " .. id)) or "Disk")
    else
     id = id or "Disk"
    end
    local used, total = fsi.spaceUsed(), fsi.spaceTotal()
    local amount = string.format("%02i", math.ceil((used / total) * 100))
    local mb = math.floor(total / (1024 * 1024))
    if fsi.isReadOnly() then
     id = "RO " .. amount .. "% " .. mb .. "M " .. id
    else
     id = "RW " .. amount .. "% " .. mb .. "M " .. id
    end
    table.insert(l, {fsi.address:sub(1, 4) .. " " .. id, function ()
     return nil, getFsNode(fs, t, fsi, "/", mode)
    end})
   end
   return l
  end,
  unknownAvailable = false,
  selectUnknown = function (text)
   return false, dialog("Ow, that hurt...", t)
  end
 }
 return t
end
return getRoot
