-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- KittenOS NEO Installer Generator --
local alg, tarName = ...

local function read(fn)
 local f = io.open(fn, "rb")
 local d = f:read("*a")
 f:close()
 return d
end

local tarData = read(tarName)
local tarSectors = math.floor(#tarData / 512)

local instCode = "K=" .. tarSectors .. "\n" .. read(alg .. "/instdeco.lua") .. read("instbase.lua")
instCode = require("libs.lexcrunch")(instCode)
io.write(instCode)

-- the \x00 is the indicator to start reading
io.write("--[[\x00")
io.stderr:write("compressing...\n")
local compressedData = require(alg .. ".compress")(tarData)
io.stderr:write("compression with " .. alg .. ": " .. #tarData .. " -> " .. #compressedData .. "\n")
-- Program the read-in state machine
compressedData = compressedData:gsub("\xFE", "\xFE\xFE")
compressedData = compressedData:gsub("]]", "]\xFE]")
io.write(compressedData)
io.write("]]")

