local igwin = require"imgui.window"
--local win = igwin:SDL(800,600, "ColorTextEditor",{vsync=true})
local win = igwin:GLFW(800,600, "ColorTextEditor",{vsync=true})


local ffi = require"ffi"
local lib = win.ig.lib
local editor = lib.TextEditor_TextEditor()
local lang = lib.LanguageDefinition_CPlusPlus();
-- set your own known preprocessor symbols...
local ppnames = { "NULL", "PM_REMOVE",
		"ZeroMemory", "DXGI_SWAP_EFFECT_DISCARD", "D3D_FEATURE_LEVEL", "D3D_DRIVER_TYPE_HARDWARE", "WINAPI","D3D11_SDK_VERSION", "assert" };
-- ... and their corresponding values
local ppvalues = { 
		"#define NULL ((void*)0)", 
		"#define PM_REMOVE (0x0001)",
		"Microsoft's own memory zapper function\n(which is a macro actually)\nvoid ZeroMemory(\n\t[in] PVOID  Destination,\n\t[in] SIZE_T Length\n); ", 
		"enum DXGI_SWAP_EFFECT::DXGI_SWAP_EFFECT_DISCARD = 0", 
		"enum D3D_FEATURE_LEVEL", 
		"enum D3D_DRIVER_TYPE::D3D_DRIVER_TYPE_HARDWARE  = ( D3D_DRIVER_TYPE_UNKNOWN + 1 )",
		"#define WINAPI __stdcall",
		"#define D3D11_SDK_VERSION (7)",
		[[ #define assert(expression) (void)(                                                 
            (!!(expression)) ||                                                              
            (_wassert(_CRT_WIDE(#expression), _CRT_WIDE(__FILE__), (unsigned)(__LINE__)), 0) 
         )]]
		};
for i=1,#ppnames do
	lib.LanguageDefinition_PIdentifiers_insert(lang, ppnames[i],ppvalues[i])
end
lib.TextEditor_SetLangDef(editor,lang);
-- error markers
local markers =	lib.TextEditor_ErrorMarkers()
lib.ErrorMarkers_insert(markers, 6, "Example error here:\nInclude file not found: \"TextEditor.h\"")
lib.ErrorMarkers_insert(markers, 41, "Another example error")
lib.TextEditor_SetErrorMarkers(editor, markers)

local fileN = [[../cimCTE/cimCTE.cpp]]
--local fileN = [[C:\LuaGL\gitsources\anima\LuaJIT-ImGui\cimCTE\ImGuiColorTextEdit\TextEditor.cpp]]
-- local lang = lib.LanguageDefinition_Lua();
-- lib.TextEditor_SetLangDef(editor,lang);
-- local fileN = [[CTE_sample.lua]]
local file,err = io.open(fileN,"r")
assert(file,err)
local strtext = file:read"*a"
file:close()
lib.TextEditor_SetText(editor, strtext)

local function toint(x) return ffi.new("int",x) end
function win:draw(ig)
	local cpos = ig.lib.TextEditor_GetCursorPosition(editor)
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
				local ro = ffi.new("bool[?]",1,ig.lib.TextEditor_IsReadOnly(editor));
				if (ig.MenuItem("Read-only mode", nil, ro)) then
					ig.lib.TextEditor_SetReadOnly(editor,ro[0])
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

				if (ig.MenuItem("Copy", "Ctrl-C", nil, ig.lib.TextEditor_HasSelection(editor))) then
					ig.lib.TextEditor_Copy(editor);
				end
				if (ig.MenuItem("Cut", "Ctrl-X", nil, not ro[0] and ig.lib.TextEditor_HasSelection(editor))) then
					ig.lib.TextEditor_Cut(editor);
				end
				if (ig.MenuItem("Delete", "Del", nil, not ro[0] and ig.lib.TextEditor_HasSelection(editor))) then
					ig.lib.TextEditor_Delete(editor);
				end
				if (ig.MenuItem("Paste", "Ctrl-V", nil, not ro[0] and ig.GetClipboardText() ~= nil)) then
					ig.lib.TextEditor_Paste(editor);
				end
				ig.Separator();

				if (ig.MenuItem("Select all", nil, nil)) then
					ig.lib.TextEditor_SetSelection(editor, ig.lib.TextEditor_Coordinates_Nil(), ig.lib.TextEditor_Coordinates_Int(ig.lib.TextEditor_GetTotalLines(editor), 0),ig.lib.Normal);
				end
				ig.EndMenu();
			end

			if (ig.BeginMenu("View")) then
			
				if (ig.MenuItem("Dark palette")) then
					ig.lib.TextEditor_SetPalette_DarkPalette(editor);
				end
				if (ig.MenuItem("Light palette")) then
					ig.lib.TextEditor_SetPalette_LightPalette(editor);
				end
				if (ig.MenuItem("Retro blue palette")) then
					ig.lib.TextEditor_SetPalette_RetroBluePalette(editor);
				end
				ig.EndMenu()
			end
			ig.EndMenuBar();
		end
		
		ig.Text("%6d/%-6d %6d lines  | %s | %s | %s | %s", toint(cpos.mLine + 1), toint(cpos.mColumn + 1), toint(ig.lib.TextEditor_GetTotalLines(editor)),
		ig.lib.TextEditor_IsOverwrite(editor) and "Ovr" or "Ins",
		ig.lib.TextEditor_CanUndo(editor) and "*" or " ",
		ig.lib.LanguageDefinition_getName(ig.lib.TextEditor_GetLanguageDefinition(editor)),fileN)
		
		ig.lib.TextEditor_Render(editor, "texteditor")
	ig.End()

end

win:start()