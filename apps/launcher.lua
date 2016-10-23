-- Application launcher
local table, unicode = A.request("table", "unicode")
local apps = A.listApps()
local maxlen = 1
for _, v in ipairs(apps) do
 if unicode.len(v) > maxlen then maxlen = unicode.len(v) end
end
local app = {}
local cursor = 1
function app.get_ch(x, y)
 if x == 1 then
  if y == cursor then return ">" else return " " end
 end
 local s = apps[y]
 if not s then s = "FIXME" end
 return unicode.sub(unicode.safeTextFormat(s), x - 1, x - 1)
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
   if cursor > #apps then cursor = #apps end
   return true
  end
  if ka == 13 then
   A.launchApp(apps[cursor])
  end
  if ka == ("C"):byte() then
   A.die()
  end
 end
end
return app, maxlen + 1, #apps