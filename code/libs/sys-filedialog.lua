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

-- State
local w, h, ctrl = 30, 8, false
local l, selection, unknownTx
local node, wnd


local function prepareNode(n)
 node = n
 l = node.list()
 selection, unknownTx = 1, ""
 wnd.setSize(w, h)
end

local function format(a)
 if a <= 1 then
  return false, fmt.pad(unicode.safeTextFormat(node.name), w, true, true)
 end
 local camY = math.max(1, selection - 3)
 local idx = a + camY - 2
 local utx = (" "):rep(w)
 if node.unknownAvailable and idx == #l + 1 then
  utx = "<OK>[" .. fmt.pad(unicode.safeTextFormat(unknownTx), w - 6, false, true, true) .. "]"
 end
 if l[idx] then
  utx = "<" .. fmt.pad(unicode.safeTextFormat(l[idx][1]), w - 2, false, true) .. ">"
 end
 return selection == idx, utx
end

local function updateLine(a)
 local colA, colB = 0xFFFFFF, 0
 local sel, text = format(a)
 if sel then
  colB, colA = 0xFFFFFF, 0
 end
 wnd.span(1, a, text, colA, colB)
end

local function flush()
 for i = 1, h do
  updateLine(i)
 end
end

local function key(ka, kc, down)
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
   w = math.max(6, w - 1)
  elseif kc == 205 then
   w = w + 1
  else
   return
  end
  wnd.setSize(w, h)
  return
 elseif (ka == 9) or (kc == 208) then
  local lo = selection
  selection = selection + 1
  local max = #l
  if node.unknownAvailable then
   max = max + 1
  end
  if selection > max then
   selection = 1
  end
 elseif kc == 200 then
  local lo = selection
  selection = selection - 1
  local max = #l
  if node.unknownAvailable then
   max = max + 1
  end
  if selection == 0 then
   selection = max
  end
 elseif ka == 13 then
  local aResult, res
  if selection ~= #l + 1 then
   aResult, res = l[selection][2]()
  else
   aResult, res = node.selectUnknown(unknownTx)
  end
  if aResult then
   retFunc(res)
   nexus.windows[wnd.id] = nil
   wnd.close()
  else
   prepareNode(res)
  end
 elseif selection == #l + 1 then
  if ka == 8 then
   unknownTx = unicode.sub(unknownTx, 1, unicode.len(unknownTx) - 1)
  elseif ka ~= 0 then
   unknownTx = unknownTx .. unicode.char(ka)
  end
 end
 flush()
end

local function key2(...)
 local res, e = pcall(key, ...)
 if not res then
  prepareNode({
   name = "F.M. Error",
   list = function ()
    local l = {}
    for k, v in ipairs(fmt.fmtText(unicode.safeTextFormat(e), w)) do
     l[k] = {v, function () return true end}
    end
    return l
   end,
   unknownAvailable = false,
   selectUnknown = function (text) end
  })
 end
end

nexus.create(w, h, class .. " " .. pkg, function (w, ev, a, b, c)
 if not wnd then
  wnd = w
  prepareNode(require("sys-filevfs")(fs, mode))
 end
 if ev == "key" then
  key2(a, b, c)
 end
 if ev == "touch" then
  local ns = b + math.max(1, selection - 3) - 2
  local max = #l
  if node.unknownAvailable then
   max = max + 1
  end
  if ns == selection and ((selection ~= #l + 1) or (a <= 4)) then
   key2(13, 0, true)
  else
   selection = math.min(math.max(1, ns), max)
   flush()
  end
 end
 if ev == "line" then
  updateLine(a)
 end
 if ev == "close" then
  retFunc(nil)
  nexus.windows[wnd.id] = nil
  wnd.close()
 end
end)

return function ()
 retFunc()
 closer()
 if wnd then
  nexus.windows[wnd.id] = nil
  wnd.close()
  wnd = nil
 end
end

-- end bad indent
end
