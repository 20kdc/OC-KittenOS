local sector = io.write -- XX
-- BUNDIVIDE reference implementation for integration XX
local Cs,Cbu,Cb,Cw,Cp,Ci,CP,CB,CD={},128,"",128,""
CP=function(d,b,i)
 i=1
 while i<=#d do
  b=d:byte(i)
  i=i+1
  if b==127 then
   b=d:byte(i)
   i=i+1
   if b==127 then
    b=d:byte(i)+254
    i=i+1
   else
    b=b+127
   end
  end
  Cp=Cp..string.char(b)
  if #Cp==512 then
   sector(Cp)
   Cp=""
  end
 end
end
for i=128,127+Cbu do Cs[i]=("\x00"):rep(512) end
Cs[Cw]=""
CB=function(d,i,d2,x,y)
 i=1
 while i<=#d-2 do
  b=d:byte(i)
  d2=d:sub(i,i)
  i=i+1
  if not Ci then
   if b==0then
    Ci=1
   end
  else
   if b>=128then
    x=d:byte(i)i=i+1
    y=(d:byte(i)+((x%2)*256))i=i+1
    d2=Cs[b]:sub(y+1,y+3+math.floor(x/2))
   end
   Cs[Cw]=Cs[Cw]..d2
   if #Cs[Cw]>=512then
    CP(Cs[Cw])
    Cw=((Cw-127)%Cbu)+128
    Cs[Cw]=""
   end
  end
 end
 return i
end
CD=function(d)
 Cb=Cb..d
 Cb=Cb:sub(CB(Cb))
end
CD(io.read("*a")) -- XX
--D.remove("init-bdivide.lua")--
--D.rename("init.lua","init-bdivide.lua")--
--local Ch=D.open("init-bdivide.lua","rb")--
--dieCB=function()D.close(Ch)D.remove("init-bdivide.lua")end--
--while true do local t=D.read(Ch, 64)if not t then break end CD(t)end--
CD("\x00\x00")CP(Cs[Cw])
