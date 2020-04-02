
local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "dial")
local win = igwin:GLFW(800,400, "dial")

--this will run outside of imgui NewFrame-Render
local function ChangeFont(font,fontsize)
	local ig = win.ig
	local ffi = require"ffi"
	
	local FontsAt = ig.GetIO().Fonts
	------destroy old
	FontsAt:Clear()
	ig.lib.ImGui_ImplOpenGL3_DestroyFontsTexture()
	
	------reconstruct
	--load default
	FontsAt:AddFontDefault()
	
	--load extra font
	local fnt_cfg = ig.ImFontConfig()
	fnt_cfg.PixelSnapH = true
	--fnt_cfg.MergeMode = true
	fnt_cfg.OversampleH = 1
	
	local ranges = FontsAt:GetGlyphRangesCyrillic()
	--local ranges = FontsAt:GetGlyphRangesChineseFull() 
	--local ranges = ffi.new("ImWchar[3]",{0xf000,0xf0a7,0}) --fontawesome
	
	print("ranges",ranges)
	
	local theFONT= FontsAt:AddFontFromFileTTF(font, fontsize, fnt_cfg,ranges)
	assert(theFONT ~= nil)
	
	--regenerate and set extra as default
	ig.lib.ImGui_ImplOpenGL3_CreateFontsTexture()
	ig.GetIO().FontDefault = theFONT
	
	--post info
	local Fonts = FontsAt.Fonts
	print("number of fonts",Fonts.Size)
	for i=0,Fonts.Size-1 do
		print(i,ffi.string(Fonts.Data[i]:GetDebugName()),Fonts.Data[i].ConfigData)
	end
end


local gui = require"filebrowser"(win.ig)

local ffi = require"ffi"
local fontsize = ffi.new("float[1]",13)
local fontscale = ffi.new("float[1]",1)
local buffer = ffi.new("unsigned char[256]",{0xef,0x82,0xa6,0}) 
local str = ffi.string(buffer)
local init_dir = jit.os=="Windows" and [[c:/windows/Fonts]] or ""
--init_dir = [[c:/anima/lua/anima/fonts]]
local fB = gui.FileBrowser(nil,{curr_dir=init_dir,pattern=[[%.ttf$]]},function(f)
	win.preimgui = function() ChangeFont(f,fontsize[0]);win.preimgui=nil end
end)

function win:draw(ig)
	if ig.Button("Load") then
		fB.open()
	end
	ig.DragFloat("fontsize",fontsize,nil,5,20)
	ig.DragFloat("font scale",fontscale,0.05,0.1,2)
	ig.GetIO().FontGlobalScale = fontscale[0]
	fB.draw()
	ig.InputText("test",buffer,256,0)
	ig.Text(str)
	ig.ShowDemoWindow()
end

win:start()