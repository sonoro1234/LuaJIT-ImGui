local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "widgets")
local win = igwin:GLFW(800,400, "widgets")
local ig = win.ig


-- Return >= 0 on mouse release
-- Optional int* p_selected display and update a currently selected item
--(const ImVec2& center, const char* popup_id, const char** items, int items_count, int* p_selected)
local function PiePopupSelectMenu(center, popup_id, items, items_count,  p_selected)
	local IM_PI = math.pi
    local ret = -1;

    -- FIXME: Missing a call to query if Popup is open so we can move the PushStyleColor inside the BeginPopupBlock (e.g. IsPopupOpen() in imgui.cpp)
    -- FIXME: Our PathFill function only handle convex polygons, so we can't have items spanning an arc too large else inner concave edge artifact is too visible, hence the ImMax(7,items_count)
    ig.PushStyleColor(ig.lib.ImGuiCol_WindowBg, ig.ImVec4(0,0,0,0));
    ig.PushStyleColor(ig.lib.ImGuiCol_Border, ig.ImVec4(0,0,0,0));
    if (ig.BeginPopup(popup_id))
    then
        local drag_delta = ig.ImVec2(ig.GetIO().MousePos.x - center.x, ig.GetIO().MousePos.y - center.y);
        local drag_dist2 = drag_delta.x*drag_delta.x + drag_delta.y*drag_delta.y;

        local style = ig.GetStyle();
        local RADIUS_MIN = 30.0;
        local RADIUS_MAX = 120.0;
        local RADIUS_INTERACT_MIN = 20.0;
        local ITEMS_MIN = 6;

        local draw_list = ig.GetWindowDrawList();
        --ImGuiWindow* window = ig.GetCurrentWindow();
        draw_list:PushClipRectFullScreen();
        draw_list:PathArcTo(center, (RADIUS_MIN + RADIUS_MAX)*0.5, 0.0, IM_PI*2.0*0.99, 32);   -- FIXME: 0.99 look like full arc with closed thick stroke has a bug now
        draw_list:PathStroke(ig.U32(0,0,0), true, RADIUS_MAX - RADIUS_MIN);

        local item_arc_span = 2*IM_PI / math.max(ITEMS_MIN, items_count);
        local drag_angle = math.atan2(drag_delta.y, drag_delta.x);
        if (drag_angle < -0.5*item_arc_span) then
            drag_angle = drag_angle + 2.0*IM_PI; end
        --ig.Text("%f", drag_angle);    // [Debug]

        local item_hovered = -1;
        for item_n=0,items_count-1 do --(int item_n = 0; item_n < items_count; item_n++)
            local item_label = items[item_n];
            local item_ang_min = item_arc_span * (item_n+0.02) - item_arc_span*0.5; -- FIXME: Could calculate padding angle based on how many pixels they'll take
            local item_ang_max = item_arc_span * (item_n+0.98) - item_arc_span*0.5;

            local hovered = false;
            if (drag_dist2 >= RADIUS_INTERACT_MIN*RADIUS_INTERACT_MIN)
            then
                if (drag_angle >= item_ang_min and drag_angle < item_ang_max) then
                    hovered = true; end
            end
            local selected = p_selected and (p_selected[0] == item_n);

            local arc_segments = math.floor(32 * item_arc_span / (2*IM_PI)) + 1;
            draw_list:PathArcTo(center, RADIUS_MAX - style.ItemInnerSpacing.x, item_ang_min, item_ang_max, arc_segments);
            draw_list:PathArcTo(center, RADIUS_MIN + style.ItemInnerSpacing.x, item_ang_max, item_ang_min, arc_segments);
            --draw_list->PathFill(window->Color(hovered ? ImGuiCol_HeaderHovered : ImGuiCol_FrameBg));
            draw_list:PathFillConvex(hovered and ig.U32(100/255,100/255,150/255) or (selected and ig.U32(120/255,120/255,140/255) or ig.U32(70/255,70/255,70/255)));

            local text_size = ig.GetFont():CalcTextSizeA(ig.GetFontSize(), ig.FLT_MAX, 0.0, item_label);
            local text_pos = ig.ImVec2(
                center.x + math.cos((item_ang_min + item_ang_max) * 0.5) * (RADIUS_MIN + RADIUS_MAX) * 0.5 - text_size.x * 0.5,
                center.y + math.sin((item_ang_min + item_ang_max) * 0.5) * (RADIUS_MIN + RADIUS_MAX) * 0.5 - text_size.y * 0.5);
            draw_list:AddText(text_pos, ig.U32(1,1,1), item_label);

            if (hovered) then
                item_hovered = item_n; end
        end
        draw_list:PopClipRect();

        if (ig.IsMouseReleased(0))
        then
            ig.CloseCurrentPopup();
            ret = item_hovered;
            if (p_selected) then
                p_selected[0] = item_hovered; end
        end
        ig.EndPopup();
    end
    ig.PopStyleColor(2);
    return ret;
end


local ffi = require"ffi"
local itchars = {}
for i,v in ipairs{ "Orange", "Blue", "Purple", "Gray", "Yellow", "Las Vegas" } do
	itchars[i] = ffi.new("const char*",v)
end
local items_count = #itchars
local items = ffi.new("const char*[?]",#itchars,itchars)

local selected = ffi.new("int[1]",-1)

function win:draw(ig)
	ig.Button(selected[0] >= 0 and items[selected[0]] or "Menu")--, ig.ImVec2(50,50));
	if (ig.IsItemActive())          -- Don't wait for button release to activate the pie menu
	then
		ig.OpenPopup("##piepopup");
	end

	local pie_menu_center = ig.GetIO().MouseClickedPos[0];
	local n = PiePopupSelectMenu(pie_menu_center, "##piepopup", items, items_count, selected);
	if (n >= 0) then
		print("returned", n);
	end
end

win:start()