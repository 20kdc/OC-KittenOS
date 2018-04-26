-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- local.lua : CLAW Repository Metadata
-- Authors: 20kdc

return {
 ["app-eeprog"] = {
  desc = "Example program: EEPROM programmer / copier",
  v = 0,
  deps = {
   "neo",
   "zzz-license-pd"
  },
  dirs = {
   "apps",
   "docs",
   "docs/repoauthors"
  },
  files = {
   "apps/app-eeprog.lua",
   "docs/repoauthors/app-eeprog"
  },
 },
 ["neo-docs"] = {
  desc = "KittenOS NEO system documentation",
  v = 2,
  deps = {
   "zzz-license-pd"
  },
  dirs = {
   "docs",
   "docs/repoauthors"
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
   "docs/gp-pedan",
   "docs/repoauthors/neo-docs"
  },
 },
 ["app-nbox2018"] = {
  desc = "NBOX2018 and NPRT2018, a 3D-printing toolbox",
  v = 0,
  deps = {
   "neo",
   "zzz-license-pd"
  },
  dirs = {
   "apps",
   "docs",
   "docs/repoauthors"
  },
  files = {
   "apps/app-nbox2018.lua",
   "apps/app-nprt2018.lua",
   "docs/repoauthors/app-nbox2018"
  },
 },
 ["app-allmem"] = {
  desc = "Near-reproducible memory usage figures",
  v = 0,
  deps = {
   "neo",
   "zzz-license-pd"
  },
  dirs = {
   "apps",
   "docs",
   "docs/repoauthors"
  },
  files = {
   "apps/app-allmem.lua",
   "docs/repoauthors/app-allmem"
  },
 },
 ["svc-ghostie"] = {
  desc = "Application that schedules a scare after a random time to test svc autostart",
  v = 0,
  deps = {
   "neo",
   "zzz-license-pd"
  },
  dirs = {
   "apps",
   "docs",
   "docs/repoauthors"
  },
  files = {
   "apps/svc-ghostie.lua",
   "apps/app-ghostcall.lua",
   "docs/repoauthors/svc-ghostie"
  },
 },
 -- licenses (MUST BE IMMUTABLE)
 ["zzz-license-pd"] = {
  desc = "license file 'Public Domain'",
  v = 0,
  deps = {
  },
  dirs = {
   "docs",
   "docs/licensing",
   "docs/repoauthors"
  },
  files = {
   "docs/licensing/Public Domain",
   "docs/repoauthors/zzz-license-pd"
  },
 }
}
