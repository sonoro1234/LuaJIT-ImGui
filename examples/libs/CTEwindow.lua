local ig
local ffi = require"ffi"
------------------- LuaCombo
local function LuaCombo(label,strs,action)
    action = action or function() end
    strs = strs or {"none"}
    local combo = {}
    local strings 
    combo.currItem = ffi.new("int[?]",1)
    local Items, anchors
    function combo:set(strs, ini)
        anchors = {}
        strings = strs
        self.currItem[0] = ini or 0
        Items = ffi.new("const char*[?]",#strs)
        for i = 0,#strs-1  do
            anchors[#anchors+1] = ffi.new("const char*",strs[i+1])
            Items[i] = anchors[#anchors]
        end
        action(ffi.string(Items[self.currItem[0]]),self.currItem[0])
    end
    function combo:set_index(ind)
        self.currItem[0] = ind or 0
        action(ffi.string(Items[self.currItem[0]]),self.currItem[0])
    end
    combo:set(strs)
    function combo:draw()
        if ig.Combo(label,self.currItem,Items,#strings,-1) then
            action(ffi.string(Items[self.currItem[0]]),self.currItem[0])
        end
    end
    function combo:get()
        return ffi.string(Items[self.currItem[0]]),self.currItem[0]
    end
    return combo
end
--local Lang_combo = LuaCombo("Lang",{"CPP","Lua","HLSL","GLSL","C","SQL","AngelScript"},function(a,b) print(a,b) end)
local langNames = {"None", "Cpp", "C", "Cs", "Python", "Lua", "Json", "Sql", "AngelScript", "Glsl", "Hlsl"}
local function toint(x) return ffi.new("int",x) end
local mLine = ffi.new("int[?]",1)
local mColumn = ffi.new("int[?]",1)
local function Render(self)
	local editor = self.editor
	editor:GetCursorPosition(mLine, mColumn)
	
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
					editor:SelectAll();
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
	
	ig.BeginChild(self.ID)--, nil, ig.lib.ImGuiWindowFlags_HorizontalScrollbar + ig.lib.ImGuiWindowFlags_MenuBar);
		--ig.SetWindowSize(ig.ImVec2(800, 600), ig.lib.ImGuiCond_FirstUseEver);
	
		ig.Text("%6d/%-6d %6d lines  | %s | %s | %s | %s", toint(mLine[0] + 1), toint(mColumn[0] + 1), toint(editor:GetLineCount()),
		editor:IsOverwriteEnabled() and "Ovr" or "Ins",
		editor:CanUndo() and "*" or " ",
		langNames[tonumber(editor:GetLanguageDefinition())],
		self.file_name)
		ig.SameLine()
		self.lang_combo:draw()
		editor:Render("texteditor")
		--ig.lib.TextEditor_ImGuiDebugPanel(editor,"deb##"..self.ID)
	ig.EndChild()
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

	W.lang_combo = LuaCombo("Lang",langNames,
				function(name,ind) 
					print(name,ind)
					editor:SetLanguageDefinition(ind)
				end)
	if ext == "cpp" or ext == "hpp" then
		W.lang_combo:set_index(1)
	elseif ext == "lua" then
		W.lang_combo:set_index(5)
	else
		W.lang_combo:set_index(0)
		print"unknown language"
	end
	W.Render = Render
	W.ID = "CTE##"..tostring(W)
	return W
end

return function(iglib)
	ig = iglib
	return {CTEwindow=CTEwindow}
end

