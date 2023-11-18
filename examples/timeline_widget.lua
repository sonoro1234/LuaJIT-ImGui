--from Flix code
--Timeline Stuff Here (from: https://github.com/nem0/LumixEngine/blob/timeline_gui/external/imgui/imgui_user.inl)=
-- Improved with code by @meshula (panzoomer here: https://github.com/ocornut/imgui/issues/76)
-- removed clipping code to allow using ImGuiListClipper from main
local function loader(ig)
local M = {}

local ffi = require"ffi"
local s_max_timeline_value=0;
local s_ptimeline_offset_and_scale = NULL;


function M.BeginTimeline(str_id, max_value, num_visible_rows, popt_offset_and_scale)

    -- reset global variables
    s_max_timeline_value=0.;
    s_ptimeline_offset_and_scale = popt_offset_and_scale;

    if (s_ptimeline_offset_and_scale~=nil) then
        if (s_ptimeline_offset_and_scale.y==0) then s_ptimeline_offset_and_scale.y=1; end
    end
    local row_height = ig.GetTextLineHeightWithSpacing();
    local rv = ig.BeginChild(str_id,ig.ImVec2(0,num_visible_rows>0 and (row_height*(num_visible_rows+1)) or (ig.GetContentRegionAvail().y-row_height*1.2)),false);
    ig.PushStyleColor(ig.lib.ImGuiCol_Separator,ig.GetStyle().Colors[ig.lib.ImGuiCol_Border]);
    ig.Columns(2,str_id);
    local contentRegionWidth = ig.GetWindowContentRegionMax().x-ig.GetWindowContentRegionMin().x; -- ImGui::GetContentRegionAvail().x ?
    if (ig.GetColumnOffset(1)>=contentRegionWidth*0.48) then ig.SetColumnOffset(1,contentRegionWidth*0.15); end
    s_max_timeline_value = max_value>=0 and max_value or (contentRegionWidth*0.85);

    return rv;
end

function M.TimelineEvent(str_id, values, keep_range_constant)

--print(str_id)
    local row_height = ig.GetTextLineHeightWithSpacing();
    local TIMELINE_RADIUS = row_height*0.45;
    local row_height_offset = (row_height-TIMELINE_RADIUS*2)*0.5;


    local win = ig.GetCurrentWindow();
    local inactive_color = ig.ColorConvertFloat4ToU32(ig.GetStyle().Colors[ig.lib.ImGuiCol_Button]);
    local active_color = ig.ColorConvertFloat4ToU32(ig.GetStyle().Colors[ig.lib.ImGuiCol_ButtonHovered]);
    local line_color = ig.ColorConvertFloat4ToU32(ig.GetStyle().Colors[ig.lib.ImGuiCol_SeparatorActive]);
    local changed = false;
    local hovered = false;
    local active = false;

    ig.Text("%s",str_id);
    ig.NextColumn();


    local s_timeline_time_offset = s_ptimeline_offset_and_scale~=nil and s_ptimeline_offset_and_scale.x or 0;
    local s_timeline_time_scale = s_ptimeline_offset_and_scale~=nil and s_ptimeline_offset_and_scale.y or 1;

    local columnOffset = ig.GetColumnOffset(1);
    local columnWidth = ig.GetColumnWidth(1)-ig.GetStyle().ScrollbarSize;
    local columnWidthScaled = columnWidth * s_timeline_time_scale;
    local columnWidthOffsetScaled = columnWidthScaled * s_timeline_time_offset;
    local cursor_pos = ig.ImVec2(ig.GetWindowContentRegionMin().x + win.Pos.x+columnOffset-TIMELINE_RADIUS,win.DC.CursorPos.y);
    local mustMoveBothEnds=false;
    local isMouseDraggingZero = ig.IsMouseDragging(0);
    local posx = ffi.new("float[?]",2,{0,0});

    for i=0,1 do
        local pos = ig.ImVec2(cursor_pos);
        pos.x = pos.x + columnWidthScaled * values[i] / s_max_timeline_value - columnWidthOffsetScaled + TIMELINE_RADIUS;
        pos.y = pos.y + row_height_offset+TIMELINE_RADIUS;
        posx[i] = pos.x;
        --if (pos.x+TIMELINE_RADIUS < cursor_pos.x or pos.x-2*TIMELINE_RADIUS > cursor_pos.x+columnWidth) continue;   -- culling
		if (pos.x+TIMELINE_RADIUS >= cursor_pos.x and pos.x-2*TIMELINE_RADIUS <= cursor_pos.x+columnWidth) then
        ig.SetCursorScreenPos(pos - ig.ImVec2(TIMELINE_RADIUS, TIMELINE_RADIUS));
        ig.PushID(i);
        ig.InvisibleButton(str_id, ig.ImVec2(2 * TIMELINE_RADIUS, 2 * TIMELINE_RADIUS));
        active = ig.IsItemActive();
        if (active or ig.IsItemHovered()) then
            ig.SetTooltip("%f", values[i]);
            if (not keep_range_constant)	then
                -- @meshula:The item hovered line needs to be compensated for vertical scrolling. Thx!
                local a = ig.ImVec2(pos.x, ig.GetWindowContentRegionMin().y + win.Pos.y + win.Scroll.y);
                local b = ig.ImVec2(pos.x, ig.GetWindowContentRegionMax().y + win.Pos.y + win.Scroll.y);
                -- possible aternative:
                --ImVec2 a(pos.x, win->Pos.y);
                --ImVec2 b(pos.x, win->Pos.y+win->Size.y);
                win.DrawList:AddLine(a, b, line_color);
            end
            hovered = true;
        end
        if (active and isMouseDraggingZero) then
            if (not keep_range_constant) then
                values[i] = values[i] + ig.GetIO().MouseDelta.x / columnWidthScaled * s_max_timeline_value;
                if (values[i]<0) then values[i]=0; 
                elseif (values[i]>s_max_timeline_value) then values[i]=s_max_timeline_value; end
            else 
				mustMoveBothEnds = true;
			end
            changed , hovered = true,true;
        end
        ig.PopID();
        win.DrawList:AddCircleFilled(
                    pos, TIMELINE_RADIUS, (ig.IsItemActive() or ig.IsItemHovered()) and active_color or inactive_color,8);
	end
    end

    local start = ig.ImVec2(posx[0]+TIMELINE_RADIUS*0.5,cursor_pos.y+row_height*0.1)--*0.3);
    local endp = ig.ImVec2(posx[1]-TIMELINE_RADIUS*0.5,start.y+row_height*0.8)--*0.4);

    if (start.x<cursor_pos.x) then start.x=cursor_pos.x; end
    if (endp.x>cursor_pos.x+columnWidth+TIMELINE_RADIUS) then endp.x=cursor_pos.x+columnWidth+TIMELINE_RADIUS; end
    local isInvisibleButtonCulled = start.x >= cursor_pos.x+columnWidth or endp.x<=cursor_pos.x;

    local isInvisibleButtonItemActive=false;
    local isInvisibleButtonItemHovered=false;
    if (not isInvisibleButtonCulled)   then
        ig.PushID(-1);
        ig.SetCursorScreenPos(start);
        ig.InvisibleButton(str_id, endp - start);
        isInvisibleButtonItemActive = ig.IsItemActive();
        isInvisibleButtonItemHovered = isInvisibleButtonItemActive or ig.IsItemHovered();
        ig.PopID();
        win.DrawList:AddRectFilled(start, endp, (isInvisibleButtonItemActive or isInvisibleButtonItemHovered) and active_color or inactive_color);
    end
    if ((isInvisibleButtonItemActive and isMouseDraggingZero) or mustMoveBothEnds) then
        local deltaX = ig.GetIO().MouseDelta.x / columnWidthScaled * s_max_timeline_value;
        values[0] = values[0] + deltaX;
        values[1] = values[1] + deltaX;
        changed, hovered = true,true;
    elseif (isInvisibleButtonItemHovered) then 
		hovered = true;
	end

    ig.SetCursorScreenPos(cursor_pos + ig.ImVec2(0, row_height));
	ig.Dummy(ig.ImVec2(0,0))
    if (changed) then
        if (values[0]>values[1]) then local tmp=values[0];values[0]=values[1];values[1]=tmp; end
        if (values[1]>s_max_timeline_value) then values[0]= values[0] -(values[1]-s_max_timeline_value);values[1]=s_max_timeline_value; end
        if (values[0]<0) then values[1]=values[1]-values[0];values[0]=0; end
    end

    if (hovered) then ig.SetMouseCursor(ig.lib.ImGuiMouseCursor_Hand) end

    ig.NextColumn();
    return changed;
end


function M.EndTimeline( num_vertical_grid_lines, current_time, timeline_running_color)    
    local row_height = ig.GetTextLineHeightWithSpacing();

    ig.NextColumn();

    local win = ig.GetCurrentWindow();

    local columnOffset = ig.GetColumnOffset(1);
    local columnWidth = ig.GetColumnWidth(1)-ig.GetStyle().ScrollbarSize;
    local s_timeline_time_offset = s_ptimeline_offset_and_scale~=nil and s_ptimeline_offset_and_scale.x or 0;
    local s_timeline_time_scale = s_ptimeline_offset_and_scale~=nil and s_ptimeline_offset_and_scale.y or 1;
    local columnWidthScaled = columnWidth*s_timeline_time_scale;
    local columnWidthOffsetScaled = columnWidthScaled * s_timeline_time_offset;
    local horizontal_interval = columnWidth / num_vertical_grid_lines;

    local color = ig.ColorConvertFloat4ToU32(ig.GetStyle().Colors[ig.lib.ImGuiCol_Button]);
    local line_color = ig.ColorConvertFloat4ToU32(ig.GetStyle().Colors[ig.lib.ImGuiCol_Border]);
    local text_color = ig.ColorConvertFloat4ToU32(ig.GetStyle().Colors[ig.lib.ImGuiCol_Text]);
    local moving_line_color = ig.ColorConvertFloat4ToU32(ig.GetStyle().Colors[ig.lib.ImGuiCol_SeparatorActive]);
    local rounding = ig.GetStyle().ScrollbarRounding;
    local startY = ig.GetWindowHeight() + win.Pos.y;

    -- Draw black vertical lines (inside scrolling area)
    for i=1,num_vertical_grid_lines do
        local a = ig.GetWindowContentRegionMin() + win.Pos;
        a.x = a.x + s_timeline_time_scale * i * horizontal_interval + columnOffset - columnWidthOffsetScaled;
        win.DrawList:AddLine(a, ig.ImVec2(a.x,startY), line_color);
    end

    -- Draw moving vertical line
    if (current_time>0 and current_time<s_max_timeline_value)	then
        local a = ig.GetWindowContentRegionMin() + win.Pos;
        a.x = a.x + columnWidthScaled*(current_time/s_max_timeline_value)+columnOffset-columnWidthOffsetScaled;
        win.DrawList:AddLine(a, ig.ImVec2(a.x,startY), moving_line_color,3);
    end

    ig.Columns(1);
    ig.PopStyleColor();

    ig.EndChild();
    local isChildWindowHovered = s_ptimeline_offset_and_scale~=nil and ig.IsItemHovered() or false;

    -- Draw bottom axis ribbon (outside scrolling region)
    win = ig.GetCurrentWindow();
    local startx = ig.GetCursorScreenPos().x + columnOffset;
    local endy = ig.GetCursorScreenPos().y+row_height;--GetWindowContentRegionMax().y + win->Pos.y;
    local start = ig.ImVec2(startx,ig.GetCursorScreenPos().y);
    local endp = ig.ImVec2(startx+columnWidth,endy);--start.y+row_height);
    local maxx = start.x+columnWidthScaled-columnWidthOffsetScaled;
    if (maxx<endp.x) then endp.x = maxx end
    if (current_time<=0) then win.DrawList:AddRectFilled(start, endp, color, rounding)
    elseif (current_time>s_max_timeline_value) then win.DrawList:AddRectFilled(start, endp, timeline_running_color, rounding);
    else 
        local median = ig.ImVec2(start.x+columnWidthScaled*(current_time/s_max_timeline_value)-columnWidthOffsetScaled,endp.y);
        if (median.x<startx) then median.x=startx;
        else 
            if (median.x>startx+columnWidth) then median.x=startx+columnWidth; end
            win.DrawList:AddRectFilled(start, median, timeline_running_color, rounding,ig.lib.ImDrawFlags_RoundCornersLeft);
        end
        median.y=start.y;
        if (median.x<startx+columnWidth) then
            win.DrawList:AddRectFilled(median, endp, color, rounding,ig.lib.ImDrawFlags_RoundCornersRight);
            if (median.x>startx) then win.DrawList:AddLine(median, ig.ImVec2(median.x,endp.y), moving_line_color,3); end
        end
    end

    local tmp = ffi.new("char[?]",256);
    for i = 0,num_vertical_grid_lines-1 do
        local a = ig.ImVec2(start);
        a.x = start.x + s_timeline_time_scale * i * horizontal_interval - columnWidthOffsetScaled;
        --if (a.x < startx or a.x >= startx+columnWidth) continue;
        if (a.x >= startx and a.x < startx+columnWidth) then
          ig.ImFormatString(tmp, ffi.sizeof(tmp), "%.2f", i * s_max_timeline_value / num_vertical_grid_lines);
          win.DrawList:AddText(a, text_color, tmp);
        end
    end
    ig.SetCursorPosY(ig.GetCursorPosY()+row_height);
	ig.Dummy(ig.ImVec2(0,0))

    -- zoom and pan
    if (s_ptimeline_offset_and_scale~=nil)   then
        local iog = ig.GetIO();
        if (isChildWindowHovered and iog.KeyCtrl) then
            if (ig.IsMouseDragging(1)) then
                -- pan
                s_ptimeline_offset_and_scale.x=s_ptimeline_offset_and_scale.x-(iog.MouseDelta.x/columnWidthScaled);
                if (s_ptimeline_offset_and_scale.x>1) then s_ptimeline_offset_and_scale.x=1;
                elseif (s_ptimeline_offset_and_scale.x<0) then s_ptimeline_offset_and_scale.x=0; end
            elseif (iog.MouseReleased[2]) then
                -- reset
                s_ptimeline_offset_and_scale.x=0;
                s_ptimeline_offset_and_scale.y=1;
            end
            if (iog.MouseWheel~=0) then
                -- zoom
                s_ptimeline_offset_and_scale.y=s_ptimeline_offset_and_scale.y*((iog.MouseWheel>0) and 1.05 or 0.95);
                if (s_ptimeline_offset_and_scale.y<0.25) then s_ptimeline_offset_and_scale.y=0.25;
                elseif (s_ptimeline_offset_and_scale.y>4.) then s_ptimeline_offset_and_scale.y=4; end
            end
        end
    end
end


return M
end

return loader
