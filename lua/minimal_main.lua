local ffi = require "ffi"
local lj_glfw = require"glfw"
local gl, glc, glu, glfw, glext = lj_glfw.libraries()
local ig = require"imgui"

glfw.glfwSetErrorCallback(function(error,description)
    print("GLFW error:",error,ffi.string(description or ""));
end)

lj_glfw.init()
local window = lj_glfw.Window(700,500)
window:makeContextCurrent() 

--choose implementation
-- local ig_gl3 = ig.ImplGlfwGL3() --multicontext
local ig_gl3 = ig.Imgui_Impl_glfw_opengl3:new() --standard imgui example

ig_gl3:Init(window, true)

local showdemo = ffi.new("bool[1]",false)
while not window:shouldClose() do

    lj_glfw.pollEvents()
    
    gl.glClear(glc.GL_COLOR_BUFFER_BIT)
    
    ig_gl3:NewFrame()
    
    if ig.Button"Hello" then
        print"Hello World!!"
    end
    ig.ShowDemoWindow(showdemo)
    
    ig_gl3:Render()
    
    window:swapBuffers()                    
end

ig_gl3:destroy()
window:destroy()
lj_glfw.terminate()