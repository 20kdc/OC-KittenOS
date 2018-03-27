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
 ["mtd"] = {
  desc = "Multi-Track Drifting",
  v = 1337,
  deps = {
   "app-eeprog"
  },
  dirs = {
  },
  files = {
   "oreproc.txt"
  }
 }
}
