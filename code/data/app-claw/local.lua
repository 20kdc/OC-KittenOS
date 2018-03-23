return {
 ["neo"] = {
  desc = "KittenOS NEO Kernel & Base Libs",
  v = 0,
  app = false,
  deps = {
  },
  dirs = {
   "apps",
   "libs",
   "data"
  },
  files = {
   "init.lua",
   "libs/event.lua",
   "libs/serial.lua",
   "libs/neoux.lua",
   "libs/sys-filewrap.lua"
  },
 },
 ["neo-init"] = {
  desc = "KittenOS NEO / sys-init (startup)",
  v = 0,
  app = "app-launcher",
  deps = {
   "neo",
   "neo-glacier",
   "neo-icecap",
   "neo-everest"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/sys-init.lua"
  },
 },
 ["neo-launcher"] = {
  desc = "KittenOS NEO / Default app-launcher",
  v = 0,
  app = "app-launcher",
  deps = {
   "neo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-launcher.lua"
  },
 },
 ["neo-everest"] = {
  desc = "KittenOS NEO / Everest (settings & monitor management)",
  v = 0,
  app = "sys-everest",
  deps = {
   "neo"
  },
  dirs = {
   "apps",
  },
  files = {
   "apps/sys-everest.lua"
  },
 },
 ["neo-icecap"] = {
  desc = "KittenOS NEO / Icecap",
  v = 0,
  app = "sys-icecap",
  deps = {
   "neo"
  },
  dirs = {
   "libs",
   "apps"
  },
  files = {
   "libs/sys-filevfs.lua",
   "libs/sys-filedialog.lua",
   "apps/sys-icecap.lua",
   "apps/app-fm.lua"
  },
 },
 ["neo-glacier"] = {
  desc = "KittenOS NEO / Glacier (settings & monitor management)",
  v = 0,
  app = "sys-glacier",
  deps = {
   "neo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/sys-glacier.lua"
  },
 },
 ["app-textedit"] = {
  desc = "KittenOS NEO Text Editor (Neolithic)",
  v = 0,
  app = "app-textedit",
  deps = {
   "neo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-textedit.lua"
  },
 },
 ["app-flash"] = {
  desc = "KittenOS NEO EEPROM Flasher",
  v = 0,
  app = "app-flash",
  deps = {
   "neo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-flash.lua"
  },
 },
 ["app-pass"] = {
  desc = "KittenOS NEO Password Setter & Logout",
  v = 0,
  app = "app-pass",
  deps = {
   "neo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-pass.lua"
  },
 },
 ["app-taskmgr"] = {
  desc = "KittenOS NEO Task Manager",
  v = 0,
  app = "app-taskmgr",
  deps = {
   "neo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-taskmgr.lua"
  },
 },
 ["app-claw"] = {
  desc = "KittenOS NEO Package Manager",
  v = 0,
  app = "app-claw",
  deps = {
   "neo"
  },
  dirs = {
   "apps",
   "libs"
  },
  files = {
   "apps/app-claw.lua",
   "libs/claw.lua"
  },
 }
}
