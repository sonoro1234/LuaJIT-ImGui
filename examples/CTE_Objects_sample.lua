local igwin = require"imgui.window"
--local win = igwin:SDL(800,600, "ColorTextEditor",{vsync=true})
local win = igwin:GLFW(800,600, "ColorTextEditor",{vsync=true})


local ffi = require"ffi"
ffi.cdef[[
typedef struct LanguageDefinition LangDef;
typedef struct TextEditor TextEditor;
typedef struct Coordinates Coordinates;
struct Coordinates
{
    int mLine, mColumn;
};
typedef enum 
	{
		Normal,
		Word,
		Line
	} SelectionMode;
typedef struct ErrorMarkers ErrorMarkers;
 TextEditor* TextEditor_TextEditor();
 void TextEditor_destroy(TextEditor * self);
 void TextEditor_SetLangDef(TextEditor* self, LangDef* lang);
 void TextEditor_SetText(TextEditor* self, const char* text);
 Coordinates* TextEditor_GetCursorPosition(TextEditor* self);
 void TextEditor_Render(TextEditor* self, const char *title);
LangDef* TextEditor_GetLanguageDefinition(TextEditor* ed);
 LangDef* LanguageDefinition_CPlusPlus();
 LangDef* LanguageDefinition_Lua();
 const char* LanguageDefinition_getName(LangDef* self);
 void LanguageDefinition_PIdentifiers_insert(LangDef *self, const char* ppnames, const char* ppvalues);
 void LanguageDefinition_Identifiers_insert(LangDef *self, const char* identifier, const char* idcl);
 ErrorMarkers* TextEditor_ErrorMarkers();
void ErrorMarkers_destroy(ErrorMarkers *mark);
void ErrorMarkers_insert(ErrorMarkers *mark, int n,const char* text);
void TextEditor_SetErrorMarkers(TextEditor* ed, ErrorMarkers* mark);
int TextEditor_GetTotalLines(TextEditor* ed);
bool TextEditor_IsOverwrite(TextEditor* ed);
bool TextEditor_CanUndo(TextEditor* ed);
bool TextEditor_CanRedo(TextEditor* ed);
bool TextEditor_IsReadOnly(TextEditor* ed);
void TextEditor_SetReadOnly(TextEditor* ed,bool aValue);
void TextEditor_Undo(TextEditor* ed, int aSteps);
void TextEditor_Redo(TextEditor* ed, int aSteps);
bool TextEditor_HasSelection(TextEditor* ed);
void TextEditor_Copy(TextEditor* ed);
void TextEditor_Cut(TextEditor* ed);
void TextEditor_Paste(TextEditor* ed);
void TextEditor_Delete(TextEditor* ed);
Coordinates* TextEditor_Coordinates_Nil();
Coordinates* TextEditor_Coordinates_Int(int aLine, int aColumn);
void TextEditor_Coordinates_destroy(Coordinates * co);
void TextEditor_SetSelection(TextEditor* ed, Coordinates* aStart, Coordinates* aEnd, SelectionMode sem);
void TextEditor_SetPalette_DarkPalette(TextEditor* ed);
void TextEditor_SetPalette_LightPalette(TextEditor* ed);
void TextEditor_SetPalette_RetroBluePalette(TextEditor* ed);
]]

local lib = win.ig.lib
-----------------Lua objects for TextEditor
local M = {}
local TextEditor = {}
TextEditor.__index = TextEditor
function TextEditor.__new(ctype)
    local ptr = lib.TextEditor_TextEditor()
    ffi.gc(ptr,lib.TextEditor_destroy)
    return ptr
end
function TextEditor:SetLangDef(lang)
	lib.TextEditor_SetLangDef(self,lang);
end
function TextEditor:SetText(text)
	lib.TextEditor_SetText(self,text);
end
function TextEditor:GetCursorPosition()
	return lib.TextEditor_GetCursorPosition(self);
end
function TextEditor:Render(title)
	lib.TextEditor_Render(self,title);
end
function TextEditor:GetLanguageDefinition()
	return lib.TextEditor_GetLanguageDefinition(self);
end
function TextEditor:SetErrorMarkers(mark)
	lib.TextEditor_SetErrorMarkers(self,mark);
end
function TextEditor:GetTotalLines()
	return lib.TextEditor_GetTotalLines(self);
end
function TextEditor:IsOverwrite()
	return lib.TextEditor_IsOverwrite(self);
end
function TextEditor:CanUndo()
	return lib.TextEditor_CanUndo(self);
end
function TextEditor:CanRedo()
	return lib.TextEditor_CanRedo(self);
end
function TextEditor:IsReadOnly()
	return lib.TextEditor_IsReadOnly(self);
end
function TextEditor:HasSelection()
	return lib.TextEditor_HasSelection(self);
end
function TextEditor:SetSelection(aStart,aEnd,sem)
	lib.TextEditor_SetSelection(self,aStart,aEnd,sem);
end
function TextEditor:SetReadOnly(aValue)
	lib.TextEditor_SetReadOnly(self,aValue);
end
function TextEditor:Undo(aSteps)
	aSteps = aSteps or 1
	lib.TextEditor_Undo(self,aSteps);
end
function TextEditor:Redo(aSteps)
	aSteps = aSteps or 1
	lib.TextEditor_Redo(self,aSteps);
end
function TextEditor:Copy()
	lib.TextEditor_Copy(self);
end
function TextEditor:Cut()
	lib.TextEditor_Cut(self);
end
function TextEditor:Paste()
	lib.TextEditor_Paste(self);
end
function TextEditor:Delete()
	lib.TextEditor_Delete(self);
end
function TextEditor:DarkPalette()
	lib.TextEditor_SetPalette_DarkPalette(self);
end
function TextEditor:LightPalette()
	lib.TextEditor_SetPalette_LightPalette(self);
end
function TextEditor:RetroBluePalette()
	lib.TextEditor_SetPalette_RetroBluePalette(self);
end
TextEditor = ffi.metatype("TextEditor",TextEditor)
M.TextEditor = TextEditor

local LangDef = {}
function M.LangDef_CPP()
	return lib.LanguageDefinition_CPlusPlus()
end
function M.LangDef_Lua()
	return lib.LanguageDefinition_Lua()
end
function LangDef:getName()
	return lib.LanguageDefinition_getName(self)
end
function LangDef:Pid_insert(ppnames, ppvalues)
	lib.LanguageDefinition_PIdentifiers_insert(self,ppnames,ppvalues)
end
function LangDef:id_insert(identifier,idcl)
	lib.LanguageDefinition_Identifiers_insert(self,identifier,idcl)
end
LangDef.__index = LangDef
M.LangDef = ffi.metatype("LangDef",LangDef)

local ErrorMarkers = {}
function ErrorMarkers.__new(ctype)
	local ptr = lib.TextEditor_ErrorMarkers()
    ffi.gc(ptr,lib.ErrorMarkers_destroy)
    return ptr
end
function ErrorMarkers:insert(n, text)
	lib.ErrorMarkers_insert(self,n,text)
end
ErrorMarkers.__index = ErrorMarkers
M.ErrorMarkers = ffi.metatype("ErrorMarkers",ErrorMarkers)

local Coordinates = {}
function Coordinates.Coordinates_Nil()
	local ptr = lib.TextEditor_Coordinates_Nil()
    ffi.gc(ptr,lib.TextEditor_Coordinates_destroy)
    return ptr
end
function Coordinates.Coordinates_Int(aLine,aColumn)
	local ptr = lib.TextEditor_Coordinates_Int(aLine,aColumn)
    ffi.gc(ptr,lib.TextEditor_Coordinates_destroy)
    return ptr
end
function Coordinates.__new(ctype, a1,a2)
	if a1==nil then return Coordinates.Coordinates_Nil() 
	else 
		return Coordinates.Coordinates_Int(a1,a2)
	end
end
Coordinates.__index = Coordinates
M.Coordinates = ffi.metatype("Coordinates",Coordinates)
-------------------------------------------------------------------
local editor = M.TextEditor()
local lang = M.LangDef_CPP();
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
local markers =	M.ErrorMarkers()
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
					editor:SetSelection(M.Coordinates(), M.Coordinates(editor:GetTotalLines(), 0),ig.lib.Normal);
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
		--ig.lib.LanguageDefinition_getName(ig.lib.TextEditor_GetLanguageDefinition(editor)),
		editor:GetLanguageDefinition():getName(),
		fileN)
		
		editor:Render("texteditor")
	ig.End()

end

win:start()