local ig
local ffi = require"ffi"
local function toint(x) return ffi.new("int",x) end
local function Render(self)
	local editor = self.editor
	local cpos = editor:GetCursorPosition()
	ig.Begin(self.ID, nil, ig.lib.ImGuiWindowFlags_HorizontalScrollbar + ig.lib.ImGuiWindowFlags_MenuBar);
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
		self.file_name)
		
		editor:Render("texteditor")
	ig.End()
end
local function CTEwindow(file_name)
	local strtext = ""
	local ext = ""
	if file_name then
		local file,err = io.open(file_name,"r")
		assert(file,err)
		strtext = file:read"*a"
		file:close()
		ext = file_name:match("[^%.]+$")
	end

	local W = {file_name = file_name or ""}
	local editor = ig.TextEditor()
	W.editor = editor
	editor:SetText( strtext)
	local lang
	if ext == "cpp" or ext == "hpp" then
		lang = ig.LangDef_CPP();
	elseif ext == "lua" then
		lang = ig.LangDef_Lua()
	else
		print"unknown language"
		lang = ig.LangDef_CPP()
	end
	editor:SetLangDef(lang)
	W.Render = Render
	W.ID = "CTE##"..tostring(W)
	return W
end

return function(iglib)
	ig = iglib
	return {CTEwindow=CTEwindow}
end

