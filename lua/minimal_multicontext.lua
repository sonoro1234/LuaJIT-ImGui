local ffi = require "ffi"
local lj_glfw = require"GLFW.glfw"
local gl, glc, glu, glfw, glext = lj_glfw.libraries()
local ig = require"imgui"

glfw.glfwSetErrorCallback(function(error,description)
    print("GLFW error:",error,ffi.string(description or ""));
end)

lj_glfw.init()
local window = lj_glfw.Window(700,500)
window:makeContextCurrent()
local ig_gl3 = ig.ImplGlfwGL3()
ig_gl3:Init(window, true)

local windowB = lj_glfw.Window(700,500)
windowB:makeContextCurrent()
local ig_gl3B = ig.ImplGlfwGL3()
ig_gl3B:Init(windowB, true)

local showdemo = ffi.new("bool[1]",false)
while not window:shouldClose() or not windowB:shouldClose() do

    lj_glfw.pollEvents()
    
    window:makeContextCurrent()
    gl.glClear(glc.GL_COLOR_BUFFER_BIT)
    ig_gl3:NewFrame()
    if ig.Button"Hello" then
        print"Hello World!!"
    end
    ig.ShowTestWindow(showdemo)
    ig_gl3:Render()
    window:swapBuffers()                    
    
    windowB:makeContextCurrent()
    gl.glClear(glc.GL_COLOR_BUFFER_BIT)
    ig_gl3B:NewFrame()
    if ig.Button"HelloB" then
        print"Hello World B!!"
    end
    ig_gl3B:Render()
    windowB:swapBuffers()   
    
end

ig_gl3:destroy()
window:destroy()
ig_gl3B:destroy()
windowB:destroy()

lj_glfw.terminate()