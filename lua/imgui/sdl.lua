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
local ImStrv
if pcall(function() local a = ffi.new("ImStrv")end) then

ImStrv= {}
function ImStrv.__new(ctype,a,b)
	b = b or ffi.new("const char*",a) + (a and #a or 0)
	return ffi.new(ctype,a,b)
end
function ImStrv.__tostring(is)
	return is.Begin~=nil and ffi.string(is.Begin,is.End~=nil and is.End-is.Begin or nil) or nil
end
ImStrv.__index = ImStrv
ImStrv = ffi.metatype("ImStrv",ImStrv)

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
	__len = function(a) return math.sqrt(a.x*a.x+a.y*a.y) end,
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
local M = {ImVec2 = ImVec2, ImVec4 = ImVec4 , ImStrv = ImStrv, lib = lib}

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


function ImGui_ImplGlfwGL3.__new()
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
    return setmetatable({ctx = lib.igCreateContext(nil)},Imgui_Impl_SDL_opengl3)
end

function Imgui_Impl_SDL_opengl3:Init(window, gl_context, glsl_version)
    self.window = window
	glsl_version = glsl_version or "#version 130"
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
    lib.ImGui_ImplSDL2_NewFrame();
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
    lib.ImGui_ImplSDL2_NewFrame();
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
    return setmetatable({ctx = lib.igCreateContext(nil)},Imgui_Impl_glfw_opengl3)
end

function Imgui_Impl_glfw_opengl3:Init(window, install_callbacks,glsl_version)
	glsl_version = glsl_version or "#version 130"
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
function M.U32(a,b,c,d) return lib.igGetColorU32_Vec4(ImVec4(a,b,c,d or 1)) end

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
function ImColor.ImColor_Nil()
    local ptr = lib.ImColor_ImColor_Nil()
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.ImColor_Float(r,g,b,a)
    if a == nil then a = 1.0 end
    local ptr = lib.ImColor_ImColor_Float(r,g,b,a)
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.ImColor_Vec4(col)
    local ptr = lib.ImColor_ImColor_Vec4(col)
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.ImColor_Int(r,g,b,a)
    if a == nil then a = 255 end
    local ptr = lib.ImColor_ImColor_Int(r,g,b,a)
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.ImColor_U32(rgba)
    local ptr = lib.ImColor_ImColor_U32(rgba)
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImColor.ImColor_Nil() end
    if (ffi.istype('float',a1) or type(a1)=='number') then return ImColor.ImColor_Float(a1,a2,a3,a4) end
    if ffi.istype('const ImVec4',a1) then return ImColor.ImColor_Vec4(a1) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return ImColor.ImColor_Int(a1,a2,a3,a4) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return ImColor.ImColor_U32(a1) end
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
ImDrawCmd.GetTexID = lib.ImDrawCmd_GetTexID
function ImDrawCmd.__new(ctype)
    local ptr = lib.ImDrawCmd_ImDrawCmd()
    return ffi.gc(ptr,lib.ImDrawCmd_destroy)
end
M.ImDrawCmd = ffi.metatype("ImDrawCmd",ImDrawCmd)
--------------------------ImDrawData----------------------------
local ImDrawData= {}
ImDrawData.__index = ImDrawData
ImDrawData.AddDrawList = lib.ImDrawData_AddDrawList
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
function ImDrawDataBuilder.__new(ctype)
    local ptr = lib.ImDrawDataBuilder_ImDrawDataBuilder()
    return ffi.gc(ptr,lib.ImDrawDataBuilder_destroy)
end
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
function ImDrawList:AddEllipse(center,radius_x,radius_y,col,rot,num_segments,thickness)
    num_segments = num_segments or 0
    rot = rot or 0.0
    thickness = thickness or 1.0
    return lib.ImDrawList_AddEllipse(self,center,radius_x,radius_y,col,rot,num_segments,thickness)
end
function ImDrawList:AddEllipseFilled(center,radius_x,radius_y,col,rot,num_segments)
    num_segments = num_segments or 0
    rot = rot or 0.0
    return lib.ImDrawList_AddEllipseFilled(self,center,radius_x,radius_y,col,rot,num_segments)
end
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
function ImDrawList:AddImageRounded(user_texture_id,p_min,p_max,uv_min,uv_max,col,rounding,flags)
    flags = flags or 0
    return lib.ImDrawList_AddImageRounded(self,user_texture_id,p_min,p_max,uv_min,uv_max,col,rounding,flags)
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
function ImDrawList:AddRect(p_min,p_max,col,rounding,flags,thickness)
    flags = flags or 0
    rounding = rounding or 0.0
    thickness = thickness or 1.0
    return lib.ImDrawList_AddRect(self,p_min,p_max,col,rounding,flags,thickness)
end
function ImDrawList:AddRectFilled(p_min,p_max,col,rounding,flags)
    flags = flags or 0
    rounding = rounding or 0.0
    return lib.ImDrawList_AddRectFilled(self,p_min,p_max,col,rounding,flags)
end
ImDrawList.AddRectFilledMultiColor = lib.ImDrawList_AddRectFilledMultiColor
function ImDrawList:AddText_Vec2(pos,col,text_begin,text_end)
    text_end = text_end or nil
    return lib.ImDrawList_AddText_Vec2(self,pos,col,text_begin,text_end)
end
function ImDrawList:AddText_FontPtr(font,font_size,pos,col,text_begin,text_end,wrap_width,cpu_fine_clip_rect)
    cpu_fine_clip_rect = cpu_fine_clip_rect or nil
    text_end = text_end or nil
    wrap_width = wrap_width or 0.0
    return lib.ImDrawList_AddText_FontPtr(self,font,font_size,pos,col,text_begin,text_end,wrap_width,cpu_fine_clip_rect)
end
function ImDrawList:AddText(a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if ffi.istype('const ImVec2',a2) then return self:AddText_Vec2(a2,a3,a4,a5) end
    if (ffi.istype('const ImFont*',a2) or ffi.istype('const ImFont',a2) or ffi.istype('const ImFont[]',a2)) then return self:AddText_FontPtr(a2,a3,a4,a5,a6,a7,a8,a9) end
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
    num_segments = num_segments or 0
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
function ImDrawList:PathEllipticalArcTo(center,radius_x,radius_y,rot,a_min,a_max,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_PathEllipticalArcTo(self,center,radius_x,radius_y,rot,a_min,a_max,num_segments)
end
ImDrawList.PathFillConvex = lib.ImDrawList_PathFillConvex
ImDrawList.PathLineTo = lib.ImDrawList_PathLineTo
ImDrawList.PathLineToMergeDuplicate = lib.ImDrawList_PathLineToMergeDuplicate
function ImDrawList:PathRect(rect_min,rect_max,rounding,flags)
    flags = flags or 0
    rounding = rounding or 0.0
    return lib.ImDrawList_PathRect(self,rect_min,rect_max,rounding,flags)
end
function ImDrawList:PathStroke(col,flags,thickness)
    flags = flags or 0
    thickness = thickness or 1.0
    return lib.ImDrawList_PathStroke(self,col,flags,thickness)
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
ImDrawList._CalcCircleAutoSegmentCount = lib.ImDrawList__CalcCircleAutoSegmentCount
ImDrawList._ClearFreeMemory = lib.ImDrawList__ClearFreeMemory
ImDrawList._OnChangedClipRect = lib.ImDrawList__OnChangedClipRect
ImDrawList._OnChangedTextureID = lib.ImDrawList__OnChangedTextureID
ImDrawList._OnChangedVtxOffset = lib.ImDrawList__OnChangedVtxOffset
ImDrawList._PathArcToFastEx = lib.ImDrawList__PathArcToFastEx
ImDrawList._PathArcToN = lib.ImDrawList__PathArcToN
ImDrawList._PopUnusedDrawCmd = lib.ImDrawList__PopUnusedDrawCmd
ImDrawList._ResetForNewFrame = lib.ImDrawList__ResetForNewFrame
ImDrawList._TryMergeDrawCmds = lib.ImDrawList__TryMergeDrawCmds
M.ImDrawList = ffi.metatype("ImDrawList",ImDrawList)
--------------------------ImDrawListSharedData----------------------------
local ImDrawListSharedData= {}
ImDrawListSharedData.__index = ImDrawListSharedData
function ImDrawListSharedData.__new(ctype)
    local ptr = lib.ImDrawListSharedData_ImDrawListSharedData()
    return ffi.gc(ptr,lib.ImDrawListSharedData_destroy)
end
ImDrawListSharedData.SetCircleTessellationMaxError = lib.ImDrawListSharedData_SetCircleTessellationMaxError
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
function ImFontAtlas:AddFontFromMemoryCompressedTTF(compressed_font_data,compressed_font_data_size,size_pixels,font_cfg,glyph_ranges)
    font_cfg = font_cfg or nil
    glyph_ranges = glyph_ranges or nil
    return lib.ImFontAtlas_AddFontFromMemoryCompressedTTF(self,compressed_font_data,compressed_font_data_size,size_pixels,font_cfg,glyph_ranges)
end
function ImFontAtlas:AddFontFromMemoryTTF(font_data,font_data_size,size_pixels,font_cfg,glyph_ranges)
    font_cfg = font_cfg or nil
    glyph_ranges = glyph_ranges or nil
    return lib.ImFontAtlas_AddFontFromMemoryTTF(self,font_data,font_data_size,size_pixels,font_cfg,glyph_ranges)
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
ImFontAtlas.GetGlyphRangesGreek = lib.ImFontAtlas_GetGlyphRangesGreek
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
--------------------------ImGuiComboPreviewData----------------------------
local ImGuiComboPreviewData= {}
ImGuiComboPreviewData.__index = ImGuiComboPreviewData
function ImGuiComboPreviewData.__new(ctype)
    local ptr = lib.ImGuiComboPreviewData_ImGuiComboPreviewData()
    return ffi.gc(ptr,lib.ImGuiComboPreviewData_destroy)
end
M.ImGuiComboPreviewData = ffi.metatype("ImGuiComboPreviewData",ImGuiComboPreviewData)
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
--------------------------ImGuiDataVarInfo----------------------------
local ImGuiDataVarInfo= {}
ImGuiDataVarInfo.__index = ImGuiDataVarInfo
ImGuiDataVarInfo.GetVarPtr = lib.ImGuiDataVarInfo_GetVarPtr
M.ImGuiDataVarInfo = ffi.metatype("ImGuiDataVarInfo",ImGuiDataVarInfo)
--------------------------ImGuiDebugAllocInfo----------------------------
local ImGuiDebugAllocInfo= {}
ImGuiDebugAllocInfo.__index = ImGuiDebugAllocInfo
function ImGuiDebugAllocInfo.__new(ctype)
    local ptr = lib.ImGuiDebugAllocInfo_ImGuiDebugAllocInfo()
    return ffi.gc(ptr,lib.ImGuiDebugAllocInfo_destroy)
end
M.ImGuiDebugAllocInfo = ffi.metatype("ImGuiDebugAllocInfo",ImGuiDebugAllocInfo)
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
ImGuiDockNode.SetLocalFlags = lib.ImGuiDockNode_SetLocalFlags
ImGuiDockNode.UpdateMergedFlags = lib.ImGuiDockNode_UpdateMergedFlags
M.ImGuiDockNode = ffi.metatype("ImGuiDockNode",ImGuiDockNode)
--------------------------ImGuiIDStackTool----------------------------
local ImGuiIDStackTool= {}
ImGuiIDStackTool.__index = ImGuiIDStackTool
function ImGuiIDStackTool.__new(ctype)
    local ptr = lib.ImGuiIDStackTool_ImGuiIDStackTool()
    return ffi.gc(ptr,lib.ImGuiIDStackTool_destroy)
end
M.ImGuiIDStackTool = ffi.metatype("ImGuiIDStackTool",ImGuiIDStackTool)
--------------------------ImGuiIO----------------------------
local ImGuiIO= {}
ImGuiIO.__index = ImGuiIO
ImGuiIO.AddFocusEvent = lib.ImGuiIO_AddFocusEvent
ImGuiIO.AddInputCharacter = lib.ImGuiIO_AddInputCharacter
ImGuiIO.AddInputCharacterUTF16 = lib.ImGuiIO_AddInputCharacterUTF16
ImGuiIO.AddInputCharactersUTF8 = lib.ImGuiIO_AddInputCharactersUTF8
ImGuiIO.AddKeyAnalogEvent = lib.ImGuiIO_AddKeyAnalogEvent
ImGuiIO.AddKeyEvent = lib.ImGuiIO_AddKeyEvent
ImGuiIO.AddMouseButtonEvent = lib.ImGuiIO_AddMouseButtonEvent
ImGuiIO.AddMousePosEvent = lib.ImGuiIO_AddMousePosEvent
ImGuiIO.AddMouseSourceEvent = lib.ImGuiIO_AddMouseSourceEvent
ImGuiIO.AddMouseViewportEvent = lib.ImGuiIO_AddMouseViewportEvent
ImGuiIO.AddMouseWheelEvent = lib.ImGuiIO_AddMouseWheelEvent
ImGuiIO.ClearEventsQueue = lib.ImGuiIO_ClearEventsQueue
ImGuiIO.ClearInputKeys = lib.ImGuiIO_ClearInputKeys
function ImGuiIO.__new(ctype)
    local ptr = lib.ImGuiIO_ImGuiIO()
    return ffi.gc(ptr,lib.ImGuiIO_destroy)
end
ImGuiIO.SetAppAcceptingEvents = lib.ImGuiIO_SetAppAcceptingEvents
function ImGuiIO:SetKeyEventNativeData(key,native_keycode,native_scancode,native_legacy_index)
    native_legacy_index = native_legacy_index or -1
    return lib.ImGuiIO_SetKeyEventNativeData(self,key,native_keycode,native_scancode,native_legacy_index)
end
M.ImGuiIO = ffi.metatype("ImGuiIO",ImGuiIO)
--------------------------ImGuiInputEvent----------------------------
local ImGuiInputEvent= {}
ImGuiInputEvent.__index = ImGuiInputEvent
function ImGuiInputEvent.__new(ctype)
    local ptr = lib.ImGuiInputEvent_ImGuiInputEvent()
    return ffi.gc(ptr,lib.ImGuiInputEvent_destroy)
end
M.ImGuiInputEvent = ffi.metatype("ImGuiInputEvent",ImGuiInputEvent)
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
--------------------------ImGuiInputTextDeactivatedState----------------------------
local ImGuiInputTextDeactivatedState= {}
ImGuiInputTextDeactivatedState.__index = ImGuiInputTextDeactivatedState
ImGuiInputTextDeactivatedState.ClearFreeMemory = lib.ImGuiInputTextDeactivatedState_ClearFreeMemory
function ImGuiInputTextDeactivatedState.__new(ctype)
    local ptr = lib.ImGuiInputTextDeactivatedState_ImGuiInputTextDeactivatedState()
    return ffi.gc(ptr,lib.ImGuiInputTextDeactivatedState_destroy)
end
M.ImGuiInputTextDeactivatedState = ffi.metatype("ImGuiInputTextDeactivatedState",ImGuiInputTextDeactivatedState)
--------------------------ImGuiInputTextState----------------------------
local ImGuiInputTextState= {}
ImGuiInputTextState.__index = ImGuiInputTextState
ImGuiInputTextState.ClearFreeMemory = lib.ImGuiInputTextState_ClearFreeMemory
ImGuiInputTextState.ClearSelection = lib.ImGuiInputTextState_ClearSelection
ImGuiInputTextState.ClearText = lib.ImGuiInputTextState_ClearText
ImGuiInputTextState.CursorAnimReset = lib.ImGuiInputTextState_CursorAnimReset
ImGuiInputTextState.CursorClamp = lib.ImGuiInputTextState_CursorClamp
ImGuiInputTextState.GetCursorPos = lib.ImGuiInputTextState_GetCursorPos
ImGuiInputTextState.GetRedoAvailCount = lib.ImGuiInputTextState_GetRedoAvailCount
ImGuiInputTextState.GetSelectionEnd = lib.ImGuiInputTextState_GetSelectionEnd
ImGuiInputTextState.GetSelectionStart = lib.ImGuiInputTextState_GetSelectionStart
ImGuiInputTextState.GetUndoAvailCount = lib.ImGuiInputTextState_GetUndoAvailCount
ImGuiInputTextState.HasSelection = lib.ImGuiInputTextState_HasSelection
function ImGuiInputTextState.__new(ctype)
    local ptr = lib.ImGuiInputTextState_ImGuiInputTextState()
    return ffi.gc(ptr,lib.ImGuiInputTextState_destroy)
end
ImGuiInputTextState.OnKeyPressed = lib.ImGuiInputTextState_OnKeyPressed
ImGuiInputTextState.ReloadUserBufAndKeepSelection = lib.ImGuiInputTextState_ReloadUserBufAndKeepSelection
ImGuiInputTextState.ReloadUserBufAndMoveToEnd = lib.ImGuiInputTextState_ReloadUserBufAndMoveToEnd
ImGuiInputTextState.ReloadUserBufAndSelectAll = lib.ImGuiInputTextState_ReloadUserBufAndSelectAll
ImGuiInputTextState.SelectAll = lib.ImGuiInputTextState_SelectAll
M.ImGuiInputTextState = ffi.metatype("ImGuiInputTextState",ImGuiInputTextState)
--------------------------ImGuiKeyOwnerData----------------------------
local ImGuiKeyOwnerData= {}
ImGuiKeyOwnerData.__index = ImGuiKeyOwnerData
function ImGuiKeyOwnerData.__new(ctype)
    local ptr = lib.ImGuiKeyOwnerData_ImGuiKeyOwnerData()
    return ffi.gc(ptr,lib.ImGuiKeyOwnerData_destroy)
end
M.ImGuiKeyOwnerData = ffi.metatype("ImGuiKeyOwnerData",ImGuiKeyOwnerData)
--------------------------ImGuiKeyRoutingData----------------------------
local ImGuiKeyRoutingData= {}
ImGuiKeyRoutingData.__index = ImGuiKeyRoutingData
function ImGuiKeyRoutingData.__new(ctype)
    local ptr = lib.ImGuiKeyRoutingData_ImGuiKeyRoutingData()
    return ffi.gc(ptr,lib.ImGuiKeyRoutingData_destroy)
end
M.ImGuiKeyRoutingData = ffi.metatype("ImGuiKeyRoutingData",ImGuiKeyRoutingData)
--------------------------ImGuiKeyRoutingTable----------------------------
local ImGuiKeyRoutingTable= {}
ImGuiKeyRoutingTable.__index = ImGuiKeyRoutingTable
ImGuiKeyRoutingTable.Clear = lib.ImGuiKeyRoutingTable_Clear
function ImGuiKeyRoutingTable.__new(ctype)
    local ptr = lib.ImGuiKeyRoutingTable_ImGuiKeyRoutingTable()
    return ffi.gc(ptr,lib.ImGuiKeyRoutingTable_destroy)
end
M.ImGuiKeyRoutingTable = ffi.metatype("ImGuiKeyRoutingTable",ImGuiKeyRoutingTable)
--------------------------ImGuiLastItemData----------------------------
local ImGuiLastItemData= {}
ImGuiLastItemData.__index = ImGuiLastItemData
function ImGuiLastItemData.__new(ctype)
    local ptr = lib.ImGuiLastItemData_ImGuiLastItemData()
    return ffi.gc(ptr,lib.ImGuiLastItemData_destroy)
end
M.ImGuiLastItemData = ffi.metatype("ImGuiLastItemData",ImGuiLastItemData)
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
ImGuiListClipper.IncludeItemByIndex = lib.ImGuiListClipper_IncludeItemByIndex
ImGuiListClipper.IncludeItemsByIndex = lib.ImGuiListClipper_IncludeItemsByIndex
ImGuiListClipper.Step = lib.ImGuiListClipper_Step
M.ImGuiListClipper = ffi.metatype("ImGuiListClipper",ImGuiListClipper)
--------------------------ImGuiListClipperData----------------------------
local ImGuiListClipperData= {}
ImGuiListClipperData.__index = ImGuiListClipperData
function ImGuiListClipperData.__new(ctype)
    local ptr = lib.ImGuiListClipperData_ImGuiListClipperData()
    return ffi.gc(ptr,lib.ImGuiListClipperData_destroy)
end
ImGuiListClipperData.Reset = lib.ImGuiListClipperData_Reset
M.ImGuiListClipperData = ffi.metatype("ImGuiListClipperData",ImGuiListClipperData)
--------------------------ImGuiListClipperRange----------------------------
local ImGuiListClipperRange= {}
ImGuiListClipperRange.__index = ImGuiListClipperRange
M.ImGuiListClipperRange_FromIndices = lib.ImGuiListClipperRange_FromIndices
M.ImGuiListClipperRange_FromPositions = lib.ImGuiListClipperRange_FromPositions
M.ImGuiListClipperRange = ffi.metatype("ImGuiListClipperRange",ImGuiListClipperRange)
--------------------------ImGuiMenuColumns----------------------------
local ImGuiMenuColumns= {}
ImGuiMenuColumns.__index = ImGuiMenuColumns
ImGuiMenuColumns.CalcNextTotalWidth = lib.ImGuiMenuColumns_CalcNextTotalWidth
ImGuiMenuColumns.DeclColumns = lib.ImGuiMenuColumns_DeclColumns
function ImGuiMenuColumns.__new(ctype)
    local ptr = lib.ImGuiMenuColumns_ImGuiMenuColumns()
    return ffi.gc(ptr,lib.ImGuiMenuColumns_destroy)
end
ImGuiMenuColumns.Update = lib.ImGuiMenuColumns_Update
M.ImGuiMenuColumns = ffi.metatype("ImGuiMenuColumns",ImGuiMenuColumns)
--------------------------ImGuiNavItemData----------------------------
local ImGuiNavItemData= {}
ImGuiNavItemData.__index = ImGuiNavItemData
ImGuiNavItemData.Clear = lib.ImGuiNavItemData_Clear
function ImGuiNavItemData.__new(ctype)
    local ptr = lib.ImGuiNavItemData_ImGuiNavItemData()
    return ffi.gc(ptr,lib.ImGuiNavItemData_destroy)
end
M.ImGuiNavItemData = ffi.metatype("ImGuiNavItemData",ImGuiNavItemData)
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
--------------------------ImGuiPlatformImeData----------------------------
local ImGuiPlatformImeData= {}
ImGuiPlatformImeData.__index = ImGuiPlatformImeData
function ImGuiPlatformImeData.__new(ctype)
    local ptr = lib.ImGuiPlatformImeData_ImGuiPlatformImeData()
    return ffi.gc(ptr,lib.ImGuiPlatformImeData_destroy)
end
M.ImGuiPlatformImeData = ffi.metatype("ImGuiPlatformImeData",ImGuiPlatformImeData)
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
function ImGuiPtrOrIndex.ImGuiPtrOrIndex_Ptr(ptr)
    local ptr = lib.ImGuiPtrOrIndex_ImGuiPtrOrIndex_Ptr(ptr)
    return ffi.gc(ptr,lib.ImGuiPtrOrIndex_destroy)
end
function ImGuiPtrOrIndex.ImGuiPtrOrIndex_Int(index)
    local ptr = lib.ImGuiPtrOrIndex_ImGuiPtrOrIndex_Int(index)
    return ffi.gc(ptr,lib.ImGuiPtrOrIndex_destroy)
end
function ImGuiPtrOrIndex.__new(ctype,a1) -- generic version
    if ffi.istype('void *',a1) then return ImGuiPtrOrIndex.ImGuiPtrOrIndex_Ptr(a1) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return ImGuiPtrOrIndex.ImGuiPtrOrIndex_Int(a1) end
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
--------------------------ImGuiStackLevelInfo----------------------------
local ImGuiStackLevelInfo= {}
ImGuiStackLevelInfo.__index = ImGuiStackLevelInfo
function ImGuiStackLevelInfo.__new(ctype)
    local ptr = lib.ImGuiStackLevelInfo_ImGuiStackLevelInfo()
    return ffi.gc(ptr,lib.ImGuiStackLevelInfo_destroy)
end
M.ImGuiStackLevelInfo = ffi.metatype("ImGuiStackLevelInfo",ImGuiStackLevelInfo)
--------------------------ImGuiStackSizes----------------------------
local ImGuiStackSizes= {}
ImGuiStackSizes.__index = ImGuiStackSizes
ImGuiStackSizes.CompareWithContextState = lib.ImGuiStackSizes_CompareWithContextState
function ImGuiStackSizes.__new(ctype)
    local ptr = lib.ImGuiStackSizes_ImGuiStackSizes()
    return ffi.gc(ptr,lib.ImGuiStackSizes_destroy)
end
ImGuiStackSizes.SetToContextState = lib.ImGuiStackSizes_SetToContextState
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
function ImGuiStoragePair.ImGuiStoragePair_Int(_key,_val)
    local ptr = lib.ImGuiStoragePair_ImGuiStoragePair_Int(_key,_val)
    return ffi.gc(ptr,lib.ImGuiStoragePair_destroy)
end
function ImGuiStoragePair.ImGuiStoragePair_Float(_key,_val)
    local ptr = lib.ImGuiStoragePair_ImGuiStoragePair_Float(_key,_val)
    return ffi.gc(ptr,lib.ImGuiStoragePair_destroy)
end
function ImGuiStoragePair.ImGuiStoragePair_Ptr(_key,_val)
    local ptr = lib.ImGuiStoragePair_ImGuiStoragePair_Ptr(_key,_val)
    return ffi.gc(ptr,lib.ImGuiStoragePair_destroy)
end
function ImGuiStoragePair.__new(ctype,a1,a2) -- generic version
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return ImGuiStoragePair.ImGuiStoragePair_Int(a1,a2) end
    if (ffi.istype('float',a2) or type(a2)=='number') then return ImGuiStoragePair.ImGuiStoragePair_Float(a1,a2) end
    if ffi.istype('void *',a2) then return ImGuiStoragePair.ImGuiStoragePair_Ptr(a1,a2) end
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
function ImGuiStyleMod.ImGuiStyleMod_Int(idx,v)
    local ptr = lib.ImGuiStyleMod_ImGuiStyleMod_Int(idx,v)
    return ffi.gc(ptr,lib.ImGuiStyleMod_destroy)
end
function ImGuiStyleMod.ImGuiStyleMod_Float(idx,v)
    local ptr = lib.ImGuiStyleMod_ImGuiStyleMod_Float(idx,v)
    return ffi.gc(ptr,lib.ImGuiStyleMod_destroy)
end
function ImGuiStyleMod.ImGuiStyleMod_Vec2(idx,v)
    local ptr = lib.ImGuiStyleMod_ImGuiStyleMod_Vec2(idx,v)
    return ffi.gc(ptr,lib.ImGuiStyleMod_destroy)
end
function ImGuiStyleMod.__new(ctype,a1,a2) -- generic version
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return ImGuiStyleMod.ImGuiStyleMod_Int(a1,a2) end
    if (ffi.istype('float',a2) or type(a2)=='number') then return ImGuiStyleMod.ImGuiStyleMod_Float(a1,a2) end
    if ffi.istype('ImVec2',a2) then return ImGuiStyleMod.ImGuiStyleMod_Vec2(a1,a2) end
    print(ctype,a1,a2)
    error'ImGuiStyleMod.__new could not find overloaded'
end
M.ImGuiStyleMod = ffi.metatype("ImGuiStyleMod",ImGuiStyleMod)
--------------------------ImGuiTabBar----------------------------
local ImGuiTabBar= {}
ImGuiTabBar.__index = ImGuiTabBar
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
--------------------------ImGuiTableInstanceData----------------------------
local ImGuiTableInstanceData= {}
ImGuiTableInstanceData.__index = ImGuiTableInstanceData
function ImGuiTableInstanceData.__new(ctype)
    local ptr = lib.ImGuiTableInstanceData_ImGuiTableInstanceData()
    return ffi.gc(ptr,lib.ImGuiTableInstanceData_destroy)
end
M.ImGuiTableInstanceData = ffi.metatype("ImGuiTableInstanceData",ImGuiTableInstanceData)
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
--------------------------ImGuiTableTempData----------------------------
local ImGuiTableTempData= {}
ImGuiTableTempData.__index = ImGuiTableTempData
function ImGuiTableTempData.__new(ctype)
    local ptr = lib.ImGuiTableTempData_ImGuiTableTempData()
    return ffi.gc(ptr,lib.ImGuiTableTempData_destroy)
end
M.ImGuiTableTempData = ffi.metatype("ImGuiTableTempData",ImGuiTableTempData)
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
--------------------------ImGuiTextIndex----------------------------
local ImGuiTextIndex= {}
ImGuiTextIndex.__index = ImGuiTextIndex
ImGuiTextIndex.append = lib.ImGuiTextIndex_append
ImGuiTextIndex.clear = lib.ImGuiTextIndex_clear
ImGuiTextIndex.get_line_begin = lib.ImGuiTextIndex_get_line_begin
ImGuiTextIndex.get_line_end = lib.ImGuiTextIndex_get_line_end
ImGuiTextIndex.size = lib.ImGuiTextIndex_size
M.ImGuiTextIndex = ffi.metatype("ImGuiTextIndex",ImGuiTextIndex)
--------------------------ImGuiTextRange----------------------------
local ImGuiTextRange= {}
ImGuiTextRange.__index = ImGuiTextRange
function ImGuiTextRange.ImGuiTextRange_Nil()
    local ptr = lib.ImGuiTextRange_ImGuiTextRange_Nil()
    return ffi.gc(ptr,lib.ImGuiTextRange_destroy)
end
function ImGuiTextRange.ImGuiTextRange_Str(_b,_e)
    local ptr = lib.ImGuiTextRange_ImGuiTextRange_Str(_b,_e)
    return ffi.gc(ptr,lib.ImGuiTextRange_destroy)
end
function ImGuiTextRange.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImGuiTextRange.ImGuiTextRange_Nil() end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return ImGuiTextRange.ImGuiTextRange_Str(a1,a2) end
    print(ctype,a1,a2)
    error'ImGuiTextRange.__new could not find overloaded'
end
ImGuiTextRange.empty = lib.ImGuiTextRange_empty
ImGuiTextRange.split = lib.ImGuiTextRange_split
M.ImGuiTextRange = ffi.metatype("ImGuiTextRange",ImGuiTextRange)
--------------------------ImGuiTypingSelectState----------------------------
local ImGuiTypingSelectState= {}
ImGuiTypingSelectState.__index = ImGuiTypingSelectState
ImGuiTypingSelectState.Clear = lib.ImGuiTypingSelectState_Clear
function ImGuiTypingSelectState.__new(ctype)
    local ptr = lib.ImGuiTypingSelectState_ImGuiTypingSelectState()
    return ffi.gc(ptr,lib.ImGuiTypingSelectState_destroy)
end
M.ImGuiTypingSelectState = ffi.metatype("ImGuiTypingSelectState",ImGuiTypingSelectState)
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
function ImGuiViewportP:CalcWorkRectPos(off_min)
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImGuiViewportP_CalcWorkRectPos(nonUDT_out,self,off_min)
    return nonUDT_out
end
function ImGuiViewportP:CalcWorkRectSize(off_min,off_max)
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImGuiViewportP_CalcWorkRectSize(nonUDT_out,self,off_min,off_max)
    return nonUDT_out
end
ImGuiViewportP.ClearRequestFlags = lib.ImGuiViewportP_ClearRequestFlags
function ImGuiViewportP:GetBuildWorkRect()
    local nonUDT_out = ffi.new("ImRect")
    lib.ImGuiViewportP_GetBuildWorkRect(nonUDT_out,self)
    return nonUDT_out
end
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
function ImGuiWindow:GetID_Str(str,str_end)
    str_end = str_end or nil
    return lib.ImGuiWindow_GetID_Str(self,str,str_end)
end
ImGuiWindow.GetID_Ptr = lib.ImGuiWindow_GetID_Ptr
ImGuiWindow.GetID_Int = lib.ImGuiWindow_GetID_Int
function ImGuiWindow:GetID(a2,a3) -- generic version
    if (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return self:GetID_Str(a2,a3) end
    if ffi.istype('void *',a2) then return self:GetID_Ptr(a2) end
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return self:GetID_Int(a2) end
    print(a2,a3)
    error'ImGuiWindow:GetID could not find overloaded'
end
ImGuiWindow.GetIDFromRectangle = lib.ImGuiWindow_GetIDFromRectangle
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
--------------------------ImNodesIO----------------------------
local ImNodesIO= {}
ImNodesIO.__index = ImNodesIO
function ImNodesIO.__new(ctype)
    local ptr = lib.ImNodesIO_ImNodesIO()
    return ffi.gc(ptr,lib.ImNodesIO_destroy)
end
M.ImNodesIO = ffi.metatype("ImNodesIO",ImNodesIO)
--------------------------ImNodesStyle----------------------------
local ImNodesStyle= {}
ImNodesStyle.__index = ImNodesStyle
function ImNodesStyle.__new(ctype)
    local ptr = lib.ImNodesStyle_ImNodesStyle()
    return ffi.gc(ptr,lib.ImNodesStyle_destroy)
end
M.ImNodesStyle = ffi.metatype("ImNodesStyle",ImNodesStyle)
--------------------------ImPlotAlignmentData----------------------------
local ImPlotAlignmentData= {}
ImPlotAlignmentData.__index = ImPlotAlignmentData
ImPlotAlignmentData.Begin = lib.ImPlotAlignmentData_Begin
ImPlotAlignmentData.End = lib.ImPlotAlignmentData_End
function ImPlotAlignmentData.__new(ctype)
    local ptr = lib.ImPlotAlignmentData_ImPlotAlignmentData()
    return ffi.gc(ptr,lib.ImPlotAlignmentData_destroy)
end
ImPlotAlignmentData.Reset = lib.ImPlotAlignmentData_Reset
ImPlotAlignmentData.Update = lib.ImPlotAlignmentData_Update
M.ImPlotAlignmentData = ffi.metatype("ImPlotAlignmentData",ImPlotAlignmentData)
--------------------------ImPlotAnnotation----------------------------
local ImPlotAnnotation= {}
ImPlotAnnotation.__index = ImPlotAnnotation
function ImPlotAnnotation.__new(ctype)
    local ptr = lib.ImPlotAnnotation_ImPlotAnnotation()
    return ffi.gc(ptr,lib.ImPlotAnnotation_destroy)
end
M.ImPlotAnnotation = ffi.metatype("ImPlotAnnotation",ImPlotAnnotation)
--------------------------ImPlotAnnotationCollection----------------------------
local ImPlotAnnotationCollection= {}
ImPlotAnnotationCollection.__index = ImPlotAnnotationCollection
ImPlotAnnotationCollection.Append = lib.ImPlotAnnotationCollection_Append
ImPlotAnnotationCollection.AppendV = lib.ImPlotAnnotationCollection_AppendV
ImPlotAnnotationCollection.GetText = lib.ImPlotAnnotationCollection_GetText
function ImPlotAnnotationCollection.__new(ctype)
    local ptr = lib.ImPlotAnnotationCollection_ImPlotAnnotationCollection()
    return ffi.gc(ptr,lib.ImPlotAnnotationCollection_destroy)
end
ImPlotAnnotationCollection.Reset = lib.ImPlotAnnotationCollection_Reset
M.ImPlotAnnotationCollection = ffi.metatype("ImPlotAnnotationCollection",ImPlotAnnotationCollection)
--------------------------ImPlotAxis----------------------------
local ImPlotAxis= {}
ImPlotAxis.__index = ImPlotAxis
ImPlotAxis.ApplyFit = lib.ImPlotAxis_ApplyFit
ImPlotAxis.CanInitFit = lib.ImPlotAxis_CanInitFit
ImPlotAxis.Constrain = lib.ImPlotAxis_Constrain
ImPlotAxis.ExtendFit = lib.ImPlotAxis_ExtendFit
ImPlotAxis.ExtendFitWith = lib.ImPlotAxis_ExtendFitWith
ImPlotAxis.GetAspect = lib.ImPlotAxis_GetAspect
ImPlotAxis.HasGridLines = lib.ImPlotAxis_HasGridLines
ImPlotAxis.HasLabel = lib.ImPlotAxis_HasLabel
ImPlotAxis.HasMenus = lib.ImPlotAxis_HasMenus
ImPlotAxis.HasTickLabels = lib.ImPlotAxis_HasTickLabels
ImPlotAxis.HasTickMarks = lib.ImPlotAxis_HasTickMarks
function ImPlotAxis.__new(ctype)
    local ptr = lib.ImPlotAxis_ImPlotAxis()
    return ffi.gc(ptr,lib.ImPlotAxis_destroy)
end
ImPlotAxis.IsAutoFitting = lib.ImPlotAxis_IsAutoFitting
ImPlotAxis.IsForeground = lib.ImPlotAxis_IsForeground
ImPlotAxis.IsInputLocked = lib.ImPlotAxis_IsInputLocked
ImPlotAxis.IsInputLockedMax = lib.ImPlotAxis_IsInputLockedMax
ImPlotAxis.IsInputLockedMin = lib.ImPlotAxis_IsInputLockedMin
ImPlotAxis.IsInverted = lib.ImPlotAxis_IsInverted
ImPlotAxis.IsLocked = lib.ImPlotAxis_IsLocked
ImPlotAxis.IsLockedMax = lib.ImPlotAxis_IsLockedMax
ImPlotAxis.IsLockedMin = lib.ImPlotAxis_IsLockedMin
ImPlotAxis.IsOpposite = lib.ImPlotAxis_IsOpposite
ImPlotAxis.IsPanLocked = lib.ImPlotAxis_IsPanLocked
ImPlotAxis.IsRangeLocked = lib.ImPlotAxis_IsRangeLocked
ImPlotAxis.PixelSize = lib.ImPlotAxis_PixelSize
ImPlotAxis.PixelsToPlot = lib.ImPlotAxis_PixelsToPlot
ImPlotAxis.PlotToPixels = lib.ImPlotAxis_PlotToPixels
ImPlotAxis.PullLinks = lib.ImPlotAxis_PullLinks
ImPlotAxis.PushLinks = lib.ImPlotAxis_PushLinks
ImPlotAxis.Reset = lib.ImPlotAxis_Reset
ImPlotAxis.SetAspect = lib.ImPlotAxis_SetAspect
function ImPlotAxis:SetMax(_max,force)
    force = force or false
    return lib.ImPlotAxis_SetMax(self,_max,force)
end
function ImPlotAxis:SetMin(_min,force)
    force = force or false
    return lib.ImPlotAxis_SetMin(self,_min,force)
end
ImPlotAxis.SetRange_double = lib.ImPlotAxis_SetRange_double
ImPlotAxis.SetRange_PlotRange = lib.ImPlotAxis_SetRange_PlotRange
function ImPlotAxis:SetRange(a2,a3) -- generic version
    if (ffi.istype('double',a2) or type(a2)=='number') then return self:SetRange_double(a2,a3) end
    if ffi.istype('const ImPlotRange',a2) then return self:SetRange_PlotRange(a2) end
    print(a2,a3)
    error'ImPlotAxis:SetRange could not find overloaded'
end
ImPlotAxis.UpdateTransformCache = lib.ImPlotAxis_UpdateTransformCache
ImPlotAxis.WillRender = lib.ImPlotAxis_WillRender
M.ImPlotAxis = ffi.metatype("ImPlotAxis",ImPlotAxis)
--------------------------ImPlotColormapData----------------------------
local ImPlotColormapData= {}
ImPlotColormapData.__index = ImPlotColormapData
ImPlotColormapData.Append = lib.ImPlotColormapData_Append
ImPlotColormapData.GetIndex = lib.ImPlotColormapData_GetIndex
ImPlotColormapData.GetKeyColor = lib.ImPlotColormapData_GetKeyColor
ImPlotColormapData.GetKeyCount = lib.ImPlotColormapData_GetKeyCount
ImPlotColormapData.GetKeys = lib.ImPlotColormapData_GetKeys
ImPlotColormapData.GetName = lib.ImPlotColormapData_GetName
ImPlotColormapData.GetTable = lib.ImPlotColormapData_GetTable
ImPlotColormapData.GetTableColor = lib.ImPlotColormapData_GetTableColor
ImPlotColormapData.GetTableSize = lib.ImPlotColormapData_GetTableSize
function ImPlotColormapData.__new(ctype)
    local ptr = lib.ImPlotColormapData_ImPlotColormapData()
    return ffi.gc(ptr,lib.ImPlotColormapData_destroy)
end
ImPlotColormapData.IsQual = lib.ImPlotColormapData_IsQual
ImPlotColormapData.LerpTable = lib.ImPlotColormapData_LerpTable
ImPlotColormapData.RebuildTables = lib.ImPlotColormapData_RebuildTables
ImPlotColormapData.SetKeyColor = lib.ImPlotColormapData_SetKeyColor
ImPlotColormapData._AppendTable = lib.ImPlotColormapData__AppendTable
M.ImPlotColormapData = ffi.metatype("ImPlotColormapData",ImPlotColormapData)
--------------------------ImPlotDateTimeSpec----------------------------
local ImPlotDateTimeSpec= {}
ImPlotDateTimeSpec.__index = ImPlotDateTimeSpec
function ImPlotDateTimeSpec.ImPlotDateTimeSpec_Nil()
    local ptr = lib.ImPlotDateTimeSpec_ImPlotDateTimeSpec_Nil()
    return ffi.gc(ptr,lib.ImPlotDateTimeSpec_destroy)
end
function ImPlotDateTimeSpec.ImPlotDateTimeSpec_PlotDateFmt(date_fmt,time_fmt,use_24_hr_clk,use_iso_8601)
    if use_24_hr_clk == nil then use_24_hr_clk = false end
    if use_iso_8601 == nil then use_iso_8601 = false end
    local ptr = lib.ImPlotDateTimeSpec_ImPlotDateTimeSpec_PlotDateFmt(date_fmt,time_fmt,use_24_hr_clk,use_iso_8601)
    return ffi.gc(ptr,lib.ImPlotDateTimeSpec_destroy)
end
function ImPlotDateTimeSpec.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImPlotDateTimeSpec.ImPlotDateTimeSpec_Nil() end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return ImPlotDateTimeSpec.ImPlotDateTimeSpec_PlotDateFmt(a1,a2,a3,a4) end
    print(ctype,a1,a2,a3,a4)
    error'ImPlotDateTimeSpec.__new could not find overloaded'
end
M.ImPlotDateTimeSpec = ffi.metatype("ImPlotDateTimeSpec",ImPlotDateTimeSpec)
--------------------------ImPlotInputMap----------------------------
local ImPlotInputMap= {}
ImPlotInputMap.__index = ImPlotInputMap
function ImPlotInputMap.__new(ctype)
    local ptr = lib.ImPlotInputMap_ImPlotInputMap()
    return ffi.gc(ptr,lib.ImPlotInputMap_destroy)
end
M.ImPlotInputMap = ffi.metatype("ImPlotInputMap",ImPlotInputMap)
--------------------------ImPlotItem----------------------------
local ImPlotItem= {}
ImPlotItem.__index = ImPlotItem
function ImPlotItem.__new(ctype)
    local ptr = lib.ImPlotItem_ImPlotItem()
    return ffi.gc(ptr,lib.ImPlotItem_destroy)
end
M.ImPlotItem = ffi.metatype("ImPlotItem",ImPlotItem)
--------------------------ImPlotItemGroup----------------------------
local ImPlotItemGroup= {}
ImPlotItemGroup.__index = ImPlotItemGroup
ImPlotItemGroup.GetItem_ID = lib.ImPlotItemGroup_GetItem_ID
ImPlotItemGroup.GetItem_Str = lib.ImPlotItemGroup_GetItem_Str
function ImPlotItemGroup:GetItem(a2) -- generic version
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return self:GetItem_ID(a2) end
    if (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return self:GetItem_Str(a2) end
    print(a2)
    error'ImPlotItemGroup:GetItem could not find overloaded'
end
ImPlotItemGroup.GetItemByIndex = lib.ImPlotItemGroup_GetItemByIndex
ImPlotItemGroup.GetItemCount = lib.ImPlotItemGroup_GetItemCount
ImPlotItemGroup.GetItemID = lib.ImPlotItemGroup_GetItemID
ImPlotItemGroup.GetItemIndex = lib.ImPlotItemGroup_GetItemIndex
ImPlotItemGroup.GetLegendCount = lib.ImPlotItemGroup_GetLegendCount
ImPlotItemGroup.GetLegendItem = lib.ImPlotItemGroup_GetLegendItem
ImPlotItemGroup.GetLegendLabel = lib.ImPlotItemGroup_GetLegendLabel
ImPlotItemGroup.GetOrAddItem = lib.ImPlotItemGroup_GetOrAddItem
function ImPlotItemGroup.__new(ctype)
    local ptr = lib.ImPlotItemGroup_ImPlotItemGroup()
    return ffi.gc(ptr,lib.ImPlotItemGroup_destroy)
end
ImPlotItemGroup.Reset = lib.ImPlotItemGroup_Reset
M.ImPlotItemGroup = ffi.metatype("ImPlotItemGroup",ImPlotItemGroup)
--------------------------ImPlotLegend----------------------------
local ImPlotLegend= {}
ImPlotLegend.__index = ImPlotLegend
function ImPlotLegend.__new(ctype)
    local ptr = lib.ImPlotLegend_ImPlotLegend()
    return ffi.gc(ptr,lib.ImPlotLegend_destroy)
end
ImPlotLegend.Reset = lib.ImPlotLegend_Reset
M.ImPlotLegend = ffi.metatype("ImPlotLegend",ImPlotLegend)
--------------------------ImPlotNextItemData----------------------------
local ImPlotNextItemData= {}
ImPlotNextItemData.__index = ImPlotNextItemData
function ImPlotNextItemData.__new(ctype)
    local ptr = lib.ImPlotNextItemData_ImPlotNextItemData()
    return ffi.gc(ptr,lib.ImPlotNextItemData_destroy)
end
ImPlotNextItemData.Reset = lib.ImPlotNextItemData_Reset
M.ImPlotNextItemData = ffi.metatype("ImPlotNextItemData",ImPlotNextItemData)
--------------------------ImPlotNextPlotData----------------------------
local ImPlotNextPlotData= {}
ImPlotNextPlotData.__index = ImPlotNextPlotData
function ImPlotNextPlotData.__new(ctype)
    local ptr = lib.ImPlotNextPlotData_ImPlotNextPlotData()
    return ffi.gc(ptr,lib.ImPlotNextPlotData_destroy)
end
ImPlotNextPlotData.Reset = lib.ImPlotNextPlotData_Reset
M.ImPlotNextPlotData = ffi.metatype("ImPlotNextPlotData",ImPlotNextPlotData)
--------------------------ImPlotPlot----------------------------
local ImPlotPlot= {}
ImPlotPlot.__index = ImPlotPlot
ImPlotPlot.ClearTextBuffer = lib.ImPlotPlot_ClearTextBuffer
ImPlotPlot.EnabledAxesX = lib.ImPlotPlot_EnabledAxesX
ImPlotPlot.EnabledAxesY = lib.ImPlotPlot_EnabledAxesY
ImPlotPlot.GetAxisLabel = lib.ImPlotPlot_GetAxisLabel
ImPlotPlot.GetTitle = lib.ImPlotPlot_GetTitle
ImPlotPlot.HasTitle = lib.ImPlotPlot_HasTitle
function ImPlotPlot.__new(ctype)
    local ptr = lib.ImPlotPlot_ImPlotPlot()
    return ffi.gc(ptr,lib.ImPlotPlot_destroy)
end
ImPlotPlot.IsInputLocked = lib.ImPlotPlot_IsInputLocked
ImPlotPlot.SetAxisLabel = lib.ImPlotPlot_SetAxisLabel
ImPlotPlot.SetTitle = lib.ImPlotPlot_SetTitle
ImPlotPlot.XAxis_Nil = lib.ImPlotPlot_XAxis_Nil
ImPlotPlot.XAxis__const = lib.ImPlotPlot_XAxis__const
function ImPlotPlot:XAxis(a2) -- generic version
    print(a2)
    error'ImPlotPlot:XAxis could not find overloaded'
end
ImPlotPlot.YAxis_Nil = lib.ImPlotPlot_YAxis_Nil
ImPlotPlot.YAxis__const = lib.ImPlotPlot_YAxis__const
function ImPlotPlot:YAxis(a2) -- generic version
    print(a2)
    error'ImPlotPlot:YAxis could not find overloaded'
end
M.ImPlotPlot = ffi.metatype("ImPlotPlot",ImPlotPlot)
--------------------------ImPlotPoint----------------------------
local ImPlotPoint= {}
ImPlotPoint.__index = ImPlotPoint
function ImPlotPoint.ImPlotPoint_Nil()
    local ptr = lib.ImPlotPoint_ImPlotPoint_Nil()
    return ffi.gc(ptr,lib.ImPlotPoint_destroy)
end
function ImPlotPoint.ImPlotPoint_double(_x,_y)
    local ptr = lib.ImPlotPoint_ImPlotPoint_double(_x,_y)
    return ffi.gc(ptr,lib.ImPlotPoint_destroy)
end
function ImPlotPoint.ImPlotPoint_Vec2(p)
    local ptr = lib.ImPlotPoint_ImPlotPoint_Vec2(p)
    return ffi.gc(ptr,lib.ImPlotPoint_destroy)
end
function ImPlotPoint.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImPlotPoint.ImPlotPoint_Nil() end
    if (ffi.istype('double',a1) or type(a1)=='number') then return ImPlotPoint.ImPlotPoint_double(a1,a2) end
    if ffi.istype('const ImVec2',a1) then return ImPlotPoint.ImPlotPoint_Vec2(a1) end
    print(ctype,a1,a2)
    error'ImPlotPoint.__new could not find overloaded'
end
M.ImPlotPoint = ffi.metatype("ImPlotPoint",ImPlotPoint)
--------------------------ImPlotPointError----------------------------
local ImPlotPointError= {}
ImPlotPointError.__index = ImPlotPointError
function ImPlotPointError.__new(ctype,x,y,neg,pos)
    local ptr = lib.ImPlotPointError_ImPlotPointError(x,y,neg,pos)
    return ffi.gc(ptr,lib.ImPlotPointError_destroy)
end
M.ImPlotPointError = ffi.metatype("ImPlotPointError",ImPlotPointError)
--------------------------ImPlotRange----------------------------
local ImPlotRange= {}
ImPlotRange.__index = ImPlotRange
ImPlotRange.Clamp = lib.ImPlotRange_Clamp
ImPlotRange.Contains = lib.ImPlotRange_Contains
function ImPlotRange.ImPlotRange_Nil()
    local ptr = lib.ImPlotRange_ImPlotRange_Nil()
    return ffi.gc(ptr,lib.ImPlotRange_destroy)
end
function ImPlotRange.ImPlotRange_double(_min,_max)
    local ptr = lib.ImPlotRange_ImPlotRange_double(_min,_max)
    return ffi.gc(ptr,lib.ImPlotRange_destroy)
end
function ImPlotRange.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImPlotRange.ImPlotRange_Nil() end
    if (ffi.istype('double',a1) or type(a1)=='number') then return ImPlotRange.ImPlotRange_double(a1,a2) end
    print(ctype,a1,a2)
    error'ImPlotRange.__new could not find overloaded'
end
ImPlotRange.Size = lib.ImPlotRange_Size
M.ImPlotRange = ffi.metatype("ImPlotRange",ImPlotRange)
--------------------------ImPlotRect----------------------------
local ImPlotRect= {}
ImPlotRect.__index = ImPlotRect
function ImPlotRect:Clamp_PlotPoInt(p)
    local nonUDT_out = ffi.new("ImPlotPoint")
    lib.ImPlotRect_Clamp_PlotPoInt(nonUDT_out,self,p)
    return nonUDT_out
end
function ImPlotRect:Clamp_double(x,y)
    local nonUDT_out = ffi.new("ImPlotPoint")
    lib.ImPlotRect_Clamp_double(nonUDT_out,self,x,y)
    return nonUDT_out
end
function ImPlotRect:Clamp(a3,a4) -- generic version
    if ffi.istype('const ImPlotPoint',a3) then return self:Clamp_PlotPoInt(a3) end
    if (ffi.istype('double',a3) or type(a3)=='number') then return self:Clamp_double(a3,a4) end
    print(a3,a4)
    error'ImPlotRect:Clamp could not find overloaded'
end
ImPlotRect.Contains_PlotPoInt = lib.ImPlotRect_Contains_PlotPoInt
ImPlotRect.Contains_double = lib.ImPlotRect_Contains_double
function ImPlotRect:Contains(a2,a3) -- generic version
    if ffi.istype('const ImPlotPoint',a2) then return self:Contains_PlotPoInt(a2) end
    if (ffi.istype('double',a2) or type(a2)=='number') then return self:Contains_double(a2,a3) end
    print(a2,a3)
    error'ImPlotRect:Contains could not find overloaded'
end
function ImPlotRect.ImPlotRect_Nil()
    local ptr = lib.ImPlotRect_ImPlotRect_Nil()
    return ffi.gc(ptr,lib.ImPlotRect_destroy)
end
function ImPlotRect.ImPlotRect_double(x_min,x_max,y_min,y_max)
    local ptr = lib.ImPlotRect_ImPlotRect_double(x_min,x_max,y_min,y_max)
    return ffi.gc(ptr,lib.ImPlotRect_destroy)
end
function ImPlotRect.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImPlotRect.ImPlotRect_Nil() end
    if (ffi.istype('double',a1) or type(a1)=='number') then return ImPlotRect.ImPlotRect_double(a1,a2,a3,a4) end
    print(ctype,a1,a2,a3,a4)
    error'ImPlotRect.__new could not find overloaded'
end
function ImPlotRect:Max()
    local nonUDT_out = ffi.new("ImPlotPoint")
    lib.ImPlotRect_Max(nonUDT_out,self)
    return nonUDT_out
end
function ImPlotRect:Min()
    local nonUDT_out = ffi.new("ImPlotPoint")
    lib.ImPlotRect_Min(nonUDT_out,self)
    return nonUDT_out
end
function ImPlotRect:Size()
    local nonUDT_out = ffi.new("ImPlotPoint")
    lib.ImPlotRect_Size(nonUDT_out,self)
    return nonUDT_out
end
M.ImPlotRect = ffi.metatype("ImPlotRect",ImPlotRect)
--------------------------ImPlotStyle----------------------------
local ImPlotStyle= {}
ImPlotStyle.__index = ImPlotStyle
function ImPlotStyle.__new(ctype)
    local ptr = lib.ImPlotStyle_ImPlotStyle()
    return ffi.gc(ptr,lib.ImPlotStyle_destroy)
end
M.ImPlotStyle = ffi.metatype("ImPlotStyle",ImPlotStyle)
--------------------------ImPlotSubplot----------------------------
local ImPlotSubplot= {}
ImPlotSubplot.__index = ImPlotSubplot
function ImPlotSubplot.__new(ctype)
    local ptr = lib.ImPlotSubplot_ImPlotSubplot()
    return ffi.gc(ptr,lib.ImPlotSubplot_destroy)
end
M.ImPlotSubplot = ffi.metatype("ImPlotSubplot",ImPlotSubplot)
--------------------------ImPlotTagCollection----------------------------
local ImPlotTagCollection= {}
ImPlotTagCollection.__index = ImPlotTagCollection
ImPlotTagCollection.Append = lib.ImPlotTagCollection_Append
ImPlotTagCollection.AppendV = lib.ImPlotTagCollection_AppendV
ImPlotTagCollection.GetText = lib.ImPlotTagCollection_GetText
function ImPlotTagCollection.__new(ctype)
    local ptr = lib.ImPlotTagCollection_ImPlotTagCollection()
    return ffi.gc(ptr,lib.ImPlotTagCollection_destroy)
end
ImPlotTagCollection.Reset = lib.ImPlotTagCollection_Reset
M.ImPlotTagCollection = ffi.metatype("ImPlotTagCollection",ImPlotTagCollection)
--------------------------ImPlotTick----------------------------
local ImPlotTick= {}
ImPlotTick.__index = ImPlotTick
function ImPlotTick.__new(ctype,value,major,level,show_label)
    local ptr = lib.ImPlotTick_ImPlotTick(value,major,level,show_label)
    return ffi.gc(ptr,lib.ImPlotTick_destroy)
end
M.ImPlotTick = ffi.metatype("ImPlotTick",ImPlotTick)
--------------------------ImPlotTicker----------------------------
local ImPlotTicker= {}
ImPlotTicker.__index = ImPlotTicker
ImPlotTicker.AddTick_doubleStr = lib.ImPlotTicker_AddTick_doubleStr
ImPlotTicker.AddTick_doublePlotFormatter = lib.ImPlotTicker_AddTick_doublePlotFormatter
ImPlotTicker.AddTick_PlotTick = lib.ImPlotTicker_AddTick_PlotTick
function ImPlotTicker:AddTick(a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('double',a2) or type(a2)=='number') and (ffi.istype('const char*',a6) or ffi.istype('char[]',a6) or type(a6)=='string') then return self:AddTick_doubleStr(a2,a3,a4,a5,a6) end
    if (ffi.istype('double',a2) or type(a2)=='number') and ffi.istype('ImPlotFormatter',a6) then return self:AddTick_doublePlotFormatter(a2,a3,a4,a5,a6,a7) end
    if ffi.istype('ImPlotTick',a2) then return self:AddTick_PlotTick(a2) end
    print(a2,a3,a4,a5,a6,a7)
    error'ImPlotTicker:AddTick could not find overloaded'
end
ImPlotTicker.GetText_Int = lib.ImPlotTicker_GetText_Int
ImPlotTicker.GetText_PlotTick = lib.ImPlotTicker_GetText_PlotTick
function ImPlotTicker:GetText(a2) -- generic version
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return self:GetText_Int(a2) end
    if ffi.istype('const ImPlotTick',a2) then return self:GetText_PlotTick(a2) end
    print(a2)
    error'ImPlotTicker:GetText could not find overloaded'
end
function ImPlotTicker.__new(ctype)
    local ptr = lib.ImPlotTicker_ImPlotTicker()
    return ffi.gc(ptr,lib.ImPlotTicker_destroy)
end
ImPlotTicker.OverrideSizeLate = lib.ImPlotTicker_OverrideSizeLate
ImPlotTicker.Reset = lib.ImPlotTicker_Reset
ImPlotTicker.TickCount = lib.ImPlotTicker_TickCount
M.ImPlotTicker = ffi.metatype("ImPlotTicker",ImPlotTicker)
--------------------------ImPlotTime----------------------------
local ImPlotTime= {}
ImPlotTime.__index = ImPlotTime
function M.ImPlotTime_FromDouble(t)
    local nonUDT_out = ffi.new("ImPlotTime")
    lib.ImPlotTime_FromDouble(nonUDT_out,t)
    return nonUDT_out
end
function ImPlotTime.ImPlotTime_Nil()
    local ptr = lib.ImPlotTime_ImPlotTime_Nil()
    return ffi.gc(ptr,lib.ImPlotTime_destroy)
end
function ImPlotTime.ImPlotTime_time_t(s,us)
    if us == nil then us = 0 end
    local ptr = lib.ImPlotTime_ImPlotTime_time_t(s,us)
    return ffi.gc(ptr,lib.ImPlotTime_destroy)
end
function ImPlotTime.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImPlotTime.ImPlotTime_Nil() end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return ImPlotTime.ImPlotTime_time_t(a1,a2) end
    print(ctype,a1,a2)
    error'ImPlotTime.__new could not find overloaded'
end
ImPlotTime.RollOver = lib.ImPlotTime_RollOver
ImPlotTime.ToDouble = lib.ImPlotTime_ToDouble
M.ImPlotTime = ffi.metatype("ImPlotTime",ImPlotTime)
--------------------------ImRect----------------------------
local ImRect= {}
ImRect.__index = ImRect
ImRect.Add_Vec2 = lib.ImRect_Add_Vec2
ImRect.Add_Rect = lib.ImRect_Add_Rect
function ImRect:Add(a2) -- generic version
    if ffi.istype('const ImVec2',a2) then return self:Add_Vec2(a2) end
    if ffi.istype('const ImRect',a2) then return self:Add_Rect(a2) end
    print(a2)
    error'ImRect:Add could not find overloaded'
end
ImRect.ClipWith = lib.ImRect_ClipWith
ImRect.ClipWithFull = lib.ImRect_ClipWithFull
ImRect.Contains_Vec2 = lib.ImRect_Contains_Vec2
ImRect.Contains_Rect = lib.ImRect_Contains_Rect
function ImRect:Contains(a2) -- generic version
    if ffi.istype('const ImVec2',a2) then return self:Contains_Vec2(a2) end
    if ffi.istype('const ImRect',a2) then return self:Contains_Rect(a2) end
    print(a2)
    error'ImRect:Contains could not find overloaded'
end
ImRect.ContainsWithPad = lib.ImRect_ContainsWithPad
ImRect.Expand_Float = lib.ImRect_Expand_Float
ImRect.Expand_Vec2 = lib.ImRect_Expand_Vec2
function ImRect:Expand(a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return self:Expand_Float(a2) end
    if ffi.istype('const ImVec2',a2) then return self:Expand_Vec2(a2) end
    print(a2)
    error'ImRect:Expand could not find overloaded'
end
ImRect.Floor = lib.ImRect_Floor
ImRect.GetArea = lib.ImRect_GetArea
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
function ImRect.ImRect_Nil()
    local ptr = lib.ImRect_ImRect_Nil()
    return ffi.gc(ptr,lib.ImRect_destroy)
end
function ImRect.ImRect_Vec2(min,max)
    local ptr = lib.ImRect_ImRect_Vec2(min,max)
    return ffi.gc(ptr,lib.ImRect_destroy)
end
function ImRect.ImRect_Vec4(v)
    local ptr = lib.ImRect_ImRect_Vec4(v)
    return ffi.gc(ptr,lib.ImRect_destroy)
end
function ImRect.ImRect_Float(x1,y1,x2,y2)
    local ptr = lib.ImRect_ImRect_Float(x1,y1,x2,y2)
    return ffi.gc(ptr,lib.ImRect_destroy)
end
function ImRect.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImRect.ImRect_Nil() end
    if ffi.istype('const ImVec2',a1) then return ImRect.ImRect_Vec2(a1,a2) end
    if ffi.istype('const ImVec4',a1) then return ImRect.ImRect_Vec4(a1) end
    if (ffi.istype('float',a1) or type(a1)=='number') then return ImRect.ImRect_Float(a1,a2,a3,a4) end
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
function ImVec1.ImVec1_Nil()
    local ptr = lib.ImVec1_ImVec1_Nil()
    return ffi.gc(ptr,lib.ImVec1_destroy)
end
function ImVec1.ImVec1_Float(_x)
    local ptr = lib.ImVec1_ImVec1_Float(_x)
    return ffi.gc(ptr,lib.ImVec1_destroy)
end
function ImVec1.__new(ctype,a1) -- generic version
    if a1==nil then return ImVec1.ImVec1_Nil() end
    if (ffi.istype('float',a1) or type(a1)=='number') then return ImVec1.ImVec1_Float(a1) end
    print(ctype,a1)
    error'ImVec1.__new could not find overloaded'
end
M.ImVec1 = ffi.metatype("ImVec1",ImVec1)
--------------------------ImVec2ih----------------------------
local ImVec2ih= {}
ImVec2ih.__index = ImVec2ih
function ImVec2ih.ImVec2ih_Nil()
    local ptr = lib.ImVec2ih_ImVec2ih_Nil()
    return ffi.gc(ptr,lib.ImVec2ih_destroy)
end
function ImVec2ih.ImVec2ih_short(_x,_y)
    local ptr = lib.ImVec2ih_ImVec2ih_short(_x,_y)
    return ffi.gc(ptr,lib.ImVec2ih_destroy)
end
function ImVec2ih.ImVec2ih_Vec2(rhs)
    local ptr = lib.ImVec2ih_ImVec2ih_Vec2(rhs)
    return ffi.gc(ptr,lib.ImVec2ih_destroy)
end
function ImVec2ih.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImVec2ih.ImVec2ih_Nil() end
    if (ffi.istype('int16_t',a1) or type(a1)=='number') then return ImVec2ih.ImVec2ih_short(a1,a2) end
    if ffi.istype('const ImVec2',a1) then return ImVec2ih.ImVec2ih_Vec2(a1) end
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
--------------------------MultipleSelectModifier----------------------------
local MultipleSelectModifier= {}
MultipleSelectModifier.__index = MultipleSelectModifier
function MultipleSelectModifier.__new(ctype)
    local ptr = lib.MultipleSelectModifier_MultipleSelectModifier()
    return ffi.gc(ptr,lib.MultipleSelectModifier_destroy)
end
M.MultipleSelectModifier = ffi.metatype("MultipleSelectModifier",MultipleSelectModifier)
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
imguiGizmo.getTransforms_vec3Ptr = lib.imguiGizmo_getTransforms_vec3Ptr
imguiGizmo.getTransforms_vec4Ptr = lib.imguiGizmo_getTransforms_vec4Ptr
function imguiGizmo:getTransforms(a2,a3,a4,a5) -- generic version
    if (ffi.istype('G3Dvec3*',a4) or ffi.istype('G3Dvec3',a4) or ffi.istype('G3Dvec3[]',a4)) then return self:getTransforms_vec3Ptr(a2,a3,a4,a5) end
    if (ffi.istype('G3Dvec4*',a4) or ffi.istype('G3Dvec4',a4) or ffi.istype('G3Dvec4[]',a4)) then return self:getTransforms_vec4Ptr(a2,a3,a4,a5) end
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
M.imguiGizmo_setDirectionColor_U32U32 = lib.imguiGizmo_setDirectionColor_U32U32
M.imguiGizmo_setDirectionColor_Vec4Vec4 = lib.imguiGizmo_setDirectionColor_Vec4Vec4
M.imguiGizmo_setDirectionColor_U32 = lib.imguiGizmo_setDirectionColor_U32
M.imguiGizmo_setDirectionColor_Vec4 = lib.imguiGizmo_setDirectionColor_Vec4
function M.imguiGizmo_setDirectionColor(a1,a2) -- generic version
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') and (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.imguiGizmo_setDirectionColor_U32U32(a1,a2) end
    if ffi.istype('const ImVec4',a1) and ffi.istype('const ImVec4',a2) then return M.imguiGizmo_setDirectionColor_Vec4Vec4(a1,a2) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') and a2==nil then return M.imguiGizmo_setDirectionColor_U32(a1) end
    if ffi.istype('const ImVec4',a1) and a2==nil then return M.imguiGizmo_setDirectionColor_Vec4(a1) end
    print(a1,a2)
    error'M.imguiGizmo_setDirectionColor could not find overloaded'
end
M.imguiGizmo_setDollyModifier = lib.imguiGizmo_setDollyModifier
M.imguiGizmo_setDollyScale = lib.imguiGizmo_setDollyScale
imguiGizmo.setDualMode = lib.imguiGizmo_setDualMode
M.imguiGizmo_setGizmoFeelingRot = lib.imguiGizmo_setGizmoFeelingRot
M.imguiGizmo_setPanModifier = lib.imguiGizmo_setPanModifier
M.imguiGizmo_setPanScale = lib.imguiGizmo_setPanScale
M.imguiGizmo_setSphereColors_Vec4 = lib.imguiGizmo_setSphereColors_Vec4
M.imguiGizmo_setSphereColors_U32 = lib.imguiGizmo_setSphereColors_U32
function M.imguiGizmo_setSphereColors(a1,a2) -- generic version
    if ffi.istype('const ImVec4',a1) then return M.imguiGizmo_setSphereColors_Vec4(a1,a2) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.imguiGizmo_setSphereColors_U32(a1,a2) end
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
M.ImGuizmo_GetStyle = lib.ImGuizmo_GetStyle
M.ImGuizmo_IsOver_Nil = lib.ImGuizmo_IsOver_Nil
M.ImGuizmo_IsOver_OPERATION = lib.ImGuizmo_IsOver_OPERATION
function M.ImGuizmo_IsOver(a1) -- generic version
    if a1==nil then return M.ImGuizmo_IsOver_Nil() end
    if ffi.istype('OPERATION',a1) then return M.ImGuizmo_IsOver_OPERATION(a1) end
    print(a1)
    error'M.ImGuizmo_IsOver could not find overloaded'
end
M.ImGuizmo_IsUsing = lib.ImGuizmo_IsUsing
M.ImGuizmo_IsUsingAny = lib.ImGuizmo_IsUsingAny
function M.ImGuizmo_Manipulate(view,projection,operation,mode,matrix,deltaMatrix,snap,localBounds,boundsSnap)
    boundsSnap = boundsSnap or nil
    deltaMatrix = deltaMatrix or nil
    localBounds = localBounds or nil
    snap = snap or nil
    return lib.ImGuizmo_Manipulate(view,projection,operation,mode,matrix,deltaMatrix,snap,localBounds,boundsSnap)
end
M.ImGuizmo_RecomposeMatrixFromComponents = lib.ImGuizmo_RecomposeMatrixFromComponents
M.ImGuizmo_SetAxisLimit = lib.ImGuizmo_SetAxisLimit
function M.ImGuizmo_SetDrawlist(drawlist)
    drawlist = drawlist or nil
    return lib.ImGuizmo_SetDrawlist(drawlist)
end
M.ImGuizmo_SetGizmoSizeClipSpace = lib.ImGuizmo_SetGizmoSizeClipSpace
M.ImGuizmo_SetID = lib.ImGuizmo_SetID
M.ImGuizmo_SetImGuiContext = lib.ImGuizmo_SetImGuiContext
M.ImGuizmo_SetOrthographic = lib.ImGuizmo_SetOrthographic
M.ImGuizmo_SetPlaneLimit = lib.ImGuizmo_SetPlaneLimit
M.ImGuizmo_SetRect = lib.ImGuizmo_SetRect
M.ImGuizmo_ViewManipulate_Float = lib.ImGuizmo_ViewManipulate_Float
M.ImGuizmo_ViewManipulate_FloatPtr = lib.ImGuizmo_ViewManipulate_FloatPtr
function M.ImGuizmo_ViewManipulate(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.ImGuizmo_ViewManipulate_Float(a1,a2,a3,a4,a5) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImGuizmo_ViewManipulate_FloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.ImGuizmo_ViewManipulate could not find overloaded'
end
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
M.ImNodes_Ez_BeginCanvas = lib.ImNodes_Ez_BeginCanvas
M.ImNodes_Ez_BeginNode = lib.ImNodes_Ez_BeginNode
M.ImNodes_Ez_Connection = lib.ImNodes_Ez_Connection
M.ImNodes_Ez_CreateContext = lib.ImNodes_Ez_CreateContext
M.ImNodes_Ez_EndCanvas = lib.ImNodes_Ez_EndCanvas
M.ImNodes_Ez_EndNode = lib.ImNodes_Ez_EndNode
M.ImNodes_Ez_FreeContext = lib.ImNodes_Ez_FreeContext
M.ImNodes_Ez_GetState = lib.ImNodes_Ez_GetState
M.ImNodes_Ez_InputSlots = lib.ImNodes_Ez_InputSlots
M.ImNodes_Ez_OutputSlots = lib.ImNodes_Ez_OutputSlots
M.ImNodes_Ez_PopStyleColor = lib.ImNodes_Ez_PopStyleColor
function M.ImNodes_Ez_PopStyleVar(count)
    count = count or 1
    return lib.ImNodes_Ez_PopStyleVar(count)
end
M.ImNodes_Ez_PushStyleColor_U32 = lib.ImNodes_Ez_PushStyleColor_U32
M.ImNodes_Ez_PushStyleColor_Vec4 = lib.ImNodes_Ez_PushStyleColor_Vec4
function M.ImNodes_Ez_PushStyleColor(a1,a2) -- generic version
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.ImNodes_Ez_PushStyleColor_U32(a1,a2) end
    if ffi.istype('const ImVec4',a2) then return M.ImNodes_Ez_PushStyleColor_Vec4(a1,a2) end
    print(a1,a2)
    error'M.ImNodes_Ez_PushStyleColor could not find overloaded'
end
M.ImNodes_Ez_PushStyleVar_Float = lib.ImNodes_Ez_PushStyleVar_Float
M.ImNodes_Ez_PushStyleVar_Vec2 = lib.ImNodes_Ez_PushStyleVar_Vec2
function M.ImNodes_Ez_PushStyleVar(a1,a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.ImNodes_Ez_PushStyleVar_Float(a1,a2) end
    if ffi.istype('const ImVec2',a2) then return M.ImNodes_Ez_PushStyleVar_Vec2(a1,a2) end
    print(a1,a2)
    error'M.ImNodes_Ez_PushStyleVar could not find overloaded'
end
M.ImNodes_Ez_SetContext = lib.ImNodes_Ez_SetContext
M.ImNodes_GetCurrentCanvas = lib.ImNodes_GetCurrentCanvas
M.ImNodes_GetNewConnection = lib.ImNodes_GetNewConnection
M.ImNodes_GetPendingConnection = lib.ImNodes_GetPendingConnection
M.ImNodes_InputSlotKind = lib.ImNodes_InputSlotKind
M.ImNodes_IsConnectingCompatibleSlot = lib.ImNodes_IsConnectingCompatibleSlot
M.ImNodes_IsInputSlotKind = lib.ImNodes_IsInputSlotKind
M.ImNodes_IsNodeHovered = lib.ImNodes_IsNodeHovered
M.ImNodes_IsOutputSlotKind = lib.ImNodes_IsOutputSlotKind
M.ImNodes_IsSlotCurveHovered = lib.ImNodes_IsSlotCurveHovered
M.ImNodes_OutputSlotKind = lib.ImNodes_OutputSlotKind
function M.ImPlot_AddColormap_Vec4Ptr(name,cols,size,qual)
    if qual == nil then qual = true end
    return lib.ImPlot_AddColormap_Vec4Ptr(name,cols,size,qual)
end
function M.ImPlot_AddColormap_U32Ptr(name,cols,size,qual)
    if qual == nil then qual = true end
    return lib.ImPlot_AddColormap_U32Ptr(name,cols,size,qual)
end
function M.ImPlot_AddColormap(a1,a2,a3,a4) -- generic version
    if (ffi.istype('const ImVec4*',a2) or ffi.istype('const ImVec4',a2) or ffi.istype('const ImVec4[]',a2)) then return M.ImPlot_AddColormap_Vec4Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_AddColormap_U32Ptr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_AddColormap could not find overloaded'
end
function M.ImPlot_AddTextCentered(DrawList,top_center,col,text_begin,text_end)
    text_end = text_end or nil
    return lib.ImPlot_AddTextCentered(DrawList,top_center,col,text_begin,text_end)
end
function M.ImPlot_AddTextVertical(DrawList,pos,col,text_begin,text_end)
    text_end = text_end or nil
    return lib.ImPlot_AddTextVertical(DrawList,pos,col,text_begin,text_end)
end
function M.ImPlot_AddTime(t,unit,count)
    local nonUDT_out = ffi.new("ImPlotTime")
    lib.ImPlot_AddTime(nonUDT_out,t,unit,count)
    return nonUDT_out
end
M.ImPlot_AllAxesInputLocked = lib.ImPlot_AllAxesInputLocked
function M.ImPlot_Annotation_Bool(x,y,col,pix_offset,clamp,round)
    round = round or false
    return lib.ImPlot_Annotation_Bool(x,y,col,pix_offset,clamp,round)
end
M.ImPlot_Annotation_Str = lib.ImPlot_Annotation_Str
function M.ImPlot_Annotation(a1,a2,a3,a4,a5,a6,...) -- generic version
    if ((ffi.istype('bool',a6) or type(a6)=='boolean') or type(a6)=='nil') then return M.ImPlot_Annotation_Bool(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const char*',a6) or ffi.istype('char[]',a6) or type(a6)=='string') then return M.ImPlot_Annotation_Str(a1,a2,a3,a4,a5,a6,...) end
    print(a1,a2,a3,a4,a5,a6,...)
    error'M.ImPlot_Annotation could not find overloaded'
end
M.ImPlot_AnnotationV = lib.ImPlot_AnnotationV
M.ImPlot_AnyAxesHeld = lib.ImPlot_AnyAxesHeld
M.ImPlot_AnyAxesHovered = lib.ImPlot_AnyAxesHovered
M.ImPlot_AnyAxesInputLocked = lib.ImPlot_AnyAxesInputLocked
function M.ImPlot_BeginAlignedPlots(group_id,vertical)
    if vertical == nil then vertical = true end
    return lib.ImPlot_BeginAlignedPlots(group_id,vertical)
end
function M.ImPlot_BeginDragDropSourceAxis(axis,flags)
    flags = flags or 0
    return lib.ImPlot_BeginDragDropSourceAxis(axis,flags)
end
function M.ImPlot_BeginDragDropSourceItem(label_id,flags)
    flags = flags or 0
    return lib.ImPlot_BeginDragDropSourceItem(label_id,flags)
end
function M.ImPlot_BeginDragDropSourcePlot(flags)
    flags = flags or 0
    return lib.ImPlot_BeginDragDropSourcePlot(flags)
end
M.ImPlot_BeginDragDropTargetAxis = lib.ImPlot_BeginDragDropTargetAxis
M.ImPlot_BeginDragDropTargetLegend = lib.ImPlot_BeginDragDropTargetLegend
M.ImPlot_BeginDragDropTargetPlot = lib.ImPlot_BeginDragDropTargetPlot
function M.ImPlot_BeginItem(label_id,flags,recolor_from)
    flags = flags or 0
    recolor_from = recolor_from or -1
    return lib.ImPlot_BeginItem(label_id,flags,recolor_from)
end
function M.ImPlot_BeginLegendPopup(label_id,mouse_button)
    mouse_button = mouse_button or 1
    return lib.ImPlot_BeginLegendPopup(label_id,mouse_button)
end
function M.ImPlot_BeginPlot(title_id,size,flags)
    flags = flags or 0
    size = size or ImVec2(-1,0)
    return lib.ImPlot_BeginPlot(title_id,size,flags)
end
function M.ImPlot_BeginSubplots(title_id,rows,cols,size,flags,row_ratios,col_ratios)
    col_ratios = col_ratios or nil
    flags = flags or 0
    row_ratios = row_ratios or nil
    return lib.ImPlot_BeginSubplots(title_id,rows,cols,size,flags,row_ratios,col_ratios)
end
function M.ImPlot_BustColorCache(plot_title_id)
    plot_title_id = plot_title_id or nil
    return lib.ImPlot_BustColorCache(plot_title_id)
end
M.ImPlot_BustItemCache = lib.ImPlot_BustItemCache
M.ImPlot_BustPlotCache = lib.ImPlot_BustPlotCache
M.ImPlot_CalcHoverColor = lib.ImPlot_CalcHoverColor
function M.ImPlot_CalcLegendSize(items,pad,spacing,vertical)
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_CalcLegendSize(nonUDT_out,items,pad,spacing,vertical)
    return nonUDT_out
end
M.ImPlot_CalcTextColor_Vec4 = lib.ImPlot_CalcTextColor_Vec4
M.ImPlot_CalcTextColor_U32 = lib.ImPlot_CalcTextColor_U32
function M.ImPlot_CalcTextColor(a1) -- generic version
    if ffi.istype('const ImVec4',a1) then return M.ImPlot_CalcTextColor_Vec4(a1) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.ImPlot_CalcTextColor_U32(a1) end
    print(a1)
    error'M.ImPlot_CalcTextColor could not find overloaded'
end
function M.ImPlot_CalcTextSizeVertical(text)
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_CalcTextSizeVertical(nonUDT_out,text)
    return nonUDT_out
end
M.ImPlot_CalculateBins_FloatPtr = lib.ImPlot_CalculateBins_FloatPtr
M.ImPlot_CalculateBins_doublePtr = lib.ImPlot_CalculateBins_doublePtr
M.ImPlot_CalculateBins_S8Ptr = lib.ImPlot_CalculateBins_S8Ptr
M.ImPlot_CalculateBins_U8Ptr = lib.ImPlot_CalculateBins_U8Ptr
M.ImPlot_CalculateBins_S16Ptr = lib.ImPlot_CalculateBins_S16Ptr
M.ImPlot_CalculateBins_U16Ptr = lib.ImPlot_CalculateBins_U16Ptr
M.ImPlot_CalculateBins_S32Ptr = lib.ImPlot_CalculateBins_S32Ptr
M.ImPlot_CalculateBins_U32Ptr = lib.ImPlot_CalculateBins_U32Ptr
M.ImPlot_CalculateBins_S64Ptr = lib.ImPlot_CalculateBins_S64Ptr
M.ImPlot_CalculateBins_U64Ptr = lib.ImPlot_CalculateBins_U64Ptr
function M.ImPlot_CalculateBins(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_CalculateBins_FloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_CalculateBins_doublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_CalculateBins_S8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_CalculateBins_U8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_CalculateBins_S16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_CalculateBins_U16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_CalculateBins_S32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_CalculateBins_U32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_CalculateBins_S64Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_CalculateBins_U64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot_CalculateBins could not find overloaded'
end
M.ImPlot_CancelPlotSelection = lib.ImPlot_CancelPlotSelection
function M.ImPlot_CeilTime(t,unit)
    local nonUDT_out = ffi.new("ImPlotTime")
    lib.ImPlot_CeilTime(nonUDT_out,t,unit)
    return nonUDT_out
end
function M.ImPlot_ClampLabelPos(pos,size,Min,Max)
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_ClampLabelPos(nonUDT_out,pos,size,Min,Max)
    return nonUDT_out
end
M.ImPlot_ClampLegendRect = lib.ImPlot_ClampLegendRect
function M.ImPlot_ColormapButton(label,size,cmap)
    cmap = cmap or -1
    size = size or ImVec2(0,0)
    return lib.ImPlot_ColormapButton(label,size,cmap)
end
M.ImPlot_ColormapIcon = lib.ImPlot_ColormapIcon
function M.ImPlot_ColormapScale(label,scale_min,scale_max,size,format,flags,cmap)
    cmap = cmap or -1
    flags = flags or 0
    format = format or "%g"
    size = size or ImVec2(0,0)
    return lib.ImPlot_ColormapScale(label,scale_min,scale_max,size,format,flags,cmap)
end
function M.ImPlot_ColormapSlider(label,t,out,format,cmap)
    cmap = cmap or -1
    format = format or ""
    out = out or nil
    return lib.ImPlot_ColormapSlider(label,t,out,format,cmap)
end
function M.ImPlot_CombineDateTime(date_part,time_part)
    local nonUDT_out = ffi.new("ImPlotTime")
    lib.ImPlot_CombineDateTime(nonUDT_out,date_part,time_part)
    return nonUDT_out
end
M.ImPlot_CreateContext = lib.ImPlot_CreateContext
function M.ImPlot_DestroyContext(ctx)
    ctx = ctx or nil
    return lib.ImPlot_DestroyContext(ctx)
end
function M.ImPlot_DragLineX(id,x,col,thickness,flags,out_clicked,out_hovered,held)
    flags = flags or 0
    held = held or nil
    out_clicked = out_clicked or nil
    out_hovered = out_hovered or nil
    thickness = thickness or 1
    return lib.ImPlot_DragLineX(id,x,col,thickness,flags,out_clicked,out_hovered,held)
end
function M.ImPlot_DragLineY(id,y,col,thickness,flags,out_clicked,out_hovered,held)
    flags = flags or 0
    held = held or nil
    out_clicked = out_clicked or nil
    out_hovered = out_hovered or nil
    thickness = thickness or 1
    return lib.ImPlot_DragLineY(id,y,col,thickness,flags,out_clicked,out_hovered,held)
end
function M.ImPlot_DragPoint(id,x,y,col,size,flags,out_clicked,out_hovered,held)
    flags = flags or 0
    held = held or nil
    out_clicked = out_clicked or nil
    out_hovered = out_hovered or nil
    size = size or 4
    return lib.ImPlot_DragPoint(id,x,y,col,size,flags,out_clicked,out_hovered,held)
end
function M.ImPlot_DragRect(id,x1,y1,x2,y2,col,flags,out_clicked,out_hovered,held)
    flags = flags or 0
    held = held or nil
    out_clicked = out_clicked or nil
    out_hovered = out_hovered or nil
    return lib.ImPlot_DragRect(id,x1,y1,x2,y2,col,flags,out_clicked,out_hovered,held)
end
M.ImPlot_EndAlignedPlots = lib.ImPlot_EndAlignedPlots
M.ImPlot_EndDragDropSource = lib.ImPlot_EndDragDropSource
M.ImPlot_EndDragDropTarget = lib.ImPlot_EndDragDropTarget
M.ImPlot_EndItem = lib.ImPlot_EndItem
M.ImPlot_EndLegendPopup = lib.ImPlot_EndLegendPopup
M.ImPlot_EndPlot = lib.ImPlot_EndPlot
M.ImPlot_EndSubplots = lib.ImPlot_EndSubplots
M.ImPlot_FillRange_Vector_Float_Ptr = lib.ImPlot_FillRange_Vector_Float_Ptr
M.ImPlot_FillRange_Vector_double_Ptr = lib.ImPlot_FillRange_Vector_double_Ptr
M.ImPlot_FillRange_Vector_S8_Ptr = lib.ImPlot_FillRange_Vector_S8_Ptr
M.ImPlot_FillRange_Vector_U8_Ptr = lib.ImPlot_FillRange_Vector_U8_Ptr
M.ImPlot_FillRange_Vector_S16_Ptr = lib.ImPlot_FillRange_Vector_S16_Ptr
M.ImPlot_FillRange_Vector_U16_Ptr = lib.ImPlot_FillRange_Vector_U16_Ptr
M.ImPlot_FillRange_Vector_S32_Ptr = lib.ImPlot_FillRange_Vector_S32_Ptr
M.ImPlot_FillRange_Vector_U32_Ptr = lib.ImPlot_FillRange_Vector_U32_Ptr
M.ImPlot_FillRange_Vector_S64_Ptr = lib.ImPlot_FillRange_Vector_S64_Ptr
M.ImPlot_FillRange_Vector_U64_Ptr = lib.ImPlot_FillRange_Vector_U64_Ptr
function M.ImPlot_FillRange(a1,a2,a3,a4) -- generic version
    if (ffi.istype('ImVector_float *',a1) or ffi.istype('ImVector_float ',a1) or ffi.istype('ImVector_float []',a1)) then return M.ImPlot_FillRange_Vector_Float_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_double *',a1) or ffi.istype('ImVector_double ',a1) or ffi.istype('ImVector_double []',a1)) then return M.ImPlot_FillRange_Vector_double_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImS8 *',a1) or ffi.istype('ImVector_ImS8 ',a1) or ffi.istype('ImVector_ImS8 []',a1)) then return M.ImPlot_FillRange_Vector_S8_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImU8 *',a1) or ffi.istype('ImVector_ImU8 ',a1) or ffi.istype('ImVector_ImU8 []',a1)) then return M.ImPlot_FillRange_Vector_U8_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImS16 *',a1) or ffi.istype('ImVector_ImS16 ',a1) or ffi.istype('ImVector_ImS16 []',a1)) then return M.ImPlot_FillRange_Vector_S16_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImU16 *',a1) or ffi.istype('ImVector_ImU16 ',a1) or ffi.istype('ImVector_ImU16 []',a1)) then return M.ImPlot_FillRange_Vector_U16_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImS32 *',a1) or ffi.istype('ImVector_ImS32 ',a1) or ffi.istype('ImVector_ImS32 []',a1)) then return M.ImPlot_FillRange_Vector_S32_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImU32 *',a1) or ffi.istype('ImVector_ImU32 ',a1) or ffi.istype('ImVector_ImU32 []',a1)) then return M.ImPlot_FillRange_Vector_U32_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImS64 *',a1) or ffi.istype('ImVector_ImS64 ',a1) or ffi.istype('ImVector_ImS64 []',a1)) then return M.ImPlot_FillRange_Vector_S64_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImU64 *',a1) or ffi.istype('ImVector_ImU64 ',a1) or ffi.istype('ImVector_ImU64 []',a1)) then return M.ImPlot_FillRange_Vector_U64_Ptr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_FillRange could not find overloaded'
end
M.ImPlot_FitPoint = lib.ImPlot_FitPoint
M.ImPlot_FitPointX = lib.ImPlot_FitPointX
M.ImPlot_FitPointY = lib.ImPlot_FitPointY
M.ImPlot_FitThisFrame = lib.ImPlot_FitThisFrame
function M.ImPlot_FloorTime(t,unit)
    local nonUDT_out = ffi.new("ImPlotTime")
    lib.ImPlot_FloorTime(nonUDT_out,t,unit)
    return nonUDT_out
end
M.ImPlot_FormatDate = lib.ImPlot_FormatDate
M.ImPlot_FormatDateTime = lib.ImPlot_FormatDateTime
M.ImPlot_FormatTime = lib.ImPlot_FormatTime
M.ImPlot_Formatter_Default = lib.ImPlot_Formatter_Default
M.ImPlot_Formatter_Logit = lib.ImPlot_Formatter_Logit
M.ImPlot_Formatter_Time = lib.ImPlot_Formatter_Time
function M.ImPlot_GetAutoColor(idx)
    local nonUDT_out = ffi.new("ImVec4")
    lib.ImPlot_GetAutoColor(nonUDT_out,idx)
    return nonUDT_out
end
function M.ImPlot_GetColormapColor(idx,cmap)
    cmap = cmap or -1
    local nonUDT_out = ffi.new("ImVec4")
    lib.ImPlot_GetColormapColor(nonUDT_out,idx,cmap)
    return nonUDT_out
end
M.ImPlot_GetColormapColorU32 = lib.ImPlot_GetColormapColorU32
M.ImPlot_GetColormapCount = lib.ImPlot_GetColormapCount
M.ImPlot_GetColormapIndex = lib.ImPlot_GetColormapIndex
M.ImPlot_GetColormapName = lib.ImPlot_GetColormapName
function M.ImPlot_GetColormapSize(cmap)
    cmap = cmap or -1
    return lib.ImPlot_GetColormapSize(cmap)
end
M.ImPlot_GetCurrentContext = lib.ImPlot_GetCurrentContext
M.ImPlot_GetCurrentItem = lib.ImPlot_GetCurrentItem
M.ImPlot_GetCurrentPlot = lib.ImPlot_GetCurrentPlot
M.ImPlot_GetDaysInMonth = lib.ImPlot_GetDaysInMonth
M.ImPlot_GetGmtTime = lib.ImPlot_GetGmtTime
M.ImPlot_GetInputMap = lib.ImPlot_GetInputMap
M.ImPlot_GetItem = lib.ImPlot_GetItem
M.ImPlot_GetItemData = lib.ImPlot_GetItemData
function M.ImPlot_GetLastItemColor()
    local nonUDT_out = ffi.new("ImVec4")
    lib.ImPlot_GetLastItemColor(nonUDT_out)
    return nonUDT_out
end
M.ImPlot_GetLocTime = lib.ImPlot_GetLocTime
function M.ImPlot_GetLocationPos(outer_rect,inner_size,location,pad)
    pad = pad or ImVec2(0,0)
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_GetLocationPos(nonUDT_out,outer_rect,inner_size,location,pad)
    return nonUDT_out
end
M.ImPlot_GetMarkerName = lib.ImPlot_GetMarkerName
M.ImPlot_GetPlot = lib.ImPlot_GetPlot
M.ImPlot_GetPlotDrawList = lib.ImPlot_GetPlotDrawList
function M.ImPlot_GetPlotLimits(x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImPlotRect")
    lib.ImPlot_GetPlotLimits(nonUDT_out,x_axis,y_axis)
    return nonUDT_out
end
function M.ImPlot_GetPlotMousePos(x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImPlotPoint")
    lib.ImPlot_GetPlotMousePos(nonUDT_out,x_axis,y_axis)
    return nonUDT_out
end
function M.ImPlot_GetPlotPos()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_GetPlotPos(nonUDT_out)
    return nonUDT_out
end
function M.ImPlot_GetPlotSelection(x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImPlotRect")
    lib.ImPlot_GetPlotSelection(nonUDT_out,x_axis,y_axis)
    return nonUDT_out
end
function M.ImPlot_GetPlotSize()
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_GetPlotSize(nonUDT_out)
    return nonUDT_out
end
M.ImPlot_GetStyle = lib.ImPlot_GetStyle
M.ImPlot_GetStyleColorName = lib.ImPlot_GetStyleColorName
M.ImPlot_GetStyleColorU32 = lib.ImPlot_GetStyleColorU32
function M.ImPlot_GetStyleColorVec4(idx)
    local nonUDT_out = ffi.new("ImVec4")
    lib.ImPlot_GetStyleColorVec4(nonUDT_out,idx)
    return nonUDT_out
end
M.ImPlot_GetYear = lib.ImPlot_GetYear
function M.ImPlot_HideNextItem(hidden,cond)
    cond = cond or 2
    if hidden == nil then hidden = true end
    return lib.ImPlot_HideNextItem(hidden,cond)
end
function M.ImPlot_ImAlmostEqual(v1,v2,ulp)
    ulp = ulp or 2
    return lib.ImPlot_ImAlmostEqual(v1,v2,ulp)
end
M.ImPlot_ImAlphaU32 = lib.ImPlot_ImAlphaU32
M.ImPlot_ImAsinh_Float = lib.ImPlot_ImAsinh_Float
M.ImPlot_ImAsinh_double = lib.ImPlot_ImAsinh_double
function M.ImPlot_ImAsinh(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_ImAsinh_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_ImAsinh_double(a1) end
    print(a1)
    error'M.ImPlot_ImAsinh could not find overloaded'
end
M.ImPlot_ImConstrainInf = lib.ImPlot_ImConstrainInf
M.ImPlot_ImConstrainLog = lib.ImPlot_ImConstrainLog
M.ImPlot_ImConstrainNan = lib.ImPlot_ImConstrainNan
M.ImPlot_ImConstrainTime = lib.ImPlot_ImConstrainTime
M.ImPlot_ImLerpU32 = lib.ImPlot_ImLerpU32
M.ImPlot_ImLog10_Float = lib.ImPlot_ImLog10_Float
M.ImPlot_ImLog10_double = lib.ImPlot_ImLog10_double
function M.ImPlot_ImLog10(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_ImLog10_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_ImLog10_double(a1) end
    print(a1)
    error'M.ImPlot_ImLog10 could not find overloaded'
end
M.ImPlot_ImMaxArray_FloatPtr = lib.ImPlot_ImMaxArray_FloatPtr
M.ImPlot_ImMaxArray_doublePtr = lib.ImPlot_ImMaxArray_doublePtr
M.ImPlot_ImMaxArray_S8Ptr = lib.ImPlot_ImMaxArray_S8Ptr
M.ImPlot_ImMaxArray_U8Ptr = lib.ImPlot_ImMaxArray_U8Ptr
M.ImPlot_ImMaxArray_S16Ptr = lib.ImPlot_ImMaxArray_S16Ptr
M.ImPlot_ImMaxArray_U16Ptr = lib.ImPlot_ImMaxArray_U16Ptr
M.ImPlot_ImMaxArray_S32Ptr = lib.ImPlot_ImMaxArray_S32Ptr
M.ImPlot_ImMaxArray_U32Ptr = lib.ImPlot_ImMaxArray_U32Ptr
M.ImPlot_ImMaxArray_S64Ptr = lib.ImPlot_ImMaxArray_S64Ptr
M.ImPlot_ImMaxArray_U64Ptr = lib.ImPlot_ImMaxArray_U64Ptr
function M.ImPlot_ImMaxArray(a1,a2) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_ImMaxArray_FloatPtr(a1,a2) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_ImMaxArray_doublePtr(a1,a2) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_ImMaxArray_S8Ptr(a1,a2) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_U8Ptr(a1,a2) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_S16Ptr(a1,a2) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_U16Ptr(a1,a2) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_S32Ptr(a1,a2) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_U32Ptr(a1,a2) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_S64Ptr(a1,a2) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_U64Ptr(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_ImMaxArray could not find overloaded'
end
M.ImPlot_ImMean_FloatPtr = lib.ImPlot_ImMean_FloatPtr
M.ImPlot_ImMean_doublePtr = lib.ImPlot_ImMean_doublePtr
M.ImPlot_ImMean_S8Ptr = lib.ImPlot_ImMean_S8Ptr
M.ImPlot_ImMean_U8Ptr = lib.ImPlot_ImMean_U8Ptr
M.ImPlot_ImMean_S16Ptr = lib.ImPlot_ImMean_S16Ptr
M.ImPlot_ImMean_U16Ptr = lib.ImPlot_ImMean_U16Ptr
M.ImPlot_ImMean_S32Ptr = lib.ImPlot_ImMean_S32Ptr
M.ImPlot_ImMean_U32Ptr = lib.ImPlot_ImMean_U32Ptr
M.ImPlot_ImMean_S64Ptr = lib.ImPlot_ImMean_S64Ptr
M.ImPlot_ImMean_U64Ptr = lib.ImPlot_ImMean_U64Ptr
function M.ImPlot_ImMean(a1,a2) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_ImMean_FloatPtr(a1,a2) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_ImMean_doublePtr(a1,a2) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_ImMean_S8Ptr(a1,a2) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_U8Ptr(a1,a2) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_S16Ptr(a1,a2) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_U16Ptr(a1,a2) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_S32Ptr(a1,a2) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_U32Ptr(a1,a2) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_S64Ptr(a1,a2) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_U64Ptr(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_ImMean could not find overloaded'
end
M.ImPlot_ImMinArray_FloatPtr = lib.ImPlot_ImMinArray_FloatPtr
M.ImPlot_ImMinArray_doublePtr = lib.ImPlot_ImMinArray_doublePtr
M.ImPlot_ImMinArray_S8Ptr = lib.ImPlot_ImMinArray_S8Ptr
M.ImPlot_ImMinArray_U8Ptr = lib.ImPlot_ImMinArray_U8Ptr
M.ImPlot_ImMinArray_S16Ptr = lib.ImPlot_ImMinArray_S16Ptr
M.ImPlot_ImMinArray_U16Ptr = lib.ImPlot_ImMinArray_U16Ptr
M.ImPlot_ImMinArray_S32Ptr = lib.ImPlot_ImMinArray_S32Ptr
M.ImPlot_ImMinArray_U32Ptr = lib.ImPlot_ImMinArray_U32Ptr
M.ImPlot_ImMinArray_S64Ptr = lib.ImPlot_ImMinArray_S64Ptr
M.ImPlot_ImMinArray_U64Ptr = lib.ImPlot_ImMinArray_U64Ptr
function M.ImPlot_ImMinArray(a1,a2) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_ImMinArray_FloatPtr(a1,a2) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_ImMinArray_doublePtr(a1,a2) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_ImMinArray_S8Ptr(a1,a2) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_U8Ptr(a1,a2) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_S16Ptr(a1,a2) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_U16Ptr(a1,a2) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_S32Ptr(a1,a2) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_U32Ptr(a1,a2) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_S64Ptr(a1,a2) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_U64Ptr(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_ImMinArray could not find overloaded'
end
M.ImPlot_ImMinMaxArray_FloatPtr = lib.ImPlot_ImMinMaxArray_FloatPtr
M.ImPlot_ImMinMaxArray_doublePtr = lib.ImPlot_ImMinMaxArray_doublePtr
M.ImPlot_ImMinMaxArray_S8Ptr = lib.ImPlot_ImMinMaxArray_S8Ptr
M.ImPlot_ImMinMaxArray_U8Ptr = lib.ImPlot_ImMinMaxArray_U8Ptr
M.ImPlot_ImMinMaxArray_S16Ptr = lib.ImPlot_ImMinMaxArray_S16Ptr
M.ImPlot_ImMinMaxArray_U16Ptr = lib.ImPlot_ImMinMaxArray_U16Ptr
M.ImPlot_ImMinMaxArray_S32Ptr = lib.ImPlot_ImMinMaxArray_S32Ptr
M.ImPlot_ImMinMaxArray_U32Ptr = lib.ImPlot_ImMinMaxArray_U32Ptr
M.ImPlot_ImMinMaxArray_S64Ptr = lib.ImPlot_ImMinMaxArray_S64Ptr
M.ImPlot_ImMinMaxArray_U64Ptr = lib.ImPlot_ImMinMaxArray_U64Ptr
function M.ImPlot_ImMinMaxArray(a1,a2,a3,a4) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_ImMinMaxArray_FloatPtr(a1,a2,a3,a4) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_ImMinMaxArray_doublePtr(a1,a2,a3,a4) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_ImMinMaxArray_S8Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_U8Ptr(a1,a2,a3,a4) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_S16Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_U16Ptr(a1,a2,a3,a4) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_S32Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_U32Ptr(a1,a2,a3,a4) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_S64Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_U64Ptr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_ImMinMaxArray could not find overloaded'
end
M.ImPlot_ImMixU32 = lib.ImPlot_ImMixU32
M.ImPlot_ImNan = lib.ImPlot_ImNan
M.ImPlot_ImNanOrInf = lib.ImPlot_ImNanOrInf
M.ImPlot_ImOverlaps_Float = lib.ImPlot_ImOverlaps_Float
M.ImPlot_ImOverlaps_double = lib.ImPlot_ImOverlaps_double
M.ImPlot_ImOverlaps_S8 = lib.ImPlot_ImOverlaps_S8
M.ImPlot_ImOverlaps_U8 = lib.ImPlot_ImOverlaps_U8
M.ImPlot_ImOverlaps_S16 = lib.ImPlot_ImOverlaps_S16
M.ImPlot_ImOverlaps_U16 = lib.ImPlot_ImOverlaps_U16
M.ImPlot_ImOverlaps_S32 = lib.ImPlot_ImOverlaps_S32
M.ImPlot_ImOverlaps_U32 = lib.ImPlot_ImOverlaps_U32
M.ImPlot_ImOverlaps_S64 = lib.ImPlot_ImOverlaps_S64
M.ImPlot_ImOverlaps_U64 = lib.ImPlot_ImOverlaps_U64
function M.ImPlot_ImOverlaps(a1,a2,a3,a4) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_Float(a1,a2,a3,a4) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_double(a1,a2,a3,a4) end
    if (ffi.istype('int8_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_S8(a1,a2,a3,a4) end
    if (ffi.istype('uint8_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_U8(a1,a2,a3,a4) end
    if (ffi.istype('int16_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_S16(a1,a2,a3,a4) end
    if (ffi.istype('uint16_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_U16(a1,a2,a3,a4) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_S32(a1,a2,a3,a4) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_U32(a1,a2,a3,a4) end
    if (ffi.istype('int64_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_S64(a1,a2,a3,a4) end
    if (ffi.istype('uint64_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_U64(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_ImOverlaps could not find overloaded'
end
M.ImPlot_ImPosMod = lib.ImPlot_ImPosMod
M.ImPlot_ImRemap_Float = lib.ImPlot_ImRemap_Float
M.ImPlot_ImRemap_double = lib.ImPlot_ImRemap_double
M.ImPlot_ImRemap_S8 = lib.ImPlot_ImRemap_S8
M.ImPlot_ImRemap_U8 = lib.ImPlot_ImRemap_U8
M.ImPlot_ImRemap_S16 = lib.ImPlot_ImRemap_S16
M.ImPlot_ImRemap_U16 = lib.ImPlot_ImRemap_U16
M.ImPlot_ImRemap_S32 = lib.ImPlot_ImRemap_S32
M.ImPlot_ImRemap_U32 = lib.ImPlot_ImRemap_U32
M.ImPlot_ImRemap_S64 = lib.ImPlot_ImRemap_S64
M.ImPlot_ImRemap_U64 = lib.ImPlot_ImRemap_U64
function M.ImPlot_ImRemap(a1,a2,a3,a4,a5) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_Float(a1,a2,a3,a4,a5) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_double(a1,a2,a3,a4,a5) end
    if (ffi.istype('int8_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_S8(a1,a2,a3,a4,a5) end
    if (ffi.istype('uint8_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_U8(a1,a2,a3,a4,a5) end
    if (ffi.istype('int16_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_S16(a1,a2,a3,a4,a5) end
    if (ffi.istype('uint16_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_U16(a1,a2,a3,a4,a5) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_S32(a1,a2,a3,a4,a5) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_U32(a1,a2,a3,a4,a5) end
    if (ffi.istype('int64_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_S64(a1,a2,a3,a4,a5) end
    if (ffi.istype('uint64_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_U64(a1,a2,a3,a4,a5) end
    print(a1,a2,a3,a4,a5)
    error'M.ImPlot_ImRemap could not find overloaded'
end
M.ImPlot_ImRemap01_Float = lib.ImPlot_ImRemap01_Float
M.ImPlot_ImRemap01_double = lib.ImPlot_ImRemap01_double
M.ImPlot_ImRemap01_S8 = lib.ImPlot_ImRemap01_S8
M.ImPlot_ImRemap01_U8 = lib.ImPlot_ImRemap01_U8
M.ImPlot_ImRemap01_S16 = lib.ImPlot_ImRemap01_S16
M.ImPlot_ImRemap01_U16 = lib.ImPlot_ImRemap01_U16
M.ImPlot_ImRemap01_S32 = lib.ImPlot_ImRemap01_S32
M.ImPlot_ImRemap01_U32 = lib.ImPlot_ImRemap01_U32
M.ImPlot_ImRemap01_S64 = lib.ImPlot_ImRemap01_S64
M.ImPlot_ImRemap01_U64 = lib.ImPlot_ImRemap01_U64
function M.ImPlot_ImRemap01(a1,a2,a3) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_Float(a1,a2,a3) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_double(a1,a2,a3) end
    if (ffi.istype('int8_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_S8(a1,a2,a3) end
    if (ffi.istype('uint8_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_U8(a1,a2,a3) end
    if (ffi.istype('int16_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_S16(a1,a2,a3) end
    if (ffi.istype('uint16_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_U16(a1,a2,a3) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_S32(a1,a2,a3) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_U32(a1,a2,a3) end
    if (ffi.istype('int64_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_S64(a1,a2,a3) end
    if (ffi.istype('uint64_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_U64(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.ImPlot_ImRemap01 could not find overloaded'
end
M.ImPlot_ImSinh_Float = lib.ImPlot_ImSinh_Float
M.ImPlot_ImSinh_double = lib.ImPlot_ImSinh_double
function M.ImPlot_ImSinh(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_ImSinh_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_ImSinh_double(a1) end
    print(a1)
    error'M.ImPlot_ImSinh could not find overloaded'
end
M.ImPlot_ImStdDev_FloatPtr = lib.ImPlot_ImStdDev_FloatPtr
M.ImPlot_ImStdDev_doublePtr = lib.ImPlot_ImStdDev_doublePtr
M.ImPlot_ImStdDev_S8Ptr = lib.ImPlot_ImStdDev_S8Ptr
M.ImPlot_ImStdDev_U8Ptr = lib.ImPlot_ImStdDev_U8Ptr
M.ImPlot_ImStdDev_S16Ptr = lib.ImPlot_ImStdDev_S16Ptr
M.ImPlot_ImStdDev_U16Ptr = lib.ImPlot_ImStdDev_U16Ptr
M.ImPlot_ImStdDev_S32Ptr = lib.ImPlot_ImStdDev_S32Ptr
M.ImPlot_ImStdDev_U32Ptr = lib.ImPlot_ImStdDev_U32Ptr
M.ImPlot_ImStdDev_S64Ptr = lib.ImPlot_ImStdDev_S64Ptr
M.ImPlot_ImStdDev_U64Ptr = lib.ImPlot_ImStdDev_U64Ptr
function M.ImPlot_ImStdDev(a1,a2) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_ImStdDev_FloatPtr(a1,a2) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_ImStdDev_doublePtr(a1,a2) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_ImStdDev_S8Ptr(a1,a2) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_U8Ptr(a1,a2) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_S16Ptr(a1,a2) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_U16Ptr(a1,a2) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_S32Ptr(a1,a2) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_U32Ptr(a1,a2) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_S64Ptr(a1,a2) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_U64Ptr(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_ImStdDev could not find overloaded'
end
M.ImPlot_ImSum_FloatPtr = lib.ImPlot_ImSum_FloatPtr
M.ImPlot_ImSum_doublePtr = lib.ImPlot_ImSum_doublePtr
M.ImPlot_ImSum_S8Ptr = lib.ImPlot_ImSum_S8Ptr
M.ImPlot_ImSum_U8Ptr = lib.ImPlot_ImSum_U8Ptr
M.ImPlot_ImSum_S16Ptr = lib.ImPlot_ImSum_S16Ptr
M.ImPlot_ImSum_U16Ptr = lib.ImPlot_ImSum_U16Ptr
M.ImPlot_ImSum_S32Ptr = lib.ImPlot_ImSum_S32Ptr
M.ImPlot_ImSum_U32Ptr = lib.ImPlot_ImSum_U32Ptr
M.ImPlot_ImSum_S64Ptr = lib.ImPlot_ImSum_S64Ptr
M.ImPlot_ImSum_U64Ptr = lib.ImPlot_ImSum_U64Ptr
function M.ImPlot_ImSum(a1,a2) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_ImSum_FloatPtr(a1,a2) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_ImSum_doublePtr(a1,a2) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_ImSum_S8Ptr(a1,a2) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_U8Ptr(a1,a2) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_S16Ptr(a1,a2) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_U16Ptr(a1,a2) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_S32Ptr(a1,a2) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_U32Ptr(a1,a2) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_S64Ptr(a1,a2) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_U64Ptr(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_ImSum could not find overloaded'
end
M.ImPlot_Initialize = lib.ImPlot_Initialize
function M.ImPlot_Intersection(a1,a2,b1,b2)
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_Intersection(nonUDT_out,a1,a2,b1,b2)
    return nonUDT_out
end
M.ImPlot_IsAxisHovered = lib.ImPlot_IsAxisHovered
M.ImPlot_IsColorAuto_Vec4 = lib.ImPlot_IsColorAuto_Vec4
M.ImPlot_IsColorAuto_PlotCol = lib.ImPlot_IsColorAuto_PlotCol
function M.ImPlot_IsColorAuto(a1) -- generic version
    if ffi.istype('const ImVec4',a1) then return M.ImPlot_IsColorAuto_Vec4(a1) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImPlot_IsColorAuto_PlotCol(a1) end
    print(a1)
    error'M.ImPlot_IsColorAuto could not find overloaded'
end
M.ImPlot_IsLeapYear = lib.ImPlot_IsLeapYear
M.ImPlot_IsLegendEntryHovered = lib.ImPlot_IsLegendEntryHovered
M.ImPlot_IsPlotHovered = lib.ImPlot_IsPlotHovered
M.ImPlot_IsPlotSelected = lib.ImPlot_IsPlotSelected
M.ImPlot_IsSubplotsHovered = lib.ImPlot_IsSubplotsHovered
M.ImPlot_ItemIcon_Vec4 = lib.ImPlot_ItemIcon_Vec4
M.ImPlot_ItemIcon_U32 = lib.ImPlot_ItemIcon_U32
function M.ImPlot_ItemIcon(a1) -- generic version
    if ffi.istype('const ImVec4',a1) then return M.ImPlot_ItemIcon_Vec4(a1) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.ImPlot_ItemIcon_U32(a1) end
    print(a1)
    error'M.ImPlot_ItemIcon could not find overloaded'
end
function M.ImPlot_LabelAxisValue(axis,value,buff,size,round)
    round = round or false
    return lib.ImPlot_LabelAxisValue(axis,value,buff,size,round)
end
M.ImPlot_Locator_Default = lib.ImPlot_Locator_Default
M.ImPlot_Locator_Log10 = lib.ImPlot_Locator_Log10
M.ImPlot_Locator_SymLog = lib.ImPlot_Locator_SymLog
M.ImPlot_Locator_Time = lib.ImPlot_Locator_Time
function M.ImPlot_MakeTime(year,month,day,hour,min,sec,us)
    day = day or 1
    hour = hour or 0
    min = min or 0
    month = month or 0
    sec = sec or 0
    us = us or 0
    local nonUDT_out = ffi.new("ImPlotTime")
    lib.ImPlot_MakeTime(nonUDT_out,year,month,day,hour,min,sec,us)
    return nonUDT_out
end
function M.ImPlot_MapInputDefault(dst)
    dst = dst or nil
    return lib.ImPlot_MapInputDefault(dst)
end
function M.ImPlot_MapInputReverse(dst)
    dst = dst or nil
    return lib.ImPlot_MapInputReverse(dst)
end
function M.ImPlot_MkGmtTime(ptm)
    local nonUDT_out = ffi.new("ImPlotTime")
    lib.ImPlot_MkGmtTime(nonUDT_out,ptm)
    return nonUDT_out
end
function M.ImPlot_MkLocTime(ptm)
    local nonUDT_out = ffi.new("ImPlotTime")
    lib.ImPlot_MkLocTime(nonUDT_out,ptm)
    return nonUDT_out
end
function M.ImPlot_NextColormapColor()
    local nonUDT_out = ffi.new("ImVec4")
    lib.ImPlot_NextColormapColor(nonUDT_out)
    return nonUDT_out
end
M.ImPlot_NextColormapColorU32 = lib.ImPlot_NextColormapColorU32
M.ImPlot_NiceNum = lib.ImPlot_NiceNum
M.ImPlot_OrderOfMagnitude = lib.ImPlot_OrderOfMagnitude
M.ImPlot_OrderToPrecision = lib.ImPlot_OrderToPrecision
function M.ImPlot_PixelsToPlot_Vec2(pix,x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImPlotPoint")
    lib.ImPlot_PixelsToPlot_Vec2(nonUDT_out,pix,x_axis,y_axis)
    return nonUDT_out
end
function M.ImPlot_PixelsToPlot_Float(x,y,x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImPlotPoint")
    lib.ImPlot_PixelsToPlot_Float(nonUDT_out,x,y,x_axis,y_axis)
    return nonUDT_out
end
function M.ImPlot_PixelsToPlot(a2,a3,a4,a5) -- generic version
    if ffi.istype('const ImVec2',a2) then return M.ImPlot_PixelsToPlot_Vec2(a2,a3,a4) end
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.ImPlot_PixelsToPlot_Float(a2,a3,a4,a5) end
    print(a2,a3,a4,a5)
    error'M.ImPlot_PixelsToPlot could not find overloaded'
end
function M.ImPlot_PlotBarGroups_FloatPtr(label_ids,values,item_count,group_count,group_size,shift,flags)
    flags = flags or 0
    group_size = group_size or 0.67
    shift = shift or 0
    return lib.ImPlot_PlotBarGroups_FloatPtr(label_ids,values,item_count,group_count,group_size,shift,flags)
end
function M.ImPlot_PlotBarGroups_doublePtr(label_ids,values,item_count,group_count,group_size,shift,flags)
    flags = flags or 0
    group_size = group_size or 0.67
    shift = shift or 0
    return lib.ImPlot_PlotBarGroups_doublePtr(label_ids,values,item_count,group_count,group_size,shift,flags)
end
function M.ImPlot_PlotBarGroups_S8Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
    flags = flags or 0
    group_size = group_size or 0.67
    shift = shift or 0
    return lib.ImPlot_PlotBarGroups_S8Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
end
function M.ImPlot_PlotBarGroups_U8Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
    flags = flags or 0
    group_size = group_size or 0.67
    shift = shift or 0
    return lib.ImPlot_PlotBarGroups_U8Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
end
function M.ImPlot_PlotBarGroups_S16Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
    flags = flags or 0
    group_size = group_size or 0.67
    shift = shift or 0
    return lib.ImPlot_PlotBarGroups_S16Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
end
function M.ImPlot_PlotBarGroups_U16Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
    flags = flags or 0
    group_size = group_size or 0.67
    shift = shift or 0
    return lib.ImPlot_PlotBarGroups_U16Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
end
function M.ImPlot_PlotBarGroups_S32Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
    flags = flags or 0
    group_size = group_size or 0.67
    shift = shift or 0
    return lib.ImPlot_PlotBarGroups_S32Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
end
function M.ImPlot_PlotBarGroups_U32Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
    flags = flags or 0
    group_size = group_size or 0.67
    shift = shift or 0
    return lib.ImPlot_PlotBarGroups_U32Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
end
function M.ImPlot_PlotBarGroups_S64Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
    flags = flags or 0
    group_size = group_size or 0.67
    shift = shift or 0
    return lib.ImPlot_PlotBarGroups_S64Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
end
function M.ImPlot_PlotBarGroups_U64Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
    flags = flags or 0
    group_size = group_size or 0.67
    shift = shift or 0
    return lib.ImPlot_PlotBarGroups_U64Ptr(label_ids,values,item_count,group_count,group_size,shift,flags)
end
function M.ImPlot_PlotBarGroups(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotBarGroups_FloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotBarGroups_doublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotBarGroups_S8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_U8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_S16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_U16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_S32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_U32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_S64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_U64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotBarGroups could not find overloaded'
end
function M.ImPlot_PlotBars_FloatPtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
    bar_size = bar_size or 0.67
    flags = flags or 0
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotBars_FloatPtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
end
function M.ImPlot_PlotBars_doublePtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
    bar_size = bar_size or 0.67
    flags = flags or 0
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotBars_doublePtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
end
function M.ImPlot_PlotBars_S8PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
    bar_size = bar_size or 0.67
    flags = flags or 0
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotBars_S8PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
end
function M.ImPlot_PlotBars_U8PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
    bar_size = bar_size or 0.67
    flags = flags or 0
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotBars_U8PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
end
function M.ImPlot_PlotBars_S16PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
    bar_size = bar_size or 0.67
    flags = flags or 0
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotBars_S16PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
end
function M.ImPlot_PlotBars_U16PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
    bar_size = bar_size or 0.67
    flags = flags or 0
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotBars_U16PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
end
function M.ImPlot_PlotBars_S32PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
    bar_size = bar_size or 0.67
    flags = flags or 0
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotBars_S32PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
end
function M.ImPlot_PlotBars_U32PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
    bar_size = bar_size or 0.67
    flags = flags or 0
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotBars_U32PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
end
function M.ImPlot_PlotBars_S64PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
    bar_size = bar_size or 0.67
    flags = flags or 0
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotBars_S64PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
end
function M.ImPlot_PlotBars_U64PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
    bar_size = bar_size or 0.67
    flags = flags or 0
    offset = offset or 0
    shift = shift or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotBars_U64PtrInt(label_id,values,count,bar_size,shift,flags,offset,stride)
end
function M.ImPlot_PlotBars_FloatPtrFloatPtr(label_id,xs,ys,count,bar_size,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotBars_FloatPtrFloatPtr(label_id,xs,ys,count,bar_size,flags,offset,stride)
end
function M.ImPlot_PlotBars_doublePtrdoublePtr(label_id,xs,ys,count,bar_size,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotBars_doublePtrdoublePtr(label_id,xs,ys,count,bar_size,flags,offset,stride)
end
function M.ImPlot_PlotBars_S8PtrS8Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotBars_S8PtrS8Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
end
function M.ImPlot_PlotBars_U8PtrU8Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotBars_U8PtrU8Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
end
function M.ImPlot_PlotBars_S16PtrS16Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotBars_S16PtrS16Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
end
function M.ImPlot_PlotBars_U16PtrU16Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotBars_U16PtrU16Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
end
function M.ImPlot_PlotBars_S32PtrS32Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotBars_S32PtrS32Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
end
function M.ImPlot_PlotBars_U32PtrU32Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotBars_U32PtrU32Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
end
function M.ImPlot_PlotBars_S64PtrS64Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotBars_S64PtrS64Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
end
function M.ImPlot_PlotBars_U64PtrU64Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotBars_U64PtrU64Ptr(label_id,xs,ys,count,bar_size,flags,offset,stride)
end
function M.ImPlot_PlotBars(a1,a2,a3,a4,a5,a6,a7,a8) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_FloatPtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_doublePtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_S8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_U8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_S16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_U16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_S32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_U32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_S64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_U64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotBars_FloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotBars_doublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotBars_S8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_U8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_S16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_U16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_S32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_U32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_S64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_U64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    print(a1,a2,a3,a4,a5,a6,a7,a8)
    error'M.ImPlot_PlotBars could not find overloaded'
end
function M.ImPlot_PlotBarsG(label_id,getter,data,count,bar_size,flags)
    flags = flags or 0
    return lib.ImPlot_PlotBarsG(label_id,getter,data,count,bar_size,flags)
end
function M.ImPlot_PlotDigital_FloatPtr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotDigital_FloatPtr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotDigital_doublePtr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotDigital_doublePtr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotDigital_S8Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotDigital_S8Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotDigital_U8Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotDigital_U8Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotDigital_S16Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotDigital_S16Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotDigital_U16Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotDigital_U16Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotDigital_S32Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotDigital_S32Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotDigital_U32Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotDigital_U32Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotDigital_S64Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotDigital_S64Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotDigital_U64Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotDigital_U64Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotDigital(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotDigital_FloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotDigital_doublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotDigital_S8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_U8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_S16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_U16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_S32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_U32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_S64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_U64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotDigital could not find overloaded'
end
function M.ImPlot_PlotDigitalG(label_id,getter,data,count,flags)
    flags = flags or 0
    return lib.ImPlot_PlotDigitalG(label_id,getter,data,count,flags)
end
function M.ImPlot_PlotDummy(label_id,flags)
    flags = flags or 0
    return lib.ImPlot_PlotDummy(label_id,flags)
end
function M.ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrInt(label_id,xs,ys,err,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrInt(label_id,xs,ys,err,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrInt(label_id,xs,ys,err,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrInt(label_id,xs,ys,err,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_S8PtrS8PtrS8PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotErrorBars_S8PtrS8PtrS8PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_U8PtrU8PtrU8PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotErrorBars_U8PtrU8PtrU8PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_S16PtrS16PtrS16PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotErrorBars_S16PtrS16PtrS16PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_U16PtrU16PtrU16PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotErrorBars_U16PtrU16PtrU16PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_S32PtrS32PtrS32PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotErrorBars_S32PtrS32PtrS32PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_U32PtrU32PtrU32PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotErrorBars_U32PtrU32PtrU32PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_S64PtrS64PtrS64PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotErrorBars_S64PtrS64PtrS64PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_U64PtrU64PtrU64PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotErrorBars_U64PtrU64PtrU64PtrInt(label_id,xs,ys,err,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrFloatPtr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrFloatPtr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrdoublePtr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrdoublePtr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_S8PtrS8PtrS8PtrS8Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotErrorBars_S8PtrS8PtrS8PtrS8Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_U8PtrU8PtrU8PtrU8Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotErrorBars_U8PtrU8PtrU8PtrU8Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_S16PtrS16PtrS16PtrS16Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotErrorBars_S16PtrS16PtrS16PtrS16Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_U16PtrU16PtrU16PtrU16Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotErrorBars_U16PtrU16PtrU16PtrU16Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_S32PtrS32PtrS32PtrS32Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotErrorBars_S32PtrS32PtrS32PtrS32Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_U32PtrU32PtrU32PtrU32Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotErrorBars_U32PtrU32PtrU32PtrU32Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_S64PtrS64PtrS64PtrS64Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotErrorBars_S64PtrS64PtrS64PtrS64Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars_U64PtrU64PtrU64PtrU64Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotErrorBars_U64PtrU64PtrU64PtrU64Ptr(label_id,xs,ys,neg,pos,count,flags,offset,stride)
end
function M.ImPlot_PlotErrorBars(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('float*',a4) or ffi.istype('float[]',a4)) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('double*',a4) or ffi.istype('double[]',a4)) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('const ImS8*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_S8PtrS8PtrS8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) and ffi.typeof('uint8_t*') == ffi.typeof(a4) or ffi.typeof('const uint8_t*') == ffi.typeof(a4) or ffi.typeof('uint8_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_U8PtrU8PtrU8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) and ffi.typeof('int16_t*') == ffi.typeof(a4) or ffi.typeof('const int16_t*') == ffi.typeof(a4) or ffi.typeof('int16_t[?]') == ffi.typeof(a4) or ffi.typeof('const int16_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_S16PtrS16PtrS16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) and ffi.typeof('uint16_t*') == ffi.typeof(a4) or ffi.typeof('const uint16_t*') == ffi.typeof(a4) or ffi.typeof('uint16_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_U16PtrU16PtrU16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) and ffi.typeof('int32_t*') == ffi.typeof(a4) or ffi.typeof('const int32_t*') == ffi.typeof(a4) or ffi.typeof('int32_t[?]') == ffi.typeof(a4) or ffi.typeof('const int32_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_S32PtrS32PtrS32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) and ffi.typeof('uint32_t*') == ffi.typeof(a4) or ffi.typeof('const uint32_t*') == ffi.typeof(a4) or ffi.typeof('uint32_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_U32PtrU32PtrU32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) and ffi.typeof('int64_t*') == ffi.typeof(a4) or ffi.typeof('const int64_t*') == ffi.typeof(a4) or ffi.typeof('int64_t[?]') == ffi.typeof(a4) or ffi.typeof('const int64_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_S64PtrS64PtrS64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) and ffi.typeof('uint64_t*') == ffi.typeof(a4) or ffi.typeof('const uint64_t*') == ffi.typeof(a4) or ffi.typeof('uint64_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_U64PtrU64PtrU64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('float*',a4) or ffi.istype('float[]',a4)) and (ffi.istype('float*',a5) or ffi.istype('float[]',a5)) then return M.ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('double*',a4) or ffi.istype('double[]',a4)) and (ffi.istype('double*',a5) or ffi.istype('double[]',a5)) then return M.ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('const ImS8*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') and (ffi.istype('const ImS8*',a5) or ffi.istype('char[]',a5) or type(a5)=='string') then return M.ImPlot_PlotErrorBars_S8PtrS8PtrS8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) and ffi.typeof('uint8_t*') == ffi.typeof(a4) or ffi.typeof('const uint8_t*') == ffi.typeof(a4) or ffi.typeof('uint8_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a4) and ffi.typeof('uint8_t*') == ffi.typeof(a5) or ffi.typeof('const uint8_t*') == ffi.typeof(a5) or ffi.typeof('uint8_t[?]') == ffi.typeof(a5) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_U8PtrU8PtrU8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) and ffi.typeof('int16_t*') == ffi.typeof(a4) or ffi.typeof('const int16_t*') == ffi.typeof(a4) or ffi.typeof('int16_t[?]') == ffi.typeof(a4) or ffi.typeof('const int16_t[?]') == ffi.typeof(a4) and ffi.typeof('int16_t*') == ffi.typeof(a5) or ffi.typeof('const int16_t*') == ffi.typeof(a5) or ffi.typeof('int16_t[?]') == ffi.typeof(a5) or ffi.typeof('const int16_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_S16PtrS16PtrS16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) and ffi.typeof('uint16_t*') == ffi.typeof(a4) or ffi.typeof('const uint16_t*') == ffi.typeof(a4) or ffi.typeof('uint16_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a4) and ffi.typeof('uint16_t*') == ffi.typeof(a5) or ffi.typeof('const uint16_t*') == ffi.typeof(a5) or ffi.typeof('uint16_t[?]') == ffi.typeof(a5) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_U16PtrU16PtrU16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) and ffi.typeof('int32_t*') == ffi.typeof(a4) or ffi.typeof('const int32_t*') == ffi.typeof(a4) or ffi.typeof('int32_t[?]') == ffi.typeof(a4) or ffi.typeof('const int32_t[?]') == ffi.typeof(a4) and ffi.typeof('int32_t*') == ffi.typeof(a5) or ffi.typeof('const int32_t*') == ffi.typeof(a5) or ffi.typeof('int32_t[?]') == ffi.typeof(a5) or ffi.typeof('const int32_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_S32PtrS32PtrS32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) and ffi.typeof('uint32_t*') == ffi.typeof(a4) or ffi.typeof('const uint32_t*') == ffi.typeof(a4) or ffi.typeof('uint32_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a4) and ffi.typeof('uint32_t*') == ffi.typeof(a5) or ffi.typeof('const uint32_t*') == ffi.typeof(a5) or ffi.typeof('uint32_t[?]') == ffi.typeof(a5) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_U32PtrU32PtrU32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) and ffi.typeof('int64_t*') == ffi.typeof(a4) or ffi.typeof('const int64_t*') == ffi.typeof(a4) or ffi.typeof('int64_t[?]') == ffi.typeof(a4) or ffi.typeof('const int64_t[?]') == ffi.typeof(a4) and ffi.typeof('int64_t*') == ffi.typeof(a5) or ffi.typeof('const int64_t*') == ffi.typeof(a5) or ffi.typeof('int64_t[?]') == ffi.typeof(a5) or ffi.typeof('const int64_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_S64PtrS64PtrS64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) and ffi.typeof('uint64_t*') == ffi.typeof(a4) or ffi.typeof('const uint64_t*') == ffi.typeof(a4) or ffi.typeof('uint64_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a4) and ffi.typeof('uint64_t*') == ffi.typeof(a5) or ffi.typeof('const uint64_t*') == ffi.typeof(a5) or ffi.typeof('uint64_t[?]') == ffi.typeof(a5) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_U64PtrU64PtrU64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.ImPlot_PlotErrorBars could not find overloaded'
end
function M.ImPlot_PlotHeatmap_FloatPtr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    return lib.ImPlot_PlotHeatmap_FloatPtr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
end
function M.ImPlot_PlotHeatmap_doublePtr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    return lib.ImPlot_PlotHeatmap_doublePtr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
end
function M.ImPlot_PlotHeatmap_S8Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    return lib.ImPlot_PlotHeatmap_S8Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
end
function M.ImPlot_PlotHeatmap_U8Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    return lib.ImPlot_PlotHeatmap_U8Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
end
function M.ImPlot_PlotHeatmap_S16Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    return lib.ImPlot_PlotHeatmap_S16Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
end
function M.ImPlot_PlotHeatmap_U16Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    return lib.ImPlot_PlotHeatmap_U16Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
end
function M.ImPlot_PlotHeatmap_S32Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    return lib.ImPlot_PlotHeatmap_S32Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
end
function M.ImPlot_PlotHeatmap_U32Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    return lib.ImPlot_PlotHeatmap_U32Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
end
function M.ImPlot_PlotHeatmap_S64Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    return lib.ImPlot_PlotHeatmap_S64Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
end
function M.ImPlot_PlotHeatmap_U64Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    return lib.ImPlot_PlotHeatmap_U64Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,flags)
end
function M.ImPlot_PlotHeatmap(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotHeatmap_FloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotHeatmap_doublePtr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotHeatmap_S8Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_U8Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_S16Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_U16Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_S32Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_U32Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_S64Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_U64Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
    error'M.ImPlot_PlotHeatmap could not find overloaded'
end
function M.ImPlot_PlotHistogram_FloatPtr(label_id,values,count,bins,bar_scale,range,flags)
    bar_scale = bar_scale or 1
    bins = bins or -2
    flags = flags or 0
    range = range or ImPlotRange()
    return lib.ImPlot_PlotHistogram_FloatPtr(label_id,values,count,bins,bar_scale,range,flags)
end
function M.ImPlot_PlotHistogram_doublePtr(label_id,values,count,bins,bar_scale,range,flags)
    bar_scale = bar_scale or 1
    bins = bins or -2
    flags = flags or 0
    range = range or ImPlotRange()
    return lib.ImPlot_PlotHistogram_doublePtr(label_id,values,count,bins,bar_scale,range,flags)
end
function M.ImPlot_PlotHistogram_S8Ptr(label_id,values,count,bins,bar_scale,range,flags)
    bar_scale = bar_scale or 1
    bins = bins or -2
    flags = flags or 0
    range = range or ImPlotRange()
    return lib.ImPlot_PlotHistogram_S8Ptr(label_id,values,count,bins,bar_scale,range,flags)
end
function M.ImPlot_PlotHistogram_U8Ptr(label_id,values,count,bins,bar_scale,range,flags)
    bar_scale = bar_scale or 1
    bins = bins or -2
    flags = flags or 0
    range = range or ImPlotRange()
    return lib.ImPlot_PlotHistogram_U8Ptr(label_id,values,count,bins,bar_scale,range,flags)
end
function M.ImPlot_PlotHistogram_S16Ptr(label_id,values,count,bins,bar_scale,range,flags)
    bar_scale = bar_scale or 1
    bins = bins or -2
    flags = flags or 0
    range = range or ImPlotRange()
    return lib.ImPlot_PlotHistogram_S16Ptr(label_id,values,count,bins,bar_scale,range,flags)
end
function M.ImPlot_PlotHistogram_U16Ptr(label_id,values,count,bins,bar_scale,range,flags)
    bar_scale = bar_scale or 1
    bins = bins or -2
    flags = flags or 0
    range = range or ImPlotRange()
    return lib.ImPlot_PlotHistogram_U16Ptr(label_id,values,count,bins,bar_scale,range,flags)
end
function M.ImPlot_PlotHistogram_S32Ptr(label_id,values,count,bins,bar_scale,range,flags)
    bar_scale = bar_scale or 1
    bins = bins or -2
    flags = flags or 0
    range = range or ImPlotRange()
    return lib.ImPlot_PlotHistogram_S32Ptr(label_id,values,count,bins,bar_scale,range,flags)
end
function M.ImPlot_PlotHistogram_U32Ptr(label_id,values,count,bins,bar_scale,range,flags)
    bar_scale = bar_scale or 1
    bins = bins or -2
    flags = flags or 0
    range = range or ImPlotRange()
    return lib.ImPlot_PlotHistogram_U32Ptr(label_id,values,count,bins,bar_scale,range,flags)
end
function M.ImPlot_PlotHistogram_S64Ptr(label_id,values,count,bins,bar_scale,range,flags)
    bar_scale = bar_scale or 1
    bins = bins or -2
    flags = flags or 0
    range = range or ImPlotRange()
    return lib.ImPlot_PlotHistogram_S64Ptr(label_id,values,count,bins,bar_scale,range,flags)
end
function M.ImPlot_PlotHistogram_U64Ptr(label_id,values,count,bins,bar_scale,range,flags)
    bar_scale = bar_scale or 1
    bins = bins or -2
    flags = flags or 0
    range = range or ImPlotRange()
    return lib.ImPlot_PlotHistogram_U64Ptr(label_id,values,count,bins,bar_scale,range,flags)
end
function M.ImPlot_PlotHistogram(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotHistogram_FloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotHistogram_doublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotHistogram_S8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_U8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_S16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_U16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_S32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_U32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_S64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_U64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotHistogram could not find overloaded'
end
function M.ImPlot_PlotHistogram2D_FloatPtr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
    flags = flags or 0
    range = range or ImPlotRect()
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_FloatPtr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
end
function M.ImPlot_PlotHistogram2D_doublePtr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
    flags = flags or 0
    range = range or ImPlotRect()
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_doublePtr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
end
function M.ImPlot_PlotHistogram2D_S8Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
    flags = flags or 0
    range = range or ImPlotRect()
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_S8Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
end
function M.ImPlot_PlotHistogram2D_U8Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
    flags = flags or 0
    range = range or ImPlotRect()
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_U8Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
end
function M.ImPlot_PlotHistogram2D_S16Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
    flags = flags or 0
    range = range or ImPlotRect()
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_S16Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
end
function M.ImPlot_PlotHistogram2D_U16Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
    flags = flags or 0
    range = range or ImPlotRect()
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_U16Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
end
function M.ImPlot_PlotHistogram2D_S32Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
    flags = flags or 0
    range = range or ImPlotRect()
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_S32Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
end
function M.ImPlot_PlotHistogram2D_U32Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
    flags = flags or 0
    range = range or ImPlotRect()
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_U32Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
end
function M.ImPlot_PlotHistogram2D_S64Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
    flags = flags or 0
    range = range or ImPlotRect()
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_S64Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
end
function M.ImPlot_PlotHistogram2D_U64Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
    flags = flags or 0
    range = range or ImPlotRect()
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_U64Ptr(label_id,xs,ys,count,x_bins,y_bins,range,flags)
end
function M.ImPlot_PlotHistogram2D(a1,a2,a3,a4,a5,a6,a7,a8) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotHistogram2D_FloatPtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotHistogram2D_doublePtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotHistogram2D_S8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_U8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_S16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_U16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_S32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_U32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_S64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_U64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    print(a1,a2,a3,a4,a5,a6,a7,a8)
    error'M.ImPlot_PlotHistogram2D could not find overloaded'
end
function M.ImPlot_PlotImage(label_id,user_texture_id,bounds_min,bounds_max,uv0,uv1,tint_col,flags)
    flags = flags or 0
    tint_col = tint_col or ImVec4(1,1,1,1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,1)
    return lib.ImPlot_PlotImage(label_id,user_texture_id,bounds_min,bounds_max,uv0,uv1,tint_col,flags)
end
function M.ImPlot_PlotInfLines_FloatPtr(label_id,values,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotInfLines_FloatPtr(label_id,values,count,flags,offset,stride)
end
function M.ImPlot_PlotInfLines_doublePtr(label_id,values,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotInfLines_doublePtr(label_id,values,count,flags,offset,stride)
end
function M.ImPlot_PlotInfLines_S8Ptr(label_id,values,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotInfLines_S8Ptr(label_id,values,count,flags,offset,stride)
end
function M.ImPlot_PlotInfLines_U8Ptr(label_id,values,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotInfLines_U8Ptr(label_id,values,count,flags,offset,stride)
end
function M.ImPlot_PlotInfLines_S16Ptr(label_id,values,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotInfLines_S16Ptr(label_id,values,count,flags,offset,stride)
end
function M.ImPlot_PlotInfLines_U16Ptr(label_id,values,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotInfLines_U16Ptr(label_id,values,count,flags,offset,stride)
end
function M.ImPlot_PlotInfLines_S32Ptr(label_id,values,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotInfLines_S32Ptr(label_id,values,count,flags,offset,stride)
end
function M.ImPlot_PlotInfLines_U32Ptr(label_id,values,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotInfLines_U32Ptr(label_id,values,count,flags,offset,stride)
end
function M.ImPlot_PlotInfLines_S64Ptr(label_id,values,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotInfLines_S64Ptr(label_id,values,count,flags,offset,stride)
end
function M.ImPlot_PlotInfLines_U64Ptr(label_id,values,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotInfLines_U64Ptr(label_id,values,count,flags,offset,stride)
end
function M.ImPlot_PlotInfLines(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotInfLines_FloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotInfLines_doublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotInfLines_S8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_U8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_S16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_U16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_S32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_U32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_S64Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_U64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot_PlotInfLines could not find overloaded'
end
function M.ImPlot_PlotLine_FloatPtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_FloatPtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotLine_doublePtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_doublePtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotLine_S8PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_S8PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotLine_U8PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_U8PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotLine_S16PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_S16PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotLine_U16PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_U16PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotLine_S32PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_S32PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotLine_U32PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_U32PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotLine_S64PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_S64PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotLine_U64PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_U64PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotLine_FloatPtrFloatPtr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotLine_FloatPtrFloatPtr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotLine_doublePtrdoublePtr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotLine_doublePtrdoublePtr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotLine_S8PtrS8Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotLine_S8PtrS8Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotLine_U8PtrU8Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotLine_U8PtrU8Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotLine_S16PtrS16Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotLine_S16PtrS16Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotLine_U16PtrU16Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotLine_U16PtrU16Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotLine_S32PtrS32Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotLine_S32PtrS32Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotLine_U32PtrU32Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotLine_U32PtrU32Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotLine_S64PtrS64Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotLine_S64PtrS64Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotLine_U64PtrU64Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotLine_U64PtrU64Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotLine(a1,a2,a3,a4,a5,a6,a7,a8) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_FloatPtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_doublePtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_S8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_U8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_S16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_U16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_S32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_U32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_S64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_U64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotLine_FloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotLine_doublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotLine_S8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_U8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_S16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_U16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_S32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_U32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_S64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_U64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7,a8)
    error'M.ImPlot_PlotLine could not find overloaded'
end
function M.ImPlot_PlotLineG(label_id,getter,data,count,flags)
    flags = flags or 0
    return lib.ImPlot_PlotLineG(label_id,getter,data,count,flags)
end
function M.ImPlot_PlotPieChart_FloatPtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    fmt_data = fmt_data or nil
    return lib.ImPlot_PlotPieChart_FloatPtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
end
function M.ImPlot_PlotPieChart_doublePtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    fmt_data = fmt_data or nil
    return lib.ImPlot_PlotPieChart_doublePtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
end
function M.ImPlot_PlotPieChart_S8PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    fmt_data = fmt_data or nil
    return lib.ImPlot_PlotPieChart_S8PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
end
function M.ImPlot_PlotPieChart_U8PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    fmt_data = fmt_data or nil
    return lib.ImPlot_PlotPieChart_U8PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
end
function M.ImPlot_PlotPieChart_S16PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    fmt_data = fmt_data or nil
    return lib.ImPlot_PlotPieChart_S16PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
end
function M.ImPlot_PlotPieChart_U16PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    fmt_data = fmt_data or nil
    return lib.ImPlot_PlotPieChart_U16PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
end
function M.ImPlot_PlotPieChart_S32PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    fmt_data = fmt_data or nil
    return lib.ImPlot_PlotPieChart_S32PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
end
function M.ImPlot_PlotPieChart_U32PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    fmt_data = fmt_data or nil
    return lib.ImPlot_PlotPieChart_U32PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
end
function M.ImPlot_PlotPieChart_S64PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    fmt_data = fmt_data or nil
    return lib.ImPlot_PlotPieChart_S64PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
end
function M.ImPlot_PlotPieChart_U64PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    fmt_data = fmt_data or nil
    return lib.ImPlot_PlotPieChart_U64PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,flags)
end
function M.ImPlot_PlotPieChart_FloatPtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotPieChart_FloatPtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
end
function M.ImPlot_PlotPieChart_doublePtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotPieChart_doublePtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
end
function M.ImPlot_PlotPieChart_S8PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotPieChart_S8PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
end
function M.ImPlot_PlotPieChart_U8PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotPieChart_U8PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
end
function M.ImPlot_PlotPieChart_S16PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotPieChart_S16PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
end
function M.ImPlot_PlotPieChart_U16PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotPieChart_U16PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
end
function M.ImPlot_PlotPieChart_S32PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotPieChart_S32PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
end
function M.ImPlot_PlotPieChart_U32PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotPieChart_U32PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
end
function M.ImPlot_PlotPieChart_S64PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotPieChart_S64PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
end
function M.ImPlot_PlotPieChart_U64PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
    angle0 = angle0 or 90
    flags = flags or 0
    label_fmt = label_fmt or "%.1f"
    return lib.ImPlot_PlotPieChart_U64PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,flags)
end
function M.ImPlot_PlotPieChart(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and ((ffi.istype('int32_t',a10) or type(a10)=='number') or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_FloatPtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and ((ffi.istype('int32_t',a10) or type(a10)=='number') or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_doublePtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and ((ffi.istype('int32_t',a10) or type(a10)=='number') or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S8PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and ((ffi.istype('int32_t',a10) or type(a10)=='number') or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U8PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and ((ffi.istype('int32_t',a10) or type(a10)=='number') or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S16PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and ((ffi.istype('int32_t',a10) or type(a10)=='number') or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U16PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and ((ffi.istype('int32_t',a10) or type(a10)=='number') or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S32PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and ((ffi.istype('int32_t',a10) or type(a10)=='number') or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U32PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and ((ffi.istype('int32_t',a10) or type(a10)=='number') or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S64PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and ((ffi.istype('int32_t',a10) or type(a10)=='number') or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U64PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_FloatPtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_doublePtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S8PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U8PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S16PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U16PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S32PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U32PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S64PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U64PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
    error'M.ImPlot_PlotPieChart could not find overloaded'
end
function M.ImPlot_PlotScatter_FloatPtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_FloatPtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotScatter_doublePtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_doublePtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotScatter_S8PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_S8PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotScatter_U8PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_U8PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotScatter_S16PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_S16PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotScatter_U16PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_U16PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotScatter_S32PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_S32PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotScatter_U32PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_U32PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotScatter_S64PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_S64PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotScatter_U64PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_U64PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotScatter_FloatPtrFloatPtr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotScatter_FloatPtrFloatPtr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotScatter_doublePtrdoublePtr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotScatter_doublePtrdoublePtr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotScatter_S8PtrS8Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotScatter_S8PtrS8Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotScatter_U8PtrU8Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotScatter_U8PtrU8Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotScatter_S16PtrS16Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotScatter_S16PtrS16Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotScatter_U16PtrU16Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotScatter_U16PtrU16Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotScatter_S32PtrS32Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotScatter_S32PtrS32Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotScatter_U32PtrU32Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotScatter_U32PtrU32Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotScatter_S64PtrS64Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotScatter_S64PtrS64Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotScatter_U64PtrU64Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotScatter_U64PtrU64Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotScatter(a1,a2,a3,a4,a5,a6,a7,a8) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_FloatPtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_doublePtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_S8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_U8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_S16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_U16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_S32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_U32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_S64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_U64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotScatter_FloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotScatter_doublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotScatter_S8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_U8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_S16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_U16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_S32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_U32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_S64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_U64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7,a8)
    error'M.ImPlot_PlotScatter could not find overloaded'
end
function M.ImPlot_PlotScatterG(label_id,getter,data,count,flags)
    flags = flags or 0
    return lib.ImPlot_PlotScatterG(label_id,getter,data,count,flags)
end
function M.ImPlot_PlotShaded_FloatPtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_FloatPtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotShaded_doublePtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_doublePtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotShaded_S8PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S8PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotShaded_U8PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U8PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotShaded_S16PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S16PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotShaded_U16PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U16PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotShaded_S32PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S32PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotShaded_U32PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U32PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotShaded_S64PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S64PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotShaded_U64PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U64PtrInt(label_id,values,count,yref,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotShaded_FloatPtrFloatPtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    yref = yref or 0
    return lib.ImPlot_PlotShaded_FloatPtrFloatPtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
end
function M.ImPlot_PlotShaded_doublePtrdoublePtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    yref = yref or 0
    return lib.ImPlot_PlotShaded_doublePtrdoublePtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
end
function M.ImPlot_PlotShaded_S8PtrS8PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S8PtrS8PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
end
function M.ImPlot_PlotShaded_U8PtrU8PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U8PtrU8PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
end
function M.ImPlot_PlotShaded_S16PtrS16PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S16PtrS16PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
end
function M.ImPlot_PlotShaded_U16PtrU16PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U16PtrU16PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
end
function M.ImPlot_PlotShaded_S32PtrS32PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S32PtrS32PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
end
function M.ImPlot_PlotShaded_U32PtrU32PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U32PtrU32PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
end
function M.ImPlot_PlotShaded_S64PtrS64PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S64PtrS64PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
end
function M.ImPlot_PlotShaded_U64PtrU64PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U64PtrU64PtrInt(label_id,xs,ys,count,yref,flags,offset,stride)
end
function M.ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr(label_id,xs,ys1,ys2,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr(label_id,xs,ys1,ys2,count,flags,offset,stride)
end
function M.ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr(label_id,xs,ys1,ys2,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr(label_id,xs,ys1,ys2,count,flags,offset,stride)
end
function M.ImPlot_PlotShaded_S8PtrS8PtrS8Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotShaded_S8PtrS8PtrS8Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
end
function M.ImPlot_PlotShaded_U8PtrU8PtrU8Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotShaded_U8PtrU8PtrU8Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
end
function M.ImPlot_PlotShaded_S16PtrS16PtrS16Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotShaded_S16PtrS16PtrS16Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
end
function M.ImPlot_PlotShaded_U16PtrU16PtrU16Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotShaded_U16PtrU16PtrU16Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
end
function M.ImPlot_PlotShaded_S32PtrS32PtrS32Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotShaded_S32PtrS32PtrS32Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
end
function M.ImPlot_PlotShaded_U32PtrU32PtrU32Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotShaded_U32PtrU32PtrU32Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
end
function M.ImPlot_PlotShaded_S64PtrS64PtrS64Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotShaded_S64PtrS64PtrS64Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
end
function M.ImPlot_PlotShaded_U64PtrU64PtrU64Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotShaded_U64PtrU64PtrU64Ptr(label_id,xs,ys1,ys2,count,flags,offset,stride)
end
function M.ImPlot_PlotShaded(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotShaded_FloatPtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotShaded_doublePtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotShaded_S8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotShaded_U8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotShaded_S16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotShaded_U16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotShaded_S32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotShaded_U32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotShaded_S64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and ((ffi.istype('int32_t',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotShaded_U64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('int32_t',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and a9==nil then return M.ImPlot_PlotShaded_FloatPtrFloatPtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('int32_t',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and a9==nil then return M.ImPlot_PlotShaded_doublePtrdoublePtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('int32_t',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and a9==nil then return M.ImPlot_PlotShaded_S8PtrS8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and a9==nil then return M.ImPlot_PlotShaded_U8PtrU8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and a9==nil then return M.ImPlot_PlotShaded_S16PtrS16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and a9==nil then return M.ImPlot_PlotShaded_U16PtrU16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and a9==nil then return M.ImPlot_PlotShaded_S32PtrS32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and a9==nil then return M.ImPlot_PlotShaded_U32PtrU32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and a9==nil then return M.ImPlot_PlotShaded_S64PtrS64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a6) or type(a6)=='number') or type(a6)=='nil') and ((ffi.istype('int32_t',a7) or type(a7)=='number') or type(a7)=='nil') and a9==nil then return M.ImPlot_PlotShaded_U64PtrU64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('float*',a4) or ffi.istype('float[]',a4)) then return M.ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('double*',a4) or ffi.istype('double[]',a4)) then return M.ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('const ImS8*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') then return M.ImPlot_PlotShaded_S8PtrS8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) and ffi.typeof('uint8_t*') == ffi.typeof(a4) or ffi.typeof('const uint8_t*') == ffi.typeof(a4) or ffi.typeof('uint8_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_U8PtrU8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) and ffi.typeof('int16_t*') == ffi.typeof(a4) or ffi.typeof('const int16_t*') == ffi.typeof(a4) or ffi.typeof('int16_t[?]') == ffi.typeof(a4) or ffi.typeof('const int16_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_S16PtrS16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) and ffi.typeof('uint16_t*') == ffi.typeof(a4) or ffi.typeof('const uint16_t*') == ffi.typeof(a4) or ffi.typeof('uint16_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_U16PtrU16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) and ffi.typeof('int32_t*') == ffi.typeof(a4) or ffi.typeof('const int32_t*') == ffi.typeof(a4) or ffi.typeof('int32_t[?]') == ffi.typeof(a4) or ffi.typeof('const int32_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_S32PtrS32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) and ffi.typeof('uint32_t*') == ffi.typeof(a4) or ffi.typeof('const uint32_t*') == ffi.typeof(a4) or ffi.typeof('uint32_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_U32PtrU32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) and ffi.typeof('int64_t*') == ffi.typeof(a4) or ffi.typeof('const int64_t*') == ffi.typeof(a4) or ffi.typeof('int64_t[?]') == ffi.typeof(a4) or ffi.typeof('const int64_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_S64PtrS64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) and ffi.typeof('uint64_t*') == ffi.typeof(a4) or ffi.typeof('const uint64_t*') == ffi.typeof(a4) or ffi.typeof('uint64_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_U64PtrU64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.ImPlot_PlotShaded could not find overloaded'
end
function M.ImPlot_PlotShadedG(label_id,getter1,data1,getter2,data2,count,flags)
    flags = flags or 0
    return lib.ImPlot_PlotShadedG(label_id,getter1,data1,getter2,data2,count,flags)
end
function M.ImPlot_PlotStairs_FloatPtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_FloatPtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotStairs_doublePtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_doublePtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotStairs_S8PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_S8PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotStairs_U8PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_U8PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotStairs_S16PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_S16PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotStairs_U16PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_U16PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotStairs_S32PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_S32PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotStairs_U32PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_U32PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotStairs_S64PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_S64PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotStairs_U64PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_U64PtrInt(label_id,values,count,xscale,xstart,flags,offset,stride)
end
function M.ImPlot_PlotStairs_FloatPtrFloatPtr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotStairs_FloatPtrFloatPtr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotStairs_doublePtrdoublePtr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotStairs_doublePtrdoublePtr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotStairs_S8PtrS8Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotStairs_S8PtrS8Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotStairs_U8PtrU8Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotStairs_U8PtrU8Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotStairs_S16PtrS16Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotStairs_S16PtrS16Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotStairs_U16PtrU16Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotStairs_U16PtrU16Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotStairs_S32PtrS32Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotStairs_S32PtrS32Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotStairs_U32PtrU32Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotStairs_U32PtrU32Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotStairs_S64PtrS64Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotStairs_S64PtrS64Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotStairs_U64PtrU64Ptr(label_id,xs,ys,count,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotStairs_U64PtrU64Ptr(label_id,xs,ys,count,flags,offset,stride)
end
function M.ImPlot_PlotStairs(a1,a2,a3,a4,a5,a6,a7,a8) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_FloatPtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_doublePtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_S8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_U8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_S16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_U16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_S32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_U32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_S64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_U64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotStairs_FloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotStairs_doublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotStairs_S8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_U8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_S16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_U16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_S32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_U32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_S64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_U64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7,a8)
    error'M.ImPlot_PlotStairs could not find overloaded'
end
function M.ImPlot_PlotStairsG(label_id,getter,data,count,flags)
    flags = flags or 0
    return lib.ImPlot_PlotStairsG(label_id,getter,data,count,flags)
end
function M.ImPlot_PlotStems_FloatPtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    scale = scale or 1
    start = start or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotStems_FloatPtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
end
function M.ImPlot_PlotStems_doublePtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    scale = scale or 1
    start = start or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotStems_doublePtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
end
function M.ImPlot_PlotStems_S8PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    scale = scale or 1
    start = start or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotStems_S8PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
end
function M.ImPlot_PlotStems_U8PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    scale = scale or 1
    start = start or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotStems_U8PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
end
function M.ImPlot_PlotStems_S16PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    scale = scale or 1
    start = start or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotStems_S16PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
end
function M.ImPlot_PlotStems_U16PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    scale = scale or 1
    start = start or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotStems_U16PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
end
function M.ImPlot_PlotStems_S32PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    scale = scale or 1
    start = start or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotStems_S32PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
end
function M.ImPlot_PlotStems_U32PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    scale = scale or 1
    start = start or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotStems_U32PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
end
function M.ImPlot_PlotStems_S64PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    scale = scale or 1
    start = start or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotStems_S64PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
end
function M.ImPlot_PlotStems_U64PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    scale = scale or 1
    start = start or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotStems_U64PtrInt(label_id,values,count,ref,scale,start,flags,offset,stride)
end
function M.ImPlot_PlotStems_FloatPtrFloatPtr(label_id,xs,ys,count,ref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    stride = stride or ffi.sizeof("float")
    return lib.ImPlot_PlotStems_FloatPtrFloatPtr(label_id,xs,ys,count,ref,flags,offset,stride)
end
function M.ImPlot_PlotStems_doublePtrdoublePtr(label_id,xs,ys,count,ref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    stride = stride or ffi.sizeof("double")
    return lib.ImPlot_PlotStems_doublePtrdoublePtr(label_id,xs,ys,count,ref,flags,offset,stride)
end
function M.ImPlot_PlotStems_S8PtrS8Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    stride = stride or ffi.sizeof("ImS8")
    return lib.ImPlot_PlotStems_S8PtrS8Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
end
function M.ImPlot_PlotStems_U8PtrU8Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    stride = stride or ffi.sizeof("ImU8")
    return lib.ImPlot_PlotStems_U8PtrU8Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
end
function M.ImPlot_PlotStems_S16PtrS16Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    stride = stride or ffi.sizeof("ImS16")
    return lib.ImPlot_PlotStems_S16PtrS16Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
end
function M.ImPlot_PlotStems_U16PtrU16Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    stride = stride or ffi.sizeof("ImU16")
    return lib.ImPlot_PlotStems_U16PtrU16Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
end
function M.ImPlot_PlotStems_S32PtrS32Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    stride = stride or ffi.sizeof("ImS32")
    return lib.ImPlot_PlotStems_S32PtrS32Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
end
function M.ImPlot_PlotStems_U32PtrU32Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    stride = stride or ffi.sizeof("ImU32")
    return lib.ImPlot_PlotStems_U32PtrU32Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
end
function M.ImPlot_PlotStems_S64PtrS64Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    stride = stride or ffi.sizeof("ImS64")
    return lib.ImPlot_PlotStems_S64PtrS64Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
end
function M.ImPlot_PlotStems_U64PtrU64Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
    flags = flags or 0
    offset = offset or 0
    ref = ref or 0
    stride = stride or ffi.sizeof("ImU64")
    return lib.ImPlot_PlotStems_U64PtrU64Ptr(label_id,xs,ys,count,ref,flags,offset,stride)
end
function M.ImPlot_PlotStems(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_FloatPtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_doublePtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_S8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_U8PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_S16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_U16PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_S32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_U32PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_S64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_U64PtrInt(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotStems_FloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotStems_doublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotStems_S8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_U8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_S16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_U16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_S32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_U32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_S64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_U64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.ImPlot_PlotStems could not find overloaded'
end
function M.ImPlot_PlotText(text,x,y,pix_offset,flags)
    flags = flags or 0
    pix_offset = pix_offset or ImVec2(0,0)
    return lib.ImPlot_PlotText(text,x,y,pix_offset,flags)
end
function M.ImPlot_PlotToPixels_PlotPoInt(plt,x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_PlotToPixels_PlotPoInt(nonUDT_out,plt,x_axis,y_axis)
    return nonUDT_out
end
function M.ImPlot_PlotToPixels_double(x,y,x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    local nonUDT_out = ffi.new("ImVec2")
    lib.ImPlot_PlotToPixels_double(nonUDT_out,x,y,x_axis,y_axis)
    return nonUDT_out
end
function M.ImPlot_PlotToPixels(a2,a3,a4,a5) -- generic version
    if ffi.istype('const ImPlotPoint',a2) then return M.ImPlot_PlotToPixels_PlotPoInt(a2,a3,a4) end
    if (ffi.istype('double',a2) or type(a2)=='number') then return M.ImPlot_PlotToPixels_double(a2,a3,a4,a5) end
    print(a2,a3,a4,a5)
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
M.ImPlot_Precision = lib.ImPlot_Precision
M.ImPlot_PushColormap_PlotColormap = lib.ImPlot_PushColormap_PlotColormap
M.ImPlot_PushColormap_Str = lib.ImPlot_PushColormap_Str
function M.ImPlot_PushColormap(a1) -- generic version
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImPlot_PushColormap_PlotColormap(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_PushColormap_Str(a1) end
    print(a1)
    error'M.ImPlot_PushColormap could not find overloaded'
end
function M.ImPlot_PushPlotClipRect(expand)
    expand = expand or 0
    return lib.ImPlot_PushPlotClipRect(expand)
end
M.ImPlot_PushStyleColor_U32 = lib.ImPlot_PushStyleColor_U32
M.ImPlot_PushStyleColor_Vec4 = lib.ImPlot_PushStyleColor_Vec4
function M.ImPlot_PushStyleColor(a1,a2) -- generic version
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.ImPlot_PushStyleColor_U32(a1,a2) end
    if ffi.istype('const ImVec4',a2) then return M.ImPlot_PushStyleColor_Vec4(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_PushStyleColor could not find overloaded'
end
M.ImPlot_PushStyleVar_Float = lib.ImPlot_PushStyleVar_Float
M.ImPlot_PushStyleVar_Int = lib.ImPlot_PushStyleVar_Int
M.ImPlot_PushStyleVar_Vec2 = lib.ImPlot_PushStyleVar_Vec2
function M.ImPlot_PushStyleVar(a1,a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.ImPlot_PushStyleVar_Float(a1,a2) end
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return M.ImPlot_PushStyleVar_Int(a1,a2) end
    if ffi.istype('const ImVec2',a2) then return M.ImPlot_PushStyleVar_Vec2(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_PushStyleVar could not find overloaded'
end
M.ImPlot_RangesOverlap = lib.ImPlot_RangesOverlap
function M.ImPlot_RegisterOrGetItem(label_id,flags,just_created)
    just_created = just_created or nil
    return lib.ImPlot_RegisterOrGetItem(label_id,flags,just_created)
end
M.ImPlot_RenderColorBar = lib.ImPlot_RenderColorBar
M.ImPlot_ResetCtxForNextAlignedPlots = lib.ImPlot_ResetCtxForNextAlignedPlots
M.ImPlot_ResetCtxForNextPlot = lib.ImPlot_ResetCtxForNextPlot
M.ImPlot_ResetCtxForNextSubplot = lib.ImPlot_ResetCtxForNextSubplot
function M.ImPlot_RoundTime(t,unit)
    local nonUDT_out = ffi.new("ImPlotTime")
    lib.ImPlot_RoundTime(nonUDT_out,t,unit)
    return nonUDT_out
end
M.ImPlot_RoundTo = lib.ImPlot_RoundTo
function M.ImPlot_SampleColormap(t,cmap)
    cmap = cmap or -1
    local nonUDT_out = ffi.new("ImVec4")
    lib.ImPlot_SampleColormap(nonUDT_out,t,cmap)
    return nonUDT_out
end
M.ImPlot_SampleColormapU32 = lib.ImPlot_SampleColormapU32
M.ImPlot_SetAxes = lib.ImPlot_SetAxes
M.ImPlot_SetAxis = lib.ImPlot_SetAxis
M.ImPlot_SetCurrentContext = lib.ImPlot_SetCurrentContext
M.ImPlot_SetImGuiContext = lib.ImPlot_SetImGuiContext
function M.ImPlot_SetNextAxesLimits(x_min,x_max,y_min,y_max,cond)
    cond = cond or 2
    return lib.ImPlot_SetNextAxesLimits(x_min,x_max,y_min,y_max,cond)
end
M.ImPlot_SetNextAxesToFit = lib.ImPlot_SetNextAxesToFit
function M.ImPlot_SetNextAxisLimits(axis,v_min,v_max,cond)
    cond = cond or 2
    return lib.ImPlot_SetNextAxisLimits(axis,v_min,v_max,cond)
end
M.ImPlot_SetNextAxisLinks = lib.ImPlot_SetNextAxisLinks
M.ImPlot_SetNextAxisToFit = lib.ImPlot_SetNextAxisToFit
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
function M.ImPlot_SetupAxes(x_label,y_label,x_flags,y_flags)
    x_flags = x_flags or 0
    y_flags = y_flags or 0
    return lib.ImPlot_SetupAxes(x_label,y_label,x_flags,y_flags)
end
function M.ImPlot_SetupAxesLimits(x_min,x_max,y_min,y_max,cond)
    cond = cond or 2
    return lib.ImPlot_SetupAxesLimits(x_min,x_max,y_min,y_max,cond)
end
function M.ImPlot_SetupAxis(axis,label,flags)
    flags = flags or 0
    label = label or nil
    return lib.ImPlot_SetupAxis(axis,label,flags)
end
M.ImPlot_SetupAxisFormat_Str = lib.ImPlot_SetupAxisFormat_Str
function M.ImPlot_SetupAxisFormat_PlotFormatter(axis,formatter,data)
    data = data or nil
    return lib.ImPlot_SetupAxisFormat_PlotFormatter(axis,formatter,data)
end
function M.ImPlot_SetupAxisFormat(a1,a2,a3) -- generic version
    if (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_SetupAxisFormat_Str(a1,a2) end
    if ffi.istype('ImPlotFormatter',a2) then return M.ImPlot_SetupAxisFormat_PlotFormatter(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.ImPlot_SetupAxisFormat could not find overloaded'
end
function M.ImPlot_SetupAxisLimits(axis,v_min,v_max,cond)
    cond = cond or 2
    return lib.ImPlot_SetupAxisLimits(axis,v_min,v_max,cond)
end
M.ImPlot_SetupAxisLimitsConstraints = lib.ImPlot_SetupAxisLimitsConstraints
M.ImPlot_SetupAxisLinks = lib.ImPlot_SetupAxisLinks
M.ImPlot_SetupAxisScale_PlotScale = lib.ImPlot_SetupAxisScale_PlotScale
function M.ImPlot_SetupAxisScale_PlotTransform(axis,forward,inverse,data)
    data = data or nil
    return lib.ImPlot_SetupAxisScale_PlotTransform(axis,forward,inverse,data)
end
function M.ImPlot_SetupAxisScale(a1,a2,a3,a4) -- generic version
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return M.ImPlot_SetupAxisScale_PlotScale(a1,a2) end
    if ffi.istype('ImPlotTransform',a2) then return M.ImPlot_SetupAxisScale_PlotTransform(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_SetupAxisScale could not find overloaded'
end
function M.ImPlot_SetupAxisTicks_doublePtr(axis,values,n_ticks,labels,keep_default)
    keep_default = keep_default or false
    labels = labels or nil
    return lib.ImPlot_SetupAxisTicks_doublePtr(axis,values,n_ticks,labels,keep_default)
end
function M.ImPlot_SetupAxisTicks_double(axis,v_min,v_max,n_ticks,labels,keep_default)
    keep_default = keep_default or false
    labels = labels or nil
    return lib.ImPlot_SetupAxisTicks_double(axis,v_min,v_max,n_ticks,labels,keep_default)
end
function M.ImPlot_SetupAxisTicks(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_SetupAxisTicks_doublePtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('double',a2) or type(a2)=='number') then return M.ImPlot_SetupAxisTicks_double(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot_SetupAxisTicks could not find overloaded'
end
M.ImPlot_SetupAxisZoomConstraints = lib.ImPlot_SetupAxisZoomConstraints
M.ImPlot_SetupFinish = lib.ImPlot_SetupFinish
function M.ImPlot_SetupLegend(location,flags)
    flags = flags or 0
    return lib.ImPlot_SetupLegend(location,flags)
end
M.ImPlot_SetupLock = lib.ImPlot_SetupLock
function M.ImPlot_SetupMouseText(location,flags)
    flags = flags or 0
    return lib.ImPlot_SetupMouseText(location,flags)
end
function M.ImPlot_ShowAltLegend(title_id,vertical,size,interactable)
    if interactable == nil then interactable = true end
    size = size or ImVec2(0,0)
    if vertical == nil then vertical = true end
    return lib.ImPlot_ShowAltLegend(title_id,vertical,size,interactable)
end
function M.ImPlot_ShowAxisContextMenu(axis,equal_axis,time_allowed)
    time_allowed = time_allowed or false
    return lib.ImPlot_ShowAxisContextMenu(axis,equal_axis,time_allowed)
end
M.ImPlot_ShowColormapSelector = lib.ImPlot_ShowColormapSelector
function M.ImPlot_ShowDatePicker(id,level,t,t1,t2)
    t1 = t1 or nil
    t2 = t2 or nil
    return lib.ImPlot_ShowDatePicker(id,level,t,t1,t2)
end
function M.ImPlot_ShowDemoWindow(p_open)
    p_open = p_open or nil
    return lib.ImPlot_ShowDemoWindow(p_open)
end
M.ImPlot_ShowInputMapSelector = lib.ImPlot_ShowInputMapSelector
M.ImPlot_ShowLegendContextMenu = lib.ImPlot_ShowLegendContextMenu
M.ImPlot_ShowLegendEntries = lib.ImPlot_ShowLegendEntries
function M.ImPlot_ShowMetricsWindow(p_popen)
    p_popen = p_popen or nil
    return lib.ImPlot_ShowMetricsWindow(p_popen)
end
M.ImPlot_ShowPlotContextMenu = lib.ImPlot_ShowPlotContextMenu
function M.ImPlot_ShowStyleEditor(ref)
    ref = ref or nil
    return lib.ImPlot_ShowStyleEditor(ref)
end
M.ImPlot_ShowStyleSelector = lib.ImPlot_ShowStyleSelector
M.ImPlot_ShowSubplotsContextMenu = lib.ImPlot_ShowSubplotsContextMenu
M.ImPlot_ShowTimePicker = lib.ImPlot_ShowTimePicker
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
M.ImPlot_SubplotNextCell = lib.ImPlot_SubplotNextCell
function M.ImPlot_TagX_Bool(x,col,round)
    round = round or false
    return lib.ImPlot_TagX_Bool(x,col,round)
end
M.ImPlot_TagX_Str = lib.ImPlot_TagX_Str
function M.ImPlot_TagX(a1,a2,a3,...) -- generic version
    if ((ffi.istype('bool',a3) or type(a3)=='boolean') or type(a3)=='nil') then return M.ImPlot_TagX_Bool(a1,a2,a3) end
    if (ffi.istype('const char*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_TagX_Str(a1,a2,a3,...) end
    print(a1,a2,a3,...)
    error'M.ImPlot_TagX could not find overloaded'
end
M.ImPlot_TagXV = lib.ImPlot_TagXV
function M.ImPlot_TagY_Bool(y,col,round)
    round = round or false
    return lib.ImPlot_TagY_Bool(y,col,round)
end
M.ImPlot_TagY_Str = lib.ImPlot_TagY_Str
function M.ImPlot_TagY(a1,a2,a3,...) -- generic version
    if ((ffi.istype('bool',a3) or type(a3)=='boolean') or type(a3)=='nil') then return M.ImPlot_TagY_Bool(a1,a2,a3) end
    if (ffi.istype('const char*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_TagY_Str(a1,a2,a3,...) end
    print(a1,a2,a3,...)
    error'M.ImPlot_TagY could not find overloaded'
end
M.ImPlot_TagYV = lib.ImPlot_TagYV
M.ImPlot_TransformForward_Log10 = lib.ImPlot_TransformForward_Log10
M.ImPlot_TransformForward_Logit = lib.ImPlot_TransformForward_Logit
M.ImPlot_TransformForward_SymLog = lib.ImPlot_TransformForward_SymLog
M.ImPlot_TransformInverse_Log10 = lib.ImPlot_TransformInverse_Log10
M.ImPlot_TransformInverse_Logit = lib.ImPlot_TransformInverse_Logit
M.ImPlot_TransformInverse_SymLog = lib.ImPlot_TransformInverse_SymLog
function M.AcceptDragDropPayload(type,flags)
    flags = flags or 0
    return lib.igAcceptDragDropPayload(type,flags)
end
M.ActivateItemByID = lib.igActivateItemByID
M.AddContextHook = lib.igAddContextHook
M.AddDrawListToDrawDataEx = lib.igAddDrawListToDrawDataEx
M.AddSettingsHandler = lib.igAddSettingsHandler
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
function M.BeginChild_Str(str_id,size,child_flags,window_flags)
    child_flags = child_flags or 0
    size = size or ImVec2(0,0)
    window_flags = window_flags or 0
    return lib.igBeginChild_Str(str_id,size,child_flags,window_flags)
end
function M.BeginChild_ID(id,size,child_flags,window_flags)
    child_flags = child_flags or 0
    size = size or ImVec2(0,0)
    window_flags = window_flags or 0
    return lib.igBeginChild_ID(id,size,child_flags,window_flags)
end
function M.BeginChild(a1,a2,a3,a4) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.BeginChild_Str(a1,a2,a3,a4) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.BeginChild_ID(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.BeginChild could not find overloaded'
end
M.BeginChildEx = lib.igBeginChildEx
function M.BeginColumns(str_id,count,flags)
    flags = flags or 0
    return lib.igBeginColumns(str_id,count,flags)
end
function M.BeginCombo(label,preview_value,flags)
    flags = flags or 0
    return lib.igBeginCombo(label,preview_value,flags)
end
M.BeginComboPopup = lib.igBeginComboPopup
M.BeginComboPreview = lib.igBeginComboPreview
function M.BeginDisabled(disabled)
    if disabled == nil then disabled = true end
    return lib.igBeginDisabled(disabled)
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
M.BeginItemTooltip = lib.igBeginItemTooltip
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
function M.BeginMenuEx(label,icon,enabled)
    if enabled == nil then enabled = true end
    return lib.igBeginMenuEx(label,icon,enabled)
end
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
M.BeginTooltipHidden = lib.igBeginTooltipHidden
M.BeginViewportSideBar = lib.igBeginViewportSideBar
M.BringWindowToDisplayBack = lib.igBringWindowToDisplayBack
M.BringWindowToDisplayBehind = lib.igBringWindowToDisplayBehind
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
M.CalcRoundingFlagsForRectInRect = lib.igCalcRoundingFlagsForRectInRect
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
M.Checkbox = lib.igCheckbox
M.CheckboxFlags_IntPtr = lib.igCheckboxFlags_IntPtr
M.CheckboxFlags_UintPtr = lib.igCheckboxFlags_UintPtr
M.CheckboxFlags_S64Ptr = lib.igCheckboxFlags_S64Ptr
M.CheckboxFlags_U64Ptr = lib.igCheckboxFlags_U64Ptr
function M.CheckboxFlags(a1,a2,a3) -- generic version
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.CheckboxFlags_IntPtr(a1,a2,a3) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.CheckboxFlags_UintPtr(a1,a2,a3) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.CheckboxFlags_S64Ptr(a1,a2,a3) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.CheckboxFlags_U64Ptr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.CheckboxFlags could not find overloaded'
end
M.ClearActiveID = lib.igClearActiveID
M.ClearDragDrop = lib.igClearDragDrop
M.ClearIniSettings = lib.igClearIniSettings
M.ClearWindowSettings = lib.igClearWindowSettings
M.CloseButton = lib.igCloseButton
M.CloseCurrentPopup = lib.igCloseCurrentPopup
M.ClosePopupToLevel = lib.igClosePopupToLevel
M.ClosePopupsExceptModals = lib.igClosePopupsExceptModals
M.ClosePopupsOverWindow = lib.igClosePopupsOverWindow
M.CollapseButton = lib.igCollapseButton
function M.CollapsingHeader_TreeNodeFlags(label,flags)
    flags = flags or 0
    return lib.igCollapsingHeader_TreeNodeFlags(label,flags)
end
function M.CollapsingHeader_BoolPtr(label,p_visible,flags)
    flags = flags or 0
    return lib.igCollapsingHeader_BoolPtr(label,p_visible,flags)
end
function M.CollapsingHeader(a1,a2,a3) -- generic version
    if ((ffi.istype('int32_t',a2) or type(a2)=='number') or type(a2)=='nil') then return M.CollapsingHeader_TreeNodeFlags(a1,a2) end
    if (ffi.istype('bool*',a2) or ffi.istype('bool[]',a2)) then return M.CollapsingHeader_BoolPtr(a1,a2,a3) end
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
function M.Combo_Str_arr(label,current_item,items,items_count,popup_max_height_in_items)
    popup_max_height_in_items = popup_max_height_in_items or -1
    return lib.igCombo_Str_arr(label,current_item,items,items_count,popup_max_height_in_items)
end
function M.Combo_Str(label,current_item,items_separated_by_zeros,popup_max_height_in_items)
    popup_max_height_in_items = popup_max_height_in_items or -1
    return lib.igCombo_Str(label,current_item,items_separated_by_zeros,popup_max_height_in_items)
end
function M.Combo_FnStrPtr(label,current_item,getter,user_data,items_count,popup_max_height_in_items)
    popup_max_height_in_items = popup_max_height_in_items or -1
    return lib.igCombo_FnStrPtr(label,current_item,getter,user_data,items_count,popup_max_height_in_items)
end
function M.Combo(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('const char* const[]',a3) or ffi.istype('const char const[]',a3) or ffi.istype('const char const[][]',a3)) then return M.Combo_Str_arr(a1,a2,a3,a4,a5) end
    if (ffi.istype('const char*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.Combo_Str(a1,a2,a3,a4) end
    if ffi.istype('const char*(*)(void* user_data,int idx)',a3) then return M.Combo_FnStrPtr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.Combo could not find overloaded'
end
M.ConvertSingleModFlagToKey = lib.igConvertSingleModFlagToKey
function M.CreateContext(shared_font_atlas)
    shared_font_atlas = shared_font_atlas or nil
    return lib.igCreateContext(shared_font_atlas)
end
M.CreateNewWindowSettings = lib.igCreateNewWindowSettings
M.DataTypeApplyFromText = lib.igDataTypeApplyFromText
M.DataTypeApplyOp = lib.igDataTypeApplyOp
M.DataTypeClamp = lib.igDataTypeClamp
M.DataTypeCompare = lib.igDataTypeCompare
M.DataTypeFormatString = lib.igDataTypeFormatString
M.DataTypeGetInfo = lib.igDataTypeGetInfo
M.DebugAllocHook = lib.igDebugAllocHook
M.DebugBreakButton = lib.igDebugBreakButton
M.DebugBreakButtonTooltip = lib.igDebugBreakButtonTooltip
M.DebugBreakClearData = lib.igDebugBreakClearData
M.DebugCheckVersionAndDataLayout = lib.igDebugCheckVersionAndDataLayout
function M.DebugDrawCursorPos(col)
    col = col or 4278190335
    return lib.igDebugDrawCursorPos(col)
end
function M.DebugDrawItemRect(col)
    col = col or 4278190335
    return lib.igDebugDrawItemRect(col)
end
function M.DebugDrawLineExtents(col)
    col = col or 4278190335
    return lib.igDebugDrawLineExtents(col)
end
M.DebugFlashStyleColor = lib.igDebugFlashStyleColor
M.DebugHookIdInfo = lib.igDebugHookIdInfo
M.DebugLocateItem = lib.igDebugLocateItem
M.DebugLocateItemOnHover = lib.igDebugLocateItemOnHover
M.DebugLocateItemResolveWithLastItem = lib.igDebugLocateItemResolveWithLastItem
M.DebugLog = lib.igDebugLog
M.DebugLogV = lib.igDebugLogV
M.DebugNodeColumns = lib.igDebugNodeColumns
M.DebugNodeDockNode = lib.igDebugNodeDockNode
M.DebugNodeDrawCmdShowMeshAndBoundingBox = lib.igDebugNodeDrawCmdShowMeshAndBoundingBox
M.DebugNodeDrawList = lib.igDebugNodeDrawList
M.DebugNodeFont = lib.igDebugNodeFont
M.DebugNodeFontGlyph = lib.igDebugNodeFontGlyph
M.DebugNodeInputTextState = lib.igDebugNodeInputTextState
M.DebugNodeStorage = lib.igDebugNodeStorage
M.DebugNodeTabBar = lib.igDebugNodeTabBar
M.DebugNodeTable = lib.igDebugNodeTable
M.DebugNodeTableSettings = lib.igDebugNodeTableSettings
M.DebugNodeTypingSelectState = lib.igDebugNodeTypingSelectState
M.DebugNodeViewport = lib.igDebugNodeViewport
M.DebugNodeWindow = lib.igDebugNodeWindow
M.DebugNodeWindowSettings = lib.igDebugNodeWindowSettings
M.DebugNodeWindowsList = lib.igDebugNodeWindowsList
M.DebugNodeWindowsListByBeginStackParent = lib.igDebugNodeWindowsListByBeginStackParent
M.DebugRenderKeyboardPreview = lib.igDebugRenderKeyboardPreview
M.DebugRenderViewportThumbnail = lib.igDebugRenderViewportThumbnail
M.DebugStartItemPicker = lib.igDebugStartItemPicker
M.DebugTextEncoding = lib.igDebugTextEncoding
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
M.DockContextEndFrame = lib.igDockContextEndFrame
M.DockContextFindNodeByID = lib.igDockContextFindNodeByID
M.DockContextGenNodeID = lib.igDockContextGenNodeID
M.DockContextInitialize = lib.igDockContextInitialize
M.DockContextNewFrameUpdateDocking = lib.igDockContextNewFrameUpdateDocking
M.DockContextNewFrameUpdateUndocking = lib.igDockContextNewFrameUpdateUndocking
M.DockContextProcessUndockNode = lib.igDockContextProcessUndockNode
function M.DockContextProcessUndockWindow(ctx,window,clear_persistent_docking_ref)
    if clear_persistent_docking_ref == nil then clear_persistent_docking_ref = true end
    return lib.igDockContextProcessUndockWindow(ctx,window,clear_persistent_docking_ref)
end
M.DockContextQueueDock = lib.igDockContextQueueDock
M.DockContextQueueUndockNode = lib.igDockContextQueueUndockNode
M.DockContextQueueUndockWindow = lib.igDockContextQueueUndockWindow
M.DockContextRebuildNodes = lib.igDockContextRebuildNodes
M.DockContextShutdown = lib.igDockContextShutdown
M.DockNodeBeginAmendTabBar = lib.igDockNodeBeginAmendTabBar
M.DockNodeEndAmendTabBar = lib.igDockNodeEndAmendTabBar
M.DockNodeGetDepth = lib.igDockNodeGetDepth
M.DockNodeGetRootNode = lib.igDockNodeGetRootNode
M.DockNodeGetWindowMenuButtonId = lib.igDockNodeGetWindowMenuButtonId
M.DockNodeIsInHierarchyOf = lib.igDockNodeIsInHierarchyOf
M.DockNodeWindowMenuHandler_Default = lib.igDockNodeWindowMenuHandler_Default
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
    v_speed = v_speed or 1.0
    return lib.igDragScalar(label,data_type,p_data,v_speed,p_min,p_max,format,flags)
end
function M.DragScalarN(label,data_type,p_data,components,v_speed,p_min,p_max,format,flags)
    flags = flags or 0
    format = format or nil
    p_max = p_max or nil
    p_min = p_min or nil
    v_speed = v_speed or 1.0
    return lib.igDragScalarN(label,data_type,p_data,components,v_speed,p_min,p_max,format,flags)
end
M.Dummy = lib.igDummy
M.End = lib.igEnd
M.EndChild = lib.igEndChild
M.EndColumns = lib.igEndColumns
M.EndCombo = lib.igEndCombo
M.EndComboPreview = lib.igEndComboPreview
M.EndDisabled = lib.igEndDisabled
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
function M.ErrorCheckEndWindowRecover(log_callback,user_data)
    user_data = user_data or nil
    return lib.igErrorCheckEndWindowRecover(log_callback,user_data)
end
M.ErrorCheckUsingSetCursorPosToExtendParentBoundaries = lib.igErrorCheckUsingSetCursorPosToExtendParentBoundaries
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
M.FindBlockingModal = lib.igFindBlockingModal
M.FindBottomMostVisibleWindowWithinBeginStack = lib.igFindBottomMostVisibleWindowWithinBeginStack
M.FindHoveredViewportFromPlatformWindowStack = lib.igFindHoveredViewportFromPlatformWindowStack
M.FindOrCreateColumns = lib.igFindOrCreateColumns
function M.FindRenderedTextEnd(text,text_end)
    text_end = text_end or nil
    return lib.igFindRenderedTextEnd(text,text_end)
end
M.FindSettingsHandler = lib.igFindSettingsHandler
M.FindViewportByID = lib.igFindViewportByID
M.FindViewportByPlatformHandle = lib.igFindViewportByPlatformHandle
M.FindWindowByID = lib.igFindWindowByID
M.FindWindowByName = lib.igFindWindowByName
M.FindWindowDisplayIndex = lib.igFindWindowDisplayIndex
M.FindWindowSettingsByID = lib.igFindWindowSettingsByID
M.FindWindowSettingsByWindow = lib.igFindWindowSettingsByWindow
M.FixupKeyChord = lib.igFixupKeyChord
M.FocusItem = lib.igFocusItem
M.FocusTopMostWindowUnderOne = lib.igFocusTopMostWindowUnderOne
function M.FocusWindow(window,flags)
    flags = flags or 0
    return lib.igFocusWindow(window,flags)
end
M.GcAwakeTransientWindowBuffers = lib.igGcAwakeTransientWindowBuffers
M.GcCompactTransientMiscBuffers = lib.igGcCompactTransientMiscBuffers
M.GcCompactTransientWindowBuffers = lib.igGcCompactTransientWindowBuffers
M.GetActiveID = lib.igGetActiveID
M.GetAllocatorFunctions = lib.igGetAllocatorFunctions
M.GetBackgroundDrawList_Nil = lib.igGetBackgroundDrawList_Nil
M.GetBackgroundDrawList_ViewportPtr = lib.igGetBackgroundDrawList_ViewportPtr
function M.GetBackgroundDrawList(a1) -- generic version
    if a1==nil then return M.GetBackgroundDrawList_Nil() end
    if (ffi.istype('ImGuiViewport*',a1) or ffi.istype('ImGuiViewport',a1) or ffi.istype('ImGuiViewport[]',a1)) then return M.GetBackgroundDrawList_ViewportPtr(a1) end
    print(a1)
    error'M.GetBackgroundDrawList could not find overloaded'
end
M.GetClipboardText = lib.igGetClipboardText
function M.GetColorU32_Col(idx,alpha_mul)
    alpha_mul = alpha_mul or 1.0
    return lib.igGetColorU32_Col(idx,alpha_mul)
end
M.GetColorU32_Vec4 = lib.igGetColorU32_Vec4
M.GetColorU32_U32 = lib.igGetColorU32_U32
function M.GetColorU32(a1,a2) -- generic version
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.GetColorU32_Col(a1,a2) end
    if ffi.istype('const ImVec4',a1) then return M.GetColorU32_Vec4(a1) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.GetColorU32_U32(a1) end
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
M.GetCurrentFocusScope = lib.igGetCurrentFocusScope
M.GetCurrentTabBar = lib.igGetCurrentTabBar
M.GetCurrentTable = lib.igGetCurrentTable
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
M.GetFont = lib.igGetFont
M.GetFontSize = lib.igGetFontSize
function M.GetFontTexUvWhitePixel()
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetFontTexUvWhitePixel(nonUDT_out)
    return nonUDT_out
end
M.GetForegroundDrawList_Nil = lib.igGetForegroundDrawList_Nil
M.GetForegroundDrawList_ViewportPtr = lib.igGetForegroundDrawList_ViewportPtr
M.GetForegroundDrawList_WindowPtr = lib.igGetForegroundDrawList_WindowPtr
function M.GetForegroundDrawList(a1) -- generic version
    if a1==nil then return M.GetForegroundDrawList_Nil() end
    if (ffi.istype('ImGuiViewport*',a1) or ffi.istype('ImGuiViewport',a1) or ffi.istype('ImGuiViewport[]',a1)) then return M.GetForegroundDrawList_ViewportPtr(a1) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.GetForegroundDrawList_WindowPtr(a1) end
    print(a1)
    error'M.GetForegroundDrawList could not find overloaded'
end
M.GetFrameCount = lib.igGetFrameCount
M.GetFrameHeight = lib.igGetFrameHeight
M.GetFrameHeightWithSpacing = lib.igGetFrameHeightWithSpacing
M.GetHoveredID = lib.igGetHoveredID
M.GetID_Str = lib.igGetID_Str
M.GetID_StrStr = lib.igGetID_StrStr
M.GetID_Ptr = lib.igGetID_Ptr
function M.GetID(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a2==nil then return M.GetID_Str(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.GetID_StrStr(a1,a2) end
    if ffi.istype('void *',a1) then return M.GetID_Ptr(a1) end
    print(a1,a2)
    error'M.GetID could not find overloaded'
end
M.GetIDWithSeed_Str = lib.igGetIDWithSeed_Str
M.GetIDWithSeed_Int = lib.igGetIDWithSeed_Int
function M.GetIDWithSeed(a1,a2,a3) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.GetIDWithSeed_Str(a1,a2,a3) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.GetIDWithSeed_Int(a1,a2) end
    print(a1,a2,a3)
    error'M.GetIDWithSeed could not find overloaded'
end
M.GetIO = lib.igGetIO
M.GetInputTextState = lib.igGetInputTextState
M.GetItemFlags = lib.igGetItemFlags
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
M.GetKeyChordName = lib.igGetKeyChordName
M.GetKeyData_ContextPtr = lib.igGetKeyData_ContextPtr
M.GetKeyData_Key = lib.igGetKeyData_Key
function M.GetKeyData(a1,a2) -- generic version
    if (ffi.istype('ImGuiContext*',a1) or ffi.istype('ImGuiContext',a1) or ffi.istype('ImGuiContext[]',a1)) then return M.GetKeyData_ContextPtr(a1,a2) end
    if ffi.istype('ImGuiKey',a1) then return M.GetKeyData_Key(a1) end
    print(a1,a2)
    error'M.GetKeyData could not find overloaded'
end
M.GetKeyIndex = lib.igGetKeyIndex
function M.GetKeyMagnitude2d(key_left,key_right,key_up,key_down)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igGetKeyMagnitude2d(nonUDT_out,key_left,key_right,key_up,key_down)
    return nonUDT_out
end
M.GetKeyName = lib.igGetKeyName
M.GetKeyOwner = lib.igGetKeyOwner
M.GetKeyOwnerData = lib.igGetKeyOwnerData
M.GetKeyPressedAmount = lib.igGetKeyPressedAmount
M.GetMainViewport = lib.igGetMainViewport
M.GetMouseClickedCount = lib.igGetMouseClickedCount
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
M.GetNavTweakPressedAmount = lib.igGetNavTweakPressedAmount
M.GetPlatformIO = lib.igGetPlatformIO
function M.GetPopupAllowedExtentRect(window)
    local nonUDT_out = ffi.new("ImRect")
    lib.igGetPopupAllowedExtentRect(nonUDT_out,window)
    return nonUDT_out
end
M.GetScrollMaxX = lib.igGetScrollMaxX
M.GetScrollMaxY = lib.igGetScrollMaxY
M.GetScrollX = lib.igGetScrollX
M.GetScrollY = lib.igGetScrollY
M.GetShortcutRoutingData = lib.igGetShortcutRoutingData
M.GetStateStorage = lib.igGetStateStorage
M.GetStyle = lib.igGetStyle
M.GetStyleColorName = lib.igGetStyleColorName
M.GetStyleColorVec4 = lib.igGetStyleColorVec4
M.GetStyleVarInfo = lib.igGetStyleVarInfo
M.GetTextLineHeight = lib.igGetTextLineHeight
M.GetTextLineHeightWithSpacing = lib.igGetTextLineHeightWithSpacing
M.GetTime = lib.igGetTime
M.GetTopMostAndVisiblePopupModal = lib.igGetTopMostAndVisiblePopupModal
M.GetTopMostPopupModal = lib.igGetTopMostPopupModal
M.GetTreeNodeToLabelSpacing = lib.igGetTreeNodeToLabelSpacing
M.GetTypematicRepeatRate = lib.igGetTypematicRepeatRate
function M.GetTypingSelectRequest(flags)
    flags = flags or 0
    return lib.igGetTypingSelectRequest(flags)
end
M.GetVersion = lib.igGetVersion
M.GetViewportPlatformMonitor = lib.igGetViewportPlatformMonitor
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
M.GetWindowResizeBorderID = lib.igGetWindowResizeBorderID
M.GetWindowResizeCornerID = lib.igGetWindowResizeCornerID
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
M.ImAbs_Int = lib.igImAbs_Int
M.ImAbs_Float = lib.igImAbs_Float
M.ImAbs_double = lib.igImAbs_double
function M.ImAbs(a1) -- generic version
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImAbs_Int(a1) end
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImAbs_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImAbs_double(a1) end
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
M.ImBitArrayClearAllBits = lib.igImBitArrayClearAllBits
M.ImBitArrayClearBit = lib.igImBitArrayClearBit
M.ImBitArrayGetStorageSizeInBytes = lib.igImBitArrayGetStorageSizeInBytes
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
M.ImExponentialMovingAverage = lib.igImExponentialMovingAverage
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
M.ImFloor_Float = lib.igImFloor_Float
function M.ImFloor_Vec2(v)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImFloor_Vec2(nonUDT_out,v)
    return nonUDT_out
end
function M.ImFloor(a1,a2) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImFloor_Float(a1) end
    if (ffi.istype('ImVec2*',a1) or ffi.istype('ImVec2',a1) or ffi.istype('ImVec2[]',a1)) then return M.ImFloor_Vec2(a2) end
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
M.ImFontAtlasUpdateConfigDataPointers = lib.igImFontAtlasUpdateConfigDataPointers
M.ImFormatString = lib.igImFormatString
M.ImFormatStringToTempBuffer = lib.igImFormatStringToTempBuffer
M.ImFormatStringToTempBufferV = lib.igImFormatStringToTempBufferV
M.ImFormatStringV = lib.igImFormatStringV
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
M.ImIsFloatAboveGuaranteedIntegerPrecision = lib.igImIsFloatAboveGuaranteedIntegerPrecision
M.ImIsPowerOfTwo_Int = lib.igImIsPowerOfTwo_Int
M.ImIsPowerOfTwo_U64 = lib.igImIsPowerOfTwo_U64
function M.ImIsPowerOfTwo(a1) -- generic version
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImIsPowerOfTwo_Int(a1) end
    if (ffi.istype('uint64_t',a1) or type(a1)=='number') then return M.ImIsPowerOfTwo_U64(a1) end
    print(a1)
    error'M.ImIsPowerOfTwo could not find overloaded'
end
M.ImLengthSqr_Vec2 = lib.igImLengthSqr_Vec2
M.ImLengthSqr_Vec4 = lib.igImLengthSqr_Vec4
function M.ImLengthSqr(a1) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.ImLengthSqr_Vec2(a1) end
    if ffi.istype('const ImVec4',a1) then return M.ImLengthSqr_Vec4(a1) end
    print(a1)
    error'M.ImLengthSqr could not find overloaded'
end
function M.ImLerp_Vec2Float(a,b,t)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImLerp_Vec2Float(nonUDT_out,a,b,t)
    return nonUDT_out
end
function M.ImLerp_Vec2Vec2(a,b,t)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImLerp_Vec2Vec2(nonUDT_out,a,b,t)
    return nonUDT_out
end
function M.ImLerp_Vec4(a,b,t)
    local nonUDT_out = ffi.new("ImVec4")
    lib.igImLerp_Vec4(nonUDT_out,a,b,t)
    return nonUDT_out
end
function M.ImLerp(a2,a3,a4) -- generic version
    if ffi.istype('const ImVec2',a2) and (ffi.istype('float',a4) or type(a4)=='number') then return M.ImLerp_Vec2Float(a2,a3,a4) end
    if ffi.istype('const ImVec2',a2) and ffi.istype('const ImVec2',a4) then return M.ImLerp_Vec2Vec2(a2,a3,a4) end
    if ffi.istype('const ImVec4',a2) then return M.ImLerp_Vec4(a2,a3,a4) end
    print(a2,a3,a4)
    error'M.ImLerp could not find overloaded'
end
function M.ImLineClosestPoint(a,b,p)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImLineClosestPoint(nonUDT_out,a,b,p)
    return nonUDT_out
end
M.ImLinearSweep = lib.igImLinearSweep
M.ImLog_Float = lib.igImLog_Float
M.ImLog_double = lib.igImLog_double
function M.ImLog(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImLog_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImLog_double(a1) end
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
M.ImParseFormatSanitizeForPrinting = lib.igImParseFormatSanitizeForPrinting
M.ImParseFormatSanitizeForScanning = lib.igImParseFormatSanitizeForScanning
M.ImParseFormatTrimDecorations = lib.igImParseFormatTrimDecorations
M.ImPow_Float = lib.igImPow_Float
M.ImPow_double = lib.igImPow_double
function M.ImPow(a1,a2) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPow_Float(a1,a2) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPow_double(a1,a2) end
    print(a1,a2)
    error'M.ImPow could not find overloaded'
end
M.ImQsort = lib.igImQsort
function M.ImRotate(v,cos_a,sin_a)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImRotate(nonUDT_out,v,cos_a,sin_a)
    return nonUDT_out
end
M.ImRsqrt_Float = lib.igImRsqrt_Float
M.ImRsqrt_double = lib.igImRsqrt_double
function M.ImRsqrt(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImRsqrt_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImRsqrt_double(a1) end
    print(a1)
    error'M.ImRsqrt could not find overloaded'
end
M.ImSaturate = lib.igImSaturate
M.ImSign_Float = lib.igImSign_Float
M.ImSign_double = lib.igImSign_double
function M.ImSign(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImSign_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImSign_double(a1) end
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
M.ImTextCharToUtf8 = lib.igImTextCharToUtf8
M.ImTextCountCharsFromUtf8 = lib.igImTextCountCharsFromUtf8
M.ImTextCountUtf8BytesFromChar = lib.igImTextCountUtf8BytesFromChar
M.ImTextCountUtf8BytesFromStr = lib.igImTextCountUtf8BytesFromStr
M.ImTextFindPreviousUtf8Codepoint = lib.igImTextFindPreviousUtf8Codepoint
function M.ImTextStrFromUtf8(out_buf,out_buf_size,in_text,in_text_end,in_remaining)
    in_remaining = in_remaining or nil
    return lib.igImTextStrFromUtf8(out_buf,out_buf_size,in_text,in_text_end,in_remaining)
end
M.ImTextStrToUtf8 = lib.igImTextStrToUtf8
M.ImToUpper = lib.igImToUpper
M.ImTriangleArea = lib.igImTriangleArea
M.ImTriangleBarycentricCoords = lib.igImTriangleBarycentricCoords
function M.ImTriangleClosestPoint(a,b,c,p)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImTriangleClosestPoint(nonUDT_out,a,b,c,p)
    return nonUDT_out
end
M.ImTriangleContainsPoint = lib.igImTriangleContainsPoint
M.ImTrunc_Float = lib.igImTrunc_Float
function M.ImTrunc_Vec2(v)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igImTrunc_Vec2(nonUDT_out,v)
    return nonUDT_out
end
function M.ImTrunc(a1,a2) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImTrunc_Float(a1) end
    if (ffi.istype('ImVec2*',a1) or ffi.istype('ImVec2',a1) or ffi.istype('ImVec2[]',a1)) then return M.ImTrunc_Vec2(a2) end
    print(a1,a2)
    error'M.ImTrunc could not find overloaded'
end
M.ImUpperPowerOfTwo = lib.igImUpperPowerOfTwo
function M.Image(user_texture_id,image_size,uv0,uv1,tint_col,border_col)
    border_col = border_col or ImVec4(0,0,0,0)
    tint_col = tint_col or ImVec4(1,1,1,1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,1)
    return lib.igImage(user_texture_id,image_size,uv0,uv1,tint_col,border_col)
end
function M.ImageButton(str_id,user_texture_id,image_size,uv0,uv1,bg_col,tint_col)
    bg_col = bg_col or ImVec4(0,0,0,0)
    tint_col = tint_col or ImVec4(1,1,1,1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,1)
    return lib.igImageButton(str_id,user_texture_id,image_size,uv0,uv1,bg_col,tint_col)
end
function M.ImageButtonEx(id,texture_id,image_size,uv0,uv1,bg_col,tint_col,flags)
    flags = flags or 0
    return lib.igImageButtonEx(id,texture_id,image_size,uv0,uv1,bg_col,tint_col,flags)
end
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
M.InputTextDeactivateHook = lib.igInputTextDeactivateHook
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
M.IsActiveIdUsingNavDir = lib.igIsActiveIdUsingNavDir
M.IsAliasKey = lib.igIsAliasKey
M.IsAnyItemActive = lib.igIsAnyItemActive
M.IsAnyItemFocused = lib.igIsAnyItemFocused
M.IsAnyItemHovered = lib.igIsAnyItemHovered
M.IsAnyMouseDown = lib.igIsAnyMouseDown
M.IsClippedEx = lib.igIsClippedEx
M.IsDragDropActive = lib.igIsDragDropActive
M.IsDragDropPayloadBeingAccepted = lib.igIsDragDropPayloadBeingAccepted
M.IsGamepadKey = lib.igIsGamepadKey
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
M.IsKeyChordPressed_Nil = lib.igIsKeyChordPressed_Nil
function M.IsKeyChordPressed_ID(key_chord,owner_id,flags)
    flags = flags or 0
    return lib.igIsKeyChordPressed_ID(key_chord,owner_id,flags)
end
function M.IsKeyChordPressed(a1,a2,a3) -- generic version
    if a2==nil then return M.IsKeyChordPressed_Nil(a1) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsKeyChordPressed_ID(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.IsKeyChordPressed could not find overloaded'
end
M.IsKeyDown_Nil = lib.igIsKeyDown_Nil
M.IsKeyDown_ID = lib.igIsKeyDown_ID
function M.IsKeyDown(a1,a2) -- generic version
    if a2==nil then return M.IsKeyDown_Nil(a1) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsKeyDown_ID(a1,a2) end
    print(a1,a2)
    error'M.IsKeyDown could not find overloaded'
end
function M.IsKeyPressed_Bool(key,_repeat)
    if _repeat == nil then _repeat = true end
    return lib.igIsKeyPressed_Bool(key,_repeat)
end
function M.IsKeyPressed_ID(key,owner_id,flags)
    flags = flags or 0
    return lib.igIsKeyPressed_ID(key,owner_id,flags)
end
function M.IsKeyPressed(a1,a2,a3) -- generic version
    if (ffi.istype('bool',a2) or type(a2)=='boolean') then return M.IsKeyPressed_Bool(a1,a2) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsKeyPressed_ID(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.IsKeyPressed could not find overloaded'
end
M.IsKeyReleased_Nil = lib.igIsKeyReleased_Nil
M.IsKeyReleased_ID = lib.igIsKeyReleased_ID
function M.IsKeyReleased(a1,a2) -- generic version
    if a2==nil then return M.IsKeyReleased_Nil(a1) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsKeyReleased_ID(a1,a2) end
    print(a1,a2)
    error'M.IsKeyReleased could not find overloaded'
end
M.IsKeyboardKey = lib.igIsKeyboardKey
M.IsLegacyKey = lib.igIsLegacyKey
M.IsModKey = lib.igIsModKey
function M.IsMouseClicked_Bool(button,_repeat)
    _repeat = _repeat or false
    return lib.igIsMouseClicked_Bool(button,_repeat)
end
function M.IsMouseClicked_ID(button,owner_id,flags)
    flags = flags or 0
    return lib.igIsMouseClicked_ID(button,owner_id,flags)
end
function M.IsMouseClicked(a1,a2,a3) -- generic version
    if (ffi.istype('bool',a2) or type(a2)=='boolean') then return M.IsMouseClicked_Bool(a1,a2) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsMouseClicked_ID(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.IsMouseClicked could not find overloaded'
end
M.IsMouseDoubleClicked_Nil = lib.igIsMouseDoubleClicked_Nil
M.IsMouseDoubleClicked_ID = lib.igIsMouseDoubleClicked_ID
function M.IsMouseDoubleClicked(a1,a2) -- generic version
    if a2==nil then return M.IsMouseDoubleClicked_Nil(a1) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsMouseDoubleClicked_ID(a1,a2) end
    print(a1,a2)
    error'M.IsMouseDoubleClicked could not find overloaded'
end
M.IsMouseDown_Nil = lib.igIsMouseDown_Nil
M.IsMouseDown_ID = lib.igIsMouseDown_ID
function M.IsMouseDown(a1,a2) -- generic version
    if a2==nil then return M.IsMouseDown_Nil(a1) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsMouseDown_ID(a1,a2) end
    print(a1,a2)
    error'M.IsMouseDown could not find overloaded'
end
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
M.IsMouseKey = lib.igIsMouseKey
function M.IsMousePosValid(mouse_pos)
    mouse_pos = mouse_pos or nil
    return lib.igIsMousePosValid(mouse_pos)
end
M.IsMouseReleased_Nil = lib.igIsMouseReleased_Nil
M.IsMouseReleased_ID = lib.igIsMouseReleased_ID
function M.IsMouseReleased(a1,a2) -- generic version
    if a2==nil then return M.IsMouseReleased_Nil(a1) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsMouseReleased_ID(a1,a2) end
    print(a1,a2)
    error'M.IsMouseReleased could not find overloaded'
end
M.IsNamedKey = lib.igIsNamedKey
M.IsNamedKeyOrModKey = lib.igIsNamedKeyOrModKey
function M.IsPopupOpen_Str(str_id,flags)
    flags = flags or 0
    return lib.igIsPopupOpen_Str(str_id,flags)
end
M.IsPopupOpen_ID = lib.igIsPopupOpen_ID
function M.IsPopupOpen(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.IsPopupOpen_Str(a1,a2) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.IsPopupOpen_ID(a1,a2) end
    print(a1,a2)
    error'M.IsPopupOpen could not find overloaded'
end
M.IsRectVisible_Nil = lib.igIsRectVisible_Nil
M.IsRectVisible_Vec2 = lib.igIsRectVisible_Vec2
function M.IsRectVisible(a1,a2) -- generic version
    if a2==nil then return M.IsRectVisible_Nil(a1) end
    if ffi.istype('const ImVec2',a2) then return M.IsRectVisible_Vec2(a1,a2) end
    print(a1,a2)
    error'M.IsRectVisible could not find overloaded'
end
M.IsWindowAbove = lib.igIsWindowAbove
M.IsWindowAppearing = lib.igIsWindowAppearing
M.IsWindowChildOf = lib.igIsWindowChildOf
M.IsWindowCollapsed = lib.igIsWindowCollapsed
function M.IsWindowContentHoverable(window,flags)
    flags = flags or 0
    return lib.igIsWindowContentHoverable(window,flags)
end
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
M.IsWindowWithinBeginStackOf = lib.igIsWindowWithinBeginStackOf
function M.ItemAdd(bb,id,nav_bb,extra_flags)
    extra_flags = extra_flags or 0
    nav_bb = nav_bb or nil
    return lib.igItemAdd(bb,id,nav_bb,extra_flags)
end
M.ItemHoverable = lib.igItemHoverable
function M.ItemSize_Vec2(size,text_baseline_y)
    text_baseline_y = text_baseline_y or -1.0
    return lib.igItemSize_Vec2(size,text_baseline_y)
end
function M.ItemSize_Rect(bb,text_baseline_y)
    text_baseline_y = text_baseline_y or -1.0
    return lib.igItemSize_Rect(bb,text_baseline_y)
end
function M.ItemSize(a1,a2) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.ItemSize_Vec2(a1,a2) end
    if ffi.istype('const ImRect',a1) then return M.ItemSize_Rect(a1,a2) end
    print(a1,a2)
    error'M.ItemSize could not find overloaded'
end
M.KeepAliveID = lib.igKeepAliveID
M.LabelText = lib.igLabelText
M.LabelTextV = lib.igLabelTextV
function M.ListBox_Str_arr(label,current_item,items,items_count,height_in_items)
    height_in_items = height_in_items or -1
    return lib.igListBox_Str_arr(label,current_item,items,items_count,height_in_items)
end
function M.ListBox_FnStrPtr(label,current_item,getter,user_data,items_count,height_in_items)
    height_in_items = height_in_items or -1
    return lib.igListBox_FnStrPtr(label,current_item,getter,user_data,items_count,height_in_items)
end
function M.ListBox(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('const char* const[]',a3) or ffi.istype('const char const[]',a3) or ffi.istype('const char const[][]',a3)) then return M.ListBox_Str_arr(a1,a2,a3,a4,a5) end
    if ffi.istype('const char*(*)(void* user_data,int idx)',a3) then return M.ListBox_FnStrPtr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ListBox could not find overloaded'
end
M.LoadIniSettingsFromDisk = lib.igLoadIniSettingsFromDisk
function M.LoadIniSettingsFromMemory(ini_data,ini_size)
    ini_size = ini_size or 0
    return lib.igLoadIniSettingsFromMemory(ini_data,ini_size)
end
M.LocalizeGetMsg = lib.igLocalizeGetMsg
M.LocalizeRegisterEntries = lib.igLocalizeRegisterEntries
M.LogBegin = lib.igLogBegin
M.LogButtons = lib.igLogButtons
M.LogFinish = lib.igLogFinish
function M.LogRenderedText(ref_pos,text,text_end)
    text_end = text_end or nil
    return lib.igLogRenderedText(ref_pos,text,text_end)
end
M.LogSetNextTextDecoration = lib.igLogSetNextTextDecoration
M.LogText = lib.igLogText
M.LogTextV = lib.igLogTextV
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
M.MarkIniSettingsDirty_Nil = lib.igMarkIniSettingsDirty_Nil
M.MarkIniSettingsDirty_WindowPtr = lib.igMarkIniSettingsDirty_WindowPtr
function M.MarkIniSettingsDirty(a1) -- generic version
    if a1==nil then return M.MarkIniSettingsDirty_Nil() end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.MarkIniSettingsDirty_WindowPtr(a1) end
    print(a1)
    error'M.MarkIniSettingsDirty could not find overloaded'
end
M.MarkItemEdited = lib.igMarkItemEdited
M.MemAlloc = lib.igMemAlloc
M.MemFree = lib.igMemFree
function M.MenuItem_Bool(label,shortcut,selected,enabled)
    if enabled == nil then enabled = true end
    selected = selected or false
    shortcut = shortcut or nil
    return lib.igMenuItem_Bool(label,shortcut,selected,enabled)
end
function M.MenuItem_BoolPtr(label,shortcut,p_selected,enabled)
    if enabled == nil then enabled = true end
    return lib.igMenuItem_BoolPtr(label,shortcut,p_selected,enabled)
end
function M.MenuItem(a1,a2,a3,a4) -- generic version
    if ((ffi.istype('bool',a3) or type(a3)=='boolean') or type(a3)=='nil') then return M.MenuItem_Bool(a1,a2,a3,a4) end
    if (ffi.istype('bool*',a3) or ffi.istype('bool[]',a3)) then return M.MenuItem_BoolPtr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.MenuItem could not find overloaded'
end
function M.MenuItemEx(label,icon,shortcut,selected,enabled)
    if enabled == nil then enabled = true end
    selected = selected or false
    shortcut = shortcut or nil
    return lib.igMenuItemEx(label,icon,shortcut,selected,enabled)
end
M.MouseButtonToKey = lib.igMouseButtonToKey
M.NavClearPreferredPosForAxis = lib.igNavClearPreferredPosForAxis
M.NavHighlightActivated = lib.igNavHighlightActivated
M.NavInitRequestApplyResult = lib.igNavInitRequestApplyResult
M.NavInitWindow = lib.igNavInitWindow
M.NavMoveRequestApplyResult = lib.igNavMoveRequestApplyResult
M.NavMoveRequestButNoResultYet = lib.igNavMoveRequestButNoResultYet
M.NavMoveRequestCancel = lib.igNavMoveRequestCancel
M.NavMoveRequestForward = lib.igNavMoveRequestForward
M.NavMoveRequestResolveWithLastItem = lib.igNavMoveRequestResolveWithLastItem
M.NavMoveRequestResolveWithPastTreeNode = lib.igNavMoveRequestResolveWithPastTreeNode
M.NavMoveRequestSubmit = lib.igNavMoveRequestSubmit
M.NavMoveRequestTryWrapping = lib.igNavMoveRequestTryWrapping
M.NavRestoreHighlightAfterMove = lib.igNavRestoreHighlightAfterMove
M.NavUpdateCurrentWindowIsScrollPushableX = lib.igNavUpdateCurrentWindowIsScrollPushableX
M.NewFrame = lib.igNewFrame
M.NewLine = lib.igNewLine
M.NextColumn = lib.igNextColumn
function M.OpenPopup_Str(str_id,popup_flags)
    popup_flags = popup_flags or 0
    return lib.igOpenPopup_Str(str_id,popup_flags)
end
function M.OpenPopup_ID(id,popup_flags)
    popup_flags = popup_flags or 0
    return lib.igOpenPopup_ID(id,popup_flags)
end
function M.OpenPopup(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.OpenPopup_Str(a1,a2) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.OpenPopup_ID(a1,a2) end
    print(a1,a2)
    error'M.OpenPopup could not find overloaded'
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
function M.PlotHistogram_FloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
    graph_size = graph_size or ImVec2(0,0)
    overlay_text = overlay_text or nil
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    stride = stride or ffi.sizeof("float")
    values_offset = values_offset or 0
    return lib.igPlotHistogram_FloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
end
function M.PlotHistogram_FnFloatPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
    graph_size = graph_size or ImVec2(0,0)
    overlay_text = overlay_text or nil
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    values_offset = values_offset or 0
    return lib.igPlotHistogram_FnFloatPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
end
function M.PlotHistogram(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.PlotHistogram_FloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.istype('float(*)(void* data,int idx)',a2) then return M.PlotHistogram_FnFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.PlotHistogram could not find overloaded'
end
function M.PlotLines_FloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
    graph_size = graph_size or ImVec2(0,0)
    overlay_text = overlay_text or nil
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    stride = stride or ffi.sizeof("float")
    values_offset = values_offset or 0
    return lib.igPlotLines_FloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
end
function M.PlotLines_FnFloatPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
    graph_size = graph_size or ImVec2(0,0)
    overlay_text = overlay_text or nil
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    values_offset = values_offset or 0
    return lib.igPlotLines_FnFloatPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
end
function M.PlotLines(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.PlotLines_FloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.istype('float(*)(void* data,int idx)',a2) then return M.PlotLines_FnFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.PlotLines could not find overloaded'
end
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
M.PopTabStop = lib.igPopTabStop
M.PopTextWrapPos = lib.igPopTextWrapPos
function M.ProgressBar(fraction,size_arg,overlay)
    overlay = overlay or nil
    size_arg = size_arg or ImVec2(-M.FLT_MIN,0)
    return lib.igProgressBar(fraction,size_arg,overlay)
end
M.PushButtonRepeat = lib.igPushButtonRepeat
M.PushClipRect = lib.igPushClipRect
M.PushColumnClipRect = lib.igPushColumnClipRect
M.PushColumnsBackground = lib.igPushColumnsBackground
M.PushFocusScope = lib.igPushFocusScope
M.PushFont = lib.igPushFont
M.PushID_Str = lib.igPushID_Str
M.PushID_StrStr = lib.igPushID_StrStr
M.PushID_Ptr = lib.igPushID_Ptr
M.PushID_Int = lib.igPushID_Int
function M.PushID(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a2==nil then return M.PushID_Str(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.PushID_StrStr(a1,a2) end
    if ffi.istype('void *',a1) then return M.PushID_Ptr(a1) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.PushID_Int(a1) end
    print(a1,a2)
    error'M.PushID could not find overloaded'
end
M.PushItemFlag = lib.igPushItemFlag
M.PushItemWidth = lib.igPushItemWidth
M.PushMultiItemsWidths = lib.igPushMultiItemsWidths
M.PushOverrideID = lib.igPushOverrideID
M.PushStyleColor_U32 = lib.igPushStyleColor_U32
M.PushStyleColor_Vec4 = lib.igPushStyleColor_Vec4
function M.PushStyleColor(a1,a2) -- generic version
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.PushStyleColor_U32(a1,a2) end
    if ffi.istype('const ImVec4',a2) then return M.PushStyleColor_Vec4(a1,a2) end
    print(a1,a2)
    error'M.PushStyleColor could not find overloaded'
end
M.PushStyleVar_Float = lib.igPushStyleVar_Float
M.PushStyleVar_Vec2 = lib.igPushStyleVar_Vec2
function M.PushStyleVar(a1,a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.PushStyleVar_Float(a1,a2) end
    if ffi.istype('const ImVec2',a2) then return M.PushStyleVar_Vec2(a1,a2) end
    print(a1,a2)
    error'M.PushStyleVar could not find overloaded'
end
M.PushTabStop = lib.igPushTabStop
function M.PushTextWrapPos(wrap_local_pos_x)
    wrap_local_pos_x = wrap_local_pos_x or 0.0
    return lib.igPushTextWrapPos(wrap_local_pos_x)
end
M.RadioButton_Bool = lib.igRadioButton_Bool
M.RadioButton_IntPtr = lib.igRadioButton_IntPtr
function M.RadioButton(a1,a2,a3) -- generic version
    if (ffi.istype('bool',a2) or type(a2)=='boolean') then return M.RadioButton_Bool(a1,a2) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.RadioButton_IntPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.RadioButton could not find overloaded'
end
M.RemoveContextHook = lib.igRemoveContextHook
M.RemoveSettingsHandler = lib.igRemoveSettingsHandler
M.Render = lib.igRender
function M.RenderArrow(draw_list,pos,col,dir,scale)
    scale = scale or 1.0
    return lib.igRenderArrow(draw_list,pos,col,dir,scale)
end
M.RenderArrowDockMenu = lib.igRenderArrowDockMenu
M.RenderArrowPointingAt = lib.igRenderArrowPointingAt
M.RenderBullet = lib.igRenderBullet
M.RenderCheckMark = lib.igRenderCheckMark
function M.RenderColorRectWithAlphaCheckerboard(draw_list,p_min,p_max,fill_col,grid_step,grid_off,rounding,flags)
    flags = flags or 0
    rounding = rounding or 0.0
    return lib.igRenderColorRectWithAlphaCheckerboard(draw_list,p_min,p_max,fill_col,grid_step,grid_off,rounding,flags)
end
M.RenderDragDropTargetRect = lib.igRenderDragDropTargetRect
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
    flags = flags or 0
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
M.ScrollToBringRectIntoView = lib.igScrollToBringRectIntoView
function M.ScrollToItem(flags)
    flags = flags or 0
    return lib.igScrollToItem(flags)
end
function M.ScrollToRect(window,rect,flags)
    flags = flags or 0
    return lib.igScrollToRect(window,rect,flags)
end
function M.ScrollToRectEx(window,rect,flags)
    flags = flags or 0
    local nonUDT_out = ffi.new("ImVec2")
    lib.igScrollToRectEx(nonUDT_out,window,rect,flags)
    return nonUDT_out
end
M.Scrollbar = lib.igScrollbar
M.ScrollbarEx = lib.igScrollbarEx
function M.Selectable_Bool(label,selected,flags,size)
    flags = flags or 0
    selected = selected or false
    size = size or ImVec2(0,0)
    return lib.igSelectable_Bool(label,selected,flags,size)
end
function M.Selectable_BoolPtr(label,p_selected,flags,size)
    flags = flags or 0
    size = size or ImVec2(0,0)
    return lib.igSelectable_BoolPtr(label,p_selected,flags,size)
end
function M.Selectable(a1,a2,a3,a4) -- generic version
    if ((ffi.istype('bool',a2) or type(a2)=='boolean') or type(a2)=='nil') then return M.Selectable_Bool(a1,a2,a3,a4) end
    if (ffi.istype('bool*',a2) or ffi.istype('bool[]',a2)) then return M.Selectable_BoolPtr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.Selectable could not find overloaded'
end
M.Separator = lib.igSeparator
function M.SeparatorEx(flags,thickness)
    thickness = thickness or 1.0
    return lib.igSeparatorEx(flags,thickness)
end
M.SeparatorText = lib.igSeparatorText
M.SeparatorTextEx = lib.igSeparatorTextEx
M.SetActiveID = lib.igSetActiveID
M.SetActiveIdUsingAllKeyboardKeys = lib.igSetActiveIdUsingAllKeyboardKeys
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
M.SetCurrentViewport = lib.igSetCurrentViewport
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
M.SetItemDefaultFocus = lib.igSetItemDefaultFocus
function M.SetItemKeyOwner(key,flags)
    flags = flags or 0
    return lib.igSetItemKeyOwner(key,flags)
end
M.SetItemTooltip = lib.igSetItemTooltip
M.SetItemTooltipV = lib.igSetItemTooltipV
function M.SetKeyOwner(key,owner_id,flags)
    flags = flags or 0
    return lib.igSetKeyOwner(key,owner_id,flags)
end
function M.SetKeyOwnersForKeyChord(key,owner_id,flags)
    flags = flags or 0
    return lib.igSetKeyOwnersForKeyChord(key,owner_id,flags)
end
function M.SetKeyboardFocusHere(offset)
    offset = offset or 0
    return lib.igSetKeyboardFocusHere(offset)
end
M.SetLastItemData = lib.igSetLastItemData
M.SetMouseCursor = lib.igSetMouseCursor
M.SetNavFocusScope = lib.igSetNavFocusScope
M.SetNavID = lib.igSetNavID
M.SetNavWindow = lib.igSetNavWindow
M.SetNextFrameWantCaptureKeyboard = lib.igSetNextFrameWantCaptureKeyboard
M.SetNextFrameWantCaptureMouse = lib.igSetNextFrameWantCaptureMouse
M.SetNextItemAllowOverlap = lib.igSetNextItemAllowOverlap
function M.SetNextItemOpen(is_open,cond)
    cond = cond or 0
    return lib.igSetNextItemOpen(is_open,cond)
end
M.SetNextItemSelectionUserData = lib.igSetNextItemSelectionUserData
M.SetNextItemShortcut = lib.igSetNextItemShortcut
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
function M.SetScrollFromPosX_Float(local_x,center_x_ratio)
    center_x_ratio = center_x_ratio or 0.5
    return lib.igSetScrollFromPosX_Float(local_x,center_x_ratio)
end
M.SetScrollFromPosX_WindowPtr = lib.igSetScrollFromPosX_WindowPtr
function M.SetScrollFromPosX(a1,a2,a3) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.SetScrollFromPosX_Float(a1,a2) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetScrollFromPosX_WindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetScrollFromPosX could not find overloaded'
end
function M.SetScrollFromPosY_Float(local_y,center_y_ratio)
    center_y_ratio = center_y_ratio or 0.5
    return lib.igSetScrollFromPosY_Float(local_y,center_y_ratio)
end
M.SetScrollFromPosY_WindowPtr = lib.igSetScrollFromPosY_WindowPtr
function M.SetScrollFromPosY(a1,a2,a3) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.SetScrollFromPosY_Float(a1,a2) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetScrollFromPosY_WindowPtr(a1,a2,a3) end
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
M.SetScrollX_Float = lib.igSetScrollX_Float
M.SetScrollX_WindowPtr = lib.igSetScrollX_WindowPtr
function M.SetScrollX(a1,a2) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.SetScrollX_Float(a1) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetScrollX_WindowPtr(a1,a2) end
    print(a1,a2)
    error'M.SetScrollX could not find overloaded'
end
M.SetScrollY_Float = lib.igSetScrollY_Float
M.SetScrollY_WindowPtr = lib.igSetScrollY_WindowPtr
function M.SetScrollY(a1,a2) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.SetScrollY_Float(a1) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetScrollY_WindowPtr(a1,a2) end
    print(a1,a2)
    error'M.SetScrollY could not find overloaded'
end
function M.SetShortcutRouting(key_chord,owner_id,flags)
    flags = flags or 0
    return lib.igSetShortcutRouting(key_chord,owner_id,flags)
end
M.SetStateStorage = lib.igSetStateStorage
M.SetTabItemClosed = lib.igSetTabItemClosed
M.SetTooltip = lib.igSetTooltip
M.SetTooltipV = lib.igSetTooltipV
M.SetWindowClipRectBeforeSetChannel = lib.igSetWindowClipRectBeforeSetChannel
function M.SetWindowCollapsed_Bool(collapsed,cond)
    cond = cond or 0
    return lib.igSetWindowCollapsed_Bool(collapsed,cond)
end
function M.SetWindowCollapsed_Str(name,collapsed,cond)
    cond = cond or 0
    return lib.igSetWindowCollapsed_Str(name,collapsed,cond)
end
function M.SetWindowCollapsed_WindowPtr(window,collapsed,cond)
    cond = cond or 0
    return lib.igSetWindowCollapsed_WindowPtr(window,collapsed,cond)
end
function M.SetWindowCollapsed(a1,a2,a3) -- generic version
    if (ffi.istype('bool',a1) or type(a1)=='boolean') then return M.SetWindowCollapsed_Bool(a1,a2) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.SetWindowCollapsed_Str(a1,a2,a3) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetWindowCollapsed_WindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetWindowCollapsed could not find overloaded'
end
M.SetWindowDock = lib.igSetWindowDock
M.SetWindowFocus_Nil = lib.igSetWindowFocus_Nil
M.SetWindowFocus_Str = lib.igSetWindowFocus_Str
function M.SetWindowFocus(a1) -- generic version
    if a1==nil then return M.SetWindowFocus_Nil() end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.SetWindowFocus_Str(a1) end
    print(a1)
    error'M.SetWindowFocus could not find overloaded'
end
M.SetWindowFontScale = lib.igSetWindowFontScale
M.SetWindowHiddenAndSkipItemsForCurrentFrame = lib.igSetWindowHiddenAndSkipItemsForCurrentFrame
M.SetWindowHitTestHole = lib.igSetWindowHitTestHole
M.SetWindowParentWindowForFocusRoute = lib.igSetWindowParentWindowForFocusRoute
function M.SetWindowPos_Vec2(pos,cond)
    cond = cond or 0
    return lib.igSetWindowPos_Vec2(pos,cond)
end
function M.SetWindowPos_Str(name,pos,cond)
    cond = cond or 0
    return lib.igSetWindowPos_Str(name,pos,cond)
end
function M.SetWindowPos_WindowPtr(window,pos,cond)
    cond = cond or 0
    return lib.igSetWindowPos_WindowPtr(window,pos,cond)
end
function M.SetWindowPos(a1,a2,a3) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.SetWindowPos_Vec2(a1,a2) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.SetWindowPos_Str(a1,a2,a3) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetWindowPos_WindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetWindowPos could not find overloaded'
end
function M.SetWindowSize_Vec2(size,cond)
    cond = cond or 0
    return lib.igSetWindowSize_Vec2(size,cond)
end
function M.SetWindowSize_Str(name,size,cond)
    cond = cond or 0
    return lib.igSetWindowSize_Str(name,size,cond)
end
function M.SetWindowSize_WindowPtr(window,size,cond)
    cond = cond or 0
    return lib.igSetWindowSize_WindowPtr(window,size,cond)
end
function M.SetWindowSize(a1,a2,a3) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.SetWindowSize_Vec2(a1,a2) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.SetWindowSize_Str(a1,a2,a3) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetWindowSize_WindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetWindowSize could not find overloaded'
end
M.SetWindowViewport = lib.igSetWindowViewport
M.ShadeVertsLinearColorGradientKeepAlpha = lib.igShadeVertsLinearColorGradientKeepAlpha
M.ShadeVertsLinearUV = lib.igShadeVertsLinearUV
M.ShadeVertsTransformPos = lib.igShadeVertsTransformPos
function M.Shortcut(key_chord,owner_id,flags)
    flags = flags or 0
    owner_id = owner_id or 0
    return lib.igShortcut(key_chord,owner_id,flags)
end
function M.ShowAboutWindow(p_open)
    p_open = p_open or nil
    return lib.igShowAboutWindow(p_open)
end
function M.ShowDebugLogWindow(p_open)
    p_open = p_open or nil
    return lib.igShowDebugLogWindow(p_open)
end
function M.ShowDemoWindow(p_open)
    p_open = p_open or nil
    return lib.igShowDemoWindow(p_open)
end
M.ShowFontAtlas = lib.igShowFontAtlas
M.ShowFontSelector = lib.igShowFontSelector
function M.ShowIDStackToolWindow(p_open)
    p_open = p_open or nil
    return lib.igShowIDStackToolWindow(p_open)
end
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
function M.SplitterBehavior(bb,id,axis,size1,size2,min_size1,min_size2,hover_extend,hover_visibility_delay,bg_col)
    bg_col = bg_col or 0
    hover_extend = hover_extend or 0.0
    hover_visibility_delay = hover_visibility_delay or 0.0
    return lib.igSplitterBehavior(bb,id,axis,size1,size2,min_size1,min_size2,hover_extend,hover_visibility_delay,bg_col)
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
M.TabBarFindTabByOrder = lib.igTabBarFindTabByOrder
M.TabBarGetCurrentTab = lib.igTabBarGetCurrentTab
M.TabBarGetTabName = lib.igTabBarGetTabName
M.TabBarGetTabOrder = lib.igTabBarGetTabOrder
M.TabBarProcessReorder = lib.igTabBarProcessReorder
M.TabBarQueueFocus = lib.igTabBarQueueFocus
M.TabBarQueueReorder = lib.igTabBarQueueReorder
M.TabBarQueueReorderFromMousePos = lib.igTabBarQueueReorderFromMousePos
M.TabBarRemoveTab = lib.igTabBarRemoveTab
M.TabItemBackground = lib.igTabItemBackground
function M.TabItemButton(label,flags)
    flags = flags or 0
    return lib.igTabItemButton(label,flags)
end
function M.TabItemCalcSize_Str(label,has_close_button_or_unsaved_marker)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igTabItemCalcSize_Str(nonUDT_out,label,has_close_button_or_unsaved_marker)
    return nonUDT_out
end
function M.TabItemCalcSize_WindowPtr(window)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igTabItemCalcSize_WindowPtr(nonUDT_out,window)
    return nonUDT_out
end
function M.TabItemCalcSize(a2,a3) -- generic version
    if (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.TabItemCalcSize_Str(a2,a3) end
    if (ffi.istype('ImGuiWindow*',a2) or ffi.istype('ImGuiWindow',a2) or ffi.istype('ImGuiWindow[]',a2)) then return M.TabItemCalcSize_WindowPtr(a2) end
    print(a2,a3)
    error'M.TabItemCalcSize could not find overloaded'
end
M.TabItemEx = lib.igTabItemEx
M.TabItemLabelAndCloseButton = lib.igTabItemLabelAndCloseButton
M.TableAngledHeadersRow = lib.igTableAngledHeadersRow
function M.TableAngledHeadersRowEx(angle,label_width)
    label_width = label_width or 0.0
    return lib.igTableAngledHeadersRowEx(angle,label_width)
end
M.TableBeginApplyRequests = lib.igTableBeginApplyRequests
M.TableBeginCell = lib.igTableBeginCell
M.TableBeginContextMenuPopup = lib.igTableBeginContextMenuPopup
M.TableBeginInitMemory = lib.igTableBeginInitMemory
M.TableBeginRow = lib.igTableBeginRow
M.TableDrawBorders = lib.igTableDrawBorders
M.TableDrawDefaultContextMenu = lib.igTableDrawDefaultContextMenu
M.TableEndCell = lib.igTableEndCell
M.TableEndRow = lib.igTableEndRow
M.TableFindByID = lib.igTableFindByID
M.TableFixColumnSortDirection = lib.igTableFixColumnSortDirection
M.TableGcCompactSettings = lib.igTableGcCompactSettings
M.TableGcCompactTransientBuffers_TablePtr = lib.igTableGcCompactTransientBuffers_TablePtr
M.TableGcCompactTransientBuffers_TableTempDataPtr = lib.igTableGcCompactTransientBuffers_TableTempDataPtr
function M.TableGcCompactTransientBuffers(a1) -- generic version
    if (ffi.istype('ImGuiTable*',a1) or ffi.istype('ImGuiTable',a1) or ffi.istype('ImGuiTable[]',a1)) then return M.TableGcCompactTransientBuffers_TablePtr(a1) end
    if (ffi.istype('ImGuiTableTempData*',a1) or ffi.istype('ImGuiTableTempData',a1) or ffi.istype('ImGuiTableTempData[]',a1)) then return M.TableGcCompactTransientBuffers_TableTempDataPtr(a1) end
    print(a1)
    error'M.TableGcCompactTransientBuffers could not find overloaded'
end
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
function M.TableGetColumnName_Int(column_n)
    column_n = column_n or -1
    return lib.igTableGetColumnName_Int(column_n)
end
M.TableGetColumnName_TablePtr = lib.igTableGetColumnName_TablePtr
function M.TableGetColumnName(a1,a2) -- generic version
    if ((ffi.istype('int32_t',a1) or type(a1)=='number') or type(a1)=='nil') then return M.TableGetColumnName_Int(a1) end
    if (ffi.istype('const ImGuiTable*',a1) or ffi.istype('const ImGuiTable',a1) or ffi.istype('const ImGuiTable[]',a1)) then return M.TableGetColumnName_TablePtr(a1,a2) end
    print(a1,a2)
    error'M.TableGetColumnName could not find overloaded'
end
M.TableGetColumnNextSortDirection = lib.igTableGetColumnNextSortDirection
function M.TableGetColumnResizeID(table,column_n,instance_no)
    instance_no = instance_no or 0
    return lib.igTableGetColumnResizeID(table,column_n,instance_no)
end
M.TableGetColumnWidthAuto = lib.igTableGetColumnWidthAuto
M.TableGetHeaderAngledMaxLabelWidth = lib.igTableGetHeaderAngledMaxLabelWidth
M.TableGetHeaderRowHeight = lib.igTableGetHeaderRowHeight
M.TableGetHoveredColumn = lib.igTableGetHoveredColumn
M.TableGetHoveredRow = lib.igTableGetHoveredRow
M.TableGetInstanceData = lib.igTableGetInstanceData
M.TableGetInstanceID = lib.igTableGetInstanceID
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
M.TableSettingsAddSettingsHandler = lib.igTableSettingsAddSettingsHandler
M.TableSettingsCreate = lib.igTableSettingsCreate
M.TableSettingsFindByID = lib.igTableSettingsFindByID
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
M.TeleportMousePos = lib.igTeleportMousePos
M.TempInputIsActive = lib.igTempInputIsActive
function M.TempInputScalar(bb,id,label,data_type,p_data,format,p_clamp_min,p_clamp_max)
    p_clamp_max = p_clamp_max or nil
    p_clamp_min = p_clamp_min or nil
    return lib.igTempInputScalar(bb,id,label,data_type,p_data,format,p_clamp_min,p_clamp_max)
end
M.TempInputText = lib.igTempInputText
M.TestKeyOwner = lib.igTestKeyOwner
M.TestShortcutRouting = lib.igTestShortcutRouting
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
M.TreeNode_Str = lib.igTreeNode_Str
M.TreeNode_StrStr = lib.igTreeNode_StrStr
M.TreeNode_Ptr = lib.igTreeNode_Ptr
function M.TreeNode(a1,a2,...) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a2==nil then return M.TreeNode_Str(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.TreeNode_StrStr(a1,a2,...) end
    if ffi.istype('void *',a1) then return M.TreeNode_Ptr(a1,a2,...) end
    print(a1,a2,...)
    error'M.TreeNode could not find overloaded'
end
function M.TreeNodeBehavior(id,flags,label,label_end)
    label_end = label_end or nil
    return lib.igTreeNodeBehavior(id,flags,label,label_end)
end
function M.TreeNodeEx_Str(label,flags)
    flags = flags or 0
    return lib.igTreeNodeEx_Str(label,flags)
end
M.TreeNodeEx_StrStr = lib.igTreeNodeEx_StrStr
M.TreeNodeEx_Ptr = lib.igTreeNodeEx_Ptr
function M.TreeNodeEx(a1,a2,a3,...) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a3==nil then return M.TreeNodeEx_Str(a1,a2) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.TreeNodeEx_StrStr(a1,a2,a3,...) end
    if ffi.istype('void *',a1) then return M.TreeNodeEx_Ptr(a1,a2,a3,...) end
    print(a1,a2,a3,...)
    error'M.TreeNodeEx could not find overloaded'
end
M.TreeNodeExV_Str = lib.igTreeNodeExV_Str
M.TreeNodeExV_Ptr = lib.igTreeNodeExV_Ptr
function M.TreeNodeExV(a1,a2,a3,a4) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.TreeNodeExV_Str(a1,a2,a3,a4) end
    if ffi.istype('void *',a1) then return M.TreeNodeExV_Ptr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.TreeNodeExV could not find overloaded'
end
M.TreeNodeSetOpen = lib.igTreeNodeSetOpen
M.TreeNodeUpdateNextOpen = lib.igTreeNodeUpdateNextOpen
M.TreeNodeV_Str = lib.igTreeNodeV_Str
M.TreeNodeV_Ptr = lib.igTreeNodeV_Ptr
function M.TreeNodeV(a1,a2,a3) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.TreeNodeV_Str(a1,a2,a3) end
    if ffi.istype('void *',a1) then return M.TreeNodeV_Ptr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.TreeNodeV could not find overloaded'
end
M.TreePop = lib.igTreePop
M.TreePush_Str = lib.igTreePush_Str
M.TreePush_Ptr = lib.igTreePush_Ptr
function M.TreePush(a1) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.TreePush_Str(a1) end
    if ffi.istype('void *',a1) then return M.TreePush_Ptr(a1) end
    print(a1)
    error'M.TreePush could not find overloaded'
end
M.TreePushOverrideID = lib.igTreePushOverrideID
M.TypingSelectFindBestLeadingMatch = lib.igTypingSelectFindBestLeadingMatch
M.TypingSelectFindMatch = lib.igTypingSelectFindMatch
M.TypingSelectFindNextSingleCharMatch = lib.igTypingSelectFindNextSingleCharMatch
function M.Unindent(indent_w)
    indent_w = indent_w or 0.0
    return lib.igUnindent(indent_w)
end
M.UpdateHoveredWindowAndCaptureFlags = lib.igUpdateHoveredWindowAndCaptureFlags
M.UpdateInputEvents = lib.igUpdateInputEvents
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
M.Value_Bool = lib.igValue_Bool
M.Value_Int = lib.igValue_Int
M.Value_Uint = lib.igValue_Uint
function M.Value_Float(prefix,v,float_format)
    float_format = float_format or nil
    return lib.igValue_Float(prefix,v,float_format)
end
function M.Value(a1,a2,a3) -- generic version
    if (ffi.istype('bool',a2) or type(a2)=='boolean') then return M.Value_Bool(a1,a2) end
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return M.Value_Int(a1,a2) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.Value_Uint(a1,a2) end
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.Value_Float(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.Value could not find overloaded'
end
function M.WindowPosRelToAbs(window,p)
    local nonUDT_out = ffi.new("ImVec2")
    lib.igWindowPosRelToAbs(nonUDT_out,window,p)
    return nonUDT_out
end
function M.WindowRectAbsToRel(window,r)
    local nonUDT_out = ffi.new("ImRect")
    lib.igWindowRectAbsToRel(nonUDT_out,window,r)
    return nonUDT_out
end
function M.WindowRectRelToAbs(window,r)
    local nonUDT_out = ffi.new("ImRect")
    lib.igWindowRectRelToAbs(nonUDT_out,window,r)
    return nonUDT_out
end
function M.gizmo3D_quatPtrFloat(noname1,noname2,noname3,noname4)
    noname4 = noname4 or 257
    return lib.iggizmo3D_quatPtrFloat(noname1,noname2,noname3,noname4)
end
function M.gizmo3D_vec4Ptr(noname1,noname2,noname3,noname4)
    noname4 = noname4 or 257
    return lib.iggizmo3D_vec4Ptr(noname1,noname2,noname3,noname4)
end
function M.gizmo3D_vec3PtrFloat(noname1,noname2,noname3,noname4)
    noname4 = noname4 or 2
    return lib.iggizmo3D_vec3PtrFloat(noname1,noname2,noname3,noname4)
end
function M.gizmo3D_quatPtrquatPtr(noname1,noname2,noname3,noname4,noname5)
    noname5 = noname5 or 264
    return lib.iggizmo3D_quatPtrquatPtr(noname1,noname2,noname3,noname4,noname5)
end
function M.gizmo3D_quatPtrvec4Ptr(noname1,noname2,noname3,noname4,noname5)
    noname5 = noname5 or 264
    return lib.iggizmo3D_quatPtrvec4Ptr(noname1,noname2,noname3,noname4,noname5)
end
function M.gizmo3D_quatPtrvec3Ptr(noname1,noname2,noname3,noname4,noname5)
    noname5 = noname5 or 264
    return lib.iggizmo3D_quatPtrvec3Ptr(noname1,noname2,noname3,noname4,noname5)
end
function M.gizmo3D_vec3PtrquatPtrFloat(noname1,noname2,noname3,noname4,noname5)
    noname5 = noname5 or 257
    return lib.iggizmo3D_vec3PtrquatPtrFloat(noname1,noname2,noname3,noname4,noname5)
end
function M.gizmo3D_vec3Ptrvec4Ptr(noname1,noname2,noname3,noname4,noname5)
    noname5 = noname5 or 257
    return lib.iggizmo3D_vec3Ptrvec4Ptr(noname1,noname2,noname3,noname4,noname5)
end
function M.gizmo3D_vec3Ptrvec3Ptr(noname1,noname2,noname3,noname4,noname5)
    noname5 = noname5 or 2
    return lib.iggizmo3D_vec3Ptrvec3Ptr(noname1,noname2,noname3,noname4,noname5)
end
function M.gizmo3D_vec3PtrquatPtrquatPtr(noname1,noname2,noname3,noname4,noname5,noname6)
    noname6 = noname6 or 264
    return lib.iggizmo3D_vec3PtrquatPtrquatPtr(noname1,noname2,noname3,noname4,noname5,noname6)
end
function M.gizmo3D_vec3PtrquatPtrvec4Ptr(noname1,noname2,noname3,noname4,noname5,noname6)
    noname6 = noname6 or 264
    return lib.iggizmo3D_vec3PtrquatPtrvec4Ptr(noname1,noname2,noname3,noname4,noname5,noname6)
end
function M.gizmo3D_vec3PtrquatPtrvec3Ptr(noname1,noname2,noname3,noname4,noname5,noname6)
    noname6 = noname6 or 264
    return lib.iggizmo3D_vec3PtrquatPtrvec3Ptr(noname1,noname2,noname3,noname4,noname5,noname6)
end
function M.gizmo3D(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('quat*',a2) or ffi.istype('quat',a2) or ffi.istype('quat[]',a2)) and (ffi.istype('float',a3) or type(a3)=='number') and ((ffi.istype('int32_t',a4) or type(a4)=='number') or type(a4)=='nil') and a5==nil then return M.gizmo3D_quatPtrFloat(a1,a2,a3,a4) end
    if (ffi.istype('G3Dvec4*',a2) or ffi.istype('G3Dvec4',a2) or ffi.istype('G3Dvec4[]',a2)) then return M.gizmo3D_vec4Ptr(a1,a2,a3,a4) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('float',a3) or type(a3)=='number') and ((ffi.istype('int32_t',a4) or type(a4)=='number') or type(a4)=='nil') and a5==nil then return M.gizmo3D_vec3PtrFloat(a1,a2,a3,a4) end
    if (ffi.istype('quat*',a2) or ffi.istype('quat',a2) or ffi.istype('quat[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3D_quatPtrquatPtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('quat*',a2) or ffi.istype('quat',a2) or ffi.istype('quat[]',a2)) and (ffi.istype('G3Dvec4*',a3) or ffi.istype('G3Dvec4',a3) or ffi.istype('G3Dvec4[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3D_quatPtrvec4Ptr(a1,a2,a3,a4,a5) end
    if (ffi.istype('quat*',a2) or ffi.istype('quat',a2) or ffi.istype('quat[]',a2)) and (ffi.istype('G3Dvec3*',a3) or ffi.istype('G3Dvec3',a3) or ffi.istype('G3Dvec3[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3D_quatPtrvec3Ptr(a1,a2,a3,a4,a5) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3D_vec3PtrquatPtrFloat(a1,a2,a3,a4,a5) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('G3Dvec4*',a3) or ffi.istype('G3Dvec4',a3) or ffi.istype('G3Dvec4[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3D_vec3Ptrvec4Ptr(a1,a2,a3,a4,a5) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('G3Dvec3*',a3) or ffi.istype('G3Dvec3',a3) or ffi.istype('G3Dvec3[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('int32_t',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3D_vec3Ptrvec3Ptr(a1,a2,a3,a4,a5) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('quat*',a4) or ffi.istype('quat',a4) or ffi.istype('quat[]',a4)) then return M.gizmo3D_vec3PtrquatPtrquatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('G3Dvec4*',a4) or ffi.istype('G3Dvec4',a4) or ffi.istype('G3Dvec4[]',a4)) then return M.gizmo3D_vec3PtrquatPtrvec4Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('G3Dvec3*',a2) or ffi.istype('G3Dvec3',a2) or ffi.istype('G3Dvec3[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('G3Dvec3*',a4) or ffi.istype('G3Dvec3',a4) or ffi.istype('G3Dvec3[]',a4)) then return M.gizmo3D_vec3PtrquatPtrvec3Ptr(a1,a2,a3,a4,a5,a6) end
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
M.imnodes_ClearLinkSelection_Nil = lib.imnodes_ClearLinkSelection_Nil
M.imnodes_ClearLinkSelection_Int = lib.imnodes_ClearLinkSelection_Int
function M.imnodes_ClearLinkSelection(a1) -- generic version
    if a1==nil then return M.imnodes_ClearLinkSelection_Nil() end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.imnodes_ClearLinkSelection_Int(a1) end
    print(a1)
    error'M.imnodes_ClearLinkSelection could not find overloaded'
end
M.imnodes_ClearNodeSelection_Nil = lib.imnodes_ClearNodeSelection_Nil
M.imnodes_ClearNodeSelection_Int = lib.imnodes_ClearNodeSelection_Int
function M.imnodes_ClearNodeSelection(a1) -- generic version
    if a1==nil then return M.imnodes_ClearNodeSelection_Nil() end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.imnodes_ClearNodeSelection_Int(a1) end
    print(a1)
    error'M.imnodes_ClearNodeSelection could not find overloaded'
end
M.imnodes_CreateContext = lib.imnodes_CreateContext
function M.imnodes_DestroyContext(ctx)
    ctx = ctx or nil
    return lib.imnodes_DestroyContext(ctx)
end
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
M.imnodes_GetCurrentContext = lib.imnodes_GetCurrentContext
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
function M.imnodes_IsAnyAttributeActive(attribute_id)
    attribute_id = attribute_id or nil
    return lib.imnodes_IsAnyAttributeActive(attribute_id)
end
M.imnodes_IsAttributeActive = lib.imnodes_IsAttributeActive
M.imnodes_IsEditorHovered = lib.imnodes_IsEditorHovered
function M.imnodes_IsLinkCreated_BoolPtr(started_at_attribute_id,ended_at_attribute_id,created_from_snap)
    created_from_snap = created_from_snap or nil
    return lib.imnodes_IsLinkCreated_BoolPtr(started_at_attribute_id,ended_at_attribute_id,created_from_snap)
end
function M.imnodes_IsLinkCreated_IntPtr(started_at_node_id,started_at_attribute_id,ended_at_node_id,ended_at_attribute_id,created_from_snap)
    created_from_snap = created_from_snap or nil
    return lib.imnodes_IsLinkCreated_IntPtr(started_at_node_id,started_at_attribute_id,ended_at_node_id,ended_at_attribute_id,created_from_snap)
end
function M.imnodes_IsLinkCreated(a1,a2,a3,a4,a5) -- generic version
    if ((ffi.istype('bool*',a3) or ffi.istype('bool[]',a3)) or type(a3)=='nil') then return M.imnodes_IsLinkCreated_BoolPtr(a1,a2,a3) end
    if ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) then return M.imnodes_IsLinkCreated_IntPtr(a1,a2,a3,a4,a5) end
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
M.imnodes_IsLinkSelected = lib.imnodes_IsLinkSelected
M.imnodes_IsLinkStarted = lib.imnodes_IsLinkStarted
M.imnodes_IsNodeHovered = lib.imnodes_IsNodeHovered
M.imnodes_IsNodeSelected = lib.imnodes_IsNodeSelected
M.imnodes_IsPinHovered = lib.imnodes_IsPinHovered
M.imnodes_Link = lib.imnodes_Link
M.imnodes_LoadCurrentEditorStateFromIniFile = lib.imnodes_LoadCurrentEditorStateFromIniFile
M.imnodes_LoadCurrentEditorStateFromIniString = lib.imnodes_LoadCurrentEditorStateFromIniString
M.imnodes_LoadEditorStateFromIniFile = lib.imnodes_LoadEditorStateFromIniFile
M.imnodes_LoadEditorStateFromIniString = lib.imnodes_LoadEditorStateFromIniString
function M.imnodes_MiniMap(minimap_size_fraction,location,node_hovering_callback,node_hovering_callback_data)
    location = location or 2
    minimap_size_fraction = minimap_size_fraction or 0.2
    node_hovering_callback = node_hovering_callback or nil
    node_hovering_callback_data = node_hovering_callback_data or nil
    return lib.imnodes_MiniMap(minimap_size_fraction,location,node_hovering_callback,node_hovering_callback_data)
end
M.imnodes_NumSelectedLinks = lib.imnodes_NumSelectedLinks
M.imnodes_NumSelectedNodes = lib.imnodes_NumSelectedNodes
M.imnodes_PopAttributeFlag = lib.imnodes_PopAttributeFlag
M.imnodes_PopColorStyle = lib.imnodes_PopColorStyle
function M.imnodes_PopStyleVar(count)
    count = count or 1
    return lib.imnodes_PopStyleVar(count)
end
M.imnodes_PushAttributeFlag = lib.imnodes_PushAttributeFlag
M.imnodes_PushColorStyle = lib.imnodes_PushColorStyle
M.imnodes_PushStyleVar_Float = lib.imnodes_PushStyleVar_Float
M.imnodes_PushStyleVar_Vec2 = lib.imnodes_PushStyleVar_Vec2
function M.imnodes_PushStyleVar(a1,a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.imnodes_PushStyleVar_Float(a1,a2) end
    if ffi.istype('const ImVec2',a2) then return M.imnodes_PushStyleVar_Vec2(a1,a2) end
    print(a1,a2)
    error'M.imnodes_PushStyleVar could not find overloaded'
end
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
M.imnodes_SelectLink = lib.imnodes_SelectLink
M.imnodes_SelectNode = lib.imnodes_SelectNode
M.imnodes_SetCurrentContext = lib.imnodes_SetCurrentContext
M.imnodes_SetImGuiContext = lib.imnodes_SetImGuiContext
M.imnodes_SetNodeDraggable = lib.imnodes_SetNodeDraggable
M.imnodes_SetNodeEditorSpacePos = lib.imnodes_SetNodeEditorSpacePos
M.imnodes_SetNodeGridSpacePos = lib.imnodes_SetNodeGridSpacePos
M.imnodes_SetNodeScreenSpacePos = lib.imnodes_SetNodeScreenSpacePos
M.imnodes_SnapNodeToGrid = lib.imnodes_SnapNodeToGrid
function M.imnodes_StyleColorsClassic(dest)
    dest = dest or nil
    return lib.imnodes_StyleColorsClassic(dest)
end
function M.imnodes_StyleColorsDark(dest)
    dest = dest or nil
    return lib.imnodes_StyleColorsDark(dest)
end
function M.imnodes_StyleColorsLight(dest)
    dest = dest or nil
    return lib.imnodes_StyleColorsLight(dest)
end
return M
----------END_AUTOGENERATED_LUA-----------------------------