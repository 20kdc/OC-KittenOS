-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- KittenOS NEO Installer Generator --
local alg, tarName, cid = ...
cid = (cid or "UNKNOWN"):sub(1, 7)

local u = require("libs.frw")

local tarData = u.read(tarName)
local tarSectors = math.floor(#tarData / 512)

local instSize = 0
local function put(data)
 io.write(data)
 instSize = instSize + #data
end

put("--" .. cid .. "\n")
put("--This is released into the public domain. No warranty is provided, implied or otherwise.\n")

local instCode = "K=" .. tarSectors .. "\n" .. u.read(alg .. "/instdeco.lua") .. u.read("instbase.lua")
instCode = require("libs.lexcrunch")(instCode)
put(instCode)

-- the \x00 is the indicator to start reading
put("--[[\x00")

io.stderr:write("compressing...\n")
local compressedData = require(alg .. ".compress")(tarData)
u.write(alg .. "/output.bin", compressedData)
io.stderr:write("compression with " .. alg .. ": " .. #tarData .. " -> " .. #compressedData .. "\n")
-- Program the read-in state machine
compressedData = compressedData:gsub("\xFE", "\xFE\xFE")
compressedData = compressedData:gsub("]]", "]\xFE]")

put(compressedData)
put("]]")

local status = ""
local statusDetail = ""
local blinkI = ""
if instSize > 65536 then
 blinkI = "5;31;"
 status = " DO NOT SHIP "
 statusDetail = "The installer is too big to ship safely.\nIt's possible it may crash on Tier 1 systems.\nUpgrade the compression system or remove existing code."
elseif instSize > 64000 then
 blinkI = "33;"
 status = " Shippable * "
 statusDetail = "The installer is getting dangerously large.\nReserve further room for bugfixes."
else
 blinkI = "32;"
 status = "  All Green  "
 statusDetail = "The installer is well within budget with room for features.\nDevelop as normal."
end
io.stderr:write("\n")
local ctS, ctM, ctE = " \x1b[1;" .. blinkI .. "7m", "\x1b[0;7m", "\x1b[0m\n"
io.stderr:write(ctS .. "             " .. ctM .. "         " .. ctE)
io.stderr:write(ctS .. status          .. ctM .. string.format(" %07i ", 65536 - instSize) .. ctE)
io.stderr:write(ctS .. "             " .. ctM .. "         " .. ctE)
io.stderr:write("\n")
io.stderr:write(statusDetail .. "\n")
io.stderr:write("\n")
io.stderr:write("Size:  " .. instSize .. "\n")
io.stderr:write(" max.  65536\n")
io.stderr:write("\n")

