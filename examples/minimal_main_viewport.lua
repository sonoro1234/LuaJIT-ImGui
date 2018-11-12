local ffi = require "ffi"
--jit.off(true,true)
local lj_glfw = require"glfw"
local gllib = require"gl"(lj_glfw)
local gl, glc, glu, glext = gllib.libraries()
local ig = require"imgui_viewport"

lj_glfw.setErrorCallback(function(error,description)
    print("GLFW error:",error,ffi.string(description or ""));
end)

lj_glfw.init()
local window = lj_glfw.Window(700,500)
window:makeContextCurrent() 
--glfw.glfwSwapInterval(1)

--choose implementation
local ig_impl = ig.Imgui_Impl_glfw_opengl3() --standard imgui opengl3 example
--local ig_impl = ig.Imgui_Impl_glfw_opengl2() --standard imgui opengl2 example

---[[
local igio = ig.GetIO()
ig.GetIO().ConfigFlags = ig.lib.ImGuiConfigFlags_ViewportsEnable + igio.ConfigFlags
igio.ConfigFlags = ig.lib.ImGuiConfigFlags_ViewportsNoTaskBarIcons + igio.ConfigFlags
igio.ConfigFlags = ig.lib.ImGuiConfigFlags_NavEnableKeyboard + igio.ConfigFlags  -- Enable Keyboard Controls
--io.ConfigFlags = ig.lib.ImGuiConfigFlags_ViewportsNoMerge + igio.ConfigFlags
--io.ConfigFlags = ig.lib.ImGuiConfigFlags_NavEnableGamepad + igio.ConfigFlags   // Enable Gamepad Controls
--]]

ig_impl:Init(window, true)

local showdemo = ffi.new("bool[1]",false)
while not window:shouldClose() do

    lj_glfw.pollEvents()

    gl.glClear(glc.GL_COLOR_BUFFER_BIT)
 
    ig_impl:NewFrame()
  
    if ig.Button"Hello" then
        print"Hello World!!"
    end
   ig.ShowDemoWindow(showdemo)
    
    ig_impl:Render()
	window:makeContextCurrent() 
    if bit.band(igio.ConfigFlags , ig.lib.ImGuiConfigFlags_ViewportsEnable) ~= 0 then
        ig.UpdatePlatformWindows();
        ig.RenderPlatformWindowsDefault();
    end
    window:makeContextCurrent() 
    window:swapBuffers()                    
end

ig_impl:destroy()
window:destroy()
lj_glfw.terminate()