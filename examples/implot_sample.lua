local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "widgets",{vsync=true})
local win = igwin:GLFW(800,400, "widgets",{vsync=true})


local ffi = require"ffi"
local xs1, ys1 = ffi.new("float[?]",1001),ffi.new("float[?]",1001)
for i = 0,1000 do
    xs1[i] = i * 0.001;
    ys1[i] = 0.5 + 0.5 * math.sin(50 * xs1[i]);
end

local xs2, ys2 = ffi.new("float[?]",11),ffi.new("float[?]",11)
for i = 0,10 do
    xs2[i] = i * 0.1;
    ys2[i] = xs2[i] * xs2[i];
end


function win:draw(ig)
	ig.ShowImPlotDemoWindow()
	ig.Begin("Ploters")
	if (ig.BeginPlot("Line Plot", "x", "f(x)", ig.ImVec2(-1,-1))) then
          ig.Plot("sin(50*x)", xs1, ys1, 1001);
          ig.PushPlotStyleVarInt(ig.lib.ImPlotStyleVar_Marker, ig.lib.ImMarker_Circle);
          ig.Plot("x^2", xs2, ys2, 11);
          ig.PopPlotStyleVar();
        ig.EndPlot();
    end
	ig.End()
end



win:start()