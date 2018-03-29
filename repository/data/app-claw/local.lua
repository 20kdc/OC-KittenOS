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
 }
}
