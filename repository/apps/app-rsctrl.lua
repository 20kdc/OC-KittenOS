-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- app-rsctrl: redstone control

local event = require("event")(neo)
local neoux = require("neoux")(event, neo)
local rs = neo.requireAccess("c.redstone", "redstone control")
neo.requireAccess("s.h.redstone_changed", "updating to new input")
local running = true
local window
--123456789012345678901234567890123456789012345
--PPPPPPPP-PPPP-PPPP-PPPPPPPPPPPP     Wake=[x]
--  D=y[x] U=y[x] N=y[x] S=y[x] W=y[x] E=y[x]
local function mainGen()
 local ctrls = {}
 local prs = 0
 for pri in rs.list() do
  prs = prs + 1
  local ins = {}
  local outs = {}
  local wt = pri.getWakeThreshold()
  for i = 0, 5 do
   ins[i + 1] = pri.getInput(i)
   outs[i + 1] = pri.getOutput(i)
  end
  table.insert(ctrls, neoux.tcrawview(1, (prs * 2) - 1, {
   unicode.safeTextFormat(pri.address),
   string.format("  D=%01x    U=%01x    N=%01x    S=%01x    W=%01x    E=%01x", table.unpack(ins))
  }))
  table.insert(ctrls, neoux.tcrawview(38, (prs * 2) - 1, {
   "Wake="
  }))
  table.insert(ctrls, neoux.tcfield(43, (prs * 2) - 1, 3, function (tx)
   if tx then
    wt = math.floor(tonumber("0x" .. tx:sub(-1)) or 0)
    pri.setWakeThreshold(wt)
   end
   return string.format("%01x", wt)
  end))
  for i = 0, 5 do
   table.insert(ctrls, neoux.tcfield(6 + (i * 7), prs * 2, 3, function (tx)
    if tx then
     outs[i + 1] = tonumber("0x" .. tx:sub(-1)) or 0
     pri.setOutput(i, outs[i + 1])
    end
    return string.format("%01x", outs[i + 1])
   end))
  end
 end
 return 45, prs * 2, nil, neoux.tcwindow(45, prs * 2, ctrls, function ()
  window.close()
  running = false
 end, 0xFFFFFF, 0)
end
window = neoux.create(mainGen())
while running do
 local hv = event.pull()
 if hv == "redstone_changed" then
  window.reset(mainGen())
 end
end
