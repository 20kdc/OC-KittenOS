-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- just don't bother with proper indent here
return function (event, neoux, retFunc, fs, pkg, mode)

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
    for k, v in ipairs(neoux.fmtText(unicode.safeTextFormat(e), 25)) do
     l[k] = {v, function () return true end}
    end
    return l
   end,
   unknownAvailable = false,
   selectUnknown = function (text) end
  })
 end
end

local function prepareNodeI(node)
 local l = node.list()
 local w, h = 30, 8
 -- Local State
 -- Selection. Having this equal to #l + 1 means typing area ('unknown')
 local selection = 1
 local unknownTx = ""
 --
 local function format(a)
  if a <= 1 then
   return true, true, node.name
  end
  local camY = math.max(1, selection - 4)
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
  wnd.span(1, a, neoux.pad(unicode.safeTextFormat(text), w, cen, true), colA, colB)
 end
 local function flush(wnd)
  for i = 1, h do
   updateLine(wnd, i)
  end
 end
 local function key(wnd, ka, kc, down)
  if not down then return end
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
    wnd.close()
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
  if evt == "line" then
   updateLine(wnd, a)
  end
  if evt == "close" then
   retFunc(nil)
   wnd.close()
  end
 end
end

local text = class .. " " .. pkg
local window = neoux.create(25, 10, text, cb)

function prepareNode(node)
 local w, h, c = prepareNodeI(node)
 ccb = c
 window.setSize(w, h)
end

prepareNode(require("sys-filevfs")(fs, mode))
return function ()
 retFunc()
 window.close()
end

-- end bad indent
end
