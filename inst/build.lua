-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- KittenOS NEO Installer Generator --
local alg, tarName, cid = ...
cid = (cid or "UNKNOWN"):sub(1, 7)

local u = require("libs.frw")

local algImpl = require(alg .. ".compress")

local instSize = 0
local function put(data)
 io.write(data)
 instSize = instSize + #data
end

-- TAR File --
local tarData = u.read(tarName)
local tarSectors = math.floor(#tarData / 512)

-- Installer Lexcrunch Context --
local lexCrunch = require("libs.lexcrunch")()

local installerCore = lexCrunch.process(u.read("instcore.lua"), {["$$SECTORS"] = tostring(tarSectors)})
local installerHead = lexCrunch.process(u.read("insthead.lua"), {["$$CORESIZE"] = tostring(#installerCore)})
local installerTail = lexCrunch.process(u.read("insttail.lua"), {})

-- Installer Compression --
local rawData = installerCore .. tarData
io.stderr:write("compressing...\n")
local compressionEngine, compressedData = algImpl(rawData, lexCrunch)
-- RISM [[
compressedData = compressedData:gsub("\xFE", "\xFE\xFE")
compressedData = compressedData:gsub("]]", "]\xFE]")
compressedData = "\x00" .. compressedData
-- ]]
io.stderr:write("compression with " .. alg .. ": " .. #rawData .. " -> " .. #compressedData .. "\n")

-- Installer Final Generation --
put("--" .. cid .. "\n")
put("--This is released into the public domain. No warranty is provided, implied or otherwise.\n")
put(lexCrunch.process(installerHead .. compressionEngine .. installerTail, {}))
put("--[[" .. compressedData .. "]]")

-- Dumping debug info --
local dbg = io.open("iSymTab", "wb")
lexCrunch.dump(dbg)
dbg:close()

