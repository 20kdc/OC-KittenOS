-- resset: resolution changer
-- Typed from within.
local math, randr = A.request("math", "randr")
local app = {}
local mW, mH = randr.maxResolution()
-- important on 5.3, and 5.3 prevents
-- the nasty memory self-destructs!
mW = math.floor(mW) mH = math.floor(mH)
local sW, sH = randr.getResolution()
sW = math.floor(sW) sH = math.floor(sH)
local function mkstr(title, w, h)
 return title .. ":" .. math.floor(w) .. "x" .. math.floor(h)
end
function app.get_ch(x, y)
 local strs = {
  mkstr("cur", randr.getResolution()),
  mkstr("new", sW, sH)
 }
 return strs[y]:sub(x, x)
end
local function modres(w, h)
 sW = sW + w
 sH = sH + h
 if sW > mW then sW = mW end
 if sH > mH then sH = mH end
 if sW < 1 then sW = 1 end
 if sH < 1 then sH = 1 end
 return true
end
function app.key(ka, kc, down)
 if down then
  if kc == 200 then
   return modres(0, -1)
  end
  if kc == 208 then
   return modres(0, 1)
  end
  if kc == 203 then
   return modres(-1, 0)
  end
  if kc == 205 then
   return modres(1, 0)
  end
  if ka == 13 then
   if randr.setResolution(sW, sH) then
    pcall(function()
     local f = A.opencfg("w")
     f.write(sW .. " " .. sH)
     f.close()
    end)
   end
   return true
  end
  if ka == ("C"):byte() then
   A.die()
  end
 end
 return false
end
-- Config stuff!
pcall(function()
 local f = A.opencfg("r")
 if f then
  local txt = f.read(64)
  local nt = txt:gmatch("[0-9]+")
  sW = math.floor(tonumber(nt()))
  sH = math.floor(tonumber(nt()))
  modres(0, 0)
  f.close()
 end
end)
return app, 12, 2