local igwin = require"imgui.window"
--local win = igwin:SDL(800,600, "ColorTextEditor",{vsync=true})
local win = igwin:GLFW(800,600, "ColorTextEditor",{vsync=true})


local ffi = require"ffi"
local lib = win.ig.lib

local langNames = {[0]="None", "Cpp", "C", "Cs", "Python", "Lua", "Json", "Sql", "AngelScript", "Glsl", "Hlsl"}
local editor = lib.TextEditor_TextEditor()

lib.TextEditor_SetLanguageDefinition(editor,lib.Cpp);


local fileN = [[../cimCTE/cimCTE.cpp]]
--local fileN = [[C:\LuaGL\gitsources\anima\LuaJIT-ImGui\cimCTE\ImGuiColorTextEdit\TextEditor.cpp]]
-- local fileN = [[CTE_sample.lua]]
local file,err = io.open(fileN,"r")
assert(file,err)
local strtext = file:read"*a"
file:close()
lib.TextEditor_SetText(editor, strtext)

local function toint(x) return ffi.new("int",x) end
local mLine = ffi.new("int[?]",1)
local mColumn = ffi.new("int[?]",1)
function win:draw(ig)
	local cpos = ig.lib.TextEditor_GetCursorPosition(editor,mLine,mColumn)
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
				local ro = ffi.new("bool[?]",1,ig.lib.TextEditor_IsReadOnlyEnabled(editor));
				if (ig.MenuItem("Read-only mode", nil, ro)) then
					ig.lib.TextEditor_SetReadOnlyEnabled(editor,ro[0])
				end
				ig.Separator();

				if (ig.MenuItem("Undo", "ALT-Backspace", nil, not ro[0] and ig.lib.TextEditor_CanUndo(editor))) then
					ig.lib.TextEditor_Undo(editor,1)
				end
				if (ig.MenuItem("Redo", "Ctrl-Y", nil,not ro[0] and ig.lib.TextEditor_CanRedo(editor)))
				then
					ig.lib.TextEditor_Redo(editor,1);
				end
				ig.Separator();

				if (ig.MenuItem("Copy", "Ctrl-C", nil, ig.lib.TextEditor_AnyCursorHasSelection(editor))) then
					ig.lib.TextEditor_Copy(editor);
				end
				if (ig.MenuItem("Cut", "Ctrl-X", nil, not ro[0] and ig.lib.TextEditor_AnyCursorHasSelection(editor))) then
					ig.lib.TextEditor_Cut(editor);
				end
				if (ig.MenuItem("Paste", "Ctrl-V", nil, not ro[0] and ig.GetClipboardText() ~= nil)) then
					ig.lib.TextEditor_Paste(editor);
				end
				ig.Separator();

				if (ig.MenuItem("Select all", nil, nil)) then
					ig.lib.TextEditor_SelectAll(editor)
				end
				ig.EndMenu();
			end

			if (ig.BeginMenu("View")) then
			
				if (ig.MenuItem("Dark palette")) then
					ig.lib.TextEditor_SetPalette(editor,ig.lib.Dark);
				end
				if (ig.MenuItem("Light palette")) then
					ig.lib.TextEditor_SetPalette(editor,ig.lib.Light);
				end
				if (ig.MenuItem("Mariana palette")) then
					ig.lib.TextEditor_SetPalette(editor,ig.lib.Mariana);
				end
				if (ig.MenuItem("Retro blue palette")) then
					ig.lib.TextEditor_SetPalette(editor,ig.lib.RetroBlue);
				end
				ig.EndMenu()
			end
			ig.EndMenuBar();
		end
		
		ig.Text("%6d/%-6d %6d lines  | %s | %s | %s | %s", toint(mLine[0] + 1), toint(mColumn[0] + 1), toint(ig.lib.TextEditor_GetLineCount(editor)),
		ig.lib.TextEditor_IsOverwriteEnabled(editor) and "Ovr" or "Ins",
		ig.lib.TextEditor_CanUndo(editor) and "*" or " ",
		langNames[ig.lib.TextEditor_GetLanguageDefinition(editor)],fileN)
		
		ig.lib.TextEditor_Render(editor, "texteditor",false,ig.ImVec2(),false)
	ig.End()

end

win:start()