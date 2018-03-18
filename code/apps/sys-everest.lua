-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- s-everest

-- Terminology:
-- "monitor": Either the Null Virtual Monitor[0] (a safetynet),
--             or an actual GPU/Screen pair managed by donkonit.
-- "surface": Everest system-level drawing primitive
-- "window" : Everest user-level wrapper around a surface providing a reliable window frame, movement, etc.
-- "line"   : A Wx1 area across a surface.
-- "span"   : A ?x1 area across a surface with text and a single fg/bg colour.
-- This has less user calls as opposed to the old KittenOS system, which had a high CPU usage.
-- Another thing to note is that Everest still uses callbacks, both for efficiency and library convenience,
--  though with automatically closing windows on process death.

-- How Bristol talks to this is:
-- 1. Bristol starts up Everest. Everest does not claim new monitors by default.
-- 2. Bristol claims all available monitors to blank out the display
-- 3. The user logs in
-- 4. Bristol runs "startSession", enabling claiming of free monitors, and then promptly dies.
-- 5. Everest claims the new monitors, and the desktop session begins
-- 6. Everest dies/respawns, or endSession is called - in both cases,
--    Everest is now essentially back at the state in 1.
-- 7. Either this is Bristol, so go to 2,
--     or this is a screensaver host, and has a saving-throw to start Bristol if it dies unexpectedly.
--    In any case, this eventually returns to 2 or 4.

local everestProvider = neo.requestAccess("r.neo.pub.window")
if not everestProvider then return end

local everestSessionProvider = neo.requestAccess("r.neo.sys.session")
if not everestSessionProvider then return end

-- Got mutexes. Now setup saving throw and shutdown callback
-- Something to note is that Donkonit is the safety net on this,
--  as it auto-releases the monitors.
local screens = neo.requestAccess("x.neo.sys.screens")
if not screens then
 error("Donkonit is required to run Everest")
end

neo.requestAccess("s.h.clipboard")
neo.requestAccess("s.h.touch")
neo.requestAccess("s.h.drag")
neo.requestAccess("s.h.key_up")
neo.requestAccess("s.h.key_down")

-- {gpu, screenAddr, w, h, bg, fg}
local monitors = {}

-- NULL VIRTUAL MONITOR!
-- This is where we stuff processes while Bristol isn't online
monitors[0] = {nil, nil, 80, 25}

-- {monitor, x, y, w, h, callback}
-- callback events are:
-- key ka kc down
-- line y
local surfaces = {}

-- Dead process's switch to clean up resources by crashing processes which "just don't get it"
local dead = false

local savingThrow = neo.requestAccess("x.neo.sys.manage")
if savingThrow then
 savingThrow.registerForShutdownEvent()
 savingThrow.registerSavingThrow(function ()
  if #monitors > 0 then
   neo.executeAsync("sys-init", monitors[1][2])
  end
  neo.executeAsync("sys-everest")
  -- In this case the surfaces are leaked and hold references here. They have to be removed manually.
  -- Do this via a "primary event" (k.deregistration) and "deathtrap events"
  -- If a process evades the deathtrap then it clearly has reason to stay alive regardless of Everest status.
  dead = true
  monitors = {}
  for _, v in ipairs(surfaces) do
   pcall(v[6], "line", 1)
   pcall(v[6], "line", 2)
  end
 end)
end

-- Grab all available monitors when they become available
local inSession = false

local function renderingAllowed()
 -- This is a safety feature to prevent implosion due to missing monitors.
 return #monitors > 0
end

local function surfaceAt(monitor, x, y)
 for k, v in ipairs(surfaces) do
  if v[1] == monitor then
   if x >= v[2] then
    if y >= v[3] then
     if x < (v[2] + v[4]) then
      if y < (v[3] + v[5]) then
       return k, (x - v[2]) + 1, (y - v[3]) + 1
      end
     end
    end
   end
  end
 end
end

local function monitorGPUColours(m, cb, bg, fg)
 local nbg = m[5]
 local nfg = m[6]
 if nbg ~= bg then
  cb.setBackground(bg)
  m[5] = bg
 end
 if nfg ~= fg then
  cb.setForeground(fg)
  m[6] = fg
 end
end

local function updateRegion(monitorId, x, y, w, h, surfaceSpanCache)
 if not renderingAllowed() then return end
 local m = monitors[monitorId]
 local mg = m[1]()
 if not mg then return end
 -- The input region is the one that makes SENSE.
 -- Considering WC handling, that's not an option.
 -- WCHAX: start
 if x > 1 then
  x = x - 1
  w = w + 1
 end
 -- this, in combination with 'forcefully blank out last column of window during render',
 -- cleans up littering
 w = w + 1
 -- end

 for span = 1, h do
  local backgroundMarkStart = nil
  for sx = 1, w do
   local t, tx, ty = surfaceAt(monitorId, sx + x - 1, span + y - 1)
   if t then
    -- It has to be in this order to get rid of wide char weirdness
    if backgroundMarkStart then
     monitorGPUColours(m, mg, 0x000020, 0)
     mg.fill(backgroundMarkStart + x - 1, span + y - 1, sx - backgroundMarkStart, 1, " ")
     backgroundMarkStart = nil
    end
    if not surfaceSpanCache[t .. "_" .. ty] then
     surfaceSpanCache[t .. "_" .. ty] = true
     surfaces[t][6]("line", ty)
    end
   elseif not backgroundMarkStart then
    backgroundMarkStart = sx
   end
  end
  if backgroundMarkStart then
   local m = monitors[monitorId]
   monitorGPUColours(m, mg, 0x000020, 0)
   mg.fill(backgroundMarkStart + x - 1, span + y - 1, (w - backgroundMarkStart) + 1, 1, " ")
  end
 end
end

local function ensureOnscreen(monitor, x, y, w, h)
 if monitor <= 0 then monitor = #monitors end
 if monitor >= (#monitors + 1) then monitor = 1 end
 -- Failing anything else, revert to monitor 0
 if #monitors == 0 then monitor = 0 end
 x = math.min(math.max(1, x), monitors[monitor][3] - (w - 1))
 y = math.min(math.max(1, y), monitors[monitor][4] - (h - 1))
 return monitor, x, y
end

-- This is the "a state change occurred" function, only for use when needed
local function reconcileAll()
 for k, v in ipairs(surfaces) do
  -- About to update whole screen anyway so avoid the wait.
  v[1], v[2], v[3] = ensureOnscreen(v[1], v[2], v[3], v[4], v[5])
 end
 for k, v in ipairs(monitors) do
  local mon = v[1]()
  if mon then
   v[3], v[4] = mon.getResolution()
  end
  v[5] = -1
  v[6] = -1
  updateRegion(k, 1, 1, v[3], v[4], {})
 end
end

local function moveSurface(surface, m, x, y, w, h)
 local om, ox, oy, ow, oh = table.unpack(surface, 1, 5)
 m = m or om
 x = x or ox
 y = y or oy
 w = w or ow
 h = h or oh
 surface[1], surface[2], surface[3], surface[4], surface[5] = m, x, y, w, h
 local cache = {}
 if om == m then
  if ow == w then
   if oh == h then
    -- Cheat - perform a GPU copy
    -- this increases "apparent" performance while we're inevitably waiting for the app to catch up,
    -- CANNOT glitch since we're going to draw over this later,
    -- and will usually work since the user can only move focused surfaces
    if renderingAllowed() then
     local cb = monitors[m][1]()
     if cb then
      cb.copy(ox, oy, w, h, x - ox, y - oy)
     end
    end
   end
  end
 end
 updateRegion(om, ox, oy, ow, oh, cache)
 updateRegion(m, x, y, w, h, cache)
end
-- Returns offset from where we expected to be to where we are.
local function ofsSurface(focus, dx, dy)
 local exX, exY = focus[2] + dx, focus[3] + dy
 local m, x, y = ensureOnscreen(focus[1], exX, exY, focus[4], focus[5])
 moveSurface(focus, nil, x, y)
 return focus[2] - exX, focus[3] - exY
end
local function ofsMSurface(focus, dm)
 local m, x, y = ensureOnscreen(focus[1] + dm, focus[2], focus[3], focus[4], focus[5])
 moveSurface(focus, m, x, y)
end

local function handleSpan(target, x, y, text, bg, fg)
 if not renderingAllowed() then return end
 local m = monitors[target[1]]
 local cb = m[1]()
 if not cb then return end
 -- It is assumed basic type checks were handled earlier.
 if y < 1 then return end
 if y > target[5] then return end
 if x < 1 then return end
 -- Note the use of unicode.len here.
 -- It's assumed that if the app is using Unicode text, then it used safeTextFormat earlier.
 -- This works for a consistent safety check.
 local w = unicode.len(text)
 if ((x + w) - 1) > target[4] then return end
 -- Checks complete, now commence screen cropping...
 local worldY = ((y + target[3]) - 1)
 if worldY < 1 then return end
 if worldY > monitors[target[1]][4] then return end
 -- The actual draw loop
 local buildingSegmentWX = nil
 local buildingSegmentWY = nil
 local buildingSegment = nil
 local buildingSegmentE = nil
 local function submitSegment()
  if buildingSegment then
   base = unicode.sub(text, buildingSegment, buildingSegmentE - 1)
   local ext = unicode.sub(text, buildingSegmentE, buildingSegmentE)
   if unicode.charWidth(ext) == 1 then
    base = base .. ext
   else
    -- While the GPU may or may not be able to display "half a character",
    --  getting it to do so reliably is another matter.
    -- In my experience it always leads to drawing errors much worse than if the code was left alone.
    -- If your language uses wide chars and you are affected by a window's positioning...
    -- ... may I ask how, exactly, you intend me to fix it?
    -- My current theory is that for cases where the segment is >= 2 chars (so we have scratchpad),
    --  the GPU might be tricked via a copy.
    -- Then the rest of the draw can proceed as normal,
    --  with the offending char removed.
    base = base .. " "
   end
   monitorGPUColours(m, cb, bg, fg)
   cb.set(buildingSegmentWX, buildingSegmentWY, unicode.undoSafeTextFormat(base))
   buildingSegment = nil
  end
 end
 for i = 1, w do
  local rWX = (i - 1) + (x - 1) + target[2]
  local rWY = (y - 1) + target[3]
  local s = surfaceAt(target[1], rWX, rWY)
  local ok = false
  if s then
   ok = surfaces[s] == target
  end
  if ok then
   if not buildingSegment then
    buildingSegmentWX = rWX
    buildingSegmentWY = rWY
    buildingSegment = i
   end
   buildingSegmentE = i
  else
   submitSegment()
  end
 end
 submitSegment()
end

local function changeFocus(oldSurface, optcache)
 local ns1 = surfaces[1]
 optcache = optcache or {}
 if ns1 ~= oldSurface then
  if oldSurface then
   oldSurface[6]("focus", false)
  end
  if ns1 then
   ns1[6]("focus", true)
  end
  if oldSurface then
   updateRegion(oldSurface[1], oldSurface[2], oldSurface[3], oldSurface[4], oldSurface[5], optcache)
  end
  if ns1 then
   updateRegion(ns1[1], ns1[2], ns1[3], ns1[4], ns1[5], optcache)
  end
 end
end

-- THE EVEREST USER API BEGINS
local surfaceOwners = {}

-- Not relevant here really, but has to be up here because it closes the window
local waitingShutdownCallback = nil
local function checkWSC()
 if waitingShutdownCallback then
  if #surfaces == 0 then
   waitingShutdownCallback()
   waitingShutdownCallback = nil
  end
 end
end

everestProvider(function (pkg, pid, sendSig)
 local base = pkg .. "/" .. pid
 local lid = 0
 return function (w, h, title)
  if dead then error("everest died") end
  w = math.floor(math.max(w, 8))
  h = math.floor(math.max(h, 1)) + 1
  if type(title) ~= "string" then
   title = base
  else
   title = base .. ":" .. title
  end
  local m = 0
  if renderingAllowed() then m = 1 end
  local surf = {m, 1, 1, w, h}
  local focusState = false
  local llid = lid
  lid = lid + 1
  local specialDragHandler
  surf[6] = function (ev, a, b, c)
   -- Must forward surface events
   if ev == "focus" then
    focusState = a
   end
   if ev == "touch" then
    specialDragHandler = nil
    if math.floor(b) == 1 then
     specialDragHandler = function (x, y)
      local ofsX, ofsY = math.floor(x) - math.floor(a), math.floor(y) - math.floor(b)
      if (ofsX == 0) and (ofsY == 0) then return end
      local pX, pY = ofsSurface(surf, ofsX, ofsY)
      --a = a + pX
      --b = b + pY
     end
     return
    end
    b = b - 1
   end
   if ev == "drag" then
    if specialDragHandler then
     specialDragHandler(a, b)
     return
    end
    b = b - 1
   end
   if ev == "line" then
    if a == 1 then
     local lw = surf[4]
     local bg = 0x0080FF
     local fg = 0x000000
     local tx = "-"
     if focusState then
      bg = 0x000000
      fg = 0x0080FF
      tx = "+"
     end
     local vtitle = title
     local vto = unicode.len(vtitle)
     if vto < lw then
      vtitle = vtitle .. (tx):rep(lw - vto)
     else
      vtitle = unicode.sub(vtitle, 1, lw)
     end
     handleSpan(surf, 1, 1, vtitle, bg, fg)
     return
    end
    -- WCHAX : Wide-char-cleanup has to be done left-to-right, so this handles the important part of that.
    handleSpan(surf, surf[4], a, " ", 0, 0)
    a = a - 1
   end
   sendSig(llid, ev, a, b, c)
  end
  local osrf = surfaces[1]
  table.insert(surfaces, 1, surf)
  surfaceOwners[surf] = pid
  changeFocus(osrf)
  return {
   id = llid,
   setSize = function (w, h)
    if dead then return end
    w = math.floor(math.max(w, 8))
    h = math.floor(math.max(h, 1)) + 1
    local _, x, y = ensureOnscreen(surf[1], surf[2], surf[3], w, h)
    moveSurface(surf, nil, x, y, w, h)
    return w, (h - 1)
   end,
   span = function (x, y, text, bg, fg)
    if dead then error("everest died") end
    if type(x) ~= "number" then error("X must be number.") end
    if type(y) ~= "number" then error("Y must be number.") end
    if type(bg) ~= "number" then error("Background must be number.") end
    if type(fg) ~= "number" then error("Foreground must be number.") end
    if type(text) ~= "string" then error("Text must be string.") end
    x, y, bg, fg = math.floor(x), math.floor(y), math.floor(bg), math.floor(fg)
    if y == 0 then return end
    handleSpan(surf, x, y + 1, text, bg, fg)
   end,
   close = function ()
    if dead then return end
    local os1 = surfaces[1]
    surfaceOwners[surf] = nil
    for k, v in ipairs(surfaces) do
     if v == surf then
      table.remove(surfaces, k)
      local cache = {}
      checkWSC()
      changeFocus(os1, cache)
      -- focus up to date, deal with any remains
      updateRegion(surf[1], surf[2], surf[3], surf[4], surf[5], cache)
      return
     end
    end
   end
  }
 end
end)
-- THE EVEREST USER API ENDS (now for the session API, which just does boring stuff)
everestSessionProvider(function (pkg, pid, sendSig)
 return {
  startSession = function ()
   inSession = true
  end,
  endSession = function (startBristol)
   if not inSession then return end
   local m = nil
   if monitors[1] then
    m = monitors[1][2]
   end
   inSession = false
   for k = 1, #monitors do
    screens.disclaim(monitors[k][2])
    monitors[k] = nil
   end
   if startBristol then
    neo.executeAsync("sys-init", m)
   end
   reconcileAll()
   if not startBristol then
    return m
   end
  end
 }
end)
-- THE EVEREST SESSION API ENDS

-- WM shortcuts are:
-- Alt-Z: Switch surface
-- Alt-Enter: Launcher
-- Alt-Up/Down/Left/Right: Move surface
local isAltDown = false
local isCtrDown = false
local function key(ka, kc, down)
 local focus = surfaces[1]
 if kc == 29 then isCtrDown = down end
 if kc == 56 then isAltDown = down end
 if isAltDown then
  if ka == 120 then
   if focus and down then ofsMSurface(focus, 1) end return
  end
  if kc == 200 then
   if focus and down then ofsSurface(focus, 0, -1) end return
  end
  if kc == 208 then
   if focus and down then ofsSurface(focus, 0, 1) end return
  end
  if kc == 203 then
   if focus and down then ofsSurface(focus, -1, 0) end return
  end
  if kc == 205 then
   if focus and down then ofsSurface(focus, 1, 0) end return
  end
  if ka == 122 then
   if focus and down then
    local n = table.remove(surfaces, 1)
    table.insert(surfaces, n)
    changeFocus(n)
   end return
  end
  if ka == 3 then
   -- Ctrl-Alt-C (!?!?!!)
   if isCtrDown then
    error("User-authorized Everest crash.")
   end
  end
  if ka == 99 then
   if down then
    if isCtrDown then
     error("User-authorized Everest crash.")
    else
     if focus then
      focus[6]("close")
     end
    end
   end
   return
  end
  if ka == 13 then
   if down and (not waitingShutdownCallback) then neo.executeAsync("app-launcher") end return
  end
 end
 if focus then
  focus[6]("key", ka, kc, down)
 end
end

while true do
 local s = {coroutine.yield()}
 if renderingAllowed() then
  if s[1] == "h.key_down" then
   key(s[3], s[4], true)
  end
  if s[1] == "h.key_up" then
   key(s[3], s[4], false)
  end
  if s[1] == "h.clipboard" then
   if surfaces[1] then
    surfaces[1][6]("clipboard", s[3])
   end
  end
  -- next on my list: high-res coordinates
  if s[1] == "h.touch" then
   for k, v in ipairs(monitors) do
    if v[2] == s[2] then
     local x, y = math.floor(s[3]), math.floor(s[4])
     local sid, lx, ly = surfaceAt(k, x, y)
     if sid then
      local os = surfaces[1]
      local ns = table.remove(surfaces, sid)
      table.insert(surfaces, 1, ns)
      changeFocus(os)
      ns[6]("touch", lx, ly)
     end
     break
    end
   end
  end
  if s[1] == "h.drag" then
   -- Pass to focus surface, even if out of bounds
   local focus = surfaces[1]
   if focus then
    for k, v in ipairs(monitors) do
     if v[2] == s[2] then
      if k == focus[1] then
       local x, y = (math.floor(s[3]) - focus[2]) + 1, (math.floor(s[4]) - focus[3]) + 1
       focus[6]("drag", x, y)
      end
      break
     end
    end
   end
  end
 else
  isCtrDown = false
  isAltDown = false
 end
 if s[1] == "k.procdie" then
  local os1 = surfaces[1]
  -- Note this is in order (that's important)
  local tags = {}
  for k, v in ipairs(surfaces) do
   if surfaceOwners[v] == s[3] then
    table.insert(tags, k)
    surfaceOwners[v] = nil
   end
  end
  for k, v in ipairs(tags) do
   local surf = table.remove(surfaces, v - (k - 1))
   updateRegion(surf[1], surf[2], surf[3], surf[4], surf[5], {})
  end
  checkWSC()
  changeFocus(os1)
 end
 if s[1] == "x.neo.sys.screens" then
  if s[2] == "available" then
   if inSession then
    local gpu = screens.claim(s[3])
    local gpucb = gpu and (gpu())
    if gpucb then
     local w, h = gpucb.getResolution()
     table.insert(monitors, {gpu, s[3], w, h, -1, -1})
     -- This is required to ensure windows are moved off of the null monitor.
     -- Luckily, there's an obvious sign if they aren't - everest will promptly crash.
     reconcileAll()
    end
   end
  end
  if s[2] == "lost" then
   for k, v in ipairs(monitors) do
    if v[2] == s[3] then
     table.remove(monitors, k)
     reconcileAll()
     break
    end
   end
  end
 end
 if s[1] == "x.neo.sys.manage" then
  if s[2] == "shutdown" then
   waitingShutdownCallback = s[4]
   for k, v in ipairs(surfaces) do
    v[6]("close")
   end
   checkWSC()
  end
 end
end
