local ffi = require"ffi"
local cdecl = require"imgui.cdefs"

local ffi_cdef = function(code)
    local ret,err = pcall(ffi.cdef,code)
    if not ret then
        local lineN = 1
        for line in code:gmatch("([^\n\r]*)\r?\n") do
            print(lineN, line)
            lineN = lineN + 1
        end
        print(err)
        error"bad cdef"
    end
end


assert(cdecl, "imgui.lua not properly build")
ffi.cdef(cdecl)


--load dll
local lib = ffi.load(cimguimodule)

-----------ImVec2 definition
local ImVec2
ImVec2 = {
    __add = function(a,b) return ImVec2(a.x + b.x, a.y + b.y) end,
    __sub = function(a,b) return ImVec2(a.x - b.x, a.y - b.y) end,
    __unm = function(a) return ImVec2(-a.x,-a.y) end,
    __mul = function(a, b) --scalar mult
        if not ffi.istype(ImVec2, b) then
        return ImVec2(a.x * b, a.y * b) end
        return ImVec2(a * b.x, a * b.y)
    end,
	norm = function(a)
		return math.sqrt(a.x*a.x+a.y*a.y)
	end,
    __tostring = function(v) return 'ImVec2<'..v.x..','..v.y..'>' end
}
ImVec2.__index = ImVec2
ImVec2 = ffi.metatype("ImVec2",ImVec2)
local ImVec4= {}
ImVec4.__index = ImVec4
ImVec4 = ffi.metatype("ImVec4",ImVec4)
--the module
local M = {ImVec2 = ImVec2, ImVec4 = ImVec4 ,lib = lib}

if jit.os == "Windows" then
    function M.ToUTF(unc_str)
        local buf_len = lib.igImTextCountUtf8BytesFromStr(unc_str, nil) + 1;
        local buf_local = ffi.new("char[?]",buf_len)
        lib.igImTextStrToUtf8(buf_local, buf_len, unc_str, nil);
        return buf_local
    end
    
    function M.FromUTF(utf_str)
        local wbuf_length = lib.igImTextCountCharsFromUtf8(utf_str, nil) + 1;
        local buf_local = ffi.new("ImWchar[?]",wbuf_length)
        lib.igImTextStrFromUtf8(buf_local, wbuf_length, utf_str, nil,nil);
        return buf_local
    end
end

M.FLT_MAX = lib.igGET_FLT_MAX()
M.FLT_MIN = lib.igGET_FLT_MIN()

-----------ImGui_ImplGlfwGL3
local ImGui_ImplGlfwGL3 = {}
ImGui_ImplGlfwGL3.__index = ImGui_ImplGlfwGL3

local gl3w_inited = false
function ImGui_ImplGlfwGL3.__new()
    if gl3w_inited == false then
        lib.Do_gl3wInit()
        gl3w_inited = true
    end
    local ptr = lib.ImGui_ImplGlfwGL3_new()
    ffi.gc(ptr,lib.ImGui_ImplGlfwGL3_delete)
    return ptr
end

function ImGui_ImplGlfwGL3:destroy()
    ffi.gc(self,nil) --prevent gc twice
    lib.ImGui_ImplGlfwGL3_delete(self)
end

function ImGui_ImplGlfwGL3:NewFrame()
    return lib.ImGui_ImplGlfwGL3_NewFrame(self)
end

function ImGui_ImplGlfwGL3:Render()
    return lib.ImGui_ImplGlfwGL3_Render(self)
end

function ImGui_ImplGlfwGL3:Init(window, install_callbacks)
    return lib.ImGui_ImplGlfwGL3_Init(self, window,install_callbacks);
end

function ImGui_ImplGlfwGL3.KeyCallback(window, key,scancode, action, mods)
    return lib.ImGui_ImplGlfwGL3_KeyCallback(window, key,scancode, action, mods);
end

function ImGui_ImplGlfwGL3.MouseButtonCallback(win, button, action, mods)
    return lib.ImGui_ImplGlfwGL3_MouseButtonCallback(win, button, action, mods)
end

function ImGui_ImplGlfwGL3.ScrollCallback(window,xoffset,yoffset)
    return lib.ImGui_ImplGlfwGL3_MouseButtonCallback(window,xoffset,yoffset)
end

function ImGui_ImplGlfwGL3.CharCallback(window,c)
    return lib.ImGui_ImplGlfwGL3_CharCallback(window, c);
end

M.ImplGlfwGL3 = ffi.metatype("ImGui_ImplGlfwGL3",ImGui_ImplGlfwGL3)

-----------------------Imgui_Impl_SDL_opengl3
local Imgui_Impl_SDL_opengl3 = {}
Imgui_Impl_SDL_opengl3.__index = Imgui_Impl_SDL_opengl3

function Imgui_Impl_SDL_opengl3.__call()
    if gl3w_inited == false then
        lib.Do_gl3wInit()
        gl3w_inited = true
    end
    return setmetatable({ctx = lib.igCreateContext(nil)},Imgui_Impl_SDL_opengl3)
end

function Imgui_Impl_SDL_opengl3:Init(window, gl_context, glsl_version)
    self.window = window
	glsl_version = glsl_version or "#version 150"
    lib.ImGui_ImplSDL2_InitForOpenGL(window, gl_context);
    lib.ImGui_ImplOpenGL3_Init(glsl_version);
end

function Imgui_Impl_SDL_opengl3:destroy()
    lib.ImGui_ImplOpenGL3_Shutdown();
    lib.ImGui_ImplSDL2_Shutdown();
    lib.igDestroyContext(self.ctx);
end

function Imgui_Impl_SDL_opengl3:NewFrame()
    lib.ImGui_ImplOpenGL3_NewFrame();
    lib.ImGui_ImplSDL2_NewFrame(self.window);
    lib.igNewFrame();
end

function Imgui_Impl_SDL_opengl3:Render()
    lib.igRender()
    lib.ImGui_ImplOpenGL3_RenderDrawData(lib.igGetDrawData());
end
M.Imgui_Impl_SDL_opengl3 = setmetatable({},Imgui_Impl_SDL_opengl3)
-----------------------Imgui_Impl_SDL_opengl2
local Imgui_Impl_SDL_opengl2 = {}
Imgui_Impl_SDL_opengl2.__index = Imgui_Impl_SDL_opengl2

function Imgui_Impl_SDL_opengl2.__call()
    return setmetatable({ctx = lib.igCreateContext(nil)},Imgui_Impl_SDL_opengl2)
end

function Imgui_Impl_SDL_opengl2:Init(window, gl_context)
    self.window = window
    lib.ImGui_ImplSDL2_InitForOpenGL(window, gl_context);
    lib.ImGui_ImplOpenGL2_Init();
end

function Imgui_Impl_SDL_opengl2:destroy()
    lib.ImGui_ImplOpenGL2_Shutdown();
    lib.ImGui_ImplSDL2_Shutdown();
    lib.igDestroyContext(self.ctx);
end

function Imgui_Impl_SDL_opengl2:NewFrame()
    lib.ImGui_ImplOpenGL2_NewFrame();
    lib.ImGui_ImplSDL2_NewFrame(self.window);
    lib.igNewFrame();
end

function Imgui_Impl_SDL_opengl2:Render()
    lib.igRender()
    lib.ImGui_ImplOpenGL2_RenderDrawData(lib.igGetDrawData());
end
M.Imgui_Impl_SDL_opengl2 = setmetatable({},Imgui_Impl_SDL_opengl2)
-----------------------Imgui_Impl_glfw_opengl3
local Imgui_Impl_glfw_opengl3 = {}
Imgui_Impl_glfw_opengl3.__index = Imgui_Impl_glfw_opengl3

function Imgui_Impl_glfw_opengl3.__call()
    if gl3w_inited == false then
        lib.Do_gl3wInit()
        gl3w_inited = true
    end
    return setmetatable({ctx = lib.igCreateContext(nil)},Imgui_Impl_glfw_opengl3)
end

function Imgui_Impl_glfw_opengl3:Init(window, install_callbacks,glsl_version)
	glsl_version = glsl_version or "#version 150"
    lib.ImGui_ImplGlfw_InitForOpenGL(window, install_callbacks);
    lib.ImGui_ImplOpenGL3_Init(glsl_version);
end

function Imgui_Impl_glfw_opengl3:destroy()
    lib.ImGui_ImplOpenGL3_Shutdown();
    lib.ImGui_ImplGlfw_Shutdown();
    lib.igDestroyContext(self.ctx);
end

function Imgui_Impl_glfw_opengl3:NewFrame()
    lib.ImGui_ImplOpenGL3_NewFrame();
    lib.ImGui_ImplGlfw_NewFrame();
    lib.igNewFrame();
end

function Imgui_Impl_glfw_opengl3:Render()
    lib.igRender()
    lib.ImGui_ImplOpenGL3_RenderDrawData(lib.igGetDrawData());
end

function Imgui_Impl_glfw_opengl3.KeyCallback(window, key,scancode, action, mods)
    return lib.ImGui_ImplGlfw_KeyCallback(window, key,scancode, action, mods);
end

function Imgui_Impl_glfw_opengl3.MouseButtonCallback(win, button, action, mods)
    return lib.ImGui_ImplGlfw_MouseButtonCallback(win, button, action, mods)
end

function Imgui_Impl_glfw_opengl3.ScrollCallback(window,xoffset,yoffset)
    return lib.ImGui_ImplGlfw_ScrollCallback(window,xoffset,yoffset)
end

function Imgui_Impl_glfw_opengl3.CharCallback(window,c)
    return lib.ImGui_ImplGlfw_CharCallback(window, c);
end

M.Imgui_Impl_glfw_opengl3 = setmetatable({},Imgui_Impl_glfw_opengl3)

-----------------------Imgui_Impl_glfw_opengl2
local Imgui_Impl_glfw_opengl2 = {}
Imgui_Impl_glfw_opengl2.__index = Imgui_Impl_glfw_opengl2

function Imgui_Impl_glfw_opengl2.__call()
    return setmetatable({ctx = lib.igCreateContext(nil)},Imgui_Impl_glfw_opengl2)
end

function Imgui_Impl_glfw_opengl2:Init(window, install_callbacks)
    lib.ImGui_ImplGlfw_InitForOpenGL(window, install_callbacks);
    lib.ImGui_ImplOpenGL2_Init();
end

function Imgui_Impl_glfw_opengl2:destroy()
    lib.ImGui_ImplOpenGL2_Shutdown();
    lib.ImGui_ImplGlfw_Shutdown();
    lib.igDestroyContext(self.ctx);
end

function Imgui_Impl_glfw_opengl2:NewFrame()
    lib.ImGui_ImplOpenGL2_NewFrame();
    lib.ImGui_ImplGlfw_NewFrame();
    lib.igNewFrame();
end

function Imgui_Impl_glfw_opengl2:Render()
    lib.igRender()
    lib.ImGui_ImplOpenGL2_RenderDrawData(lib.igGetDrawData());
end

function Imgui_Impl_glfw_opengl2.KeyCallback(window, key,scancode, action, mods)
    return lib.ImGui_ImplGlfw_KeyCallback(window, key,scancode, action, mods);
end

function Imgui_Impl_glfw_opengl2.MouseButtonCallback(win, button, action, mods)
    return lib.ImGui_ImplGlfw_MouseButtonCallback(win, button, action, mods)
end

function Imgui_Impl_glfw_opengl2.ScrollCallback(window,xoffset,yoffset)
    return lib.ImGui_ImplGlfw_ScrollCallback(window,xoffset,yoffset)
end

function Imgui_Impl_glfw_opengl2.CharCallback(window,c)
    return lib.ImGui_ImplGlfw_CharCallback(window, c);
end

M.Imgui_Impl_glfw_opengl2 = setmetatable({},Imgui_Impl_glfw_opengl2)
-----------------------another Log
local Log = {}
Log.__index = Log
function Log.__new()
    local ptr = lib.Log_new()
    ffi.gc(ptr,lib.Log_delete)
    return ptr
end
function Log:Add(fmt,...)
    lib.Log_Add(self,fmt,...)
end
function Log:Draw(title)
    title = title or "Log"
    lib.Log_Draw(self,title)
end
M.Log = ffi.metatype("Log",Log)
------------convenience function
function M.U32(a,b,c,d) return lib.igGetColorU32Vec4(ImVec4(a,b,c,d or 1)) end

-------------ImGuiZMO.quat

function M.mat4_cast(q)
	local nonUDT_out = ffi.new("Mat4")
	lib.mat4_cast(q,nonUDT_out)
	return nonUDT_out
end
function M.mat4_pos_cast(q,pos)
	local nonUDT_out = ffi.new("Mat4")
	lib.mat4_pos_cast(q,pos,nonUDT_out)
	return nonUDT_out
end
function M.quat_cast(f)
	local nonUDT_out = ffi.new("quat")
	lib.quat_cast(f,nonUDT_out)
	return nonUDT_out
end
function M.quat_pos_cast(f)
	local nonUDT_out = ffi.new("quat")
	local nonUDT_pos = ffi.new("G3Dvec3")
	lib.quat_pos_cast(f,nonUDT_out,nonUDT_pos)
	return nonUDT_out,nonUDT_pos
end

--------------- several widgets------------
local sin, cos, atan2, pi, max, min,acos,sqrt = math.sin, math.cos, math.atan2, math.pi, math.max, math.min,math.acos,math.sqrt
function M.dial(label,value_p,sz, fac)

	fac = fac or 1
	sz = sz or 20
	local style = M.GetStyle()
	
	local p = M.GetCursorScreenPos();

	local radio =  sz*0.5
	local center = M.ImVec2(p.x + radio, p.y + radio)
	
	local x2 = cos(value_p[0]/fac)*radio + center.x
	local y2 = sin(value_p[0]/fac)*radio + center.y
	
	M.InvisibleButton(label.."t",M.ImVec2(sz, sz)) 
	local is_active = M.IsItemActive()
	local is_hovered = M.IsItemHovered()
	
	local touched = false
	if is_active then 
		touched = true
		local m = M.GetIO().MousePos
		local md = M.GetIO().MouseDelta
		if md.x == 0 and md.y == 0 then touched=false end
		local mp = M.ImVec2(m.x - md.x, m.y - md.y)
		local ax = mp.x - center.x
		local ay = mp.y - center.y
		local bx = m.x - center.x
		local by = m.y - center.y
		local ma = sqrt(ax*ax + ay*ay)
		local mb = sqrt(bx*bx + by*by)
		local ab  = ax * bx + ay * by;
		local vet = ax * by - bx * ay;
		ab = ab / (ma * mb);
		if not (ma == 0 or mb == 0 or ab < -1 or ab > 1) then

			if (vet>0) then
				value_p[0] = value_p[0] + acos(ab)*fac;
			else 
				value_p[0] = value_p[0] - acos(ab)*fac;
			end
		end
	end
	
	local col32idx = is_active and lib.ImGuiCol_FrameBgActive or (is_hovered and lib.ImGuiCol_FrameBgHovered or lib.ImGuiCol_FrameBg)
	local col32 = M.GetColorU32(col32idx, 1) 
	local col32line = M.GetColorU32(lib.ImGuiCol_SliderGrabActive, 1) 
	local draw_list = M.GetWindowDrawList();
	draw_list:AddCircleFilled( center, radio, col32, 16);
	draw_list:AddLine( center, M.ImVec2(x2, y2), col32line, 1);
	M.SameLine()
	M.PushItemWidth(50)
	if M.InputFloat(label, value_p, 0.0, 0.1) then
		touched = true
	end
	M.PopItemWidth()
	return touched
end

function M.Curve(name,numpoints,LUTsize,pressed_on_modified)
	if pressed_on_modified == nil then pressed_on_modified=true end
	numpoints = numpoints or 10
	LUTsize = LUTsize or 720
	local CU = {name = name,numpoints=numpoints,LUTsize=LUTsize}
	CU.LUT = ffi.new("float[?]",LUTsize)
	CU.LUT[0] = -1
	CU.points = ffi.new("ImVec2[?]",numpoints)
	CU.points[0].x = -1
	function CU:getpoints()
		local pts = {}
		for i=0,numpoints-1 do
			pts[i+1] = {x=CU.points[i].x,y=CU.points[i].y}
		end
		return pts
	end
	function CU:setpoints(pts)
		assert(#pts<=numpoints)
		for i=1,#pts do
			CU.points[i-1].x = pts[i].x
			CU.points[i-1].y = pts[i].y
		end
		CU.LUT[0] = -1
		lib.CurveGetData(CU.points, numpoints,CU.LUT, LUTsize )
	end
	function CU:get_data()
		CU.LUT[0] = -1
		lib.CurveGetData(CU.points, numpoints,CU.LUT, LUTsize )
	end
	function CU:draw(sz)
		sz = sz or M.ImVec2(200,200)
		return lib.Curve(name, sz,CU.points, CU.numpoints,CU.LUT, CU.LUTsize,pressed_on_modified) 
	end
	return CU
end


function M.pad(label,value,sz)
	local function clip(val,mini,maxi) return math.min(maxi,math.max(mini,val)) end
	sz = sz or 200
	local canvas_pos = M.GetCursorScreenPos();
	M.InvisibleButton(label.."t",M.ImVec2(sz, sz)) -- + style.ItemInnerSpacing.y))
	local is_active = M.IsItemActive()
	local is_hovered = M.IsItemHovered()
	local touched = false
	if is_active then
		touched = true
		local m = M.GetIO().MousePos
		local md = M.GetIO().MouseDelta
		if md.x == 0 and md.y == 0 and not M.IsMouseClicked(0,false) then touched=false end
		value[0] = ((m.x - canvas_pos.x)/sz)*2 - 1
		value[1] = (1.0 - (m.y - canvas_pos.y)/sz)*2 - 1
		value[0] = clip(value[0], -1,1)
		value[1] = clip(value[1], -1,1)
	end
	local draw_list = M.GetWindowDrawList();
	draw_list:AddRect(canvas_pos,canvas_pos+M.ImVec2(sz,sz),M.U32(1,0,0,1))
	draw_list:AddLine(canvas_pos + M.ImVec2(0,sz/2),canvas_pos + M.ImVec2(sz,sz/2) ,M.U32(1,0,0,1))
	draw_list:AddLine(canvas_pos + M.ImVec2(sz/2,0),canvas_pos + M.ImVec2(sz/2,sz) ,M.U32(1,0,0,1))
	draw_list:AddCircleFilled(canvas_pos + M.ImVec2((1+value[0])*sz,((1-value[1])*sz)+1)*0.5,5,M.U32(1,0,0,1))
	return touched
end

function M.Plotter(xmin,xmax,nvals)
	local Graph = {xmin=xmin or 0,xmax=xmax or 1,nvals=nvals or 400}
	function Graph:init()
		self.values = ffi.new("float[?]",self.nvals)
	end
	function Graph:itox(i)
		return self.xmin + i/(self.nvals-1)*(self.xmax-self.xmin)
	end
	function Graph:calc(func,ymin1,ymax1)
		local vmin = math.huge
		local vmax = -math.huge
		for i=0,self.nvals-1 do
			self.values[i] = func(self:itox(i))
			vmin = (vmin < self.values[i]) and vmin or self.values[i]
			vmax = (vmax > self.values[i]) and vmax or self.values[i]
		end
		self.ymin = ymin1 or vmin
		self.ymax = ymax1 or vmax
	end
	function Graph:draw()
	
		local regionsize = M.GetContentRegionAvail()
		local desiredY = regionsize.y - M.GetFrameHeightWithSpacing()
		M.PushItemWidth(-1)
		M.PlotLines("##grafica",self.values,self.nvals,nil,nil,self.ymin,self.ymax,M.ImVec2(0,desiredY))
		local p = M.GetCursorScreenPos() 
		p.y = p.y - M.GetStyle().FramePadding.y
		local w = M.CalcItemWidth()
		self.origin = p
		self.size = M.ImVec2(w,desiredY)
		
		local draw_list = M.GetWindowDrawList()
		for i=0,4 do
			local ylab = i*desiredY/4 --+ M.GetStyle().FramePadding.y
			draw_list:AddLine(M.ImVec2(p.x, p.y - ylab), M.ImVec2(p.x + w,p.y - ylab), M.U32(1,0,0,1))
			local valy = self.ymin + (self.ymax - self.ymin)*i/4
			local labelY = string.format("%0.3f",valy)
			-- - M.CalcTextSize(labelY).x
			draw_list:AddText(M.ImVec2(p.x , p.y -ylab), M.U32(0,1,0,1),labelY)
		end
	
		for i=0,10 do
			local xlab = i*w/10
			draw_list:AddLine(M.ImVec2(p.x + xlab,p.y), M.ImVec2(p.x + xlab,p.y - desiredY), M.U32(1,0,0,1))
			local valx = self:itox(i/10*(self.nvals -1))
			draw_list:AddText(M.ImVec2(p.x + xlab,p.y + 2), M.U32(0,1,0,1),string.format("%0.3f",valx))
		end
		
		M.PopItemWidth()
		
		return w,desiredY
	end
	Graph:init()
	return Graph
end


