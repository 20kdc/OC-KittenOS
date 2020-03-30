-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- Installer Compression Verification Tool --
local alg, tarName = ...
local u = require("libs.frw")

io.stderr:write("verifying... ")
local p = u.progress()

local tarData = u.read(tarName)

local total = ""
function M(t)
 assert(#t == 512)
 total = total .. t
 p(#total / #tarData)
end

dofile(alg .. "/instdeco.lua")

L(u.read(alg .. "/output.bin"))

if total ~= tarData then
 io.stderr:write("\n" .. #total .. " : " .. #tarData .. "\n")
 u.write(alg .. "/vfyerr.bin", total)
 error("VERIFICATION FAILURE : see inst/" .. alg .. "/vfyerr.bin!")
end
io.stderr:write("\nverification success\n")

