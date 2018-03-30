-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- neoux: Implements utilities on top of Everest & event:
-- Everest crash protection

-- Control reference
-- x/y/w/h: ints, position/size, 1,1 TL
-- selectable: boolean
-- key(window, update, char, code, down)
-- touch(window, update, x, y, xI, yI, button)
-- drag(window, update, x, y, xI, yI, button)
-- drop(window, update, x, y, xI, yI, button)
-- scroll(window, update, x, y, xI, yI, amount)
-- clipboard(window, update, contents)

-- Global forces reference. Otherwise, nasty duplication happens.
newNeoux = function (event, neo)
 -- id -> callback
 local lclEvToW = {}
 local everest = neo.requireAccess("x.neo.pub.window", "windowing")
 event.listen("x.neo.pub.window", function (_, window, tp, ...)
  if lclEvToW[window] then
   lclEvToW[window](tp, ...)
  end
 end)
 local neoux = {}
 neoux.fileDialog = function (forWrite, callback)
  local sync = false
  local rtt = nil
  if not callback then
   sync = true
   callback = function (rt)
    sync = false
    rtt = rt
   end
  end
  local tag = neo.requestAccess("x.neo.pub.base").showFileDialogAsync(forWrite)
  local f
  f = function (_, fd, tg, re)
   if fd == "filedialog" then
    if tg == tag then
     callback(re)
     event.ignore(f)
    end
   end
  end
  event.listen("x.neo.pub.base", f)
  while sync do
   event.pull()
  end
  return rtt
 end
 -- Creates a wrapper around a window.
 neoux.create = function (w, h, title, callback)
  local window = {}
  local windowCore = everest(w, h, title)
  -- res is the window!
  lclEvToW[windowCore.id] = function (...) callback(window, ...) end
  -- API convenience: args compatible with .create
  window.reset = function (nw, nh, _, cb)
   callback = cb
   w = nw or w
   h = nh or h
   windowCore.setSize(w, h)
  end
  window.getSize = function ()
   return w, h
  end
  window.getDepth = windowCore.getDepth
  window.setSize = function (nw, nh)
   w = nw
   h = nh
   windowCore.setSize(w, h)
  end
  window.span = windowCore.span
  window.close = function ()
   windowCore.close()
   lclEvToW[windowCore.id] = nil
   windowCore = nil
  end
  return window
 end
 -- Padding function
 neoux.pad = require("fmttext").pad
 -- Text dialog formatting function.
 -- Assumes you've run unicode.safeTextFormat if need be
 neoux.fmtText = function (...)
  local fmt = require("fmttext")
  return fmt.fmtText(...)
 end
 -- UI FRAMEWORK --
 neoux.tcwindow = function (w, h, controls, closing, bg, fg, selIndex)
  local function rotateSelIndex()
   local original = selIndex
   while true do
    selIndex = selIndex + 1
    if not controls[selIndex] then
     selIndex = 1
    end
    if controls[selIndex] then
     if controls[selIndex].selectable then
      return
     end
    end
    if selIndex == original then
     return
    end
   end
  end
  if not selIndex then
   selIndex = #controls
   if #controls == 0 then
    selIndex = 1
   end
   rotateSelIndex()
  end
  local function moveIndex(vertical, negative)
   if not controls[selIndex] then return end
   local currentMA, currentOA = controls[selIndex].y, controls[selIndex].x
   local currentMAX = controls[selIndex].y + controls[selIndex].h - 1
   if vertical then
    currentMA, currentOA = controls[selIndex].x, controls[selIndex].y
    currentMAX = controls[selIndex].x + controls[selIndex].w - 1
   end
   local bestOA = 9001
   local bestSI = selIndex
   if negative then
    bestOA = -9000
   end
   for k, v in ipairs(controls) do
    if (k ~= selIndex) and v.selectable then
     local ma, oa = v.y, v.x
     local max = v.y + v.h - 1
     if vertical then
      ma, oa = v.x, v.y
      max = v.x + v.w - 1
     end
     if (ma >= currentMA and ma <= currentMAX) or (max >= currentMA and max <= currentMAX)
     or (currentMA >= ma and currentMA <= max) or (currentMAX >= ma and currentMAX <= max) then
      if negative then
       if (oa < currentOA) and (oa > bestOA) then
        bestOA = oa
        bestSI = k
       end
      else
       if (oa > currentOA) and (oa < bestOA) then
        bestOA = oa
        bestSI = k
       end
      end
     end
    end
   end
   selIndex = bestSI
  end

  local function doLine(window, a)
   window.span(1, a, (" "):rep(w), bg, fg)
   for k, v in ipairs(controls) do
    if a >= v.y then
     if a < (v.y + v.h) then
      v.line(window, v.x, a, (a - v.y) + 1, bg, fg, selIndex == k)
     end
    end
   end
  end
  local function doZone(window, control, cache)
   for i = 1, control.h do
    local l = i + control.y - 1
    if (not cache) or (not cache[l]) then
     doLine(window, l)
     if cache then cache[l] = true end
    end
   end
  end

  local function moveIndexAU(window, vertical, negative)
   local c1 = controls[selIndex]
   moveIndex(vertical, negative)
   local c2 = controls[selIndex]
   local cache = {}
   if c1 then doZone(window, c1, cache) end
   if c2 then doZone(window, c2, cache) end
  end
  -- Attach .update for external interference
  for k, v in ipairs(controls) do
   v.update = function (window) doZone(window, v, {}) end
  end
  return function (window, ev, a, b, c, d, e)
   -- X,Y,Xi,Yi,B
   if ev == "touch" then
    local found = nil
    for k, v in ipairs(controls) do
     if v.selectable then
      if a >= v.x then
       if a < (v.x + v.w) then
        if b >= v.y then
         if b < (v.y + v.h) then
          found = k
          break
         end
        end
       end
      end
     end
    end
    if found then
     local c1 = controls[selIndex]
     selIndex = found
     local c2 = controls[selIndex]
     local cache = {}
     if c1 then doZone(window, c1, cache) end
     if c2 then
      doZone(window, c2, cache)
      if c2.touch then
       c2.touch(window, function () doZone(window, c2) end, (a - c2.x) + 1, (b - c2.y) + 1, c, d, e)
      end
     end
    end
   -- X,Y,Xi,Yi,B (or D for scroll)
   elseif ev == "drag" or ev == "drop" or ev == "scroll" then
    if controls[selIndex] then
     if controls[selIndex][ev] then
      controls[selIndex][ev](window, function () doZone(window, controls[selIndex]) end, (a - controls[selIndex].x) + 1, (b - controls[selIndex].y) + 1, c, d, e)
     end
    end
   elseif ev == "key" then
    if b == 203 then
     if c then
      moveIndexAU(window, false, true)
     end
    elseif b == 205 then
     if c then
      moveIndexAU(window, false, false)
     end
    elseif b == 200 then
     if c then
      moveIndexAU(window, true, true)
     end
    elseif b == 208 then
     if c then
      moveIndexAU(window, true, false)
     end
    elseif a == 9 then
     if c then
      local c1 = controls[selIndex]
      rotateSelIndex()
      local c2 = controls[selIndex]
      local cache = {}
      if c1 then doZone(window, c1, cache) end
      if c2 then doZone(window, c2, cache) end
     end
    elseif controls[selIndex] then
     if controls[selIndex].key then
      controls[selIndex].key(window, function () doZone(window, controls[selIndex]) end, a, b, c)
     end
    end
   elseif ev == "clipboard" then
    if controls[selIndex] then
     if controls[selIndex].clipboard then
      controls[selIndex].clipboard(window, function () doZone(window, controls[selIndex]) end, a)
     end
    end
   elseif ev == "line" then
    doLine(window, a)
   elseif ev == "close" then
    closing(window)
   end
  end, doZone
 end
 neoux.tcrawview = function (x, y, lines)
  return {
   x = x,
   y = y,
   w = unicode.len(lines[1]),
   h = #lines,
   selectable = false,
   line = function (window, x, y, lined, bg, fg, selected)
    -- Can't be selected normally so ignore that flag
    window.span(x, y, lines[lined], bg, fg)
   end
  }
 end
 neoux.tchdivider = function (x, y, w)
  return neoux.tcrawview(x, y, {("-"):rep(w)})
 end
 neoux.tcvdivider = function (x, y, h)
  local n = {}
  for i = 1, h do
   n[i] = "|"
  end
  return neoux.tcrawview(x, y, n)
 end
 neoux.tcbutton = function (x, y, text, callback)
  text = "<" .. text .. ">"
  return {
   x = x,
   y = y,
   w = unicode.len(text),
   h = 1,
   selectable = true,
   key = function (window, update, a, c, d)
    if d then
     if a == 13 or a == 32 then
      callback(window)
     end
    end
   end,
   touch = function (window, update, x, y, button)
    callback(window)
   end,
   line = function (window, x, y, lind, bg, fg, selected)
    local fg1 = fg
    if selected then
     fg = bg
     bg = fg1
    end
    window.span(x, y, text, bg, fg)
   end
  }
 end
 -- Note: w should be at least 2 - this is similar to buttons.
 neoux.tcfield = function (x, y, w, textprop)
  return {
   x = x,
   y = y,
   w = w,
   h = 1,
   selectable = true,
   key = function (window, update, a, c, d)
    if d then
     if a == 13 then
     elseif a == 8 then
      local str = textprop()
      textprop(unicode.sub(str, 1, unicode.len(str) - 1))
      update()
     elseif a ~= 0 then
      textprop(textprop() .. unicode.char(a))
      update()
     end
    end
   end,
   line = function (window, x, y, lind, bg, fg, selected)
    local fg1 = fg
    if selected then
     fg = bg
     bg = fg1
    end
    local text = unicode.safeTextFormat(textprop())
    local txl = unicode.len(text)
    local start = math.max(1, (txl - (w - 2)) + 1)
    text = "[" .. neoux.pad(unicode.sub(text, start, start + (w - 3)), w - 2, false, true) .. "]"
    window.span(x, y, text, bg, fg)
   end
  }
 end
 neoux.startDialog = function (fmt, title, wait)
  fmt = neoux.fmtText(unicode.safeTextFormat(fmt), 40)
  neoux.create(40, #fmt, title, function (window, ev, a, b, c)
   if ev == "line" then
    window.span(1, a, fmt[a], 0xFFFFFF, 0)
   end
   if ev == "close" then
    window.close()
    wait = nil
   end
  end)
  while wait do
   event.pull()
  end
 end
 return neoux
end
return newNeoux
