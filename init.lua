-- KittenOS

-- ISO 639 language code.
local systemLanguage = "en"

function component.get(tp)
 local a = component.list(tp, true)()
 if not a then return nil end
 return component.proxy(a)
end

local primaryDisk = component.proxy(computer.getBootAddress())
local langFile = primaryDisk.open("language", "rb")
if langFile then
 systemLanguage = primaryDisk.read(langFile, 64)
 primaryDisk.close(langFile)
end
local function loadfile(s, e)
 local h = primaryDisk.open(s)
 if h then
  local ch = ""
  local c = primaryDisk.read(h, 256)
  while c do
   ch = ch .. c
   c = primaryDisk.read(h, 256)
  end
  primaryDisk.close(h)
  return load(ch, "=" .. s, "t", e)
 end
 return nil, "File Unreadable"
end

-- Must be a sane source of time in seconds.
local function saneTime()
 return computer.uptime()
end
local primaryScreen = component.get("screen")
local primaryGPU = component.get("gpu")

primaryGPU.bind(primaryScreen.address)
local scrW, scrH = 50, 16
local frameH = 1
local redrawWorldSoon = true
primaryGPU.setResolution(scrW, scrH)
primaryGPU.setBackground(0x000000)
primaryGPU.setForeground(0xFFFFFF)
primaryGPU.fill(1, 1, scrW, scrH, "#")
-- apps maps aid (Running application ID, like Process ID) to app data
-- appZ handles Z-order
local apps = {}
local appZ = {}
local function sanech(ch, bch)
 if not bch then bch = " " end
 if not ch then return bch end
 if unicode.len(ch) ~= 1 then return bch end
 return ch
end

-- aid
local launchApp = nil
-- text, die
local dialogApp = nil
-- aid, pkg, txt
local openDialog = nil
-- Component of the system that handles file access,
--  does cleanup after dead apps, etc.
local fileWrapper = nil
local drawing = false
local function handleEv(aid, evt, ...)
 local f = apps[aid].i[evt]
 if not f then return end
 local r2 = {pcall(f, ...)}
 if r2[1] then
  return select(2, table.unpack(r2))
 else
  -- possible error during death
  if apps[aid] then
   -- error, override instance immediately.
   local i, w, h = dialogApp(r2[2], apps[aid].A.die)
   -- REALLY BAD STUFF (not much choice)
   local od = drawing
   drawing = false
   apps[aid].i = i
   --apps[aid].i = {}
   apps[aid].A.resize(w, h)
   drawing = od
  else
   openDialog("error-" .. aid, "*error-during-death", r2[2])
  end
 end
end
local needRedraw = {}
local function handleEvNRD(aid, ...)
 local doRedraw = handleEv(aid, ...)
 if doRedraw then needRedraw[aid] = true end
end
-- This function is critical to wide text support.
-- The measures taken below mean that the *system* can deal with wide text,
--  but applications need to have the same spacing rules in place.
-- Since these spacing rules,
--  and the ability to get a wide-char point from a "normal" point,
--  are probably beneficial to everybody anyway,
--  they're exposed here as a unicode function.
function unicode.safeTextFormat(s, ptr)
 local res = ""
 if not ptr then ptr = 1 end
 local aptr = 1
 for i = 1, unicode.len(s) do
  local ch = unicode.sub(s, i, i)
  local ex = unicode.charWidth(ch)
  if i < ptr then
   aptr = aptr + ex
  end
  for j = 2, ex do
   ch = ch .. " "
  end
  res = res .. ch
 end
 return res, aptr
end
-- Do not let wide characters cause weirdness outside home window!!!
local function wideCharSpillFilter(ch, x, doNotTouch)
 if (x + 1) == doNotTouch then
  if unicode.isWide(ch) then
   return "%"
  end
 end
 return ch
end
local function getChar(x, y)
 -- Note: The colours used here tend to
 --       game the autoselect so this works
 --       without any depth nastiness.
 for i = 1, #appZ do
  local k = appZ[(#appZ + 1) - i]
  local title = unicode.safeTextFormat(k)
  local v = apps[k]
  if x >= v.x and x < (v.x + v.w) then
   if y == v.y then
    local bgc = 0x80FFFF
    local bch = "-"
    if i == 1 then bgc = 0x808080 bch = "+" end
    local ch = sanech(unicode.sub(title, (x - v.x) + 1, (x - v.x) + 1), bch)
    return 0x000000, bgc, wideCharSpillFilter(ch, x, v.x + v.w)
   else
    if y > v.y and y < (v.y + v.h + frameH) then
     -- get char from app
     local ch = sanech(handleEv(k, "get_ch", (x - v.x) + 1, (y - (v.y + frameH)) + 1))
     return 0xFFFFFF, 0x000000, wideCharSpillFilter(ch, x, v.x + v.w)
    end
   end
  end
 end
 return 0xFFFFFF, 0x000000, " "
end
local function failDrawing()
 if drawing then error("Cannot call when drawing.") end
end
local function redrawSection(x, y, w, h)
 drawing = true
 primaryGPU.setBackground(0x000000)
 primaryGPU.setForeground(0xFFFFFF)
 local cfg, cbg = 0xFFFFFF, 0x000000
 --primaryGPU.fill(x, y, w, h, " ")
 for ly = 1, h do
  local buf = ""
  local bufX = x
  -- Wide characters are annoying.
  local wideCharacterAdvance = 0
  for lx = 1, w do
   if wideCharacterAdvance == 0 then
    local fg, bg, tx = getChar(x + (lx - 1), y + (ly - 1))
    local flush = false
    if fg ~= cfg then flush = true end
    if bg ~= cbg then flush = true end
    if flush then
     if buf:len() > 0 then
      primaryGPU.set(bufX, y + (ly - 1), buf)
     end
     buf = ""
     bufX = x + (lx - 1)
    end
    if fg ~= cfg then primaryGPU.setForeground(fg) cfg = fg end
    if bg ~= cbg then primaryGPU.setBackground(bg) cbg = bg end
    buf = buf .. tx
    wideCharacterAdvance = unicode.charWidth(tx) - 1
   else
    -- nothing to add to buffer, since the extra "letters" don't count
    wideCharacterAdvance = wideCharacterAdvance - 1
   end
  end
  primaryGPU.set(bufX, y + (ly - 1), buf)
 end
 drawing = false
end
local function redrawApp(aid, onlyBar)
 local h = frameH
 if not onlyBar then h = h + apps[aid].h end
 redrawSection(apps[aid].x, apps[aid].y, apps[aid].w, h)
end
local function hideApp(aid, deferRedraw)
 local function sk()
  for ri, v in ipairs(appZ) do
   if v == aid then table.remove(appZ, ri) return end
  end
 end
 sk()
 if not deferRedraw then
  redrawApp(aid)
  local newFocus = appZ[#appZ]
  if newFocus then redrawApp(newFocus, true) end
 end
 return {apps[aid].x, apps[aid].y, apps[aid].w, apps[aid].h + frameH}
end
local function focusApp(aid, focusUndrawn)
 hideApp(aid, true) -- just ensure it's not on stack, no need to redraw as it won't move
 local lastFocus = appZ[#appZ]
 table.insert(appZ, aid)
 -- make the focus indicator disappear should one exist.
 -- focusUndrawn indicates that the focus was transient and never got drawn
 if lastFocus and (not focusUndrawn) then redrawApp(lastFocus, true) end
 -- Finally, make absolutely sure the application is shown on the screen
 redrawApp(aid)
end
local function moveApp(aid, x, y)
 local section = hideApp(aid, true) -- remove from stack, do NOT redraw
 apps[aid].x = x                    -- (prevents interim focus weirdness)
 apps[aid].y = y
 -- put back on stack, redrawing destination, but not the
 -- interim focus target (since we made sure NOT to redraw that)
 focusApp(aid, true)
 redrawSection(table.unpack(section)) -- handle source cleanup
end
local function ofsApp(aid, x, y)
 moveApp(aid, apps[aid].x + x, apps[aid].y + y)
end
local function killApp(aid)
 hideApp(aid)
 apps[aid] = nil
 if fileWrapper then
  fileWrapper.appDead(aid)
  if fileWrapper.canFree() then
   fileWrapper = nil
  end
 end
end
local getLCopy = nil
function getLCopy(t)
 if type(t) == "table" then
  local t2 = {}
  setmetatable(t2, {__index = function(a, k) return getLCopy(t[k]) end})
  return t2
 else
  return t
 end
end
-- Used to ensure the "primary" device is safe
--  while allowing complete control otherwise.
local function omittingComponentL(o, t)
 local i = component.list(t, true)
 return function()
  local ii = i()
  if ii == o then ii = i() end
  if not ii then return nil end
  return component.proxy(ii)
 end
end
-- Allows for simple "Control any of these connected to the system" APIs,
--  for things the OS shouldn't be poking it's nose in.
local function basicComponentSW(t, primary)
 return {
  list = function()
   local i = component.list(t, true)
   return function ()
    local ii = i()
    if not ii then return nil end
    return component.proxy(ii)
   end
  end,
  primary = primary
 }
end
local function getAPI(s, cAid, cPkg, access)
 if s == "math" then return getLCopy(math) end
 if s == "table" then return getLCopy(table) end
 if s == "string" then return getLCopy(string) end
 if s == "unicode" then return getLCopy(unicode) end
 if s == "root" then return _ENV end
 if s == "stat" then return {
  totalMemory = computer.totalMemory,
  freeMemory = computer.freeMemory,
  energy = computer.energy,
  maxEnergy = computer.maxEnergy,
  clock = os.clock,
  date = os.date,
  difftime = os.difftime,
  time = os.time,
  componentList = component.list
 } end
 if s == "proc" then return {
  aid = cAid,
  pkg = cPkg,
  listApps = function ()
   local t = {}
   local t2 = {}
   for k, v in pairs(apps) do
    table.insert(t, k)
    t2[k] = v.pkg
   end
   table.sort(t)
   local t3 = {}
   for k, v in ipairs(t) do
    t3[k] = {v, t2[v]}
   end
   return t3
  end,
  sendRPC = function (aid, ...)
   if type(aid) ~= "string" then error("aid must be string") end
   if not apps[aid] then error("RPC target does not exist.") end
   return handleEv(aid, "rpc", cPkg, cAid, ...)
  end
 } end
 if s == "lang" then return {
  getLanguage = function ()
   return systemLanguage
  end,
  getTable = function ()
   local ca, cb = loadfile("lang/" .. systemLanguage .. "/" .. cPkg .. ".lua", {})
   if not ca then return nil, cb end
   ca, cb = pcall(ca)
   if not ca then return nil, cb end
   return cb
  end
 } end
 if s == "setlang" then return function (lang)
  if type(lang) ~= "string" then error("Language must be string") end
  systemLanguage = lang
  pcall(function ()
   local langFile = primaryDisk.open("language", "wb")
   if langFile then
    primaryDisk.write(langFile, systemLanguage)
    primaryDisk.close(langFile)
   end
  end)
 end end
 if s == "kill" then return {
  killApp = function (aid) 
   if type(aid) ~= "string" then error("aid must be string") end
   if apps[aid] then killApp(aid) end
  end
 } end
 if s == "randr" then return {
  getResolution = primaryGPU.getResolution,
  maxResolution = primaryGPU.maxResolution,
  setResolution = function (w, h)
   failDrawing()
   if primaryGPU.setResolution(w, h) then
    scrW = w
    scrH = h
    redrawWorldSoon = true
    return true
   end
   return false
  end,
  iterateScreens = function()
   -- List all screens, but do NOT give a primary screen.
   return omittingComponentL(primaryScreen.address, "screen")
  end,
  iterateGPUs = function()
   -- List all GPUs, but do NOT give a primary GPU.
   return omittingComponentL(primaryGPU.address, "gpu")
  end
 } end

 if s == "c.modem" then access["s.modem_message"] = true end
 if s == "c.tunnel" then access["s.modem_message"] = true end
 if s == "c.chat_box" then access["s.chat_message"] = true end

 if s == "c.filesystem" then return basicComponentSW("filesystem", primaryDisk) end
 if s == "c.screen" then return basicComponentSW("screen", primaryScreen) end
 if s == "c.gpu" then return basicComponentSW("gpu", primaryGPU) end
 if s:sub(1, 2) == "c." then return basicComponentSW(s:sub(3)) end
 return nil
end
local function launchAppCore(aid, pkg, f)
 if apps[aid] then return end
 local function fD()
  -- stops potentially nasty situations
  if not apps[aid] then error("App already dead") end
 end
 local A = {
  listApps = function (a) fD()
   local appList = {}
   for _, v in ipairs(primaryDisk.list("apps")) do
    if v:sub(v:len() - 3) == ".lua" then
     table.insert(appList, v:sub(1, v:len() - 4))
    end
   end
   return appList
  end,
  launchApp = function (a) fD()
   if type(a) ~= "string" then error("App IDs are strings") end
   if a:gmatch("[a-zA-Z%-_\x80-\xFF]+")() ~= a then error("App '" .. a .. "' does not seem sane") end
   failDrawing()
   return launchApp(a)
  end,
  opencfg = function (openmode) fD()
   if type(openmode) ~= "string" then
    error("Openmode must be nil or string.")
   end
   local ok = false
   if openmode == "r" then ok = true end
   if openmode == "w" then ok = true end
   if not ok then error("Bad openmode.") end
   if not fileWrapper then
    fileWrapper = loadfile("filewrap.lua", _ENV)()
   end
   return fileWrapper.open(aid, {primaryDisk.address, "cfgs/" .. pkg}, openmode)
  end,
  openfile = function (filetype, openmode) fD()
   if openmode ~= nil then if type(openmode) ~= "string" then
    error("Openmode must be nil or string.")
   end end
   if type(filetype) ~= "string" then error("Filetype must be string.") end
   filetype = aid .. ": " .. filetype
   failDrawing()
   redrawWorldSoon = true
   local rs, rt = pcall(function()
    if fileWrapper then
     if fileWrapper.canFree() then
      fileWrapper = nil
     end
    end
    local r = loadfile("tfilemgr.lua", _ENV)(filetype, openmode, primaryGPU)
    if r and openmode then
     if not fileWrapper then
      fileWrapper = loadfile("filewrap.lua", _ENV)()
     end
     return fileWrapper.open(aid, r, openmode) -- 'r' is table {drive, dir}
    end
   end)
   if not rs then
    openDialog("*fmgr", "FMerr/" .. aid, rt)
   else
    return rt
   end
  end,
  request = function (...) fD()
   failDrawing()
   local requests = {...}
   -- If the same process requests a permission twice,
   --  just let it.
   -- "needed" is true if we still need permission.
   -- first pass confirms we need permission,
   -- second pass asks for it
   local needed = false
   for _, v in ipairs(requests) do
    if type(v) == "string" then
     if not apps[aid].hasAccess[v] then
      needed = true
     end
     if apps[aid].denyAccess[v] then
      return nil -- Don't even bother.
     end
    end
   end
   if needed then
    local r, d = loadfile("policykit.lua", _ENV)(primaryGPU, pkg, requests)
    if r then
     needed = false
    end
    if not d then
     redrawWorldSoon = true
    end
   end
   local results = {}
   for _, v in ipairs(requests) do
    if type(v) == "string" then
     if not needed then
      table.insert(results, getAPI(v, aid, pkg, apps[aid].hasAccess))
      apps[aid].hasAccess[v] = true
     else
      apps[aid].denyAccess[v] = true
     end
    end
   end
   return table.unpack(results)
  end,
  timer = function (ud) fD()
   if type(ud) ~= "number" then error("Timer must take number.") end
   failDrawing()
   if ud > 0 then
    apps[aid].nextUpdate = saneTime() + ud
   else
    apps[aid].nextUpdate = nil
   end
  end,
  resize = function (w, h) fD()
   if type(w) ~= "number" then error("Width must be number.") end
   if type(h) ~= "number" then error("Height must be number.") end
   w = math.floor(w)
   h = math.floor(h)
   if w < 1 then w = 1 end
   if h < 1 then h = 1 end
   failDrawing()
   local dW = apps[aid].w
   local dH = apps[aid].h
   if dW < w then dW = w end
   if dH < h then dH = h end
   apps[aid].w = w
   apps[aid].h = h
   redrawSection(apps[aid].x, apps[aid].y, dW, dH + frameH)
  end,
  die = function () fD()
   failDrawing()
   killApp(aid)
  end
 }
 apps[aid] = {}
 apps[aid].pkg = pkg
 local iDummy = {} -- Dummy object to keep app valid during init.
 apps[aid].i = iDummy
 apps[aid].A = A
 apps[aid].nextUpdate = saneTime()
 apps[aid].hasAccess = {}
 apps[aid].denyAccess = {}
 apps[aid].x = 1
 apps[aid].y = 1
 apps[aid].w = 1
 apps[aid].h = 1
 local i, w, h = f(A)
 if apps[aid] then
  -- If the app triggered an error handler,
  --  then the instance could be replaced, make this act OK
  if apps[aid].i == iDummy then
   apps[aid].i = i
   apps[aid].w = w
   apps[aid].h = h
  end
  focusApp(aid)
  return aid
 end
 -- App self-destructed
end
function launchApp(pkg)
 local aid = 0
 while apps[pkg .. "-" .. aid] do aid = aid + 1 end
 aid = pkg .. "-" .. aid
 return launchAppCore(aid, pkg, function (A)
  local f, fe = loadfile("apps/" .. pkg .. ".lua", {
   A = A,
   assert = assert,     ipairs = ipairs,
   load = load,         next = next,
   pairs = pairs,       pcall = pcall,
   xpcall = xpcall,     rawequal = rawequal,
   rawget = rawget,     rawlen = rawlen,
   rawset = rawset,     select = select,
   type = type,         error = error,
   tonumber = tonumber, tostring = tostring
  })
  if not f then
   return dialogApp(fe, A.die)
  end
  local ok, app, ww, wh = pcall(f)
  if ok and ww and wh then
   ww = math.floor(ww)
   wh = math.floor(wh)
   if ww < 1 then ww = 1 end
   if wh < 1 then wh = 1 end
   return app, ww, wh
  end
  if ok and not ww then app = "No Size" end
  if ok and not wh then app = "No Size" end
  return dialogApp(app, A.die)
 end)
end
-- emergency dialog app
function dialogApp(fe, die)
 fe = tostring(fe)
 local ww, wh = 32, 1
 wh = math.floor(unicode.len(fe) / ww) + 1
 return {
  key = function (ka, kc, down) if ka == 13 and down then die() end end,
  update = function() end, get_ch = function (x, y)
   local p = x + ((y - 1) * ww)
   return unicode.sub(fe, p, p)
  end
 }, ww, wh
end
function openDialog(pkg, aid, txt)
 launchAppCore(pkg, aid, function (A) return dialogApp(txt, A.die) end)
end

-- Perhaps outsource this to a file???
openDialog("Welcome to KittenOS", "~welcome",
--2345678901234567890123456789012
"Alt-(arrow key): Move window.   " ..
"Alt-Enter: Start 'launcher'.    " ..
"Shift-C will generally stop apps" ..
" which don't care about text, or" ..
" don't want any text right now. " ..
"Tab: Switch window.")

-- main WM
local isAltDown = false
local function key(ka, kc, down)
 local focus = appZ[#appZ]
 if kc == 56 then isAltDown = down end
 if isAltDown then
  if kc == 200 then
   if focus and down then ofsApp(focus, 0, -1) end return
  end
  if kc == 208 then
   if focus and down then ofsApp(focus, 0, 1) end return
  end
  if kc == 203 then
   if focus and down then ofsApp(focus, -1, 0) end return
  end
  if kc == 205 then
   if focus and down then ofsApp(focus, 1, 0) end return
  end
  if kc == 46 then
   if focus and down then killApp(focus) end return
  end
  if ka == 13 then
   if down then launchApp("launcher") end return
  end
 end
 if kc == 15 then
  if focus and down then focusApp(appZ[1]) end
  return
 end
 if focus then
  handleEvNRD(focus, "key", ka, kc, down)
 end
end

while true do
 local maxTime = 480
 local now = saneTime()
 for k, v in pairs(apps) do
  if v.nextUpdate then
   local timeIn = v.nextUpdate - now
   if timeIn <= 0 then
    v.nextUpdate = nil
    handleEvNRD(k, "update")
    if v.nextUpdate then
     timeIn = v.nextUpdate - now
    end
   end
   if timeIn > 0 then
    maxTime = math.min(maxTime, timeIn)
   end
  end
 end
 for k, v in pairs(needRedraw) do if v then
  if apps[k] and not redrawWorldSoon then
   redrawApp(k)
  end
  needRedraw[k] = nil
 end end
 if redrawWorldSoon then
  redrawWorldSoon = false
  redrawSection(1, 1, scrW, scrH)
 end
 local signal = {computer.pullSignal(maxTime)}
 local t, p1, p2, p3, p4 = table.unpack(signal)
 if t then
  for k, v in pairs(apps) do
   if v.hasAccess["root"] or v.hasAccess["s." .. t] then
    handleEvNRD(k, "event", table.unpack(signal))
   end
  end
  if t == "key_down" then
   key(p2, p3, true)
  end
  if t == "key_up" then
   key(p2, p3, false)
  end
  if t == "clipboard" then
   local focus = appZ[#appZ]
   if focus then
    handleEvNRD(focus, "clipboard", p2)
   end
  end
 end
end
