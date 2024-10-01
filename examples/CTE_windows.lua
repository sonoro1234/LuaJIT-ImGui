local igwin = require"imgui.window"
--local win = igwin:SDL(800,600, "ColorTextEditor",{vsync=true,use_imgui_viewport=true})
local win = igwin:GLFW(800,600, "ColorTextEditor",{vsync=true,use_imgui_viewport=true})

local CTE = require"libs.CTEwindow"(win.ig)

local opendocs = {}
local opendocfnames = {}
local new_doc = -1
local function addEditor(fullname)
		if opendocfnames[fullname] then return end -- to avoid reopening
		opendocfnames[fullname] = true
        local doc = CTE.CTEwindow(fullname)
        table.insert(opendocs,doc);
        new_doc = #opendocs
		doc.shrt_name = fullname:match([[([^/\]+)$]])
        print("load",fullname,new_doc) 
end

local gui = require"libs.filebrowser"(win.ig)
local fb = gui.FileBrowser(nil,{key="loader",pattern=nil},
    function(fullname,dir,fname)
		addEditor(fullname)
    end)

--add two editors
addEditor(gui.pathut.abspath([[../cimgui/imgui/imgui.cpp]]))
addEditor(gui.pathut.abspath("CTE_sample.lua"))

local ffi = require"ffi"
local curr_opendoc = 1

function win:draw(ig)
    ig.ShowDemoWindow()
    
    local openfilepopup = false
    ig.Begin("Documents",nil,ig.lib.ImGuiWindowFlags_MenuBar)
        if (ig.BeginMenuBar()) then
            if (ig.BeginMenu("File")) then
                if (ig.MenuItem("Load")) then
                    openfilepopup = true
                end
                if (ig.MenuItem("Close")) then
                    local doc = table.remove(opendocs,curr_opendoc)
					opendocfnames[doc.file_name] = nil
                end
                ig.EndMenu();
            end
        ig.EndMenuBar()
    end
    if openfilepopup then fb.open() end
    fb.draw()

    ig.SetWindowSize(ig.ImVec2(800, 600), ig.lib.ImGuiCond_FirstUseEver);
    if (ig.BeginTabBar("##Tabs", ig.lib.ImGuiTabBarFlags_None)) then
        for i,v in ipairs(opendocs) do
            --if (ig.BeginTabItem(v.file_name)) then
            --if (ig.BeginTabItem(v.file_name,ffi.new("bool[?]",1,i==curr_opendoc))) then
            --if (ig.BeginTabItem(v.file_name, nil,(i==curr_opendoc) and ig.lib.ImGuiTabItemFlags_SetSelected or 0)) then
            if (ig.BeginTabItem(v.shrt_name.."##"..i, nil,(i==new_doc) and ig.lib.ImGuiTabItemFlags_SetSelected or 0)) then
                if new_doc == i then new_doc = -1 end
                curr_opendoc = i
                v:Render()
                ig.EndTabItem();
            end
        end
        ig.EndTabBar();
    end
    ig.End()
end

win:start()