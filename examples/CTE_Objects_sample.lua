local igwin = require"imgui.window"
--local win = igwin:SDL(800,600, "ColorTextEditor",{vsync=true})
local win = igwin:GLFW(800,600, "ColorTextEditor",{vsync=true})

local ffi = require"ffi"

local ig = win.ig
local editor = ig.TextEditor()
local lang = ig.LangDef_CPP();
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
	lang:Pid_insert(ppnames[i],ppvalues[i])
end
editor:SetLangDef(lang)
-- error markers
local markers =	ig.ErrorMarkers()
markers:insert( 6, "Example error here:\nInclude file not found: \"TextEditor.h\"")
markers:insert( 41, "Another example error")
editor:SetErrorMarkers( markers)

local fileN = [[../cimCTE/cimCTE.cpp]]
--local fileN = [[C:\LuaGL\gitsources\anima\LuaJIT-ImGui\cimCTE\ImGuiColorTextEdit\TextEditor.cpp]]
-- local lang = lib.LanguageDefinition_Lua();
-- lib.TextEditor_SetLangDef(editor,lang);
-- local fileN = [[CTE_sample.lua]]
local file,err = io.open(fileN,"r")
assert(file,err)
local strtext = file:read"*a"
file:close()
editor:SetText( strtext)

local function toint(x) return ffi.new("int",x) end
function win:draw(ig)
	local cpos = editor:GetCursorPosition()
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
				local ro = ffi.new("bool[?]",1,editor:IsReadOnly());
				if (ig.MenuItem("Read-only mode", nil, ro)) then
					editor:SetReadOnly(ro[0])
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

				if (ig.MenuItem("Copy", "Ctrl-C", nil, editor:HasSelection())) then
					editor:Copy();
				end
				if (ig.MenuItem("Cut", "Ctrl-X", nil, not ro[0] and editor:HasSelection())) then
					editor:Cut();
				end
				if (ig.MenuItem("Delete", "Del", nil, not ro[0] and editor:HasSelection())) then
					editor:Delete();
				end
				if (ig.MenuItem("Paste", "Ctrl-V", nil, not ro[0] and ig.GetClipboardText() ~= nil)) then
					editor:Paste();
				end
				ig.Separator();

				if (ig.MenuItem("Select all", nil, nil)) then
					editor:SetSelection(ig.Coordinates(), ig.Coordinates(editor:GetTotalLines(), 0),ig.lib.Normal);
				end
				ig.EndMenu();
			end

			if (ig.BeginMenu("View")) then
			
				if (ig.MenuItem("Dark palette")) then
					editor:DarkPalette();
				end
				if (ig.MenuItem("Light palette")) then
					editor:LightPalette();
				end
				if (ig.MenuItem("Retro blue palette")) then
					editor:RetroBluePalette();
				end
				ig.EndMenu()
			end
			ig.EndMenuBar();
		end
		
		ig.Text("%6d/%-6d %6d lines  | %s | %s | %s | %s", toint(cpos.mLine + 1), toint(cpos.mColumn + 1), toint(editor:GetTotalLines()),
		editor:IsOverwrite() and "Ovr" or "Ins",
		editor:CanUndo() and "*" or " ",
		editor:GetLanguageDefinition():getName(),
		fileN)
		
		editor:Render("texteditor")
	ig.End()

end

win:start()