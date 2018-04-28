-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.
return {
 ["neo"] = {
  desc = "KittenOS NEO Kernel & Base Libs",
  v = 2,
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
   "libs/bmp.lua",
   "libs/sys-filewrap.lua",
   "libs/sys-gpualloc.lua"
  },
 },
 ["neo-init"] = {
  desc = "KittenOS NEO / sys-init (startup)",
  v = 2,
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
  v = 2,
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
  v = 2,
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
  v = 2,
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
  v = 2,
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
  desc = "KittenOS NEO Logo shower",
  v = 2,
  deps = {
   "neo",
   "app-klogo-logo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-klogo.lua",
  },
 },
 ["app-klogo-logo"] = {
  desc = "KittenOS NEO Logo (data)",
  v = 2,
  deps = {
  },
  dirs = {
   "data",
   "data/app-klogo"
  },
  files = {
   "data/app-klogo/logo.bmp"
  },
 },
 ["app-flash"] = {
  desc = "KittenOS NEO EEPROM Flasher",
  v = 2,
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
 ["app-wget"] = {
  desc = "KittenOS Web Retriever",
  v = 2,
  deps = {
   "neo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-wget.lua"
  },
 },
 ["app-claw"] = {
  desc = "KittenOS NEO Package Manager",
  v = 2,
  deps = {
   "neo"
  },
  dirs = {
   "apps",
   "libs"
  },
  files = {
   "apps/app-claw.lua",
   "libs/app-claw-core.lua",
   "libs/app-claw-csi.lua"
  },
 },
 ["neo-meta"] = {
  desc = "KittenOS NEO: Use 'All' to install to other disks",
  v = 2,
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
   "app-claw",
   "app-wget"
  },
  dirs = {
  },
  files = {
  }
 }
}
