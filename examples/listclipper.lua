local igwin = require"imgui.window"
local win = igwin:SDL(800,400, "list clipper")
local ig = win.ig
local ffi = require"ffi"
function win:draw(ig)
    local cols = 10
    if ig.Begin("testt") then
        local clipper = ig.ImGuiListClipper()
        clipper:Begin(1000)
        while (clipper:Step()) do
            for line = clipper.DisplayStart,clipper.DisplayEnd-1 do
                for N=line*cols+1,line*cols+cols do
                    if ig.Button(string.format("%04d",N)) then
                        print(N)
                    end
                    if not ((N)%cols == 0) then ig.SameLine() end
                end
            end
        end
        clipper:End()
    end
    ig.End()
end

win:start()