-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- This library helps in crunching down the installer a bit further.
local sequences = {
 {"\n", " "},
 {"  ", " "},
 {" #", "#"},
 {"# ", "#"},
 {" ,", ","},
 {", ", ","},
 {" (", "("},
 {"( ", "("},
 {" )", ")"},
 {") ", ")"},
 {" {", "{"},
 {"{ ", "{"},
 {" }", "}"},
 {"} ", "}"},
 {" <", "<"},
 {"< ", "<"},
 {" >", ">"},
 {"> ", ">"},
 {" *", "*"},
 {"* ", "*"},
 {" ~", "~"},
 {"~ ", "~"},
 {" /", "/"},
 {"/ ", "/"},
 {" %", "%"},
 {"% ", "%"},
 {" =", "="},
 {"= ", "="},
 {" -", "-"},
 {"- ", "-"},
 {" +", "+"},
 {"+ ", "+"},
 {".. ", ".."},
 {" ..", ".."},
 {"\"\" ", "\"\""},
 {"=0 t", "=0t"},
 {">0 t", ">0t"},
 {">1 t", ">1t"},
 {"=1 w", "=1w"},
 {"=380 l", "=380l"},
 {"=127 t", "=127t"},
 {"<128 t", "<128t"},
 {"=128 t", "=128t"},
 {">255 t", ">255t"},
 {"=512 t", "=512t"}
}

local function pass(buffer)
 local ob = ""
 local smode = false
 while #buffer > 0 do
  if not smode then
   local ds = true
   while ds do
    ds = false
    for _, v in ipairs(sequences) do
     if buffer:sub(1, #(v[1])) == v[1] then
      buffer = v[2] .. buffer:sub(#(v[1]) + 1)
      ds = true
     end
    end
   end
  end
  local ch = buffer:sub(1, 1)
  buffer = buffer:sub(2)
  ob = ob .. ch
  if ch == "\"" then
   smode = not smode
  end
 end
 return ob
end

-- Context creation --
return function ()
 local forwardSymTab = {}
 local reverseSymTab = {}

 local temporaryPool = {}

 local stackFrames = {}

 local log = {}

 local possible = {}
 for i = 1, 52 do
  possible[i] = ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"):sub(i, i)
 end

 local function allocate(reason)
  for _, v in pairs(possible) do
   if not reverseSymTab[v] then
    reverseSymTab[v] = reason
    return v
   end
  end
 end

 local function allocTmp(id)
  assert(not forwardSymTab[id], "var already exists: " .. id)
  local val = table.remove(temporaryPool, 1)
  if not val then val = allocate("temporary") end
  forwardSymTab[id] = val
  table.insert(log, "allocTmp " .. id .. " -> " .. val)
  return val
 end

 local lexCrunch = {}
 function lexCrunch.dump(file)
  file:write("forward table:\n")
  for k, v in pairs(forwardSymTab) do
   file:write(k .. " -> " .. v .. "\n")
  end
  file:write("reverse table (where differing):\n")
  for k, v in pairs(reverseSymTab) do
   if forwardSymTab[v] ~= k then
    file:write(v .. " -> " .. k .. "\n")
   end
  end
  file:write("log:\n")
  for k, v in ipairs(log) do
   file:write(v .. "\n")
  end
 end
 function lexCrunch.process(op, defines)
  -- symbol replacement
  op = op:gsub("%$[%$a-z%{%}%|A-Z0-9]*", function (str)
   if str:sub(2, 2) == "$" then
    -- defines
    assert(defines[str], "no define " .. str)
    return defines[str]
   end
   local com = {}
   for v in str:sub(2):gmatch("[^%|]*") do
    table.insert(com, v)
   end
   if com[1] == "L" then
    assert(#com == 2)
    local id = "$" .. com[2]
    assert(stackFrames[1], "allocation of " .. id .. " outside of stack frame")
    table.insert(stackFrames[1], id)
    return allocTmp(id)
   elseif com[1] == "{" then
    assert(#com == 1)
    table.insert(stackFrames, 1, {})
    return ""
   elseif com[1] == "}" then
    assert(#com == 1)
    for _, id in ipairs(table.remove(stackFrames, 1)) do
     table.insert(temporaryPool, forwardSymTab[id])
     forwardSymTab[id] = nil
    end
    return ""
   else
    assert(#com == 1)
    local id = "$" .. com[1]
    -- normal handling
    if forwardSymTab[id] then
     return forwardSymTab[id]
    end
    local v = allocate(id)
    forwardSymTab[id] = v
    return v
   end
  end)
  -- comment removal
  while true do
   local np = op:gsub("%-%-[^\n]*\n", " ")
   np = np:gsub("%-%-[^\n]*$", "")
   if np == op then
    break
   end
   op = np
  end
  -- stripping
  while true do
   local np = pass(op)
   if np == op then
    return np
   end
   op = np
  end
  return op
 end
 return lexCrunch
end
