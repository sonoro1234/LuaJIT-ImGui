local igwin = require"imgui.window"

--local win = igwin:SDL(800,400, "dock_lock",{vsync=true})
local win = igwin:GLFW(800,400, "dock_lock",{vsync=true})

local ffi = require"ffi"
local lock = ffi.new("bool[1]",true);

win.ig.GetIO().IniFilename = "docklock4.ini"

local wndclass = win.ig.ImGuiWindowClass()
wndclass.DockNodeFlagsOverrideSet = win.ig.lib.ImGuiWindowFlags_NoMove 
function win:draw(ig)
    local redock_all = false;
    local dFlags = win.ig.lib.ImGuiDockNodeFlags_None
    local wndflags = 0
    ig.Begin("Main Window");
  
        ig.Checkbox("no move panes", lock);
        if (lock[0]) then
            --dFlags = dFlags + ig.lib.ImGuiDockNodeFlags_NoResize;
            -- Is there a flag that will disable undocking while keeping the current docked state?
            wndflags = ig.lib.ImGuiWindowFlags_NoMove
        end
    
        ig.SameLine(); redock_all = ig.Button("Redock all"); 
        
        local dockspaceID = ig.GetID("HUB_DockSpace");
        ig.DockSpace(dockspaceID, ig.ImVec2(0.0, 0.0), dFlags + ig.lib.ImGuiDockNodeFlags_PassthruCentralNode);
        ig.SetNextWindowDockID(dockspaceID, redock_all and ig.lib.ImGuiCond_Always or ig.lib.ImGuiCond_FirstUseEver);
        --ig.SetNextWindowClass(wndclass);
        ig.Begin("Some window 1",nil,wndflags);
            ig.TextUnformatted("docked1:"..tostring(ig.IsWindowDocked()))
        ig.End();
        ig.SetNextWindowDockID(dockspaceID, redock_all and ig.lib.ImGuiCond_Always or ig.lib.ImGuiCond_FirstUseEver);
        ig.Begin("Some window 2",nil,wndflags);
            ig.TextUnformatted("docked2:"..tostring(ig.IsWindowDocked()))
        ig.End();  
        ig.SetNextWindowDockID(dockspaceID, redock_all and ig.lib.ImGuiCond_Always or ig.lib.ImGuiCond_FirstUseEver);
        ig.Begin("Some window 3",nil,wndflags);
            ig.TextUnformatted("docked3:"..tostring(ig.IsWindowDocked()))
        ig.End();

    ig.End();
  
    ig.ShowDemoWindow()
end


win:start(clean)