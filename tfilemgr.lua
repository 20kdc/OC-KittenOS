-- The File Manager (manager of files).
-- Args:
local filetype, openmode, gpu = ...
local fileManager = nil
function fileManager(filetype, openmode)
 -- Like policykit, this is a trusted gateway.
 -- Note that The File Manager just returns a path {fs, path}.
 -- The File Wrapper is given that path, and the open mode.
 local title = nil
 -- Valid open modes are:
 -- nil: The File Wrapper should not be invoked -
 --       likely a "file manager launcher" application.
 if openmode == nil then title = "File Manager" end
 -- "r": Open the file for reading. Binary mode is assumed.
 if openmode == "r" then
  title = "Read " .. filetype
 end
 if openmode == "w" then
  title = "Write " .. filetype
 end
 -- "w": Open the file for truncate-writing, again binary assumed.
 if not title then error("Bad openmode") end
 
 local scrW, scrH = gpu.getResolution()
 gpu.setBackground(0)
 gpu.setForeground(0xFFFFFF)
 local function cls()
  gpu.fill(1, 1, scrW, scrH, " ")
 end
 local function menuKey(cursor, el, text, ka, kc, allowEntry)
  if ka == 13 then
   -- entry denied, so we hit here.
   return cursor, text
  end
  if kc == 200 then
   cursor = cursor - 1
   if cursor < 1 then cursor = el end
   return cursor, text, false, true
  end
  if kc == 208 then
   cursor = cursor + 1
   if cursor > el then cursor = 1 end
   return cursor, text, false, true
  end
  if allowEntry then
   if ka == 8 then
    return cursor, unicode.sub(text, 1, unicode.len(text) - 1), true
   end
   if (ka ~= 0) and (ka ~= ("/"):byte()) and (ka ~= ("\\"):byte()) then
    text = text .. unicode.char(ka)
    return cursor, text, true
   end
  end
  return cursor, text
 end
 local function menu(title, entries, allowEntry)
  cls()
  gpu.fill(1, 1, scrW, 1, "-")
  gpu.set(1, 1, title)
  local cursor = 1
  local escrH = scrH
  local entryText = ""
  local cursorBlinky = false
  if allowEntry then escrH = scrH - 1 end
  while true do
   for y = 2, escrH do
    local o = cursor + (y - 8)
    local s = tostring(entries[o])
    if not entries[o] then s = "" end
    if o == cursor then s = ">" .. s else s = " " .. s end
    gpu.fill(1, y, scrW, 1, " ")
    gpu.set(1, y, s)
   end
   cursorBlinky = not cursorBlinky
   if allowEntry then
    gpu.fill(1, scrH, scrW, 1, " ")
    if cursorBlinky then
     gpu.set(1, scrH, ":" .. entryText)
    else
     gpu.set(1, scrH, ":" .. entryText .. "_")
    end
   end
   local t, p1, p2, p3, p4 = computer.pullSignal(1)
   if t == "key_down" then
    if p2 == 13 then
     if allowEntry then
      if entryText ~= "" then
       return entryText
      end
     else
      return entries[cursor]
     end
    end
    cursor, entryText, search, lookup = menuKey(cursor, #entries, entryText, p2, p3, allowEntry)
    if search then
     for k, v in ipairs(entries) do
      if v:sub(1, v:len()) == entryText then cursor = k end
     end
    end
    if lookup then
     entryText = entries[cursor]
    end
   end
  end
 end
 
 local currentDir = nil
 local currentDrive = nil
 local function listDir(dv, dr)
  if dv == nil then
   local l = {}
   local t = {}
   for c in component.list("filesystem") do
    l[c] = {c, "/"}
    table.insert(t, c)
   end
   return l, t, "Filesystems"
  end
  local names = component.invoke(dv, "list", dr)
  local l = {}
  for k, v in ipairs(names) do
   if component.invoke(dv, "isDirectory", dr .. v) then
    l[v] = {dv, dr .. v}
   end
  end
  return l, names, dv .. ":" .. dr
 end
 local function isDir(dv, dr)
  if dv == nil then return true end
  return component.invoke(dv, "isDirectory", dr)
 end
 
 local tagMkdir = "// Create Directory //"
 local tagCancel = "// Cancel //"
 local tagOpen = "// Open //"
 local tagDelete = "// Delete //"
 local tagRename = "// Rename //"
 local tagCopy = "// Copy //"
 local tagBack = ".."
 
 local function textEntry(title)
  local txt = menu(title, {tagCancel}, true)
  if txt ~= tagCancel then return txt end
  return nil
 end
 local function report(title)
  menu(title, {"OK"}, false)
 end
 
 local history = {}
 local function navigate(ndr, ndd)
  table.insert(history, {currentDrive, currentDir})
  currentDrive, currentDir = ndr, ndd
 end
 while true do
  local map, sl, name = listDir(currentDrive, currentDir)
  if #history ~= 0 then
   table.insert(sl, tagBack)
  end
  table.insert(sl, tagCancel)
  if currentDrive then
   table.insert(sl, tagMkdir)
  end
  local str = menu(title .. " " .. name, sl, (openmode == "w") and currentDrive)
  if str == tagBack then
   local r = table.remove(history, #history)
   currentDrive, currentDir = table.unpack(r)
  else
   if str == tagCancel then return nil end
   if str == tagMkdir then
    local nam = textEntry("Create Directory...")
    if nam then
     component.invoke(currentDrive, "makeDirectory", currentDir .. nam)
    end
   else
    if map[str] then
     if map[str][1] and currentDrive then
      local act = menu(name .. ":" .. str, {tagOpen, tagRename, tagDelete, tagCancel})
      if act == tagOpen then
       navigate(table.unpack(map[str]))
      end
      if act == tagRename then
       local s = textEntry("Rename " .. str)
       if s then
        component.invoke(map[str][1], "rename", map[str][2], currentDir .. s)
       end
      end
      if act == tagDelete then
       component.invoke(map[str][1], "remove", map[str][2])
      end
     else
      navigate(table.unpack(map[str]))
     end
    else
     if openmode == "w" then return {currentDrive, currentDir .. str} end
     local r = currentDir .. str
     local subTag = "Size: " .. math.ceil(component.invoke(currentDrive, "size", r) / 1024) ..  "KiB"
     if openmode == "r" then subTag = tagOpen end
     local act = menu(name .. ":" .. str, {subTag, tagRename, tagCopy, tagDelete, tagCancel})
     if act == tagOpen then return {currentDrive, currentDir .. str} end
     if act == tagRename then
      local s = textEntry("Rename " .. str)
      component.invoke(currentDrive, "rename", currentDir .. str, currentDir .. s)
     end
     if act == tagCopy then
      local f2 = fileManager("Copy " .. str, "w")
      if f2 then
       local h = component.invoke(currentDrive, "open", currentDir .. str, "rb")
       if not h then
        report("Couldn't open file!")
       else
        local h2 = component.invoke(f2[1], "open", f2[2], "wb")
        if not h2 then
         report("Couldn't open dest. file!")
        else
         local chk = component.invoke(currentDrive, "read", h, 128)
         while chk do
          component.invoke(f2[1], "write", h2, chk)
          chk = component.invoke(currentDrive, "read", h, 128)
         end
        end
        component.invoke(currentDrive, "close", h)
       end
      end
     end
     if act == tagDelete then
      component.invoke(currentDrive, "remove", currentDir .. str)
     end
    end
   end
  end
 end
end
return fileManager(filetype, openmode)