-- File Wrapper
local fwrap = {}
local appTables = {}
-- NOTE: May not be error-sandboxed.
--       Be careful.
function fwrap.appDead(aid)
 if appTables[aid] then
  for k, v in ipairs(appTables[aid]) do
   pcall(function()
    local prox = component.proxy(v.device)
    if prox then
     prox.close(v.handle)
    end
   end)
  end
  appTables[aid] = nil
 end
end
function fwrap.canFree()
 for _, v in pairs(appTables) do
  if v then
   if #v > 0 then
    return false
   end
  end
 end
 return true
end
-- Always error-sandboxed, let errors throw
function fwrap.open(aid, path, mode)
 local finst = {}
 finst.device = path[1]
 finst.file = path[2]
 finst.handle = component.invoke(finst.device, "open", finst.file, mode .. "b")
 if not appTables[aid] then
  appTables[aid] = {}
 end
 table.insert(appTables, finst)
 local function closer()
  pcall(function()
   component.invoke(finst.device, "close", finst.handle)
  end)
  for k, v in ipairs(appTables[aid]) do
   if v == finst then
    table.remove(appTables[aid], k)
    return
   end
  end
 end
 if mode == "r" then
  return {
   close = closer,
   read = function (len)
    if type(len) ~= "number" then error("Length of read must be number") end
    return component.invoke(finst.device, "read", finst.handle, len)
   end
  }
 end
 if mode == "w" then
  return {
   close = closer,
   write = function (txt)
    if type(txt) ~= "string" then error("Write data must be string-bytearray") end
    return component.invoke(finst.device, "write", finst.handle, txt)
   end
  }
 end
 error("Bad mode")
end
return fwrap