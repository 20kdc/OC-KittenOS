-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

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
  v = 9,
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
   "docs/us-clawf",
   "docs/us-termi",
   "docs/ul-seria",
   "docs/ul-fwrap",
   "docs/ul-event",
   "docs/ul-fmttx",
   "docs/ul-neoux",
   "docs/ul-brail",
   "docs/ul-bmp__",
   "docs/ul-linee",
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
 ["app-telnet"] = {
  desc = "TELNET client",
  v = 0,
  deps = {
   "neo",
   "svc-t",
   "zzz-license-pd"
  },
  dirs = {
   "apps",
   "docs",
   "docs/repoauthors"
  },
  files = {
   "apps/app-telnet.lua",
   "docs/repoauthors/app-telnet"
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
 ["app-metamachine"] = {
  desc = "Virtual machine",
  v = 4,
  deps = {
   "neo",
   "zzz-license-pd"
  },
  dirs = {
   "apps",
   "libs",
   "docs",
   "docs/repoauthors",
   "data",
   "data/app-metamachine"
  },
  files = {
   "apps/app-metamachine.lua",
   "libs/metamachine-vgpu.lua",
   "libs/metamachine-vfs.lua",
   "docs/repoauthors/app-metamachine",
   "data/app-metamachine/confboot.lua",
   "data/app-metamachine/lucaboot.lua"
  },
 },
 ["app-pclogix-upload"] = {
  desc = "paste.pc-logix.com text uploader",
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
   "apps/app-pclogix-upload.lua",
   "docs/repoauthors/app-pclogix-upload"
  },
 },
 ["app-rsctrl"] = {
  desc = "Redstone control",
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
   "apps/app-rsctrl.lua",
   "docs/repoauthors/app-rsctrl"
  },
 },
 ["app-nbcompose"] = {
  desc = "Music player/composer using the NBS format",
  v = 1,
  deps = {
   "neo",
   "lib-knbs",
   "zzz-license-pd"
  },
  dirs = {
   "apps",
   "docs",
   "docs/repoauthors"
  },
  files = {
   "apps/app-nbcompose.lua",
   "docs/repoauthors/app-nbcompose"
  },
 },
 ["app-tapedeck"] = {
  desc = "Computronics Tape Drive interface",
  v = 2,
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
   "apps/app-tapedeck.lua",
   "docs/repoauthors/app-tapedeck"
  },
 },
 ["app-launchbar"] = {
  desc = "Application launcher bar",
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
   "apps/app-launchbar.lua",
   "docs/repoauthors/app-launchbar"
  },
 },
 ["app-slaunch"] = {
  desc = "Searching launcher",
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
   "apps/app-slaunch.lua",
   "docs/repoauthors/app-slaunch"
  },
 },
 -- libraries
 ["lib-knbs"] = {
  desc = "NBS reader/writer library",
  v = 1,
  deps = {
   "zzz-license-pd"
  },
  dirs = {
   "libs",
   "docs",
   "docs/repoauthors"
  },
  files = {
   "libs/knbs.lua",
   "docs/repoauthors/lib-knbs"
  },
 },
 ["svc-virtudev"] = {
  desc = "a clone of vcomponent",
  v = 1,
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
   "apps/svc-virtudev.lua",
   "apps/app-vdrslamp.lua",
   "docs/us-virtu",
   "docs/repoauthors/svc-virtudev"
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
 },
 ["zzz-license-kosneo-bsd0"] = {
  desc = "license file 'KittenOS NEO BSD0'",
  v = 0,
  deps = {
  },
  dirs = {
   "docs",
   "docs/licensing",
   "docs/repoauthors"
  },
  files = {
   "docs/licensing/KittenOS NEO BSD0",
   "docs/repoauthors/zzz-license-kosneo-bsd0"
  },
 }
}
