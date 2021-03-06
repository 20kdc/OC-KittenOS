-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- app-taskmgr: Task manager
-- a-hello : simple test program for Everest.

local everest = neo.requireAccess("x.neo.pub.window", "main window")

local kill = neo.requestAccess("k.kill")

local sW, sH = 20, 8
local headlines = 2

local window = everest(sW, sH)

local lastIdleTimeTime = os.uptime()
local lastIdleTime = neo.totalIdleTime()
local cpuPercent = 100

local lastCPUTimeRecord = {}
local cpuCause = "(none)"

local camY = 1
-- elements have {pid, text}
local consistentProcList = {}

local function drawLine(n)
 local red = false
 local idx = (camY + n) - (headlines + 1)
 local stat = ("~"):rep(sW)
 if n == 1 then
  -- x.everest redraw. Since this window only has one line...
  local usage = math.floor((os.totalMemory() - os.freeMemory()) / 1024)
  stat = usage .. "/" .. math.floor(os.totalMemory() / 1024) .. "K, CPU " .. cpuPercent .. "%"
  red = true
 elseif n == 2 then
  stat = "MAX:" .. cpuCause
  red = true
 elseif consistentProcList[idx] then
  if idx == camY then
   stat = ">" .. consistentProcList[idx][2]
  else
   stat = " " .. consistentProcList[idx][2]
  end
 end
 stat = unicode.safeTextFormat(stat)
 while unicode.len(stat) < sW do stat = stat .. " " end
 if red then
  window.span(1, n, unicode.sub(stat, 1, sW), 0xFFFFFF, 0)
 else
  window.span(1, n, unicode.sub(stat, 1, sW), 0x000000, 0xFFFFFF)
 end
end
local function updateConsistentProcList(pt, lp)
 local tbl = {}
 local tbl2 = {}
 local tbl3 = {}
 for _, v in ipairs(pt) do
  table.insert(tbl, v[1])
  tbl2[v[1]] = v[2] .. "/" .. v[1] .. " " .. tostring(lp[v[1]]) .. "%"
 end
 table.sort(tbl)
 for k, v in ipairs(tbl) do
  tbl3[k] = {v, tbl2[v]}
 end
 consistentProcList = tbl3
end
local p = os.uptime()
neo.scheduleTimer(p)
local ctrl = false
while true do
 local n = {coroutine.yield()}
 if n[1] == "x.neo.pub.window" then
  if n[3] == "line" then
   drawLine(n[4])
  end
  if n[3] == "close" then
   return
  end
  if n[3] == "key" then
   if n[5] == 29 then
    ctrl = n[6]
   elseif n[6] then
    if ctrl then
     if n[5] == 200 then
      sH = math.max(headlines + 1, sH - 1)
      window.setSize(sW, sH)
     elseif n[5] == 208 then
      sH = sH + 1
      window.setSize(sW, sH)
     elseif n[5] == 203 then
      sW = math.max(20, sW - 1)
      window.setSize(sW, sH)
     elseif n[5] == 205 then
      sW = sW + 1
      window.setSize(sW, sH)
     end
    else
     if n[4] == 8 or n[5] == 211 then
      if consistentProcList[camY] then
       kill(consistentProcList[camY][1])
      end
     end
     if n[5] == 200 then
      camY = camY - 1
      if camY < 1 then camY = 1 end
      for i = (headlines + 1), sH do drawLine(i) end
     end
     if n[5] == 208 then
      camY = camY + 1
      for i = (headlines + 1), sH do drawLine(i) end
     end
    end
   end
  end
 end
 if n[1] == "k.timer" then
  local now = os.uptime()
  local nowIT = neo.totalIdleTime()
  local tD = now - lastIdleTimeTime
  local iD = nowIT - lastIdleTime
  cpuPercent = math.ceil(((tD - iD) / tD) * 100)
  lastIdleTimeTime = now
  lastIdleTime = nowIT

  local newRecord = {}
  cpuCause = "(none)"
  local causeUsage = 0
  local pt = neo.listProcs()
  local localPercent = {}
  for _, v in ipairs(pt) do
   -- pkg, pid, cpuTime
   local baseline = 0
   if lastCPUTimeRecord[v[1]] then
    baseline = lastCPUTimeRecord[v[1]]
   end
   local val = v[3] - baseline
   localPercent[v[1]] = math.ceil(100 * (val / tD))
   if causeUsage < val then
    cpuCause = v[2] .. "/" .. v[1]
    causeUsage = val
   end
   newRecord[v[1]] = v[3]
  end
  lastCPUTimeRecord = newRecord
  updateConsistentProcList(pt, localPercent)
  for i = 1, sH do drawLine(i) end
  p = p + 1
  neo.scheduleTimer(p)
 end
end
