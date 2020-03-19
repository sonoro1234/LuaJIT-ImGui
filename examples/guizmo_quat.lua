
local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "guizmo_quat")
local win = igwin:GLFW(800,400, "guizmo_quat")


local ffi = require"ffi"
local Quat = ffi.new("quat",{1,0,0,0})
local v3 = ffi.new("float[3]",{1,1,1})
function win:draw(ig)

    ig.Guizmo3D("###guizmo0",Quat,200,ig.lib.mode3Axes + ig.lib.cubeAtOrigin)
    ig.setDirectionColor(ig.ImVec4(1,0,0,1))
    ig.Guizmo3Dvec3("guizmo3",v3,150,ig.lib.modeDirection)
    ig.restoreDirectionColor()

end

win:start()