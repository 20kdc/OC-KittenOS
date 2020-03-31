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

 return function (op, defines)
  -- symbol replacement
  op = op:gsub("%$[%$a-zA-Z0-9]*", function (str)
   if str:sub(2, 2) == "$" then
    -- defines
    assert(defines[str], "no define " .. str)
    return defines[str]
   elseif str:sub(2, 3) == "NT" then
    -- temporaries +
    local id = "$" .. str:sub(4)
    assert(not forwardSymTab[id], "var already exists: " .. id)
    local val = table.remove(temporaryPool, 1)
    if not val then val = allocate("temporary") end
    forwardSymTab[id] = val
    return ""
   elseif str:sub(2, 3) == "DT" then
    -- temporaries -
    local id = "$" .. str:sub(4)
    assert(forwardSymTab[id], "no such var: " .. id)
    assert(reverseSymTab[forwardSymTab[id]] == "temporary", "var not allocated as temporary: " .. id)
    table.insert(temporaryPool, forwardSymTab[id])
    forwardSymTab[id] = nil
    return ""
   else
    -- normal handling
    if forwardSymTab[str] then
     return forwardSymTab[str]
    end
    local v = allocate(str)
    forwardSymTab[str] = v
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
end
