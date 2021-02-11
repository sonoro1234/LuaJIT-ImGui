local cimguimodule = 'cimgui_sdl' --set imgui directory location
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

-----------ImStr definition
local ImStr
if pcall(function() local a = ffi.new("ImStr")end) then

ImStr= {}
function ImStr.__new(ctype,a,b)
	b = b or ffi.new("const char*",a) + (a and #a or 0)
	return ffi.new(ctype,a,b)
end
function ImStr.__tostring(is)
	return is.Begin~=nil and ffi.string(is.Begin,is.End~=nil and is.End-is.Begin or nil) or nil
end
ImStr.__index = ImStr
ImStr = ffi.metatype("ImStr",ImStr)

end
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
local M = {ImVec2 = ImVec2, ImVec4 = ImVec4 , ImStr = ImStr, lib = lib}

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


----------BEGIN_AUTOGENERATED_LUA---------------------------
--------------------------CanvasState----------------------------
local CanvasState= {}
CanvasState.__index = CanvasState
function CanvasState.__new(ctype)
    local ptr = lib.CanvasState_CanvasState()
    return ffi.gc(ptr,lib.CanvasState_destroy)
end
M.CanvasState = ffi.metatype("CanvasState",CanvasState)
--------------------------EmulateThreeButtonMouse----------------------------
local EmulateThreeButtonMouse= {}
EmulateThreeButtonMouse.__index = EmulateThreeButtonMouse
function EmulateThreeButtonMouse.__new(ctype)
    local ptr = lib.EmulateThreeButtonMouse_EmulateThreeButtonMouse()
    return ffi.gc(ptr,lib.EmulateThreeButtonMouse_destroy)
end
M.EmulateThreeButtonMouse = ffi.metatype("EmulateThreeButtonMouse",EmulateThreeButtonMouse)
--------------------------IO----------------------------
local IO= {}
IO.__index = IO
function IO.__new(ctype)
    local ptr = lib.IO_IO()
    return ffi.gc(ptr,lib.IO_destroy)
end
M.IO = ffi.metatype("IO",IO)
--------------------------ImBitVector----------------------------
local ImBitVector= {}
ImBitVector.__index = ImBitVector
ImBitVector.Clear = lib.ImBitVector_Clear
ImBitVector.ClearBit = lib.ImBitVector_ClearBit
ImBitVector.Create = lib.ImBitVector_Create
ImBitVector.SetBit = lib.ImBitVector_SetBit
ImBitVector.TestBit = lib.ImBitVector_TestBit
M.ImBitVector = ffi.metatype("ImBitVector",ImBitVector)
--------------------------ImColor----------------------------
local ImColor= {}
ImColor.__index = ImColor
function M.ImColor_HSV(h,s,v,a)
    a = a or 1.0
    local nonUDT_out = ffi.new("ImColor")
    lib.ImColor_HSV(nonUDT_out,h,s,v,a)
    return nonUDT_out
end
function ImColor.ImColorNil()
    local ptr = lib.ImColor_ImColorNil()
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.ImColorInt(r,g,b,a)
    if a == nil then a = 255 end
    local ptr = lib.ImColor_ImColorInt(r,g,b,a)
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.ImColorU32(rgba)
    local ptr = lib.ImColor_ImColorU32(rgba)
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.ImColorFloat(r,g,b,a)
    if a == nil then a = 1.0 end
    local ptr = lib.ImColor_ImColorFloat(r,g,b,a)
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.ImColorVec4(col)
    local ptr = lib.ImColor_ImColorVec4(col)
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImColor.ImColorNil() end
    if (ffi.istype('int',a1) or type(a1)=='number') then return ImColor.ImColorInt(a1,a2,a3,a4) end
    if (ffi.istype('ImU32',a1) or type(a1)=='number') then return ImColor.ImColorU32(a1) end
    if (ffi.istype('float',a1) or type(a1)=='number') then return ImColor.ImColorFloat(a1,a2,a3,a4) end
    if ffi.istype('const ImVec4',a1) then return ImColor.ImColorVec4(a1) end
    print(ctype,a1,a2,a3,a4)
    error'ImColor.__new could not find overloaded'
end
function ImColor:SetHSV(h,s,v,a)
    a = a or 1.0
    return lib.ImColor_SetHSV(self,h,s,v,a)
end
M.ImColor = ffi.metatype("ImColor",ImColor)
--------------------------ImDrawCmd----------------------------
local ImDrawCmd= {}
ImDrawCmd.__index = ImDrawCmd
function ImDrawCmd.__new(ctype)
    local ptr = lib.ImDrawCmd_ImDrawCmd()
    return ffi.gc(ptr,lib.ImDrawCmd_destroy)
end
M.ImDrawCmd = ffi.metatype("ImDrawCmd",ImDrawCmd)
--------------------------ImDrawData----------------------------
local ImDrawData= {}
ImDrawData.__index = ImDrawData
ImDrawData.Clear = lib.ImDrawData_Clear
ImDrawData.DeIndexAllBuffers = lib.ImDrawData_DeIndexAllBuffers
function ImDrawData.__new(ctype)
    local ptr = lib.ImDrawData_ImDrawData()
    return ffi.gc(ptr,lib.ImDrawData_destroy)
end
ImDrawData.ScaleClipRects = lib.ImDrawData_ScaleClipRects
M.ImDrawData = ffi.metatype("ImDrawData",ImDrawData)
--------------------------ImDrawDataBuilder----------------------------
local ImDrawDataBuilder= {}
ImDrawDataBuilder.__index = ImDrawDataBuilder
ImDrawDataBuilder.Clear = lib.ImDrawDataBuilder_Clear
ImDrawDataBuilder.ClearFreeMemory = lib.ImDrawDataBuilder_ClearFreeMemory
ImDrawDataBuilder.FlattenIntoSingleLayer = lib.ImDrawDataBuilder_FlattenIntoSingleLayer
ImDrawDataBuilder.GetDrawListCount = lib.ImDrawDataBuilder_GetDrawListCount
M.ImDrawDataBuilder = ffi.metatype("ImDrawDataBuilder",ImDrawDataBuilder)
--------------------------ImDrawList----------------------------
local ImDrawList= {}
ImDrawList.__index = ImDrawList
function ImDrawList:AddBezierCubic(p1,p2,p3,p4,col,thickness,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_AddBezierCubic(self,p1,p2,p3,p4,col,thickness,num_segments)
end
function ImDrawList:AddBezierQuadratic(p1,p2,p3,col,thickness,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_AddBezierQuadratic(self,p1,p2,p3,col,thickness,num_segments)
end
ImDrawList.AddCallback = lib.ImDrawList_AddCallback
function ImDrawList:AddCircle(center,radius,col,num_segments,thickness)
    num_segments = num_segments or 0
    thickness = thickness or 1.0
    return lib.ImDrawList_AddCircle(self,center,radius,col,num_segments,thickness)
end
function ImDrawList:AddCircleFilled(center,radius,col,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_AddCircleFilled(self,center,radius,col,num_segments)
end
ImDrawList.AddConvexPolyFilled = lib.ImDrawList_AddConvexPolyFilled
ImDrawList.AddDrawCmd = lib.ImDrawList_AddDrawCmd
function ImDrawList:AddImage(user_texture_id,p_min,p_max,uv_min,uv_max,col)
    col = col or 4294967295
    uv_max = uv_max or ImVec2(1,1)
    uv_min = uv_min or ImVec2(0,0)
    return lib.ImDrawList_AddImage(self,user_texture_id,p_min,p_max,uv_min,uv_max,col)
end
function ImDrawList:AddImageQuad(user_texture_id,p1,p2,p3,p4,uv1,uv2,uv3,uv4,col)
    col = col or 4294967295
    uv1 = uv1 or ImVec2(0,0)
    uv2 = uv2 or ImVec2(1,0)
    uv3 = uv3 or ImVec2(1,1)
    uv4 = uv4 or ImVec2(0,1)
    return lib.ImDrawList_AddImageQuad(self,user_texture_id,p1,p2,p3,p4,uv1,uv2,uv3,uv4,col)
end
function ImDrawList:AddImageRounded(user_texture_id,p_min,p_max,uv_min,uv_max,col,rounding,rounding_corners)
    rounding_corners = rounding_corners or 15
    return lib.ImDrawList_AddImageRounded(self,user_texture_id,p_min,p_max,uv_min,uv_max,col,rounding,rounding_corners)
end
function ImDrawList:AddLine(p1,p2,col,thickness)
    thickness = thickness or 1.0
    return lib.ImDrawList_AddLine(self,p1,p2,col,thickness)
end
function ImDrawList:AddNgon(center,radius,col,num_segments,thickness)
    thickness = thickness or 1.0
    return lib.ImDrawList_AddNgon(self,center,radius,col,num_segments,thickness)
end
ImDrawList.AddNgonFilled = lib.ImDrawList_AddNgonFilled
ImDrawList.AddPolyline = lib.ImDrawList_AddPolyline
function ImDrawList:AddQuad(p1,p2,p3,p4,col,thickness)
    thickness = thickness or 1.0
    return lib.ImDrawList_AddQuad(self,p1,p2,p3,p4,col,thickness)
end
ImDrawList.AddQuadFilled = lib.ImDrawList_AddQuadFilled
function ImDrawList:AddRect(p_min,p_max,col,rounding,rounding_corners,thickness)
    rounding = rounding or 0.0
    rounding_corners = rounding_corners or 15
    thickness = thickness or 1.0
    return lib.ImDrawList_AddRect(self,p_min,p_max,col,rounding,rounding_corners,thickness)
end
function ImDrawList:AddRectFilled(p_min,p_max,col,rounding,rounding_corners)
    rounding = rounding or 0.0
    rounding_corners = rounding_corners or 15
    return lib.ImDrawList_AddRectFilled(self,p_min,p_max,col,rounding,rounding_corners)
end
ImDrawList.AddRectFilledMultiColor = lib.ImDrawList_AddRectFilledMultiColor
function ImDrawList:AddTextVec2(pos,col,text_begin,text_end)
    text_end = text_end or nil
    return lib.ImDrawList_AddTextVec2(self,pos,col,text_begin,text_end)
end
function ImDrawList:AddTextFontPtr(font,font_size,pos,col,text_begin,text_end,wrap_width,cpu_fine_clip_rect)
    cpu_fine_clip_rect = cpu_fine_clip_rect or nil
    text_end = text_end or nil
    wrap_width = wrap_width or 0.0
    return lib.ImDrawList_AddTextFontPtr(self,font,font_size,pos,col,text_begin,text_end,wrap_width,cpu_fine_clip_rect)
end
function ImDrawList:AddText(a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if ffi.istype('const ImVec2',a2) then return self:AddTextVec2(a2,a3,a4,a5) end
    if (ffi.istype('const ImFont*',a2) or ffi.istype('const ImFont',a2) or ffi.istype('const ImFont[]',a2)) then return self:AddTextFontPtr(a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a2,a3,a4,a5,a6,a7,a8,a9)
    error'ImDrawList:AddText could not find overloaded'
end
function ImDrawList:AddTriangle(p1,p2,p3,col,thickness)
    thickness = thickness or 1.0
    return lib.ImDrawList_AddTriangle(self,p1,p2,p3,col,thickness)
end
ImDrawList.AddTriangleFilled = lib.ImDrawList_AddTriangleFilled
ImDrawList.ChannelsMerge = lib.ImDrawList_ChannelsMerge
ImDrawList.ChannelsSetCurrent = lib.ImDrawList_ChannelsSetCurrent
ImDrawList.ChannelsSplit = lib.ImDrawList_ChannelsSplit
ImDrawList.CloneOutput = lib.ImDrawList_CloneOutput
function ImDrawList:GetClipRectMax()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImDrawList_GetClipRectMax(nonUDT_out,self)
    return nonUDT_out
end
function ImDrawList:GetClipRectMin()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImDrawList_GetClipRectMin(nonUDT_out,self)
    return nonUDT_out
end
function ImDrawList.__new(ctype,shared_data)
    local ptr = lib.ImDrawList_ImDrawList(shared_data)
    return ffi.gc(ptr,lib.ImDrawList_destroy)
end
function ImDrawList:PathArcTo(center,radius,a_min,a_max,num_segments)
    num_segments = num_segments or 10
    return lib.ImDrawList_PathArcTo(self,center,radius,a_min,a_max,num_segments)
end
ImDrawList.PathArcToFast = lib.ImDrawList_PathArcToFast
function ImDrawList:PathBezierCubicCurveTo(p2,p3,p4,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_PathBezierCubicCurveTo(self,p2,p3,p4,num_segments)
end
function ImDrawList:PathBezierQuadraticCurveTo(p2,p3,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_PathBezierQuadraticCurveTo(self,p2,p3,num_segments)
end
ImDrawList.PathClear = lib.ImDrawList_PathClear
ImDrawList.PathFillConvex = lib.ImDrawList_PathFillConvex
ImDrawList.PathLineTo = lib.ImDrawList_PathLineTo
ImDrawList.PathLineToMergeDuplicate = lib.ImDrawList_PathLineToMergeDuplicate
function ImDrawList:PathRect(rect_min,rect_max,rounding,rounding_corners)
    rounding = rounding or 0.0
    rounding_corners = rounding_corners or 15
    return lib.ImDrawList_PathRect(self,rect_min,rect_max,rounding,rounding_corners)
end
function ImDrawList:PathStroke(col,closed,thickness)
    thickness = thickness or 1.0
    return lib.ImDrawList_PathStroke(self,col,closed,thickness)
end
ImDrawList.PopClipRect = lib.ImDrawList_PopClipRect
ImDrawList.PopTextureID = lib.ImDrawList_PopTextureID
ImDrawList.PrimQuadUV = lib.ImDrawList_PrimQuadUV
ImDrawList.PrimRect = lib.ImDrawList_PrimRect
ImDrawList.PrimRectUV = lib.ImDrawList_PrimRectUV
ImDrawList.PrimReserve = lib.ImDrawList_PrimReserve
ImDrawList.PrimUnreserve = lib.ImDrawList_PrimUnreserve
ImDrawList.PrimVtx = lib.ImDrawList_PrimVtx
ImDrawList.PrimWriteIdx = lib.ImDrawList_PrimWriteIdx
ImDrawList.PrimWriteVtx = lib.ImDrawList_PrimWriteVtx
function ImDrawList:PushClipRect(clip_rect_min,clip_rect_max,intersect_with_current_clip_rect)
    intersect_with_current_clip_rect = intersect_with_current_clip_rect or false
    return lib.ImDrawList_PushClipRect(self,clip_rect_min,clip_rect_max,intersect_with_current_clip_rect)
end
ImDrawList.PushClipRectFullScreen = lib.ImDrawList_PushClipRectFullScreen
ImDrawList.PushTextureID = lib.ImDrawList_PushTextureID
ImDrawList._ClearFreeMemory = lib.ImDrawList__ClearFreeMemory
ImDrawList._OnChangedClipRect = lib.ImDrawList__OnChangedClipRect
ImDrawList._OnChangedTextureID = lib.ImDrawList__OnChangedTextureID
ImDrawList._OnChangedVtxOffset = lib.ImDrawList__OnChangedVtxOffset
ImDrawList._PopUnusedDrawCmd = lib.ImDrawList__PopUnusedDrawCmd
ImDrawList._ResetForNewFrame = lib.ImDrawList__ResetForNewFrame
M.ImDrawList = ffi.metatype("ImDrawList",ImDrawList)
--------------------------ImDrawListSharedData----------------------------
local ImDrawListSharedData= {}
ImDrawListSharedData.__index = ImDrawListSharedData
function ImDrawListSharedData.__new(ctype)
    local ptr = lib.ImDrawListSharedData_ImDrawListSharedData()
    return ffi.gc(ptr,lib.ImDrawListSharedData_destroy)
end
ImDrawListSharedData.SetCircleSegmentMaxError = lib.ImDrawListSharedData_SetCircleSegmentMaxError
M.ImDrawListSharedData = ffi.metatype("ImDrawListSharedData",ImDrawListSharedData)
--------------------------ImDrawListSplitter----------------------------
local ImDrawListSplitter= {}
ImDrawListSplitter.__index = ImDrawListSplitter
ImDrawListSplitter.Clear = lib.ImDrawListSplitter_Clear
ImDrawListSplitter.ClearFreeMemory = lib.ImDrawListSplitter_ClearFreeMemory
function ImDrawListSplitter.__new(ctype)
    local ptr = lib.ImDrawListSplitter_ImDrawListSplitter()
    return ffi.gc(ptr,lib.ImDrawListSplitter_destroy)
end
ImDrawListSplitter.Merge = lib.ImDrawListSplitter_Merge
ImDrawListSplitter.SetCurrentChannel = lib.ImDrawListSplitter_SetCurrentChannel
ImDrawListSplitter.Split = lib.ImDrawListSplitter_Split
M.ImDrawListSplitter = ffi.metatype("ImDrawListSplitter",ImDrawListSplitter)
--------------------------ImFont----------------------------
local ImFont= {}
ImFont.__index = ImFont
ImFont.AddGlyph = lib.ImFont_AddGlyph
function ImFont:AddRemapChar(dst,src,overwrite_dst)
    if overwrite_dst == nil then overwrite_dst = true end
    return lib.ImFont_AddRemapChar(self,dst,src,overwrite_dst)
end
ImFont.BuildLookupTable = lib.ImFont_BuildLookupTable
function ImFont:CalcTextSizeA(size,max_width,wrap_width,text_begin,text_end,remaining)
    remaining = remaining or nil
    text_end = text_end or nil
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImFont_CalcTextSizeA(nonUDT_out,self,size,max_width,wrap_width,text_begin,text_end,remaining)
    return nonUDT_out
end
ImFont.CalcWordWrapPositionA = lib.ImFont_CalcWordWrapPositionA
ImFont.ClearOutputData = lib.ImFont_ClearOutputData
ImFont.FindGlyph = lib.ImFont_FindGlyph
ImFont.FindGlyphNoFallback = lib.ImFont_FindGlyphNoFallback
ImFont.GetCharAdvance = lib.ImFont_GetCharAdvance
ImFont.GetDebugName = lib.ImFont_GetDebugName
ImFont.GrowIndex = lib.ImFont_GrowIndex
function ImFont.__new(ctype)
    local ptr = lib.ImFont_ImFont()
    return ffi.gc(ptr,lib.ImFont_destroy)
end
ImFont.IsGlyphRangeUnused = lib.ImFont_IsGlyphRangeUnused
ImFont.IsLoaded = lib.ImFont_IsLoaded
ImFont.RenderChar = lib.ImFont_RenderChar
function ImFont:RenderText(draw_list,size,pos,col,clip_rect,text_begin,text_end,wrap_width,cpu_fine_clip)
    cpu_fine_clip = cpu_fine_clip or false
    wrap_width = wrap_width or 0.0
    return lib.ImFont_RenderText(self,draw_list,size,pos,col,clip_rect,text_begin,text_end,wrap_width,cpu_fine_clip)
end
ImFont.SetFallbackChar = lib.ImFont_SetFallbackChar
ImFont.SetGlyphVisible = lib.ImFont_SetGlyphVisible
M.ImFont = ffi.metatype("ImFont",ImFont)
--------------------------ImFontAtlas----------------------------
local ImFontAtlas= {}
ImFontAtlas.__index = ImFontAtlas
function ImFontAtlas:AddCustomRectFontGlyph(font,id,width,height,advance_x,offset)
    offset = offset or ImVec2(0,0)
    return lib.ImFontAtlas_AddCustomRectFontGlyph(self,font,id,width,height,advance_x,offset)
end
ImFontAtlas.AddCustomRectRegular = lib.ImFontAtlas_AddCustomRectRegular
ImFontAtlas.AddFont = lib.ImFontAtlas_AddFont
function ImFontAtlas:AddFontDefault(font_cfg)
    font_cfg = font_cfg or nil
    return lib.ImFontAtlas_AddFontDefault(self,font_cfg)
end
function ImFontAtlas:AddFontFromFileTTF(filename,size_pixels,font_cfg,glyph_ranges)
    font_cfg = font_cfg or nil
    glyph_ranges = glyph_ranges or nil
    return lib.ImFontAtlas_AddFontFromFileTTF(self,filename,size_pixels,font_cfg,glyph_ranges)
end
function ImFontAtlas:AddFontFromMemoryCompressedBase85TTF(compressed_font_data_base85,size_pixels,font_cfg,glyph_ranges)
    font_cfg = font_cfg or nil
    glyph_ranges = glyph_ranges or nil
    return lib.ImFontAtlas_AddFontFromMemoryCompressedBase85TTF(self,compressed_font_data_base85,size_pixels,font_cfg,glyph_ranges)
end
function ImFontAtlas:AddFontFromMemoryCompressedTTF(compressed_font_data,compressed_font_size,size_pixels,font_cfg,glyph_ranges)
    font_cfg = font_cfg or nil
    glyph_ranges = glyph_ranges or nil
    return lib.ImFontAtlas_AddFontFromMemoryCompressedTTF(self,compressed_font_data,compressed_font_size,size_pixels,font_cfg,glyph_ranges)
end
function ImFontAtlas:AddFontFromMemoryTTF(font_data,font_size,size_pixels,font_cfg,glyph_ranges)
    font_cfg = font_cfg or nil
    glyph_ranges = glyph_ranges or nil
    return lib.ImFontAtlas_AddFontFromMemoryTTF(self,font_data,font_size,size_pixels,font_cfg,glyph_ranges)
end
ImFontAtlas.Build = lib.ImFontAtlas_Build
ImFontAtlas.CalcCustomRectUV = lib.ImFontAtlas_CalcCustomRectUV
ImFontAtlas.Clear = lib.ImFontAtlas_Clear
ImFontAtlas.ClearFonts = lib.ImFontAtlas_ClearFonts
ImFontAtlas.ClearInputData = lib.ImFontAtlas_ClearInputData
ImFontAtlas.ClearTexData = lib.ImFontAtlas_ClearTexData
ImFontAtlas.GetCustomRectByIndex = lib.ImFontAtlas_GetCustomRectByIndex
ImFontAtlas.GetGlyphRangesChineseFull = lib.ImFontAtlas_GetGlyphRangesChineseFull
ImFontAtlas.GetGlyphRangesChineseSimplifiedCommon = lib.ImFontAtlas_GetGlyphRangesChineseSimplifiedCommon
ImFontAtlas.GetGlyphRangesCyrillic = lib.ImFontAtlas_GetGlyphRangesCyrillic
ImFontAtlas.GetGlyphRangesDefault = lib.ImFontAtlas_GetGlyphRangesDefault
ImFontAtlas.GetGlyphRangesJapanese = lib.ImFontAtlas_GetGlyphRangesJapanese
ImFontAtlas.GetGlyphRangesKorean = lib.ImFontAtlas_GetGlyphRangesKorean
ImFontAtlas.GetGlyphRangesThai = lib.ImFontAtlas_GetGlyphRangesThai
ImFontAtlas.GetGlyphRangesVietnamese = lib.ImFontAtlas_GetGlyphRangesVietnamese
ImFontAtlas.GetMouseCursorTexData = lib.ImFontAtlas_GetMouseCursorTexData
function ImFontAtlas:GetTexDataAsAlpha8(out_pixels,out_width,out_height,out_bytes_per_pixel)
    out_bytes_per_pixel = out_bytes_per_pixel or nil
    return lib.ImFontAtlas_GetTexDataAsAlpha8(self,out_pixels,out_width,out_height,out_bytes_per_pixel)
end
function ImFontAtlas:GetTexDataAsRGBA32(out_pixels,out_width,out_height,out_bytes_per_pixel)
    out_bytes_per_pixel = out_bytes_per_pixel or nil
    return lib.ImFontAtlas_GetTexDataAsRGBA32(self,out_pixels,out_width,out_height,out_bytes_per_pixel)
end
function ImFontAtlas.__new(ctype)
    local ptr = lib.ImFontAtlas_ImFontAtlas()
    return ffi.gc(ptr,lib.ImFontAtlas_destroy)
end
ImFontAtlas.IsBuilt = lib.ImFontAtlas_IsBuilt
ImFontAtlas.SetTexID = lib.ImFontAtlas_SetTexID
M.ImFontAtlas = ffi.metatype("ImFontAtlas",ImFontAtlas)
--------------------------ImFontAtlasCustomRect----------------------------
local ImFontAtlasCustomRect= {}
ImFontAtlasCustomRect.__index = ImFontAtlasCustomRect
function ImFontAtlasCustomRect.__new(ctype)
    local ptr = lib.ImFontAtlasCustomRect_ImFontAtlasCustomRect()
    return ffi.gc(ptr,lib.ImFontAtlasCustomRect_destroy)
end
ImFontAtlasCustomRect.IsPacked = lib.ImFontAtlasCustomRect_IsPacked
M.ImFontAtlasCustomRect = ffi.metatype("ImFontAtlasCustomRect",ImFontAtlasCustomRect)
--------------------------ImFontConfig----------------------------
local ImFontConfig= {}
ImFontConfig.__index = ImFontConfig
function ImFontConfig.__new(ctype)
    local ptr = lib.ImFontConfig_ImFontConfig()
    return ffi.gc(ptr,lib.ImFontConfig_destroy)
end
M.ImFontConfig = ffi.metatype("ImFontConfig",ImFontConfig)
--------------------------ImFontGlyphRangesBuilder----------------------------
local ImFontGlyphRangesBuilder= {}
ImFontGlyphRangesBuilder.__index = ImFontGlyphRangesBuilder
ImFontGlyphRangesBuilder.AddChar = lib.ImFontGlyphRangesBuilder_AddChar
ImFontGlyphRangesBuilder.AddRanges = lib.ImFontGlyphRangesBuilder_AddRanges
function ImFontGlyphRangesBuilder:AddText(text,text_end)
    text_end = text_end or nil
    return lib.ImFontGlyphRangesBuilder_AddText(self,text,text_end)
end
ImFontGlyphRangesBuilder.BuildRanges = lib.ImFontGlyphRangesBuilder_BuildRanges
ImFontGlyphRangesBuilder.Clear = lib.ImFontGlyphRangesBuilder_Clear
ImFontGlyphRangesBuilder.GetBit = lib.ImFontGlyphRangesBuilder_GetBit
function ImFontGlyphRangesBuilder.__new(ctype)
    local ptr = lib.ImFontGlyphRangesBuilder_ImFontGlyphRangesBuilder()
    return ffi.gc(ptr,lib.ImFontGlyphRangesBuilder_destroy)
end
ImFontGlyphRangesBuilder.SetBit = lib.ImFontGlyphRangesBuilder_SetBit
M.ImFontGlyphRangesBuilder = ffi.metatype("ImFontGlyphRangesBuilder",ImFontGlyphRangesBuilder)
--------------------------ImGuiContext----------------------------
local ImGuiContext= {}
ImGuiContext.__index = ImGuiContext
function ImGuiContext.__new(ctype,shared_font_atlas)
    local ptr = lib.ImGuiContext_ImGuiContext(shared_font_atlas)
    return ffi.gc(ptr,lib.ImGuiContext_destroy)
end
M.ImGuiContext = ffi.metatype("ImGuiContext",ImGuiContext)
--------------------------ImGuiContextHook----------------------------
local ImGuiContextHook= {}
ImGuiContextHook.__index = ImGuiContextHook
function ImGuiContextHook.__new(ctype)
    local ptr = lib.ImGuiContextHook_ImGuiContextHook()
    return ffi.gc(ptr,lib.ImGuiContextHook_destroy)
end
M.ImGuiContextHook = ffi.metatype("ImGuiContextHook",ImGuiContextHook)
--------------------------ImGuiDockContext----------------------------
local ImGuiDockContext= {}
ImGuiDockContext.__index = ImGuiDockContext
function ImGuiDockContext.__new(ctype)
    local ptr = lib.ImGuiDockContext_ImGuiDockContext()
    return ffi.gc(ptr,lib.ImGuiDockContext_destroy)
end
M.ImGuiDockContext = ffi.metatype("ImGuiDockContext",ImGuiDockContext)
--------------------------ImGuiDockNode----------------------------
local ImGuiDockNode= {}
ImGuiDockNode.__index = ImGuiDockNode
ImGuiDockNode.GetMergedFlags = lib.ImGuiDockNode_GetMergedFlags
function ImGuiDockNode.__new(ctype,id)
    local ptr = lib.ImGuiDockNode_ImGuiDockNode(id)
    return ffi.gc(ptr,lib.ImGuiDockNode_destroy)
end
ImGuiDockNode.IsCentralNode = lib.ImGuiDockNode_IsCentralNode
ImGuiDockNode.IsDockSpace = lib.ImGuiDockNode_IsDockSpace
ImGuiDockNode.IsEmpty = lib.ImGuiDockNode_IsEmpty
ImGuiDockNode.IsFloatingNode = lib.ImGuiDockNode_IsFloatingNode
ImGuiDockNode.IsHiddenTabBar = lib.ImGuiDockNode_IsHiddenTabBar
ImGuiDockNode.IsLeafNode = lib.ImGuiDockNode_IsLeafNode
ImGuiDockNode.IsNoTabBar = lib.ImGuiDockNode_IsNoTabBar
ImGuiDockNode.IsRootNode = lib.ImGuiDockNode_IsRootNode
ImGuiDockNode.IsSplitNode = lib.ImGuiDockNode_IsSplitNode
function ImGuiDockNode:Rect()
    local nonUDT_out = ffi.new("ImRect")
    lib.ImGuiDockNode_Rect(nonUDT_out,self)
    return nonUDT_out
end
M.ImGuiDockNode = ffi.metatype("ImGuiDockNode",ImGuiDockNode)
--------------------------ImGuiIO----------------------------
local ImGuiIO= {}
ImGuiIO.__index = ImGuiIO
ImGuiIO.AddInputCharacter = lib.ImGuiIO_AddInputCharacter
ImGuiIO.AddInputCharacterUTF16 = lib.ImGuiIO_AddInputCharacterUTF16
ImGuiIO.AddInputCharactersUTF8 = lib.ImGuiIO_AddInputCharactersUTF8
ImGuiIO.ClearInputCharacters = lib.ImGuiIO_ClearInputCharacters
function ImGuiIO.__new(ctype)
    local ptr = lib.ImGuiIO_ImGuiIO()
    return ffi.gc(ptr,lib.ImGuiIO_destroy)
end
M.ImGuiIO = ffi.metatype("ImGuiIO",ImGuiIO)
--------------------------ImGuiInputTextCallbackData----------------------------
local ImGuiInputTextCallbackData= {}
ImGuiInputTextCallbackData.__index = ImGuiInputTextCallbackData
ImGuiInputTextCallbackData.ClearSelection = lib.ImGuiInputTextCallbackData_ClearSelection
ImGuiInputTextCallbackData.DeleteChars = lib.ImGuiInputTextCallbackData_DeleteChars
ImGuiInputTextCallbackData.HasSelection = lib.ImGuiInputTextCallbackData_HasSelection
function ImGuiInputTextCallbackData.__new(ctype)
    local ptr = lib.ImGuiInputTextCallbackData_ImGuiInputTextCallbackData()
    return ffi.gc(ptr,lib.ImGuiInputTextCallbackData_destroy)
end
function ImGuiInputTextCallbackData:InsertChars(pos,text,text_end)
    text_end = text_end or nil
    return lib.ImGuiInputTextCallbackData_InsertChars(self,pos,text,text_end)
end
ImGuiInputTextCallbackData.SelectAll = lib.ImGuiInputTextCallbackData_SelectAll
M.ImGuiInputTextCallbackData = ffi.metatype("ImGuiInputTextCallbackData",ImGuiInputTextCallbackData)
--------------------------ImGuiInputTextState----------------------------
local ImGuiInputTextState= {}
ImGuiInputTextState.__index = ImGuiInputTextState
ImGuiInputTextState.ClearFreeMemory = lib.ImGuiInputTextState_ClearFreeMemory
ImGuiInputTextState.ClearSelection = lib.ImGuiInputTextState_ClearSelection
ImGuiInputTextState.ClearText = lib.ImGuiInputTextState_ClearText
ImGuiInputTextState.CursorAnimReset = lib.ImGuiInputTextState_CursorAnimReset
ImGuiInputTextState.CursorClamp = lib.ImGuiInputTextState_CursorClamp
ImGuiInputTextState.GetRedoAvailCount = lib.ImGuiInputTextState_GetRedoAvailCount
ImGuiInputTextState.GetUndoAvailCount = lib.ImGuiInputTextState_GetUndoAvailCount
ImGuiInputTextState.HasSelection = lib.ImGuiInputTextState_HasSelection
function ImGuiInputTextState.__new(ctype)
    local ptr = lib.ImGuiInputTextState_ImGuiInputTextState()
    return ffi.gc(ptr,lib.ImGuiInputTextState_destroy)
end
ImGuiInputTextState.OnKeyPressed = lib.ImGuiInputTextState_OnKeyPressed
ImGuiInputTextState.SelectAll = lib.ImGuiInputTextState_SelectAll
M.ImGuiInputTextState = ffi.metatype("ImGuiInputTextState",ImGuiInputTextState)
--------------------------ImGuiLastItemDataBackup----------------------------
local ImGuiLastItemDataBackup= {}
ImGuiLastItemDataBackup.__index = ImGuiLastItemDataBackup
ImGuiLastItemDataBackup.Backup = lib.ImGuiLastItemDataBackup_Backup
function ImGuiLastItemDataBackup.__new(ctype)
    local ptr = lib.ImGuiLastItemDataBackup_ImGuiLastItemDataBackup()
    return ffi.gc(ptr,lib.ImGuiLastItemDataBackup_destroy)
end
ImGuiLastItemDataBackup.Restore = lib.ImGuiLastItemDataBackup_Restore
M.ImGuiLastItemDataBackup = ffi.metatype("ImGuiLastItemDataBackup",ImGuiLastItemDataBackup)
--------------------------ImGuiListClipper----------------------------
local ImGuiListClipper= {}
ImGuiListClipper.__index = ImGuiListClipper
function ImGuiListClipper:Begin(items_count,items_height)
    items_height = items_height or -1.0
    return lib.ImGuiListClipper_Begin(self,items_count,items_height)
end
ImGuiListClipper.End = lib.ImGuiListClipper_End
function ImGuiListClipper.__new(ctype)
    local ptr = lib.ImGuiListClipper_ImGuiListClipper()
    return ffi.gc(ptr,lib.ImGuiListClipper_destroy)
end
ImGuiListClipper.Step = lib.ImGuiListClipper_Step
M.ImGuiListClipper = ffi.metatype("ImGuiListClipper",ImGuiListClipper)
--------------------------ImGuiMenuColumns----------------------------
local ImGuiMenuColumns= {}
ImGuiMenuColumns.__index = ImGuiMenuColumns
ImGuiMenuColumns.CalcExtraSpace = lib.ImGuiMenuColumns_CalcExtraSpace
ImGuiMenuColumns.DeclColumns = lib.ImGuiMenuColumns_DeclColumns
function ImGuiMenuColumns.__new(ctype)
    local ptr = lib.ImGuiMenuColumns_ImGuiMenuColumns()
    return ffi.gc(ptr,lib.ImGuiMenuColumns_destroy)
end
ImGuiMenuColumns.Update = lib.ImGuiMenuColumns_Update
M.ImGuiMenuColumns = ffi.metatype("ImGuiMenuColumns",ImGuiMenuColumns)
--------------------------ImGuiMetricsConfig----------------------------
local ImGuiMetricsConfig= {}
ImGuiMetricsConfig.__index = ImGuiMetricsConfig
function ImGuiMetricsConfig.__new(ctype)
    local ptr = lib.ImGuiMetricsConfig_ImGuiMetricsConfig()
    return ffi.gc(ptr,lib.ImGuiMetricsConfig_destroy)
end
M.ImGuiMetricsConfig = ffi.metatype("ImGuiMetricsConfig",ImGuiMetricsConfig)
--------------------------ImGuiNavMoveResult----------------------------
local ImGuiNavMoveResult= {}
ImGuiNavMoveResult.__index = ImGuiNavMoveResult
ImGuiNavMoveResult.Clear = lib.ImGuiNavMoveResult_Clear
function ImGuiNavMoveResult.__new(ctype)
    local ptr = lib.ImGuiNavMoveResult_ImGuiNavMoveResult()
    return ffi.gc(ptr,lib.ImGuiNavMoveResult_destroy)
end
M.ImGuiNavMoveResult = ffi.metatype("ImGuiNavMoveResult",ImGuiNavMoveResult)
--------------------------ImGuiNextItemData----------------------------
local ImGuiNextItemData= {}
ImGuiNextItemData.__index = ImGuiNextItemData
ImGuiNextItemData.ClearFlags = lib.ImGuiNextItemData_ClearFlags
function ImGuiNextItemData.__new(ctype)
    local ptr = lib.ImGuiNextItemData_ImGuiNextItemData()
    return ffi.gc(ptr,lib.ImGuiNextItemData_destroy)
end
M.ImGuiNextItemData = ffi.metatype("ImGuiNextItemData",ImGuiNextItemData)
--------------------------ImGuiNextWindowData----------------------------
local ImGuiNextWindowData= {}
ImGuiNextWindowData.__index = ImGuiNextWindowData
ImGuiNextWindowData.ClearFlags = lib.ImGuiNextWindowData_ClearFlags
function ImGuiNextWindowData.__new(ctype)
    local ptr = lib.ImGuiNextWindowData_ImGuiNextWindowData()
    return ffi.gc(ptr,lib.ImGuiNextWindowData_destroy)
end
M.ImGuiNextWindowData = ffi.metatype("ImGuiNextWindowData",ImGuiNextWindowData)
--------------------------ImGuiOldColumnData----------------------------
local ImGuiOldColumnData= {}
ImGuiOldColumnData.__index = ImGuiOldColumnData
function ImGuiOldColumnData.__new(ctype)
    local ptr = lib.ImGuiOldColumnData_ImGuiOldColumnData()
    return ffi.gc(ptr,lib.ImGuiOldColumnData_destroy)
end
M.ImGuiOldColumnData = ffi.metatype("ImGuiOldColumnData",ImGuiOldColumnData)
--------------------------ImGuiOldColumns----------------------------
local ImGuiOldColumns= {}
ImGuiOldColumns.__index = ImGuiOldColumns
function ImGuiOldColumns.__new(ctype)
    local ptr = lib.ImGuiOldColumns_ImGuiOldColumns()
    return ffi.gc(ptr,lib.ImGuiOldColumns_destroy)
end
M.ImGuiOldColumns = ffi.metatype("ImGuiOldColumns",ImGuiOldColumns)
--------------------------ImGuiOnceUponAFrame----------------------------
local ImGuiOnceUponAFrame= {}
ImGuiOnceUponAFrame.__index = ImGuiOnceUponAFrame
function ImGuiOnceUponAFrame.__new(ctype)
    local ptr = lib.ImGuiOnceUponAFrame_ImGuiOnceUponAFrame()
    return ffi.gc(ptr,lib.ImGuiOnceUponAFrame_destroy)
end
M.ImGuiOnceUponAFrame = ffi.metatype("ImGuiOnceUponAFrame",ImGuiOnceUponAFrame)
--------------------------ImGuiPayload----------------------------
local ImGuiPayload= {}
ImGuiPayload.__index = ImGuiPayload
ImGuiPayload.Clear = lib.ImGuiPayload_Clear
function ImGuiPayload.__new(ctype)
    local ptr = lib.ImGuiPayload_ImGuiPayload()
    return ffi.gc(ptr,lib.ImGuiPayload_destroy)
end
ImGuiPayload.IsDataType = lib.ImGuiPayload_IsDataType
ImGuiPayload.IsDelivery = lib.ImGuiPayload_IsDelivery
ImGuiPayload.IsPreview = lib.ImGuiPayload_IsPreview
M.ImGuiPayload = ffi.metatype("ImGuiPayload",ImGuiPayload)
--------------------------ImGuiPlatformIO----------------------------
local ImGuiPlatformIO= {}
ImGuiPlatformIO.__index = ImGuiPlatformIO
function ImGuiPlatformIO.__new(ctype)
    local ptr = lib.ImGuiPlatformIO_ImGuiPlatformIO()
    return ffi.gc(ptr,lib.ImGuiPlatformIO_destroy)
end
M.ImGuiPlatformIO = ffi.metatype("ImGuiPlatformIO",ImGuiPlatformIO)
--------------------------ImGuiPlatformMonitor----------------------------
local ImGuiPlatformMonitor= {}
ImGuiPlatformMonitor.__index = ImGuiPlatformMonitor
function ImGuiPlatformMonitor.__new(ctype)
    local ptr = lib.ImGuiPlatformMonitor_ImGuiPlatformMonitor()
    return ffi.gc(ptr,lib.ImGuiPlatformMonitor_destroy)
end
M.ImGuiPlatformMonitor = ffi.metatype("ImGuiPlatformMonitor",ImGuiPlatformMonitor)
--------------------------ImGuiPopupData----------------------------
local ImGuiPopupData= {}
ImGuiPopupData.__index = ImGuiPopupData
function ImGuiPopupData.__new(ctype)
    local ptr = lib.ImGuiPopupData_ImGuiPopupData()
    return ffi.gc(ptr,lib.ImGuiPopupData_destroy)
end
M.ImGuiPopupData = ffi.metatype("ImGuiPopupData",ImGuiPopupData)
--------------------------ImGuiPtrOrIndex----------------------------
local ImGuiPtrOrIndex= {}
ImGuiPtrOrIndex.__index = ImGuiPtrOrIndex
function ImGuiPtrOrIndex.ImGuiPtrOrIndexPtr(ptr)
    local ptr = lib.ImGuiPtrOrIndex_ImGuiPtrOrIndexPtr(ptr)
    return ffi.gc(ptr,lib.ImGuiPtrOrIndex_destroy)
end
function ImGuiPtrOrIndex.ImGuiPtrOrIndexInt(index)
    local ptr = lib.ImGuiPtrOrIndex_ImGuiPtrOrIndexInt(index)
    return ffi.gc(ptr,lib.ImGuiPtrOrIndex_destroy)
end
function ImGuiPtrOrIndex.__new(ctype,a1) -- generic version
    if ffi.istype('void*',a1) then return ImGuiPtrOrIndex.ImGuiPtrOrIndexPtr(a1) end
    if (ffi.istype('int',a1) or type(a1)=='number') then return ImGuiPtrOrIndex.ImGuiPtrOrIndexInt(a1) end
    print(ctype,a1)
    error'ImGuiPtrOrIndex.__new could not find overloaded'
end
M.ImGuiPtrOrIndex = ffi.metatype("ImGuiPtrOrIndex",ImGuiPtrOrIndex)
--------------------------ImGuiSettingsHandler----------------------------
local ImGuiSettingsHandler= {}
ImGuiSettingsHandler.__index = ImGuiSettingsHandler
function ImGuiSettingsHandler.__new(ctype)
    local ptr = lib.ImGuiSettingsHandler_ImGuiSettingsHandler()
    return ffi.gc(ptr,lib.ImGuiSettingsHandler_destroy)
end
M.ImGuiSettingsHandler = ffi.metatype("ImGuiSettingsHandler",ImGuiSettingsHandler)
--------------------------ImGuiStackSizes----------------------------
local ImGuiStackSizes= {}
ImGuiStackSizes.__index = ImGuiStackSizes
ImGuiStackSizes.CompareWithCurrentState = lib.ImGuiStackSizes_CompareWithCurrentState
function ImGuiStackSizes.__new(ctype)
    local ptr = lib.ImGuiStackSizes_ImGuiStackSizes()
    return ffi.gc(ptr,lib.ImGuiStackSizes_destroy)
end
ImGuiStackSizes.SetToCurrentState = lib.ImGuiStackSizes_SetToCurrentState
M.ImGuiStackSizes = ffi.metatype("ImGuiStackSizes",ImGuiStackSizes)
--------------------------ImGuiStorage----------------------------
local ImGuiStorage= {}
ImGuiStorage.__index = ImGuiStorage
ImGuiStorage.BuildSortByKey = lib.ImGuiStorage_BuildSortByKey
ImGuiStorage.Clear = lib.ImGuiStorage_Clear
function ImGuiStorage:GetBool(key,default_val)
    default_val = default_val or false
    return lib.ImGuiStorage_GetBool(self,key,default_val)
end
function ImGuiStorage:GetBoolRef(key,default_val)
    default_val = default_val or false
    return lib.ImGuiStorage_GetBoolRef(self,key,default_val)
end
function ImGuiStorage:GetFloat(key,default_val)
    default_val = default_val or 0.0
    return lib.ImGuiStorage_GetFloat(self,key,default_val)
end
function ImGuiStorage:GetFloatRef(key,default_val)
    default_val = default_val or 0.0
    return lib.ImGuiStorage_GetFloatRef(self,key,default_val)
end
function ImGuiStorage:GetInt(key,default_val)
    default_val = default_val or 0
    return lib.ImGuiStorage_GetInt(self,key,default_val)
end
function ImGuiStorage:GetIntRef(key,default_val)
    default_val = default_val or 0
    return lib.ImGuiStorage_GetIntRef(self,key,default_val)
end
ImGuiStorage.GetVoidPtr = lib.ImGuiStorage_GetVoidPtr
function ImGuiStorage:GetVoidPtrRef(key,default_val)
    default_val = default_val or nil
    return lib.ImGuiStorage_GetVoidPtrRef(self,key,default_val)
end
ImGuiStorage.SetAllInt = lib.ImGuiStorage_SetAllInt
ImGuiStorage.SetBool = lib.ImGuiStorage_SetBool
ImGuiStorage.SetFloat = lib.ImGuiStorage_SetFloat
ImGuiStorage.SetInt = lib.ImGuiStorage_SetInt
ImGuiStorage.SetVoidPtr = lib.ImGuiStorage_SetVoidPtr
M.ImGuiStorage = ffi.metatype("ImGuiStorage",ImGuiStorage)
--------------------------ImGuiStoragePair----------------------------
local ImGuiStoragePair= {}
ImGuiStoragePair.__index = ImGuiStoragePair
function ImGuiStoragePair.ImGuiStoragePairInt(_key,_val_i)
    local ptr = lib.ImGuiStoragePair_ImGuiStoragePairInt(_key,_val_i)
    return ffi.gc(ptr,lib.ImGuiStoragePair_destroy)
end
function ImGuiStoragePair.ImGuiStoragePairFloat(_key,_val_f)
    local ptr = lib.ImGuiStoragePair_ImGuiStoragePairFloat(_key,_val_f)
    return ffi.gc(ptr,lib.ImGuiStoragePair_destroy)
end
function ImGuiStoragePair.ImGuiStoragePairPtr(_key,_val_p)
    local ptr = lib.ImGuiStoragePair_ImGuiStoragePairPtr(_key,_val_p)
    return ffi.gc(ptr,lib.ImGuiStoragePair_destroy)
end
function ImGuiStoragePair.__new(ctype,a1,a2) -- generic version
    if (ffi.istype('int',a2) or type(a2)=='number') then return ImGuiStoragePair.ImGuiStoragePairInt(a1,a2) end
    if (ffi.istype('float',a2) or type(a2)=='number') then return ImGuiStoragePair.ImGuiStoragePairFloat(a1,a2) end
    if ffi.istype('void*',a2) then return ImGuiStoragePair.ImGuiStoragePairPtr(a1,a2) end
    print(ctype,a1,a2)
    error'ImGuiStoragePair.__new could not find overloaded'
end
M.ImGuiStoragePair = ffi.metatype("ImGuiStoragePair",ImGuiStoragePair)
--------------------------ImGuiStyle----------------------------
local ImGuiStyle= {}
ImGuiStyle.__index = ImGuiStyle
function ImGuiStyle.__new(ctype)
    local ptr = lib.ImGuiStyle_ImGuiStyle()
    return ffi.gc(ptr,lib.ImGuiStyle_destroy)
end
ImGuiStyle.ScaleAllSizes = lib.ImGuiStyle_ScaleAllSizes
M.ImGuiStyle = ffi.metatype("ImGuiStyle",ImGuiStyle)
--------------------------ImGuiStyleMod----------------------------
local ImGuiStyleMod= {}
ImGuiStyleMod.__index = ImGuiStyleMod
function ImGuiStyleMod.ImGuiStyleModInt(idx,v)
    local ptr = lib.ImGuiStyleMod_ImGuiStyleModInt(idx,v)
    return ffi.gc(ptr,lib.ImGuiStyleMod_destroy)
end
function ImGuiStyleMod.ImGuiStyleModFloat(idx,v)
    local ptr = lib.ImGuiStyleMod_ImGuiStyleModFloat(idx,v)
    return ffi.gc(ptr,lib.ImGuiStyleMod_destroy)
end
function ImGuiStyleMod.ImGuiStyleModVec2(idx,v)
    local ptr = lib.ImGuiStyleMod_ImGuiStyleModVec2(idx,v)
    return ffi.gc(ptr,lib.ImGuiStyleMod_destroy)
end
function ImGuiStyleMod.__new(ctype,a1,a2) -- generic version
    if (ffi.istype('int',a2) or type(a2)=='number') then return ImGuiStyleMod.ImGuiStyleModInt(a1,a2) end
    if (ffi.istype('float',a2) or type(a2)=='number') then return ImGuiStyleMod.ImGuiStyleModFloat(a1,a2) end
    if ffi.istype('ImVec2',a2) then return ImGuiStyleMod.ImGuiStyleModVec2(a1,a2) end
    print(ctype,a1,a2)
    error'ImGuiStyleMod.__new could not find overloaded'
end
M.ImGuiStyleMod = ffi.metatype("ImGuiStyleMod",ImGuiStyleMod)
--------------------------ImGuiTabBar----------------------------
local ImGuiTabBar= {}
ImGuiTabBar.__index = ImGuiTabBar
ImGuiTabBar.GetTabName = lib.ImGuiTabBar_GetTabName
ImGuiTabBar.GetTabOrder = lib.ImGuiTabBar_GetTabOrder
function ImGuiTabBar.__new(ctype)
    local ptr = lib.ImGuiTabBar_ImGuiTabBar()
    return ffi.gc(ptr,lib.ImGuiTabBar_destroy)
end
M.ImGuiTabBar = ffi.metatype("ImGuiTabBar",ImGuiTabBar)
--------------------------ImGuiTabItem----------------------------
local ImGuiTabItem= {}
ImGuiTabItem.__index = ImGuiTabItem
function ImGuiTabItem.__new(ctype)
    local ptr = lib.ImGuiTabItem_ImGuiTabItem()
    return ffi.gc(ptr,lib.ImGuiTabItem_destroy)
end
M.ImGuiTabItem = ffi.metatype("ImGuiTabItem",ImGuiTabItem)
--------------------------ImGuiTable----------------------------
local ImGuiTable= {}
ImGuiTable.__index = ImGuiTable
function ImGuiTable.__new(ctype)
    local ptr = lib.ImGuiTable_ImGuiTable()
    return ffi.gc(ptr,lib.ImGuiTable_destroy)
end
M.ImGuiTable = ffi.metatype("ImGuiTable",ImGuiTable)
--------------------------ImGuiTableColumn----------------------------
local ImGuiTableColumn= {}
ImGuiTableColumn.__index = ImGuiTableColumn
function ImGuiTableColumn.__new(ctype)
    local ptr = lib.ImGuiTableColumn_ImGuiTableColumn()
    return ffi.gc(ptr,lib.ImGuiTableColumn_destroy)
end
M.ImGuiTableColumn = ffi.metatype("ImGuiTableColumn",ImGuiTableColumn)
--------------------------ImGuiTableColumnSettings----------------------------
local ImGuiTableColumnSettings= {}
ImGuiTableColumnSettings.__index = ImGuiTableColumnSettings
function ImGuiTableColumnSettings.__new(ctype)
    local ptr = lib.ImGuiTableColumnSettings_ImGuiTableColumnSettings()
    return ffi.gc(ptr,lib.ImGuiTableColumnSettings_destroy)
end
M.ImGuiTableColumnSettings = ffi.metatype("ImGuiTableColumnSettings",ImGuiTableColumnSettings)
--------------------------ImGuiTableColumnSortSpecs----------------------------
local ImGuiTableColumnSortSpecs= {}
ImGuiTableColumnSortSpecs.__index = ImGuiTableColumnSortSpecs
function ImGuiTableColumnSortSpecs.__new(ctype)
    local ptr = lib.ImGuiTableColumnSortSpecs_ImGuiTableColumnSortSpecs()
    return ffi.gc(ptr,lib.ImGuiTableColumnSortSpecs_destroy)
end
M.ImGuiTableColumnSortSpecs = ffi.metatype("ImGuiTableColumnSortSpecs",ImGuiTableColumnSortSpecs)
--------------------------ImGuiTableSettings----------------------------
local ImGuiTableSettings= {}
ImGuiTableSettings.__index = ImGuiTableSettings
ImGuiTableSettings.GetColumnSettings = lib.ImGuiTableSettings_GetColumnSettings
function ImGuiTableSettings.__new(ctype)
    local ptr = lib.ImGuiTableSettings_ImGuiTableSettings()
    return ffi.gc(ptr,lib.ImGuiTableSettings_destroy)
end
M.ImGuiTableSettings = ffi.metatype("ImGuiTableSettings",ImGuiTableSettings)
--------------------------ImGuiTableSortSpecs----------------------------
local ImGuiTableSortSpecs= {}
ImGuiTableSortSpecs.__index = ImGuiTableSortSpecs
function ImGuiTableSortSpecs.__new(ctype)
    local ptr = lib.ImGuiTableSortSpecs_ImGuiTableSortSpecs()
    return ffi.gc(ptr,lib.ImGuiTableSortSpecs_destroy)
end
M.ImGuiTableSortSpecs = ffi.metatype("ImGuiTableSortSpecs",ImGuiTableSortSpecs)
--------------------------ImGuiTextBuffer----------------------------
local ImGuiTextBuffer= {}
ImGuiTextBuffer.__index = ImGuiTextBuffer
function ImGuiTextBuffer.__new(ctype)
    local ptr = lib.ImGuiTextBuffer_ImGuiTextBuffer()
    return ffi.gc(ptr,lib.ImGuiTextBuffer_destroy)
end
function ImGuiTextBuffer:append(str,str_end)
    str_end = str_end or nil
    return lib.ImGuiTextBuffer_append(self,str,str_end)
end
ImGuiTextBuffer.appendf = lib.ImGuiTextBuffer_appendf
ImGuiTextBuffer.appendfv = lib.ImGuiTextBuffer_appendfv
ImGuiTextBuffer.begin = lib.ImGuiTextBuffer_begin
ImGuiTextBuffer.c_str = lib.ImGuiTextBuffer_c_str
ImGuiTextBuffer.clear = lib.ImGuiTextBuffer_clear
ImGuiTextBuffer.empty = lib.ImGuiTextBuffer_empty
ImGuiTextBuffer._end = lib.ImGuiTextBuffer_end
ImGuiTextBuffer.reserve = lib.ImGuiTextBuffer_reserve
ImGuiTextBuffer.size = lib.ImGuiTextBuffer_size
M.ImGuiTextBuffer = ffi.metatype("ImGuiTextBuffer",ImGuiTextBuffer)
--------------------------ImGuiTextFilter----------------------------
local ImGuiTextFilter= {}
ImGuiTextFilter.__index = ImGuiTextFilter
ImGuiTextFilter.Build = lib.ImGuiTextFilter_Build
ImGuiTextFilter.Clear = lib.ImGuiTextFilter_Clear
function ImGuiTextFilter:Draw(label,width)
    label = label or "Filter(inc,-exc)"
    width = width or 0.0
    return lib.ImGuiTextFilter_Draw(self,label,width)
end
function ImGuiTextFilter.__new(ctype,default_filter)
    if default_filter == nil then default_filter = "" end
    local ptr = lib.ImGuiTextFilter_ImGuiTextFilter(default_filter)
    return ffi.gc(ptr,lib.ImGuiTextFilter_destroy)
end
ImGuiTextFilter.IsActive = lib.ImGuiTextFilter_IsActive
function ImGuiTextFilter:PassFilter(text,text_end)
    text_end = text_end or nil
    return lib.ImGuiTextFilter_PassFilter(self,text,text_end)
end
M.ImGuiTextFilter = ffi.metatype("ImGuiTextFilter",ImGuiTextFilter)
--------------------------ImGuiTextRange----------------------------
local ImGuiTextRange= {}
ImGuiTextRange.__index = ImGuiTextRange
function ImGuiTextRange.ImGuiTextRangeNil()
    local ptr = lib.ImGuiTextRange_ImGuiTextRangeNil()
    return ffi.gc(ptr,lib.ImGuiTextRange_destroy)
end
function ImGuiTextRange.ImGuiTextRangeStr(_b,_e)
    local ptr = lib.ImGuiTextRange_ImGuiTextRangeStr(_b,_e)
    return ffi.gc(ptr,lib.ImGuiTextRange_destroy)
end
function ImGuiTextRange.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImGuiTextRange.ImGuiTextRangeNil() end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return ImGuiTextRange.ImGuiTextRangeStr(a1,a2) end
    print(ctype,a1,a2)
    error'ImGuiTextRange.__new could not find overloaded'
end
ImGuiTextRange.empty = lib.ImGuiTextRange_empty
ImGuiTextRange.split = lib.ImGuiTextRange_split
M.ImGuiTextRange = ffi.metatype("ImGuiTextRange",ImGuiTextRange)
--------------------------ImGuiViewport----------------------------
local ImGuiViewport= {}
ImGuiViewport.__index = ImGuiViewport
function ImGuiViewport:GetCenter()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImGuiViewport_GetCenter(nonUDT_out,self)
    return nonUDT_out
end
function ImGuiViewport:GetWorkCenter()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImGuiViewport_GetWorkCenter(nonUDT_out,self)
    return nonUDT_out
end
function ImGuiViewport.__new(ctype)
    local ptr = lib.ImGuiViewport_ImGuiViewport()
    return ffi.gc(ptr,lib.ImGuiViewport_destroy)
end
M.ImGuiViewport = ffi.metatype("ImGuiViewport",ImGuiViewport)
--------------------------ImGuiViewportP----------------------------
local ImGuiViewportP= {}
ImGuiViewportP.__index = ImGuiViewportP
ImGuiViewportP.ClearRequestFlags = lib.ImGuiViewportP_ClearRequestFlags
function ImGuiViewportP:GetMainRect()
    local nonUDT_out = ffi.new("ImRect")
    lib.ImGuiViewportP_GetMainRect(nonUDT_out,self)
    return nonUDT_out
end
function ImGuiViewportP:GetWorkRect()
    local nonUDT_out = ffi.new("ImRect")
    lib.ImGuiViewportP_GetWorkRect(nonUDT_out,self)
    return nonUDT_out
end
function ImGuiViewportP.__new(ctype)
    local ptr = lib.ImGuiViewportP_ImGuiViewportP()
    return ffi.gc(ptr,lib.ImGuiViewportP_destroy)
end
ImGuiViewportP.UpdateWorkRect = lib.ImGuiViewportP_UpdateWorkRect
M.ImGuiViewportP = ffi.metatype("ImGuiViewportP",ImGuiViewportP)
--------------------------ImGuiWindow----------------------------
local ImGuiWindow= {}
ImGuiWindow.__index = ImGuiWindow
ImGuiWindow.CalcFontSize = lib.ImGuiWindow_CalcFontSize
function ImGuiWindow:GetIDStr(str,str_end)
    str_end = str_end or nil
    return lib.ImGuiWindow_GetIDStr(self,str,str_end)
end
ImGuiWindow.GetIDPtr = lib.ImGuiWindow_GetIDPtr
ImGuiWindow.GetIDInt = lib.ImGuiWindow_GetIDInt
function ImGuiWindow:GetID(a2,a3) -- generic version
    if (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return self:GetIDStr(a2,a3) end
    if ffi.istype('const void*',a2) then return self:GetIDPtr(a2) end
    if (ffi.istype('int',a2) or type(a2)=='number') then return self:GetIDInt(a2) end
    print(a2,a3)
    error'ImGuiWindow:GetID could not find overloaded'
end
ImGuiWindow.GetIDFromRectangle = lib.ImGuiWindow_GetIDFromRectangle
function ImGuiWindow:GetIDNoKeepAliveStr(str,str_end)
    str_end = str_end or nil
    return lib.ImGuiWindow_GetIDNoKeepAliveStr(self,str,str_end)
end
ImGuiWindow.GetIDNoKeepAlivePtr = lib.ImGuiWindow_GetIDNoKeepAlivePtr
ImGuiWindow.GetIDNoKeepAliveInt = lib.ImGuiWindow_GetIDNoKeepAliveInt
function ImGuiWindow:GetIDNoKeepAlive(a2,a3) -- generic version
    if (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return self:GetIDNoKeepAliveStr(a2,a3) end
    if ffi.istype('const void*',a2) then return self:GetIDNoKeepAlivePtr(a2) end
    if (ffi.istype('int',a2) or type(a2)=='number') then return self:GetIDNoKeepAliveInt(a2) end
    print(a2,a3)
    error'ImGuiWindow:GetIDNoKeepAlive could not find overloaded'
end
function ImGuiWindow.__new(ctype,context,name)
    local ptr = lib.ImGuiWindow_ImGuiWindow(context,name)
    return ffi.gc(ptr,lib.ImGuiWindow_destroy)
end
ImGuiWindow.MenuBarHeight = lib.ImGuiWindow_MenuBarHeight
function ImGuiWindow:MenuBarRect()
    local nonUDT_out = ffi.new("ImRect")
    lib.ImGuiWindow_MenuBarRect(nonUDT_out,self)
    return nonUDT_out
end
function ImGuiWindow:Rect()
    local nonUDT_out = ffi.new("ImRect")
    lib.ImGuiWindow_Rect(nonUDT_out,self)
    return nonUDT_out
end
ImGuiWindow.TitleBarHeight = lib.ImGuiWindow_TitleBarHeight
function ImGuiWindow:TitleBarRect()
    local nonUDT_out = ffi.new("ImRect")
    lib.ImGuiWindow_TitleBarRect(nonUDT_out,self)
    return nonUDT_out
end
M.ImGuiWindow = ffi.metatype("ImGuiWindow",ImGuiWindow)
--------------------------ImGuiWindowClass----------------------------
local ImGuiWindowClass= {}
ImGuiWindowClass.__index = ImGuiWindowClass
function ImGuiWindowClass.__new(ctype)
    local ptr = lib.ImGuiWindowClass_ImGuiWindowClass()
    return ffi.gc(ptr,lib.ImGuiWindowClass_destroy)
end
M.ImGuiWindowClass = ffi.metatype("ImGuiWindowClass",ImGuiWindowClass)
--------------------------ImGuiWindowSettings----------------------------
local ImGuiWindowSettings= {}
ImGuiWindowSettings.__index = ImGuiWindowSettings
ImGuiWindowSettings.GetName = lib.ImGuiWindowSettings_GetName
function ImGuiWindowSettings.__new(ctype)
    local ptr = lib.ImGuiWindowSettings_ImGuiWindowSettings()
    return ffi.gc(ptr,lib.ImGuiWindowSettings_destroy)
end
M.ImGuiWindowSettings = ffi.metatype("ImGuiWindowSettings",ImGuiWindowSettings)
--------------------------ImPlotInputMap----------------------------
local ImPlotInputMap= {}
ImPlotInputMap.__index = ImPlotInputMap
function ImPlotInputMap.__new(ctype)
    local ptr = lib.ImPlotInputMap_ImPlotInputMap()
    return ffi.gc(ptr,lib.ImPlotInputMap_destroy)
end
M.ImPlotInputMap = ffi.metatype("ImPlotInputMap",ImPlotInputMap)
--------------------------ImPlotLimits----------------------------
local ImPlotLimits= {}
ImPlotLimits.__index = ImPlotLimits
ImPlotLimits.ContainsPlotPoInt = lib.ImPlotLimits_ContainsPlotPoInt
ImPlotLimits.Containsdouble = lib.ImPlotLimits_Containsdouble
function ImPlotLimits:Contains(a2,a3) -- generic version
    if ffi.istype('const ImPlotPoint',a2) then return self:ContainsPlotPoInt(a2) end
    if (ffi.istype('double',a2) or type(a2)=='number') then return self:Containsdouble(a2,a3) end
    print(a2,a3)
    error'ImPlotLimits:Contains could not find overloaded'
end
M.ImPlotLimits = ffi.metatype("ImPlotLimits",ImPlotLimits)
--------------------------ImPlotPoint----------------------------
local ImPlotPoint= {}
ImPlotPoint.__index = ImPlotPoint
function ImPlotPoint.ImPlotPointNil()
    local ptr = lib.ImPlotPoint_ImPlotPointNil()
    return ffi.gc(ptr,lib.ImPlotPoint_destroy)
end
function ImPlotPoint.ImPlotPointdouble(_x,_y)
    local ptr = lib.ImPlotPoint_ImPlotPointdouble(_x,_y)
    return ffi.gc(ptr,lib.ImPlotPoint_destroy)
end
function ImPlotPoint.ImPlotPointVec2(p)
    local ptr = lib.ImPlotPoint_ImPlotPointVec2(p)
    return ffi.gc(ptr,lib.ImPlotPoint_destroy)
end
function ImPlotPoint.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImPlotPoint.ImPlotPointNil() end
    if (ffi.istype('double',a1) or type(a1)=='number') then return ImPlotPoint.ImPlotPointdouble(a1,a2) end
    if ffi.istype('const ImVec2',a1) then return ImPlotPoint.ImPlotPointVec2(a1) end
    print(ctype,a1,a2)
    error'ImPlotPoint.__new could not find overloaded'
end
M.ImPlotPoint = ffi.metatype("ImPlotPoint",ImPlotPoint)
--------------------------ImPlotRange----------------------------
local ImPlotRange= {}
ImPlotRange.__index = ImPlotRange
ImPlotRange.Contains = lib.ImPlotRange_Contains
function ImPlotRange.ImPlotRangeNil()
    local ptr = lib.ImPlotRange_ImPlotRangeNil()
    return ffi.gc(ptr,lib.ImPlotRange_destroy)
end
function ImPlotRange.ImPlotRangedouble(_min,_max)
    local ptr = lib.ImPlotRange_ImPlotRangedouble(_min,_max)
    return ffi.gc(ptr,lib.ImPlotRange_destroy)
end
function ImPlotRange.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImPlotRange.ImPlotRangeNil() end
    if (ffi.istype('double',a1) or type(a1)=='number') then return ImPlotRange.ImPlotRangedouble(a1,a2) end
    print(ctype,a1,a2)
    error'ImPlotRange.__new could not find overloaded'
end
ImPlotRange.Size = lib.ImPlotRange_Size
M.ImPlotRange = ffi.metatype("ImPlotRange",ImPlotRange)
--------------------------ImPlotStyle----------------------------
local ImPlotStyle= {}
ImPlotStyle.__index = ImPlotStyle
function ImPlotStyle.__new(ctype)
    local ptr = lib.ImPlotStyle_ImPlotStyle()
    return ffi.gc(ptr,lib.ImPlotStyle_destroy)
end
M.ImPlotStyle = ffi.metatype("ImPlotStyle",ImPlotStyle)
--------------------------ImRect----------------------------
local ImRect= {}
ImRect.__index = ImRect
ImRect.AddVec2 = lib.ImRect_AddVec2
ImRect.AddRect = lib.ImRect_AddRect
function ImRect:Add(a2) -- generic version
    if ffi.istype('const ImVec2',a2) then return self:AddVec2(a2) end
    if ffi.istype('const ImRect',a2) then return self:AddRect(a2) end
    print(a2)
    error'ImRect:Add could not find overloaded'
end
ImRect.ClipWith = lib.ImRect_ClipWith
ImRect.ClipWithFull = lib.ImRect_ClipWithFull
ImRect.ContainsVec2 = lib.ImRect_ContainsVec2
ImRect.ContainsRect = lib.ImRect_ContainsRect
function ImRect:Contains(a2) -- generic version
    if ffi.istype('const ImVec2',a2) then return self:ContainsVec2(a2) end
    if ffi.istype('const ImRect',a2) then return self:ContainsRect(a2) end
    print(a2)
    error'ImRect:Contains could not find overloaded'
end
ImRect.ExpandFloat = lib.ImRect_ExpandFloat
ImRect.ExpandVec2 = lib.ImRect_ExpandVec2
function ImRect:Expand(a2) -- generic version
    if ffi.istype('const float',a2) then return self:ExpandFloat(a2) end
    if ffi.istype('const ImVec2',a2) then return self:ExpandVec2(a2) end
    print(a2)
    error'ImRect:Expand could not find overloaded'
end
ImRect.Floor = lib.ImRect_Floor
function ImRect:GetBL()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImRect_GetBL(nonUDT_out,self)
    return nonUDT_out
end
function ImRect:GetBR()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImRect_GetBR(nonUDT_out,self)
    return nonUDT_out
end
function ImRect:GetCenter()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImRect_GetCenter(nonUDT_out,self)
    return nonUDT_out
end
ImRect.GetHeight = lib.ImRect_GetHeight
function ImRect:GetSize()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImRect_GetSize(nonUDT_out,self)
    return nonUDT_out
end
function ImRect:GetTL()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImRect_GetTL(nonUDT_out,self)
    return nonUDT_out
end
function ImRect:GetTR()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImRect_GetTR(nonUDT_out,self)
    return nonUDT_out
end
ImRect.GetWidth = lib.ImRect_GetWidth
function ImRect.ImRectNil()
    local ptr = lib.ImRect_ImRectNil()
    return ffi.gc(ptr,lib.ImRect_destroy)
end
function ImRect.ImRectVec2(min,max)
    local ptr = lib.ImRect_ImRectVec2(min,max)
    return ffi.gc(ptr,lib.ImRect_destroy)
end
function ImRect.ImRectVec4(v)
    local ptr = lib.ImRect_ImRectVec4(v)
    return ffi.gc(ptr,lib.ImRect_destroy)
end
function ImRect.ImRectFloat(x1,y1,x2,y2)
    local ptr = lib.ImRect_ImRectFloat(x1,y1,x2,y2)
    return ffi.gc(ptr,lib.ImRect_destroy)
end
function ImRect.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImRect.ImRectNil() end
    if ffi.istype('const ImVec2',a1) then return ImRect.ImRectVec2(a1,a2) end
    if ffi.istype('const ImVec4',a1) then return ImRect.ImRectVec4(a1) end
    if (ffi.istype('float',a1) or type(a1)=='number') then return ImRect.ImRectFloat(a1,a2,a3,a4) end
    print(ctype,a1,a2,a3,a4)
    error'ImRect.__new could not find overloaded'
end
ImRect.IsInverted = lib.ImRect_IsInverted
ImRect.Overlaps = lib.ImRect_Overlaps
function ImRect:ToVec4()
    local nonUDT_out = ffi.new("ImVec4")
    lib.ImRect_ToVec4(nonUDT_out,self)
    return nonUDT_out
end
ImRect.Translate = lib.ImRect_Translate
ImRect.TranslateX = lib.ImRect_TranslateX
ImRect.TranslateY = lib.ImRect_TranslateY
M.ImRect = ffi.metatype("ImRect",ImRect)
--------------------------ImVec1----------------------------
local ImVec1= {}
ImVec1.__index = ImVec1
function ImVec1.ImVec1Nil()
    local ptr = lib.ImVec1_ImVec1Nil()
    return ffi.gc(ptr,lib.ImVec1_destroy)
end
function ImVec1.ImVec1Float(_x)
    local ptr = lib.ImVec1_ImVec1Float(_x)
    return ffi.gc(ptr,lib.ImVec1_destroy)
end
function ImVec1.__new(ctype,a1) -- generic version
    if a1==nil then return ImVec1.ImVec1Nil() end
    if (ffi.istype('float',a1) or type(a1)=='number') then return ImVec1.ImVec1Float(a1) end
    print(ctype,a1)
    error'ImVec1.__new could not find overloaded'
end
M.ImVec1 = ffi.metatype("ImVec1",ImVec1)
--------------------------ImVec2ih----------------------------
local ImVec2ih= {}
ImVec2ih.__index = ImVec2ih
function ImVec2ih.ImVec2ihNil()
    local ptr = lib.ImVec2ih_ImVec2ihNil()
    return ffi.gc(ptr,lib.ImVec2ih_destroy)
end
function ImVec2ih.ImVec2ihshort(_x,_y)
    local ptr = lib.ImVec2ih_ImVec2ihshort(_x,_y)
    return ffi.gc(ptr,lib.ImVec2ih_destroy)
end
function ImVec2ih.ImVec2ihVec2(rhs)
    local ptr = lib.ImVec2ih_ImVec2ihVec2(rhs)
    return ffi.gc(ptr,lib.ImVec2ih_destroy)
end
function ImVec2ih.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImVec2ih.ImVec2ihNil() end
    if ffi.istype('short',a1) then return ImVec2ih.ImVec2ihshort(a1,a2) end
    if ffi.istype('const ImVec2',a1) then return ImVec2ih.ImVec2ihVec2(a1) end
    print(ctype,a1,a2)
    error'ImVec2ih.__new could not find overloaded'
end
M.ImVec2ih = ffi.metatype("ImVec2ih",ImVec2ih)
--------------------------LinkDetachWithModifierClick----------------------------
local LinkDetachWithModifierClick= {}
LinkDetachWithModifierClick.__index = LinkDetachWithModifierClick
function LinkDetachWithModifierClick.__new(ctype)
    local ptr = lib.LinkDetachWithModifierClick_LinkDetachWithModifierClick()
    return ffi.gc(ptr,lib.LinkDetachWithModifierClick_destroy)
end
M.LinkDetachWithModifierClick = ffi.metatype("LinkDetachWithModifierClick",LinkDetachWithModifierClick)
--------------------------Style----------------------------
local Style= {}
Style.__index = Style
function Style.__new(ctype)
    local ptr = lib.Style_Style()
    return ffi.gc(ptr,lib.Style_destroy)
end
M.Style = ffi.metatype("Style",Style)
--------------------------imguiGizmo----------------------------
local imguiGizmo= {}
imguiGizmo.__index = imguiGizmo
M.imguiGizmo_buildCone = lib.imguiGizmo_buildCone
M.imguiGizmo_buildCube = lib.imguiGizmo_buildCube
M.imguiGizmo_buildCylinder = lib.imguiGizmo_buildCylinder
function M.imguiGizmo_buildPlane(size,thickness)
    thickness = thickness or planeThickness
    return lib.imguiGizmo_buildPlane(size,thickness)
end
M.imguiGizmo_buildPolygon = lib.imguiGizmo_buildPolygon
M.imguiGizmo_buildSphere = lib.imguiGizmo_buildSphere
imguiGizmo.drawFunc = lib.imguiGizmo_drawFunc
M.imguiGizmo_getDollyScale = lib.imguiGizmo_getDollyScale
M.imguiGizmo_getGizmoFeelingRot = lib.imguiGizmo_getGizmoFeelingRot
M.imguiGizmo_getPanScale = lib.imguiGizmo_getPanScale
imguiGizmo.getTransformsvec3Ptr = lib.imguiGizmo_getTransformsvec3Ptr
imguiGizmo.getTransformsvec4Ptr = lib.imguiGizmo_getTransformsvec4Ptr
function imguiGizmo:getTransforms(a2,a3,a4,a5) -- generic version
    if (ffi.istype('G3Dvec3*',a4) or ffi.istype('G3Dvec3',a4) or ffi.istype('G3Dvec3[]',a4)) then return self:getTransformsvec3Ptr(a2,a3,a4,a5) end
    if (ffi.istype('G3Dvec4*',a4) or ffi.istype('G3Dvec4',a4) or ffi.istype('G3Dvec4[]',a4)) then return self:getTransformsvec4Ptr(a2,a3,a4,a5) end
    print(a2,a3,a4,a5)
    error'imguiGizmo:getTransforms could not find overloaded'
end
imguiGizmo.modeSettings = lib.imguiGizmo_modeSettings
M.imguiGizmo_resizeAxesOf = lib.imguiGizmo_resizeAxesOf
M.imguiGizmo_resizeSolidOf = lib.imguiGizmo_resizeSolidOf
M.imguiGizmo_restoreAxesSize = lib.imguiGizmo_restoreAxesSize
M.imguiGizmo_restoreDirectionColor = lib.imguiGizmo_restoreDirectionColor
M.imguiGizmo_restoreSolidSize = lib.imguiGizmo_restoreSolidSize
M.imguiGizmo_restoreSphereColors = lib.imguiGizmo_restoreSphereColors
M.imguiGizmo_setDirectionColorU32U32 = lib.imguiGizmo_setDirectionColorU32U32
M.imguiGizmo_setDirectionColorVec4Vec4 = lib.imguiGizmo_setDirectionColorVec4Vec4
M.imguiGizmo_setDirectionColorU32 = lib.imguiGizmo_setDirectionColorU32
M.imguiGizmo_setDirectionColorVec4 = lib.imguiGizmo_setDirectionColorVec4
function M.imguiGizmo_setDirectionColor(a1,a2) -- generic version
    if (ffi.istype('ImU32',a1) or type(a1)=='number') and ffi.istype('const ImU32',a2) then return M.imguiGizmo_setDirectionColorU32U32(a1,a2) end
    if ffi.istype('const ImVec4',a1) and ffi.istype('const ImVec4',a2) then return M.imguiGizmo_setDirectionColorVec4Vec4(a1,a2) end
    if (ffi.istype('ImU32',a1) or type(a1)=='number') and a2==nil then return M.imguiGizmo_setDirectionColorU32(a1) end
    if ffi.istype('const ImVec4',a1) and a2==nil then return M.imguiGizmo_setDirectionColorVec4(a1) end
    print(a1,a2)
    error'M.imguiGizmo_setDirectionColor could not find overloaded'
end
M.imguiGizmo_setDollyModifier = lib.imguiGizmo_setDollyModifier
M.imguiGizmo_setDollyScale = lib.imguiGizmo_setDollyScale
imguiGizmo.setDualMode = lib.imguiGizmo_setDualMode
M.imguiGizmo_setGizmoFeelingRot = lib.imguiGizmo_setGizmoFeelingRot
M.imguiGizmo_setPanModifier = lib.imguiGizmo_setPanModifier
M.imguiGizmo_setPanScale = lib.imguiGizmo_setPanScale
M.imguiGizmo_setSphereColorsVec4 = lib.imguiGizmo_setSphereColorsVec4
M.imguiGizmo_setSphereColorsU32 = lib.imguiGizmo_setSphereColorsU32
function M.imguiGizmo_setSphereColors(a1,a2) -- generic version
    if ffi.istype('const ImVec4',a1) then return M.imguiGizmo_setSphereColorsVec4(a1,a2) end
    if (ffi.istype('ImU32',a1) or type(a1)=='number') then return M.imguiGizmo_setSphereColorsU32(a1,a2) end
    print(a1,a2)
    error'M.imguiGizmo_setSphereColors could not find overloaded'
end
M.imguiGizmo = ffi.metatype("imguiGizmo",imguiGizmo)
------------------------------------------------------
M.ImGuizmo_AllowAxisFlip = lib.ImGuizmo_AllowAxisFlip
M.ImGuizmo_BeginFrame = lib.ImGuizmo_BeginFrame
M.ImGuizmo_DecomposeMatrixToComponents = lib.ImGuizmo_DecomposeMatrixToComponents
M.ImGuizmo_DrawCubes = lib.ImGuizmo_DrawCubes
M.ImGuizmo_DrawGrid = lib.ImGuizmo_DrawGrid
M.ImGuizmo_Enable = lib.ImGuizmo_Enable
M.ImGuizmo_IsOverNil = lib.ImGuizmo_IsOverNil
M.ImGuizmo_IsOverOPERATION = lib.ImGuizmo_IsOverOPERATION
function M.ImGuizmo_IsOver(a1) -- generic version
    if a1==nil then return M.ImGuizmo_IsOverNil() end
    if ffi.istype('OPERATION',a1) then return M.ImGuizmo_IsOverOPERATION(a1) end
    print(a1)
    error'M.ImGuizmo_IsOver could not find overloaded'
end
M.ImGuizmo_IsUsing = lib.ImGuizmo_IsUsing
function M.ImGuizmo_Manipulate(view,projection,operation,mode,matrix,deltaMatrix,snap,localBounds,boundsSnap)
    boundsSnap = boundsSnap or nil
    deltaMatrix = deltaMatrix or nil
    localBounds = localBounds or nil
    snap = snap or nil
    return lib.ImGuizmo_Manipulate(view,projection,operation,mode,matrix,deltaMatrix,snap,localBounds,boundsSnap)
end
M.ImGuizmo_RecomposeMatrixFromComponents = lib.ImGuizmo_RecomposeMatrixFromComponents
function M.ImGuizmo_SetDrawlist(drawlist)
    drawlist = drawlist or nil
    return lib.ImGuizmo_SetDrawlist(drawlist)
end
M.ImGuizmo_SetGizmoSizeClipSpace = lib.ImGuizmo_SetGizmoSizeClipSpace
M.ImGuizmo_SetID = lib.ImGuizmo_SetID
M.ImGuizmo_SetImGuiContext = lib.ImGuizmo_SetImGuiContext
M.ImGuizmo_SetOrthographic = lib.ImGuizmo_SetOrthographic
M.ImGuizmo_SetRect = lib.ImGuizmo_SetRect
M.ImGuizmo_ViewManipulate = lib.ImGuizmo_ViewManipulate
M.ImNodes_AutoPositionNode = lib.ImNodes_AutoPositionNode
M.ImNodes_BeginCanvas = lib.ImNodes_BeginCanvas
M.ImNodes_BeginInputSlot = lib.ImNodes_BeginInputSlot
M.ImNodes_BeginNode = lib.ImNodes_BeginNode
M.ImNodes_BeginOutputSlot = lib.ImNodes_BeginOutputSlot
M.ImNodes_BeginSlot = lib.ImNodes_BeginSlot
M.ImNodes_Connection = lib.ImNodes_Connection
M.ImNodes_EndCanvas = lib.ImNodes_EndCanvas
M.ImNodes_EndNode = lib.ImNodes_EndNode
M.ImNodes_EndSlot = lib.ImNodes_EndSlot
M.ImNodes_Ez_BeginNode = lib.ImNodes_Ez_BeginNode
M.ImNodes_Ez_EndNode = lib.ImNodes_Ez_EndNode
M.ImNodes_Ez_InputSlots = lib.ImNodes_Ez_InputSlots
M.ImNodes_Ez_OutputSlots = lib.ImNodes_Ez_OutputSlots
M.ImNodes_GetCurrentCanvas = lib.ImNodes_GetCurrentCanvas
M.ImNodes_GetNewConnection = lib.ImNodes_GetNewConnection
M.ImNodes_GetPendingConnection = lib.ImNodes_GetPendingConnection
M.ImNodes_InputSlotKind = lib.ImNodes_InputSlotKind
M.ImNodes_IsConnectingCompatibleSlot = lib.ImNodes_IsConnectingCompatibleSlot
M.ImNodes_IsInputSlotKind = lib.ImNodes_IsInputSlotKind
M.ImNodes_IsOutputSlotKind = lib.ImNodes_IsOutputSlotKind
M.ImNodes_IsSlotCurveHovered = lib.ImNodes_IsSlotCurveHovered
M.ImNodes_OutputSlotKind = lib.ImNodes_OutputSlotKind
M.ImPlot_AnnotateStr = lib.ImPlot_AnnotateStr
M.ImPlot_AnnotateVec4 = lib.ImPlot_AnnotateVec4
function M.ImPlot_Annotate(a1,a2,a3,a4,...) -- generic version
    if (ffi.istype('const char*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') then return M.ImPlot_AnnotateStr(a1,a2,a3,a4,...) end
    if ffi.istype('const ImVec4',a4) then return M.ImPlot_AnnotateVec4(a1,a2,a3,a4,...) end
    print(a1,a2,a3,a4,...)
    error'M.ImPlot_Annotate could not find overloaded'
end
M.ImPlot_AnnotateClampedStr = lib.ImPlot_AnnotateClampedStr
M.ImPlot_AnnotateClampedVec4 = lib.ImPlot_AnnotateClampedVec4
function M.ImPlot_AnnotateClamped(a1,a2,a3,a4,...) -- generic version
    if (ffi.istype('const char*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') then return M.ImPlot_AnnotateClampedStr(a1,a2,a3,a4,...) end
    if ffi.istype('const ImVec4',a4) then return M.ImPlot_AnnotateClampedVec4(a1,a2,a3,a4,...) end
    print(a1,a2,a3,a4,...)
    error'M.ImPlot_AnnotateClamped could not find overloaded'
end
M.ImPlot_AnnotateClampedVStr = lib.ImPlot_AnnotateClampedVStr
M.ImPlot_AnnotateClampedVVec4 = lib.ImPlot_AnnotateClampedVVec4
function M.ImPlot_AnnotateClampedV(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('const char*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') then return M.ImPlot_AnnotateClampedVStr(a1,a2,a3,a4,a5) end
    if ffi.istype('const ImVec4',a4) then return M.ImPlot_AnnotateClampedVVec4(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot_AnnotateClampedV could not find overloaded'
end
M.ImPlot_AnnotateVStr = lib.ImPlot_AnnotateVStr
M.ImPlot_AnnotateVVec4 = lib.ImPlot_AnnotateVVec4
function M.ImPlot_AnnotateV(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('const char*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') then return M.ImPlot_AnnotateVStr(a1,a2,a3,a4,a5) end
    if ffi.istype('const ImVec4',a4) then return M.ImPlot_AnnotateVVec4(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot_AnnotateV could not find overloaded'
end
function M.ImPlot_BeginLegendDragDropSource(label_id,flags)
    flags = flags or 0
    return lib.ImPlot_BeginLegendDragDropSource(label_id,flags)
end
function M.ImPlot_BeginLegendPopup(label_id,mouse_button)
    mouse_button = mouse_button or 1
    return lib.ImPlot_BeginLegendPopup(label_id,mouse_button)
end
function M.ImPlot_BeginPlot(title_id,x_label,y_label,size,flags,x_flags,y_flags,y2_flags,y3_flags)
    flags = flags or 0
    size = size or ImVec2(-1,0)
    x_flags = x_flags or 0
    x_label = x_label or nil
    y2_flags = y2_flags or 1
    y3_flags = y3_flags or 1
    y_flags = y_flags or 0
    y_label = y_label or nil
    return lib.ImPlot_BeginPlot(title_id,x_label,y_label,size,flags,x_flags,y_flags,y2_flags,y3_flags)
end
M.ImPlot_CreateContext = lib.ImPlot_CreateContext
function M.ImPlot_DestroyContext(ctx)
    ctx = ctx or nil
    return lib.ImPlot_DestroyContext(ctx)
end
function M.ImPlot_DragLineX(id,x_value,show_label,col,thickness)
    col = col or ImVec4(0,0,0,-1)
    if show_label == nil then show_label = true end
    thickness = thickness or 1
    return lib.ImPlot_DragLineX(id,x_value,show_label,col,thickness)
end
function M.ImPlot_DragLineY(id,y_value,show_label,col,thickness)
    col = col or ImVec4(0,0,0,-1)
    if show_label == nil then show_label = true end
    thickness = thickness or 1
    return lib.ImPlot_DragLineY(id,y_value,show_label,col,thickness)
end
function M.ImPlot_DragPoint(id,x,y,show_label,col,radius)
    col = col or ImVec4(0,0,0,-1)
    radius = radius or 4
    if show_label == nil then show_label = true end
    return lib.ImPlot_DragPoint(id,x,y,show_label,col,radius)
end
M.ImPlot_EndLegendDragDropSource = lib.ImPlot_EndLegendDragDropSource
M.ImPlot_EndLegendPopup = lib.ImPlot_EndLegendPopup
M.ImPlot_EndPlot = lib.ImPlot_EndPlot
function M.ImPlot_FitNextPlotAxes(x,y,y2,y3)
    if x == nil then x = true end
    if y == nil then y = true end
    if y2 == nil then y2 = true end
    if y3 == nil then y3 = true end
    return lib.ImPlot_FitNextPlotAxes(x,y,y2,y3)
end
function M.ImPlot_GetColormapColor(index)
    local nonUDT_out = ffi.new("ImVec4")
    lib.ImPlot_GetColormapColor(nonUDT_out,index)
    return nonUDT_out
end
M.ImPlot_GetColormapName = lib.ImPlot_GetColormapName
M.ImPlot_GetColormapSize = lib.ImPlot_GetColormapSize
M.ImPlot_GetCurrentContext = lib.ImPlot_GetCurrentContext
M.ImPlot_GetInputMap = lib.ImPlot_GetInputMap
function M.ImPlot_GetLastItemColor()
    local nonUDT_out = ffi.new("ImVec4")
    lib.ImPlot_GetLastItemColor(nonUDT_out)
    return nonUDT_out
end
M.ImPlot_GetMarkerName = lib.ImPlot_GetMarkerName
M.ImPlot_GetPlotDrawList = lib.ImPlot_GetPlotDrawList
function M.ImPlot_GetPlotLimits(y_axis)
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImPlotLimits")
    lib.ImPlot_GetPlotLimits(nonUDT_out,y_axis)
    return nonUDT_out
end
function M.ImPlot_GetPlotMousePos(y_axis)
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImPlotPoint")
    lib.ImPlot_GetPlotMousePos(nonUDT_out,y_axis)
    return nonUDT_out
end
function M.ImPlot_GetPlotPos()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_GetPlotPos(nonUDT_out)
    return nonUDT_out
end
function M.ImPlot_GetPlotQuery(y_axis)
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImPlotLimits")
    lib.ImPlot_GetPlotQuery(nonUDT_out,y_axis)
    return nonUDT_out
end
function M.ImPlot_GetPlotSize()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_GetPlotSize(nonUDT_out)
    return nonUDT_out
end
M.ImPlot_GetStyle = lib.ImPlot_GetStyle
M.ImPlot_GetStyleColorName = lib.ImPlot_GetStyleColorName
function M.ImPlot_HideNextItem(hidden,cond)
    cond = cond or 2
    if hidden == nil then hidden = true end
    return lib.ImPlot_HideNextItem(hidden,cond)
end
M.ImPlot_IsLegendEntryHovered = lib.ImPlot_IsLegendEntryHovered
M.ImPlot_IsPlotHovered = lib.ImPlot_IsPlotHovered
M.ImPlot_IsPlotQueried = lib.ImPlot_IsPlotQueried
M.ImPlot_IsPlotXAxisHovered = lib.ImPlot_IsPlotXAxisHovered
function M.ImPlot_IsPlotYAxisHovered(y_axis)
    y_axis = y_axis or 0
    return lib.ImPlot_IsPlotYAxisHovered(y_axis)
end
function M.ImPlot_LerpColormap(t)
    local nonUDT_out = ffi.new("ImVec4")
    lib.ImPlot_LerpColormap(nonUDT_out,t)
    return nonUDT_out
end
function M.ImPlot_LinkNextPlotLimits(xmin,xmax,ymin,ymax,ymin2,ymax2,ymin3,ymax3)
    ymax2 = ymax2 or nil
    ymax3 = ymax3 or nil
    ymin2 = ymin2 or nil
    ymin3 = ymin3 or nil
    return lib.ImPlot_LinkNextPlotLimits(xmin,xmax,ymin,ymax,ymin2,ymax2,ymin3,ymax3)
end
function M.ImPlot_NextColormapColor()
    local nonUDT_out = ffi.new("ImVec4")
    lib.ImPlot_NextColormapColor(nonUDT_out)
    return nonUDT_out
end
function M.ImPlot_PixelsToPlotVec2(pix,y_axis)
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImPlotPoint")
    lib.ImPlot_PixelsToPlotVec2(nonUDT_out,pix,y_axis)
    return nonUDT_out
end
function M.ImPlot_PixelsToPlotFloat(x,y,y_axis)
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImPlotPoint")
    lib.ImPlot_PixelsToPlotFloat(nonUDT_out,x,y,y_axis)
    return nonUDT_out
end
function M.ImPlot_PixelsToPlot(a2,a3,a4) -- generic version
    if ffi.istype('const ImVec2',a2) then return M.ImPlot_PixelsToPlotVec2(a2,a3) end
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.ImPlot_PixelsToPlotFloat(a2,a3,a4) end
    print(a2,a3,a4)
    error'M.ImPlot_PixelsToPlot could not find overloaded'
end
function M.ImPlot_PlotBarsFloatPtrInt(label_id,values,count,width,shift,offset,stride)
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("float")
    width = width or 0.67
    return lib.ImPlot_PlotBarsFloatPtrInt(label_id,values,count,width,shift,offset,stride)
end
function M.ImPlot_PlotBarsdoublePtrInt(label_id,values,count,width,shift,offset,stride)
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("double")
    width = width or 0.67
    return lib.ImPlot_PlotBarsdoublePtrInt(label_id,values,count,width,shift,offset,stride)
end
function M.ImPlot_PlotBarsS8PtrInt(label_id,values,count,width,shift,offset,stride)
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImS8")
    width = width or 0.67
    return lib.ImPlot_PlotBarsS8PtrInt(label_id,values,count,width,shift,offset,stride)
end
function M.ImPlot_PlotBarsU8PtrInt(label_id,values,count,width,shift,offset,stride)
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImU8")
    width = width or 0.67
    return lib.ImPlot_PlotBarsU8PtrInt(label_id,values,count,width,shift,offset,stride)
end
function M.ImPlot_PlotBarsS16PtrInt(label_id,values,count,width,shift,offset,stride)
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImS16")
    width = width or 0.67
    return lib.ImPlot_PlotBarsS16PtrInt(label_id,values,count,width,shift,offset,stride)
end
function M.ImPlot_PlotBarsU16PtrInt(label_id,values,count,width,shift,offset,stride)
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImU16")
    width = width or 0.67
    return lib.ImPlot_PlotBarsU16PtrInt(label_id,values,count,width,shift,offset,stride)
end
function M.ImPlot_PlotBarsS32PtrInt(label_id,values,count,width,shift,offset,stride)
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImS32")
    width = width or 0.67
    return lib.ImPlot_PlotBarsS32PtrInt(label_id,values,count,width,shift,offset,stride)
end
function M.ImPlot_PlotBarsU32PtrInt(label_id,values,count,width,shift,offset,stride)
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImU32")
    width = width or 0.67
    return lib.ImPlot_PlotBarsU32PtrInt(label_id,values,count,width,shift,offset,stride)
end
function M.ImPlot_PlotBarsS64PtrInt(label_id,values,count,width,shift,offset,stride)
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImS64")
    width = width or 0.67
    return lib.ImPlot_PlotBarsS64PtrInt(label_id,values,count,width,shift,offset,stride)
end
function M.ImPlot_PlotBarsU64PtrInt(label_id,values,count,width,shift,offset,stride)
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImU64")
    width = width or 0.67
    return lib.ImPlot_PlotBarsU64PtrInt(label_id,values,count,width,shift,offset,stride)
end
function M.ImPlot_PlotBarsFloatPtrFloatPtr(label_id,xs,ys,count,width,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotBarsFloatPtrFloatPtr(label_id,xs,ys,count,width,offset,stride)
end
function M.ImPlot_PlotBarsdoublePtrdoublePtr(label_id,xs,ys,count,width,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotBarsdoublePtrdoublePtr(label_id,xs,ys,count,width,offset,stride)
end
function M.ImPlot_PlotBarsS8PtrS8Ptr(label_id,xs,ys,count,width,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotBarsS8PtrS8Ptr(label_id,xs,ys,count,width,offset,stride)
end
function M.ImPlot_PlotBarsU8PtrU8Ptr(label_id,xs,ys,count,width,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotBarsU8PtrU8Ptr(label_id,xs,ys,count,width,offset,stride)
end
function M.ImPlot_PlotBarsS16PtrS16Ptr(label_id,xs,ys,count,width,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotBarsS16PtrS16Ptr(label_id,xs,ys,count,width,offset,stride)
end
function M.ImPlot_PlotBarsU16PtrU16Ptr(label_id,xs,ys,count,width,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotBarsU16PtrU16Ptr(label_id,xs,ys,count,width,offset,stride)
end
function M.ImPlot_PlotBarsS32PtrS32Ptr(label_id,xs,ys,count,width,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotBarsS32PtrS32Ptr(label_id,xs,ys,count,width,offset,stride)
end
function M.ImPlot_PlotBarsU32PtrU32Ptr(label_id,xs,ys,count,width,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotBarsU32PtrU32Ptr(label_id,xs,ys,count,width,offset,stride)
end
function M.ImPlot_PlotBarsS64PtrS64Ptr(label_id,xs,ys,count,width,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotBarsS64PtrS64Ptr(label_id,xs,ys,count,width,offset,stride)
end
function M.ImPlot_PlotBarsU64PtrU64Ptr(label_id,xs,ys,count,width,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotBarsU64PtrU64Ptr(label_id,xs,ys,count,width,offset,stride)
end
function M.ImPlot_PlotBars(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsFloatPtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsdoublePtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsS8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsU8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsS16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsU16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsS32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsU32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsS64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsU64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('const float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotBarsFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('const double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotBarsdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotBarsS8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('const ImU8*',a3) or ffi.istype('const ImU8',a3) or ffi.istype('const ImU8[]',a3)) then return M.ImPlot_PlotBarsU8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('const ImS16*',a3) or ffi.istype('const ImS16',a3) or ffi.istype('const ImS16[]',a3)) then return M.ImPlot_PlotBarsS16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('const ImU16*',a3) or ffi.istype('const ImU16',a3) or ffi.istype('const ImU16[]',a3)) then return M.ImPlot_PlotBarsU16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('const ImS32*',a3) or ffi.istype('const ImS32',a3) or ffi.istype('const ImS32[]',a3)) then return M.ImPlot_PlotBarsS32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('const ImU32*',a3) or ffi.istype('const ImU32',a3) or ffi.istype('const ImU32[]',a3)) then return M.ImPlot_PlotBarsU32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('const ImS64*',a3) or ffi.istype('const ImS64',a3) or ffi.istype('const ImS64[]',a3)) then return M.ImPlot_PlotBarsS64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('const ImU64*',a3) or ffi.istype('const ImU64',a3) or ffi.istype('const ImU64[]',a3)) then return M.ImPlot_PlotBarsU64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotBars could not find overloaded'
end
function M.ImPlot_PlotBarsG(label_id,getter,data,count,width,offset)
    offset = offset or 0
    return lib.ImPlot_PlotBarsG(label_id,getter,data,count,width,offset)
end
function M.ImPlot_PlotBarsHFloatPtrInt(label_id,values,count,height,shift,offset,stride)
    height = height or 0.67
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotBarsHFloatPtrInt(label_id,values,count,height,shift,offset,stride)
end
function M.ImPlot_PlotBarsHdoublePtrInt(label_id,values,count,height,shift,offset,stride)
    height = height or 0.67
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotBarsHdoublePtrInt(label_id,values,count,height,shift,offset,stride)
end
function M.ImPlot_PlotBarsHS8PtrInt(label_id,values,count,height,shift,offset,stride)
    height = height or 0.67
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotBarsHS8PtrInt(label_id,values,count,height,shift,offset,stride)
end
function M.ImPlot_PlotBarsHU8PtrInt(label_id,values,count,height,shift,offset,stride)
    height = height or 0.67
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotBarsHU8PtrInt(label_id,values,count,height,shift,offset,stride)
end
function M.ImPlot_PlotBarsHS16PtrInt(label_id,values,count,height,shift,offset,stride)
    height = height or 0.67
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotBarsHS16PtrInt(label_id,values,count,height,shift,offset,stride)
end
function M.ImPlot_PlotBarsHU16PtrInt(label_id,values,count,height,shift,offset,stride)
    height = height or 0.67
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotBarsHU16PtrInt(label_id,values,count,height,shift,offset,stride)
end
function M.ImPlot_PlotBarsHS32PtrInt(label_id,values,count,height,shift,offset,stride)
    height = height or 0.67
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotBarsHS32PtrInt(label_id,values,count,height,shift,offset,stride)
end
function M.ImPlot_PlotBarsHU32PtrInt(label_id,values,count,height,shift,offset,stride)
    height = height or 0.67
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotBarsHU32PtrInt(label_id,values,count,height,shift,offset,stride)
end
function M.ImPlot_PlotBarsHS64PtrInt(label_id,values,count,height,shift,offset,stride)
    height = height or 0.67
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotBarsHS64PtrInt(label_id,values,count,height,shift,offset,stride)
end
function M.ImPlot_PlotBarsHU64PtrInt(label_id,values,count,height,shift,offset,stride)
    height = height or 0.67
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotBarsHU64PtrInt(label_id,values,count,height,shift,offset,stride)
end
function M.ImPlot_PlotBarsHFloatPtrFloatPtr(label_id,xs,ys,count,height,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotBarsHFloatPtrFloatPtr(label_id,xs,ys,count,height,offset,stride)
end
function M.ImPlot_PlotBarsHdoublePtrdoublePtr(label_id,xs,ys,count,height,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotBarsHdoublePtrdoublePtr(label_id,xs,ys,count,height,offset,stride)
end
function M.ImPlot_PlotBarsHS8PtrS8Ptr(label_id,xs,ys,count,height,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotBarsHS8PtrS8Ptr(label_id,xs,ys,count,height,offset,stride)
end
function M.ImPlot_PlotBarsHU8PtrU8Ptr(label_id,xs,ys,count,height,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotBarsHU8PtrU8Ptr(label_id,xs,ys,count,height,offset,stride)
end
function M.ImPlot_PlotBarsHS16PtrS16Ptr(label_id,xs,ys,count,height,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotBarsHS16PtrS16Ptr(label_id,xs,ys,count,height,offset,stride)
end
function M.ImPlot_PlotBarsHU16PtrU16Ptr(label_id,xs,ys,count,height,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotBarsHU16PtrU16Ptr(label_id,xs,ys,count,height,offset,stride)
end
function M.ImPlot_PlotBarsHS32PtrS32Ptr(label_id,xs,ys,count,height,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotBarsHS32PtrS32Ptr(label_id,xs,ys,count,height,offset,stride)
end
function M.ImPlot_PlotBarsHU32PtrU32Ptr(label_id,xs,ys,count,height,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotBarsHU32PtrU32Ptr(label_id,xs,ys,count,height,offset,stride)
end
function M.ImPlot_PlotBarsHS64PtrS64Ptr(label_id,xs,ys,count,height,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotBarsHS64PtrS64Ptr(label_id,xs,ys,count,height,offset,stride)
end
function M.ImPlot_PlotBarsHU64PtrU64Ptr(label_id,xs,ys,count,height,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotBarsHU64PtrU64Ptr(label_id,xs,ys,count,height,offset,stride)
end
function M.ImPlot_PlotBarsH(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsHFloatPtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsHdoublePtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsHS8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsHU8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsHS16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsHU16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsHS32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsHU32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsHS64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotBarsHU64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('const float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotBarsHFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('const double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotBarsHdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotBarsHS8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('const ImU8*',a3) or ffi.istype('const ImU8',a3) or ffi.istype('const ImU8[]',a3)) then return M.ImPlot_PlotBarsHU8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('const ImS16*',a3) or ffi.istype('const ImS16',a3) or ffi.istype('const ImS16[]',a3)) then return M.ImPlot_PlotBarsHS16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('const ImU16*',a3) or ffi.istype('const ImU16',a3) or ffi.istype('const ImU16[]',a3)) then return M.ImPlot_PlotBarsHU16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('const ImS32*',a3) or ffi.istype('const ImS32',a3) or ffi.istype('const ImS32[]',a3)) then return M.ImPlot_PlotBarsHS32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('const ImU32*',a3) or ffi.istype('const ImU32',a3) or ffi.istype('const ImU32[]',a3)) then return M.ImPlot_PlotBarsHU32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('const ImS64*',a3) or ffi.istype('const ImS64',a3) or ffi.istype('const ImS64[]',a3)) then return M.ImPlot_PlotBarsHS64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('const ImU64*',a3) or ffi.istype('const ImU64',a3) or ffi.istype('const ImU64[]',a3)) then return M.ImPlot_PlotBarsHU64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotBarsH could not find overloaded'
end
function M.ImPlot_PlotBarsHG(label_id,getter,data,count,height,offset)
    offset = offset or 0
    return lib.ImPlot_PlotBarsHG(label_id,getter,data,count,height,offset)
end
function M.ImPlot_PlotDigitalFloatPtr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotDigitalFloatPtr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotDigitaldoublePtr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotDigitaldoublePtr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotDigitalS8Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotDigitalS8Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotDigitalU8Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotDigitalU8Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotDigitalS16Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotDigitalS16Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotDigitalU16Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotDigitalU16Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotDigitalS32Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotDigitalS32Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotDigitalU32Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotDigitalU32Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotDigitalS64Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotDigitalS64Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotDigitalU64Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotDigitalU64Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotDigital(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotDigitalFloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotDigitaldoublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotDigitalS8Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) then return M.ImPlot_PlotDigitalU8Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) then return M.ImPlot_PlotDigitalS16Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) then return M.ImPlot_PlotDigitalU16Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) then return M.ImPlot_PlotDigitalS32Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) then return M.ImPlot_PlotDigitalU32Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) then return M.ImPlot_PlotDigitalS64Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) then return M.ImPlot_PlotDigitalU64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot_PlotDigital could not find overloaded'
end
function M.ImPlot_PlotDigitalG(label_id,getter,data,count,offset)
    offset = offset or 0
    return lib.ImPlot_PlotDigitalG(label_id,getter,data,count,offset)
end
M.ImPlot_PlotDummy = lib.ImPlot_PlotDummy
function M.ImPlot_PlotErrorBarsFloatPtrFloatPtrFloatPtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotErrorBarsFloatPtrFloatPtrFloatPtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsdoublePtrdoublePtrdoublePtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotErrorBarsdoublePtrdoublePtrdoublePtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsS8PtrS8PtrS8PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotErrorBarsS8PtrS8PtrS8PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsU8PtrU8PtrU8PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotErrorBarsU8PtrU8PtrU8PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsS16PtrS16PtrS16PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotErrorBarsS16PtrS16PtrS16PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsU16PtrU16PtrU16PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotErrorBarsU16PtrU16PtrU16PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsS32PtrS32PtrS32PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotErrorBarsS32PtrS32PtrS32PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsU32PtrU32PtrU32PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotErrorBarsU32PtrU32PtrU32PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsS64PtrS64PtrS64PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotErrorBarsS64PtrS64PtrS64PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsU64PtrU64PtrU64PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotErrorBarsU64PtrU64PtrU64PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsFloatPtrFloatPtrFloatPtrFloatPtr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotErrorBarsFloatPtrFloatPtrFloatPtrFloatPtr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsdoublePtrdoublePtrdoublePtrdoublePtr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotErrorBarsdoublePtrdoublePtrdoublePtrdoublePtr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsS8PtrS8PtrS8PtrS8Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotErrorBarsS8PtrS8PtrS8PtrS8Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsU8PtrU8PtrU8PtrU8Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotErrorBarsU8PtrU8PtrU8PtrU8Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsS16PtrS16PtrS16PtrS16Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotErrorBarsS16PtrS16PtrS16PtrS16Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsU16PtrU16PtrU16PtrU16Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotErrorBarsU16PtrU16PtrU16PtrU16Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsS32PtrS32PtrS32PtrS32Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotErrorBarsS32PtrS32PtrS32PtrS32Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsU32PtrU32PtrU32PtrU32Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotErrorBarsU32PtrU32PtrU32PtrU32Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsS64PtrS64PtrS64PtrS64Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotErrorBarsS64PtrS64PtrS64PtrS64Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsU64PtrU64PtrU64PtrU64Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotErrorBarsU64PtrU64PtrU64PtrU64Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBars(a1,a2,a3,a4,a5,a6,a7,a8) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('const float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('const float*',a4) or ffi.istype('float[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsFloatPtrFloatPtrFloatPtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('const double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('const double*',a4) or ffi.istype('double[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsdoublePtrdoublePtrdoublePtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('const ImS8*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsS8PtrS8PtrS8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('const ImU8*',a3) or ffi.istype('const ImU8',a3) or ffi.istype('const ImU8[]',a3)) and (ffi.istype('const ImU8*',a4) or ffi.istype('const ImU8',a4) or ffi.istype('const ImU8[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsU8PtrU8PtrU8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('const ImS16*',a3) or ffi.istype('const ImS16',a3) or ffi.istype('const ImS16[]',a3)) and (ffi.istype('const ImS16*',a4) or ffi.istype('const ImS16',a4) or ffi.istype('const ImS16[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsS16PtrS16PtrS16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('const ImU16*',a3) or ffi.istype('const ImU16',a3) or ffi.istype('const ImU16[]',a3)) and (ffi.istype('const ImU16*',a4) or ffi.istype('const ImU16',a4) or ffi.istype('const ImU16[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsU16PtrU16PtrU16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('const ImS32*',a3) or ffi.istype('const ImS32',a3) or ffi.istype('const ImS32[]',a3)) and (ffi.istype('const ImS32*',a4) or ffi.istype('const ImS32',a4) or ffi.istype('const ImS32[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsS32PtrS32PtrS32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('const ImU32*',a3) or ffi.istype('const ImU32',a3) or ffi.istype('const ImU32[]',a3)) and (ffi.istype('const ImU32*',a4) or ffi.istype('const ImU32',a4) or ffi.istype('const ImU32[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsU32PtrU32PtrU32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('const ImS64*',a3) or ffi.istype('const ImS64',a3) or ffi.istype('const ImS64[]',a3)) and (ffi.istype('const ImS64*',a4) or ffi.istype('const ImS64',a4) or ffi.istype('const ImS64[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsS64PtrS64PtrS64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('const ImU64*',a3) or ffi.istype('const ImU64',a3) or ffi.istype('const ImU64[]',a3)) and (ffi.istype('const ImU64*',a4) or ffi.istype('const ImU64',a4) or ffi.istype('const ImU64[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsU64PtrU64PtrU64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('const float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('const float*',a4) or ffi.istype('float[]',a4)) and (ffi.istype('const float*',a5) or ffi.istype('float[]',a5)) then return M.ImPlot_PlotErrorBarsFloatPtrFloatPtrFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('const double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('const double*',a4) or ffi.istype('double[]',a4)) and (ffi.istype('const double*',a5) or ffi.istype('double[]',a5)) then return M.ImPlot_PlotErrorBarsdoublePtrdoublePtrdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('const ImS8*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') and (ffi.istype('const ImS8*',a5) or ffi.istype('char[]',a5) or type(a5)=='string') then return M.ImPlot_PlotErrorBarsS8PtrS8PtrS8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('const ImU8*',a3) or ffi.istype('const ImU8',a3) or ffi.istype('const ImU8[]',a3)) and (ffi.istype('const ImU8*',a4) or ffi.istype('const ImU8',a4) or ffi.istype('const ImU8[]',a4)) and (ffi.istype('const ImU8*',a5) or ffi.istype('const ImU8',a5) or ffi.istype('const ImU8[]',a5)) then return M.ImPlot_PlotErrorBarsU8PtrU8PtrU8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('const ImS16*',a3) or ffi.istype('const ImS16',a3) or ffi.istype('const ImS16[]',a3)) and (ffi.istype('const ImS16*',a4) or ffi.istype('const ImS16',a4) or ffi.istype('const ImS16[]',a4)) and (ffi.istype('const ImS16*',a5) or ffi.istype('const ImS16',a5) or ffi.istype('const ImS16[]',a5)) then return M.ImPlot_PlotErrorBarsS16PtrS16PtrS16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('const ImU16*',a3) or ffi.istype('const ImU16',a3) or ffi.istype('const ImU16[]',a3)) and (ffi.istype('const ImU16*',a4) or ffi.istype('const ImU16',a4) or ffi.istype('const ImU16[]',a4)) and (ffi.istype('const ImU16*',a5) or ffi.istype('const ImU16',a5) or ffi.istype('const ImU16[]',a5)) then return M.ImPlot_PlotErrorBarsU16PtrU16PtrU16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('const ImS32*',a3) or ffi.istype('const ImS32',a3) or ffi.istype('const ImS32[]',a3)) and (ffi.istype('const ImS32*',a4) or ffi.istype('const ImS32',a4) or ffi.istype('const ImS32[]',a4)) and (ffi.istype('const ImS32*',a5) or ffi.istype('const ImS32',a5) or ffi.istype('const ImS32[]',a5)) then return M.ImPlot_PlotErrorBarsS32PtrS32PtrS32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('const ImU32*',a3) or ffi.istype('const ImU32',a3) or ffi.istype('const ImU32[]',a3)) and (ffi.istype('const ImU32*',a4) or ffi.istype('const ImU32',a4) or ffi.istype('const ImU32[]',a4)) and (ffi.istype('const ImU32*',a5) or ffi.istype('const ImU32',a5) or ffi.istype('const ImU32[]',a5)) then return M.ImPlot_PlotErrorBarsU32PtrU32PtrU32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('const ImS64*',a3) or ffi.istype('const ImS64',a3) or ffi.istype('const ImS64[]',a3)) and (ffi.istype('const ImS64*',a4) or ffi.istype('const ImS64',a4) or ffi.istype('const ImS64[]',a4)) and (ffi.istype('const ImS64*',a5) or ffi.istype('const ImS64',a5) or ffi.istype('const ImS64[]',a5)) then return M.ImPlot_PlotErrorBarsS64PtrS64PtrS64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('const ImU64*',a3) or ffi.istype('const ImU64',a3) or ffi.istype('const ImU64[]',a3)) and (ffi.istype('const ImU64*',a4) or ffi.istype('const ImU64',a4) or ffi.istype('const ImU64[]',a4)) and (ffi.istype('const ImU64*',a5) or ffi.istype('const ImU64',a5) or ffi.istype('const ImU64[]',a5)) then return M.ImPlot_PlotErrorBarsU64PtrU64PtrU64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    print(a1,a2,a3,a4,a5,a6,a7,a8)
    error'M.ImPlot_PlotErrorBars could not find overloaded'
end
function M.ImPlot_PlotErrorBarsHFloatPtrFloatPtrFloatPtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotErrorBarsHFloatPtrFloatPtrFloatPtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHdoublePtrdoublePtrdoublePtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotErrorBarsHdoublePtrdoublePtrdoublePtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHS8PtrS8PtrS8PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotErrorBarsHS8PtrS8PtrS8PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHU8PtrU8PtrU8PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotErrorBarsHU8PtrU8PtrU8PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHS16PtrS16PtrS16PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotErrorBarsHS16PtrS16PtrS16PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHU16PtrU16PtrU16PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotErrorBarsHU16PtrU16PtrU16PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHS32PtrS32PtrS32PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotErrorBarsHS32PtrS32PtrS32PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHU32PtrU32PtrU32PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotErrorBarsHU32PtrU32PtrU32PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHS64PtrS64PtrS64PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotErrorBarsHS64PtrS64PtrS64PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHU64PtrU64PtrU64PtrInt(label_id,xs,ys,err,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotErrorBarsHU64PtrU64PtrU64PtrInt(label_id,xs,ys,err,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHFloatPtrFloatPtrFloatPtrFloatPtr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotErrorBarsHFloatPtrFloatPtrFloatPtrFloatPtr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHdoublePtrdoublePtrdoublePtrdoublePtr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotErrorBarsHdoublePtrdoublePtrdoublePtrdoublePtr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHS8PtrS8PtrS8PtrS8Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotErrorBarsHS8PtrS8PtrS8PtrS8Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHU8PtrU8PtrU8PtrU8Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotErrorBarsHU8PtrU8PtrU8PtrU8Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHS16PtrS16PtrS16PtrS16Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotErrorBarsHS16PtrS16PtrS16PtrS16Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHU16PtrU16PtrU16PtrU16Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotErrorBarsHU16PtrU16PtrU16PtrU16Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHS32PtrS32PtrS32PtrS32Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotErrorBarsHS32PtrS32PtrS32PtrS32Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHU32PtrU32PtrU32PtrU32Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotErrorBarsHU32PtrU32PtrU32PtrU32Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHS64PtrS64PtrS64PtrS64Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotErrorBarsHS64PtrS64PtrS64PtrS64Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsHU64PtrU64PtrU64PtrU64Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotErrorBarsHU64PtrU64PtrU64PtrU64Ptr(label_id,xs,ys,neg,pos,count,offset,stride)
end
function M.ImPlot_PlotErrorBarsH(a1,a2,a3,a4,a5,a6,a7,a8) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('const float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('const float*',a4) or ffi.istype('float[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsHFloatPtrFloatPtrFloatPtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('const double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('const double*',a4) or ffi.istype('double[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsHdoublePtrdoublePtrdoublePtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('const ImS8*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsHS8PtrS8PtrS8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('const ImU8*',a3) or ffi.istype('const ImU8',a3) or ffi.istype('const ImU8[]',a3)) and (ffi.istype('const ImU8*',a4) or ffi.istype('const ImU8',a4) or ffi.istype('const ImU8[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsHU8PtrU8PtrU8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('const ImS16*',a3) or ffi.istype('const ImS16',a3) or ffi.istype('const ImS16[]',a3)) and (ffi.istype('const ImS16*',a4) or ffi.istype('const ImS16',a4) or ffi.istype('const ImS16[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsHS16PtrS16PtrS16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('const ImU16*',a3) or ffi.istype('const ImU16',a3) or ffi.istype('const ImU16[]',a3)) and (ffi.istype('const ImU16*',a4) or ffi.istype('const ImU16',a4) or ffi.istype('const ImU16[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsHU16PtrU16PtrU16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('const ImS32*',a3) or ffi.istype('const ImS32',a3) or ffi.istype('const ImS32[]',a3)) and (ffi.istype('const ImS32*',a4) or ffi.istype('const ImS32',a4) or ffi.istype('const ImS32[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsHS32PtrS32PtrS32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('const ImU32*',a3) or ffi.istype('const ImU32',a3) or ffi.istype('const ImU32[]',a3)) and (ffi.istype('const ImU32*',a4) or ffi.istype('const ImU32',a4) or ffi.istype('const ImU32[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsHU32PtrU32PtrU32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('const ImS64*',a3) or ffi.istype('const ImS64',a3) or ffi.istype('const ImS64[]',a3)) and (ffi.istype('const ImS64*',a4) or ffi.istype('const ImS64',a4) or ffi.istype('const ImS64[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsHS64PtrS64PtrS64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('const ImU64*',a3) or ffi.istype('const ImU64',a3) or ffi.istype('const ImU64[]',a3)) and (ffi.istype('const ImU64*',a4) or ffi.istype('const ImU64',a4) or ffi.istype('const ImU64[]',a4)) and (ffi.istype('int',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBarsHU64PtrU64PtrU64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('const float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('const float*',a4) or ffi.istype('float[]',a4)) and (ffi.istype('const float*',a5) or ffi.istype('float[]',a5)) then return M.ImPlot_PlotErrorBarsHFloatPtrFloatPtrFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('const double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('const double*',a4) or ffi.istype('double[]',a4)) and (ffi.istype('const double*',a5) or ffi.istype('double[]',a5)) then return M.ImPlot_PlotErrorBarsHdoublePtrdoublePtrdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('const ImS8*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') and (ffi.istype('const ImS8*',a5) or ffi.istype('char[]',a5) or type(a5)=='string') then return M.ImPlot_PlotErrorBarsHS8PtrS8PtrS8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('const ImU8*',a3) or ffi.istype('const ImU8',a3) or ffi.istype('const ImU8[]',a3)) and (ffi.istype('const ImU8*',a4) or ffi.istype('const ImU8',a4) or ffi.istype('const ImU8[]',a4)) and (ffi.istype('const ImU8*',a5) or ffi.istype('const ImU8',a5) or ffi.istype('const ImU8[]',a5)) then return M.ImPlot_PlotErrorBarsHU8PtrU8PtrU8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('const ImS16*',a3) or ffi.istype('const ImS16',a3) or ffi.istype('const ImS16[]',a3)) and (ffi.istype('const ImS16*',a4) or ffi.istype('const ImS16',a4) or ffi.istype('const ImS16[]',a4)) and (ffi.istype('const ImS16*',a5) or ffi.istype('const ImS16',a5) or ffi.istype('const ImS16[]',a5)) then return M.ImPlot_PlotErrorBarsHS16PtrS16PtrS16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('const ImU16*',a3) or ffi.istype('const ImU16',a3) or ffi.istype('const ImU16[]',a3)) and (ffi.istype('const ImU16*',a4) or ffi.istype('const ImU16',a4) or ffi.istype('const ImU16[]',a4)) and (ffi.istype('const ImU16*',a5) or ffi.istype('const ImU16',a5) or ffi.istype('const ImU16[]',a5)) then return M.ImPlot_PlotErrorBarsHU16PtrU16PtrU16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('const ImS32*',a3) or ffi.istype('const ImS32',a3) or ffi.istype('const ImS32[]',a3)) and (ffi.istype('const ImS32*',a4) or ffi.istype('const ImS32',a4) or ffi.istype('const ImS32[]',a4)) and (ffi.istype('const ImS32*',a5) or ffi.istype('const ImS32',a5) or ffi.istype('const ImS32[]',a5)) then return M.ImPlot_PlotErrorBarsHS32PtrS32PtrS32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('const ImU32*',a3) or ffi.istype('const ImU32',a3) or ffi.istype('const ImU32[]',a3)) and (ffi.istype('const ImU32*',a4) or ffi.istype('const ImU32',a4) or ffi.istype('const ImU32[]',a4)) and (ffi.istype('const ImU32*',a5) or ffi.istype('const ImU32',a5) or ffi.istype('const ImU32[]',a5)) then return M.ImPlot_PlotErrorBarsHU32PtrU32PtrU32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('const ImS64*',a3) or ffi.istype('const ImS64',a3) or ffi.istype('const ImS64[]',a3)) and (ffi.istype('const ImS64*',a4) or ffi.istype('const ImS64',a4) or ffi.istype('const ImS64[]',a4)) and (ffi.istype('const ImS64*',a5) or ffi.istype('const ImS64',a5) or ffi.istype('const ImS64[]',a5)) then return M.ImPlot_PlotErrorBarsHS64PtrS64PtrS64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('const ImU64*',a3) or ffi.istype('const ImU64',a3) or ffi.istype('const ImU64[]',a3)) and (ffi.istype('const ImU64*',a4) or ffi.istype('const ImU64',a4) or ffi.istype('const ImU64[]',a4)) and (ffi.istype('const ImU64*',a5) or ffi.istype('const ImU64',a5) or ffi.istype('const ImU64[]',a5)) then return M.ImPlot_PlotErrorBarsHU64PtrU64PtrU64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    print(a1,a2,a3,a4,a5,a6,a7,a8)
    error'M.ImPlot_PlotErrorBarsH could not find overloaded'
end
function M.ImPlot_PlotHeatmapFloatPtr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotHeatmapFloatPtr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
end
function M.ImPlot_PlotHeatmapdoublePtr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotHeatmapdoublePtr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
end
function M.ImPlot_PlotHeatmapS8Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotHeatmapS8Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
end
function M.ImPlot_PlotHeatmapU8Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotHeatmapU8Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
end
function M.ImPlot_PlotHeatmapS16Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotHeatmapS16Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
end
function M.ImPlot_PlotHeatmapU16Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotHeatmapU16Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
end
function M.ImPlot_PlotHeatmapS32Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotHeatmapS32Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
end
function M.ImPlot_PlotHeatmapU32Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotHeatmapU32Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
end
function M.ImPlot_PlotHeatmapS64Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotHeatmapS64Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
end
function M.ImPlot_PlotHeatmapU64Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotHeatmapU64Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max)
end
function M.ImPlot_PlotHeatmap(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotHeatmapFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotHeatmapdoublePtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotHeatmapS8Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) then return M.ImPlot_PlotHeatmapU8Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) then return M.ImPlot_PlotHeatmapS16Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) then return M.ImPlot_PlotHeatmapU16Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) then return M.ImPlot_PlotHeatmapS32Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) then return M.ImPlot_PlotHeatmapU32Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) then return M.ImPlot_PlotHeatmapS64Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) then return M.ImPlot_PlotHeatmapU64Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.ImPlot_PlotHeatmap could not find overloaded'
end
function M.ImPlot_PlotImage(label_id,user_texture_id,bounds_min,bounds_max,uv0,uv1,tint_col)
    tint_col = tint_col or ImVec4(1,1,1,1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,1)
    return lib.ImPlot_PlotImage(label_id,user_texture_id,bounds_min,bounds_max,uv0,uv1,tint_col)
end
function M.ImPlot_PlotLineFloatPtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotLineFloatPtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotLinedoublePtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotLinedoublePtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotLineS8PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotLineS8PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotLineU8PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotLineU8PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotLineS16PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotLineS16PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotLineU16PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotLineU16PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotLineS32PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotLineS32PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotLineU32PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotLineU32PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotLineS64PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotLineS64PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotLineU64PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotLineU64PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotLineFloatPtrFloatPtr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotLineFloatPtrFloatPtr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotLinedoublePtrdoublePtr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotLinedoublePtrdoublePtr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotLineS8PtrS8Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotLineS8PtrS8Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotLineU8PtrU8Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotLineU8PtrU8Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotLineS16PtrS16Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotLineS16PtrS16Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotLineU16PtrU16Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotLineU16PtrU16Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotLineS32PtrS32Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotLineS32PtrS32Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotLineU32PtrU32Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotLineU32PtrU32Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotLineS64PtrS64Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotLineS64PtrS64Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotLineU64PtrU64Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotLineU64PtrU64Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotLine(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotLineFloatPtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotLinedoublePtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotLineS8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotLineU8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotLineS16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotLineU16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotLineS32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotLineU32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotLineS64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotLineU64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('const float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotLineFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('const double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotLinedoublePtrdoublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotLineS8PtrS8Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('const ImU8*',a3) or ffi.istype('const ImU8',a3) or ffi.istype('const ImU8[]',a3)) then return M.ImPlot_PlotLineU8PtrU8Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('const ImS16*',a3) or ffi.istype('const ImS16',a3) or ffi.istype('const ImS16[]',a3)) then return M.ImPlot_PlotLineS16PtrS16Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('const ImU16*',a3) or ffi.istype('const ImU16',a3) or ffi.istype('const ImU16[]',a3)) then return M.ImPlot_PlotLineU16PtrU16Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('const ImS32*',a3) or ffi.istype('const ImS32',a3) or ffi.istype('const ImS32[]',a3)) then return M.ImPlot_PlotLineS32PtrS32Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('const ImU32*',a3) or ffi.istype('const ImU32',a3) or ffi.istype('const ImU32[]',a3)) then return M.ImPlot_PlotLineU32PtrU32Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('const ImS64*',a3) or ffi.istype('const ImS64',a3) or ffi.istype('const ImS64[]',a3)) then return M.ImPlot_PlotLineS64PtrS64Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('const ImU64*',a3) or ffi.istype('const ImU64',a3) or ffi.istype('const ImU64[]',a3)) then return M.ImPlot_PlotLineU64PtrU64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotLine could not find overloaded'
end
function M.ImPlot_PlotLineG(label_id,getter,data,count,offset)
    offset = offset or 0
    return lib.ImPlot_PlotLineG(label_id,getter,data,count,offset)
end
function M.ImPlot_PlotPieChartFloatPtr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    normalize = normalize or false
    return lib.ImPlot_PlotPieChartFloatPtr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
end
function M.ImPlot_PlotPieChartdoublePtr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    normalize = normalize or false
    return lib.ImPlot_PlotPieChartdoublePtr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
end
function M.ImPlot_PlotPieChartS8Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    normalize = normalize or false
    return lib.ImPlot_PlotPieChartS8Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
end
function M.ImPlot_PlotPieChartU8Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    normalize = normalize or false
    return lib.ImPlot_PlotPieChartU8Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
end
function M.ImPlot_PlotPieChartS16Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    normalize = normalize or false
    return lib.ImPlot_PlotPieChartS16Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
end
function M.ImPlot_PlotPieChartU16Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    normalize = normalize or false
    return lib.ImPlot_PlotPieChartU16Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
end
function M.ImPlot_PlotPieChartS32Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    normalize = normalize or false
    return lib.ImPlot_PlotPieChartS32Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
end
function M.ImPlot_PlotPieChartU32Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    normalize = normalize or false
    return lib.ImPlot_PlotPieChartU32Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
end
function M.ImPlot_PlotPieChartS64Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    normalize = normalize or false
    return lib.ImPlot_PlotPieChartS64Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
end
function M.ImPlot_PlotPieChartU64Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    normalize = normalize or false
    return lib.ImPlot_PlotPieChartU64Ptr(label_ids,values,count,x,y,radius,normalize,label_fmt,angle0)
end
function M.ImPlot_PlotPieChart(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotPieChartFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotPieChartdoublePtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotPieChartS8Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) then return M.ImPlot_PlotPieChartU8Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) then return M.ImPlot_PlotPieChartS16Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) then return M.ImPlot_PlotPieChartU16Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) then return M.ImPlot_PlotPieChartS32Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) then return M.ImPlot_PlotPieChartU32Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) then return M.ImPlot_PlotPieChartS64Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) then return M.ImPlot_PlotPieChartU64Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.ImPlot_PlotPieChart could not find overloaded'
end
function M.ImPlot_PlotScatterFloatPtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotScatterFloatPtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotScatterdoublePtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotScatterdoublePtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotScatterS8PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotScatterS8PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotScatterU8PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotScatterU8PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotScatterS16PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotScatterS16PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotScatterU16PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotScatterU16PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotScatterS32PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotScatterS32PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotScatterU32PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotScatterU32PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotScatterS64PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotScatterS64PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotScatterU64PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotScatterU64PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotScatterFloatPtrFloatPtr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotScatterFloatPtrFloatPtr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotScatterdoublePtrdoublePtr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotScatterdoublePtrdoublePtr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotScatterS8PtrS8Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotScatterS8PtrS8Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotScatterU8PtrU8Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotScatterU8PtrU8Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotScatterS16PtrS16Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotScatterS16PtrS16Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotScatterU16PtrU16Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotScatterU16PtrU16Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotScatterS32PtrS32Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotScatterS32PtrS32Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotScatterU32PtrU32Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotScatterU32PtrU32Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotScatterS64PtrS64Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotScatterS64PtrS64Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotScatterU64PtrU64Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotScatterU64PtrU64Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotScatter(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotScatterFloatPtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotScatterdoublePtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotScatterS8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotScatterU8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotScatterS16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotScatterU16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotScatterS32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotScatterU32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotScatterS64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotScatterU64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('const float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotScatterFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('const double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotScatterdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotScatterS8PtrS8Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('const ImU8*',a3) or ffi.istype('const ImU8',a3) or ffi.istype('const ImU8[]',a3)) then return M.ImPlot_PlotScatterU8PtrU8Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('const ImS16*',a3) or ffi.istype('const ImS16',a3) or ffi.istype('const ImS16[]',a3)) then return M.ImPlot_PlotScatterS16PtrS16Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('const ImU16*',a3) or ffi.istype('const ImU16',a3) or ffi.istype('const ImU16[]',a3)) then return M.ImPlot_PlotScatterU16PtrU16Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('const ImS32*',a3) or ffi.istype('const ImS32',a3) or ffi.istype('const ImS32[]',a3)) then return M.ImPlot_PlotScatterS32PtrS32Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('const ImU32*',a3) or ffi.istype('const ImU32',a3) or ffi.istype('const ImU32[]',a3)) then return M.ImPlot_PlotScatterU32PtrU32Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('const ImS64*',a3) or ffi.istype('const ImS64',a3) or ffi.istype('const ImS64[]',a3)) then return M.ImPlot_PlotScatterS64PtrS64Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('const ImU64*',a3) or ffi.istype('const ImU64',a3) or ffi.istype('const ImU64[]',a3)) then return M.ImPlot_PlotScatterU64PtrU64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotScatter could not find overloaded'
end
function M.ImPlot_PlotScatterG(label_id,getter,data,count,offset)
    offset = offset or 0
    return lib.ImPlot_PlotScatterG(label_id,getter,data,count,offset)
end
function M.ImPlot_PlotShadedFloatPtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedFloatPtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotShadeddoublePtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadeddoublePtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotShadedS8PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedS8PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotShadedU8PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedU8PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotShadedS16PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedS16PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotShadedU16PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedU16PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotShadedS32PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedS32PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotShadedU32PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedU32PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotShadedS64PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedS64PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotShadedU64PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedU64PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotShadedFloatPtrFloatPtrInt(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedFloatPtrFloatPtrInt(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotShadeddoublePtrdoublePtrInt(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadeddoublePtrdoublePtrInt(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotShadedS8PtrS8PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedS8PtrS8PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotShadedU8PtrU8PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedU8PtrU8PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotShadedS16PtrS16PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedS16PtrS16PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotShadedU16PtrU16PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedU16PtrU16PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotShadedS32PtrS32PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedS32PtrS32PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotShadedU32PtrU32PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedU32PtrU32PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotShadedS64PtrS64PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedS64PtrS64PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotShadedU64PtrU64PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotShadedU64PtrU64PtrInt(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotShadedFloatPtrFloatPtrFloatPtr(label_id,xs,ys1,ys2,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotShadedFloatPtrFloatPtrFloatPtr(label_id,xs,ys1,ys2,count,offset,stride)
end
function M.ImPlot_PlotShadeddoublePtrdoublePtrdoublePtr(label_id,xs,ys1,ys2,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotShadeddoublePtrdoublePtrdoublePtr(label_id,xs,ys1,ys2,count,offset,stride)
end
function M.ImPlot_PlotShadedS8PtrS8PtrS8Ptr(label_id,xs,ys1,ys2,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotShadedS8PtrS8PtrS8Ptr(label_id,xs,ys1,ys2,count,offset,stride)
end
function M.ImPlot_PlotShadedU8PtrU8PtrU8Ptr(label_id,xs,ys1,ys2,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotShadedU8PtrU8PtrU8Ptr(label_id,xs,ys1,ys2,count,offset,stride)
end
function M.ImPlot_PlotShadedS16PtrS16PtrS16Ptr(label_id,xs,ys1,ys2,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotShadedS16PtrS16PtrS16Ptr(label_id,xs,ys1,ys2,count,offset,stride)
end
function M.ImPlot_PlotShadedU16PtrU16PtrU16Ptr(label_id,xs,ys1,ys2,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotShadedU16PtrU16PtrU16Ptr(label_id,xs,ys1,ys2,count,offset,stride)
end
function M.ImPlot_PlotShadedS32PtrS32PtrS32Ptr(label_id,xs,ys1,ys2,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotShadedS32PtrS32PtrS32Ptr(label_id,xs,ys1,ys2,count,offset,stride)
end
function M.ImPlot_PlotShadedU32PtrU32PtrU32Ptr(label_id,xs,ys1,ys2,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotShadedU32PtrU32PtrU32Ptr(label_id,xs,ys1,ys2,count,offset,stride)
end
function M.ImPlot_PlotShadedS64PtrS64PtrS64Ptr(label_id,xs,ys1,ys2,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotShadedS64PtrS64PtrS64Ptr(label_id,xs,ys1,ys2,count,offset,stride)
end
function M.ImPlot_PlotShadedU64PtrU64PtrU64Ptr(label_id,xs,ys1,ys2,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotShadedU64PtrU64PtrU64Ptr(label_id,xs,ys1,ys2,count,offset,stride)
end
function M.ImPlot_PlotShaded(a1,a2,a3,a4,a5,a6,a7,a8) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int',a8) or type(a8)=='number') or type(a8)=='nil') then return M.ImPlot_PlotShadedFloatPtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int',a8) or type(a8)=='number') or type(a8)=='nil') then return M.ImPlot_PlotShadeddoublePtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int',a8) or type(a8)=='number') or type(a8)=='nil') then return M.ImPlot_PlotShadedS8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int',a8) or type(a8)=='number') or type(a8)=='nil') then return M.ImPlot_PlotShadedU8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int',a8) or type(a8)=='number') or type(a8)=='nil') then return M.ImPlot_PlotShadedS16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int',a8) or type(a8)=='number') or type(a8)=='nil') then return M.ImPlot_PlotShadedU16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int',a8) or type(a8)=='number') or type(a8)=='nil') then return M.ImPlot_PlotShadedS32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int',a8) or type(a8)=='number') or type(a8)=='nil') then return M.ImPlot_PlotShadedU32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int',a8) or type(a8)=='number') or type(a8)=='nil') then return M.ImPlot_PlotShadedS64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int',a8) or type(a8)=='number') or type(a8)=='nil') then return M.ImPlot_PlotShadedU64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('const float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('int',a4) or type(a4)=='number') and ((ffi.istype('int',a6) or type(a6)=='number') or type(a6)=='nil') and a8==nil then return M.ImPlot_PlotShadedFloatPtrFloatPtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('const double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('int',a4) or type(a4)=='number') and ((ffi.istype('int',a6) or type(a6)=='number') or type(a6)=='nil') and a8==nil then return M.ImPlot_PlotShadeddoublePtrdoublePtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('int',a4) or type(a4)=='number') and ((ffi.istype('int',a6) or type(a6)=='number') or type(a6)=='nil') and a8==nil then return M.ImPlot_PlotShadedS8PtrS8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('const ImU8*',a3) or ffi.istype('const ImU8',a3) or ffi.istype('const ImU8[]',a3)) and (ffi.istype('int',a4) or type(a4)=='number') and ((ffi.istype('int',a6) or type(a6)=='number') or type(a6)=='nil') and a8==nil then return M.ImPlot_PlotShadedU8PtrU8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('const ImS16*',a3) or ffi.istype('const ImS16',a3) or ffi.istype('const ImS16[]',a3)) and (ffi.istype('int',a4) or type(a4)=='number') and ((ffi.istype('int',a6) or type(a6)=='number') or type(a6)=='nil') and a8==nil then return M.ImPlot_PlotShadedS16PtrS16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('const ImU16*',a3) or ffi.istype('const ImU16',a3) or ffi.istype('const ImU16[]',a3)) and (ffi.istype('int',a4) or type(a4)=='number') and ((ffi.istype('int',a6) or type(a6)=='number') or type(a6)=='nil') and a8==nil then return M.ImPlot_PlotShadedU16PtrU16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('const ImS32*',a3) or ffi.istype('const ImS32',a3) or ffi.istype('const ImS32[]',a3)) and (ffi.istype('int',a4) or type(a4)=='number') and ((ffi.istype('int',a6) or type(a6)=='number') or type(a6)=='nil') and a8==nil then return M.ImPlot_PlotShadedS32PtrS32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('const ImU32*',a3) or ffi.istype('const ImU32',a3) or ffi.istype('const ImU32[]',a3)) and (ffi.istype('int',a4) or type(a4)=='number') and ((ffi.istype('int',a6) or type(a6)=='number') or type(a6)=='nil') and a8==nil then return M.ImPlot_PlotShadedU32PtrU32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('const ImS64*',a3) or ffi.istype('const ImS64',a3) or ffi.istype('const ImS64[]',a3)) and (ffi.istype('int',a4) or type(a4)=='number') and ((ffi.istype('int',a6) or type(a6)=='number') or type(a6)=='nil') and a8==nil then return M.ImPlot_PlotShadedS64PtrS64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('const ImU64*',a3) or ffi.istype('const ImU64',a3) or ffi.istype('const ImU64[]',a3)) and (ffi.istype('int',a4) or type(a4)=='number') and ((ffi.istype('int',a6) or type(a6)=='number') or type(a6)=='nil') and a8==nil then return M.ImPlot_PlotShadedU64PtrU64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('const float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('const float*',a4) or ffi.istype('float[]',a4)) then return M.ImPlot_PlotShadedFloatPtrFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('const double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('const double*',a4) or ffi.istype('double[]',a4)) then return M.ImPlot_PlotShadeddoublePtrdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('const ImS8*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') then return M.ImPlot_PlotShadedS8PtrS8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('const ImU8*',a3) or ffi.istype('const ImU8',a3) or ffi.istype('const ImU8[]',a3)) and (ffi.istype('const ImU8*',a4) or ffi.istype('const ImU8',a4) or ffi.istype('const ImU8[]',a4)) then return M.ImPlot_PlotShadedU8PtrU8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('const ImS16*',a3) or ffi.istype('const ImS16',a3) or ffi.istype('const ImS16[]',a3)) and (ffi.istype('const ImS16*',a4) or ffi.istype('const ImS16',a4) or ffi.istype('const ImS16[]',a4)) then return M.ImPlot_PlotShadedS16PtrS16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('const ImU16*',a3) or ffi.istype('const ImU16',a3) or ffi.istype('const ImU16[]',a3)) and (ffi.istype('const ImU16*',a4) or ffi.istype('const ImU16',a4) or ffi.istype('const ImU16[]',a4)) then return M.ImPlot_PlotShadedU16PtrU16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('const ImS32*',a3) or ffi.istype('const ImS32',a3) or ffi.istype('const ImS32[]',a3)) and (ffi.istype('const ImS32*',a4) or ffi.istype('const ImS32',a4) or ffi.istype('const ImS32[]',a4)) then return M.ImPlot_PlotShadedS32PtrS32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('const ImU32*',a3) or ffi.istype('const ImU32',a3) or ffi.istype('const ImU32[]',a3)) and (ffi.istype('const ImU32*',a4) or ffi.istype('const ImU32',a4) or ffi.istype('const ImU32[]',a4)) then return M.ImPlot_PlotShadedU32PtrU32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('const ImS64*',a3) or ffi.istype('const ImS64',a3) or ffi.istype('const ImS64[]',a3)) and (ffi.istype('const ImS64*',a4) or ffi.istype('const ImS64',a4) or ffi.istype('const ImS64[]',a4)) then return M.ImPlot_PlotShadedS64PtrS64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('const ImU64*',a3) or ffi.istype('const ImU64',a3) or ffi.istype('const ImU64[]',a3)) and (ffi.istype('const ImU64*',a4) or ffi.istype('const ImU64',a4) or ffi.istype('const ImU64[]',a4)) then return M.ImPlot_PlotShadedU64PtrU64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7,a8)
    error'M.ImPlot_PlotShaded could not find overloaded'
end
function M.ImPlot_PlotShadedG(label_id,getter1,data1,getter2,data2,count,offset)
    offset = offset or 0
    return lib.ImPlot_PlotShadedG(label_id,getter1,data1,getter2,data2,count,offset)
end
function M.ImPlot_PlotStairsFloatPtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotStairsFloatPtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStairsdoublePtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotStairsdoublePtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStairsS8PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotStairsS8PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStairsU8PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotStairsU8PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStairsS16PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotStairsS16PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStairsU16PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotStairsU16PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStairsS32PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotStairsS32PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStairsU32PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotStairsU32PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStairsS64PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotStairsS64PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStairsU64PtrInt(label_id,values,count,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    x0 = x0 or 0
    xscale = xscale or 1
    return lib.ImPlot_PlotStairsU64PtrInt(label_id,values,count,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStairsFloatPtrFloatPtr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotStairsFloatPtrFloatPtr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotStairsdoublePtrdoublePtr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotStairsdoublePtrdoublePtr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotStairsS8PtrS8Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotStairsS8PtrS8Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotStairsU8PtrU8Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotStairsU8PtrU8Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotStairsS16PtrS16Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotStairsS16PtrS16Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotStairsU16PtrU16Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotStairsU16PtrU16Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotStairsS32PtrS32Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotStairsS32PtrS32Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotStairsU32PtrU32Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotStairsU32PtrU32Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotStairsS64PtrS64Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotStairsS64PtrS64Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotStairsU64PtrU64Ptr(label_id,xs,ys,count,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotStairsU64PtrU64Ptr(label_id,xs,ys,count,offset,stride)
end
function M.ImPlot_PlotStairs(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStairsFloatPtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStairsdoublePtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStairsS8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStairsU8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStairsS16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStairsU16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStairsS32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStairsU32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStairsS64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStairsU64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('const float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotStairsFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('const double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotStairsdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotStairsS8PtrS8Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('const ImU8*',a3) or ffi.istype('const ImU8',a3) or ffi.istype('const ImU8[]',a3)) then return M.ImPlot_PlotStairsU8PtrU8Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('const ImS16*',a3) or ffi.istype('const ImS16',a3) or ffi.istype('const ImS16[]',a3)) then return M.ImPlot_PlotStairsS16PtrS16Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('const ImU16*',a3) or ffi.istype('const ImU16',a3) or ffi.istype('const ImU16[]',a3)) then return M.ImPlot_PlotStairsU16PtrU16Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('const ImS32*',a3) or ffi.istype('const ImS32',a3) or ffi.istype('const ImS32[]',a3)) then return M.ImPlot_PlotStairsS32PtrS32Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('const ImU32*',a3) or ffi.istype('const ImU32',a3) or ffi.istype('const ImU32[]',a3)) then return M.ImPlot_PlotStairsU32PtrU32Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('const ImS64*',a3) or ffi.istype('const ImS64',a3) or ffi.istype('const ImS64[]',a3)) then return M.ImPlot_PlotStairsS64PtrS64Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('const ImU64*',a3) or ffi.istype('const ImU64',a3) or ffi.istype('const ImU64[]',a3)) then return M.ImPlot_PlotStairsU64PtrU64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotStairs could not find overloaded'
end
function M.ImPlot_PlotStairsG(label_id,getter,data,count,offset)
    offset = offset or 0
    return lib.ImPlot_PlotStairsG(label_id,getter,data,count,offset)
end
function M.ImPlot_PlotStemsFloatPtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsFloatPtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStemsdoublePtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsdoublePtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStemsS8PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsS8PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStemsU8PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsU8PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStemsS16PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsS16PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStemsU16PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsU16PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStemsS32PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsS32PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStemsU32PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsU32PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStemsS64PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsS64PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStemsU64PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    x0 = x0 or 0
    xscale = xscale or 1
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsU64PtrInt(label_id,values,count,y_ref,xscale,x0,offset,stride)
end
function M.ImPlot_PlotStemsFloatPtrFloatPtr(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsFloatPtrFloatPtr(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotStemsdoublePtrdoublePtr(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsdoublePtrdoublePtr(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotStemsS8PtrS8Ptr(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsS8PtrS8Ptr(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotStemsU8PtrU8Ptr(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsU8PtrU8Ptr(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotStemsS16PtrS16Ptr(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsS16PtrS16Ptr(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotStemsU16PtrU16Ptr(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsU16PtrU16Ptr(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotStemsS32PtrS32Ptr(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsS32PtrS32Ptr(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotStemsU32PtrU32Ptr(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsU32PtrU32Ptr(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotStemsS64PtrS64Ptr(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsS64PtrS64Ptr(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotStemsU64PtrU64Ptr(label_id,xs,ys,count,y_ref,offset,stride)
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    y_ref = y_ref or 0
    return lib.ImPlot_PlotStemsU64PtrU64Ptr(label_id,xs,ys,count,y_ref,offset,stride)
end
function M.ImPlot_PlotStems(a1,a2,a3,a4,a5,a6,a7,a8) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStemsFloatPtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStemsdoublePtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStemsS8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStemsU8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStemsS16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStemsU16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStemsS32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStemsU32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStemsS64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('int',a3) or type(a3)=='number') then return M.ImPlot_PlotStemsU64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('const float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotStemsFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('const double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotStemsdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotStemsS8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU8*',a2) or ffi.istype('const ImU8',a2) or ffi.istype('const ImU8[]',a2)) and (ffi.istype('const ImU8*',a3) or ffi.istype('const ImU8',a3) or ffi.istype('const ImU8[]',a3)) then return M.ImPlot_PlotStemsU8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS16*',a2) or ffi.istype('const ImS16',a2) or ffi.istype('const ImS16[]',a2)) and (ffi.istype('const ImS16*',a3) or ffi.istype('const ImS16',a3) or ffi.istype('const ImS16[]',a3)) then return M.ImPlot_PlotStemsS16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU16*',a2) or ffi.istype('const ImU16',a2) or ffi.istype('const ImU16[]',a2)) and (ffi.istype('const ImU16*',a3) or ffi.istype('const ImU16',a3) or ffi.istype('const ImU16[]',a3)) then return M.ImPlot_PlotStemsU16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS32*',a2) or ffi.istype('const ImS32',a2) or ffi.istype('const ImS32[]',a2)) and (ffi.istype('const ImS32*',a3) or ffi.istype('const ImS32',a3) or ffi.istype('const ImS32[]',a3)) then return M.ImPlot_PlotStemsS32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU32*',a2) or ffi.istype('const ImU32',a2) or ffi.istype('const ImU32[]',a2)) and (ffi.istype('const ImU32*',a3) or ffi.istype('const ImU32',a3) or ffi.istype('const ImU32[]',a3)) then return M.ImPlot_PlotStemsU32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS64*',a2) or ffi.istype('const ImS64',a2) or ffi.istype('const ImS64[]',a2)) and (ffi.istype('const ImS64*',a3) or ffi.istype('const ImS64',a3) or ffi.istype('const ImS64[]',a3)) then return M.ImPlot_PlotStemsS64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImU64*',a2) or ffi.istype('const ImU64',a2) or ffi.istype('const ImU64[]',a2)) and (ffi.istype('const ImU64*',a3) or ffi.istype('const ImU64',a3) or ffi.istype('const ImU64[]',a3)) then return M.ImPlot_PlotStemsU64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7,a8)
    error'M.ImPlot_PlotStems could not find overloaded'
end
function M.ImPlot_PlotText(text,x,y,vertical,pix_offset)
    pix_offset = pix_offset or ImVec2(0,0)
    vertical = vertical or false
    return lib.ImPlot_PlotText(text,x,y,vertical,pix_offset)
end
function M.ImPlot_PlotToPixelsPlotPoInt(plt,y_axis)
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_PlotToPixelsPlotPoInt(nonUDT_out,plt,y_axis)
    return nonUDT_out
end
function M.ImPlot_PlotToPixelsdouble(x,y,y_axis)
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_PlotToPixelsdouble(nonUDT_out,x,y,y_axis)
    return nonUDT_out
end
function M.ImPlot_PlotToPixels(a2,a3,a4) -- generic version
    if ffi.istype('const ImPlotPoint',a2) then return M.ImPlot_PlotToPixelsPlotPoInt(a2,a3) end
    if (ffi.istype('double',a2) or type(a2)=='number') then return M.ImPlot_PlotToPixelsdouble(a2,a3,a4) end
    print(a2,a3,a4)
    error'M.ImPlot_PlotToPixels could not find overloaded'
end
function M.ImPlot_PopColormap(count)
    count = count or 1
    return lib.ImPlot_PopColormap(count)
end
M.ImPlot_PopPlotClipRect = lib.ImPlot_PopPlotClipRect
function M.ImPlot_PopStyleColor(count)
    count = count or 1
    return lib.ImPlot_PopStyleColor(count)
end
function M.ImPlot_PopStyleVar(count)
    count = count or 1
    return lib.ImPlot_PopStyleVar(count)
end
M.ImPlot_PushColormapPlotColormap = lib.ImPlot_PushColormapPlotColormap
M.ImPlot_PushColormapVec4Ptr = lib.ImPlot_PushColormapVec4Ptr
function M.ImPlot_PushColormap(a1,a2) -- generic version
    if (ffi.istype('ImPlotColormap',a1) or type(a1)=='number') then return M.ImPlot_PushColormapPlotColormap(a1) end
    if (ffi.istype('const ImVec4*',a1) or ffi.istype('const ImVec4',a1) or ffi.istype('const ImVec4[]',a1)) then return M.ImPlot_PushColormapVec4Ptr(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_PushColormap could not find overloaded'
end
M.ImPlot_PushPlotClipRect = lib.ImPlot_PushPlotClipRect
M.ImPlot_PushStyleColorU32 = lib.ImPlot_PushStyleColorU32
M.ImPlot_PushStyleColorVec4 = lib.ImPlot_PushStyleColorVec4
function M.ImPlot_PushStyleColor(a1,a2) -- generic version
    if (ffi.istype('ImU32',a2) or type(a2)=='number') then return M.ImPlot_PushStyleColorU32(a1,a2) end
    if ffi.istype('const ImVec4',a2) then return M.ImPlot_PushStyleColorVec4(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_PushStyleColor could not find overloaded'
end
M.ImPlot_PushStyleVarFloat = lib.ImPlot_PushStyleVarFloat
M.ImPlot_PushStyleVarInt = lib.ImPlot_PushStyleVarInt
M.ImPlot_PushStyleVarVec2 = lib.ImPlot_PushStyleVarVec2
function M.ImPlot_PushStyleVar(a1,a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.ImPlot_PushStyleVarFloat(a1,a2) end
    if (ffi.istype('int',a2) or type(a2)=='number') then return M.ImPlot_PushStyleVarInt(a1,a2) end
    if ffi.istype('const ImVec2',a2) then return M.ImPlot_PushStyleVarVec2(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_PushStyleVar could not find overloaded'
end
M.ImPlot_SetColormapVec4Ptr = lib.ImPlot_SetColormapVec4Ptr
function M.ImPlot_SetColormapPlotColormap(colormap,samples)
    samples = samples or 0
    return lib.ImPlot_SetColormapPlotColormap(colormap,samples)
end
function M.ImPlot_SetColormap(a1,a2) -- generic version
    if (ffi.istype('const ImVec4*',a1) or ffi.istype('const ImVec4',a1) or ffi.istype('const ImVec4[]',a1)) then return M.ImPlot_SetColormapVec4Ptr(a1,a2) end
    if (ffi.istype('ImPlotColormap',a1) or type(a1)=='number') then return M.ImPlot_SetColormapPlotColormap(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_SetColormap could not find overloaded'
end
M.ImPlot_SetCurrentContext = lib.ImPlot_SetCurrentContext
M.ImPlot_SetImGuiContext = lib.ImPlot_SetImGuiContext
function M.ImPlot_SetLegendLocation(location,orientation,outside)
    orientation = orientation or 1
    outside = outside or false
    return lib.ImPlot_SetLegendLocation(location,orientation,outside)
end
M.ImPlot_SetMousePosLocation = lib.ImPlot_SetMousePosLocation
function M.ImPlot_SetNextErrorBarStyle(col,size,weight)
    col = col or ImVec4(0,0,0,-1)
    size = size or -1
    weight = weight or -1
    return lib.ImPlot_SetNextErrorBarStyle(col,size,weight)
end
function M.ImPlot_SetNextFillStyle(col,alpha_mod)
    alpha_mod = alpha_mod or -1
    col = col or ImVec4(0,0,0,-1)
    return lib.ImPlot_SetNextFillStyle(col,alpha_mod)
end
function M.ImPlot_SetNextLineStyle(col,weight)
    col = col or ImVec4(0,0,0,-1)
    weight = weight or -1
    return lib.ImPlot_SetNextLineStyle(col,weight)
end
function M.ImPlot_SetNextMarkerStyle(marker,size,fill,weight,outline)
    fill = fill or ImVec4(0,0,0,-1)
    marker = marker or -1
    outline = outline or ImVec4(0,0,0,-1)
    size = size or -1
    weight = weight or -1
    return lib.ImPlot_SetNextMarkerStyle(marker,size,fill,weight,outline)
end
function M.ImPlot_SetNextPlotLimits(xmin,xmax,ymin,ymax,cond)
    cond = cond or 2
    return lib.ImPlot_SetNextPlotLimits(xmin,xmax,ymin,ymax,cond)
end
function M.ImPlot_SetNextPlotLimitsX(xmin,xmax,cond)
    cond = cond or 2
    return lib.ImPlot_SetNextPlotLimitsX(xmin,xmax,cond)
end
function M.ImPlot_SetNextPlotLimitsY(ymin,ymax,cond,y_axis)
    cond = cond or 2
    y_axis = y_axis or 0
    return lib.ImPlot_SetNextPlotLimitsY(ymin,ymax,cond,y_axis)
end
function M.ImPlot_SetNextPlotTicksXdoublePtr(values,n_ticks,labels,show_default)
    labels = labels or nil
    show_default = show_default or false
    return lib.ImPlot_SetNextPlotTicksXdoublePtr(values,n_ticks,labels,show_default)
end
function M.ImPlot_SetNextPlotTicksXdouble(x_min,x_max,n_ticks,labels,show_default)
    labels = labels or nil
    show_default = show_default or false
    return lib.ImPlot_SetNextPlotTicksXdouble(x_min,x_max,n_ticks,labels,show_default)
end
function M.ImPlot_SetNextPlotTicksX(a1,a2,a3,a4,a5) -- generic version
    if (ffi.istype('const double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_SetNextPlotTicksXdoublePtr(a1,a2,a3,a4) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_SetNextPlotTicksXdouble(a1,a2,a3,a4,a5) end
    print(a1,a2,a3,a4,a5)
    error'M.ImPlot_SetNextPlotTicksX could not find overloaded'
end
function M.ImPlot_SetNextPlotTicksYdoublePtr(values,n_ticks,labels,show_default,y_axis)
    labels = labels or nil
    show_default = show_default or false
    y_axis = y_axis or 0
    return lib.ImPlot_SetNextPlotTicksYdoublePtr(values,n_ticks,labels,show_default,y_axis)
end
function M.ImPlot_SetNextPlotTicksYdouble(y_min,y_max,n_ticks,labels,show_default,y_axis)
    labels = labels or nil
    show_default = show_default or false
    y_axis = y_axis or 0
    return lib.ImPlot_SetNextPlotTicksYdouble(y_min,y_max,n_ticks,labels,show_default,y_axis)
end
function M.ImPlot_SetNextPlotTicksY(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('const double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_SetNextPlotTicksYdoublePtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_SetNextPlotTicksYdouble(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot_SetNextPlotTicksY could not find overloaded'
end
M.ImPlot_SetPlotYAxis = lib.ImPlot_SetPlotYAxis
M.ImPlot_ShowColormapScale = lib.ImPlot_ShowColormapScale
M.ImPlot_ShowColormapSelector = lib.ImPlot_ShowColormapSelector
function M.ImPlot_ShowDemoWindow(p_open)
    p_open = p_open or nil
    return lib.ImPlot_ShowDemoWindow(p_open)
end
function M.ImPlot_ShowMetricsWindow(p_popen)
    p_popen = p_popen or nil
    return lib.ImPlot_ShowMetricsWindow(p_popen)
end
function M.ImPlot_ShowStyleEditor(ref)
    ref = ref or nil
    return lib.ImPlot_ShowStyleEditor(ref)
end
M.ImPlot_ShowStyleSelector = lib.ImPlot_ShowStyleSelector
M.ImPlot_ShowUserGuide = lib.ImPlot_ShowUserGuide
function M.ImPlot_StyleColorsAuto(dst)
    dst = dst or nil
    return lib.ImPlot_StyleColorsAuto(dst)
end
function M.ImPlot_StyleColorsClassic(dst)
    dst = dst or nil
    return lib.ImPlot_StyleColorsClassic(dst)
end
function M.ImPlot_StyleColorsDark(dst)
    dst = dst or nil
    return lib.ImPlot_StyleColorsDark(dst)
end
function M.ImPlot_StyleColorsLight(dst)
    dst = dst or nil
    return lib.ImPlot_StyleColorsLight(dst)
end
function M.AcceptDragDropPayload(type,flags)
    flags = flags or 0
    return lib.igAcceptDragDropPayload(type,flags)
end
M.ActivateItem = lib.igActivateItem
M.AddContextHook = lib.igAddContextHook
M.AlignTextToFramePadding = lib.igAlignTextToFramePadding
M.ArrowButton = lib.igArrowButton
function M.ArrowButtonEx(str_id,dir,size_arg,flags)
    flags = flags or 0
    return lib.igArrowButtonEx(str_id,dir,size_arg,flags)
end
function M.Begin(name,p_open,flags)
    flags = flags or 0
    p_open = p_open or nil
    return lib.igBegin(name,p_open,flags)
end
function M.BeginChildStr(str_id,size,border,flags)
    border = border or false
    flags = flags or 0
    size = size or ImVec2(0,0)
    return lib.igBeginChildStr(str_id,size,border,flags)
end
function M.BeginChildID(id,size,border,flags)
    border = border or false
    flags = flags or 0
    size = size or ImVec2(0,0)
    return lib.igBeginChildID(id,size,border,flags)
end
function M.BeginChild(a1,a2,a3,a4) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.BeginChildStr(a1,a2,a3,a4) end
    if ffi.istype('ImGuiID',a1) then return M.BeginChildID(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.BeginChild could not find overloaded'
end
M.BeginChildEx = lib.igBeginChildEx
function M.BeginChildFrame(id,size,flags)
    flags = flags or 0
    return lib.igBeginChildFrame(id,size,flags)
end
function M.BeginColumns(str_id,count,flags)
    flags = flags or 0
    return lib.igBeginColumns(str_id,count,flags)
end
function M.BeginCombo(label,preview_value,flags)
    flags = flags or 0
    return lib.igBeginCombo(label,preview_value,flags)
end
M.BeginDockableDragDropSource = lib.igBeginDockableDragDropSource
M.BeginDockableDragDropTarget = lib.igBeginDockableDragDropTarget
M.BeginDocked = lib.igBeginDocked
function M.BeginDragDropSource(flags)
    flags = flags or 0
    return lib.igBeginDragDropSource(flags)
end
M.BeginDragDropTarget = lib.igBeginDragDropTarget
M.BeginDragDropTargetCustom = lib.igBeginDragDropTargetCustom
M.BeginGroup = lib.igBeginGroup
function M.BeginListBox(label,size)
    size = size or ImVec2(0,0)
    return lib.igBeginListBox(label,size)
end
M.BeginMainMenuBar = lib.igBeginMainMenuBar
function M.BeginMenu(label,enabled)
    if enabled == nil then enabled = true end
    return lib.igBeginMenu(label,enabled)
end
M.BeginMenuBar = lib.igBeginMenuBar
function M.BeginPopup(str_id,flags)
    flags = flags or 0
    return lib.igBeginPopup(str_id,flags)
end
function M.BeginPopupContextItem(str_id,popup_flags)
    popup_flags = popup_flags or 1
    str_id = str_id or nil
    return lib.igBeginPopupContextItem(str_id,popup_flags)
end
function M.BeginPopupContextVoid(str_id,popup_flags)
    popup_flags = popup_flags or 1
    str_id = str_id or nil
    return lib.igBeginPopupContextVoid(str_id,popup_flags)
end
function M.BeginPopupContextWindow(str_id,popup_flags)
    popup_flags = popup_flags or 1
    str_id = str_id or nil
    return lib.igBeginPopupContextWindow(str_id,popup_flags)
end
M.BeginPopupEx = lib.igBeginPopupEx
function M.BeginPopupModal(name,p_open,flags)
    flags = flags or 0
    p_open = p_open or nil
    return lib.igBeginPopupModal(name,p_open,flags)
end
function M.BeginTabBar(str_id,flags)
    flags = flags or 0
    return lib.igBeginTabBar(str_id,flags)
end
M.BeginTabBarEx = lib.igBeginTabBarEx
function M.BeginTabItem(label,p_open,flags)
    flags = flags or 0
    p_open = p_open or nil
    return lib.igBeginTabItem(label,p_open,flags)
end
function M.BeginTable(str_id,column,flags,outer_size,inner_width)
    flags = flags or 0
    inner_width = inner_width or 0.0
    outer_size = outer_size or ImVec2(0.0,0.0)
    return lib.igBeginTable(str_id,column,flags,outer_size,inner_width)
end
function M.BeginTableEx(name,id,columns_count,flags,outer_size,inner_width)
    flags = flags or 0
    inner_width = inner_width or 0.0
    outer_size = outer_size or ImVec2(0,0)
    return lib.igBeginTableEx(name,id,columns_count,flags,outer_size,inner_width)
end
M.BeginTooltip = lib.igBeginTooltip
M.BeginTooltipEx = lib.igBeginTooltipEx
M.BringWindowToDisplayBack = lib.igBringWindowToDisplayBack
M.BringWindowToDisplayFront = lib.igBringWindowToDisplayFront
M.BringWindowToFocusFront = lib.igBringWindowToFocusFront
M.Bullet = lib.igBullet
M.BulletText = lib.igBulletText
M.BulletTextV = lib.igBulletTextV
function M.Button(label,size)
    size = size or ImVec2(0,0)
    return lib.igButton(label,size)
end
function M.ButtonBehavior(bb,id,out_hovered,out_held,flags)
    flags = flags or 0
    return lib.igButtonBehavior(bb,id,out_hovered,out_held,flags)
end
function M.ButtonEx(label,size_arg,flags)
    flags = flags or 0
    size_arg = size_arg or ImVec2(0,0)
    return lib.igButtonEx(label,size_arg,flags)
end
function M.CalcItemSize(size,default_w,default_h)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igCalcItemSize(nonUDT_out,size,default_w,default_h)
    return nonUDT_out
end
M.CalcItemWidth = lib.igCalcItemWidth
M.CalcListClipping = lib.igCalcListClipping
function M.CalcTextSize(text,text_end,hide_text_after_double_hash,wrap_width)
    hide_text_after_double_hash = hide_text_after_double_hash or false
    text_end = text_end or nil
    wrap_width = wrap_width or -1.0
    local nonUDT_out = ffi.new("ImVec2")
    lib.igCalcTextSize(nonUDT_out,text,text_end,hide_text_after_double_hash,wrap_width)
    return nonUDT_out
end
M.CalcTypematicRepeatAmount = lib.igCalcTypematicRepeatAmount
function M.CalcWindowNextAutoFitSize(window)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igCalcWindowNextAutoFitSize(nonUDT_out,window)
    return nonUDT_out
end
M.CalcWrapWidthForPos = lib.igCalcWrapWidthForPos
M.CallContextHooks = lib.igCallContextHooks
function M.CaptureKeyboardFromApp(want_capture_keyboard_value)
    if want_capture_keyboard_value == nil then want_capture_keyboard_value = true end
    return lib.igCaptureKeyboardFromApp(want_capture_keyboard_value)
end
function M.CaptureMouseFromApp(want_capture_mouse_value)
    if want_capture_mouse_value == nil then want_capture_mouse_value = true end
    return lib.igCaptureMouseFromApp(want_capture_mouse_value)
end
M.Checkbox = lib.igCheckbox
M.CheckboxFlagsIntPtr = lib.igCheckboxFlagsIntPtr
M.CheckboxFlagsUintPtr = lib.igCheckboxFlagsUintPtr
M.CheckboxFlagsS64Ptr = lib.igCheckboxFlagsS64Ptr
M.CheckboxFlagsU64Ptr = lib.igCheckboxFlagsU64Ptr
function M.CheckboxFlags(a1,a2,a3) -- generic version
    if (ffi.istype('int*',a2) or ffi.istype('int[]',a2)) then return M.CheckboxFlagsIntPtr(a1,a2,a3) end
    if (ffi.istype('unsigned int*',a2) or ffi.istype('unsigned int',a2) or ffi.istype('unsigned int[]',a2)) then return M.CheckboxFlagsUintPtr(a1,a2,a3) end
    if (ffi.istype('ImS64*',a2) or ffi.istype('ImS64',a2) or ffi.istype('ImS64[]',a2)) then return M.CheckboxFlagsS64Ptr(a1,a2,a3) end
    if (ffi.istype('ImU64*',a2) or ffi.istype('ImU64',a2) or ffi.istype('ImU64[]',a2)) then return M.CheckboxFlagsU64Ptr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.CheckboxFlags could not find overloaded'
end
M.ClearActiveID = lib.igClearActiveID
M.ClearDragDrop = lib.igClearDragDrop
M.ClearIniSettings = lib.igClearIniSettings
M.CloseButton = lib.igCloseButton
M.CloseCurrentPopup = lib.igCloseCurrentPopup
M.ClosePopupToLevel = lib.igClosePopupToLevel
M.ClosePopupsOverWindow = lib.igClosePopupsOverWindow
M.CollapseButton = lib.igCollapseButton
function M.CollapsingHeaderTreeNodeFlags(label,flags)
    flags = flags or 0
    return lib.igCollapsingHeaderTreeNodeFlags(label,flags)
end
function M.CollapsingHeaderBoolPtr(label,p_visible,flags)
    flags = flags or 0
    return lib.igCollapsingHeaderBoolPtr(label,p_visible,flags)
end
function M.CollapsingHeader(a1,a2,a3) -- generic version
    if ((ffi.istype('ImGuiTreeNodeFlags',a2) or type(a2)=='number') or type(a2)=='nil') then return M.CollapsingHeaderTreeNodeFlags(a1,a2) end
    if (ffi.istype('bool*',a2) or ffi.istype('bool',a2) or ffi.istype('bool[]',a2)) then return M.CollapsingHeaderBoolPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.CollapsingHeader could not find overloaded'
end
function M.ColorButton(desc_id,col,flags,size)
    flags = flags or 0
    size = size or ImVec2(0,0)
    return lib.igColorButton(desc_id,col,flags,size)
end
M.ColorConvertFloat4ToU32 = lib.igColorConvertFloat4ToU32
M.ColorConvertHSVtoRGB = lib.igColorConvertHSVtoRGB
M.ColorConvertRGBtoHSV = lib.igColorConvertRGBtoHSV
function M.ColorConvertU32ToFloat4(_in)
    local nonUDT_out = ffi.new("ImVec4")
    lib.igColorConvertU32ToFloat4(nonUDT_out,_in)
    return nonUDT_out
end
function M.ColorEdit3(label,col,flags)
    flags = flags or 0
    return lib.igColorEdit3(label,col,flags)
end
function M.ColorEdit4(label,col,flags)
    flags = flags or 0
    return lib.igColorEdit4(label,col,flags)
end
M.ColorEditOptionsPopup = lib.igColorEditOptionsPopup
function M.ColorPicker3(label,col,flags)
    flags = flags or 0
    return lib.igColorPicker3(label,col,flags)
end
function M.ColorPicker4(label,col,flags,ref_col)
    flags = flags or 0
    ref_col = ref_col or nil
    return lib.igColorPicker4(label,col,flags,ref_col)
end
M.ColorPickerOptionsPopup = lib.igColorPickerOptionsPopup
M.ColorTooltip = lib.igColorTooltip
function M.Columns(count,id,border)
    if border == nil then border = true end
    count = count or 1
    id = id or nil
    return lib.igColumns(count,id,border)
end
function M.ComboStr_arr(label,current_item,items,items_count,popup_max_height_in_items)
    popup_max_height_in_items = popup_max_height_in_items or -1
    return lib.igComboStr_arr(label,current_item,items,items_count,popup_max_height_in_items)
end
function M.ComboStr(label,current_item,items_separated_by_zeros,popup_max_height_in_items)
    popup_max_height_in_items = popup_max_height_in_items or -1
    return lib.igComboStr(label,current_item,items_separated_by_zeros,popup_max_height_in_items)
end
function M.ComboFnBoolPtr(label,current_item,items_getter,data,items_count,popup_max_height_in_items)
    popup_max_height_in_items = popup_max_height_in_items or -1
    return lib.igComboFnBoolPtr(label,current_item,items_getter,data,items_count,popup_max_height_in_items)
end
function M.Combo(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('const char* const[]',a3) or ffi.istype('const char const[]',a3) or ffi.istype('const char const[][]',a3)) then return M.ComboStr_arr(a1,a2,a3,a4,a5) end
    if (ffi.istype('const char*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ComboStr(a1,a2,a3,a4) end
    if ffi.istype('bool(*)(void* data,int idx,const char** out_text)',a3) then return M.ComboFnBoolPtr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.Combo could not find overloaded'
end
function M.CreateContext(shared_font_atlas)
    shared_font_atlas = shared_font_atlas or nil
    return lib.igCreateContext(shared_font_atlas)
end
M.CreateNewWindowSettings = lib.igCreateNewWindowSettings
M.DataTypeApplyOp = lib.igDataTypeApplyOp
M.DataTypeApplyOpFromText = lib.igDataTypeApplyOpFromText
M.DataTypeClamp = lib.igDataTypeClamp
M.DataTypeCompare = lib.igDataTypeCompare
M.DataTypeFormatString = lib.igDataTypeFormatString
M.DataTypeGetInfo = lib.igDataTypeGetInfo
M.DebugCheckVersionAndDataLayout = lib.igDebugCheckVersionAndDataLayout
function M.DebugDrawItemRect(col)
    col = col or 4278190335
    return lib.igDebugDrawItemRect(col)
end
M.DebugNodeColumns = lib.igDebugNodeColumns
M.DebugNodeDockNode = lib.igDebugNodeDockNode
M.DebugNodeDrawCmdShowMeshAndBoundingBox = lib.igDebugNodeDrawCmdShowMeshAndBoundingBox
M.DebugNodeDrawList = lib.igDebugNodeDrawList
M.DebugNodeStorage = lib.igDebugNodeStorage
M.DebugNodeTabBar = lib.igDebugNodeTabBar
M.DebugNodeTable = lib.igDebugNodeTable
M.DebugNodeTableSettings = lib.igDebugNodeTableSettings
M.DebugNodeViewport = lib.igDebugNodeViewport
M.DebugNodeWindow = lib.igDebugNodeWindow
M.DebugNodeWindowSettings = lib.igDebugNodeWindowSettings
M.DebugNodeWindowsList = lib.igDebugNodeWindowsList
M.DebugRenderViewportThumbnail = lib.igDebugRenderViewportThumbnail
M.DebugStartItemPicker = lib.igDebugStartItemPicker
function M.DestroyContext(ctx)
    ctx = ctx or nil
    return lib.igDestroyContext(ctx)
end
M.DestroyPlatformWindow = lib.igDestroyPlatformWindow
M.DestroyPlatformWindows = lib.igDestroyPlatformWindows
function M.DockBuilderAddNode(node_id,flags)
    flags = flags or 0
    node_id = node_id or 0
    return lib.igDockBuilderAddNode(node_id,flags)
end
M.DockBuilderCopyDockSpace = lib.igDockBuilderCopyDockSpace
M.DockBuilderCopyNode = lib.igDockBuilderCopyNode
M.DockBuilderCopyWindowSettings = lib.igDockBuilderCopyWindowSettings
M.DockBuilderDockWindow = lib.igDockBuilderDockWindow
M.DockBuilderFinish = lib.igDockBuilderFinish
M.DockBuilderGetCentralNode = lib.igDockBuilderGetCentralNode
M.DockBuilderGetNode = lib.igDockBuilderGetNode
M.DockBuilderRemoveNode = lib.igDockBuilderRemoveNode
M.DockBuilderRemoveNodeChildNodes = lib.igDockBuilderRemoveNodeChildNodes
function M.DockBuilderRemoveNodeDockedWindows(node_id,clear_settings_refs)
    if clear_settings_refs == nil then clear_settings_refs = true end
    return lib.igDockBuilderRemoveNodeDockedWindows(node_id,clear_settings_refs)
end
M.DockBuilderSetNodePos = lib.igDockBuilderSetNodePos
M.DockBuilderSetNodeSize = lib.igDockBuilderSetNodeSize
M.DockBuilderSplitNode = lib.igDockBuilderSplitNode
M.DockContextCalcDropPosForDocking = lib.igDockContextCalcDropPosForDocking
M.DockContextClearNodes = lib.igDockContextClearNodes
M.DockContextGenNodeID = lib.igDockContextGenNodeID
M.DockContextInitialize = lib.igDockContextInitialize
M.DockContextNewFrameUpdateDocking = lib.igDockContextNewFrameUpdateDocking
M.DockContextNewFrameUpdateUndocking = lib.igDockContextNewFrameUpdateUndocking
M.DockContextQueueDock = lib.igDockContextQueueDock
M.DockContextQueueUndockNode = lib.igDockContextQueueUndockNode
M.DockContextQueueUndockWindow = lib.igDockContextQueueUndockWindow
M.DockContextRebuildNodes = lib.igDockContextRebuildNodes
M.DockContextShutdown = lib.igDockContextShutdown
M.DockNodeBeginAmendTabBar = lib.igDockNodeBeginAmendTabBar
M.DockNodeEndAmendTabBar = lib.igDockNodeEndAmendTabBar
M.DockNodeGetDepth = lib.igDockNodeGetDepth
M.DockNodeGetRootNode = lib.igDockNodeGetRootNode
function M.DockSpace(id,size,flags,window_class)
    flags = flags or 0
    size = size or ImVec2(0,0)
    window_class = window_class or nil
    return lib.igDockSpace(id,size,flags,window_class)
end
function M.DockSpaceOverViewport(viewport,flags,window_class)
    flags = flags or 0
    viewport = viewport or nil
    window_class = window_class or nil
    return lib.igDockSpaceOverViewport(viewport,flags,window_class)
end
M.DragBehavior = lib.igDragBehavior
function M.DragFloat(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    v_max = v_max or 0.0
    v_min = v_min or 0.0
    v_speed = v_speed or 1.0
    return lib.igDragFloat(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragFloat2(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    v_max = v_max or 0.0
    v_min = v_min or 0.0
    v_speed = v_speed or 1.0
    return lib.igDragFloat2(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragFloat3(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    v_max = v_max or 0.0
    v_min = v_min or 0.0
    v_speed = v_speed or 1.0
    return lib.igDragFloat3(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragFloat4(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    v_max = v_max or 0.0
    v_min = v_min or 0.0
    v_speed = v_speed or 1.0
    return lib.igDragFloat4(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragFloatRange2(label,v_current_min,v_current_max,v_speed,v_min,v_max,format,format_max,flags)
    flags = flags or 0
    format = format or "%.3f"
    format_max = format_max or nil
    v_max = v_max or 0.0
    v_min = v_min or 0.0
    v_speed = v_speed or 1.0
    return lib.igDragFloatRange2(label,v_current_min,v_current_max,v_speed,v_min,v_max,format,format_max,flags)
end
function M.DragInt(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    v_max = v_max or 0
    v_min = v_min or 0
    v_speed = v_speed or 1.0
    return lib.igDragInt(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragInt2(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    v_max = v_max or 0
    v_min = v_min or 0
    v_speed = v_speed or 1.0
    return lib.igDragInt2(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragInt3(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    v_max = v_max or 0
    v_min = v_min or 0
    v_speed = v_speed or 1.0
    return lib.igDragInt3(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragInt4(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    v_max = v_max or 0
    v_min = v_min or 0
    v_speed = v_speed or 1.0
    return lib.igDragInt4(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragIntRange2(label,v_current_min,v_current_max,v_speed,v_min,v_max,format,format_max,flags)
    flags = flags or 0
    format = format or "%d"
    format_max = format_max or nil
    v_max = v_max or 0
    v_min = v_min or 0
    v_speed = v_speed or 1.0
    return lib.igDragIntRange2(label,v_current_min,v_current_max,v_speed,v_min,v_max,format,format_max,flags)
end
function M.DragScalar(label,data_type,p_data,v_speed,p_min,p_max,format,flags)
    flags = flags or 0
    format = format or nil
    p_max = p_max or nil
    p_min = p_min or nil
    return lib.igDragScalar(label,data_type,p_data,v_speed,p_min,p_max,format,flags)
end
function M.DragScalarN(label,data_type,p_data,components,v_speed,p_min,p_max,format,flags)
    flags = flags or 0
    format = format or nil
    p_max = p_max or nil
    p_min = p_min or nil
    return lib.igDragScalarN(label,data_type,p_data,components,v_speed,p_min,p_max,format,flags)
end
M.Dummy = lib.igDummy
M.End = lib.igEnd
M.EndChild = lib.igEndChild
M.EndChildFrame = lib.igEndChildFrame
M.EndColumns = lib.igEndColumns
M.EndCombo = lib.igEndCombo
M.EndDragDropSource = lib.igEndDragDropSource
M.EndDragDropTarget = lib.igEndDragDropTarget
M.EndFrame = lib.igEndFrame
M.EndGroup = lib.igEndGroup
M.EndListBox = lib.igEndListBox
M.EndMainMenuBar = lib.igEndMainMenuBar
M.EndMenu = lib.igEndMenu
M.EndMenuBar = lib.igEndMenuBar
M.EndPopup = lib.igEndPopup
M.EndTabBar = lib.igEndTabBar
M.EndTabItem = lib.igEndTabItem
M.EndTable = lib.igEndTable
M.EndTooltip = lib.igEndTooltip
function M.ErrorCheckEndFrameRecover(log_callback,user_data)
    user_data = user_data or nil
    return lib.igErrorCheckEndFrameRecover(log_callback,user_data)
end
function M.FindBestWindowPosForPopup(window)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igFindBestWindowPosForPopup(nonUDT_out,window)
    return nonUDT_out
end
function M.FindBestWindowPosForPopupEx(ref_pos,size,last_dir,r_outer,r_avoid,policy)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igFindBestWindowPosForPopupEx(nonUDT_out,ref_pos,size,last_dir,r_outer,r_avoid,policy)
    return nonUDT_out
end
M.FindOrCreateColumns = lib.igFindOrCreateColumns
M.FindOrCreateWindowSettings = lib.igFindOrCreateWindowSettings
function M.FindRenderedTextEnd(text,text_end)
    text_end = text_end or nil
    return lib.igFindRenderedTextEnd(text,text_end)
end
M.FindSettingsHandler = lib.igFindSettingsHandler
M.FindViewportByID = lib.igFindViewportByID
M.FindViewportByPlatformHandle = lib.igFindViewportByPlatformHandle
M.FindWindowByID = lib.igFindWindowByID
M.FindWindowByName = lib.igFindWindowByName
M.FindWindowSettings = lib.igFindWindowSettings
M.FocusTopMostWindowUnderOne = lib.igFocusTopMostWindowUnderOne
M.FocusWindow = lib.igFocusWindow
M.FocusableItemRegister = lib.igFocusableItemRegister
M.FocusableItemUnregister = lib.igFocusableItemUnregister
M.GcAwakeTransientWindowBuffers = lib.igGcAwakeTransientWindowBuffers
M.GcCompactTransientMiscBuffers = lib.igGcCompactTransientMiscBuffers
M.GcCompactTransientWindowBuffers = lib.igGcCompactTransientWindowBuffers
M.GetActiveID = lib.igGetActiveID
M.GetBackgroundDrawListNil = lib.igGetBackgroundDrawListNil
M.GetBackgroundDrawListViewportPtr = lib.igGetBackgroundDrawListViewportPtr
function M.GetBackgroundDrawList(a1) -- generic version
    if a1==nil then return M.GetBackgroundDrawListNil() end
    if (ffi.istype('ImGuiViewport*',a1) or ffi.istype('ImGuiViewport',a1) or ffi.istype('ImGuiViewport[]',a1)) then return M.GetBackgroundDrawListViewportPtr(a1) end
    print(a1)
    error'M.GetBackgroundDrawList could not find overloaded'
end
M.GetClipboardText = lib.igGetClipboardText
function M.GetColorU32Col(idx,alpha_mul)
    alpha_mul = alpha_mul or 1.0
    return lib.igGetColorU32Col(idx,alpha_mul)
end
M.GetColorU32Vec4 = lib.igGetColorU32Vec4
M.GetColorU32U32 = lib.igGetColorU32U32
function M.GetColorU32(a1,a2) -- generic version
    if (ffi.istype('ImGuiCol',a1) or type(a1)=='number') then return M.GetColorU32Col(a1,a2) end
    if ffi.istype('const ImVec4',a1) then return M.GetColorU32Vec4(a1) end
    if (ffi.istype('ImU32',a1) or type(a1)=='number') then return M.GetColorU32U32(a1) end
    print(a1,a2)
    error'M.GetColorU32 could not find overloaded'
end
M.GetColumnIndex = lib.igGetColumnIndex
M.GetColumnNormFromOffset = lib.igGetColumnNormFromOffset
function M.GetColumnOffset(column_index)
    column_index = column_index or -1
    return lib.igGetColumnOffset(column_index)
end
M.GetColumnOffsetFromNorm = lib.igGetColumnOffsetFromNorm
function M.GetColumnWidth(column_index)
    column_index = column_index or -1
    return lib.igGetColumnWidth(column_index)
end
M.GetColumnsCount = lib.igGetColumnsCount
M.GetColumnsID = lib.igGetColumnsID
function M.GetContentRegionAvail()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetContentRegionAvail(nonUDT_out)
    return nonUDT_out
end
function M.GetContentRegionMax()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetContentRegionMax(nonUDT_out)
    return nonUDT_out
end
function M.GetContentRegionMaxAbs()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetContentRegionMaxAbs(nonUDT_out)
    return nonUDT_out
end
M.GetCurrentContext = lib.igGetCurrentContext
M.GetCurrentWindow = lib.igGetCurrentWindow
M.GetCurrentWindowRead = lib.igGetCurrentWindowRead
function M.GetCursorPos()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetCursorPos(nonUDT_out)
    return nonUDT_out
end
M.GetCursorPosX = lib.igGetCursorPosX
M.GetCursorPosY = lib.igGetCursorPosY
function M.GetCursorScreenPos()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetCursorScreenPos(nonUDT_out)
    return nonUDT_out
end
function M.GetCursorStartPos()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetCursorStartPos(nonUDT_out)
    return nonUDT_out
end
M.GetDefaultFont = lib.igGetDefaultFont
M.GetDragDropPayload = lib.igGetDragDropPayload
M.GetDrawData = lib.igGetDrawData
M.GetDrawListSharedData = lib.igGetDrawListSharedData
M.GetFocusID = lib.igGetFocusID
M.GetFocusScope = lib.igGetFocusScope
M.GetFocusedFocusScope = lib.igGetFocusedFocusScope
M.GetFont = lib.igGetFont
M.GetFontSize = lib.igGetFontSize
function M.GetFontTexUvWhitePixel()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetFontTexUvWhitePixel(nonUDT_out)
    return nonUDT_out
end
M.GetForegroundDrawListNil = lib.igGetForegroundDrawListNil
M.GetForegroundDrawListViewportPtr = lib.igGetForegroundDrawListViewportPtr
M.GetForegroundDrawListWindowPtr = lib.igGetForegroundDrawListWindowPtr
function M.GetForegroundDrawList(a1) -- generic version
    if a1==nil then return M.GetForegroundDrawListNil() end
    if (ffi.istype('ImGuiViewport*',a1) or ffi.istype('ImGuiViewport',a1) or ffi.istype('ImGuiViewport[]',a1)) then return M.GetForegroundDrawListViewportPtr(a1) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.GetForegroundDrawListWindowPtr(a1) end
    print(a1)
    error'M.GetForegroundDrawList could not find overloaded'
end
M.GetFrameCount = lib.igGetFrameCount
M.GetFrameHeight = lib.igGetFrameHeight
M.GetFrameHeightWithSpacing = lib.igGetFrameHeightWithSpacing
M.GetHoveredID = lib.igGetHoveredID
M.GetIDStr = lib.igGetIDStr
M.GetIDStrStr = lib.igGetIDStrStr
M.GetIDPtr = lib.igGetIDPtr
function M.GetID(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a2==nil then return M.GetIDStr(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.GetIDStrStr(a1,a2) end
    if ffi.istype('const void*',a1) then return M.GetIDPtr(a1) end
    print(a1,a2)
    error'M.GetID could not find overloaded'
end
M.GetIDWithSeed = lib.igGetIDWithSeed
M.GetIO = lib.igGetIO
M.GetInputTextState = lib.igGetInputTextState
M.GetItemID = lib.igGetItemID
function M.GetItemRectMax()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetItemRectMax(nonUDT_out)
    return nonUDT_out
end
function M.GetItemRectMin()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetItemRectMin(nonUDT_out)
    return nonUDT_out
end
function M.GetItemRectSize()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetItemRectSize(nonUDT_out)
    return nonUDT_out
end
M.GetItemStatusFlags = lib.igGetItemStatusFlags
M.GetItemsFlags = lib.igGetItemsFlags
M.GetKeyIndex = lib.igGetKeyIndex
M.GetKeyPressedAmount = lib.igGetKeyPressedAmount
M.GetMainViewport = lib.igGetMainViewport
M.GetMergedKeyModFlags = lib.igGetMergedKeyModFlags
M.GetMouseCursor = lib.igGetMouseCursor
function M.GetMouseDragDelta(button,lock_threshold)
    button = button or 0
    lock_threshold = lock_threshold or -1.0
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetMouseDragDelta(nonUDT_out,button,lock_threshold)
    return nonUDT_out
end
function M.GetMousePos()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetMousePos(nonUDT_out)
    return nonUDT_out
end
function M.GetMousePosOnOpeningCurrentPopup()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetMousePosOnOpeningCurrentPopup(nonUDT_out)
    return nonUDT_out
end
M.GetNavInputAmount = lib.igGetNavInputAmount
function M.GetNavInputAmount2d(dir_sources,mode,slow_factor,fast_factor)
    fast_factor = fast_factor or 0.0
    slow_factor = slow_factor or 0.0
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetNavInputAmount2d(nonUDT_out,dir_sources,mode,slow_factor,fast_factor)
    return nonUDT_out
end
M.GetPlatformIO = lib.igGetPlatformIO
M.GetScrollMaxX = lib.igGetScrollMaxX
M.GetScrollMaxY = lib.igGetScrollMaxY
M.GetScrollX = lib.igGetScrollX
M.GetScrollY = lib.igGetScrollY
M.GetStateStorage = lib.igGetStateStorage
M.GetStyle = lib.igGetStyle
M.GetStyleColorName = lib.igGetStyleColorName
M.GetStyleColorVec4 = lib.igGetStyleColorVec4
M.GetTextLineHeight = lib.igGetTextLineHeight
M.GetTextLineHeightWithSpacing = lib.igGetTextLineHeightWithSpacing
M.GetTime = lib.igGetTime
M.GetTopMostPopupModal = lib.igGetTopMostPopupModal
M.GetTreeNodeToLabelSpacing = lib.igGetTreeNodeToLabelSpacing
M.GetVersion = lib.igGetVersion
function M.GetWindowAllowedExtentRect(window)
    local nonUDT_out = ffi.new("ImRect")
    lib.igGetWindowAllowedExtentRect(nonUDT_out,window)
    return nonUDT_out
end
M.GetWindowAlwaysWantOwnTabBar = lib.igGetWindowAlwaysWantOwnTabBar
function M.GetWindowContentRegionMax()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetWindowContentRegionMax(nonUDT_out)
    return nonUDT_out
end
function M.GetWindowContentRegionMin()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetWindowContentRegionMin(nonUDT_out)
    return nonUDT_out
end
M.GetWindowContentRegionWidth = lib.igGetWindowContentRegionWidth
M.GetWindowDockID = lib.igGetWindowDockID
M.GetWindowDockNode = lib.igGetWindowDockNode
M.GetWindowDpiScale = lib.igGetWindowDpiScale
M.GetWindowDrawList = lib.igGetWindowDrawList
M.GetWindowHeight = lib.igGetWindowHeight
function M.GetWindowPos()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetWindowPos(nonUDT_out)
    return nonUDT_out
end
M.GetWindowResizeID = lib.igGetWindowResizeID
M.GetWindowScrollbarID = lib.igGetWindowScrollbarID
function M.GetWindowScrollbarRect(window,axis)
    local nonUDT_out = ffi.new("ImRect")
    lib.igGetWindowScrollbarRect(nonUDT_out,window,axis)
    return nonUDT_out
end
function M.GetWindowSize()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetWindowSize(nonUDT_out)
    return nonUDT_out
end
M.GetWindowViewport = lib.igGetWindowViewport
M.GetWindowWidth = lib.igGetWindowWidth
M.ImAbsFloat = lib.igImAbsFloat
M.ImAbsdouble = lib.igImAbsdouble
function M.ImAbs(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImAbsFloat(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImAbsdouble(a1) end
    print(a1)
    error'M.ImAbs could not find overloaded'
end
M.ImAlphaBlendColors = lib.igImAlphaBlendColors
function M.ImBezierCubicCalc(p1,p2,p3,p4,t)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImBezierCubicCalc(nonUDT_out,p1,p2,p3,p4,t)
    return nonUDT_out
end
function M.ImBezierCubicClosestPoint(p1,p2,p3,p4,p,num_segments)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImBezierCubicClosestPoint(nonUDT_out,p1,p2,p3,p4,p,num_segments)
    return nonUDT_out
end
function M.ImBezierCubicClosestPointCasteljau(p1,p2,p3,p4,p,tess_tol)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImBezierCubicClosestPointCasteljau(nonUDT_out,p1,p2,p3,p4,p,tess_tol)
    return nonUDT_out
end
function M.ImBezierQuadraticCalc(p1,p2,p3,t)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImBezierQuadraticCalc(nonUDT_out,p1,p2,p3,t)
    return nonUDT_out
end
M.ImBitArrayClearBit = lib.igImBitArrayClearBit
M.ImBitArraySetBit = lib.igImBitArraySetBit
M.ImBitArraySetBitRange = lib.igImBitArraySetBitRange
M.ImBitArrayTestBit = lib.igImBitArrayTestBit
M.ImCharIsBlankA = lib.igImCharIsBlankA
M.ImCharIsBlankW = lib.igImCharIsBlankW
function M.ImClamp(v,mn,mx)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImClamp(nonUDT_out,v,mn,mx)
    return nonUDT_out
end
M.ImDot = lib.igImDot
M.ImFileClose = lib.igImFileClose
M.ImFileGetSize = lib.igImFileGetSize
function M.ImFileLoadToMemory(filename,mode,out_file_size,padding_bytes)
    out_file_size = out_file_size or nil
    padding_bytes = padding_bytes or 0
    return lib.igImFileLoadToMemory(filename,mode,out_file_size,padding_bytes)
end
M.ImFileOpen = lib.igImFileOpen
M.ImFileRead = lib.igImFileRead
M.ImFileWrite = lib.igImFileWrite
M.ImFloorFloat = lib.igImFloorFloat
function M.ImFloorVec2(v)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImFloorVec2(nonUDT_out,v)
    return nonUDT_out
end
function M.ImFloor(a1,a2) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImFloorFloat(a1) end
    if (ffi.istype('ImVec2*',a1) or ffi.istype('ImVec2',a1) or ffi.istype('ImVec2[]',a1)) then return M.ImFloorVec2(a2) end
    print(a1,a2)
    error'M.ImFloor could not find overloaded'
end
M.ImFontAtlasBuildFinish = lib.igImFontAtlasBuildFinish
M.ImFontAtlasBuildInit = lib.igImFontAtlasBuildInit
M.ImFontAtlasBuildMultiplyCalcLookupTable = lib.igImFontAtlasBuildMultiplyCalcLookupTable
M.ImFontAtlasBuildMultiplyRectAlpha8 = lib.igImFontAtlasBuildMultiplyRectAlpha8
M.ImFontAtlasBuildPackCustomRects = lib.igImFontAtlasBuildPackCustomRects
M.ImFontAtlasBuildRender32bppRectFromString = lib.igImFontAtlasBuildRender32bppRectFromString
M.ImFontAtlasBuildRender8bppRectFromString = lib.igImFontAtlasBuildRender8bppRectFromString
M.ImFontAtlasBuildSetupFont = lib.igImFontAtlasBuildSetupFont
M.ImFontAtlasGetBuilderForStbTruetype = lib.igImFontAtlasGetBuilderForStbTruetype
M.ImFormatString = lib.igImFormatString
M.ImFormatStringV = lib.igImFormatStringV
M.ImGetDirQuadrantFromDelta = lib.igImGetDirQuadrantFromDelta
function M.ImHashData(data,data_size,seed)
    seed = seed or 0
    return lib.igImHashData(data,data_size,seed)
end
function M.ImHashStr(data,data_size,seed)
    data_size = data_size or 0
    seed = seed or 0
    return lib.igImHashStr(data,data_size,seed)
end
M.ImInvLength = lib.igImInvLength
M.ImIsPowerOfTwoInt = lib.igImIsPowerOfTwoInt
M.ImIsPowerOfTwoU64 = lib.igImIsPowerOfTwoU64
function M.ImIsPowerOfTwo(a1) -- generic version
    if (ffi.istype('int',a1) or type(a1)=='number') then return M.ImIsPowerOfTwoInt(a1) end
    if ffi.istype('ImU64',a1) then return M.ImIsPowerOfTwoU64(a1) end
    print(a1)
    error'M.ImIsPowerOfTwo could not find overloaded'
end
M.ImLengthSqrVec2 = lib.igImLengthSqrVec2
M.ImLengthSqrVec4 = lib.igImLengthSqrVec4
function M.ImLengthSqr(a1) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.ImLengthSqrVec2(a1) end
    if ffi.istype('const ImVec4',a1) then return M.ImLengthSqrVec4(a1) end
    print(a1)
    error'M.ImLengthSqr could not find overloaded'
end
function M.ImLerpVec2Float(a,b,t)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImLerpVec2Float(nonUDT_out,a,b,t)
    return nonUDT_out
end
function M.ImLerpVec2Vec2(a,b,t)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImLerpVec2Vec2(nonUDT_out,a,b,t)
    return nonUDT_out
end
function M.ImLerpVec4(a,b,t)
    local nonUDT_out = ffi.new("ImVec4")
    lib.igImLerpVec4(nonUDT_out,a,b,t)
    return nonUDT_out
end
function M.ImLerp(a2,a3,a4) -- generic version
    if (ffi.istype('ImVec2*',a1) or ffi.istype('ImVec2',a1) or ffi.istype('ImVec2[]',a1)) and (ffi.istype('float',a4) or type(a4)=='number') then return M.ImLerpVec2Float(a2,a3,a4) end
    if (ffi.istype('ImVec2*',a1) or ffi.istype('ImVec2',a1) or ffi.istype('ImVec2[]',a1)) and ffi.istype('const ImVec2',a4) then return M.ImLerpVec2Vec2(a2,a3,a4) end
    if (ffi.istype('ImVec4*',a1) or ffi.istype('ImVec4',a1) or ffi.istype('ImVec4[]',a1)) then return M.ImLerpVec4(a2,a3,a4) end
    print(a2,a3,a4)
    error'M.ImLerp could not find overloaded'
end
function M.ImLineClosestPoint(a,b,p)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImLineClosestPoint(nonUDT_out,a,b,p)
    return nonUDT_out
end
M.ImLinearSweep = lib.igImLinearSweep
M.ImLogFloat = lib.igImLogFloat
M.ImLogdouble = lib.igImLogdouble
function M.ImLog(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImLogFloat(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImLogdouble(a1) end
    print(a1)
    error'M.ImLog could not find overloaded'
end
function M.ImMax(lhs,rhs)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImMax(nonUDT_out,lhs,rhs)
    return nonUDT_out
end
function M.ImMin(lhs,rhs)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImMin(nonUDT_out,lhs,rhs)
    return nonUDT_out
end
M.ImModPositive = lib.igImModPositive
function M.ImMul(lhs,rhs)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImMul(nonUDT_out,lhs,rhs)
    return nonUDT_out
end
M.ImParseFormatFindEnd = lib.igImParseFormatFindEnd
M.ImParseFormatFindStart = lib.igImParseFormatFindStart
M.ImParseFormatPrecision = lib.igImParseFormatPrecision
M.ImParseFormatTrimDecorations = lib.igImParseFormatTrimDecorations
M.ImPowFloat = lib.igImPowFloat
M.ImPowdouble = lib.igImPowdouble
function M.ImPow(a1,a2) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPowFloat(a1,a2) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPowdouble(a1,a2) end
    print(a1,a2)
    error'M.ImPow could not find overloaded'
end
function M.ImRotate(v,cos_a,sin_a)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImRotate(nonUDT_out,v,cos_a,sin_a)
    return nonUDT_out
end
M.ImSaturate = lib.igImSaturate
M.ImSignFloat = lib.igImSignFloat
M.ImSigndouble = lib.igImSigndouble
function M.ImSign(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImSignFloat(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImSigndouble(a1) end
    print(a1)
    error'M.ImSign could not find overloaded'
end
M.ImStrSkipBlank = lib.igImStrSkipBlank
M.ImStrTrimBlanks = lib.igImStrTrimBlanks
M.ImStrbolW = lib.igImStrbolW
M.ImStrchrRange = lib.igImStrchrRange
M.ImStrdup = lib.igImStrdup
M.ImStrdupcpy = lib.igImStrdupcpy
M.ImStreolRange = lib.igImStreolRange
M.ImStricmp = lib.igImStricmp
M.ImStristr = lib.igImStristr
M.ImStrlenW = lib.igImStrlenW
M.ImStrncpy = lib.igImStrncpy
M.ImStrnicmp = lib.igImStrnicmp
M.ImTextCharFromUtf8 = lib.igImTextCharFromUtf8
M.ImTextCountCharsFromUtf8 = lib.igImTextCountCharsFromUtf8
M.ImTextCountUtf8BytesFromChar = lib.igImTextCountUtf8BytesFromChar
M.ImTextCountUtf8BytesFromStr = lib.igImTextCountUtf8BytesFromStr
function M.ImTextStrFromUtf8(buf,buf_size,in_text,in_text_end,in_remaining)
    in_remaining = in_remaining or nil
    return lib.igImTextStrFromUtf8(buf,buf_size,in_text,in_text_end,in_remaining)
end
M.ImTextStrToUtf8 = lib.igImTextStrToUtf8
M.ImTriangleArea = lib.igImTriangleArea
M.ImTriangleBarycentricCoords = lib.igImTriangleBarycentricCoords
function M.ImTriangleClosestPoint(a,b,c,p)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImTriangleClosestPoint(nonUDT_out,a,b,c,p)
    return nonUDT_out
end
M.ImTriangleContainsPoint = lib.igImTriangleContainsPoint
M.ImUpperPowerOfTwo = lib.igImUpperPowerOfTwo
function M.Image(user_texture_id,size,uv0,uv1,tint_col,border_col)
    border_col = border_col or ImVec4(0,0,0,0)
    tint_col = tint_col or ImVec4(1,1,1,1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,1)
    return lib.igImage(user_texture_id,size,uv0,uv1,tint_col,border_col)
end
function M.ImageButton(user_texture_id,size,uv0,uv1,frame_padding,bg_col,tint_col)
    bg_col = bg_col or ImVec4(0,0,0,0)
    frame_padding = frame_padding or -1
    tint_col = tint_col or ImVec4(1,1,1,1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,1)
    return lib.igImageButton(user_texture_id,size,uv0,uv1,frame_padding,bg_col,tint_col)
end
M.ImageButtonEx = lib.igImageButtonEx
function M.Indent(indent_w)
    indent_w = indent_w or 0.0
    return lib.igIndent(indent_w)
end
M.Initialize = lib.igInitialize
function M.InputDouble(label,v,step,step_fast,format,flags)
    flags = flags or 0
    format = format or "%.6f"
    step = step or 0
    step_fast = step_fast or 0
    return lib.igInputDouble(label,v,step,step_fast,format,flags)
end
function M.InputFloat(label,v,step,step_fast,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    step = step or 0.0
    step_fast = step_fast or 0.0
    return lib.igInputFloat(label,v,step,step_fast,format,flags)
end
function M.InputFloat2(label,v,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igInputFloat2(label,v,format,flags)
end
function M.InputFloat3(label,v,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igInputFloat3(label,v,format,flags)
end
function M.InputFloat4(label,v,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igInputFloat4(label,v,format,flags)
end
function M.InputInt(label,v,step,step_fast,flags)
    flags = flags or 0
    step = step or 1
    step_fast = step_fast or 100
    return lib.igInputInt(label,v,step,step_fast,flags)
end
function M.InputInt2(label,v,flags)
    flags = flags or 0
    return lib.igInputInt2(label,v,flags)
end
function M.InputInt3(label,v,flags)
    flags = flags or 0
    return lib.igInputInt3(label,v,flags)
end
function M.InputInt4(label,v,flags)
    flags = flags or 0
    return lib.igInputInt4(label,v,flags)
end
function M.InputScalar(label,data_type,p_data,p_step,p_step_fast,format,flags)
    flags = flags or 0
    format = format or nil
    p_step = p_step or nil
    p_step_fast = p_step_fast or nil
    return lib.igInputScalar(label,data_type,p_data,p_step,p_step_fast,format,flags)
end
function M.InputScalarN(label,data_type,p_data,components,p_step,p_step_fast,format,flags)
    flags = flags or 0
    format = format or nil
    p_step = p_step or nil
    p_step_fast = p_step_fast or nil
    return lib.igInputScalarN(label,data_type,p_data,components,p_step,p_step_fast,format,flags)
end
function M.InputText(label,buf,buf_size,flags,callback,user_data)
    callback = callback or nil
    flags = flags or 0
    user_data = user_data or nil
    return lib.igInputText(label,buf,buf_size,flags,callback,user_data)
end
function M.InputTextEx(label,hint,buf,buf_size,size_arg,flags,callback,user_data)
    callback = callback or nil
    user_data = user_data or nil
    return lib.igInputTextEx(label,hint,buf,buf_size,size_arg,flags,callback,user_data)
end
function M.InputTextMultiline(label,buf,buf_size,size,flags,callback,user_data)
    callback = callback or nil
    flags = flags or 0
    size = size or ImVec2(0,0)
    user_data = user_data or nil
    return lib.igInputTextMultiline(label,buf,buf_size,size,flags,callback,user_data)
end
function M.InputTextWithHint(label,hint,buf,buf_size,flags,callback,user_data)
    callback = callback or nil
    flags = flags or 0
    user_data = user_data or nil
    return lib.igInputTextWithHint(label,hint,buf,buf_size,flags,callback,user_data)
end
function M.InvisibleButton(str_id,size,flags)
    flags = flags or 0
    return lib.igInvisibleButton(str_id,size,flags)
end
M.IsActiveIdUsingKey = lib.igIsActiveIdUsingKey
M.IsActiveIdUsingNavDir = lib.igIsActiveIdUsingNavDir
M.IsActiveIdUsingNavInput = lib.igIsActiveIdUsingNavInput
M.IsAnyItemActive = lib.igIsAnyItemActive
M.IsAnyItemFocused = lib.igIsAnyItemFocused
M.IsAnyItemHovered = lib.igIsAnyItemHovered
M.IsAnyMouseDown = lib.igIsAnyMouseDown
M.IsClippedEx = lib.igIsClippedEx
M.IsDragDropPayloadBeingAccepted = lib.igIsDragDropPayloadBeingAccepted
M.IsItemActivated = lib.igIsItemActivated
M.IsItemActive = lib.igIsItemActive
function M.IsItemClicked(mouse_button)
    mouse_button = mouse_button or 0
    return lib.igIsItemClicked(mouse_button)
end
M.IsItemDeactivated = lib.igIsItemDeactivated
M.IsItemDeactivatedAfterEdit = lib.igIsItemDeactivatedAfterEdit
M.IsItemEdited = lib.igIsItemEdited
M.IsItemFocused = lib.igIsItemFocused
function M.IsItemHovered(flags)
    flags = flags or 0
    return lib.igIsItemHovered(flags)
end
M.IsItemToggledOpen = lib.igIsItemToggledOpen
M.IsItemToggledSelection = lib.igIsItemToggledSelection
M.IsItemVisible = lib.igIsItemVisible
M.IsKeyDown = lib.igIsKeyDown
function M.IsKeyPressed(user_key_index,_repeat)
    if _repeat == nil then _repeat = true end
    return lib.igIsKeyPressed(user_key_index,_repeat)
end
function M.IsKeyPressedMap(key,_repeat)
    if _repeat == nil then _repeat = true end
    return lib.igIsKeyPressedMap(key,_repeat)
end
M.IsKeyReleased = lib.igIsKeyReleased
function M.IsMouseClicked(button,_repeat)
    _repeat = _repeat or false
    return lib.igIsMouseClicked(button,_repeat)
end
M.IsMouseDoubleClicked = lib.igIsMouseDoubleClicked
M.IsMouseDown = lib.igIsMouseDown
function M.IsMouseDragPastThreshold(button,lock_threshold)
    lock_threshold = lock_threshold or -1.0
    return lib.igIsMouseDragPastThreshold(button,lock_threshold)
end
function M.IsMouseDragging(button,lock_threshold)
    lock_threshold = lock_threshold or -1.0
    return lib.igIsMouseDragging(button,lock_threshold)
end
function M.IsMouseHoveringRect(r_min,r_max,clip)
    if clip == nil then clip = true end
    return lib.igIsMouseHoveringRect(r_min,r_max,clip)
end
function M.IsMousePosValid(mouse_pos)
    mouse_pos = mouse_pos or nil
    return lib.igIsMousePosValid(mouse_pos)
end
M.IsMouseReleased = lib.igIsMouseReleased
M.IsNavInputDown = lib.igIsNavInputDown
M.IsNavInputTest = lib.igIsNavInputTest
function M.IsPopupOpenStr(str_id,flags)
    flags = flags or 0
    return lib.igIsPopupOpenStr(str_id,flags)
end
M.IsPopupOpenID = lib.igIsPopupOpenID
function M.IsPopupOpen(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.IsPopupOpenStr(a1,a2) end
    if ffi.istype('ImGuiID',a1) then return M.IsPopupOpenID(a1,a2) end
    print(a1,a2)
    error'M.IsPopupOpen could not find overloaded'
end
M.IsRectVisibleNil = lib.igIsRectVisibleNil
M.IsRectVisibleVec2 = lib.igIsRectVisibleVec2
function M.IsRectVisible(a1,a2) -- generic version
    if a2==nil then return M.IsRectVisibleNil(a1) end
    if ffi.istype('const ImVec2',a2) then return M.IsRectVisibleVec2(a1,a2) end
    print(a1,a2)
    error'M.IsRectVisible could not find overloaded'
end
M.IsWindowAbove = lib.igIsWindowAbove
M.IsWindowAppearing = lib.igIsWindowAppearing
M.IsWindowChildOf = lib.igIsWindowChildOf
M.IsWindowCollapsed = lib.igIsWindowCollapsed
M.IsWindowDocked = lib.igIsWindowDocked
function M.IsWindowFocused(flags)
    flags = flags or 0
    return lib.igIsWindowFocused(flags)
end
function M.IsWindowHovered(flags)
    flags = flags or 0
    return lib.igIsWindowHovered(flags)
end
M.IsWindowNavFocusable = lib.igIsWindowNavFocusable
function M.ItemAdd(bb,id,nav_bb)
    nav_bb = nav_bb or nil
    return lib.igItemAdd(bb,id,nav_bb)
end
M.ItemHoverable = lib.igItemHoverable
function M.ItemSizeVec2(size,text_baseline_y)
    text_baseline_y = text_baseline_y or -1.0
    return lib.igItemSizeVec2(size,text_baseline_y)
end
function M.ItemSizeRect(bb,text_baseline_y)
    text_baseline_y = text_baseline_y or -1.0
    return lib.igItemSizeRect(bb,text_baseline_y)
end
function M.ItemSize(a1,a2) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.ItemSizeVec2(a1,a2) end
    if ffi.istype('const ImRect',a1) then return M.ItemSizeRect(a1,a2) end
    print(a1,a2)
    error'M.ItemSize could not find overloaded'
end
M.KeepAliveID = lib.igKeepAliveID
M.LabelText = lib.igLabelText
M.LabelTextV = lib.igLabelTextV
function M.ListBoxStr_arr(label,current_item,items,items_count,height_in_items)
    height_in_items = height_in_items or -1
    return lib.igListBoxStr_arr(label,current_item,items,items_count,height_in_items)
end
function M.ListBoxFnBoolPtr(label,current_item,items_getter,data,items_count,height_in_items)
    height_in_items = height_in_items or -1
    return lib.igListBoxFnBoolPtr(label,current_item,items_getter,data,items_count,height_in_items)
end
function M.ListBox(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('const char* const[]',a3) or ffi.istype('const char const[]',a3) or ffi.istype('const char const[][]',a3)) then return M.ListBoxStr_arr(a1,a2,a3,a4,a5) end
    if ffi.istype('bool(*)(void* data,int idx,const char** out_text)',a3) then return M.ListBoxFnBoolPtr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ListBox could not find overloaded'
end
M.LoadIniSettingsFromDisk = lib.igLoadIniSettingsFromDisk
function M.LoadIniSettingsFromMemory(ini_data,ini_size)
    ini_size = ini_size or 0
    return lib.igLoadIniSettingsFromMemory(ini_data,ini_size)
end
M.LogBegin = lib.igLogBegin
M.LogButtons = lib.igLogButtons
M.LogFinish = lib.igLogFinish
function M.LogRenderedText(ref_pos,text,text_end)
    text_end = text_end or nil
    return lib.igLogRenderedText(ref_pos,text,text_end)
end
M.LogSetNextTextDecoration = lib.igLogSetNextTextDecoration
M.LogText = lib.igLogText
function M.LogToBuffer(auto_open_depth)
    auto_open_depth = auto_open_depth or -1
    return lib.igLogToBuffer(auto_open_depth)
end
function M.LogToClipboard(auto_open_depth)
    auto_open_depth = auto_open_depth or -1
    return lib.igLogToClipboard(auto_open_depth)
end
function M.LogToFile(auto_open_depth,filename)
    auto_open_depth = auto_open_depth or -1
    filename = filename or nil
    return lib.igLogToFile(auto_open_depth,filename)
end
function M.LogToTTY(auto_open_depth)
    auto_open_depth = auto_open_depth or -1
    return lib.igLogToTTY(auto_open_depth)
end
M.MarkIniSettingsDirtyNil = lib.igMarkIniSettingsDirtyNil
M.MarkIniSettingsDirtyWindowPtr = lib.igMarkIniSettingsDirtyWindowPtr
function M.MarkIniSettingsDirty(a1) -- generic version
    if a1==nil then return M.MarkIniSettingsDirtyNil() end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.MarkIniSettingsDirtyWindowPtr(a1) end
    print(a1)
    error'M.MarkIniSettingsDirty could not find overloaded'
end
M.MarkItemEdited = lib.igMarkItemEdited
M.MemAlloc = lib.igMemAlloc
M.MemFree = lib.igMemFree
function M.MenuItemBool(label,shortcut,selected,enabled)
    if enabled == nil then enabled = true end
    selected = selected or false
    shortcut = shortcut or nil
    return lib.igMenuItemBool(label,shortcut,selected,enabled)
end
function M.MenuItemBoolPtr(label,shortcut,p_selected,enabled)
    if enabled == nil then enabled = true end
    return lib.igMenuItemBoolPtr(label,shortcut,p_selected,enabled)
end
function M.MenuItem(a1,a2,a3,a4) -- generic version
    if ((ffi.istype('bool',a3) or type(a3)=='boolean') or type(a3)=='nil') then return M.MenuItemBool(a1,a2,a3,a4) end
    if (ffi.istype('bool*',a3) or ffi.istype('bool',a3) or ffi.istype('bool[]',a3)) then return M.MenuItemBoolPtr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.MenuItem could not find overloaded'
end
M.NavInitWindow = lib.igNavInitWindow
M.NavMoveRequestButNoResultYet = lib.igNavMoveRequestButNoResultYet
M.NavMoveRequestCancel = lib.igNavMoveRequestCancel
M.NavMoveRequestForward = lib.igNavMoveRequestForward
M.NavMoveRequestTryWrapping = lib.igNavMoveRequestTryWrapping
M.NewFrame = lib.igNewFrame
M.NewLine = lib.igNewLine
M.NextColumn = lib.igNextColumn
function M.OpenPopup(str_id,popup_flags)
    popup_flags = popup_flags or 0
    return lib.igOpenPopup(str_id,popup_flags)
end
function M.OpenPopupEx(id,popup_flags)
    popup_flags = popup_flags or 0
    return lib.igOpenPopupEx(id,popup_flags)
end
function M.OpenPopupOnItemClick(str_id,popup_flags)
    popup_flags = popup_flags or 1
    str_id = str_id or nil
    return lib.igOpenPopupOnItemClick(str_id,popup_flags)
end
M.PlotEx = lib.igPlotEx
function M.PlotHistogramFloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
    graph_size = graph_size or ImVec2(0,0)
    overlay_text = overlay_text or nil
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    stride = stride or ffi.sizeof("float")
    values_offset = values_offset or 0
    return lib.igPlotHistogramFloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
end
function M.PlotHistogramFnFloatPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
    graph_size = graph_size or ImVec2(0,0)
    overlay_text = overlay_text or nil
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    values_offset = values_offset or 0
    return lib.igPlotHistogramFnFloatPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
end
function M.PlotHistogram(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) then return M.PlotHistogramFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.istype('float(*)(void* data,int idx)',a2) then return M.PlotHistogramFnFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.PlotHistogram could not find overloaded'
end
function M.PlotLinesFloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
    graph_size = graph_size or ImVec2(0,0)
    overlay_text = overlay_text or nil
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    stride = stride or ffi.sizeof("float")
    values_offset = values_offset or 0
    return lib.igPlotLinesFloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
end
function M.PlotLinesFnFloatPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
    graph_size = graph_size or ImVec2(0,0)
    overlay_text = overlay_text or nil
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    values_offset = values_offset or 0
    return lib.igPlotLinesFnFloatPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
end
function M.PlotLines(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('const float*',a2) or ffi.istype('float[]',a2)) then return M.PlotLinesFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.istype('float(*)(void* data,int idx)',a2) then return M.PlotLinesFnFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.PlotLines could not find overloaded'
end
M.PopAllowKeyboardFocus = lib.igPopAllowKeyboardFocus
M.PopButtonRepeat = lib.igPopButtonRepeat
M.PopClipRect = lib.igPopClipRect
M.PopColumnsBackground = lib.igPopColumnsBackground
M.PopFocusScope = lib.igPopFocusScope
M.PopFont = lib.igPopFont
M.PopID = lib.igPopID
M.PopItemFlag = lib.igPopItemFlag
M.PopItemWidth = lib.igPopItemWidth
function M.PopStyleColor(count)
    count = count or 1
    return lib.igPopStyleColor(count)
end
function M.PopStyleVar(count)
    count = count or 1
    return lib.igPopStyleVar(count)
end
M.PopTextWrapPos = lib.igPopTextWrapPos
function M.ProgressBar(fraction,size_arg,overlay)
    overlay = overlay or nil
    size_arg = size_arg or ImVec2(-M.FLT_MIN,0)
    return lib.igProgressBar(fraction,size_arg,overlay)
end
M.PushAllowKeyboardFocus = lib.igPushAllowKeyboardFocus
M.PushButtonRepeat = lib.igPushButtonRepeat
M.PushClipRect = lib.igPushClipRect
M.PushColumnClipRect = lib.igPushColumnClipRect
M.PushColumnsBackground = lib.igPushColumnsBackground
M.PushFocusScope = lib.igPushFocusScope
M.PushFont = lib.igPushFont
M.PushIDStr = lib.igPushIDStr
M.PushIDStrStr = lib.igPushIDStrStr
M.PushIDPtr = lib.igPushIDPtr
M.PushIDInt = lib.igPushIDInt
function M.PushID(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a2==nil then return M.PushIDStr(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.PushIDStrStr(a1,a2) end
    if ffi.istype('const void*',a1) then return M.PushIDPtr(a1) end
    if (ffi.istype('int',a1) or type(a1)=='number') then return M.PushIDInt(a1) end
    print(a1,a2)
    error'M.PushID could not find overloaded'
end
M.PushItemFlag = lib.igPushItemFlag
M.PushItemWidth = lib.igPushItemWidth
M.PushMultiItemsWidths = lib.igPushMultiItemsWidths
M.PushOverrideID = lib.igPushOverrideID
M.PushStyleColorU32 = lib.igPushStyleColorU32
M.PushStyleColorVec4 = lib.igPushStyleColorVec4
function M.PushStyleColor(a1,a2) -- generic version
    if (ffi.istype('ImU32',a2) or type(a2)=='number') then return M.PushStyleColorU32(a1,a2) end
    if ffi.istype('const ImVec4',a2) then return M.PushStyleColorVec4(a1,a2) end
    print(a1,a2)
    error'M.PushStyleColor could not find overloaded'
end
M.PushStyleVarFloat = lib.igPushStyleVarFloat
M.PushStyleVarVec2 = lib.igPushStyleVarVec2
function M.PushStyleVar(a1,a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.PushStyleVarFloat(a1,a2) end
    if ffi.istype('const ImVec2',a2) then return M.PushStyleVarVec2(a1,a2) end
    print(a1,a2)
    error'M.PushStyleVar could not find overloaded'
end
function M.PushTextWrapPos(wrap_local_pos_x)
    wrap_local_pos_x = wrap_local_pos_x or 0.0
    return lib.igPushTextWrapPos(wrap_local_pos_x)
end
M.RadioButtonBool = lib.igRadioButtonBool
M.RadioButtonIntPtr = lib.igRadioButtonIntPtr
function M.RadioButton(a1,a2,a3) -- generic version
    if (ffi.istype('bool',a2) or type(a2)=='boolean') then return M.RadioButtonBool(a1,a2) end
    if (ffi.istype('int*',a2) or ffi.istype('int[]',a2)) then return M.RadioButtonIntPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.RadioButton could not find overloaded'
end
M.RemoveContextHook = lib.igRemoveContextHook
M.Render = lib.igRender
function M.RenderArrow(draw_list,pos,col,dir,scale)
    scale = scale or 1.0
    return lib.igRenderArrow(draw_list,pos,col,dir,scale)
end
M.RenderArrowDockMenu = lib.igRenderArrowDockMenu
M.RenderArrowPointingAt = lib.igRenderArrowPointingAt
M.RenderBullet = lib.igRenderBullet
M.RenderCheckMark = lib.igRenderCheckMark
function M.RenderColorRectWithAlphaCheckerboard(draw_list,p_min,p_max,fill_col,grid_step,grid_off,rounding,rounding_corners_flags)
    rounding = rounding or 0.0
    rounding_corners_flags = rounding_corners_flags or -1
    return lib.igRenderColorRectWithAlphaCheckerboard(draw_list,p_min,p_max,fill_col,grid_step,grid_off,rounding,rounding_corners_flags)
end
function M.RenderFrame(p_min,p_max,fill_col,border,rounding)
    if border == nil then border = true end
    rounding = rounding or 0.0
    return lib.igRenderFrame(p_min,p_max,fill_col,border,rounding)
end
function M.RenderFrameBorder(p_min,p_max,rounding)
    rounding = rounding or 0.0
    return lib.igRenderFrameBorder(p_min,p_max,rounding)
end
M.RenderMouseCursor = lib.igRenderMouseCursor
function M.RenderNavHighlight(bb,id,flags)
    flags = flags or 1
    return lib.igRenderNavHighlight(bb,id,flags)
end
function M.RenderPlatformWindowsDefault(platform_render_arg,renderer_render_arg)
    platform_render_arg = platform_render_arg or nil
    renderer_render_arg = renderer_render_arg or nil
    return lib.igRenderPlatformWindowsDefault(platform_render_arg,renderer_render_arg)
end
M.RenderRectFilledRangeH = lib.igRenderRectFilledRangeH
M.RenderRectFilledWithHole = lib.igRenderRectFilledWithHole
function M.RenderText(pos,text,text_end,hide_text_after_hash)
    if hide_text_after_hash == nil then hide_text_after_hash = true end
    text_end = text_end or nil
    return lib.igRenderText(pos,text,text_end,hide_text_after_hash)
end
function M.RenderTextClipped(pos_min,pos_max,text,text_end,text_size_if_known,align,clip_rect)
    align = align or ImVec2(0,0)
    clip_rect = clip_rect or nil
    return lib.igRenderTextClipped(pos_min,pos_max,text,text_end,text_size_if_known,align,clip_rect)
end
function M.RenderTextClippedEx(draw_list,pos_min,pos_max,text,text_end,text_size_if_known,align,clip_rect)
    align = align or ImVec2(0,0)
    clip_rect = clip_rect or nil
    return lib.igRenderTextClippedEx(draw_list,pos_min,pos_max,text,text_end,text_size_if_known,align,clip_rect)
end
M.RenderTextEllipsis = lib.igRenderTextEllipsis
M.RenderTextWrapped = lib.igRenderTextWrapped
function M.ResetMouseDragDelta(button)
    button = button or 0
    return lib.igResetMouseDragDelta(button)
end
function M.SameLine(offset_from_start_x,spacing)
    offset_from_start_x = offset_from_start_x or 0.0
    spacing = spacing or -1.0
    return lib.igSameLine(offset_from_start_x,spacing)
end
M.SaveIniSettingsToDisk = lib.igSaveIniSettingsToDisk
function M.SaveIniSettingsToMemory(out_ini_size)
    out_ini_size = out_ini_size or nil
    return lib.igSaveIniSettingsToMemory(out_ini_size)
end
M.ScaleWindowsInViewport = lib.igScaleWindowsInViewport
function M.ScrollToBringRectIntoView(window,item_rect)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igScrollToBringRectIntoView(nonUDT_out,window,item_rect)
    return nonUDT_out
end
M.Scrollbar = lib.igScrollbar
M.ScrollbarEx = lib.igScrollbarEx
function M.SelectableBool(label,selected,flags,size)
    flags = flags or 0
    selected = selected or false
    size = size or ImVec2(0,0)
    return lib.igSelectableBool(label,selected,flags,size)
end
function M.SelectableBoolPtr(label,p_selected,flags,size)
    flags = flags or 0
    size = size or ImVec2(0,0)
    return lib.igSelectableBoolPtr(label,p_selected,flags,size)
end
function M.Selectable(a1,a2,a3,a4) -- generic version
    if ((ffi.istype('bool',a2) or type(a2)=='boolean') or type(a2)=='nil') then return M.SelectableBool(a1,a2,a3,a4) end
    if (ffi.istype('bool*',a2) or ffi.istype('bool',a2) or ffi.istype('bool[]',a2)) then return M.SelectableBoolPtr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.Selectable could not find overloaded'
end
M.Separator = lib.igSeparator
M.SeparatorEx = lib.igSeparatorEx
M.SetActiveID = lib.igSetActiveID
function M.SetAllocatorFunctions(alloc_func,free_func,user_data)
    user_data = user_data or nil
    return lib.igSetAllocatorFunctions(alloc_func,free_func,user_data)
end
M.SetClipboardText = lib.igSetClipboardText
M.SetColorEditOptions = lib.igSetColorEditOptions
M.SetColumnOffset = lib.igSetColumnOffset
M.SetColumnWidth = lib.igSetColumnWidth
M.SetCurrentContext = lib.igSetCurrentContext
M.SetCurrentFont = lib.igSetCurrentFont
M.SetCursorPos = lib.igSetCursorPos
M.SetCursorPosX = lib.igSetCursorPosX
M.SetCursorPosY = lib.igSetCursorPosY
M.SetCursorScreenPos = lib.igSetCursorScreenPos
function M.SetDragDropPayload(type,data,sz,cond)
    cond = cond or 0
    return lib.igSetDragDropPayload(type,data,sz,cond)
end
M.SetFocusID = lib.igSetFocusID
M.SetHoveredID = lib.igSetHoveredID
M.SetItemAllowOverlap = lib.igSetItemAllowOverlap
M.SetItemDefaultFocus = lib.igSetItemDefaultFocus
M.SetItemUsingMouseWheel = lib.igSetItemUsingMouseWheel
function M.SetKeyboardFocusHere(offset)
    offset = offset or 0
    return lib.igSetKeyboardFocusHere(offset)
end
M.SetLastItemData = lib.igSetLastItemData
M.SetMouseCursor = lib.igSetMouseCursor
M.SetNavID = lib.igSetNavID
M.SetNavIDWithRectRel = lib.igSetNavIDWithRectRel
function M.SetNextItemOpen(is_open,cond)
    cond = cond or 0
    return lib.igSetNextItemOpen(is_open,cond)
end
M.SetNextItemWidth = lib.igSetNextItemWidth
M.SetNextWindowBgAlpha = lib.igSetNextWindowBgAlpha
M.SetNextWindowClass = lib.igSetNextWindowClass
function M.SetNextWindowCollapsed(collapsed,cond)
    cond = cond or 0
    return lib.igSetNextWindowCollapsed(collapsed,cond)
end
M.SetNextWindowContentSize = lib.igSetNextWindowContentSize
function M.SetNextWindowDockID(dock_id,cond)
    cond = cond or 0
    return lib.igSetNextWindowDockID(dock_id,cond)
end
M.SetNextWindowFocus = lib.igSetNextWindowFocus
function M.SetNextWindowPos(pos,cond,pivot)
    cond = cond or 0
    pivot = pivot or ImVec2(0,0)
    return lib.igSetNextWindowPos(pos,cond,pivot)
end
M.SetNextWindowScroll = lib.igSetNextWindowScroll
function M.SetNextWindowSize(size,cond)
    cond = cond or 0
    return lib.igSetNextWindowSize(size,cond)
end
function M.SetNextWindowSizeConstraints(size_min,size_max,custom_callback,custom_callback_data)
    custom_callback = custom_callback or nil
    custom_callback_data = custom_callback_data or nil
    return lib.igSetNextWindowSizeConstraints(size_min,size_max,custom_callback,custom_callback_data)
end
M.SetNextWindowViewport = lib.igSetNextWindowViewport
function M.SetScrollFromPosXFloat(local_x,center_x_ratio)
    center_x_ratio = center_x_ratio or 0.5
    return lib.igSetScrollFromPosXFloat(local_x,center_x_ratio)
end
M.SetScrollFromPosXWindowPtr = lib.igSetScrollFromPosXWindowPtr
function M.SetScrollFromPosX(a1,a2,a3) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.SetScrollFromPosXFloat(a1,a2) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetScrollFromPosXWindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetScrollFromPosX could not find overloaded'
end
function M.SetScrollFromPosYFloat(local_y,center_y_ratio)
    center_y_ratio = center_y_ratio or 0.5
    return lib.igSetScrollFromPosYFloat(local_y,center_y_ratio)
end
M.SetScrollFromPosYWindowPtr = lib.igSetScrollFromPosYWindowPtr
function M.SetScrollFromPosY(a1,a2,a3) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.SetScrollFromPosYFloat(a1,a2) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetScrollFromPosYWindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetScrollFromPosY could not find overloaded'
end
function M.SetScrollHereX(center_x_ratio)
    center_x_ratio = center_x_ratio or 0.5
    return lib.igSetScrollHereX(center_x_ratio)
end
function M.SetScrollHereY(center_y_ratio)
    center_y_ratio = center_y_ratio or 0.5
    return lib.igSetScrollHereY(center_y_ratio)
end
M.SetScrollXFloat = lib.igSetScrollXFloat
M.SetScrollXWindowPtr = lib.igSetScrollXWindowPtr
function M.SetScrollX(a1,a2) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.SetScrollXFloat(a1) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetScrollXWindowPtr(a1,a2) end
    print(a1,a2)
    error'M.SetScrollX could not find overloaded'
end
M.SetScrollYFloat = lib.igSetScrollYFloat
M.SetScrollYWindowPtr = lib.igSetScrollYWindowPtr
function M.SetScrollY(a1,a2) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.SetScrollYFloat(a1) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetScrollYWindowPtr(a1,a2) end
    print(a1,a2)
    error'M.SetScrollY could not find overloaded'
end
M.SetStateStorage = lib.igSetStateStorage
M.SetTabItemClosed = lib.igSetTabItemClosed
M.SetTooltip = lib.igSetTooltip
M.SetTooltipV = lib.igSetTooltipV
M.SetWindowClipRectBeforeSetChannel = lib.igSetWindowClipRectBeforeSetChannel
function M.SetWindowCollapsedBool(collapsed,cond)
    cond = cond or 0
    return lib.igSetWindowCollapsedBool(collapsed,cond)
end
function M.SetWindowCollapsedStr(name,collapsed,cond)
    cond = cond or 0
    return lib.igSetWindowCollapsedStr(name,collapsed,cond)
end
function M.SetWindowCollapsedWindowPtr(window,collapsed,cond)
    cond = cond or 0
    return lib.igSetWindowCollapsedWindowPtr(window,collapsed,cond)
end
function M.SetWindowCollapsed(a1,a2,a3) -- generic version
    if (ffi.istype('bool',a1) or type(a1)=='boolean') then return M.SetWindowCollapsedBool(a1,a2) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.SetWindowCollapsedStr(a1,a2,a3) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetWindowCollapsedWindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetWindowCollapsed could not find overloaded'
end
M.SetWindowDock = lib.igSetWindowDock
M.SetWindowFocusNil = lib.igSetWindowFocusNil
M.SetWindowFocusStr = lib.igSetWindowFocusStr
function M.SetWindowFocus(a1) -- generic version
    if a1==nil then return M.SetWindowFocusNil() end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.SetWindowFocusStr(a1) end
    print(a1)
    error'M.SetWindowFocus could not find overloaded'
end
M.SetWindowFontScale = lib.igSetWindowFontScale
M.SetWindowHitTestHole = lib.igSetWindowHitTestHole
function M.SetWindowPosVec2(pos,cond)
    cond = cond or 0
    return lib.igSetWindowPosVec2(pos,cond)
end
function M.SetWindowPosStr(name,pos,cond)
    cond = cond or 0
    return lib.igSetWindowPosStr(name,pos,cond)
end
function M.SetWindowPosWindowPtr(window,pos,cond)
    cond = cond or 0
    return lib.igSetWindowPosWindowPtr(window,pos,cond)
end
function M.SetWindowPos(a1,a2,a3) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.SetWindowPosVec2(a1,a2) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.SetWindowPosStr(a1,a2,a3) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetWindowPosWindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetWindowPos could not find overloaded'
end
function M.SetWindowSizeVec2(size,cond)
    cond = cond or 0
    return lib.igSetWindowSizeVec2(size,cond)
end
function M.SetWindowSizeStr(name,size,cond)
    cond = cond or 0
    return lib.igSetWindowSizeStr(name,size,cond)
end
function M.SetWindowSizeWindowPtr(window,size,cond)
    cond = cond or 0
    return lib.igSetWindowSizeWindowPtr(window,size,cond)
end
function M.SetWindowSize(a1,a2,a3) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.SetWindowSizeVec2(a1,a2) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.SetWindowSizeStr(a1,a2,a3) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetWindowSizeWindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetWindowSize could not find overloaded'
end
M.ShadeVertsLinearColorGradientKeepAlpha = lib.igShadeVertsLinearColorGradientKeepAlpha
M.ShadeVertsLinearUV = lib.igShadeVertsLinearUV
function M.ShowAboutWindow(p_open)
    p_open = p_open or nil
    return lib.igShowAboutWindow(p_open)
end
function M.ShowDemoWindow(p_open)
    p_open = p_open or nil
    return lib.igShowDemoWindow(p_open)
end
M.ShowFontSelector = lib.igShowFontSelector
function M.ShowMetricsWindow(p_open)
    p_open = p_open or nil
    return lib.igShowMetricsWindow(p_open)
end
function M.ShowStyleEditor(ref)
    ref = ref or nil
    return lib.igShowStyleEditor(ref)
end
M.ShowStyleSelector = lib.igShowStyleSelector
M.ShowUserGuide = lib.igShowUserGuide
M.ShrinkWidths = lib.igShrinkWidths
M.Shutdown = lib.igShutdown
function M.SliderAngle(label,v_rad,v_degrees_min,v_degrees_max,format,flags)
    flags = flags or 0
    format = format or "%.0f deg"
    v_degrees_max = v_degrees_max or 360.0
    v_degrees_min = v_degrees_min or -360.0
    return lib.igSliderAngle(label,v_rad,v_degrees_min,v_degrees_max,format,flags)
end
M.SliderBehavior = lib.igSliderBehavior
function M.SliderFloat(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igSliderFloat(label,v,v_min,v_max,format,flags)
end
function M.SliderFloat2(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igSliderFloat2(label,v,v_min,v_max,format,flags)
end
function M.SliderFloat3(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igSliderFloat3(label,v,v_min,v_max,format,flags)
end
function M.SliderFloat4(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igSliderFloat4(label,v,v_min,v_max,format,flags)
end
function M.SliderInt(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    return lib.igSliderInt(label,v,v_min,v_max,format,flags)
end
function M.SliderInt2(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    return lib.igSliderInt2(label,v,v_min,v_max,format,flags)
end
function M.SliderInt3(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    return lib.igSliderInt3(label,v,v_min,v_max,format,flags)
end
function M.SliderInt4(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    return lib.igSliderInt4(label,v,v_min,v_max,format,flags)
end
function M.SliderScalar(label,data_type,p_data,p_min,p_max,format,flags)
    flags = flags or 0
    format = format or nil
    return lib.igSliderScalar(label,data_type,p_data,p_min,p_max,format,flags)
end
function M.SliderScalarN(label,data_type,p_data,components,p_min,p_max,format,flags)
    flags = flags or 0
    format = format or nil
    return lib.igSliderScalarN(label,data_type,p_data,components,p_min,p_max,format,flags)
end
M.SmallButton = lib.igSmallButton
M.Spacing = lib.igSpacing
function M.SplitterBehavior(bb,id,axis,size1,size2,min_size1,min_size2,hover_extend,hover_visibility_delay)
    hover_extend = hover_extend or 0.0
    hover_visibility_delay = hover_visibility_delay or 0.0
    return lib.igSplitterBehavior(bb,id,axis,size1,size2,min_size1,min_size2,hover_extend,hover_visibility_delay)
end
M.StartMouseMovingWindow = lib.igStartMouseMovingWindow
M.StartMouseMovingWindowOrNode = lib.igStartMouseMovingWindowOrNode
function M.StyleColorsClassic(dst)
    dst = dst or nil
    return lib.igStyleColorsClassic(dst)
end
function M.StyleColorsDark(dst)
    dst = dst or nil
    return lib.igStyleColorsDark(dst)
end
function M.StyleColorsLight(dst)
    dst = dst or nil
    return lib.igStyleColorsLight(dst)
end
M.TabBarAddTab = lib.igTabBarAddTab
M.TabBarCloseTab = lib.igTabBarCloseTab
M.TabBarFindMostRecentlySelectedTabForActiveWindow = lib.igTabBarFindMostRecentlySelectedTabForActiveWindow
M.TabBarFindTabByID = lib.igTabBarFindTabByID
M.TabBarProcessReorder = lib.igTabBarProcessReorder
M.TabBarQueueReorder = lib.igTabBarQueueReorder
M.TabBarRemoveTab = lib.igTabBarRemoveTab
M.TabItemBackground = lib.igTabItemBackground
function M.TabItemButton(label,flags)
    flags = flags or 0
    return lib.igTabItemButton(label,flags)
end
function M.TabItemCalcSize(label,has_close_button)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igTabItemCalcSize(nonUDT_out,label,has_close_button)
    return nonUDT_out
end
M.TabItemEx = lib.igTabItemEx
M.TabItemLabelAndCloseButton = lib.igTabItemLabelAndCloseButton
M.TableBeginApplyRequests = lib.igTableBeginApplyRequests
M.TableBeginCell = lib.igTableBeginCell
M.TableBeginInitMemory = lib.igTableBeginInitMemory
M.TableBeginRow = lib.igTableBeginRow
M.TableDrawBorders = lib.igTableDrawBorders
M.TableDrawContextMenu = lib.igTableDrawContextMenu
M.TableEndCell = lib.igTableEndCell
M.TableEndRow = lib.igTableEndRow
M.TableFindByID = lib.igTableFindByID
M.TableFixColumnSortDirection = lib.igTableFixColumnSortDirection
M.TableGcCompactSettings = lib.igTableGcCompactSettings
M.TableGcCompactTransientBuffers = lib.igTableGcCompactTransientBuffers
M.TableGetBoundSettings = lib.igTableGetBoundSettings
function M.TableGetCellBgRect(table,column_n)
    local nonUDT_out = ffi.new("ImRect")
    lib.igTableGetCellBgRect(nonUDT_out,table,column_n)
    return nonUDT_out
end
M.TableGetColumnCount = lib.igTableGetColumnCount
function M.TableGetColumnFlags(column_n)
    column_n = column_n or -1
    return lib.igTableGetColumnFlags(column_n)
end
M.TableGetColumnIndex = lib.igTableGetColumnIndex
function M.TableGetColumnNameInt(column_n)
    column_n = column_n or -1
    return lib.igTableGetColumnNameInt(column_n)
end
M.TableGetColumnNameTablePtr = lib.igTableGetColumnNameTablePtr
function M.TableGetColumnName(a1,a2) -- generic version
    if ((ffi.istype('int',a1) or type(a1)=='number') or type(a1)=='nil') then return M.TableGetColumnNameInt(a1) end
    if (ffi.istype('const ImGuiTable*',a1) or ffi.istype('const ImGuiTable',a1) or ffi.istype('const ImGuiTable[]',a1)) then return M.TableGetColumnNameTablePtr(a1,a2) end
    print(a1,a2)
    error'M.TableGetColumnName could not find overloaded'
end
M.TableGetColumnNextSortDirection = lib.igTableGetColumnNextSortDirection
function M.TableGetColumnResizeID(table,column_n,instance_no)
    instance_no = instance_no or 0
    return lib.igTableGetColumnResizeID(table,column_n,instance_no)
end
M.TableGetColumnWidthAuto = lib.igTableGetColumnWidthAuto
M.TableGetHeaderRowHeight = lib.igTableGetHeaderRowHeight
M.TableGetHoveredColumn = lib.igTableGetHoveredColumn
M.TableGetMaxColumnWidth = lib.igTableGetMaxColumnWidth
M.TableGetRowIndex = lib.igTableGetRowIndex
M.TableGetSortSpecs = lib.igTableGetSortSpecs
M.TableHeader = lib.igTableHeader
M.TableHeadersRow = lib.igTableHeadersRow
M.TableLoadSettings = lib.igTableLoadSettings
M.TableMergeDrawChannels = lib.igTableMergeDrawChannels
M.TableNextColumn = lib.igTableNextColumn
function M.TableNextRow(row_flags,min_row_height)
    min_row_height = min_row_height or 0.0
    row_flags = row_flags or 0
    return lib.igTableNextRow(row_flags,min_row_height)
end
function M.TableOpenContextMenu(column_n)
    column_n = column_n or -1
    return lib.igTableOpenContextMenu(column_n)
end
M.TablePopBackgroundChannel = lib.igTablePopBackgroundChannel
M.TablePushBackgroundChannel = lib.igTablePushBackgroundChannel
M.TableRemove = lib.igTableRemove
M.TableResetSettings = lib.igTableResetSettings
M.TableSaveSettings = lib.igTableSaveSettings
function M.TableSetBgColor(target,color,column_n)
    column_n = column_n or -1
    return lib.igTableSetBgColor(target,color,column_n)
end
M.TableSetColumnEnabled = lib.igTableSetColumnEnabled
M.TableSetColumnIndex = lib.igTableSetColumnIndex
M.TableSetColumnSortDirection = lib.igTableSetColumnSortDirection
M.TableSetColumnWidth = lib.igTableSetColumnWidth
M.TableSetColumnWidthAutoAll = lib.igTableSetColumnWidthAutoAll
M.TableSetColumnWidthAutoSingle = lib.igTableSetColumnWidthAutoSingle
M.TableSettingsCreate = lib.igTableSettingsCreate
M.TableSettingsFindByID = lib.igTableSettingsFindByID
M.TableSettingsInstallHandler = lib.igTableSettingsInstallHandler
function M.TableSetupColumn(label,flags,init_width_or_weight,user_id)
    flags = flags or 0
    init_width_or_weight = init_width_or_weight or 0.0
    user_id = user_id or 0
    return lib.igTableSetupColumn(label,flags,init_width_or_weight,user_id)
end
M.TableSetupDrawChannels = lib.igTableSetupDrawChannels
M.TableSetupScrollFreeze = lib.igTableSetupScrollFreeze
M.TableSortSpecsBuild = lib.igTableSortSpecsBuild
M.TableSortSpecsSanitize = lib.igTableSortSpecsSanitize
M.TableUpdateBorders = lib.igTableUpdateBorders
M.TableUpdateColumnsWeightFromWidth = lib.igTableUpdateColumnsWeightFromWidth
M.TableUpdateLayout = lib.igTableUpdateLayout
M.TempInputIsActive = lib.igTempInputIsActive
function M.TempInputScalar(bb,id,label,data_type,p_data,format,p_clamp_min,p_clamp_max)
    p_clamp_max = p_clamp_max or nil
    p_clamp_min = p_clamp_min or nil
    return lib.igTempInputScalar(bb,id,label,data_type,p_data,format,p_clamp_min,p_clamp_max)
end
M.TempInputText = lib.igTempInputText
M.Text = lib.igText
M.TextColored = lib.igTextColored
M.TextColoredV = lib.igTextColoredV
M.TextDisabled = lib.igTextDisabled
M.TextDisabledV = lib.igTextDisabledV
function M.TextEx(text,text_end,flags)
    flags = flags or 0
    text_end = text_end or nil
    return lib.igTextEx(text,text_end,flags)
end
function M.TextUnformatted(text,text_end)
    text_end = text_end or nil
    return lib.igTextUnformatted(text,text_end)
end
M.TextV = lib.igTextV
M.TextWrapped = lib.igTextWrapped
M.TextWrappedV = lib.igTextWrappedV
M.TranslateWindowsInViewport = lib.igTranslateWindowsInViewport
M.TreeNodeStr = lib.igTreeNodeStr
M.TreeNodeStrStr = lib.igTreeNodeStrStr
M.TreeNodePtr = lib.igTreeNodePtr
function M.TreeNode(a1,a2,...) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a2==nil then return M.TreeNodeStr(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.TreeNodeStrStr(a1,a2,...) end
    if ffi.istype('const void*',a1) then return M.TreeNodePtr(a1,a2,...) end
    print(a1,a2,...)
    error'M.TreeNode could not find overloaded'
end
function M.TreeNodeBehavior(id,flags,label,label_end)
    label_end = label_end or nil
    return lib.igTreeNodeBehavior(id,flags,label,label_end)
end
function M.TreeNodeBehaviorIsOpen(id,flags)
    flags = flags or 0
    return lib.igTreeNodeBehaviorIsOpen(id,flags)
end
function M.TreeNodeExStr(label,flags)
    flags = flags or 0
    return lib.igTreeNodeExStr(label,flags)
end
M.TreeNodeExStrStr = lib.igTreeNodeExStrStr
M.TreeNodeExPtr = lib.igTreeNodeExPtr
function M.TreeNodeEx(a1,a2,a3,...) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a3==nil then return M.TreeNodeExStr(a1,a2) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.TreeNodeExStrStr(a1,a2,a3,...) end
    if ffi.istype('const void*',a1) then return M.TreeNodeExPtr(a1,a2,a3,...) end
    print(a1,a2,a3,...)
    error'M.TreeNodeEx could not find overloaded'
end
M.TreeNodeExVStr = lib.igTreeNodeExVStr
M.TreeNodeExVPtr = lib.igTreeNodeExVPtr
function M.TreeNodeExV(a1,a2,a3,a4) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.TreeNodeExVStr(a1,a2,a3,a4) end
    if ffi.istype('const void*',a1) then return M.TreeNodeExVPtr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.TreeNodeExV could not find overloaded'
end
M.TreeNodeVStr = lib.igTreeNodeVStr
M.TreeNodeVPtr = lib.igTreeNodeVPtr
function M.TreeNodeV(a1,a2,a3) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.TreeNodeVStr(a1,a2,a3) end
    if ffi.istype('const void*',a1) then return M.TreeNodeVPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.TreeNodeV could not find overloaded'
end
M.TreePop = lib.igTreePop
M.TreePushStr = lib.igTreePushStr
function M.TreePushPtr(ptr_id)
    ptr_id = ptr_id or nil
    return lib.igTreePushPtr(ptr_id)
end
function M.TreePush(a1) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.TreePushStr(a1) end
    if (ffi.istype('const void*',a1) or type(a1)=='nil') then return M.TreePushPtr(a1) end
    print(a1)
    error'M.TreePush could not find overloaded'
end
M.TreePushOverrideID = lib.igTreePushOverrideID
function M.Unindent(indent_w)
    indent_w = indent_w or 0.0
    return lib.igUnindent(indent_w)
end
M.UpdateHoveredWindowAndCaptureFlags = lib.igUpdateHoveredWindowAndCaptureFlags
M.UpdateMouseMovingWindowEndFrame = lib.igUpdateMouseMovingWindowEndFrame
M.UpdateMouseMovingWindowNewFrame = lib.igUpdateMouseMovingWindowNewFrame
M.UpdatePlatformWindows = lib.igUpdatePlatformWindows
M.UpdateWindowParentAndRootLinks = lib.igUpdateWindowParentAndRootLinks
function M.VSliderFloat(label,size,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igVSliderFloat(label,size,v,v_min,v_max,format,flags)
end
function M.VSliderInt(label,size,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    return lib.igVSliderInt(label,size,v,v_min,v_max,format,flags)
end
function M.VSliderScalar(label,size,data_type,p_data,p_min,p_max,format,flags)
    flags = flags or 0
    format = format or nil
    return lib.igVSliderScalar(label,size,data_type,p_data,p_min,p_max,format,flags)
end
M.ValueBool = lib.igValueBool
M.ValueInt = lib.igValueInt
M.ValueUint = lib.igValueUint
function M.ValueFloat(prefix,v,float_format)
    float_format = float_format or nil
    return lib.igValueFloat(prefix,v,float_format)
end
function M.Value(a1,a2,a3) -- generic version
    if (ffi.istype('bool',a2) or type(a2)=='boolean') then return M.ValueBool(a1,a2) end
    if (ffi.istype('int',a2) or type(a2)=='number') then return M.ValueInt(a1,a2) end
    if ffi.istype('unsigned int',a2) then return M.ValueUint(a1,a2) end
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.ValueFloat(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.Value could not find overloaded'
end
function M.gizmo3DquatPtrFloat(noname1,noname2,noname3,noname4)
    noname4 = noname4 or 257
    return lib.iggizmo3DquatPtrFloat(noname1,noname2,noname3,noname4)
end
function M.gizmo3Dvec4Ptr(noname1,noname2,noname3,noname4)
    noname4 = noname4 or 257
    return lib.iggizmo3Dvec4Ptr(noname1,noname2,noname3,noname4)
end
function M.gizmo3Dvec3PtrFloat(noname1,noname2,noname3,noname4)
    noname4 = noname4 or 2
    return lib.iggizmo3Dvec3PtrFloat(noname1,noname2,noname3,noname4)
end
function M.gizmo3DquatPtrquatPtr(noname1,noname2,noname3,noname4,noname5)
    noname5 = noname5 or 264
    return lib.iggizmo3DquatPtrquatPtr(noname1,noname2,noname3,noname4,noname5)
end
function M.gizmo3DquatPtrvec4Ptr(noname1,noname2,noname3,noname4,noname5)
    noname5 = noname5 or 264
    return lib.iggizmo3DquatPtrvec4Ptr(noname1,noname2,noname3,noname4,noname5)
end
function M.gizmo3DquatPtrvec3Ptr(noname1,noname2,noname3,noname4,noname5)
    noname5 = noname5 or 264
    return lib.iggizmo3DquatPtrvec3Ptr(noname1,noname2,noname3,noname4,noname5)
end
function M.gizmo3Dvec3PtrquatPtrFloat(noname1,noname2,noname3,noname4,noname5)
    noname5 = noname5 or 257
    return lib.iggizmo3Dvec3PtrquatPtrFloat(noname1,noname2,noname3,noname4,noname5)
end
function M.gizmo3Dvec3Ptrvec4Ptr(noname1,noname2,noname3,noname4,noname5)
    noname5 = noname5 or 257
    return lib.iggizmo3Dvec3Ptrvec4Ptr(noname1,noname2,noname3,noname4,noname5)
end
function M.gizmo3Dvec3Ptrvec3Ptr(noname1,noname2,noname3,noname4,noname5)
    noname5 = noname5 or 2
    return lib.iggizmo3Dvec3Ptrvec3Ptr(noname1,noname2,noname3,noname4,noname5)
end
function M.gizmo3Dvec3PtrquatPtrquatPtr(noname1,noname2,noname3,noname4,noname5,noname6)
    noname6 = noname6 or 264
    return lib.iggizmo3Dvec3PtrquatPtrquatPtr(noname1,noname2,noname3,noname4,noname5,noname6)
end
function M.gizmo3Dvec3PtrquatPtrvec4Ptr(noname1,noname2,noname3,noname4,noname5,noname6)
    noname6 = noname6 or 264
    return lib.iggizmo3Dvec3PtrquatPtrvec4Ptr(noname1,noname2,noname3,noname4,noname5,noname6)
end
function M.gizmo3Dvec3PtrquatPtrvec3Ptr(noname1,noname2,noname3,noname4,noname5,noname6)
    noname6 = noname6 or 264
    return lib.iggizmo3Dvec3PtrquatPtrvec3Ptr(noname1,noname2,noname3,noname4,noname5,noname6)
end
function M.gizmo3D(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('quat*',a2) or ffi.istype('quat',a2) or ffi.istype('quat[]',a2)) and (ffi.istype('float',a3) or type(a3)=='number') and ((ffi.istype('const int',a4) or type(a4)=='number') or type(a4)=='nil') and a5==nil then return M.gizmo3DquatPtrFloat(a1,a2,a3,a4) end
    if (ffi.istype('G3Dvec4*',a2) or ffi.istype('G3Dvec4',a2) or ffi.istype('G3Dvec4[]',a2)) then return M.gizmo3Dvec4Ptr(a1,a2,a3,a4) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('float',a3) or type(a3)=='number') and ((ffi.istype('const int',a4) or type(a4)=='number') or type(a4)=='nil') and a5==nil then return M.gizmo3Dvec3PtrFloat(a1,a2,a3,a4) end
    if (ffi.istype('quat*',a2) or ffi.istype('quat',a2) or ffi.istype('quat[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('const int',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3DquatPtrquatPtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('quat*',a2) or ffi.istype('quat',a2) or ffi.istype('quat[]',a2)) and (ffi.istype('G3Dvec4*',a3) or ffi.istype('G3Dvec4',a3) or ffi.istype('G3Dvec4[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('const int',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3DquatPtrvec4Ptr(a1,a2,a3,a4,a5) end
    if (ffi.istype('quat*',a2) or ffi.istype('quat',a2) or ffi.istype('quat[]',a2)) and (ffi.istype('G3Dvec3*',a3) or ffi.istype('G3Dvec3',a3) or ffi.istype('G3Dvec3[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('const int',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3DquatPtrvec3Ptr(a1,a2,a3,a4,a5) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('const int',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3Dvec3PtrquatPtrFloat(a1,a2,a3,a4,a5) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('G3Dvec4*',a3) or ffi.istype('G3Dvec4',a3) or ffi.istype('G3Dvec4[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('const int',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3Dvec3Ptrvec4Ptr(a1,a2,a3,a4,a5) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('G3Dvec3*',a3) or ffi.istype('G3Dvec3',a3) or ffi.istype('G3Dvec3[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('const int',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3Dvec3Ptrvec3Ptr(a1,a2,a3,a4,a5) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('quat*',a4) or ffi.istype('quat',a4) or ffi.istype('quat[]',a4)) then return M.gizmo3Dvec3PtrquatPtrquatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('G3Dvec4*',a4) or ffi.istype('G3Dvec4',a4) or ffi.istype('G3Dvec4[]',a4)) then return M.gizmo3Dvec3PtrquatPtrvec4Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('G3Dvec3*',a4) or ffi.istype('G3Dvec3',a4) or ffi.istype('G3Dvec3[]',a4)) then return M.gizmo3Dvec3PtrquatPtrvec3Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.gizmo3D could not find overloaded'
end
function M.imnodes_BeginInputAttribute(id,shape)
    shape = shape or 1
    return lib.imnodes_BeginInputAttribute(id,shape)
end
M.imnodes_BeginNode = lib.imnodes_BeginNode
M.imnodes_BeginNodeEditor = lib.imnodes_BeginNodeEditor
M.imnodes_BeginNodeTitleBar = lib.imnodes_BeginNodeTitleBar
function M.imnodes_BeginOutputAttribute(id,shape)
    shape = shape or 1
    return lib.imnodes_BeginOutputAttribute(id,shape)
end
M.imnodes_BeginStaticAttribute = lib.imnodes_BeginStaticAttribute
M.imnodes_ClearLinkSelection = lib.imnodes_ClearLinkSelection
M.imnodes_ClearNodeSelection = lib.imnodes_ClearNodeSelection
M.imnodes_EditorContextCreate = lib.imnodes_EditorContextCreate
M.imnodes_EditorContextFree = lib.imnodes_EditorContextFree
function M.imnodes_EditorContextGetPanning()
    local nonUDT_out = ffi.new("ImVec2")
    lib.imnodes_EditorContextGetPanning(nonUDT_out)
    return nonUDT_out
end
M.imnodes_EditorContextMoveToNode = lib.imnodes_EditorContextMoveToNode
M.imnodes_EditorContextResetPanning = lib.imnodes_EditorContextResetPanning
M.imnodes_EditorContextSet = lib.imnodes_EditorContextSet
M.imnodes_EndInputAttribute = lib.imnodes_EndInputAttribute
M.imnodes_EndNode = lib.imnodes_EndNode
M.imnodes_EndNodeEditor = lib.imnodes_EndNodeEditor
M.imnodes_EndNodeTitleBar = lib.imnodes_EndNodeTitleBar
M.imnodes_EndOutputAttribute = lib.imnodes_EndOutputAttribute
M.imnodes_EndStaticAttribute = lib.imnodes_EndStaticAttribute
M.imnodes_GetIO = lib.imnodes_GetIO
function M.imnodes_GetNodeDimensions(id)
    local nonUDT_out = ffi.new("ImVec2")
    lib.imnodes_GetNodeDimensions(nonUDT_out,id)
    return nonUDT_out
end
function M.imnodes_GetNodeEditorSpacePos(node_id)
    local nonUDT_out = ffi.new("ImVec2")
    lib.imnodes_GetNodeEditorSpacePos(nonUDT_out,node_id)
    return nonUDT_out
end
function M.imnodes_GetNodeGridSpacePos(node_id)
    local nonUDT_out = ffi.new("ImVec2")
    lib.imnodes_GetNodeGridSpacePos(nonUDT_out,node_id)
    return nonUDT_out
end
function M.imnodes_GetNodeScreenSpacePos(node_id)
    local nonUDT_out = ffi.new("ImVec2")
    lib.imnodes_GetNodeScreenSpacePos(nonUDT_out,node_id)
    return nonUDT_out
end
M.imnodes_GetSelectedLinks = lib.imnodes_GetSelectedLinks
M.imnodes_GetSelectedNodes = lib.imnodes_GetSelectedNodes
M.imnodes_GetStyle = lib.imnodes_GetStyle
M.imnodes_Initialize = lib.imnodes_Initialize
function M.imnodes_IsAnyAttributeActive(attribute_id)
    attribute_id = attribute_id or nil
    return lib.imnodes_IsAnyAttributeActive(attribute_id)
end
M.imnodes_IsAttributeActive = lib.imnodes_IsAttributeActive
M.imnodes_IsEditorHovered = lib.imnodes_IsEditorHovered
function M.imnodes_IsLinkCreatedBoolPtr(started_at_attribute_id,ended_at_attribute_id,created_from_snap)
    created_from_snap = created_from_snap or nil
    return lib.imnodes_IsLinkCreatedBoolPtr(started_at_attribute_id,ended_at_attribute_id,created_from_snap)
end
function M.imnodes_IsLinkCreatedIntPtr(started_at_node_id,started_at_attribute_id,ended_at_node_id,ended_at_attribute_id,created_from_snap)
    created_from_snap = created_from_snap or nil
    return lib.imnodes_IsLinkCreatedIntPtr(started_at_node_id,started_at_attribute_id,ended_at_node_id,ended_at_attribute_id,created_from_snap)
end
function M.imnodes_IsLinkCreated(a1,a2,a3,a4,a5) -- generic version
    if ((ffi.istype('bool*',a3) or ffi.istype('bool',a3) or ffi.istype('bool[]',a3)) or type(a3)=='nil') then return M.imnodes_IsLinkCreatedBoolPtr(a1,a2,a3) end
    if (ffi.istype('int*',a3) or ffi.istype('int[]',a3)) then return M.imnodes_IsLinkCreatedIntPtr(a1,a2,a3,a4,a5) end
    print(a1,a2,a3,a4,a5)
    error'M.imnodes_IsLinkCreated could not find overloaded'
end
M.imnodes_IsLinkDestroyed = lib.imnodes_IsLinkDestroyed
function M.imnodes_IsLinkDropped(started_at_attribute_id,including_detached_links)
    if including_detached_links == nil then including_detached_links = true end
    started_at_attribute_id = started_at_attribute_id or nil
    return lib.imnodes_IsLinkDropped(started_at_attribute_id,including_detached_links)
end
M.imnodes_IsLinkHovered = lib.imnodes_IsLinkHovered
M.imnodes_IsLinkStarted = lib.imnodes_IsLinkStarted
M.imnodes_IsNodeHovered = lib.imnodes_IsNodeHovered
M.imnodes_IsPinHovered = lib.imnodes_IsPinHovered
M.imnodes_Link = lib.imnodes_Link
M.imnodes_LoadCurrentEditorStateFromIniFile = lib.imnodes_LoadCurrentEditorStateFromIniFile
M.imnodes_LoadCurrentEditorStateFromIniString = lib.imnodes_LoadCurrentEditorStateFromIniString
M.imnodes_LoadEditorStateFromIniFile = lib.imnodes_LoadEditorStateFromIniFile
M.imnodes_LoadEditorStateFromIniString = lib.imnodes_LoadEditorStateFromIniString
M.imnodes_NumSelectedLinks = lib.imnodes_NumSelectedLinks
M.imnodes_NumSelectedNodes = lib.imnodes_NumSelectedNodes
M.imnodes_PopAttributeFlag = lib.imnodes_PopAttributeFlag
M.imnodes_PopColorStyle = lib.imnodes_PopColorStyle
M.imnodes_PopStyleVar = lib.imnodes_PopStyleVar
M.imnodes_PushAttributeFlag = lib.imnodes_PushAttributeFlag
M.imnodes_PushColorStyle = lib.imnodes_PushColorStyle
M.imnodes_PushStyleVar = lib.imnodes_PushStyleVar
M.imnodes_SaveCurrentEditorStateToIniFile = lib.imnodes_SaveCurrentEditorStateToIniFile
function M.imnodes_SaveCurrentEditorStateToIniString(data_size)
    data_size = data_size or nil
    return lib.imnodes_SaveCurrentEditorStateToIniString(data_size)
end
M.imnodes_SaveEditorStateToIniFile = lib.imnodes_SaveEditorStateToIniFile
function M.imnodes_SaveEditorStateToIniString(editor,data_size)
    data_size = data_size or nil
    return lib.imnodes_SaveEditorStateToIniString(editor,data_size)
end
M.imnodes_SetNodeDraggable = lib.imnodes_SetNodeDraggable
M.imnodes_SetNodeEditorSpacePos = lib.imnodes_SetNodeEditorSpacePos
M.imnodes_SetNodeGridSpacePos = lib.imnodes_SetNodeGridSpacePos
M.imnodes_SetNodeScreenSpacePos = lib.imnodes_SetNodeScreenSpacePos
M.imnodes_Shutdown = lib.imnodes_Shutdown
M.imnodes_StyleColorsClassic = lib.imnodes_StyleColorsClassic
M.imnodes_StyleColorsDark = lib.imnodes_StyleColorsDark
M.imnodes_StyleColorsLight = lib.imnodes_StyleColorsLight
return M
----------END_AUTOGENERATED_LUA-----------------------------