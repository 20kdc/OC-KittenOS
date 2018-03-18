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
local actualPolicy = function (pkg, pid, perm)
 -- System stuff is allowed.
 if pkg:sub(1, 4) == "sys-" then
  return "allow"
 end
 -- <The following is for apps & services>
 -- x.neo.pub (aka Icecap) is open to all
 if perm:sub(1, 10) == "x.neo.pub." then
  return "allow"
 end
 -- This is to ensure the prefix naming scheme is FOLLOWED!
 -- sys- : System, part of KittenOS NEO and thus tries to present a "unified fragmented interface" in 'neo'
 -- app- : Application - these can have ad-hoc relationships. It is EXPECTED these have a GUI
 -- svc- : Service - Same as Application but with no expectation of desktop usability
 -- Libraries "have no rights" as they are essentially loadable blobs of Lua code.
 -- They have access via the calling program, and have a subset of the NEO Kernel API
 local pfx = nil
 if pkg:sub(1, 4) == "app-" then pfx = "app" end
 if pkg:sub(1, 4) == "svc-" then pfx = "svc" end
 if pfx then
  -- Apps can register with their own name
  if perm == "r." .. pfx .. "." .. pkg:sub(5) then
   return "allow"
  end
 end
 -- Userlevel has no other registration rights
 if perm:sub(1, 2) == "r." then
  return "deny"
 end
 -- app/svc stuff is world-accessible
 if perm:sub(1, 6) == "x.app." then
  return "allow"
 end
 if perm:sub(1, 6) == "x.svc." then
  return "allow"
 end
 -- For hardware access, ASK!
 return "ask"
end

return function (neoux, settings, pkg, pid, perm, rsp)
 local res = actualPolicy(pkg, pid, perm)
 if res == "ask" then
  res = settings.getSetting("perm|" .. pkg .. "|" .. perm) or "ask"
 end
 if res == "ask" then
  local fmt = neoux.fmtText(unicode.safeTextFormat(string.format("%s/%i wants:\n%s\nAllow this?", pkg, pid, perm)), 20)

  local always = "Always"
  local yes = "Yes"
  local no = "No"
  local totalW = (#yes) + (#always) + (#no) + 8
  neoux.create(20, #fmt + 2, "security", neoux.tcwindow(20, #fmt + 3, {
   neoux.tcbutton(1, #fmt + 2, no, function (w)
    rsp(false)
    w.close()
   end),
   neoux.tcbutton(totalW - ((#yes) + 1), #fmt + 2, yes, function (w)
    rsp(true)
    w.close()
   end),
   neoux.tcbutton((#yes) + 3, #fmt + 2, always, function (w)
    settings.setSetting("perm|" .. pkg .. "|" .. perm, "allow")
    rsp(true)
    w.close()
   end),
   neoux.tchdivider(1, #fmt + 1, 21),
   neoux.tcrawview(1, 1, fmt),
  }, function (w)
   rsp(false)
   w.close()
  end, 0xFFFFFF, 0))
 else
  rsp(res == "allow")
 end
end

