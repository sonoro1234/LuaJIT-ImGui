local ffi = require "ffi"
local lj_glfw = require"glfw"
local gllib = require"gl"
gllib.set_loader(lj_glfw)
local gl, glc, glu, glext = gllib.libraries()

local ig = require"imgui"

lj_glfw.setErrorCallback(function(error,description)
    print("GLFW error:",error,ffi.string(description or ""));
end)

lj_glfw.init()
local window = lj_glfw.Window(700,500)
window:makeContextCurrent() 

--choose implementation
--local ig_impl = ig.ImplGlfwGL3() --multicontext
local ig_impl = ig.Imgui_Impl_glfw_opengl3() --standard imgui opengl3 example
--local ig_impl = ig.Imgui_Impl_glfw_opengl2() --standard imgui opengl2 example

local igio = ig.GetIO()
igio.ConfigFlags = ig.lib.ImGuiConfigFlags_NavEnableKeyboard + igio.ConfigFlags


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
    
    window:swapBuffers()                    
end

ig_impl:destroy()
window:destroy()
lj_glfw.terminate()