-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- s-everest

-- Terminology:
-- "monitor": Either the Null Virtual Monitor[0] (a safetynet),
--             or an actual GPU/Screen pair managed by Glacier.
-- "surface": Everest system-level drawing primitive
-- "window" : Everest user-level wrapper around a surface providing a reliable window frame, movement, etc.
-- "line"   : A Wx1 area across a surface.
-- "span"   : A ?x1 area across a surface with text and a single fg/bg colour.
-- This has less user calls as opposed to the old KittenOS system, which had a high CPU usage.
-- Another thing to note is that Everest still uses callbacks, both for efficiency and library convenience,
--  though with automatically closing windows on process death.

-- How Bristol talks to this is:
-- 1. The user logs in
-- 2. Bristol starts up Everest, and frees the primary monitor
-- 3. The primary monitor is claimed by Everest and becomes monitor 1
-- 4. After a small time, Bristol dies, unclaiming all monitors
-- 5. Everest claims the new monitors, and the desktop session begins
-- 6. Everest shuts down for some reason,
--     sys-init gets started UNLESS endSession(false) was used

local everestProvider = neo.requireAccess("r.neo.pub.window", "registering npw")
local everestSessionProvider = neo.requireAccess("r.neo.sys.session", "registering nsse")

-- Got mutexes. Now setup saving throw and shutdown callback
-- Something to note is that Donkonit is the safety net on this,
--  as it auto-releases the monitors.
local screens = neo.requireAccess("x.neo.sys.screens", "access to screens")

neo.requestAccess("s.h.clipboard")
neo.requestAccess("s.h.touch")
neo.requestAccess("s.h.drag")
neo.requestAccess("s.h.drop")
neo.requestAccess("s.h.scroll")
neo.requestAccess("s.h.key_up")
neo.requestAccess("s.h.key_down")

-- {gpu, screenAddr, w, h, bg, fg}
local monitors = {}

-- NULL VIRTUAL MONITOR!
-- This is where we stuff processes until monitors show up
monitors[0] = {nil, nil, 160, 50}

-- {monitor, x, y, w, h, callback, title}
-- callback events are:
-- key ka kc down
-- line y
local surfaces = {}

-- Last Interact Monitor
local lIM = 1

-- Stops the main loop
local shuttingDown = false

-- Also used for settings.
local savingThrow = neo.requestAccess("x.neo.sys.manage")

local draggingWindowX, draggingWindowY

local function suggestAppsStop()
 for k, v in ipairs(surfaces) do
  for i = 1, 4 do
   v[6](v[8], "close")
  end
 end
end

local function dying()
 local primary = (monitors[1] or {})[2] or ""
 for _, v in ipairs(monitors) do
  pcall(screens.disclaim, v[2])
 end
 monitors = {}
 neo.executeAsync("sys-init", primary)
 -- In this case the surfaces are leaked and hold references here. They have to be removed manually.
 -- Do this via a "primary event" (k.deregistration) and "deathtrap events"
 -- If a process evades the deathtrap then it clearly has reason to stay alive regardless of Everest status.
 -- Also note, should savingThrow fail, neo.dead is now a thing.
 for _, v in ipairs(surfaces) do
  pcall(v[6], v[8], "line", 1)
  pcall(v[6], v[8], "line", 2)
 end
 surfaces = {}
end
if savingThrow then
 savingThrow.registerForShutdownEvent()
 savingThrow.registerSavingThrow(dying)
end

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

-- Always use the first if the GPU has been rebound
local function monitorResetBF(m)
 m[5] = -1
 m[6] = -1
end
local function monitorGPUColours(m, cb, bg, fg)
 local nbg = m[5]
 local nfg = m[6]
 if nbg ~= bg then
  pcall(cb.setBackground, bg)
  m[5] = bg
 end
 if nfg ~= fg then
  pcall(cb.setForeground, fg)
  m[6] = fg
 end
end

-- Status line at top of screen
local statusLine = nil

local function doBackgroundLine(m, mg, bdx, bdy, bdl)
 if statusLine and (bdy == 1) then
  -- Status bar
  monitorGPUColours(m, mg, 0x000000, 0xFFFFFF)
  local str = unicode.sub(statusLine, bdx, bdx + bdl - 1)
  local strl = unicode.len(str)
  pcall(mg.set, bdx, bdy, unicode.undoSafeTextFormat(str))
  pcall(mg.set, bdx + strl, bdy, (" "):rep(bdl - strl))
 else
  monitorGPUColours(m, mg, 0x000040, 0)
  pcall(mg.set, bdx, bdy, (" "):rep(bdl))
 end
end

local function handleSpan(target, x, y, text, bg, fg)
 if not renderingAllowed() then return end
 local m = monitors[target[1]]
 local cb, rb = m[1]()
 if not cb then return end
 if rb then
  monitorResetBF(m)
 end
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
   base = unicode.sub(text, buildingSegment, buildingSegmentE)
   -- rely on undoSafeTextFormat for this transform now
   monitorGPUColours(m, cb, bg, fg)
   pcall(cb.set, buildingSegmentWX, buildingSegmentWY, unicode.undoSafeTextFormat(base))
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

local function updateRegion(monitorId, x, y, w, h, surfaceSpanCache)
 if not renderingAllowed() then return end
 local m = monitors[monitorId]
 local mg, rb = m[1]()
 if not mg then return end
 if rb then
  monitorResetBF(m)
 end
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
 -- WCHAX: end

 for span = 1, h do
  local backgroundMarkStart = nil
  for sx = 1, w do
   local t, tx, ty = surfaceAt(monitorId, sx + x - 1, span + y - 1)
   if t then
    -- Background must occur first due to wide char weirdness
    if backgroundMarkStart then
     local bdx, bdy, bdl = backgroundMarkStart + x - 1, span + y - 1, sx - backgroundMarkStart
     doBackgroundLine(m, mg, bdx, bdy, bdl)
     backgroundMarkStart = nil
    end
    if not surfaceSpanCache[monitorId .. "_" .. t .. "_" .. ty] then
     surfaceSpanCache[monitorId .. "_" .. t .. "_" .. ty] = true
     if ty == 1 then
      local lw = surfaces[t][4]
      local bg = 0x0080FF
      local fg = 0x000000
      local tx = "-"
      if t == 1 then
       bg = 0x000000
       fg = 0x0080FF
       tx = "+"
      end
      local vtitle = surfaces[t][7]
      local vto = unicode.len(vtitle)
      if vto < lw then
       vtitle = vtitle .. (tx):rep(lw - vto)
      else
       vtitle = unicode.sub(vtitle, 1, lw)
      end
      handleSpan(surfaces[t], 1, 1, vtitle, bg, fg)
     else
      surfaces[t][6](surfaces[t][8], "line", ty - 1)
     end
    end
   elseif not backgroundMarkStart then
    backgroundMarkStart = sx
   end
  end
  if backgroundMarkStart then
   doBackgroundLine(monitors[monitorId], mg, backgroundMarkStart + x - 1, span + y - 1, (w - backgroundMarkStart) + 1)
  end
 end
end

local function updateStatus()
 statusLine = "Λ-¶: menu (launch 'control' to logout)"
 if surfaces[1] then
  if #monitors > 1 then
   --            123456789X123456789X123456789X123456789X123456789X
   statusLine = "Λ-+: move, Λ-Z: switch, Λ-X: swMonitor, Λ-C: close"
  else
   statusLine = "Λ-+: move, Λ-Z: switch, Λ-C: close"
  end
 end
 statusLine = unicode.safeTextFormat(statusLine)
 for k, v in ipairs(monitors) do
  updateRegion(k, 1, 1, v[3], 1, {})
 end
end

local function ensureOnscreen(monitor, x, y, w, h)
 if monitor <= 0 then monitor = #monitors end
 if monitor >= (#monitors + 1) then monitor = 1 end
 -- Failing anything else, revert to monitor 0
 if #monitors == 0 then monitor = 0 end
 x = math.min(math.max(x, 1), monitors[monitor][3] - (w - 1))
 y = math.max(2 - h, math.min(monitors[monitor][4], y))
 return monitor, x, y
end

-- This is the "a state change occurred" function, only for use when needed
local function reconcileAll()
 for k, v in ipairs(surfaces) do
  -- About to update whole screen anyway so avoid the wait.
  v[1], v[2], v[3] = ensureOnscreen(v[1], v[2], v[3], v[4], v[5])
 end
 local k = 1
 while k <= #monitors do
  local v = monitors[k]
  local mon, rb = v[1]()
  if rb then
   monitorResetBF(v)
  end
  if mon then
   -- This *can* return null if something went wonky. Let's detect that
   v[3], v[4] = mon.getResolution()
   if not v[3] then
    neo.emergency("everest: monitor went AWOL and nobody told me u.u")
    table.remove(monitors, k)
    v = nil
   end
  end
  if v then
   updateRegion(k, 1, 1, v[3], v[4], {})
   k = k + 1
  end
 end
 updateStatus()
end

-- NOTE: If the M, X, Y, W and H are the same, this function ignores you, unless you put , true on the end.
local function moveSurface(surface, m, x, y, w, h, force)
 local om, ox, oy, ow, oh = table.unpack(surface, 1, 5)
 m = m or om
 x = x or ox
 y = y or oy
 w = w or ow
 h = h or oh
 surface[1], surface[2], surface[3], surface[4], surface[5] = m, x, y, w, h
 local cache = {}
 if om == m and ow == w and oh == h then
  if ox == x and oy == y and not force then
   return
  end
  -- note: this doesn't always work due to WC support, and due to resize-to-repaint
  if renderingAllowed() and not force then
   local cb, b = monitors[m][1]()
   if b then
    monitorResetBF(monitors[m])
   end
   if cb then
    local monH = monitors[m][4]
    local cutTop = math.max(0, 1 - math.min(oy, y))
    local cutBottom = math.max(0, (math.max(oy + oh, y + h) - 1) - monH)
    pcall(cb.copy, ox, oy + cutTop, w, h - (cutTop + cutBottom), x - ox, y - oy)
    if surface == surfaces[1] then
     local cacheControl = {}
     for i = 1 + cutTop, h - cutBottom do
      cacheControl[om .. "_1_" .. i] = true
     end
     updateRegion(om, ox, oy, ow, oh, cacheControl)
     return
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

local basePalT2 = {
 -- on T2 we provide 'system colours' by default
 0x000000, 0x0080FF, 0x000040, 0xFFFFFF,
 -- stuff above cannot be altered by user applications, to prevent graphical glitches.
 -- Provide some shades of grey to try and prevent accidental chroma.
 0x182828, 0x404040, 0x686868, 0x909090,
 0xB8B8B8, 0xE0E0E0, 0x800080, 0xFF0000,
 0x808000, 0x00FF00, 0x008080, 0x0000FF
}
local basePalT3 = {
 -- on T3 we provide the Tier 3 pal.
 0x0F0F0F, 0x1E1E1E, 0x2D2D2D, 0x3C3C3C,
 0x4B4B4B, 0x5A5A5A, 0x696969, 0x787878,
 0x878787, 0x969696, 0xA5A5A5, 0xB4B4B4,
 0xC3C3C3, 0xD2D2D2, 0xE1E1E1, 0xF0F0F0
}

local function setSurfacePalette(surf, pal)
 if neo.dead then return 0 end
 local m = monitors[surf[1]]
 if not m then return 0 end
 local cb, rb = m[1]()
 if not cb then return 0 end
 local dok, depth = pcall(cb.getDepth)
 if not dok then depth = 4 end
 if rb then
  monitorResetBF(m)
 end
 local ko = -1
 local unlocked = false
 if not rawequal(pal, nil) then
  neo.ensureType(pal, "table")
  if depth < 8 then
   ko = 3 -- start overriding at indexes 4+
  end
 elseif depth < 8 then
  pal = basePalT2
  unlocked = true
 else
  pal = basePalT3
  unlocked = true
 end
 for k, v in ipairs(pal) do
  -- prevent graphical glitches for
  -- critical system colours on T3
  local av = v % 0x1000000
  if unlocked or (av ~= 0xFFFFFF and
     av ~= 0x000000 and
     av ~= 0x0080FF and
     av ~= 0x000040) then
   local ok = pcall(cb.setPaletteColor, k + ko, v)
   if not ok then return k - 1 end
  end
 end
 return #pal
end

local function changeFocus(oldSurface, optcache)
 local ns1 = surfaces[1]
 optcache = optcache or {}
 if ns1 ~= oldSurface then
  if oldSurface then
   setSurfacePalette(oldSurface, nil)
   oldSurface[6](oldSurface[8], "focus", false)
  end
  if ns1 then
   setSurfacePalette(ns1, nil)
   ns1[6](ns1[8], "focus", true)
  end
  updateStatus()
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
  if neo.dead then error("everest died") end
  if shuttingDown or waitingShutdownCallback then error("system shutting down") end
  w = math.floor(math.max(w, 8))
  h = math.floor(math.max(h, 1)) + 1
  if type(title) ~= "string" then
   title = base
  else
   title = base .. ":" .. title
  end
  local llid = lid
  lid = lid + 1
  local surf = {math.min(#monitors, math.max(1, lIM)), 1, 2, w, h, sendSig, title, llid}
  if h >= monitors[surf[1]][4] then
   surf[3] = 1
  end
  local osrf = surfaces[1]
  table.insert(surfaces, 1, surf)
  surfaceOwners[surf] = pid
  changeFocus(osrf)
  return {
   id = llid,
   setSize = function (w, h)
    if neo.dead then return end
    w = math.floor(math.max(w, 8))
    h = math.floor(math.max(h, 1)) + 1
    local _, x, y = ensureOnscreen(surf[1], surf[2], surf[3], w, h)
    moveSurface(surf, nil, x, y, w, h, true)
    return w, (h - 1)
   end,
   getDepth = function ()
    if neo.dead then return 1 end
    local m = monitors[surf[1]]
    if not m then return 1 end
    local cb, rb = m[1]()
    if not cb then return 1 end
    if rb then
     monitorResetBF(m)
    end
    return cb.getDepth()
   end,
   span = function (x, y, text, bg, fg)
    if neo.dead then error("everest died") end
    checkArg(3, text, "string")
    x, y, bg, fg = math.floor(x), math.floor(y), math.floor(bg), math.floor(fg)
    if y == 0 then return end
    handleSpan(surf, x, y + 1, text, bg, fg)
   end,
   recommendPalette = function (pal)
    if surfaces[1] ~= surf then return 0 end
    return setSurfacePalette(surf, pal)
   end,
   close = function ()
    if neo.dead then return end
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
-- used later on for lost monitor, too
local function disclaimMonitor(mon)
 checkArg(1, mon, "string")
 screens.disclaim(mon)
 for k, v in ipairs(monitors) do
  if v[2] == mon then
   table.remove(monitors, k)
   reconcileAll()
   return true
  end
 end
 return false
end
everestSessionProvider(function (pkg, pid, sendSig)
 return {
  endSession = function (gotoBristol)
   checkArg(1, gotoBristol, "boolean")
   shuttingDown = true
   if gotoBristol then
    suggestAppsStop()
    dying()
   end
  end,
  getMonitors = function ()
   local details = {}
   for k, v in ipairs(monitors) do
    details[k] = v[2]
   end
   return details
  end,
  disclaimMonitor = disclaimMonitor
 }
end)
-- THE EVEREST SESSION API ENDS

local function startLauncher()
 if not waitingShutdownCallback then
  local lApp = "app-launcher"
  if savingThrow then
   lApp = savingThrow.getSetting("sys-everest.launcher") or lApp
  end
  if lApp then
   neo.executeAsync(lApp)
  end
 end
end

-- WM shortcuts are:
-- Alt-Z: Switch surface
-- Alt-Enter: Launcher
-- Alt-Up/Down/Left/Right: Move surface
local isAltDown = false
local isCtrDown = false
local function key(ku, ka, kc, down)
 local ku = screens.getMonitorByKeyboard(ku)
 if not ku then return end
 for k, v in ipairs(monitors) do
  if v[2] == mu then
   lIM = k
  end
 end
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
  if ka == 97 then
   if not down then
    isAltDown = false
   end
   return
  end
  if ka == 3 or ka == 99 then
   if down then
    if isCtrDown then
     error("User-authorized Everest crash.")
    else
     if focus then
      focus[6](focus[8], "close")
     end
    end
   end
   return
  end
  if ka == 13 then
   if down then
    startLauncher()
   end
   return
  end
 end
 if focus then
  if kc ~= 56 then
   lIM = focus[1]
  end
  focus[6](focus[8], "key", ka, kc, down)
 end
end

-- take all displays!
local function performClaim(s3)
 local gpu, _ = screens.claim(s3)
 local gpucb = gpu and (gpu())
 if gpucb then
  local w, h = gpucb.getResolution()
  table.insert(monitors, {gpu, s3, w, h, -1, -1})
  setSurfacePalette({#monitors}, nil)
  -- This is required to ensure windows are moved off of the null monitor.
  -- Luckily, there's an obvious sign if they aren't - everest will promptly crash.
  reconcileAll()
 end
end

for _, v in ipairs(screens.getClaimable()) do
 performClaim(v)
end

while not shuttingDown do
 local s = {coroutine.yield()}
 if renderingAllowed() then
  if s[1] == "h.key_down" then
   key(s[2], s[3], s[4], true)
  end
  if s[1] == "h.key_up" then
   key(s[2], s[3], s[4], false)
  end
  if s[1] == "h.clipboard" then
   if surfaces[1] then
    surfaces[1][6](surfaces[1][8], "clipboard", s[3])
   end
  end
  -- next on my list: high-res coordinates
  if s[1] == "h.touch" then
   for k, v in ipairs(monitors) do
    if v[2] == s[2] then
     lIM = k
     local x, y = math.ceil(s[3]), math.ceil(s[4])
     local ix, iy = s[3] - math.floor(x), s[4] - math.floor(y)
     local sid, lx, ly = surfaceAt(k, x, y)
     if sid then
      local os = surfaces[1]
      local ns = table.remove(surfaces, sid)
      table.insert(surfaces, 1, ns)
      changeFocus(os)
      draggingWindowX, draggingWindowY = nil
      if ly == 1 then
       if s[5] == 1 then
        ns[6](ns[8], "close")
       else
        draggingWindowX, draggingWindowY = lx, ly
       end
      else
       ns[6](ns[8], "touch", lx, ly - 1, ix, iy, s[5])
      end
     else
      if s[5] == 1 then startLauncher() end
     end
     break
    end
   end
  end
  if s[1] == "h.drag" or s[1] == "h.drop" or s[1] == "h.scroll" then
   -- Pass to focus surface, even if out of bounds
   local focus = surfaces[1]
   if focus then
    for k, v in ipairs(monitors) do
     if v[2] == s[2] then
      if k == focus[1] then
       local x, y = (math.ceil(s[3]) - focus[2]) + 1, (math.ceil(s[4]) - focus[3]) + 1
       local ix, iy = s[3] - math.floor(s[3]), s[4] - math.floor(s[4])
       if s[1] == "h.drag" and draggingWindowX then
        local ofsX, ofsY = x - draggingWindowX, y - draggingWindowY
        if ofsX ~= 0 or ofsY ~= 0 then
         ofsSurface(focus, ofsX, ofsY)
        end
       else
        draggingWindowX, draggingWindowY = nil
        -- Ok, so let's see...
        focus[6](focus[8], s[1]:sub(3), x, y - 1, ix, iy, s[5])
       end
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
   if os1 == surf then
    os1 = nil
   end
   updateRegion(surf[1], surf[2], surf[3], surf[4], surf[5], {})
  end
  checkWSC()
  if os1 then
   changeFocus(os1)
  else
   changeFocus()
  end
 end
 if s[1] == "x.neo.sys.screens" then
  if s[2] == "available" then
   performClaim(s[3])
  end
  if s[2] == "lost" then
   disclaimMonitor(s[3])
  end
 end
 if s[1] == "x.neo.sys.manage" then
  if s[2] == "shutdown" then
   waitingShutdownCallback = s[4]
   suggestAppsStop()
   checkWSC()
  end
 end
end
