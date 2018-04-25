-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- just don't bother with proper indent here
return function (event, nexus, retFunc, fs, pkg, mode)
local fmt = require("fmttext")
local class = "manage"
if mode ~= nil then
 if mode then
  class = "save"
 else
  class = "load"
 end
end

local prepareNode

local ccb = nil
local function cb(...)
 local res, e = pcall(ccb, ...)
 if not res then
  prepareNode({
   name = "F.M. Error",
   list = function ()
    local l = {}
    for k, v in ipairs(fmt.fmtText(unicode.safeTextFormat(e), 25)) do
     l[k] = {v, function () return true end}
    end
    return l
   end,
   unknownAvailable = false,
   selectUnknown = function (text) end
  })
 end
end

local w, h = 30, 8

local function prepareNodeI(node)
 local l = node.list()
 -- Local State
 -- Selection. Having this equal to #l + 1 means typing area ('unknown')
 local selection = 1
 local unknownTx = ""
 --
 local function format(a)
  if a <= 1 then
   return true, true, node.name
  end
  local camY = math.max(1, selection - 3)
  local idx = a + camY - 2
  if node.unknownAvailable then
   if idx == #l + 1 then
    return selection == #l + 1, false, ":" .. unknownTx
   end
  end
  if l[idx] then
   return selection == idx, false, l[idx][1]
  end
  return true, true, "~~~"
 end
 local function updateLine(wnd, a)
  local colA, colB = 0xFFFFFF, 0
  local sel, cen, text = format(a)
  if sel then
   colB, colA = 0xFFFFFF, 0
  end
  wnd.span(1, a, fmt.pad(unicode.safeTextFormat(text), w, cen, true), colA, colB)
 end
 local function flush(wnd)
  for i = 1, h do
   updateLine(wnd, i)
  end
 end
 local ctrl = false
 local function key(wnd, ka, kc, down)
  if kc == 29 then
   ctrl = down
  end
  if not down then return end
  if ctrl then
   if kc == 200 then
    h = math.max(2, h - 1)
   elseif kc == 208 then
    h = h + 1
   elseif kc == 203 then
    w = math.max(1, w - 1)
   elseif kc == 205 then
    w = w + 1
   else
    return
   end
   wnd.setSize(w, h)
   return
  end
  if (ka == 9) or (kc == 208) then
   local lo = selection
   selection = selection + 1
   local max = #l
   if node.unknownAvailable then
    max = max + 1
   end
   if selection > max then
    selection = 1
   end
   flush(wnd)
   return
  end
  if kc == 200 then
   local lo = selection
   selection = selection - 1
   local max = #l
   if node.unknownAvailable then
    max = max + 1
   end
   if selection == 0 then
    selection = max
   end
   flush(wnd)
   return
  end
  if ka == 13 then
   local aResult, res
   if selection ~= #l + 1 then
    aResult, res = l[selection][2]()
   else
    aResult, res = node.selectUnknown(unknownTx)
   end
   if aResult then
    retFunc(res)
    nexus.close(wnd)
   else
    prepareNode(res)
   end
   return
  end
  if selection == #l + 1 then
   if ka == 8 then
    unknownTx = unicode.sub(unknownTx, 1, unicode.len(unknownTx) - 1)
    flush(wnd)
    return
   end
   if ka ~= 0 then
    unknownTx = unknownTx .. unicode.char(ka)
    flush(wnd)
   end
  end
 end
 return w, h, function (wnd, evt, a, b, c)
  if evt == "key" then
   key(wnd, a, b, c)
  end
  if evt == "touch" then
   local ns = b + math.max(1, selection - 3) - 2
   local max = #l
   if node.unknownAvailable then
    max = max + 1
   end
   if ns == selection and selection ~= #l + 1 then
    key(wnd, 13, 0, true)
   else
    selection = math.min(math.max(1, ns), max)
    flush(wnd)
   end
  end
  if evt == "line" then
   updateLine(wnd, a)
  end
  if evt == "close" then
   retFunc(nil)
   nexus.close(wnd)
  end
 end
end

local text = class .. " " .. pkg
local window

function prepareNode(node)
 local w, h, c = prepareNodeI(node)
 ccb = c
 window.setSize(w, h)
end

local closer = nexus.createNexusThread(function ()
 window = nexus.create(25, 10, text)
 prepareNode(require("sys-filevfs")(fs, mode))
 while window do
  cb(window, coroutine.yield())
 end
end)
if not closer then
 retFunc()
 return
end
return function ()
 retFunc()
 closer()
 if window then
  nexus.close(window)
  window = nil
 end
end

-- end bad indent
end
