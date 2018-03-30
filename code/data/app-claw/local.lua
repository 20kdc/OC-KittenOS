return {
 ["neo"] = {
  desc = "KittenOS NEO Kernel & Base Libs",
  v = 1,
  deps = {
  },
  dirs = {
   "apps",
   "libs",
   "data"
  },
  files = {
   "init.lua",
   "apps/sys-glacier.lua",
   "libs/event.lua",
   "libs/serial.lua",
   "libs/fmttext.lua",
   "libs/neoux.lua",
   "libs/braille.lua",
   "libs/sys-filewrap.lua"
  },
 },
 ["neo-init"] = {
  desc = "KittenOS NEO / sys-init (startup)",
  v = 0,
  deps = {
   "neo",
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
  desc = "KittenOS NEO / Everest (windowing)",
  v = 0,
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
  v = 1,
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
 ["neo-secpolicy"] = {
  desc = "KittenOS NEO / Secpolicy",
  v = 1,
  deps = {
  },
  dirs = {
   "libs"
  },
  files = {
   "libs/sys-secpolicy.lua"
  }
 },
 ["neo-coreapps"] = {
  desc = "KittenOS NEO Core Apps",
  v = 2,
  deps = {
   "neo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-textedit.lua",
   "apps/app-control.lua",
   "apps/app-taskmgr.lua"
  }
 },
 ["app-klogo"] = {
  desc = "KittenOS NEO Logo",
  v = 0,
  deps = {
   "neo"
  },
  dirs = {
   "apps",
   "data",
   "data/app-klogo"
  },
  files = {
   "apps/app-klogo.lua",
   "data/app-klogo/logo.data"
  },
 },
 ["app-flash"] = {
  desc = "KittenOS NEO EEPROM Flasher",
  v = 0,
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
 ["app-claw"] = {
  desc = "KittenOS NEO Package Manager",
  v = 1,
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
 },
 ["neo-meta"] = {
  desc = "KittenOS NEO: Use 'All' to install to other disks",
  v = 0,
  deps = {
   "neo",
   "neo-init",
   "neo-launcher",
   "neo-everest",
   "neo-icecap",
   "neo-secpolicy",
   "neo-coreapps",
   "app-klogo",
   "app-flash",
   "app-claw"
  },
  dirs = {
  },
  files = {
  }
 }
}
