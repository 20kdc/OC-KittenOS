local lang, setlang, math, table, unicode, fs = A.request("lang", "setlang", "math", "table", "unicode", "c.filesystem")

local options = {}
local optionCallback = function (index) end
local cursor = 1
local inited = false

local languages = {}
local languagesMenu = {}
local languageNames = {
 ["en"] = "English",
 ["de"] = "German",
 ["ru"] = "Russian",
 ["jbo"] = "Lojban",
 ["ja"] = "Japanese",
 ["kw"] = "Cornish",
 ["nl"] = "Dutch",
 ["pl"] = "Polish",
 ["pt"] = "Portugese",
 ["zh"] = "Chinese",
 ["it"] = "Italian",
 ["ga"] = "Irish",
 ["fr"] = "French",
 ["es"] = "Spanish",
 ["pirate"] = "I be speakin' Pirate!"
}
for k, v in pairs(languageNames) do
 if fs.primary.exists("lang/" .. k .. "/installer.lua") or (k == "en") then
  table.insert(languages, k)
  table.insert(languagesMenu, v)
 end
end

local langTable = nil
local function G(text)
 if langTable then
  if langTable[text] then
   return langTable[text]
  end
 end
 return text
end

-- Config
local appDeny = {}
local installFS = nil
local installLang = nil

-- Stages
local startLanguageSel = nil
local startFSSel = nil
local startAppSel = nil
local startFSConfirm = nil
local startInstall = nil

-- Stuff for actual install
local runningInstall = nil
local runningInstallPoint = 0

local function setOptions(ol, callback)
 options = ol
 optionCallback = callback
 cursor = 1
 local maxlen = 1
 for k, v in ipairs(options) do
  options[k] = unicode.safeTextFormat(v)
  local l = unicode.len(v)
  if l > maxlen then maxlen = l end
 end
 A.resize(maxlen + 1, #options)
end

local app = {}
function startLanguageSel()
 setOptions(languagesMenu, function (i)
  setlang(languages[i])
  langTable = lang.getTable()
  startAppSel()
 end)
end
function startAppSel()
 local al = A.listApps()
 table.sort(al)
 local tbl = {}
 table.insert(tbl, G("KittenOS Installer"))
 table.insert(tbl, G("Applications to install:"))
 for _, v in ipairs(al) do
  table.insert(tbl, G("Install Application: ") .. v .. " [" .. G(tostring(not appDeny[v])) .. "]")
 end
 table.insert(tbl, G("<Confirm>"))
 setOptions(tbl, function (i)
  if i >= 3 and i < #tbl then
   appDeny[al[i - 2]] = not appDeny[al[i - 2]]
   startAppSel()
   return
  end
  if i == #tbl then
   startFSSel()
  end
 end)
end
function startFSSel()
 local fsl = {}
 for fsp in fs.list() do
  if fsp ~= fs.primary then
   table.insert(fsl, fsp.address)
  end
 end
 local tbl = {}
 table.insert(tbl, G("KittenOS Installer"))
 table.insert(tbl, G("Filesystem to target:"))
 for _, v in ipairs(fsl) do
  table.insert(tbl, "<" .. v .. ">")
 end
 setOptions(tbl, function (i)
  if i > 2 then
   for fsp in fs.list() do
    if fsp.address == fsl[i - 2] then
     installFS = fsp
     startFSConfirm()
     return
    end
   end
   startFSSel()
  end
 end)
end
function startFSConfirm()
 local tbl = {}
 table.insert(tbl, G("KittenOS Installer"))
 table.insert(tbl, G("Are you sure you want to install to FS:"))
 table.insert(tbl, installFS.address)
 table.insert(tbl, G("These applications will be installed:"))
 local other = nil
 for _, v in ipairs(A.listApps()) do
  if not appDeny[v] then
   if other then
    table.insert(tbl, other .. ", " .. v)
    other = nil
   else
    other = v
   end
  end
 end
 if other then
  table.insert(tbl, other)
 end
 table.insert(tbl, G("<Yes>"))
 table.insert(tbl, G("<No, change settings>"))
 setOptions(tbl, function (i)
  if i == (#tbl - 1) then
   -- first, create directories.
   local function forceMakeDirectory(s)
    if installFS.exists(s) then
     if not installFS.isDirectory(s) then
      installFS.remove(s)
     end
    end
    installFS.makeDirectory(s)
   end
   installLang = lang.getLanguage()
   forceMakeDirectory("apps")
   forceMakeDirectory("cfgs")
   forceMakeDirectory("lang")
   forceMakeDirectory("lang/" .. installLang)
   runningInstall = {
    -- in order of importance
    "init.lua",
    "policykit.lua",
    "tfilemgr.lua",
    "filewrap.lua",
    "language"
   }
   for _, v in ipairs(A.listApps()) do
    if not appDeny[v] then
     table.insert(runningInstall, "apps/" .. v .. ".lua")
     if fs.primary.exists("lang/" .. installLang .. "/" .. v .. ".lua") then
      table.insert(runningInstall, "lang/" .. installLang .. "/" .. v .. ".lua")
     end
    end
   end
   runningInstallPoint = 1
   startInstall()
  end
  if i == #tbl then
   startAppSel()
  end
 end)
end
function startInstall()
 local percent = math.floor((runningInstallPoint / #runningInstall) * 100)
 local tbl = {
  G("Installing.") .. " " .. percent .. "%"
 }
 setOptions(tbl, function (i) end)
 A.timer(1)
end
function startComplete()
 setOptions({G("Installation complete."), G("Press Shift-C to leave.")}, function (i) end)
end
function app.update()
 if runningInstall then
  if runningInstall[runningInstallPoint] then
   local txt = runningInstall[runningInstallPoint]
   -- perform copy
   local h2 = installFS.open(txt, "wb")
   if txt == "language" then
    if installLang then
     installFS.write(h2, installLang)
    else
     installFS.write(h2, "en")
    end
   else
    local h = fs.primary.open(txt, "rb")
    local chk = fs.primary.read(h, 1024)
    while chk do
     installFS.write(h2, chk)
     chk = fs.primary.read(h, 1024)
    end
    fs.primary.close(h)
   end
   installFS.close(h2)
   startInstall()
   runningInstallPoint = runningInstallPoint + 1
  else
   runningInstall = nil
   startComplete()
  end
  return true
 end
 -- should only be called once, but just in case
 if not inited then
  startLanguageSel()
  inited = true
 end
 return true
end
function app.get_ch(x, y)
 if x == 1 then
  if y == cursor then return ">" else return " " end
 end
 local s = options[y]
 if not s then s = "FIXME" end
 return unicode.sub(s, x - 1, x - 1)
end
function app.key(ka, kc, down)
 if down then
  if kc == 200 then
   cursor = cursor - 1
   if cursor < 1 then cursor = 1 end
   return true
  end
  if kc == 208 then
   cursor = cursor + 1
   if cursor > #options then cursor = #options end
   return true
  end
  if ka == 13 then
   optionCallback(cursor)
   return true
  end
  if ka == ("C"):byte() then
   A.die()
  end
 end
end
return app, 1, 1
