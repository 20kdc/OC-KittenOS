-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- metamachine-vgpu.lua : Virtual GPU library
-- Authors: 20kdc

return {
 -- Creates a new virtual GPU.
 -- 'screens' is the component mapping, and thus:
 -- [id] = <glacier GPU function: gpu, rebound = f()>
 newGPU = function (screens)
  local boundScreen
  local backgroundRGB, foregroundRGB = 0, 0xFFFFFF
  local function bound()
   if not screens[boundScreen] then return end
   local gpu, rebound = screens[boundScreen]()
   if not gpu then screens[boundScreen] = nil return end
   if rebound then
    gpu.setBackground(backgroundRGB)
    gpu.setForeground(foregroundRGB)
   end
   return gpu
  end
  return {
   -- Virtual GPU proxy
   type = "gpu",
   -- == getAspectRatio more or less
   getSize = function ()
    local gpu = bound()
    if not gpu then
     return 1, 1
    else
     return gpu.getSize()
    end
   end,
   bind = function (adr, rst)
    boundScreen = adr
    local gpu = bound()
    if gpu then
     if rst then
      gpu.setResolution(gpu.maxResolution())
     end
     return true
    end
    boundScreen = nil
    -- :(
    return false, "No such virtual screen"
   end,
   getScreen = function ()
    return boundScreen
   end,
   maxResolution = function ()
    local gpu = bound()
    if gpu then
     return gpu.maxResolution()
    end
    error("unbound")
   end,
   getResolution = function ()
    local gpu = bound()
    if gpu then
     return gpu.getResolution()
    end
    error("unbound")
   end,
   getViewport = function ()
    -- annoyingly undocumented so we'll pretend it's this, as OCEmu does
    local gpu = bound()
    if gpu then
     return gpu.getResolution()
    end
    error("unbound")
   end,
   setResolution = function (...)
    local gpu = bound()
    if gpu then
     return gpu.setResolution(...)
    end
    error("unbound")
   end,
   setViewport = function (...)
    -- annoyingly undocumented so we'll pretend it's this, as OCEmu does
    local gpu = bound()
    if gpu then
     return gpu.setResolution(...)
    end
    error("unbound")
   end,
   maxDepth = function ()
    local gpu = bound()
    if gpu then
     return gpu.maxDepth()
    end
    error("unbound")
   end,
   getDepth = function ()
    local gpu = bound()
    if gpu then
     return gpu.getDepth()
    end
    error("unbound")
   end,
   setDepth = function (...)
    local gpu = bound()
    if gpu then
     return gpu.setDepth(...)
    end
    error("unbound")
   end,
   get = function (...)
    local gpu = bound()
    if gpu then
     return gpu.get(...)
    end
    error("unbound")
   end,
   set = function (...)
    local gpu = bound()
    if gpu then
     return gpu.set(...)
    end
    error("unbound")
   end,
   copy = function (...)
    local gpu = bound()
    if gpu then
     return gpu.copy(...)
    end
    error("unbound")
   end,
   fill = function (...)
    local gpu = bound()
    if gpu then
     return gpu.fill(...)
    end
    error("unbound")
   end,
   getPaletteColor = function ()
    return 0
   end,
   setPaletteColor = function ()
    -- Fail
   end,
   setForeground = function (rgb)
    checkArg(1, rgb, "number")
    local old = foregroundRGB
    foregroundRGB = rgb
    local gpu = bound()
    if gpu then
     gpu.setForeground(foregroundRGB)
    end
    return old
   end,
   setBackground = function (rgb)
    checkArg(1, rgb, "number")
    local old = backgroundRGB
    backgroundRGB = rgb
    local gpu = bound()
    if gpu then
     gpu.setBackground(backgroundRGB)
    end
    return old
   end,
   getForeground = function ()
    return foregroundRGB
   end,
   getBackground = function ()
    return backgroundRGB
   end
  }
 end,
 -- 'window' is used for span and setSize.
 -- emitResize(w, h) is used for screen_resized events.
 -- queueLine(y) is used for line queuing.
 newBuffer = function (window, keyboards, maxW, maxH, emitResize, queueLine)
  local screenW, screenH
  local screenText = ""
  local screenFR = ""
  local screenFG = ""
  local screenFB = ""
  local screenBR = ""
  local screenBG = ""
  local screenBB = ""
  -- Gets characters for R, G and B
  local function decodeRGB(rgb)
   return
    string.char(math.floor(rgb / 65536) % 256),
    string.char(math.floor(rgb / 256) % 256),
    string.char(rgb % 256)
  end
  -- Returns the width, or nothing if totally out of bounds.
  local function put(x, y, ch, fg, bg)
   if x < 1 or x > screenW then return end
   if y < 1 or y > screenH then return end
   local fr, fg, fb = decodeRGB(fg)
   local br, bg, bb = decodeRGB(bg)
   ch = unicode.safeTextFormat(ch)
   local chw = unicode.len(ch)
   -- Crop
   ch = unicode.sub(ch, 1, (screenW - x) + 1)
   chw = unicode.len(ch)

   local index = x + ((y - 1) * screenW)
   screenText = unicode.sub(screenText, 1, index - 1) .. ch .. unicode.sub(screenText, index + chw)
   screenFR = screenFR:sub(1, index - 1) .. fr:rep(chw) .. screenFR:sub(index + chw)
   screenFG = screenFG:sub(1, index - 1) .. fg:rep(chw) .. screenFG:sub(index + chw)
   screenFB = screenFB:sub(1, index - 1) .. fb:rep(chw) .. screenFB:sub(index + chw)
   screenBR = screenBR:sub(1, index - 1) .. br:rep(chw) .. screenBR:sub(index + chw)
   screenBG = screenBG:sub(1, index - 1) .. bg:rep(chw) .. screenBG:sub(index + chw)
   screenBB = screenBB:sub(1, index - 1) .. bb:rep(chw) .. screenBB:sub(index + chw)
   return chw
  end
  local function getCh(x, y)
   x, y = math.floor(x), math.floor(y)
   if x < 1 or x > screenW then return " ", 0, 0 end
   if y < 1 or y > screenH then return " ", 0, 0 end
   local index = x + ((y - 1) * screenW)
   local fg = (screenFR:byte(index) * 65536) + (screenFG:byte(index) * 256) + screenFB:byte(index)
   local bg = (screenBR:byte(index) * 65536) + (screenBG:byte(index) * 256) + screenBB:byte(index)
   return unicode.sub(screenText, index, index), fg, bg
  end
  --
  -- Directly exposed to userspace
  local function setSize(w, h, first)
   w = math.min(math.max(math.floor(w), 1), maxW)
   h = math.min(math.max(math.floor(h), 1), maxH)
   screenW, screenH = w, h
   screenText = (" "):rep(w * h)
   screenFR = ("\xFF"):rep(w * h)
   screenFG = screenFR
   screenFB = screenFG
   screenBR = ("\x00"):rep(w * h)
   screenBG = screenBR
   screenBB = screenBG
   if not first then emitResize(w, h) end
   window.setSize(w, h)
  end
  local function rectOOB(x, y, w, h)
   if x < 1 or x > screenW - (w - 1) then return true end
   if y < 1 or y > screenH - (h - 1) then return true end
  end
  local function redrawLine(x, y, w)
   x, y, w = math.floor(x), math.floor(y), math.floor(w)
   w = math.min(w, screenW - (x - 1))
   if w < 1 then return end
   if x < 1 or x > screenW then return end
   if y < 1 or y > screenH then return end
   local index = x + ((y - 1) * screenW)
   local currentSegmentI
   local currentSegment
   local currentSegmentR2
   local function flushSegment()
    if not currentSegment then return end
    local tx = unicode.undoSafeTextFormat(currentSegment)
    local fg = (currentSegmentR2:byte(1) * 65536) + (currentSegmentR2:byte(2) * 256) + currentSegmentR2:byte(3)
    local bg = (currentSegmentR2:byte(4) * 65536) + (currentSegmentR2:byte(5) * 256) + currentSegmentR2:byte(6)
    -- Span format is bg, fg, not fg, bg
    window.span(x + currentSegmentI - 1, y, tx, bg, fg)
    currentSegment = nil
    currentSegmentI = nil
    currentSegmentR2 = nil
   end
   for i = 1, w do
    local idx = index + i - 1
    local p = unicode.sub(screenText, idx, idx)
    local s =
     screenFR:sub(idx, idx) .. screenFG:sub(idx, idx) .. screenFB:sub(idx, idx) ..
     screenBR:sub(idx, idx) .. screenBG:sub(idx, idx) .. screenBB:sub(idx, idx)
    if currentSegmentR2 ~= s then
     flushSegment()
     currentSegmentI = i
     currentSegmentR2 = s
     currentSegment = p
    else
     currentSegment = currentSegment .. p
    end
   end
   flushSegment()
  end
  local function queueRedraw(x, y, w, h)
   for i = 1, h do
    queueLine(y + i - 1)
   end
  end
  setSize(maxW, maxH, true)
  local fgRGB, bgRGB = 0xFFFFFF, 0
  local videoInterfaceChipset = {
   getSize = function ()
    return 1, 1
   end,
   maxResolution = function ()
    return maxW, maxH
   end,
   getResolution = function ()
    return screenW, screenH
   end,
   setResolution = setSize,
   maxDepth = function ()
    return 8
   end,
   getDepth = function ()
    return 8
   end,
   setDepth = function (d)
   end,
   get = getCh,
   set = function (x, y, str, v)
    x, y = math.floor(x), math.floor(y)
    if v then
     for i = 1, unicode.len(str) do
      put(x, y + i - 1, unicode.sub(str, i, i), fgRGB, bgRGB)
     end
     return true
    end
    local chw = put(x, y, str, fgRGB, bgRGB)
    if chw then
     queueLine(y)
    else
     return false, "Out of bounds."
    end
    return true
   end,
   copy = function (x, y, w, h, ox, oy)
    x, y, w, h, ox, oy = math.floor(x), math.floor(y), math.floor(w), math.floor(h), math.floor(ox), math.floor(oy)
    if rectOOB(x, y, w, h) then return false, "out of bounds. s" end
    if rectOOB(x + ox, y + oy, w, h) then return false, "out of bounds. t" end
    local collation = {}
    for iy = 1, h do
     collation[iy] = {}
     for ix = 1, w do
      collation[iy][ix] = {getCh(ix + x - 1, iy + y - 1)}
     end
    end
    for iy = 1, h do
     for ix = 1, w do
      local cc = collation[iy][ix]
      if ix + unicode.charWidth(cc[1]) - 1 <= w then
       put(ix + ox + x - 1, iy + oy + y - 1, cc[1], cc[2], cc[3])
      end
     end
    end
    queueRedraw(x + ox, y + oy, w, h)
    return true
   end,
   fill = function (x, y, w, h, str)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    if rectOOB(x, y, w, h) then return false, "out of bounds" end
    str = unicode.sub(str, 1, 1)
    str = str:rep(math.floor(w / unicode.charWidth(str)))
    for i = 1, h do
     put(x, y + i - 1, str, fgRGB, bgRGB)
    end
    queueRedraw(x, y, w, h)
    return true
   end,
   setForeground = function (rgb)
    fgRGB = rgb
   end,
   setBackground = function (rgb)
    bgRGB = rgb
   end,
  }
  -- Various interfaces
  local int = {
   -- Internal interface
   line = function (y)
    redrawLine(1, y, screenW)
   end,
   precise = false
  }
  return function ()
   return videoInterfaceChipset, false
  end, int, {
   type = "screen",
   isOn = function ()
    return true
   end,
   turnOn = function ()
    return true
   end,
   turnOff = function ()
    return true
   end,
   getAspectRatio = function ()
    return 1, 1
   end,
   getKeyboards = function ()
    local kbs = {}
    for k, v in ipairs(keyboards) do
     kbs[k] = v
    end
    return kbs
   end,
   setPrecise = function (p)
    int.precise = p
   end,
   isPrecise = function ()
    return int.precise
   end,
   setTouchModeInverted = function (p)
    return false
   end,
   isTouchModeInverted = function ()
    return false
   end,
  }
 end
}
