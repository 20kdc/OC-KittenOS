-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- Status Screen --
local target = ...
local u = require("libs.frw")
local instSize = #u.read(target)

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

