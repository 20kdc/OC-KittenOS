-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- local.lua : CLAW Repository Metadata
-- Authors: 20kdc

return {
 ["licensing"] = {
  desc = "Legal compliance package, dependency of everything in the repository",
  v = 0,
  deps = {
  },
  dirs = {
   "docs",
   "docs/licensing"
  },
  files = {
   "docs/repo-authors",
   "docs/licensing/Public Domain"
  },
 },
 ["app-eeprog"] = {
  desc = "Example program: EEPROM programmer / copier",
  v = 0,
  deps = {
   "neo",
   "licensing"
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
   "licensing"
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
   "docs/us-nxapp",
   "docs/us-setti",
   "docs/us-evrst",
   "docs/ul-seria",
   "docs/ul-fwrap",
   "docs/ul-event",
   "docs/ul-fmttx",
   "docs/ul-neoux",
   "docs/ul-brail",
   "docs/ul-bmp__",
   "docs/gp-pedan"
  },
 },
 ["app-nbox2018"] = {
  desc = "NBOX2018 and NPRT2018, a 3D-printing toolbox",
  v = 0,
  deps = {
   "neo",
   "licensing"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-nbox2018.lua",
   "apps/app-nprt2018.lua"
  },
 },
 ["svc-ghostie"] = {
  desc = "Application that schedules a scare after a random time to test svc autostart",
  v = 0,
  deps = {
   "neo",
   "licensing"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/svc-ghostie.lua",
   "apps/app-ghostcall.lua"
  },
 }
}
