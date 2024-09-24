local igwin = require"imgui.window"
local win = igwin:SDL(800,600, "ColorTextEditor",{vsync=true,use_imgui_viewport=true})
--local win = igwin:GLFW(800,600, "ColorTextEditor",{vsync=true})

local CTE = require"libs.CTEwindow"(win.ig)

local ctew = CTE.CTEwindow([[../cimCTE/cimCTE.cpp]])
local ctew2 = CTE.CTEwindow("CTE_sample.lua")

function win:draw(ig)
	ctew:Render()
	ctew2:Render()
end

win:start()