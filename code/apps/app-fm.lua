-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-fm: dummy app to start FM
neo.requestAccess("x.neo.pub.base").showFileDialogAsync(nil)
while true do
 local x = {coroutine.yield()}
 if x[1] == "x.neo.pub.base" then
  if x[2] == "filedialog" then
   return
  end
 end
end
