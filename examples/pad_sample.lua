
local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "pad")
local win = igwin:GLFW(400,400, "pad")

local ffi = require"ffi"
local val2 = ffi.new("float[2]")
function win:draw(ig)
	ig.pad("mypad", val2)
	ig.InputFloat2("vals",val2)
end

win:start()