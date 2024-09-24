local igwin = require"imgui.window"
--local win = igwin:SDL(800,600, "ColorTextEditor",{vsync=true})
local win = igwin:GLFW(800,600, "ColorTextEditor",{vsync=true})

local ffi = require"ffi"

local ig = win.ig
local langNames = {[0]="None", "Cpp", "C", "Cs", "Python", "Lua", "Json", "Sql", "AngelScript", "Glsl", "Hlsl"}
local editor = ig.TextEditor()

editor:SetLanguageDefinition(ig.lib.Cpp)


local fileN = [[../cimCTE/cimCTE.cpp]]
--local fileN = [[C:\LuaGL\gitsources\anima\LuaJIT-ImGui\cimCTE\ImGuiColorTextEdit\TextEditor.cpp]]
-- local fileN = [[CTE_sample.lua]]
local file,err = io.open(fileN,"r")
assert(file,err)
local strtext = file:read"*a"
file:close()
editor:SetText( strtext)

local function toint(x) return ffi.new("int",x) end
local mLine = ffi.new("int[?]",1)
local mColumn = ffi.new("int[?]",1)
function win:draw(ig)
	editor:GetCursorPosition(mLine, mColumn)
	ig.Begin("Text Editor Demo", nil, ig.lib.ImGuiWindowFlags_HorizontalScrollbar + ig.lib.ImGuiWindowFlags_MenuBar);
		ig.SetWindowSize(ig.ImVec2(800, 600), ig.lib.ImGuiCond_FirstUseEver);
		if (ig.BeginMenuBar())
		then
			if (ig.BeginMenu("File"))
			then
				if (ig.MenuItem("Save"))
				then
					--auto textToSave = editor.GetText();
					--/// save text....
				end
				if (ig.MenuItem("Quit", "Alt-F4"))
				then
					print("quit")--break;
				end
				ig.EndMenu();
			end
	
			if (ig.BeginMenu("Edit"))
			then
				local ro = ffi.new("bool[?]",1,editor:IsReadOnlyEnabled());
				if (ig.MenuItem("Read-only mode", nil, ro)) then
					editor:SetReadOnlyEnabled(ro[0])
				end
				ig.Separator();

				if (ig.MenuItem("Undo", "ALT-Backspace", nil, not ro[0] and editor:CanUndo())) then
					editor:Undo()
				end
				if (ig.MenuItem("Redo", "Ctrl-Y", nil,not ro[0] and editor:CanRedo()))
				then
					editor:Redo();
				end
				ig.Separator();

				if (ig.MenuItem("Copy", "Ctrl-C", nil, editor:AnyCursorHasSelection())) then
					editor:Copy();
				end
				if (ig.MenuItem("Cut", "Ctrl-X", nil, not ro[0] and editor:AnyCursorHasSelection())) then
					editor:Cut();
				end
				if (ig.MenuItem("Paste", "Ctrl-V", nil, not ro[0] and ig.GetClipboardText() ~= nil)) then
					editor:Paste();
				end
				ig.Separator();

				if (ig.MenuItem("Select all", nil, nil)) then
					editor:SelectAll()
				end
				ig.EndMenu();
			end

			if (ig.BeginMenu("View")) then
			
				if (ig.MenuItem("Dark palette")) then
					editor:SetPalette(ig.lib.Dark);
				end
				if (ig.MenuItem("Light palette")) then
					editor:SetPalette(ig.lib.Light);
				end
				if (ig.MenuItem("Mariana palette")) then
					editor:SetPalette(ig.lib.Mariana);
				end
				if (ig.MenuItem("Retro blue palette")) then
					editor:SetPalette(ig.lib.RetroBlue);
				end
				ig.EndMenu()
			end
			ig.EndMenuBar();
		end
		
		ig.Text("%6d/%-6d %6d lines  | %s | %s | %s | %s", toint(mLine[0] + 1), toint(mColumn[0] + 1), toint(editor:GetLineCount()),
		editor:IsOverwriteEnabled() and "Ovr" or "Ins",
		editor:CanUndo() and "*" or " ",
		langNames[tonumber(editor:GetLanguageDefinition())],
		fileN)
		
		editor:Render("texteditor")
	ig.End()

end

win:start()