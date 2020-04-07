local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "widgets")
local win = igwin:GLFW(800,400, "widgets")


local ffi = require"ffi"
local val = ffi.new("float[1]")
local padval = ffi.new("float[2]")
local curve = win.ig.Curve("mycurve",12,100)
local Quat = ffi.new("quat",{1,0,0,0})
local v3 = ffi.new("float[3]",{1,0,0})
local mat4 = win.ig.mat4_cast(Quat).f

function win:draw(ig)

	if ig.Begin("widgets",nil, ig.lib.ImGuiWindowFlags_AlwaysAutoResize) then
		if ig.TreeNode"dial" then
			ig.dial("turns",val,nil,0.5/math.pi)
			ig.SameLine()
			ig.dial("radians",val)
			ig.TreePop();
			ig.Separator();
		end
		if ig.TreeNode"pad" then
			ig.pad("mypad", padval)
			ig.InputFloat2("vals",padval)
			ig.TreePop();
			ig.Separator();
		end
		if ig.TreeNode"curve" then
			if curve:draw(ig.ImVec2(400,300)) then
			--do something with curve.LUT array of 100 floats
			end
			ig.InputFloat2("first two",curve.LUT, nil, ig.lib.ImGuiInputTextFlags_ReadOnly)
			ig.TreePop();
			ig.Separator();
		end
		if ig.TreeNode"gizmoquat" then

			if ig.Guizmo3D("###guizmo0",Quat,150,ig.lib.mode3Axes + ig.lib.cubeAtOrigin) then
				mat4 = ig.mat4_cast(Quat).f
				print(mat4)
			end
			ig.SameLine()
			ig.BeginGroup()
			ig.InputFloat4("##1",mat4, nil, ig.lib.ImGuiInputTextFlags_ReadOnly)
			ig.InputFloat4("##2",mat4+4, nil, ig.lib.ImGuiInputTextFlags_ReadOnly)
			ig.InputFloat4("##3",mat4+8, nil, ig.lib.ImGuiInputTextFlags_ReadOnly)
			ig.InputFloat4("##4",mat4+12, nil, ig.lib.ImGuiInputTextFlags_ReadOnly)
			ig.EndGroup()
			ig.setDirectionColor(ig.ImVec4(1,0,0,1))
			ig.Guizmo3Dvec3("guizmo3",v3,150,ig.lib.modeDirection)
			ig.restoreDirectionColor()
			ig.InputFloat3("dir",v3, nil, ig.lib.ImGuiInputTextFlags_ReadOnly)
			ig.TreePop();
			ig.Separator();
		end
	end
	ig.End()
end



win:start()