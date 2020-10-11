local igwin = require"imgui.window"

--local win = igwin:SDL(800,400, "widgets",{vsync=true,use_implot=true})
local win = igwin:GLFW(800,400, "widgets",{vsync=true})
win.ig.ImPlot_CreateContext()

local ffi = require"ffi"

local xs2, ys2 = ffi.new("float[?]",11),ffi.new("float[?]",11)
for i = 0,10 do
    xs2[i] = i * 0.1;
    ys2[i] = xs2[i] * xs2[i];
end

local gettercb = ffi.cast("ImPlotPoint *(*)(void* data, int idx)", function(data,idx)
    local ipp = ffi.new("ImPlotPoint[1]")
    ipp[0].x = idx*0.001; ipp[0].y=0.5 + 0.5 * math.sin(50 * ipp[0].x);
    return ipp
end)
function win:draw(ig)
    ig.ImPlot_ShowDemoWindow()
    ig.Begin("Ploters")
    if (ig.ImPlot_BeginPlot("Line Plot", "x", "f(x)", ig.ImVec2(-1,-1))) then
        ig.ImPlot_PlotLineG("Line Plot",gettercb,nil,1000,0)
        ig.ImPlot_AnnotateClamped(0.25,1.1,ig.ImVec2(15,15),ig.ImPlot_GetLastItemColor(),"function %f %s",1,"hello");
        ig.ImPlot_SetNextMarkerStyle(ig.lib.ImPlotMarker_Circle);
        ig.ImPlot_PlotLine("x^2", xs2, ys2, 11);
        ig.ImPlot_EndPlot();
    end
    ig.End()
end

local function clean()
    win.ig.ImPlot_DestroyContext()
end

win:start(clean)