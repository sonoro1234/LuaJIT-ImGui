local ffi = require "ffi"
jit.off(true,true)
local lj_glfw = require"glfw"
local gl, glc, glu, glfw, glext = lj_glfw.libraries()
local ig = require"imgui_viewport"

glfw.glfwSetErrorCallback(function(error,description)
    print("GLFW error:",error,ffi.string(description or ""));
end)

lj_glfw.init()
local window = lj_glfw.Window(700,500)
window:makeContextCurrent() 
--glfw.glfwSwapInterval(1)

--choose implementation
--local ig_impl = ig.ImplGlfwGL3() --multicontext
local ig_impl = ig.Imgui_Impl_glfw_opengl3() --standard imgui opengl3 example
--local ig_impl = ig.Imgui_Impl_glfw_opengl2() --standard imgui opengl2 example


ig.CreateContext(nil);

---[[
local igio = ig.GetIO()
print(ig.lib.ImGuiConfigFlags_ViewportsEnable , igio.ConfigFlags,igio)
ig.GetIO().ConfigFlags = ig.lib.ImGuiConfigFlags_ViewportsEnable --+ igio.ConfigFlags
--ig.GetIO().ConfigFlags = 0
print(ig.lib.ImGuiConfigFlags_ViewportsEnable , igio.ConfigFlags,igio)
igio.ConfigFlags = ig.lib.ImGuiConfigFlags_ViewportsNoTaskBarIcons + igio.ConfigFlags
igio.ConfigFlags = ig.lib.ImGuiConfigFlags_NavEnableKeyboard + igio.ConfigFlags  -- Enable Keyboard Controls
--io.ConfigFlags |= ImGuiConfigFlags_ViewportsNoMerge;
--io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;   // Enable Gamepad Controls
--]]
--ig_impl:Init(window, true)
    ig.lib.ImGui_ImplGlfw_InitForOpenGL(window, true);
    ig.lib.ImGui_ImplOpenGL3_Init("#version 150");
local showdemo = ffi.new("bool[1]",false)
while not window:shouldClose() do
--print"loop"
    lj_glfw.pollEvents()
    --print(igio.MousePos)
    gl.glClear(glc.GL_COLOR_BUFFER_BIT)
 -- print"loop2"    
    ig_impl:NewFrame()
 -- print"loop3"    
    if ig.Button"Hello" then
        print"Hello World!!"
    end
   ig.ShowDemoWindow(showdemo)
    
    ig_impl:Render()
	--print(igio.ConfigFlags , ig.lib.ImGuiConfigFlags_ViewportsEnable)
	if bit.band(igio.ConfigFlags , ig.lib.ImGuiConfigFlags_ViewportsEnable) ~= 0 then
		--print"update"
        ig.UpdatePlatformWindows();
        ig.RenderPlatformWindowsDefault();
    end
	window:makeContextCurrent() 
    window:swapBuffers()                    
end

ig_impl:destroy()
window:destroy()
lj_glfw.terminate()