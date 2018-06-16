local ffi = require"ffi"

--uncomment to debug cdef calls
---[[
local ffi_cdef = ffi.cdef
ffi.cdef = function(code)
	local ret,err = pcall(ffi_cdef,code)
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
--]]

assert(cdecl, "imgui.lua not properly build")
ffi.cdef(cdecl)

-- glfw3 implementation and extras ----------------------------------------
ffi.cdef[[

//////////////// glfw3 gl3 Implementation
int Do_gl3wInit(void);
typedef struct GLFWwindow GLFWwindow;
typedef struct {
	// Data
	GLFWwindow*  g_Window ;
	struct ImGuiContext* ctx;
	double       g_Time ;
	bool         g_MousePressed[3] ;
	float        g_MouseWheel;
	unsigned int g_FontTexture;
	int          g_ShaderHandle, g_VertHandle, g_FragHandle;
	int          g_AttribLocationTex, g_AttribLocationProjMtx;
	int          g_AttribLocationPosition, g_AttribLocationUV, g_AttribLocationColor;
	unsigned int g_VboHandle, g_VaoHandle, g_ElementsHandle;
}ImGui_ImplGlfwGL3;

ImGui_ImplGlfwGL3* ImGui_ImplGlfwGL3_new();
void ImGui_ImplGlfwGL3_delete(ImGui_ImplGlfwGL3*);
bool        ImGui_ImplGlfwGL3_Init(ImGui_ImplGlfwGL3*,GLFWwindow* window, bool install_callbacks);
void        ImGui_ImplGlfwGL3_NewFrame(ImGui_ImplGlfwGL3*);
void        ImGui_ImplGlfwGL3_Render(ImGui_ImplGlfwGL3* impl);
// Use if you want to reset your rendering device without losing ImGui state.
void        ImGui_ImplGlfwGL3_InvalidateDeviceObjects(ImGui_ImplGlfwGL3*);
void 		ImGui_ImplGlfwGL3_Set(ImGui_ImplGlfwGL3*);
// bool        ImGui_ImplGlfwGL3_CreateDeviceObjects();

// GLFW callbacks (installed by default if you enable 'install_callbacks' during initialization)
// Provided here if you want to chain callbacks.
// You can also handle inputs yourself and use those as a reference.
 void        ImGui_ImplGlfwGL3_MouseButtonCallback(GLFWwindow* window, int button, int action, int mods);
 void        ImGui_ImplGlfwGL3_ScrollCallback(GLFWwindow* window, double xoffset, double yoffset);
 void        ImGui_ImplGlfwGL3_KeyCallback(GLFWwindow* window, int key, int scancode, int action, int mods);
 void        ImGui_ImplGlfwGL3_CharCallback(GLFWwindow* window, unsigned int c);
 
//addons
bool Knob(const char* label, float* value_p, float minv, float maxv);
int Bezier( const char *label, float P[4] );
bool Curve(const char *label, const struct ImVec2& size, struct ImVec2 *points, const int maxpoints, float *data, int datalen);
void CurveGetData(struct ImVec2 *points, const int maxpoints, float *data, int datalen);
 								

//experiments
struct ImVec2 igGetCursorScreenPosORIG();
struct ImVec2 igGetCursorScreenPosORIG2();

//ImVec2 GetCursorScreenPos();
]]

ffi.cdef[[
//Log
typedef struct Log Log;
Log* Log_new();
void Log_Add(Log* log,const char* fmt, ...);
void Log_Draw(Log* log, const char* title); //, bool* p_open = NULL
void Log_delete(Log* log);	

]]



if jit.os == "Windows" then
ffi.cdef[[
 
// Helpers: UTF-8 <> wchar
int           igImTextStrToUtf8(char* buf, int buf_size, const ImWchar* in_text, const ImWchar* in_text_end);      // return output UTF-8 bytes count 
int           igImTextCharFromUtf8(unsigned int* out_char, const char* in_text, const char* in_text_end);          // return input UTF-8 bytes count 
int           igImTextStrFromUtf8(ImWchar* buf, int buf_size, const char* in_text, const char* in_text_end, const char** in_remaining);   // return input UTF-8 bytes count 
int           igImTextCountCharsFromUtf8(const char* in_text, const char* in_text_end);                            // return number of UTF-8 code-points (NOT bytes count) 
int           igImTextCountUtf8BytesFromStr(const ImWchar* in_text, const ImWchar* in_text_end);                   // return number of bytes to express string as UTF-8 code-points 
 
]]
end

--load dll
local lib = ffi.load[[C:\luaGL\gitsources\build_luajit-imgui_auto2\libcimgui]]

-----------ImVec2 definition
local ImVec2 
ImVec2 = ffi.metatype("ImVec2",{
	__add = function(a,b) return ImVec2(a.x + b.x, a.y + b.y) end,
	__sub = function(a,b) return ImVec2(a.x - b.x, a.y - b.y) end,
	__unm = function(a) return ImVec2(-a.x,-a.y) end,
	__mul = function(a, b) --scalar mult
		if not ffi.istype(ImVec2, b) then
		return ImVec2(a.x * b, a.y * b) end
		return ImVec2(a * b.x, a * b.y)
	end,
	__tostring = function(v) return 'ImVec2<'..v.x..','..v.y..'>' end
})
local ImVec4 = ffi.typeof("struct ImVec4")
--the module
local M = {ImVec2 = ImVec2, ImVec4 = ImVec4 ,lib = lib}
----------ImFontConfig
local ImFontConfig = {}
ImFontConfig.__index = ImFontConfig
ImFontConfig.__new = function(tp)
	local ret = ffi.new(tp)
	lib.ImFontConfig_DefaultConstructor(ret)
	return ret
end
M.ImFontConfig = ffi.metatype("ImFontConfig",ImFontConfig)

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

M.ImplGlfwGL3 = ffi.metatype("ImGui_ImplGlfwGL3",ImGui_ImplGlfwGL3)
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
