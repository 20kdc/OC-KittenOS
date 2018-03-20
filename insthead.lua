-- KOSNEO inst.
-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

local C, O, G, D = component, computer
local sa = C.list("screen", true)()
if sa then
 G = C.list("gpu", true)()
 if G then
  G = C.proxy(G)
  G.bind(sa)
  G.setForeground(0xFFFFFF)
  G.setBackground(0x000000)
  G.setResolution(50, 5)
  G.setDepth(1)
  G.fill(1, 1, 50, 5, " ")
  G.setBackground(0xFFFFFF)
  G.setForeground(0x000000)
  G.fill(1, 2, 50, 1, " ")
  G.set(2, 2, "KittenOS NEO Installer")
 end
end

D = C.proxy(O.getBootAddress())

local tF = nil
local tFN = "Starting..."
local tFSR = 0
local tW = 0

local convoct
convoct = function (oct)
 local v = oct:byte(#oct) - 0x30
 if #oct > 1 then
  return (convoct(oct:sub(1, #oct - 1)) * 8) + v
 end
 return v
end
local function tA(s)
 if tW > 0 then
  tW = tW - 1
  return
 end
 if tF then
  local ta = math.min(512, tFSR)
  D.write(tF, s:sub(1, ta))
  tFSR = tFSR - ta
  if tFSR == 0 then
   D.close(tF)
   tF = nil
  end
 else
  tFN = s:sub(1, 100):gsub("\x00", "")
  local sz = convoct(s:sub(125, 135))
  if tFN:sub(1, 5) ~= "work/" then
   tW = math.ceil(sz / 512)
  else
   tFN = tFN:sub(6)
   if tFN == "" then
    return
   end
   if tFN:sub(#tFN) == "/" then
    tW = math.ceil(sz / 512)
    D.makeDirectory(tFN)
   else
    tF = D.open(tFN, "wb")
    tFSR = sz
    if tFSR == 0 then
     D.close(tF)
     tF = nil
    end
   end
  end
 end
end

local dieCB = function () end

local sN = 0
local sC = 0

local function sector(n)
 tA(n)
 sN = sN + 1
 if G then
  local a = sN / sC
  G.fill(1, 2, 50, 1, " ")
  G.set(2, 2, "KittenOS NEO Installer : " .. tFN)
  G.setForeground(0xFFFFFF)
  G.setBackground(0x000000)
  G.fill(2, 4, 48, 1, " ")
  G.setBackground(0xFFFFFF)
  G.setForeground(0x000000)
  G.fill(2, 4, math.ceil(48 * a), 1, " ")
 end
 if sN % 8 == 0 then
  O.pullSignal(0.05)
 end
 if sN == sC then
  dieCB()
  O.shutdown(true)
 end
end
