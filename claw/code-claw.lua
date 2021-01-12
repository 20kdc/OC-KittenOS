-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

return {
 ["neo"] = {
  desc = "KittenOS NEO Kernel & Base Libs",
  v = 10,
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
   "libs/lineedit.lua",
   "libs/braille.lua",
   "libs/bmp.lua",
   "libs/sys-filewrap.lua",
   "libs/sys-gpualloc.lua"
  },
 },
 ["neo-init"] = {
  desc = "KittenOS NEO / sys-init (startup)",
  v = 10,
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
  v = 10,
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
  v = 10,
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
  v = 10,
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
  v = 10,
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
  v = 10,
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
  v = 10,
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
  v = 10,
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
  v = 10,
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
  v = 10,
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
  v = 10,
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
 ["svc-t"] = {
  desc = "KittenOS NEO Terminal System",
  v = 10,
  deps = {
   "neo"
  },
  dirs = {
   "apps"
  },
  files = {
   "apps/svc-t.lua",
   "apps/app-luashell.lua"
  },
 },
 ["neo-meta"] = {
  desc = "KittenOS NEO: Use 'All' to install to other disks",
  v = 10,
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
   "svc-t",
   "app-wget"
  },
  dirs = {
  },
  files = {
  }
 }
}
