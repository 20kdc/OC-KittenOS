-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- neoux: Implements utilities on top of Everest & event:
-- Everest crash protection
return function (event, neo)
 -- this is why neo access is 'needed'
 local function retrieveIcecap()
  return neo.requestAccess("x.neo.pub.base")
 end
 local function retrieveEverest()
  return neo.requestAccess("x.neo.pub.window")
 end
 -- id -> {lclEv, w, h, title, callback}
 local windows = {}
 local lclEvToW = {}
 retrieveEverest()
 local function everestDied()
  for _, v in pairs(windows) do
   v[1] = nil
  end
  lclEvToW = {}
 end
 local function pushWindowToEverest(k)
  local everest = retrieveEverest()
  if not everest then
   everestDied()
   return
  end
  local v = windows[k]
  local r, res = pcall(everest, v[2], v[3], v[4])
  if not r then
   everestDied()
   return
  else
   -- res is the window!
   lclEvToW[res.id] = k
   windows[k][1] = res
  end
 end
 event.listen("k.registration", function (_, xe)
  if #windows > 0 then
   if xe == "x.neo.pub.window" then
    for k, v in pairs(windows) do
     pushWindowToEverest(k)
    end
   end
  end
 end)
 event.listen("k.deregistration", function (_, xe)
  if xe == "x.neo.pub.window" then
   everestDied()
  end
 end)
 event.listen("x.neo.pub.window", function (_, window, tp, ...)
  if lclEvToW[window] then
   windows[lclEvToW[window]][5](tp, ...)
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
  local tag = retrieveIcecap().showFileDialogAsync(forWrite)
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
  local windowCore = {nil, w, h, title, function (...) callback(window, ...) end}
  local k = #windows + 1
  table.insert(windows, windowCore)
  pushWindowToEverest(k)
  window.reset = function (w, h, cb)
   callback = cb
   if mw or nh then
    windowCore[2] = nw
    windowCore[3] = nh
   end
   if windowCore[1] then
    windowCore[1].setSize(windowCore[2], windowCore[3])
   end
  end
  window.getSize = function ()
   return windowCore[2], windowCore[3]
  end
  window.setSize = function (w, h)
   windowCore[2] = w
   windowCore[3] = h
   if windowCore[1] then
    windowCore[1].setSize(w, h)
   end
  end
  window.span = function (x, y, text, bg, fg)
   if windowCore[1] then
    pcall(windowCore[1].span, x, y, text, bg, fg)
   end
  end
  window.close = function ()
   if windowCore[1] then
    windowCore[1].close()
    lclEvToW[windowCore[1].id] = nil
    windowCore[1] = nil
   end
   windows[k] = nil
  end
  return window
 end
 -- Padding function
 neoux.pad = function (t, len, centre, cut)
  local l = unicode.len(t)
  local add = len - l
  if add > 0 then
   if centre then
    t = (" "):rep(math.floor(add / 2)) .. t .. (" "):rep(math.ceil(add / 2))
   else
    t = t .. (" "):rep(add)
   end
  end
  if cut then
   t = unicode.sub(t, 1, len)
  end
  return t
 end
 -- Text dialog formatting function.
 -- Assumes you've run unicode.safeTextFormat if need be
 neoux.fmtText = function (text, w)
  local nl = text:find("\n")
  if nl then
   local base = text:sub(1, nl - 1)
   local ext = text:sub(nl + 1)
   local baseT = neoux.fmtText(base, w)
   local extT = neoux.fmtText(ext, w)
   for _, v in ipairs(extT) do
    table.insert(baseT, v)
   end
   return baseT
  end
  if unicode.len(text) > w then
   local lastSpace
   for i = 1, w do
    if unicode.sub(text, i, i) == " " then
     -- Check this isn't an inserted space (unicode safe text format)
     local ok = true
     if i > 1 then
      if unicode.charWidth(unicode.sub(text, i - 1, i - 1)) ~= 1 then
       ok = false
      end
     end
     if ok then
      lastSpace = i
     end
    end
   end
   local baseText, extText
   if not lastSpace then
    -- Break at a 1-earlier boundary 
    local wEffect = w
    if unicode.charWidth(unicode.sub(text, w, w)) ~= 1 then
     -- Guaranteed to be safe, so
     wEffect = wEffect - 1
    end
    baseText = unicode.sub(text, 1, wEffect)
    extText = unicode.sub(text, wEffect + 1)
   else
    baseText = unicode.sub(text, 1, lastSpace - 1)
    extText = unicode.sub(text, lastSpace + 1) 
   end
   local full = neoux.fmtText(extText, w)
   table.insert(full, 1, neoux.pad(baseText, w))
   return full
  end
  return {neoux.pad(text, w)}
 end
 -- UI FRAMEWORK --
 neoux.tcwindow = function (w, h, controls, closing, bg, fg)
  local selIndex = #controls
  if #controls == 0 then
   selIndex = 1
  end
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
  rotateSelIndex()
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
   touch = function (window, update, x, y)
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
  fmt = neoux.fmtText(unicode.safeTextFormat(fmt), 20)
  neoux.create(20, #fmt, title, function (window, ev, a, b, c)
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
