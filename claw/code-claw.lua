-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.
return {
 ["neo"] = {
  desc = "KittenOS NEO Kernel & Base Libs",
  v = 5,
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
  v = 7,
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
  v = 5,
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
  v = 7,
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
  v = 5,
  deps = {
   "neo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-textedit.lua",
   "apps/app-batmon.lua",
   "apps/app-control.lua",
   "apps/app-taskmgr.lua"
  }
 },
 ["app-bmpview"] = {
  desc = "KittenOS NEO .bmp viewer",
  v = 5,
  deps = {
   "neo",
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-bmpview.lua",
  },
 },
 ["neo-logo"] = {
  desc = "KittenOS NEO Logo (data)",
  v = 6,
  deps = {
  },
  dirs = {
   "docs"
  },
  files = {
   "docs/logo.bmp"
  },
 },
 ["app-flash"] = {
  desc = "KittenOS NEO EEPROM Flasher",
  v = 5,
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
  v = 5,
  deps = {
   "neo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/app-claw.lua",
   "apps/svc-app-claw-worker.lua"
  },
 },
 ["neo-meta"] = {
  desc = "KittenOS NEO: Use 'All' to install to other disks",
  v = 5,
  deps = {
   "neo",
   "neo-init",
   "neo-launcher",
   "neo-everest",
   "neo-icecap",
   "neo-secpolicy",
   "neo-coreapps",
   "neo-logo",
   "app-bmpview",
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
