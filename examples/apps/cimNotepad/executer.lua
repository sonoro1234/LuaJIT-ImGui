--WINUSEPTHREAD=true --this sets WINUSEPTHREAD for windows

---------get LuaJIT path
local function get_executable(arg)
    local i=0
    local v
    while true do 
        v = arg[i]
        if not v then
            i = i + 1 --was the last (inverse order)
            break
        end
        i = i - 1
    end
    return arg[i]
end
---------for out process
local pathut = require"imgui.libs.path"
local file_path = pathut.file_path()

local os_execute_async = function(executable, cmd, inprocess, K, debuggerlinda, breakpoints, do_debug , coop_cancel, jit_on, ...)
    --print("00000os_execute_async",executable, cmd, inprocess, K, debuggerlinda, breakpoints, do_debug, coop_cancel)
    local pathut = require"imgui.libs.path"
    local Thread = require"lj-async.thread"
    local Kmaker = require"lj-async.keeper"
    --FINALIZER = function(ok,val) print("---i am executer finalizer",ok,val) end
    K = Kmaker.KeeperCast(K)
    debuggerlinda = Kmaker.KeeperCast(debuggerlinda)
    local args = {...}
    return function(ud)
        local ffi = require"ffi"
        
        local ret
        if inprocess then
        --------loadstring bad for same process sdl or glfw
        local f,err = loadfile(pathut.chain(file_path,"runner.lua"))--cmd)
        if f then 
            if not jit_on then jit.off() end
            ret = f()(cmd, K, debuggerlinda, breakpoints, do_debug) 
        else 
            K:send("clave","loadfile error:"..tostring(err)) 
        end

        else 
        --not inprocess
        --print"=====not in process------------"
        ---for another process we have:
        ------- 1 execute
        -- but needs ipc 
        -- local ret = os.execute(executable.." ".." ./libs/runner.lua "..cmd)
        
        -------- 2 popen
        -- debuggerlinda cant be used so that a file is opened by runner and will read deblindaS
        local serializer = require"imgui.libs.serializer"
        --print"=====not in process------------2"
        --send initial breakpoits via a file which runner will get
        if do_debug then
            local breakstr = serializer("tab_name",breakpoints,";")..";return tab_name;"
            local f,err = io.open(file_path.."/breakpoints","w")
            assert(f,err)
            f:write(breakstr)
            f:close()
        else
            os.remove(file_path.."/breakpoints")
        end
        
        --local jitstr = coop_cancel and "-j off" or ""
        local jitstr = jit_on and "" or "-j off" 
        local pcomand = executable.." "..jitstr.." "..pathut.chain(file_path,"runner.lua").." "..cmd
        --print("==========pcomand",pcomand)
        if jit.os == "Windows" then pcomand = [["]]..pcomand..[["]] end

        local exe,err = io.popen(pcomand, "r")
        if not exe then
            K:send("clave","Could not popen. Error: "..tostring(err))
        else
            exe:setvbuf("no")
            repeat
                exe:flush()
                local line = exe:read("*l")
                if line then
                    if line == "" then
                    elseif line:match"^debuggerXXXX" then
                        local value = line:match("debuggerXXXX(.+)")
                        K:send("debuggerXXXX", value)
                    elseif line:match"^eretXXXX" then
                        ret = line:match("^eretXXXX(.+)")
                    else 
                        K:send("clave",line) 
                    end
                else
                    break
                end
            until false
            exe:close()
        end
        --ret = err 
        end

        --print("executer finishig", ret)
        if ret then return Thread._return(tonumber(ret)) end
    end
end

----------------------------------------------------------------------
local hasThread, Thread = pcall(require, "lj-async.thread")

local executable = get_executable(arg)
---------for in process
local Kmaker = require"lj-async.keeper"
local K = Kmaker.MakeKeeper()
local debuggerlinda = Kmaker.MakeKeeper()

---------for out process
local serializer = require"imgui.libs.serializer"
--  print("executer file_path:",file_path)

--- for out process sends to deblinda in runner
local deblindaS = {}
function deblindaS:init()
    self.file,err = io.open(pathut.chain(file_path,"debuggerlinda"),"w")
    assert(self.file, err)
end
function deblindaS:close()
    if self.file then
        self.file:close()
    end
end

function deblindaS:send(key, value)
    if type(value)=="table" then
        value = "TABLE"..serializer("ttt",value,";").."return ttt;"
    end
    self.file:write("key"..tostring(key).."value"..tostring(value).."\n")
    self.file:flush()
end

Execute = function(self, cmd, inprocess, breakpoints, do_debug, coop_cancel, jit_on)
    self.Log:Clear()
    self.setStack() -- clear Stack

    local func = os_execute_async
    if coop_cancel then
        func = {os_execute_async}
    end
    local thread = Thread(func, nil,executable, cmd, inprocess, K, debuggerlinda, breakpoints, do_debug, coop_cancel, jit_on)

    return thread
end

local deb_wait = false
ExecutePull = function(self)
    while true do
        local key,value = K:receive("debuggerXXXX","debugger","clave") 
        if key then
            if key == "debuggerXXXX" then
                local f,err = loadstring(value)
                --assert(f,err)
                if not f then print(err);print(value);break end
                value = f()
                local Stack = value[3]
                local _error = value[4]
                local vars = value[5]
                local compile_err = value[6]
                -- not needed with keepper with cycles
                -- local f,err = loadstring(vars)
                -- assert(f,err)
                -- vars = f()
                self.setStack(value[1], value[2],Stack, _error, vars,compile_err)
                deb_wait = true
            elseif key == "debugger" then
                local Stack = value[3]
                local _error = value[4]
                local vars = value[5]
                local compile_err = value[6]
                -- not needed with keepper with cycles
                -- local f,err = loadstring(vars)
                -- assert(f,err)
                -- vars = f()
                self.setStack(value[1], value[2],Stack, _error, vars, compile_err)
                deb_wait = true
            else
                --self.Log:Add(string.format("-- %s: %s\n", key,value))
                self.Log:Add(string.format("%s\n",value))
            end
        else
            break
        end
    end
    if self.runningThread then
            local ok, err = self.runningThread:join(0.01, true) --true for getting number
            if ok then
                local color
               
                if err == 1 then
                    self.setStack() -- clear Stack
                    self.notifications:Add(self.notifications.Type.success, "Execute finished",10);
                    color = self.ig.U32(0,1,0,1)
                elseif err==2 then
                    self.notifications:Add(self.notifications.Type.warning, "Compile error",10);
                    color = self.ig.U32(1,1,0,1)
                elseif err==3 then
                    self.notifications:Add(self.notifications.Type.error, "Execute error",10);
                    color = self.ig.U32(1,0,0,1)
                elseif err==4 then
                    self.notifications:Add(self.notifications.Type.error, "stack overflow",10);
                    color = self.ig.U32(1,0,1,1)
                    self.Log:Add(string.format("stack overflow in %q \n", self.shrt_name), color)
                end
                self.Log:Add(string.format("Joined %q %d\n", self.shrt_name, tonumber(err) or -1), color)
                self.runningThread:free()
                self.runningThread = false
                deb_wait = false
            elseif not err then
                --print("  Timed out")
            else
                print("  Error:")
                print(err)
            end
    end
end

-- the used debugger linda
-- debuggerlinda or deblindaS
local deblinda

local function send_breakpoint(bp)
    if deblinda then
        deblinda:send("brpoints",bp)
    end
end


local ffi = require"ffi"
local do_debug = ffi.new("bool[?]",1,true)
local inprocess = ffi.new("bool[?]",1,true)
local coop_cancel = ffi.new("bool[?]",1,false)
local jit_on = ffi.new("bool[?]",1,false)

local function renderMenuExecute(self, curdoc)
    self.file_name = self.opendocs[curdoc] and self.opendocs[curdoc].file_name or nil
    self.shrt_name = self.opendocs[curdoc] and self.opendocs[curdoc].shrt_name or nil
    self.ext = self.opendocs[curdoc] and self.opendocs[curdoc].ext or nil
    
    local function MenuExecute()
        deb_wait = false
        if inprocess[0] then
            deblinda = debuggerlinda
            local thread = Execute(self, self.file_name, true, self.getBreakPoints(), do_debug[0], coop_cancel[0], jit_on[0])
            self.runningThread = thread
        else
            deblindaS:close()
            deblindaS:init()
            deblinda = deblindaS
            local thread = Execute(self, self.file_name, false, self.getBreakPoints(), do_debug[0], coop_cancel[0], jit_on[0])
            self.runningThread = thread
        end
    end
    local ig = self.ig
    local function is_running()
        return self.runningThread and true --or false
    end
    
    if (ig.BeginMainMenuBar()) then
    if (ig.BeginMenu("Execute", self.file_name~=nil and executable and hasThread and self.ext=="lua"))  then 
            --print(deb_wait, self.runningThread,do_debug[0], deb_wait and self.runningThread and (do_debug[0] or false))
            if (ig.MenuItem("Execute", "F6", nil, not is_running()))  then
                MenuExecute()
            end
            ig.Separator()
            if ig.BeginMenu("Hooks", not is_running()) then
                if ig.MenuItem("Debug", nil, do_debug) then coop_cancel[0] = false end
                if ig.MenuItem("Coop cancel", nil, coop_cancel, inprocess[0]) then do_debug[0] = false end
                ig.EndMenu()
            end
            if ig.MenuItem("In process", nil, inprocess , not is_running()) then
                if not inprocess[0] then coop_cancel[0] = false end
            end
            if ig.MenuItem("Jit on", nil, jit_on , not is_running()) then

            end

            ig.Separator()
            if (ig.MenuItem("continue", "F9", nil, deb_wait and is_running() and do_debug[0]))  then 
                deblinda:send("continue",true)
                deb_wait = false
            end 
            --if (ig.MenuItem("break", nil, nil, (not deb_wait) and self.runningThread and do_debug[0]))  then 
            if ig.MenuItem("cancel", nil, nil, (not deb_wait) and is_running() and (do_debug[0] or (coop_cancel[0] and inprocess[0])))  then 
                if do_debug[0] then
                    deblinda:send("cancel",true)
                else
                    self.runningThread:cancel()
                end
            end 
            if (ig.MenuItem("break", nil, nil, (not deb_wait) and is_running() and do_debug[0]))  then 
                deblinda:send("break",true)
            end 
            if (ig.MenuItem("debug_exit", nil, nil, is_running() and do_debug[0]))  then 
                deblinda:send("debug_exit",true)
                do_debug[0] = false
            end 
            if (ig.MenuItem("step_into", "F10", nil, deb_wait and is_running() and do_debug[0]))  then 
                deblinda:send("step_into",true)
            end
            if (ig.MenuItem("step_over", "Shift-F10", nil, deb_wait and is_running() and do_debug[0]))  then 
                deblinda:send("step_over",true)
            end
            if (ig.MenuItem("step_out", "Ctrl-F10", nil, deb_wait and is_running() and do_debug[0]))  then 
                deblinda:send("step_out",true)
            end
        ig.EndMenu();
    end 
        ig.EndMainMenuBar()
    end
    if ig.Shortcut(ig.lib.ImGuiKey_F6) then
        if not is_running() then
            MenuExecute()
        end
    end
    if ig.Shortcut(ig.lib.ImGuiKey_F9) then
        if deb_wait and is_running() and do_debug[0] then
            deblinda:send("continue",true)
        end
    end
    if ig.Shortcut(ig.lib.ImGuiKey_F10) then
        if deb_wait and is_running() and do_debug[0] then
            deblinda:send("step_into",true)
        end
    end
    if ig.Shortcut(bit.bor(ig.lib.ImGuiMod_Ctrl, ig.lib.ImGuiKey_F10)) then
        if deb_wait and is_running() and do_debug[0] then
            deblinda:send("step_out",true)
        end
    end
    if ig.Shortcut(bit.bor(ig.lib.ImGuiMod_Shift, ig.lib.ImGuiKey_F10)) then
        if deb_wait and is_running() and do_debug[0] then
            deblinda:send("step_over",true)
        end
    end
end

if not hasThread then
    return {Execute = nil, ExecutePull = function() end, debuggerlinda = debuggerlinda, hasThread = hasThread, renderMenuExecute = renderMenuExecute}
else
return {Execute = Execute, ExecutePull = ExecutePull, send_breakpoint = send_breakpoint, executable = executable, hasThread = hasThread, renderMenuExecute = renderMenuExecute}
end
