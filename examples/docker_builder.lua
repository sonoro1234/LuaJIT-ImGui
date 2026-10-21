local igwin = require"imgui.window"

--local win = igwin:SDL(800,400, "docker_builder",{vsync=true})
local win = igwin:GLFW(800,400, "docker_builder",{vsync=true, not_main_dock_space = true})
local ffi = require"ffi"
win.ig.GetIO().IniFilename = "docker_builder.ini"

local view_dock = true

local ig = win.ig
local function Dock(dockspace_id)
	local lib = ig.lib
	local viewport = ig.GetMainViewport();
	if (ig.DockBuilderGetNode(dockspace_id) == nil)
	then

		ig.DockBuilderAddNode(dockspace_id, lib.ImGuiDockNodeFlags_DockSpace);
		ig.DockBuilderSetNodeSize(dockspace_id, viewport.Size);
		local dock_id_left = ffi.new("ImGuiID[?]",1,0);
		local dock_id_left_bottom = ffi.new("ImGuiID[?]",1,0);
		local dock_id_right = ffi.new("ImGuiID[?]",1,0);
		local dock_id_main = ffi.new("ImGuiID[?]",1,dockspace_id)--dockspace_id;
		ig.DockBuilderSplitNode(dock_id_main[0], lib.ImGuiDir_Left, 0.20, dock_id_left, dock_id_right);
		local dock_id_left_top = ffi.new("ImGuiID[?]",1,0);
		ig.DockBuilderSplitNode(dock_id_left[0], lib.ImGuiDir_Up, 0.50, dock_id_left_top, dock_id_left_bottom);
		ig.DockBuilderDockWindow("Game", dock_id_right[0]);
		ig.DockBuilderDockWindow("Properties", dock_id_left_top[0]);
		ig.DockBuilderDockWindow("Scene", dock_id_left_bottom[0]);
		ig.DockBuilderFinish(dockspace_id);
	end

	--// Submit dockspace
	ig.DockSpaceOverViewport(dockspace_id, viewport, lib.ImGuiDockNodeFlags_PassthruCentralNode);
end

local function UnDock(dockspace_id)
	ig.DockBuilderRemoveNode(dockspace_id)
end

function win:draw(ig)
	--ig.ShowDemoWindow()
	-----------------------
	-- local ctx = ig.GetCurrentContext()
	-- ctx.DebugLogFlags = bit.bor(ctx.DebugLogFlags , ig.lib.ImGuiDebugLogFlags_EventDocking)
	-- ig.ShowDebugLogWindow()
	-----------------------

	local dockspace_id = ig.GetID("dockspace_id")
	
    if ig.IsKeyPressed(ig.lib.ImGuiKey_F3,false) then
		view_dock = not view_dock
		if not view_dock then
			UnDock(dockspace_id)
		end
    end
	
    if (ig.BeginMainMenuBar()) then
		if ig.BeginMenu("dock") then
		if ig.MenuItem("view_dock","F3") then
			view_dock = not view_dock
			if not view_dock then
				UnDock(dockspace_id)
			end
		end
		ig.EndMenu()
		end
       ig.EndMainMenuBar()
    end
	
	if view_dock then
		Dock(dockspace_id)
		
		--// Submit windows
		ig.Begin("Properties",nil,ig.lib.ImGuiWindowFlags_NoMove);
		ig.TextWrapped("1 Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ");
		ig.End()
		
		ig.Begin("Game");
		ig.TextWrapped("2 Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ");
		ig.End()
	end

	if ig.Begin("Scene",nil,ig.lib.ImGuiWindowFlags_AlwaysAutoResize) then
		ig.TextWrapped("3 Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ");
	end
	ig.End()
	
end

win:start()