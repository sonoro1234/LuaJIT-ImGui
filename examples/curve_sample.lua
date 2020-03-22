
local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "curve")
local win = igwin:GLFW(800,400, "curve")


local curve = win.ig.Curve("mycurve",12,100)

function win:draw(ig)
	if curve:draw(ig.ImVec2(400,300)) then
		--do something with curve.LUT array of 100 floats
	end
	ig.InputFloat2("first two",curve.LUT, nil, ig.lib.ImGuiInputTextFlags_ReadOnly)
end

win:start()