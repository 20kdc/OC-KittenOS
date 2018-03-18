-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-taskmgr: Task manager
-- a-hello : simple test program for Everest.

local everest = neo.requestAccess("x.neo.pub.window")
if not everest then error("no everest") return end

local kill = neo.requestAccess("k.kill")

local sW, sH = 20, 8
local headlines = 2

local window = everest(sW, sH)
if not window then error("no window") end

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
   if n[6] then
    if n[4] == 8 then
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
