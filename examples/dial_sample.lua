
local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "dial")
local win = igwin:GLFW(800,400, "dial")

local ffi = require"ffi"
local val = ffi.new("float[1]")

function win:draw(ig)
	ig.dial("turns",val,nil,0.5/math.pi)
	ig.dial("radians",val)
end

win:start()