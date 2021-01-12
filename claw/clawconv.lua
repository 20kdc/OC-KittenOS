-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- CLAW local.lua converter. Expects to be run from outermost folder.

local target = ...

local serial = loadfile("code/libs/serial.lua")()

for k, v in pairs(serial.deserialize(io.read("*a"))) do
 print(k .. "." .. v.v .. ".c2p")
 print(k .. ".c2x")
 local f2 = io.open(target .. k .. "." .. v.v .. ".c2p", "wb")
 f2:write(k .. "\n")
 f2:write(v.desc .. "\n")
 f2:write("v" .. v.v .. " deps " .. table.concat(v.deps, ", "))
 f2:close()
 f2 = io.open(target .. k .. ".c2x", "wb")
 for _, vx in ipairs(v.deps) do
  f2:write("?" .. vx .. "\n")
 end
 for _, vx in ipairs(v.dirs) do
  f2:write("/" .. vx .. "\n")
 end
 for _, vx in ipairs(v.files) do
  f2:write("+" .. vx .. "\n")
 end
 f2:write("/data\n")
 f2:write("/data/app-claw\n")
 f2:write("+data/app-claw/" .. k .. ".c2x\n")
 f2:write("+data/app-claw/" .. k .. "." .. v.v .. ".c2p\n")
 f2:close()
end

