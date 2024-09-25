local igwin = require"imgui.window"
--local win = igwin:SDL(800,600, "ColorTextEditor",{vsync=true,use_imgui_viewport=true})
local win = igwin:GLFW(800,600, "ColorTextEditor",{vsync=true,use_imgui_viewport=true})

local CTE = require"libs.CTEwindow"(win.ig)

local ctew = CTE.CTEwindow([[../cimCTE/cimCTE.cpp]])
local ctew2 = CTE.CTEwindow("CTE_sample.lua")

function win:draw(ig)
	
	ig.Begin("Documents",nil,ig.lib.ImGuiWindowFlags_MenuBar)
	ig.SetWindowSize(ig.ImVec2(800, 600), ig.lib.ImGuiCond_FirstUseEver);
	if (ig.BeginTabBar("##Tabs", ig.lib.ImGuiTabBarFlags_None)) then
        if (ig.BeginTabItem(ctew.file_name)) then
            ctew:Render()
            ig.EndTabItem();
        end
        if (ig.BeginTabItem(ctew2.file_name)) then
            ctew2:Render()
            ig.EndTabItem();
        end
        ig.EndTabBar();
    end
	ig.End()
end

win:start()