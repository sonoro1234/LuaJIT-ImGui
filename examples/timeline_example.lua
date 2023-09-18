local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "timeline")
local win = igwin:GLFW(800,400, "timeline")

local tl = require"timeline_widget"(win.ig)

local ffi = require"ffi"
local offandscale = win.ig.ImVec2(0,1) 
local events = ffi.new("float[?]",1000)
for i=0,499 do
	events[i*2] = math.random(0,50)
	events[i*2+1] = math.random(events[i*2],50)
end
function win:draw(ig)
		ig.SetNextWindowSize(ig.ImVec2(500,300),ig.lib.ImGuiCond_Once)
		ig.Begin("timelines")
		local clipper = ig.ImGuiListClipper()
        if (tl.BeginTimeline("MyTimeline",50,0,offandscale)) then -- label, max_value, num_visible_rows
			clipper:Begin(500)
			while (clipper:Step()) do
				for line = clipper.DisplayStart,clipper.DisplayEnd-1 do
					if tl.TimelineEvent("Event"..line,events+line*2,line%10==0) then
						print("modi: ",line)
					end
					if ig.IsItemClicked() and ig.IsMouseDoubleClicked(0) then print("edit",line) end
				end
			end
			clipper:End()
        end
        local elapsedTime = (((ig.GetTime()*1000))%50000)/1000;    -- So that it's always in [0,50]
        tl.EndTimeline(5,elapsedTime,ig.U32(1,0,0,1));  -- num_vertical_grid_lines, current_time (optional), timeline_running_color (optional)
		ig.End()
end

win:start()
