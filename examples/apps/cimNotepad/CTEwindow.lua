

local ig
local ffi = require"ffi"



local langNames = {"None", "Cpp", "C", "Cs", "Python", "Lua", "Json", "Sql", "AngelScript", "Glsl", "Hlsl","Markdown"}
local function toint(x) return ffi.new("int",x) end

local it_cb = ffi.cast("void(*)(const char *)", function(ident)
    if ident ~= nil then
        print(ffi.string(ident))
    end
end)

local function RenderDiff(self)
    ig.OpenPopup("Changes since Opening File##diff");
    local viewport = ig.GetMainViewport();
    local center = viewport:GetCenter();
    ig.SetNextWindowPos(center, ig.lib.ImGuiCond_Appearing, ig.ImVec2(0.5, 0.5));

    if (ig.BeginPopupModal("Changes since Opening File##diff", nil, ig.lib.ImGuiWindowFlags_AlwaysAutoResize)) then
        local diff = self.diff
        diff:Render("diff", viewport.Size * 0.8, true);

        ig.Separator();
        local buttonWidth = 80.0;
        local buttonOffset = ig.GetContentRegionAvail().x - buttonWidth;
        local sideBySide = ffi.new("bool[?]",1)
        sideBySide[0] = diff:GetSideBySideMode();

        if (ig.Checkbox("Show side-by-side", sideBySide)) then
            diff:SetSideBySideMode(sideBySide[0]);
        end

        ig.SameLine();
        ig.Indent(buttonOffset);

        if (ig.Button("OK", ig.ImVec2(buttonWidth, 0.0)) or ig.IsKeyPressed(ig.lib.ImGuiKey_Escape, false)) then
            self.render_diff = false
            ig.CloseCurrentPopup();
        end

        ig.EndPopup();
    end
end
local function showDiff(self)
    self.diff:SetLanguage(self.editor:GetLanguage());
    self.diff:SetText(self.originalText, self.editor:GetText());
    self.render_diff = true
end
local function renderStatusBar(self)
        local editor = self.editor
        local cupos = editor:GetMainCursorPosition()
        local mLine, mColumn = cupos.line, cupos.index
        --local  cursorPos = editor:DocPos2VisPos(editor:GetCurrentCursorPosition());
        ig.Text("%6d/%-6d %6d lines  | %s |", toint(mLine + 1), toint(mColumn + 1), toint(editor:GetLineCount()),
        editor:IsOverwriteEnabled() and "Ovr" or "Ins")
        ig.SameLine()
        local dirty = self:is_dirty() --editor:CanUndo()
        local tcolor = dirty and ig.ImVec4(1,0,0,1) or ig.ImVec4(1,1,1,1)
        ig.TextColored(tcolor," %s | %s ",dirty and "*" or " ", self.shrt_name)
        ig.SameLine()
        self.lang_combo:draw()
end

-- should be global options?
local function renderMenuOptions(self)
        local editor = self.editor
        if (ig.BeginMenu("Options"))  then
            if (ig.BeginMenu("Tab Size"))  then
                local tsiz = editor:GetTabSize()
                if (ig.MenuItem("1",nil,tsiz == 1))  then  editor:SetTabSize(1);  end 
                if (ig.MenuItem("2",nil,tsiz == 2))  then  editor:SetTabSize(2);  end 
                if (ig.MenuItem("4",nil,tsiz == 4))  then  editor:SetTabSize(4);  end 
                if (ig.MenuItem("8",nil,tsiz == 8))  then  editor:SetTabSize(8);  end 
                ig.EndMenu();
             end 

            if (ig.BeginMenu("Line Spacing"))  then 
                local lspc = editor:GetLineSpacing()
                if (ig.MenuItem("1.00", nil, lspc == 1))  then  editor:SetLineSpacing(1.0);  end 
                if (ig.MenuItem("1.25", nil, lspc == 1.25))  then  editor:SetLineSpacing(1.25);  end 
                if (ig.MenuItem("1.50", nil, lspc == 1.5))  then  editor:SetLineSpacing(1.5);  end 
                if (ig.MenuItem("1.75", nil, lspc == 1.75))  then  editor:SetLineSpacing(1.75);  end 
                if (ig.MenuItem("2.00", nil, lspc == 2))  then  editor:SetLineSpacing(2.0);  end 
                ig.EndMenu();
             end 

            if (ig.BeginMenu("MiniMap Columns"))  then 
                local width = ffi.new("int[?]",1,editor:GetMiniMapColumns())
                if (ig.SliderInt("##miniMapColumns", width, 0, 200))  then  editor:SetMiniMapColumns(width[0]);  end 
                ig.EndMenu();
             end 

            ig.Separator();

            local flag = ffi.new("bool[?]",1)
            flag[0] = editor:IsReadOnlyEnabled(); if (ig.MenuItem("Read Only", nullptr, flag))  then  editor:SetReadOnlyEnabled(flag[0]);  end ;
            flag[0] = editor:IsCaretsVisible(); if (ig.MenuItem("Carets Visible", nullptr, flag))  then  editor:SetCaretsVisible(flag[0]);  end ;
            flag[0] = editor:IsOverwriteEnabled(); if (ig.MenuItem("Overwrite", nullptr, flag))  then  editor:SetOverwriteEnabled(flag[0]);  end ;
            flag[0] = editor:IsWordWrapEnabled(); if (ig.MenuItem("Word Wrap", nullptr, flag))  then  editor:SetWordWrapEnabled(flag[0]);  end ;
            flag[0] = editor:IsLineFoldingEnabled(); if (ig.MenuItem("Line Folding", nullptr, flag))  then  editor:SetLineFoldingEnabled(flag[0]);  end ;
            flag[0] = editor:IsShowWhitespacesEnabled(); if (ig.MenuItem("Show Whitespaces", nullptr, flag))  then  editor:SetShowWhitespacesEnabled(flag[0]);  end ;
            flag[0] = editor:IsShowSpacesEnabled(); if (ig.MenuItem("Show Spaces", nullptr, flag))  then  editor:SetShowSpacesEnabled(flag[0]);  end ;
            flag[0] = editor:IsShowTabsEnabled(); if (ig.MenuItem("Show Tabs", nullptr, flag))  then  editor:SetShowTabsEnabled(flag[0]);  end ;
            flag[0] = editor:IsShowLineNumbersEnabled(); if (ig.MenuItem("Show Line Numbers", nullptr, flag))  then  editor:SetShowLineNumbersEnabled(flag[0]);  end ;
            flag[0] = editor:IsShowingMatchingBrackets(); if (ig.MenuItem("Show Matching Brackets", nullptr, flag))  then  editor:SetShowMatchingBrackets(flag[0]);  end ;
            flag[0] = editor:IsCompletingPairedGlyphs(); if (ig.MenuItem("Complete Matching Glyphs", nullptr, flag))  then  editor:SetCompletePairedGlyphs(flag[0]);  end ;
            flag[0] = editor:IsShowMiniMapEnabled(); if (ig.MenuItem("Show Mini Map", nullptr, flag))  then  editor:SetShowMiniMapEnabled(flag[0]);  end ;
            flag[0] = editor:IsShowScrollbarMiniMapEnabled(); if (ig.MenuItem("Show Scrollbar Mini Map", nullptr, flag))  then  editor:SetShowScrollbarMiniMapEnabled(flag[0]);  end ;
            flag[0] = editor:IsShowPanScrollIndicatorEnabled(); if (ig.MenuItem("Show Pan/Scroll Indicator", nullptr, flag))  then  editor:SetShowPanScrollIndicatorEnabled(flag[0]);  end ;
            flag[0] = editor:IsMiddleMousePanMode(); if (ig.MenuItem("Middle Mouse Pan Mode", nullptr, flag))  then  if (flag[0])  then editor:SetMiddleMousePanMode(); else editor:SetMiddleMouseScrollMode();  end  end ;
            --ig.MenuItem("Unicode Line Break Algorithm", nullptr, lineBreakConfig.useUnicodeAnnex14);
            ig.EndMenu();
         end 
end


local function toggleTrieAutoComplete(self) 
    local editor = self.editor
    local trieAutoComplete = self.trieAutoComplete
    -- see if we are turning it on or off
    if (self.demoTrieAutoComplete[0]) then
        -- deactivate language server demo (if required)
        -- if (demoLspBridge) {
            -- demoLspBridge = false;
            -- toggleLspBridge();
        -- }

        -- connect autocomplete helper to editor
        trieAutoComplete:Connect(editor);
        self.notifications:Add(self.notifications.Type.info, "Autocomplete activated");

    else 
        --// disconnect autocomplete helper from editor
        trieAutoComplete:Disconnect();
        self.notifications:Add(self.notifications.Type.info, "Autocomplete deactivated");
    end
end

local function IM_COL32(a,b,c,d)
    return ig.U32(a/255,b/255,c/255,d/255)
end

local function toggleNavigationMode(self) 
    local iog = ig.GetIO();

    if bit.band(iog.ConfigFlags, ig.lib.ImGuiConfigFlags_NavEnableKeyboard)~=0 then
        iog.ConfigFlags = bit.band(iog.ConfigFlags, bit.bnot(ig.lib.ImGuiConfigFlags_NavEnableKeyboard), bit.bnot( ig.lib.ImGuiConfigFlags_NavEnableGamepad))
        self.notifications:Add(self.notifications.Type.info, "Keyboard/gamepad navigation mode deactivated");
    else
        iog.ConfigFlags = bit.bor(iog.ConfigFlags, ig.lib.ImGuiConfigFlags_NavEnableKeyboard, ig.lib.ImGuiConfigFlags_NavEnableGamepad)
        self.notifications:Add(self.notifications.Type.info, "Keyboard/gamepad navigation mode activated");
    end
end
local function renderMenuBar(self)
        local editor = self.editor
        if (ig.BeginMainMenuBar()) then
            if (ig.BeginMenu("Edit")) then
                local ro = ffi.new("bool[?]",1,editor:IsReadOnlyEnabled());
                if (ig.MenuItem("Read-only mode", nil, ro)) then
                    editor:SetReadOnlyEnabled(ro[0])
                end
                ig.Separator();

                if (ig.MenuItem("Undo", "Ctrl-Z", nil, not ro[0] and editor:CanUndo())) then
                    editor:Undo()
                end
                if (ig.MenuItem("Redo", "Ctrl-Y", nil,not ro[0] and editor:CanRedo())) then
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
                local flag = ffi.new("bool[?]",1,editor:IsInsertSpacesOnTabs())
                if (ig.MenuItem("Insert Spaces on Tabs", nil, flag)) then editor:SetInsertSpacesOnTabs(flag[0]); end
                if (ig.MenuItem("Tabs To Spaces")) then editor:TabsToSpaces(); end
                if (ig.MenuItem("Spaces To Tabs", nil, nil, not editor:IsInsertSpacesOnTabs())) then editor:SpacesToTabs(); end
                if (ig.MenuItem("Strip Trailing Whitespaces")) then editor:StripTrailingWhitespaces(); end
                ig.Separator();
                if (ig.MenuItem("Select all", nil, nil)) then
                    editor:SelectAll();
                end
                
                -- if (ig.MenuItem("Find")) then
                    -- editor:OpenFindReplaceWindow()
                -- end
                ig.EndMenu();
            end
            
            if (ig.BeginMenu("Selection"))  then 
                if (ig.MenuItem("Select All", "Ctrl-A", nullptr, not editor:IsEmpty()))  then  editor:SelectAll();  end 

                ig.Separator();
                if (ig.MenuItem("Indent Line(s)",  "Ctrl-]", nullptr, not editor:IsEmpty()))  then  editor:IndentLines();  end 
                if (ig.MenuItem("Deindent Line(s)", "Ctrl-[", nullptr, not editor:IsEmpty()))  then  editor:DeindentLines();  end 
                if (ig.MenuItem("Move Line(s) Up", nullptr, nullptr, not editor:IsEmpty()))  then  editor:MoveUpLines();  end 
                if (ig.MenuItem("Move Line(s) Down", nullptr, nullptr, not editor:IsEmpty()))  then  editor:MoveDownLines();  end 
                if (ig.MenuItem("Toggle Comments",  "Ctrl-L", nullptr, editor:HasLanguage()))  then  editor:ToggleComments();  end 
    
                ig.Separator();
                if (ig.MenuItem("To Uppercase", nullptr, nullptr, editor:AnyCursorHasSelection()))  then  editor:SelectionToUpperCase();  end 
                if (ig.MenuItem("To Lowercase", nullptr, nullptr, editor:AnyCursorHasSelection()))  then  editor:SelectionToLowerCase();  end 
    
                ig.Separator();
                if (ig.MenuItem("Add Next Occurrence", "Ctrl-D", nullptr, editor:CurrentCursorHasSelection()))  then  editor:AddNextOccurrence();  end 
                if (ig.MenuItem("Select All Occurrences", "^Ctrl-D", nullptr, editor:CurrentCursorHasSelection()))  then  editor:SelectAllOccurrences();  end 
    
                ig.EndMenu();
            end 
            
            if (ig.BeginMenu("Find")) then
                if (ig.MenuItem("Find", "Ctrl-F")) then editor:OpenFindReplaceWindow(); end
                if (ig.MenuItem("Find Next","Ctrl-G", nil, editor:HasFindString())) then editor:FindNext(); end
                if (ig.MenuItem("Find All", "^Ctrl-G", nil, editor:HasFindString())) then editor:FindAll(); end
                ig.Separator();
                ig.EndMenu();
            end
            -- should be general menu?
            if (ig.BeginMenu("View")) then
                -- if (ig.MenuItem("Zoom In", "Ctrl-+")) then increaseFontSIze(); end
                -- if (ig.MenuItem("Zoom Out", "Ctrl--")) then decreaseFontSIze(); end
                -- ig.Separator();
                local flag = ffi.new("bool[?]",1)
                --if (ig.MenuItem("Autocomplete", nil, &autocomplete)) { setAutocompleteMode(autocomplete); }
                flag[0] = editor:IsShowWhitespacesEnabled(); 
                if (ig.MenuItem("Show Whitespaces", nil, flag)) then editor:SetShowWhitespacesEnabled(flag[0]); end
                flag[0] = editor:IsShowSpacesEnabled();
                if (ig.MenuItem("Show Spaces", nil, flag)) then editor:SetShowSpacesEnabled(flag[0]) end
                flag[0] = editor:IsShowTabsEnabled();
                if (ig.MenuItem("Show Tabs", nil, flag)) then editor:SetShowTabsEnabled(flag[0]) end
                flag[0] = editor:IsShowLineNumbersEnabled();
                if (ig.MenuItem("Show Line Numbers", nil, flag)) then editor:SetShowLineNumbersEnabled(flag[0]) end
                flag[0] = editor:IsShowingMatchingBrackets();
                if (ig.MenuItem("Show Matching Brackets", nil, flag)) then editor:SetShowMatchingBrackets(flag[0]); end
                flag[0] = editor:IsCompletingPairedGlyphs(); 
                if (ig.MenuItem("Complete Matching Glyphs", nil, flag)) then editor:SetCompletePairedGlyphs(flag[0]); end
                flag[0] = editor:IsShowPanScrollIndicatorEnabled();
                if (ig.MenuItem("Show Pan/Scroll Indicator", nil, flag)) then editor:SetShowPanScrollIndicatorEnabled(flag[0]); end
                flag[0] = editor:IsMiddleMousePanMode(); 
                if (ig.MenuItem("Middle Mouse Pan Mode", nil, flag)) then
                    if (flag[0]) then editor:SetMiddleMousePanMode();
                    else editor:SetMiddleMouseScrollMode(); end
                end
                ig.Separator();
                if (ig.MenuItem("Show Diff", "Ctrl-I")) then showDiff(self); end
                ig.EndMenu()
            end
            
            renderMenuOptions(self)
            
            if (ig.BeginMenu("Examples")) then
                if (ig.MenuItem("Trie-based AutoComplete", nullptr, self.demoTrieAutoComplete)) then toggleTrieAutoComplete(self); end
                --if (ig.MenuItem("Language Server Protocol Bridge", nullptr, &demoLspBridge)) { toggleLspBridge(); }
                --if (ig.MenuItem("Show Word at Mouse", nullptr, &showWordAtMouse)) { toggleShowWordAtMouse(); }
                -- if (ig.MenuItem("Show Line Markers", nullptr, self.showLineMarkers)) then toggleLineMarkers(self); end
                -- if (ig.MenuItem("Show Line Decorator", nullptr, &showLineDecorator)) { toggleLineDecorator(); }
                -- if (ig.MenuItem("Show Context Menus", nullptr, &showContextMenus)) { toggleContextMenus(); }
                ig.Separator();
                local navigationMode = ffi.new("bool[?]",1,bit.band(ig.GetIO().ConfigFlags, ig.lib.ImGuiConfigFlags_NavEnableKeyboard))
                if ig.MenuItem("Keyboard/Gamepad Navigation Mode", "Ctrl-Alt-N", navigationMode) then toggleNavigationMode(self); end
                --ig.MenuItem("Show Debug Information", nullptr, &showDebugInformation);
                if (ig.MenuItem("iterate")) then
                --ig.lib.IterateIdentifiers(editor,it_cb)
                    editor:IterateIdentifiers(it_cb)
                end
                ig.EndMenu();
            end
            ig.EndMainMenuBar();
        end
        if (ig.Shortcut(bit.bor(ig.lib.ImGuiMod_Ctrl, ig.lib.ImGuiMod_Alt, ig.lib.ImGuiKey_N), ig.lib.ImGuiInputFlags_RouteAlways)) then toggleNavigationMode(self); end
        if ig.Shortcut(bit.bor(ig.lib.ImGuiMod_Ctrl, ig.lib.ImGuiKey_I)) then showDiff(self) end
end

local show_mode = ffi.new("int[?]",1,0)
local modes = {"line sorted","name sorted","object sorted"}
local com_mode
local function renderFunctionList(self)

    if self.function_list then

        ig.BeginChild("funtion list")--,nil, nil, ig.lib.ImGuiWindowFlags_MenuBar)
        --hack for having a window bar
        -- if ig.BeginMenuBar() then
            -- if ig.BeginMenu("funtion list") then
                -- ig.RadioButton("line sorted", show_mode , 0)
                -- ig.RadioButton("name sorted", show_mode , 1)
                -- ig.RadioButton("object sorted", show_mode , 2)
               -- ig.EndMenu();
            -- end
            -- ig.EndMenuBar();
        -- end
        if not com_mode then
            com_mode = ig.LuaCombo("###mode", modes, function(it,id) show_mode[0] = id-1 end, {calcwidth = true})
            com_mode:set_index(3)
        end
        com_mode:draw()
        if show_mode[0] ~= 2 then --line or name sorted
            local funcs = (show_mode[0]==1) and self.function_list.funcs_sorted or self.function_list.funcs
            for i,v in ipairs(funcs) do
                if ig.Selectable(v.name.."##"..tostring(i) ) then
                    self.editor:SetCursor(ig.DocPos(v.line-1,0)[0])
                    self.editor:ScrollToLine(v.line-1, ig.lib.alignMiddle)
                    self.editor:SetFocus()
                end
            end
        else --object sorted
        --[[
            local objs = self.function_list.tables
            for i, obj in ipairs(objs) do
                if ig.Selectable(obj.name.."##"..tostring(i) ) then
                    self.editor:ScrollToLine(obj.line-1, ig.lib.alignMiddle)
                end
                ig.Indent()
                for j, fun in ipairs(obj.child_f) do
                    if ig.Selectable(fun.name.."##"..tostring(j) ) then
                        self.editor:ScrollToLine(fun.line-1, ig.lib.alignMiddle)
                    end
                end
                ig.Unindent()
            end
        --]]
            local objs = self.function_list.tables
            for i, obj in ipairs(objs) do
                if ig.TreeNode(obj.name.."##tree"..tostring(i) ) then
                    if ig.Selectable("def.".."##"..tostring(i) ) then
                        self.editor:SetCursor(ig.DocPos(obj.line-1,0)[0])
                        self.editor:ScrollToLine(obj.line-1, ig.lib.alignMiddle)
                        self.editor:SetFocus()
                    end
                    for j, fun in ipairs(obj.child_f) do
                        if ig.Selectable(fun.name.."##"..tostring(j) ) then
                            self.editor:SetCursor(ig.DocPos(fun.line-1,0)[0])
                            self.editor:ScrollToLine(fun.line-1, ig.lib.alignMiddle)
                            self.editor:SetFocus()
                        end
                    end
                    ig.TreePop()
                end
            end
        end
        ig.EndChild()

    end
end
local function Render(self)
    local editor = self.editor
    
    --------------
    renderMenuBar(self)
    renderStatusBar(self)

    local ret = editor:Render("texteditor"..self.ID)
    ig.SameLine()

    -- kepped as example
    -- if ig.IsItemClicked() and ig.IsMouseDoubleClicked(0) then 
        -- local docpos = editor:GetDocPosAtMousePos(ig.GetMousePos())
        -- self.breakpoints[tonumber(docpos.line + 1)] = true
    -- end

    if self.render_diff then
        RenderDiff(self)
    end
    
    return ret
end
local lfs = require"lfs_ffi"
local function Save(self,fname)
    local editor = self.editor
    
    if fname then
        --print("saving",fname)
        local file,err = io.open(fname,"w")
        assert(file,err)
        
        local txt = editor:GetText()
        local str = ffi.string(txt)
        file:write(str)
        file:close()
        if fname == self.file_name then
            --print"fname == self.file_name"
            editor:SetText(str)
        end
        self.modification = lfs.attributes(fname,"modification")
        self.dirty = false
        self.is_new = nil
    end
end

local function ReLoad(self, doit)
    if doit then
        local file,err = io.open(self.file_name,"r")
        assert(file,err)
        local strtext = file:read"*a"
        file:close()
        self.originalText = strtext
        self.editor:SetText(strtext)
        self.dirty = false
    else
        self.dirty = true
    end
    self.modification = lfs.attributes(self.file_name,"modification")
end

local function CTEwindow(file_name, args)
    local strtext = ""
    local ext, shrt_name = "" , ""
    local modification
    if not args.is_new then
        local file,err = io.open(file_name,"r")
        --assert(file,err)
        if not file then
            print(err)
            args.is_new = true
        else
            strtext = file:read"*a"
            file:close()
            modification = lfs.attributes(file_name,"modification")
            --print(file_name)
            --print(os.time(),modification)
            --for k,v in ipairs({"change","access","modification"}) do print(v,at[v]) end
        end
    end

    ext = file_name:match("%.([^%.]+)$")
    if ext then
        shrt_name = file_name:match("[^/\\]+%."..ext.."$")
        shrt_name = shrt_name.."."..ext
    else
        shrt_name = file_name:match("[^/\\]+$")
        ext = ""
    end
   


    local W = {file_name = file_name or "", shrt_name = shrt_name or "", ext = ext or "", is_new = args.is_new, modification = modification}
    local editor = ig.TextEditor()
    W.is_dirty = function(self) return self.dirty or self.editor:CanUndo() end
    W.ReLoad = ReLoad
    W.Log = args.Log
    W.editor = editor
    W.function_list = args.function_list.find_functions(strtext,ext)
    W.render_functions = renderFunctionList
    editor:SetLineFoldingEnabled(true);
    editor:SetWordWrapEnabled(true)
    --test some callbacks
    --editor:SetChangeCallback(function() print"change" end,0)
    --[[
    editor:SetCustomCaretRenderer(function(caret) 
        if (caret.caretVisible) then
            local color = ig.GetColorU32_U32(caret.caretColor, 0.5);
            caret.drawList:AddRectFilled(caret.glyphPos, caret.glyphPos + caret.glyphSize, color);
        end
    end);
    --]]
    --[[
    editor:SetLineNumberContextMenuCallback(function(pp)
        if (ig.MenuItem("Set Breakpoint"))then print"set" end
        if (ig.MenuItem("Remove Breakpoint"))then print"remove" end
    end)
    editor:SetTextContextMenuCallback(function(data)
        local pos2 = ig.DocPos(data.pos.line+1 ,data.pos.index)
        ig.Text("Line %zu, index %zu", data.pos.line + 1, data.pos.index + 1);
        ig.Text("Line %zu, index %zu", pos2.line + 1, pos2.index + 1);
        ig.Text(editor:GetSectionText(data.pos,pos2[0]))
    end)
    --]]
    W.breakpoints = args.breakpoints or {}
    W.send_breakpoint = args.send_breakpoint
    -- decorator for breakpoint
    editor:SetLineDecorator(1.0, function(decorator) 
        local size = decorator.height - 1.0;
        local pos = ig.GetCursorScreenPos();
        local drawlist = ig.GetWindowDrawList();
    
        ig.InvisibleButton("Invisible", ig.ImVec2(size, size))
    
        if W.breakpoints[tonumber(decorator.line+1)] then
            drawlist:AddCircleFilled(
            ig.ImVec2(pos.x + size * 0.5, pos.y + size * 0.5),
            (size - 6.0) * 0.5,
            ig.U32(128/255, 0, 0, 255/255));
    
        elseif ig.IsItemHovered() then
            drawlist:AddCircle(
            ig.ImVec2(pos.x + size * 0.5, pos.y + size * 0.5),
            (size - 6.0) * 0.5,
            ig.U32(128/255, 0, 0, 255/255));
        end
    
        if ig.IsItemHovered() and ig.IsMouseClicked(0) then 
            if W.breakpoints[tonumber(decorator.line+1)] then
                W.breakpoints[tonumber(decorator.line+1)] = nil
                W.send_breakpoint({"delete", "@"..W.file_name, tonumber(decorator.line+1)})
            else
                W.breakpoints[tonumber(decorator.line+1)] = true
                W.send_breakpoint({"add", "@"..W.file_name, tonumber(decorator.line+1)})
            end
        end
    end)

    W.diff = ig.TextDiff()
    W.trieAutoComplete = ig.TrieAutoComplete()
    W.trieAutoComplete:Connect(W.editor);

    W.demoTrieAutoComplete = ffi.new("bool[?]",1,true);
    W.showLineMarkers = ffi.new("bool[?]",1,false);
    W.render_diff = false
    W.originalText = strtext
    editor:SetText( strtext)

    W.lang_combo = ig.LuaCombo("Lang",langNames,
                function(name,ind)
                    if name=="None" then
                        editor:SetLanguage(nil)
                    else
                        editor:SetLanguage(ig["Language_"..name]())
                    end
                end,{calcwidth=true})
    if ext == "cpp" or ext == "hpp" then
        W.lang_combo:set_index(2)
    elseif ext == "c" or ext == "h" then
        W.lang_combo:set_index(3)
    elseif ext == "lua" then
        W.lang_combo:set_index(6)
    elseif ext == "json" then
        W.lang_combo:set_index(7)
    else
        W.lang_combo:set_index(1)
        print"unknown language"
    end
    --------------------------------
    W.Render = Render
    W.notifications = args.notifications
    W.ID = "CTE##"..tostring(W)
    W.Save = Save
    W.ig = ig
    return W
end

return function(iglib)
    ig = iglib
    return {CTEwindow=CTEwindow}
end

