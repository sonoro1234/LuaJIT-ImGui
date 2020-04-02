local ffi = require "ffi"

---------------------------------------------FileBrowser---------------------------------------
-- plain luafilesystem
--local lfs = require"lfs"
-- or to get unicode lfs with luajit
-- https://github.com/sonoro1234/luafilesystem
local lfs = require"lfs_ffi"
   --------------path utilities extracted from penligth (Steve Donovan)
local M = {}
local is_windows = package.config:sub(1,1) == '\\'
local function isabs(P)
    if is_windows then
        return P:sub(1,1) == '/' or P:sub(1,1)=='\\' or P:sub(2,2)==':'
    else
        return P:sub(1,1) == '/'
    end
end
local sep = is_windows and '\\' or '/'
M.sep = sep
local np_gen1, np_gen2 = '[^SEP]+SEP%.%.SEP?', 'SEP+%.?SEP'
local np_pat1, np_pat2 = np_gen1:gsub('SEP',sep) , np_gen2:gsub('SEP',sep)
local function normpath(P)
    if is_windows then
        if P:match '^\\\\' then -- UNC
            return '\\\\'..normpath(P:sub(3))
        end
        P = P:gsub('/','\\')
    end
    local k
    repeat -- /./ -> /
        P,k = P:gsub(np_pat2,sep)
    until k == 0
    repeat -- A/../ -> (empty)
        P,k = P:gsub(np_pat1,'')
    until k == 0
    if P == '' then P = '.' end
    return P
end
local function abspath(P)
    local pwd = lfs.currentdir()
    if not isabs(P) then
        P = pwd..sep..P
    elseif is_windows  and P:sub(2,2) ~= ':' and P:sub(2,2) ~= '\\' then
        P = pwd:sub(1,2)..P -- attach current drive to path like '\\fred.txt'
    end
    return normpath(P)
end
M.abspath = abspath
function M.chain(...)
    local res={}
    for i=1, select('#', ...) do
        local t = select(i, ...)
        table.insert(res,t)
    end
    return table.concat(res,sep)
end
local function splitpath(P)
    return P:match("(.+)"..sep.."([^"..sep.."]+)")
end
function M.this_script_path()
    return splitpath(abspath(arg[0])) --.. sep
end
local pathut = M

function loader(ig)
    -----------------------YesNo dialog ---------------
local gui = {}
function gui.YesNo(msg)
    local D = {}
    function D.open() 
        ig.OpenPopup("yesno") 
    end
    function D.draw(doit)
        local resp = doit
        if ig.BeginPopupModal("yesno",nil,0) then
            ig.Text(msg)
            if ig.Button("yes") then
                resp = true
                ig.CloseCurrentPopup(); 
            end
            ig.SameLine()
            if ig.Button("no") then
                resp = false
                ig.CloseCurrentPopup(); 
            end
            ig.EndPopup()
        end
        return resp
    end
    return D
end
--filename_p char pointer to get filename
-- funcOK function called on selection
--args.key, args.curr_dir, args.pattern, args.filename, args.check_existence
function gui.FileBrowser(filename_p, args, funcOK)
    
    args = args or {}
    args.key = args.key or "filechooser"
    local pattern_ed = ffi.new"char[32]"
    ffi.copy(pattern_ed, args.pattern or "" )
    local pathut = M --require"anima.path"
    local curr_dir = args.curr_dir or pathut.this_script_path() 
    local curr_dir_ed = ffi.new("char[256]")
    ffi.copy(curr_dir_ed, curr_dir )
    
    local curr_dir_done = false
    local curr_dir_files = {}
    local curr_dir_dirs = {}
    local fullname
    
    local function funcdir(path, patt)
        for file in lfs.dir(path) do
            if file ~= "."  then --and file ~= ".." then
                    local f = pathut.chain(path,file)
                    local attr = lfs.attributes (f)
                    assert (type(attr) == "table")
                    if attr.mode == "directory" then
                        table.insert(curr_dir_dirs, {path=f,name=file,is_dir=true})
                    elseif (not patt) or file:match(patt) then
                        table.insert(curr_dir_files, {path=f,name=file,is_dir=false})
                    end
            end
        end
    end
    
    local yesnoD = gui.YesNo("overwrite?")
    
    --local regionsize = ffi.new("ImVec2[1]")
    local save_file_name = ffi.new("char[256]",args.filename or "")
    local function filechooser()
    
        
        if (ig.BeginPopupModal(args.key, nil, 0)) then 

            local tsize = ig.CalcTextSize(curr_dir_ed, nil,false, -1.0);
            ig.PushItemWidth(tsize.x + ig.GetStyle().ItemInnerSpacing.x * 2)
            if ig.InputText("##dir",curr_dir_ed,256,0,nil,nil) then
                curr_dir = ffi.string(curr_dir_ed)
                curr_dir_done = false 
            end
            ig.PopItemWidth()
            
            if not curr_dir_done then
                curr_dir_files , curr_dir_dirs = {},{} 
                funcdir(curr_dir,ffi.string(pattern_ed))
                curr_dir_done = true
            end
            
            local regionsize = ig.GetContentRegionAvail()
            local desiredY = math.max(regionsize.y - ig.GetFrameHeightWithSpacing()*3,200)
            ig.BeginChild("files", ig.ImVec2(0,desiredY), true, 0)
            
            for i,v in ipairs(curr_dir_dirs) do
                if(ig.Selectable(v.name.." ->",false,ig.lib.ImGuiSelectableFlags_AllowDoubleClick,ig.ImVec2(0,0))) then 
                    if (ig.IsMouseDoubleClicked(0)) then
                            ffi.copy(save_file_name, "")
                            curr_dir = pathut.abspath(v.path)
                            ffi.copy(curr_dir_ed,curr_dir)
                            curr_dir_done = false
                    end
                end
            end
            for i,v in ipairs(curr_dir_files) do
                if(ig.Selectable(v.name,false,ig.lib.ImGuiSelectableFlags_AllowDoubleClick,ig.ImVec2(0,0))) then
                    if (ig.IsMouseDoubleClicked(0)) then
                        ffi.copy(save_file_name, v.name)
                    end
                end
                
            end
            ig.EndChild()
            
            ig.InputText("file",save_file_name,256)
            if ig.InputText("pattern",pattern_ed,32,ig.lib.ImGuiInputTextFlags_EnterReturnsTrue) then curr_dir_done = false end
            local doit = false
            
            if ig.Button("OK") then
                local savefilename = save_file_name~=nil and ffi.string(save_file_name) or nil
                fullname = ""
                if #savefilename > 0 then
                    fullname = pathut.chain(curr_dir,savefilename)
                    if args.check_existence then
                        if lfs.attributes(fullname) then
                            print("check_existence true",fullname)
                            yesnoD.open()
                        else
                            print("check_existence false",fullname)
                            doit = true
                        end
                    else
                        doit = true
                    end
                else
                    ig.CloseCurrentPopup(); 
                end
            end
            doit = yesnoD.draw(doit)
            if doit then
                if funcOK then
                    funcOK(fullname)
                else
                    filename_p[0] = fullname
                end
                ig.CloseCurrentPopup();
            end
            ig.SameLine()
            if ig.Button("CANCEL") then 
                ig.CloseCurrentPopup(); 
            end
            ig.EndPopup()
    
        end
    end
    return {draw = filechooser, open = function() curr_dir_done = false;ig.OpenPopup(args.key) end,func = funcOK}
end

return gui
end

return loader