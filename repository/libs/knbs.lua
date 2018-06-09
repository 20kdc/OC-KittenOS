-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- knbs.lua : Partial .nbs (Note Block Studio) R/W library
-- Does not support custom instruments!
-- Authors: 20kdc

local function dsu16(str)
 return
  str:byte(1) +
  (str:byte(2) * 256),
  str:sub(3)
end
local function dsu32(str)
 local a, str = dsu16(str)
 local b, str = dsu16(str)
 return a + (b * 0x10000), str
end
local function dsstr(str)
 local a, str = dsu32(str)
 return str:sub(1, a), str:sub(a + 1)
end
local function su16(i, wr)
 wr(string.char(i % 0x100, math.floor(i / 0x100)))
end
local function su32(i, wr)
 su16(i % 0x10000, wr)
 su16(math.floor(i / 0x10000), wr)
end
local function sstr(str, wr)
 su32(#str, wr)
 wr(str)
end

return {
 new = function ()
  return {
   length = 1,
   height = 1,
   name = "New Song",
   transcriptor = "Mr.Anderson",
   songwriter = "Morpheus",
   description = "A blank song.",
   tempo = 200,
   autosave = 0,
   autosaveMin = 60,
   timeSignature = 4,
   usageMin = 0, usageLeft = 0, usageRight = 0, usageAdd = 0, usageRm = 0,
   importName = "",
   ci = "",
   ticks = {
    [0] = {
     [0] = {0, 33}
    }
   },
   layers = {
    [0] = {"L0", 100}
   }
  }
 end,
 deserialize = function (str)
  local nbs = {}
  nbs.length, str = dsu16(str)
  nbs.length = nbs.length + 1 -- hmph!
  nbs.height, str = dsu16(str)
  nbs.name, str = dsstr(str)
  nbs.transcriptor, str = dsstr(str)
  nbs.songwriter, str = dsstr(str)
  nbs.description, str = dsstr(str)
  nbs.tempo, str = dsu16(str)
  nbs.autosave, str = str:byte(), str:sub(2)
  nbs.autosaveMin, str = str:byte(), str:sub(2)
  nbs.timeSignature, str = str:byte(), str:sub(2)
  nbs.usageMin, str = dsu32(str)
  nbs.usageLeft, str = dsu32(str)
  nbs.usageRight, str = dsu32(str)
  nbs.usageAdd, str = dsu32(str)
  nbs.usageRm, str = dsu32(str)
  nbs.importName, str = dsstr(str)
  -- ticks[tick][layer] = key
  nbs.ticks = {}
  local tick = -1
  while true do
   local ntJ
   ntJ, str = dsu16(str)
   if ntJ == 0 then break end
   tick = tick + ntJ
   local tickData = {}
   nbs.ticks[tick] = tickData
   local layer = -1
   while true do
    local lJ
    lJ, str = dsu16(str)
    if lJ == 0 then break end
    layer = layer + lJ
    local ins = str:byte(1)
    local key = str:byte(2)
    str = str:sub(3)
    local layerData = {ins, key}
    if layer < nbs.height then
     tickData[layer] = layerData
     -- else: drop the invalid note
    end
   end
  end
  -- nbs.layers[layer] = {name, volume}
  nbs.layers = {}
  if str ~= "" then
   for i = 0, nbs.height - 1 do
    nbs.layers[i] = {}
    nbs.layers[i][1], str = dsstr(str)
    nbs.layers[i][2], str = str:byte(), str:sub(2)
   end
  else
   for i = 0, nbs.height - 1 do
    nbs.layers[i] = {"L" .. i, 100}
   end
  end
  nbs.ci = str
  return nbs
 end,
 resizeLayers = function (nbs, layers)
  -- make all layers after target layer go away
  for i = layers, nbs.height - 1 do
   nbs.layers[i] = nil
  end
  -- add layers up to target
  for i = nbs.height, layers - 1 do
   nbs.layers[i] = {"L" .. i, 100}
  end
  -- clean up song
  for k, v in pairs(nbs.ticks) do
   for lk, lv in pairs(v) do
    if lk >= layers then
     v[lk] = nil
    end
   end
  end
  nbs.height = layers
 end,
 -- Corrects length, height (should not be necessary in correct applications!), and clears out unused tick columns.
 -- Returns the actual effective height, which can be passed to resizeLayers to remove dead weight.
 correctSongLH = function (nbs)
  nbs.length = 1
  nbs.height = 0
  for k, v in pairs(nbs.layers) do
   nbs.height = math.max(nbs.height, k + 1)
  end
  local eH = 0
  for k, v in pairs(nbs.ticks) do
   local ok = false
   for lk, lv in pairs(v) do
    ok = true
    eH = math.max(eH, lk + 1)
   end
   if not ok then
    nbs.ticks[k] = nil
   else
    nbs.length = math.max(nbs.length, k + 1)
   end
  end
  return eH
 end,
 serialize = function (nbs, wr)
  su16(math.max(0, nbs.length - 1), wr)
  su16(nbs.height, wr)
  sstr(nbs.name, wr)
  sstr(nbs.transcriptor, wr)
  sstr(nbs.songwriter, wr)
  sstr(nbs.description, wr)
  su16(nbs.tempo, wr)
  wr(string.char(nbs.autosave, nbs.autosaveMin, nbs.timeSignature))
  su32(nbs.usageMin, wr)
  su32(nbs.usageLeft, wr)
  su32(nbs.usageRight, wr)
  su32(nbs.usageAdd, wr)
  su32(nbs.usageRm, wr)
  sstr(nbs.importName, wr)
  local ptr = -1
  for i = 0, nbs.length - 1 do
   if nbs.ticks[i] then
    su16(i - ptr, wr)
    ptr = i
    local lp = -1
    for j = 0, nbs.height - 1 do
     local id = nbs.ticks[i][j]
     if id then
      su16(j - lp, wr)
      lp = j
      wr(string.char(id[1], id[2]))
     end
    end
    su16(0, wr)
   end
  end
  su16(0, wr)
  for i = 0, nbs.height - 1 do
   sstr(nbs.layers[i][1], wr)
   wr(string.char(nbs.layers[i][2]))
  end
  wr(nbs.ci)
 end
}
