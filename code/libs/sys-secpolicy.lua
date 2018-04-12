-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- CRITICAL FILE!
-- This file defines how your KittenOS NEO system responds to access requests.
-- Modification, renaming or deletion can disable security features.
-- Usually, a change that breaks the ability for the file to do it's job will cause the "failsafe" to activate,
--  and for the system to become unable to run user applications.
-- However - I would not like to test this in a situation where said user applications were in any way untrusted,
--  for example, if you downloaded them from the Internet, or in particular if someone forwarded them over Discord.
-- IRC is usually pretty safe, but no guarantees.

-- Returns "allow", "deny", or "ask".
local function actualPolicy(pkg, pid, perm, matchesSvc)
 -- System stuff is allowed.
 if pkg:sub(1, 4) == "sys-" then
  return "allow"
 end
 -- <The following is for apps & services>
 -- x.neo.pub (aka Icecap) is open to all
 if perm:sub(1, 10) == "x.neo.pub." then
  return "allow"
 end
 -- These signals are harmless, though they identify HW (as does everything in OC...)
 if perm == "s.h.component_added" or perm == "s.h.component_removed" then
  return "allow"
 end
 if matchesSvc("r.", pkg, perm) then
  return "allow"
 end
 -- Userlevel has no other registration rights
 if perm:sub(1, 2) == "r." then
  return "deny"
 end
 -- app/svc stuff is world-accessible,
 -- but note perm|*| overrides this
 if perm:sub(1, 6) == "x.app." then
  return "allow"
 end
 if perm:sub(1, 6) == "x.svc." then
  return "allow"
 end
 -- For hardware access, ASK!
 return "ask"
end

return function (nexus, settings, pkg, pid, perm, rsp, matchesSvc)
 local res = "ask"
 if settings then
  res = settings.getSetting("perm|" .. pkg .. "|" .. perm) or
        settings.getSetting("perm|*|" .. perm) or "ask"
 end
 if res == "ask" then
  res = actualPolicy(pkg, pid, perm, matchesSvc)
 end
 if res == "ask" and nexus then
  local totalW = 3 + 6 + 2 + 8
  local fmt = require("fmttext").fmtText(unicode.safeTextFormat(string.format("%s/%i wants:\n%s\nAllow this?\n\n", pkg, pid, perm)), totalW)
  local buttons = {
   {"<No>", function (w)
    rsp(false)
    nexus.close(w)
   end},
   {"<Always>", function (w)
    if settings then
     settings.setSetting("perm|" .. pkg .. "|" .. perm, "allow")
    end
    rsp(true)
    nexus.close(w)
   end},
   {"<Yes>", function (w)
    rsp(true)
    nexus.close(w)
   end}
  }
  nexus.createNexusThread(function ()
   local window = nexus.create(totalW, #fmt, "security")
   local cButton = 0
   local ev, a, b, c
   while true do
    if not ev then
     ev, a, b, c = coroutine.yield()
    end
    if ev == "line" or ev == "touch" then
     local cor = b
     if ev == "line" then
      cor = a
      if fmt[a] then
       window.span(1, a, fmt[a], 0xFFFFFF, 0)
      end
     end
     if cor == #fmt then
      local x = 1
      for k, v in ipairs(buttons) do
       if ev == "line" then
        if k ~= cButton + 1 then
         window.span(x, a, v[1], 0xFFFFFF, 0)
        else
         window.span(x, a, v[1], 0, 0xFFFFFF)
        end
       elseif a >= x and a < (x + #v[1]) then
        cButton = k - 1
        ev = "key"
        a = 32
        b = 0
        c = true
        break
       end
       x = x + #v[1] + 1
      end
     end
    elseif ev == "close" then
     rsp(false)
     nexus.close(window)
     return
    end
    if ev == "key" then
     if c and (a == 9 or b == 205) then
      cButton = (cButton + 1) % #buttons
      ev = "line"
      a = #fmt
     elseif c and b == 203 then
      cButton = (cButton - 1) % #buttons
      ev = "line"
      a = #fmt
     elseif c and (a == 13 or a == 32) then
      buttons[cButton + 1][2](window)
      ev = nil
     else
      ev = nil
     end
    else
     ev = nil
    end
   end
  end)
 else
  rsp(res == "allow")
 end
end

