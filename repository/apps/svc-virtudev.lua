-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- svc-virtudev.lua : Virtual Device interface
-- Authors: 20kdc

local ic = neo.requireAccess("x.neo.pub.base", "to lock x.svc.virtudev")
-- this is a pretty powerful permission, and PROBABLY EXPLOITABLE
ic.lockPerm("x.svc.virtudev")
local r = neo.requireAccess("r.svc.virtudev", "api endpoint")

local root = neo.requireAccess("k.root", "the ability to modify the component API")

local proxies = {}
local types = {}

local function uninstall(k)
 proxies[k] = nil
 types[k] = nil
 root.computer.pushSignal("component_removed", k, types[k])
end

local users = {}
local userCount = 0

r(function (pkg, pid, sendSig)
 local userAddresses = {}
 users[pid] = userAddresses
 userCount = userCount + 1
 return {
  install = function (proxy)
   local proxyAddress = proxy.address
   local proxyType = proxy.type
   assert(type(proxyAddress) == "string")
   assert(type(proxyType) == "string")
   assert(not proxies[proxyAddress], "proxy address in use: " .. proxyAddress)
   proxies[proxyAddress] = proxy
   types[proxyAddress] = proxyType
   userAddresses[proxyAddress] = true
   root.computer.pushSignal("component_added", proxyAddress, proxyType)
   return function (a, ...)
    root.computer.pushSignal(a, proxyAddress, ...)
   end
  end,
  uninstall = function (k)
   if userAddresses[k] then
    uninstall(k)
    userAddresses[k] = nil
   end
  end
 }
end)

local componentProxyRaw = root.component.proxy
local componentTypeRaw = root.component.type
local componentMethodsRaw = root.component.methods
local componentFieldsRaw = root.component.fields
local componentDocRaw = root.component.doc
local componentInvokeRaw = root.component.invoke
local componentListRaw = root.component.list

root.component.proxy = function (address)
 if proxies[address] then
  return proxies[address]
 end
 return componentProxyRaw(address)
end

root.component.type = function (address)
 if types[address] then
  return types[address]
 end
 return componentTypeRaw(address)
end

local function methodsFieldsHandler(address, methods)
 if proxies[address] then
  local mt = {}
  for k, v in pairs(proxies[address]) do
   if (type(v) == "function") == methods then
    mt[k] = true
   end
  end
  return mt
 end
 if methods then
  return componentMethodsRaw(address)
 else
  return componentFieldsRaw(address)
 end
end

root.component.methods = function (address) return methodsFieldsHandler(address, true) end
root.component.fields = function (address) return methodsFieldsHandler(address, false) end
root.component.doc = function (address, method)
 if proxies[address] then
  return tostring(proxies[address][method])
 end
 return componentDocRaw(address, method)
end
root.component.invoke = function (address, method, ...)
 if proxies[address] then
  return proxies[address][method](...)
 end
 return componentInvokeRaw(address, method, ...)
end

root.component.list = function (f, e)
 local iter = componentListRaw(f, e)
 local ended = false
 local others = {}
 for k, v in pairs(types) do
  if (f == v) or ((not e) and v:find(f, 1, true)) then
   table.insert(others, {k, v})
  end
 end
 return function ()
  if not ended then
   local a, t = iter()
   if not a then
    ended = true
   else
    return a, t
   end
  end
  -- at end of that, so what about others
  local ent = table.remove(others, 1)
  if ent then
   return table.unpack(ent)
  end
 end
end

while true do
 local e1, e2, e3 = coroutine.yield()
 if e1 == "k.procdie" then
  if users[e3] then
   for k, _ in pairs(users[e3]) do
    uninstall(k)
   end
   users[e3] = nil
   userCount = userCount - 1
   if userCount == 0 then
    break
   end
  end
 end
end

root.component.proxy = componentProxyRaw
root.component.type = componentTypeRaw
root.component.methods = componentMethodsRaw
root.component.fields = componentFieldsRaw
root.component.doc = componentDocRaw
root.component.invoke = componentInvokeRaw
root.component.list = componentListRaw
