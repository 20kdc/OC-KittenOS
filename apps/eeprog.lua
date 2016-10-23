local lang, unicode = A.request("lang", "unicode")
local eeprom = A.request("c.eeprom")
if eeprom then
 eeprom = eeprom.list()()
end

local langTable = lang.getTable()
local function G(text)
 if langTable then
  if langTable[text] then
   return langTable[text]
  end
 end
 return text
end

local postFlash = false
local label = ""
local app = {}
function app.key(ka, kc, down)
 if down then
  if postFlash then
   if ka ~= 0 then
    if ka == 8 then
     label = unicode.sub(label, 1, unicode.len(label) - 1)
     return true
    end
    if ka == 13 then
     eeprom.setLabel(label)
     postFlash = false
     return true
    end
    label = label .. unicode.char(ka)
    return true
   end
   return false
  end
  if ka == ("r"):byte() then
   local f = A.openfile(G("EEPROM Dump"), "w")
   if f then
    f.write(eeprom.get())
    f.close()
   end
  end
  if ka == ("w"):byte() then
   local f = A.openfile(G("EEPROM to flash"), "r")
   if f then
    local txt = f.read(128)
    local ch = ""
    while txt do
     ch = ch .. txt
     txt = f.read(128)
    end
    eeprom.set(ch)
    postFlash = true
    label = ""
    return true
   end
  end
  if ka == ("C"):byte() then
   A.die()
   return false
  end
 end
end
-- this string must be the longest, kind of bad but oh well
-- at least it's not a forced 29 chars...
local baseString = unicode.safeTextFormat(G("EEPROMFlash! (R)ead, (W)rite?"))
function app.get_ch(x, y)
 if postFlash then
  return unicode.sub(unicode.safeTextFormat(G("Label: ") .. label), x, x)
 end
 if not eeprom then
  return unicode.sub(unicode.safeTextFormat(G("No EEPROM installed?")), x, x)
 end
 return unicode.sub(baseString, x, x)
end
return app, unicode.len(baseString), 1