-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- event: Implements pull/listen semantics in a consistent way for a given process.
-- This is similar in API to OpenOS's event framework, but is per-process.
-- To make this work, a function is shared.
-- This function needs access to the caller's NEO in order to ensure that NEO system functions are covered.
-- This can do less checks than usual as it only affects the caller.

-- Global forces reference to prevent duplication
newEvent = function (neo)
 local listeners = {}
 local translations = {}
 local timers = {}
 local oldRA = neo.requestAccess
 local function doPush(tp, tag, ...)
  if tp == "k.timer" then
   local f = timers[tag]
   timers[tag] = nil
   if f then
    f(...)
   end
  end
  local listeners2 = {}
  for k, _ in pairs(listeners) do
   table.insert(listeners2, k)
  end
  for _, v in ipairs(listeners2) do
   v(tp, tag, ...)
  end
 end
 neo.requestAccess = function (perm, handler)
  return oldRA(perm, function (...)
   doPush(...)
   if handler then
    handler(...)
   end
  end)
 end
 local function doPull()
  local ev = {coroutine.yield()}
  doPush(table.unpack(ev))
  return ev
 end
 return {
  listen = function (p1, p2)
   if type(p2) == "function" then
    local t = function (...)
     local evn = ...
     if evn == p1 then
      p2(...)
     end
    end
    translations[p2] = t
    listeners[t] = true
   else
    listeners[p1] = true
   end
  end,
  ignore = function (func)
   if translations[func] then
    listeners[translations[func]] = nil
    translations[func] = nil
   end
   listeners[func] = nil
  end,
  -- Arguments are filtering.
  -- For example, to filter for timers with a given tag, use pull("k.timer", tag)
  -- Note the explicit discouragement of timeout-pulls. Use runAt or the complex form of sleep.
  pull = function (...)
   local filter = {...}
   while true do
    local ev = doPull()
    local err = false
    for i = 1, #filter do
     err = err or (filter[i] ~= ev[i])
    end
    if not err then return table.unpack(ev) end
   end
  end,
  -- Run a function at a specified uptime.
  runAt = function (time, func)
   timers[neo.scheduleTimer(time)] = func
  end,
  -- Sleeps until a time (unless time is nil, in which case sleeps forever), but can be woken up before then.
  -- This allows using an async API as a synchronous one with optional time-to-failure.
  sleepTo = function (time, wakeUpPoll)
   local timerHit = false
   local oWUP = wakeUpPoll
   wakeUpPoll = function ()
    if oWUP then
     return timerHit or (oWUP())
    end
    return timerHit
   end
   if time then
    timers[neo.scheduleTimer(time)] = function () timerHit = true end
   end
   while true do
    local ev = doPull()
    if wakeUpPoll() then return end
   end
  end
 }
end
return newEvent
