local igwin = require"imgui.window"
--local win = igwin:SDL(800,600, "ColorTextEditor",{vsync=true,use_imgui_viewport=true})
local win = igwin:GLFW(800,600, "ColorTextEditor",{vsync=true,use_imgui_viewport=false})

local CTE = require"libs.CTEwindow"(win.ig)
local gui = require"libs.filebrowser"(win.ig)

local opendocs = {}
local opendocfnames = {}
local set_tab = -1
local function addEditor(fullname)
		if opendocfnames[fullname] then return end -- to avoid reopening
		opendocfnames[fullname] = true
        local doc = CTE.CTEwindow(fullname)
        table.insert(opendocs,doc);
        set_tab = #opendocs
		doc.shrt_name = fullname:match([[([^/\]+)$]])
end
local confirm_close = gui.YesNo("There are unsaved changes. Do you still want to close?")
local function CheckCloseEditor(id)
	local doc = opendocs[id]
	if doc.editor:CanUndo() then
		confirm_close.open()
		return false
	end
	return true
end
local function CloseEditor(id)
	local doc = table.remove(opendocs,id)
	opendocfnames[doc.file_name] = nil
end

local ffi = require"ffi"
local curr_opendoc = 1

local fb = gui.FileBrowser(nil,{key="loader",pattern=nil},
    function(fullname,dir,fname)
		addEditor(fullname)
    end)
local fbs = gui.FileBrowser(nil,{key="saver",check_existence=true},
	function(fname)
		local doc = opendocs[curr_opendoc]
		doc:Save(fname)
	end)
	
--add two editors
addEditor(gui.pathut.abspath([[../cimgui/imgui/imgui.cpp]]))
addEditor(gui.pathut.abspath("CTE_sample.lua"))

function win:draw(ig)
    ig.ShowDemoWindow()
    
    local openfilepopup = false
	local savefilepopup = false
	local doclosefile = false
	
	local viewport = ig.GetMainViewport();

    --Submit a window filling the entire viewport
    ig.SetNextWindowPos(viewport.WorkPos);
    ig.SetNextWindowSize(viewport.WorkSize);
    ig.SetNextWindowViewport(viewport.ID);
	
	local host_window_flags = bit.bor( ig.lib.ImGuiWindowFlags_NoTitleBar , ig.lib.ImGuiWindowFlags_NoCollapse, ig.lib.ImGuiWindowFlags_NoResize , ig.lib.ImGuiWindowFlags_NoMove , ig.lib.ImGuiWindowFlags_NoDocking, ig.lib.ImGuiWindowFlags_NoBringToFrontOnFocus, ig.lib.ImGuiWindowFlags_NoNavFocus,ig.lib.ImGuiWindowFlags_MenuBar)
	
    ig.Begin("Documents",nil, host_window_flags) --ig.lib.ImGuiWindowFlags_MenuBar)
        if (ig.BeginMenuBar()) then
            if (ig.BeginMenu("File")) then
                if (ig.MenuItem("Load")) then
                    openfilepopup = true
                end
				if (ig.MenuItem("Save As")) then
                    savefilepopup = true
                end
                if (ig.MenuItem("Close")) then
				   doclosefile = true
                end
                ig.EndMenu();
            end
        ig.EndMenuBar()
    end
    if openfilepopup then fb.open() end
    fb.draw()
	if savefilepopup then fbs.open() end
	fbs.draw()

    ig.SetWindowSize(ig.ImVec2(800, 600), ig.lib.ImGuiCond_FirstUseEver);
    if (ig.BeginTabBar("##Tabs", ig.lib.ImGuiTabBarFlags_None)) then
		local opened =  ffi.new("bool[?]",1,true)
        for i,v in ipairs(opendocs) do
			local opentab = ig.BeginTabItem(v.shrt_name.."##"..i, opened,(i==set_tab) and ig.lib.ImGuiTabItemFlags_SetSelected or 0)
			if ig.IsItemHovered() then ig.SetTooltip(v.file_name) end
			if opentab then
                if set_tab == i then set_tab = -1 end
                curr_opendoc = i
                v:Render()
                ig.EndTabItem();
            end
			if not opened[0] then 
				doclosefile = true
				break
			end
        end
        ig.EndTabBar();
    end
	local doit = false
	if doclosefile then 
		doit = CheckCloseEditor(curr_opendoc)
	end
	if confirm_close.draw(doit) then
		CloseEditor(curr_opendoc)
	end

    ig.End()
	
end

win:start()