-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- local.lua : CLAW Repository Metadata
-- Authors: 20kdc

return {
 ["app-eeprog"] = {
  desc = "EEPROM programmer / copier",
  v = 0,
  deps = {
   "neo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-eeprog.lua"
  },
 },
 ["neo-docs"] = {
  desc = "KittenOS NEO system documentation",
  v = 2,
  deps = {
  },
  dirs = {
   "docs"
  },
  files = {
   "docs/an-intro",
   "docs/kn-intro",
   "docs/kn-refer",
   "docs/kn-sched",
   "docs/kn-perms",
   "docs/us-perms",
   "docs/ul-seria",
   "docs/ul-event",
   "docs/ul-neoux",
   "docs/ul-broil",
   "docs/gp-pedan"
  },
 }
}
