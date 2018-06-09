-- This is released into the public domain. XX
-- No warranty is provided, implied or otherwise. XX
local sector = io.write -- XX
-- XX
-- BUNDIVIDE (r5 edition) reference implementation for integration XX
-- Lines ending with XX are not included in the output. XX
-- Lines that both start and end with -- are only for use in the output, XX
--  and are thus not executed during any sanity-check procedure. XX
-- XX
Cp,Ct,Cc,Cw="","","",("\x00"):rep(65536)
-- High-level breakdown: XX
-- CP is unescaper & TAR-sector-breakup. XX
-- It'll only begin to input if at least 3 bytes are available, XX
--  so you'll want to throw in 2 extra zeroes at the end of stream as done here. XX
-- It uses Ct (input buffer) and Cp (output buffer). XX
-- Ignore its second argument, as that's a lie, it's just there for a local. XX
-- CD is the actual decompressor. It has the same quirk as CP, wanting two more bytes. XX
-- It stores to Cc (compressed), and Cw (window). XX
-- It uses Ca as the "first null" activation flag. XX
-- It outputs that which goes to the window to CP also. XX
-- And it also uses a fake local. XX
CP = function (d, b)
 Ct = Ct .. d
 while #Ct > 2 do
  b = Ct:byte()
  Ct = Ct:sub(2)
  if b == 127 then
   b = Ct:byte()
   Ct = Ct:sub(2)
   if b == 127 then
    b = Ct:byte() + 254
    if b > 255 then
     b = b - 256
    end
    Ct = Ct:sub(2)
   else
    b = b + 127
   end
  end
  Cp = Cp .. string.char(b)
  if #Cp == 512 then
   sector(Cp)
   Cp = ""
  end
 end
end
-- XX
CD = function (d, b, p)
 Cc = Cc .. d
 while #Cc > 2 do
  b = Cc:byte()
  if not Ca then
   Ca, b, Cc = b < 1, "", Cc:sub(2)
  elseif b < 128 then
   b, Cc = Cc:sub(1, 1), Cc:sub(2)
  else
   p = Cc:byte(2) * 256 + Cc:byte(3) + 1
   b, Cc = Cw:sub(p, p + b - 125), Cc:sub(4)
  end
  CP(b)
  Cw = (Cw .. b):sub(-65536)
 end
end
-- XX
CD(io.read("*a")) -- XX
--D.remove("init-bdivide.lua")--
--D.rename("init.lua","init-bdivide.lua")--
--local Ch=D.open("init-bdivide.lua","rb")--
--dieCB=function()D.close(Ch)D.remove("init-bdivide.lua")end--
--while true do local t=D.read(Ch, 64)if not t then break end CD(t)end--
-- XX
CD("\x00\x00")CP("\x00\x00")
