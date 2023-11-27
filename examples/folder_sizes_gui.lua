
local lfs = require"lfs_ffi"
--lfs.unicode = false
local function preparepath(patt)
	if not patt then return end
	for i,v in ipairs(patt) do
		v:gsub("%.","%.")
	end
end
local sep = "/"

local function funcdir(path, func, patt, recur, funcd, tree)
	--print(path, func, patt, recur, funcd, tree)
	if type(patt)=="string" then patt = {patt} end
	if not tree then preparepath(patt) end --if first time
	tree = tree or ""
    for file,obj in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local f = path..sep..file
            local attr = lfs.attributes (f)
			--local attr = obj and obj:attr() or lfs.attributes (f)
			assert (type(attr) == "table",f)
            if attr.mode == "directory" then
				if funcd then funcd(f,file,attr,tree) end
				if recur then
					local newtree = (tree == "") and file or tree..sep..file
					--funcdir(f, func, patt, recur, funcd, newtree)
					local ok,err = pcall(funcdir,f, func, patt, recur, funcd, newtree)
					if not ok then 
						print("--------------------------------error on",f)
						print(err)
						--prtable(attr)
					else
						func(f, file, attr, tree, newtree)
					end
				end
            elseif (not patt) or matchpath(file,patt) then
				func(f, file, attr, tree)
            end
        end
    end
end


local function ffd(f, file, attr, tree)
	--curdir = f
	--print("dir",f,tree)
end

local dirsizes = {}
local function ff(f, file, attr, tree, newtree)
	if attr.mode == "directory" then
		dirsizes[tree] = (dirsizes[tree] or 0) + (dirsizes[newtree] or 0)
	else
		dirsizes[tree] = (dirsizes[tree] or 0) + attr.size
	end
end

local function get_sizes(inidir)
	local time1 = os.clock()
	dirsizes = {}
	funcdir(inidir, ff,nil, true,ffd)
	
	print("done",os.clock()-time1)
	local ssizes = {}
	for k,v in pairs(dirsizes) do
		ssizes[#ssizes + 1] = {dir=k,size=v}
	end
	
	table.sort(ssizes,function(a,b) return a.size > b.size end)
	return ssizes
end
----------------------------------------------------------
local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "dirsizes")
local win = igwin:GLFW(800,400, "dirsizes",{vsync=true})

local gui = require"filebrowser"(win.ig)

local thesizes = {}
local curdir = ""
local fb = gui.FileBrowser(nil,{key="loader",pattern=nil,choose_dir=true},function(fname,dir) 
	print("load",fname,dir); 
	thesizes = get_sizes(dir);
	curdir = dir
	end)


function win:draw(ig)
	ig.ShowDemoWindow()
	if ig.Begin"sizes" then
		if ig.SmallButton("load") then
			fb.open()
		end
		fb.draw()
		ig.SameLine()
		ig.TextUnformatted(curdir)
		if ig.BeginTable("dirsizes",2,ig.lib.ImGuiTableFlags_Sortable + ig.lib.ImGuiTableFlags_Borders + ig.lib.ImGuiTableFlags_RowBg + ig.lib.ImGuiTableFlags_ScrollY + ig.lib.ImGuiTableFlags_Resizable) then
			ig.TableSetupColumn("folder");
            ig.TableSetupColumn("size");
            ig.TableHeadersRow();
			local sort_specs = ig.TableGetSortSpecs();
			if sort_specs and sort_specs.SpecsDirty then 
				local col_specs = sort_specs.Specs[0]
				print(col_specs.ColumnUserID, col_specs.ColumnIndex, col_specs.SortOrder, col_specs.SortDirection);
				if col_specs.ColumnIndex == 0 then
					if col_specs.SortDirection == ig.lib.ImGuiSortDirection_Ascending then
						table.sort(thesizes,function(a,b) return a.dir < b.dir end)
					elseif col_specs.SortDirection == ig.lib.ImGuiSortDirection_Descending then
						table.sort(thesizes,function(a,b) return a.dir > b.dir end)
					end
				elseif col_specs.ColumnIndex == 1 then
					if col_specs.SortDirection == ig.lib.ImGuiSortDirection_Ascending then
						table.sort(thesizes,function(a,b) return a.size < b.size end)
					elseif col_specs.SortDirection == ig.lib.ImGuiSortDirection_Descending then
						table.sort(thesizes,function(a,b) return a.size > b.size end)
					end
				end
				
				sort_specs.SpecsDirty=false 
			end
			local clipper = ig.ImGuiListClipper()
			clipper:Begin(#thesizes)
			while (clipper:Step()) do
				for line = clipper.DisplayStart+1,clipper.DisplayEnd-1+1 do
					if line <= #thesizes then
					ig.TableNextRow()
					ig.TableNextColumn()
					ig.TextUnformatted(thesizes[line].dir)
					ig.TableNextColumn()
					ig.Text("%s",string.format("%d",thesizes[line].size))
					end
				end
			end
			clipper:End()
			-- for i,v in ipairs(thesizes) do
				-- ig.TableNextRow()
				-- ig.TableNextColumn()
				-- ig.TextUnformatted(v.dir)
				-- ig.TableNextColumn()
				-- ig.Text("%s",string.format("%d",v.size))
			-- end
			ig.EndTable()
		end
	end
	ig.End()
end

win:start()