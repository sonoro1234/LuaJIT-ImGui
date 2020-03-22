
local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "plotter")
local win = igwin:GLFW(800,400, "plotter")

local ffi = require"ffi"
local buffer = ffi.new("char[256]", "1/x")

local Graph = win.ig.Plotter(-10,10)
--Graph:calc(function(x) return math.exp(x) end)
Graph:calc(function(x) return 1/x end)
--Graph:calc(function(x) return x*(x+1)/x end)

function win:draw(ig)

    if ig.InputText("function(x)",buffer,ffi.sizeof(buffer),ig.lib.ImGuiInputTextFlags_EnterReturnsTrue) then
        local str = ffi.string(buffer)
        str = "return function(x) return "..str.." end"
        local f = loadstring(str)
        if f then
            Graph:calc(f())
        else
            print"bad function definition"
        end
    end
    Graph:draw()

end

win:start()