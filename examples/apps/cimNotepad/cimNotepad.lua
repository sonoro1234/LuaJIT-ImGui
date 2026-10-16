--[[-----------------------------------hack for being able to require in cimNotepad dir------
local sep = package.config:sub(1,1)
local currpath = debug.getinfo(1,'S').source
currpath = currpath:match("@(.+)[\\/]([^\\/]+)")
print("cimNotepad scriptpath:",currpath)
package.path = currpath..sep.."?.lua;"..package.path
print(package.path)
-------------------------------------------------------------------------------
--]]
local pathut = require"imgui.libs.path"
local currpath = pathut.file_path()

-------singleton app
local sing,err = io.open(pathut.chain(currpath,"singleton.log"),"r")
if sing then
    sing:close()
    print"There is singleton open, on last execution error delete 'singleton.log' from cimNotepad folder"
    print"Dont delete if there is another cimNotepad executing."
    print("delete?: y/n")
    local del = io.read"*l"
    if del=="y" then
        os.remove(pathut.chain(currpath,"singleton.log"))
        print("singleton.log deleted. cimNotepad is active.")
    else
        return
    end
end
--create singleton.log
sing,err =io.open(pathut.chain(currpath,"singleton.log"),"w")
assert(sing, err)
sing:close()
------------------------------------------
local igwin = require"imgui.window"
--local win = igwin:SDL(1000,600, "cimNotepad",{fps=30,vsync=true,use_imgui_viewport=false, not_main_dock_space = true})
--local win = igwin:SDL3(1000,600, "cimNotepad",{fps=30,vsync=true,use_imgui_viewport=false, not_main_dock_space = true})
local win = igwin:GLFW(1000,600, "cimNotepad",{fps=30,vsync=true,use_imgui_viewport=false, not_main_dock_space = true})


---------- locals ---------------------------------
local ig = win.ig
local CTE = dofile(pathut.chain(currpath,"CTEwindow.lua"))(win.ig)
local gui = require"imgui.libs.filebrowser"(win.ig)
local ffi = require"ffi"
--------Thread execute
--local Exec = require"executer"
local Exec = dofile(pathut.chain(currpath,"executer.lua"))
local ExecutePull, send_breakpoint = Exec.ExecutePull, Exec.send_breakpoint
-----function list
local function_list = dofile(pathut.chain(currpath,"functions_list.lua"))

------------------------------------------------------------------

local Log = gui.CLog() -- app Log
--tab orderer docs
local opendocs = {}
local opendocfnames = {}
--set curr_opendoc in next draw
local set_tab = -1
local curr_opendoc = 1
local close_doc

local style_module = dofile(pathut.chain(currpath,"style_module.lua"))(win.ig, opendocs)

local notifications = dofile(pathut.chain(currpath,"Notifications.lua"))(ig) --ig.Notifications()
local showhelp = false

local Stack = {}
local StackLevel = 1
local Vars = {}
local setStack

local openfilepopup = false
local savefilepopup = false
local doclosefile = false

local help_txt = 
[[multicursor (ctrl + click to add a new one)
ctrl + d for selecting next match
ctrl + [ and ctrl + ] for indentation
ctrl + backspace and ctrl + delete for word mode delete
ctrl + / for comment toggling]]

local addEditor
---------------------------------------------------
setStack = function(sour, line,stack,err, vars, is_compile_err)

    Vars = vars or {}
    for i,doc in ipairs(opendocs) do
        doc.editor:ClearMarkers();
    end

    Stack = stack or {}

    --add error marker
    local color = is_compile_err and ig.U32(0.5,0.5,0,1) or ig.U32(128/255, 0, 32/255, 128/255)
    for i,v in ipairs(Stack) do
        if v.source:match"^@" then
            StackLevel = i
            local doc = addEditor(v.source:sub(2), v.currentline)
            if doc then
                doc.editor:AddMarker( v.currentline-1, 0, color, "", err or "Error detected on this line");
            end
            break
        end
    end
end

local function recursiveTree(k,v, look_up, parent_str)
    look_up = look_up or {}
    parent_str = parent_str or ""
    if look_up[v] then ig.TextUnformatted(tostring(k)..": recursion: "..look_up[v]) return end
    look_up[v] = parent_str.."["..k.."]"
    if ig.TreeNode(k) then
        for k2,v2 in pairs(v) do
            if type(v2)=="table" then
                recursiveTree(k2,v2,look_up,parent_str.."["..k.."]")
            else
                ig.TextUnformatted(tostring(k2)..": "..tostring(v2))
            end
        end
        ig.TreePop()
    end
end

local function renderVars()

    ig.TextUnformatted("StackLevel:"..tostring(StackLevel))
    ig.Separator()
    if Vars[StackLevel] then
        for k,v in pairs(Vars[StackLevel]) do
            if type(v)=="table" then
                recursiveTree(k,v)
            else
                ig.TextUnformatted(tostring(k)..": "..tostring(v))
            end
        end
    end

end


local function renderStack()

    if ig.BeginTable("stack_levels", 4, ig.lib.ImGuiTableFlags_Borders 
    --+ ig.lib.ImGuiTableFlags_RowBg 
    --+ ig.lib.ImGuiTableFlags_ScrollY + ig.lib.ImGuiTableFlags_Resizable 
    --+ ig.lib.ImGuiTableFlags_SizingFixedFit
    + ig.lib.ImGuiTableFlags_SizingStretchProp 
    ) then
        ig.TableSetupColumn("name");
        ig.TableSetupColumn("what");
        ig.TableSetupColumn("namewhat");
        ig.TableSetupColumn("source");
        ig.TableHeadersRow();

        for i,lev in ipairs(Stack) do
            ig.TableNextRow()
            ig.TableNextColumn();ig.TextUnformatted(lev.name or "")
            ig.TableNextColumn();ig.TextUnformatted(lev.what or "")
            ig.TableNextColumn();ig.TextUnformatted(lev.namewhat or "")
            ig.TableNextColumn();
            if lev.source == "=[C]" then
                ig.TextUnformatted(lev.source..":"..tostring(lev.currentline))
                -- local show_name = lev.source..":"..tostring(lev.currentline).."##"..tostring(i)
                -- if ig.Selectable(show_name,nil,
                -- bit.bor(ig.lib.ImGuiSelectableFlags_SpanAllColumns, (StackLevel== i) and ig.lib.ImGuiSelectableFlags_Highlight or 0)) then
                    -- StackLevel = i
                -- end
            else
                local source = lev.source:sub(2)
                local shrt_name = source
                local doc = opendocfnames[source]
                if not doc then 
                    shrt_name = source
                else
                    shrt_name = doc.shrt_name
                end
                local show_name = shrt_name..":"..tostring(lev.currentline).."##"..tostring(i)
                if ig.Selectable(show_name,nil,
                bit.bor(ig.lib.ImGuiSelectableFlags_SpanAllColumns, (StackLevel== i) and ig.lib.ImGuiSelectableFlags_Highlight or 0)) then
                    StackLevel = i
                    addEditor(source, lev.currentline)
                end
            end
        end
        ig.EndTable()
    end

end

local function renderStackVars()
    ig.Begin"StackVars"
        if (ig.BeginTabBar("##TabsStackVars", ig.lib.ImGuiTabBarFlags_None)) then
            if ig.BeginTabItem("Stack") then
                renderStack()
                ig.EndTabItem();
            end
            if ig.BeginTabItem("Vars") then
                renderVars()
                ig.EndTabItem();
            end
        ig.EndTabBar();
        end
    ig.End()
end




local fb = gui.FileBrowser(nil,{key="loader",pattern=nil},
    function(fullname,dir,fname)
        addEditor(fullname)
    end)

local TRO
local fbs = gui.FileBrowser(nil,{key="saver",check_existence=true},
    function(fname)
        local doc = opendocs[curr_opendoc]
        -- save as
        if doc.file_name ~= fname then
            opendocfnames[doc.file_name] = nil
            opendocfnames[fname] = doc
            doc.file_name = fname
            doc.shrt_name = fname:match([[([^/\]+)$]])
            set_tab = curr_opendoc
            TRO.clear_next()
        end
        doc:Save(fname)
    end)
    

-------------------Menus
local function renderMenuDocs()
        if ig.BeginMenu("Docs") then
            if ig.MenuItem("sort") then
                local currdoc = opendocs[curr_opendoc]
                table.sort(opendocs, function(a,b) return a.shrt_name < b.shrt_name end)
                for i, doc in ipairs(opendocs) do
                    if doc == currdoc then
                        curr_opendoc = i
                        set_tab = i
                        break
                    end
                end
            end
            ig.Separator()
            for i,doc in ipairs(opendocs) do
                local dirty = doc:is_dirty() and "*" or ""
                if ig.MenuItem(doc.shrt_name..dirty, nil, i==curr_opendoc) then
                    curr_opendoc = i
                    set_tab = i
                end
            end
            ig.EndMenu()
        end
end

local function renderMenuFile(win)
    if (ig.BeginMainMenuBar()) then
            if (ig.BeginMenu("File")) then
                if (ig.MenuItem("New")) then
                    local fname = "new1.lua"
                    while true do
                        if not opendocfnames[fname] then break
                        else 
                            local number = fname:match("%d+")
                            fname = "new"..tostring(number + 1)..".lua"
                        end
                    end
                    addEditor(fname, nil, true)
                end
                if (ig.MenuItem("Load")) then
                    openfilepopup = true
                end
                if (ig.MenuItem("Save","Ctrl-S")) then
                    local doc = opendocs[curr_opendoc]
                    doc:Save(doc.file_name)
                end
                if (ig.MenuItem("Save As")) then
                    savefilepopup = true
                end
                if (ig.MenuItem("Close")) then
                   doclosefile = true
                   close_doc = curr_opendoc
                end
                if (ig.MenuItem("Quit")) then
                    win:quit()
                end
                ig.EndMenu();
            end
            ig.EndMainMenuBar()
        end

    if ig.Shortcut(bit.bor(ig.lib.ImGuiMod_Ctrl, ig.lib.ImGuiKey_S)) then
        local doc = opendocs[curr_opendoc]
        doc:Save(doc.file_name)
    end

    if openfilepopup then fb.open() end
    fb.draw()

    if savefilepopup then fbs.open() end
    fbs.draw()
end

-------------------TabBar functions
local function showTabBar()
    local TabBar = ig.GetCurrentTabBar()
    local Tabs = TabBar.Tabs
    print"---ShowTabBar ---------------"
    for i=0, Tabs.Size-1 do
        local tab = Tabs.Data[i]
        print("tab",i + 1 ,tab.BeginOrder + 1, opendocs[tab.BeginOrder + 1].shrt_name)
    end
end

local function do_reorder(order,orderinv)
    local new_opendocs = {}
    for i,v in ipairs(order) do
        new_opendocs[i] = opendocs[v]
    end
    curr_opendoc = orderinv[curr_opendoc]
    set_tab = curr_opendoc
    opendocs = new_opendocs
    -------------
    local doc = opendocs[curr_opendoc]
    local cupos = doc.editor:GetMainCursorPosition()
    local line = tonumber(cupos.line) + 1
    doc.editor:ScrollToLine(line-1, ig.lib.alignTop)
    doc.editor:SetFocus()
end

TRO = gui.TabReorder(do_reorder)
---------------------------------

addEditor = function(fullname, line, is_new, breakpoints)
--print("---addEditor",fullname, line, is_new)
        if opendocfnames[fullname] then
            if line then
                for i,doc in ipairs(opendocs) do
                    if doc.file_name == fullname then 
                        doc.editor:SetCursor(ig.DocPos(line-1,0)[0])
                        doc.editor:ScrollToLine(line-1, ig.lib.alignTop)
                        curr_opendoc = i
                        set_tab = i
                        return doc
                    end
                end
                print("Error not found",fullname)
            end
            return -- to avoid reopening
        end 
        
        local doc = CTE.CTEwindow(fullname,{Log = Log, is_new = is_new, notifications = notifications, send_breakpoint = send_breakpoint, breakpoints = breakpoints, function_list = function_list})
        --style
        doc.editor:SetPalette(style_module.current_palette)
        doc.diff:SetPalette(style_module.current_palette)
        -- set line
        if line then
            doc.editor:SetCursor(ig.DocPos(line-1,0)[0])
            doc.editor:ScrollToLine(line-1, ig.lib.alignTop)
        end
        opendocfnames[fullname] = doc
        table.insert(opendocs,doc);
        curr_opendoc = #opendocs
        set_tab = #opendocs
        doc.shrt_name = fullname:match([[([^/\]+)$]])
        return doc
end

local function CloseEditor(id)
    --print("CloseEditor",id, opendocs[id].shrt_name)
    local doc = table.remove(opendocs,id)
    opendocfnames[doc.file_name] = nil
    if #opendocs == 0 then
        addEditor("new1.lua", nil, true)
    end
end

local confirm_close_app = gui.YesNo("There are unsaved changes. Do you still want to close?",{id = "closeapp"})
local confirm_close_file = gui.YesNo("The file has unsaved changes. Do you still want to close?", {id = "closefile"})

local doc_check_close
local doc_to_close
local function CheckCloseEditor(id, dodel)
    if dodel then
        doc_to_close = id
        local doc = opendocs[id]
        if doc:is_dirty() then
            confirm_close_file.open()
            doc_check_close = doc
        else
            doc_check_close = nil
        end
    else
        if doc_check_close then
            local conf = confirm_close_file.draw(nil, doc_check_close.shrt_name.." has unsaved changes.\nDo you still want to close?")
            -- conf == nil do nothing
            if conf==true then
                doc_check_close = nil
                doc_to_close = nil
                CloseEditor(id)
            elseif conf == false then
                curr_opendoc = doc_to_close
                set_tab = doc_to_close
                doc_check_close = nil
                doc_to_close = nil
            end
        elseif doc_to_close then
            doc_to_close = nil
            CloseEditor(id)
        end
    end
end


local lfs = require"lfs_ffi"
local counterCheck = 0
local checking
local load_modification = gui.YesNo("Another program modified"..". Do you want to reload?",{id="modYesNo"})
local function checkModification()
    counterCheck = counterCheck + 1
    if counterCheck == win.args.fps then
        for i,doc in ipairs(opendocs) do
            if not doc.is_new then
                local modification = lfs.attributes(doc.file_name,"modification")
                if doc.modification < modification then
                    --print(doc.file_name,"modificated")
                    load_modification.open()
                    checking = doc
                    goto draw
                end
            end
        end
        counterCheck = 0
    end
    if not checking then return end
    ::draw::
    local doit = load_modification.draw(nil,"Another program modified "..checking.shrt_name..".\nDo you want to reload?")
    if checking then
        --when doit==nil nothing happens
        if doit then
            --print"load file"
            checking:ReLoad(true)
            checking = nil
            counterCheck = 0
        elseif doit == false then
            --print"dont load"
            checking:ReLoad(false)
            checking = nil
            counterCheck = 0
        end
    end
end

local serializer = require"imgui.libs.serializer"
local function PersitenceSave()
    local persist = {curr_opendoc = curr_opendoc}
    for i,doc in ipairs(opendocs) do
        local cupos = doc.editor:GetMainCursorPosition()
        local line = tonumber(cupos.line) + 1
        persist[i] = {file_name = doc.file_name, breakpoints = doc.breakpoints, is_new = doc.is_new, line = line} 
    end
    local persist_str = serializer("persist", persist).."return persist;"
    local f,err =io.open(pathut.chain(currpath,"persistence.lua"),"w")
    assert(f, err)
    f:write(persist_str)
    f:close()
end

local function PersistenceLoad()
    local f,err =io.open(pathut.chain(currpath,"persistence.lua"),"r")
    if f then
        f:close()
        local persist = dofile(pathut.chain(currpath,"persistence.lua"))
        for i, v in ipairs(persist) do
            addEditor(v.file_name, v.line, v.is_new, v.breakpoints)
        end
        curr_opendoc = persist.curr_opendoc or 1
        set_tab = curr_opendoc
    else -- have initial example
        addEditor(gui.pathut.chain(currpath,"scripts","loop.lua"))
    end
end

local function getBreakPoints()
    local bp = {}
    for i, doc in ipairs(opendocs) do
        for k,v in pairs(doc.breakpoints) do
            bp[k] = bp[k] or {}
            bp[k]["@"..doc.file_name] = true
        end
    end
    return {breakpoints = bp}
end

local this = {ig = ig, Log = Log, setStack = setStack, opendocs = opendocs,
 notifications = notifications, getBreakPoints = getBreakPoints, runningThread = false}
 
win.ig.GetIO().IniFilename = nil --"cimNotepad.ini"

style_module.LoadFont()
-- load persistence
PersistenceLoad()

-- docking stuff
local dock_id_bottom_left, dock_id_bottom, dock_id_top, dockspace_id
local old_viewport_size
local comments_size 
local comments_ratio = ig.ImVec2(0.5,0.25)


local ExpandContract_used
local function ExpandLog(vSize)
    ig.DockBuilderSetNodeSize(dock_id_top[0], ig.ImVec2(vSize.x,40))
    ig.DockBuilderSetNodeSize(dock_id_bottom[0], vSize)
    ig.DockBuilderSetNodeSize(dock_id_bottom_left[0], vSize)
    ExpandContract_used = true
end

local function ContractLog(vSize, ratio)
    ig.DockBuilderSetNodeSize(dock_id_top[0], vSize*(1 - ratio.y))
    ig.DockBuilderSetNodeSize(dock_id_bottom[0], vSize*ratio.y)
    ig.DockBuilderSetNodeSize(dock_id_bottom_left[0], vSize*ratio.x)
    ExpandContract_used = true
end

local selected_text
function win:draw(ig)

    --ig.ShowDemoWindow()
    checkModification()

    ----check execute
    ExecutePull(this)
    
    local lib = ig.lib
    
    local viewport = ig.GetMainViewport();

    if not dockspace_id then
        dockspace_id = ffi.new("ImGuiID[?]",1,ig.GetID("My Dockspace"));
        ig.DockBuilderAddNode(dockspace_id[0], lib.ImGuiDockNodeFlags_DockSpace);
        ig.DockBuilderSetNodeSize(dockspace_id[0], viewport.Size);
        local dock_id_main = ffi.new("ImGuiID[?]",1,dockspace_id[0])--dockspace_id;
        dock_id_top = ffi.new("ImGuiID[?]",1,0);
        dock_id_bottom = ffi.new("ImGuiID[?]",1,0);
        dock_id_bottom_left = ffi.new("ImGuiID[?]",1,0);
        dock_id_bottom_right = ffi.new("ImGuiID[?]",1,0);
        ig.DockBuilderSplitNode(dock_id_main[0], lib.ImGuiDir_Up, 0.80, dock_id_top, dock_id_bottom);
        ig.DockBuilderSplitNode(dock_id_bottom[0], lib.ImGuiDir_Left, 0.50, dock_id_bottom_left, dock_id_bottom_right);
        dock_id_top_left = ffi.new("ImGuiID[?]",1,0);
        dock_id_top_right = ffi.new("ImGuiID[?]",1,0);
        ig.DockBuilderSplitNode(dock_id_top[0], lib.ImGuiDir_Left, 0.85, dock_id_top_left, dock_id_top_right);
        ig.DockBuilderDockWindow("functions", dock_id_top_right[0]);
        ig.DockBuilderDockWindow("Documents", dock_id_top_left[0]);
        ig.DockBuilderDockWindow("comments", dock_id_bottom_left[0]);
        ig.DockBuilderDockWindow("StackVars", dock_id_bottom_right[0]);
        ig.DockBuilderFinish(dockspace_id[0]);
    end
    ig.DockSpaceOverViewport(dockspace_id[0], viewport, lib.ImGuiDockNodeFlags_PassthruCentralNode + lib.ImGuiDockNodeFlags_NoTabBar);
    
    local viewport_justresized = false
    if (viewport.Size~=old_viewport_size) then
        --print("viewport resize", old_viewport_size, viewport.Size)
        old_viewport_size = ig.ImVec2(viewport.Size.x, viewport.Size.y)
        viewport_justresized = true
    end

    
    local host_window_flags = bit.bor( ig.lib.ImGuiWindowFlags_NoTitleBar , ig.lib.ImGuiWindowFlags_NoCollapse, ig.lib.ImGuiWindowFlags_NoResize ,
    --ig.lib.ImGuiWindowFlags_NoMove , 
    ig.lib.ImGuiWindowFlags_NoBringToFrontOnFocus)--, --ig.lib.ImGuiWindowFlags_NoNavFocus,
    --ig.lib.ImGuiWindowFlags_MenuBar)
    
    openfilepopup = false
    savefilepopup = false
    doclosefile = false

    -- main menu

    
    
    if ig.Begin("Documents",nil, host_window_flags) then
        renderMenuFile(win)
-- for debug
-- ig.TextUnformatted("curr_opendoc: "..tostring(curr_opendoc).." "..(opendocs[curr_opendoc] and opendocs[curr_opendoc].file_name or ""))
-- ig.TextUnformatted("close_doc: "..tostring(close_doc).." "..(opendocs[close_doc] and opendocs[close_doc].file_name or ""))

    if ig.BeginTabBar("##Tabs", bit.bor(TRO.flag(),ig.lib.ImGuiTabBarFlags_DrawSelectedOverline)) then
        local opened =  ffi.new("bool[?]",1,true)
        for i,v in ipairs(opendocs) do
            local dopop = false
            if v:is_dirty() then 
                local col =  ig.U32(0.6,0,0,0.8)
                ig.PushStyleColor(ig.lib.ImGuiCol_TabHovered, ig.U32(0.6,0,0,1));
                ig.PushStyleColor(ig.lib.ImGuiCol_Tab, col);
                ig.PushStyleColor(ig.lib.ImGuiCol_TabSelected, ig.U32(0.6,0,0,0.9));
                dopop = true 
            end
            local opentab = ig.BeginTabItem(v.shrt_name.."##"..i, opened,(i==set_tab) and ig.lib.ImGuiTabItemFlags_SetSelected or 0)
            if dopop then ig.PopStyleColor(3) end
            if ig.IsItemHovered() then 
                ig.SetTooltip(v.file_name) 
                if ig.IsMouseClicked(0) then 
                     --print"click";
                     v.editor:SetFocus() 
                end
            end
            if opentab then
                if set_tab == -1 or set_tab == i then

                    if set_tab ~= -1 then 
                        -- we come from addEditor or getTabOrder
                        --print("set_tab just setted",set_tab)
                        v.editor:SetFocus()
                    end
                    
                    if curr_opendoc~=i then 
                        --print("manual changeg",string.format(" curr: %d, i: %d, set_tab: %d",curr_opendoc, i,set_tab))
                        v.editor:SetFocus()
                    end

                    set_tab = -1
                    curr_opendoc = i
                    --if ig.Button("showTabBar") then showTabBar() end
                    local ret = v:Render()
                    --if ret then print("changed") end
                    ---[[
                    if v.editor:MainCursorHasSelection() then
                        local dp= v.editor:GetMainCursorSelection()
                        local txt = v.editor:GetSectionText(dp)
                        if txt ~= selected_text then
                            selected_text = txt
                            v.editor:SelectAllOccurrencesOf(txt, true, true)
                        end
                    else
                        selected_text = nil
                    end
                    --]]
                else 
                    --print("going to change tab from", i,"to",set_tab)
                end
                ig.EndTabItem();
            end
            if not opened[0] then 
                close_doc = i
                doclosefile = true
                break
            end
        end
        TRO.Update()
        ig.EndTabBar();
    end
    
    CheckCloseEditor(close_doc, doclosefile)
    
    Exec.renderMenuExecute(this, curr_opendoc)
    style_module.renderMenuFonts()
	
    if (ig.BeginMainMenuBar()) then
        renderMenuDocs()
        if ig.BeginMenu("Help") then
            if (ig.MenuItem("Show")) then
                showhelp = true
            end
            ig.EndMenu()
        end
        ig.EndMainMenuBar()
    end
    end
    ig.End() --documents
    
    ig.Begin("functions")
        opendocs[curr_opendoc]:render_functions()
    ig.End()
    
    ig.Begin("comments")
        if comments_size ~= ig.GetWindowSize() then
            local siz = ig.GetWindowSize()

            if viewport_justresized then 
                ContractLog(viewport.Size, comments_ratio)
            elseif ExpandContract_used then
                ExpandContract_used = false --clear flag
            else
                comments_ratio = siz/viewport.Size
            end
            comments_size = ig.ImVec2(siz.x, siz.y)
        end
        if ig.SmallButton("expand") then
            ExpandLog(viewport.Size)
        end
        ig.SameLine()
        if ig.SmallButton("contract") then
            ContractLog(viewport.Size, comments_ratio)
        end
        Log:Draw()
    ig.End()
    
    renderStackVars()
    
    -- render notifications
    local style = ig.GetStyle()
    local statusBarHeight = ig.GetFrameHeight() + 2.0 * style.WindowPadding.y;
    local mainWindowSize = ig.GetMainViewport().Size;
    local mainWindowPos = ig.GetMainViewport().Pos;
    local offset = statusBarHeight + style.ItemSpacing.y * 2.0;

    notifications:Render(ig.ImVec2(
    mainWindowPos.x + mainWindowSize.x - ig.GetStyle().ItemSpacing.x,
    mainWindowPos.y + mainWindowSize.y - ig.GetStyle().ItemSpacing.y - offset));
    
    if showhelp then
        ig.SetNextWindowSize(ig.ImVec2(500,200));
        ig.OpenPopup("Help##p")
        if ig.BeginPopupModal("Help##p") then 
            ig.TextWrapped(help_txt)
            if ig.Button("OK") then
                ig.CloseCurrentPopup()
                showhelp = false
            end
            ig.EndPopup()
        end
    end
end

local function check_quit()
    local needs_confirm = false
    for i, doc in ipairs(opendocs) do
        if doc:is_dirty() then
            needs_confirm = true
            break
        end
    end

    local function checker()

        if needs_confirm then
            confirm_close_app.open()
        end

        local is_confirmed = confirm_close_app.draw(nil)
        if is_confirmed then
            -- doclose
            return true
        elseif is_confirmed == false then
            -- dont close
            return false
        elseif is_confirmed == nil then
            -- continue checking
            return nil
        end
    end
    return not needs_confirm, checker
end
win:start(check_quit)

-- after start finishes
-- persistence
PersitenceSave()
-- remove singleton.log
os.remove(pathut.chain(currpath,"singleton.log"))