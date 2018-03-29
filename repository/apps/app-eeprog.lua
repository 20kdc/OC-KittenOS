-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-eeprog.lua : Tiny EEPROM flasher
-- Authors: 20kdc

-- Example of a tiny app a user could write relatively quickly if they have NEO system knowledge
-- Note the high amount of synchronous routines used here.
-- For a tiny app like this, it's fine, and KittenOS NEO makes sure it won't interfere.
-- (Plus, this isn't a library, so that's not a concern)
-- Really, in KittenOS NEO, the only program you break is your own

local event = require("event")(neo)
local neoux = require("neoux")(event, neo)

local eeprom = neo.requireAccess("c.eeprom", "EEPROM access")
eeprom = eeprom.list()()

neoux.startDialog("NOTE: If this program is used improperly, it can require EEPROM replacement.\nOnly use trusted EEPROMs.", "eeprom-flash", true)

local fd = neoux.fileDialog(false)
if not fd then return end
local eepromCode = fd.read("*a")
fd.close()
eeprom.set(eepromCode)

neoux.startDialog("The flash was successful - the next dialog can change the label.", "eeprom-flash", true)

-- text dialog
local done = false
neoux.create(20, 1, "label", neoux.tcwindow(20, 1, {
 neoux.tcfield(1, 1, 20, function (nv)
  if not nv then
   return eeprom.getLabel()
  end
  eeprom.setLabel(nv)
 end)
}, function (w)
 w.close()
 done = true
end, 0xFFFFFF, 0))

while not done do
 event.pull()
end
