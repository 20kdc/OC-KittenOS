local gpu, aid, requests = ...
if #requests == 1 then
 local permits = {
  -- This is a list of specific permits for specific known apps.
  -- Do not put an app here lightly - find another way.
 }
end
if aid == "launcher" then return true, true end
local restrictions = {
--                      |                                        |
 ["root"] =            "Completely, absolutely control the device.",
 ["randr"] =           "Control displays and GPUs.", -- not precisely true but close enough
 ["stat"] =            "Read energy, sage, memory usage and time.",
 ["setlang"] =         "Change the system language.",
 ["kill"] =            "Kill other processes.",
 ["c.filesystem"] =    "Access filesystems directly (virus risk!).",
 ["c.drive"] =         "Access unmanaged drives directly.",
 ["c.modem"] =         "Send to and receive from the network.",
 ["c.tunnel"] =        "Use Linked Cards, receive from all modems.",
 ["s.modem_message"] = "Listen to all network messages.",
 ["c.internet"] =      "Connect to the real-life Internet.",
 ["c.robot"] =         "Control the 'robot' abilities.",
 ["c.drone"] =         "Control the 'drone' abilities.",
 ["c.redstone"] =      "Control Redstone Cards and I/O Blocks.",
 ["c.screen"] =        "Screw up screens directly. <USE RANDR!!!>",
 ["c.gpu"] =           "Screw up GPUs directly.    <USE RANDR!!!>",
 ["c.eeprom"] =        "Modify EEPROMs. Extremely dangerous.",
 ["c.debug"] =         "Modify the game world. Beyond dangerous.",
 ["c.printer3d"] =     "Use connected 3D Printers.",
-- disk_drive seems safe enough, same with keyboard
 ["s.key_down"] =      "Potentially act as a keylogger. (down)",
 ["s.key_up"] =        "Potentially act as a keylogger. (up)",
-- COMPUTRONICS
 ["c.chat_box"] =      "Listen and talk to players.",
 ["s.chat_message"] =  "Listen in on players talking."
}
local centre = ""
local sW, sH = gpu.getResolution()
for i = 1, math.floor((sW / 2) - 7) do
 centre = centre .. " "
end
local text = {
 centre .. "Security Alert",
 "",
 " '" .. aid .. "' would like to:",
 "",
}
local automaticOK = true
for _, v in ipairs(requests) do
 if v ~= nil then
  if type(v) == "string" then
   if restrictions[v] then
    automaticOK = false
    table.insert(text, "  + " .. restrictions[v])
   end
  end
 end
end
-- Nothing restricted.
if automaticOK then return true, true end
table.insert(text, "")
table.insert(text, " If you agree, press 'y', else 'n'.")
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)
gpu.fill(1, 1, sW, sH, " ")
for k, v in ipairs(text) do
 gpu.set(1, k, v)
end
text = nil
while true do
 local t, p1, p2, p3, p4 = computer.pullSignal()
 if t == "key_down" then
  if p2 == ("y"):byte() then
   return true, false
  end
  if p2 == ("n"):byte() then
   return false, false
  end
 end
end