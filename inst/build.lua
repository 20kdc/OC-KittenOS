-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- KittenOS NEO Installer Generator --
local args = {...}

local cid = args[1]
local tarName = args[2]
local algorithmsInReverseOrder = {}
for i = 3, #args do
 table.insert(algorithmsInReverseOrder, 1, args[i])
end

local u = require("libs.frw")

local instSize = 0
local function put(data)
 io.write(data)
 instSize = instSize + #data
end

-- Installer Lexcrunch Context --
local lexCrunch = require("libs.lexcrunch")()

-- Installer Core --

-- installerFinalized:
--  Stuff that's already finished and put at the end of RISM. Prepend to this.
-- installerPayload / installerProgramLength:
--  The next-outer chunk that hasn't been written to the end of RISM
--   as the compression scheme (if one) has not been applied yet.
--  Really, installerProgramLength is only necessary because of the innermost chunk,
--   as that chunk has the TAR; additional data that's part of the same effective compression block,
--   but requires the program length to avoid it.
local installerPayload
local installerProgramLength
local installerFinalized = ""

do
 local tarData = u.read(tarName)
 local tarSectors = math.floor(#tarData / 512)
 local installerCore = lexCrunch.process(u.read("instcore.lua"), {["$$SECTORS"] = tostring(tarSectors)})
 installerPayload = installerCore .. tarData
 installerProgramLength = #installerCore
end

-- Installer Compression --
for _, v in ipairs(algorithmsInReverseOrder) do
 io.stderr:write("compressing (" .. v .. ")\n")
 local algImpl = require(v .. ".compress")
 local algEngine, algData = algImpl(installerPayload, lexCrunch)
 io.stderr:write("result: " .. #installerPayload .. " -> " .. #algData .. "\n")
 -- prepend the program length of the last section
 algEngine = lexCrunch.process("$iBlockingLen = " .. installerProgramLength .. " " .. algEngine, {})
 -- commit
 installerPayload = algEngine
 installerProgramLength = #installerPayload
 installerFinalized = algData .. installerFinalized
end

-- Installer Final --

-- This is a special case, so the program length/payload/etc. business has to be repeated.
put("--" .. cid .. "\n")
put("--This is released into the public domain. No warranty is provided, implied or otherwise.\n")
put(lexCrunch.process(u.read("insthead.lua"), {["$$CORESIZE"] = tostring(installerProgramLength)}))

local RISM = installerPayload .. installerFinalized
RISM = RISM:gsub("\xFE", "\xFE\xFE")
RISM = RISM:gsub("]]", "]\xFE]")
RISM = "\x00" .. RISM
put("--[[" .. RISM .. "]]")

-- Dumping debug info --
local dbg = io.open("iSymTab", "wb")
lexCrunch.dump(dbg)
dbg:close()

