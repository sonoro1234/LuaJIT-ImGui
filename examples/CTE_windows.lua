local igwin = require"imgui.window"
local win = igwin:SDL(800,600, "ColorTextEditor",{vsync=true,use_imgui_viewport=true})
--local win = igwin:GLFW(800,600, "ColorTextEditor",{vsync=true})

local CTE = require"libs.CTEwindow"(win.ig)

local ctew = CTE.CTEwindow([[../cimCTE/cimCTE.cpp]])
local markers =	win.ig.ErrorMarkers()
markers:insert( 6, "Example error here:\nInclude file not found: \"TextEditor.h\"")
markers:insert( 41, "Another example error")
ctew.editor:SetErrorMarkers( markers)

local ctew2 = CTE.CTEwindow("CTE_sample.lua")

function win:draw(ig)
	ctew:Render()
	ctew2:Render()
end

win:start()