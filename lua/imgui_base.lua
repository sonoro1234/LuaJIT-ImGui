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

-- local file = io.open([[c:/luagl/lua/cimgui.txt]],"r")
-- local strfile = file:read"*a"
-- file:close()
-- ffi.cdef(strfile)

-- fonts ---------------------
ffi.cdef[[
typedef struct ImVec2 ImVec2;

struct ImVector
{
	int Size;
	int Capacity;
	void* Data;
};
typedef struct ImVector ImVector;

struct Glyph
{
    ImWchar         Codepoint;          // 0x0000..0xFFFF
    float           AdvanceX;           // Distance to next character (= data from font + ImFontConfig::GlyphExtraSpacing.x baked in)
    float           X0, Y0, X1, Y1;     // Glyph corners
    float           U0, V0, U1, V1;     // Texture coordinates
};
typedef struct Glyph ImFontGlyph;

typedef int ImFontAtlasFlags; 
struct ImFontAtlas 
{
//ImTextureID                 TexID;              // User data to refer to the texture once it has been uploaded to user's graphic systems. It is passed back to you during rendering via the ImDrawCmd structure.
	ImFontAtlasFlags Flags;
	void* TexID;
    int                         TexDesiredWidth;    // Texture width desired by user before Build(). Must be a power-of-two. If have many glyphs your graphics API have texture size restrictions you may want to increase texture width to decrease height.
    int                         TexGlyphPadding;    // Padding between glyphs within texture in pixels. Defaults to 1.

    // [Internal]
    // NB: Access texture data via GetTexData*() calls! Which will setup a default font for you.
    unsigned char*              TexPixelsAlpha8;    // 1 component per pixel, each component is unsigned 8-bit. Total size = TexWidth * TexHeight
    unsigned int*               TexPixelsRGBA32;    // 4 component per pixel, each component is unsigned 8-bit. Total size = TexWidth * TexHeight * 4
    int                         TexWidth;           // Texture width calculated during Build().
    int                         TexHeight;          // Texture height calculated during Build().
	ImVec2						TexUvScale;
	ImVec2                      TexUvWhitePixel;    // Texture coordinates to a white pixel
    ImVector/*<ImFont*> */          Fonts;              // Hold all the fonts returned by AddFont*. Fonts[0] is the default font upon calling ImGui::NewFrame(), use ImGui::PushFont()/PopFont() to change the current font.
	ImVector/*<CustomRect> */       CustomRects;        // Rectangles for packing custom texture data into the atlas.
	ImVector/*<ImFontConfig>*/      ConfigData;         // Internal data
    int                         CustomRectIds[1];   // Identifiers of custom texture rectangle used by ImFontAtlas/ImDrawList
	
};
typedef struct ImFontAtlas ImFontAtlas;

typedef struct ImGuiContext ImGuiContext;
typedef struct ImFontConfig ImFontConfig;

struct ImFont
{
    // Members: Hot ~62/78 bytes
    float                       FontSize;           // <user set>   // Height of characters, set during loading (don't change after loading)
    float                       Scale;              // = 1.f        // Base font scale, multiplied by the per-window font scale which you can adjust with SetFontScale()
    ImVec2                      DisplayOffset;      // = (0.f,1.f)  // Offset font rendering by xx pixels
    ImVector/*<ImFontGlyph>*/       Glyphs;             //              // All glyphs.
    ImVector/*<float>*/             IndexAdvanceX;      //              // Sparse. Glyphs->AdvanceX in a directly indexable way (more cache-friendly, for CalcTextSize functions which are often bottleneck in large UI).
    ImVector/*<unsigned short>*/    IndexLookup;        //              // Sparse. Index glyphs by Unicode code-point.
    const ImFontGlyph*          FallbackGlyph;      // == FindGlyph(FontFallbackChar)
    float                       FallbackAdvanceX;   // == FallbackGlyph->AdvanceX
    ImWchar                     FallbackChar;       // = '?'        // Replacement glyph if one isn't found. Only set via SetFallbackChar()

    // Members: Cold ~18/26 bytes
    short                       ConfigDataCount;    // ~ 1          // Number of ImFontConfig involved in creating this font. Bigger than 1 when merging multiple font sources into one ImFont.
    struct ImFontConfig*               ConfigData;         //              // Pointer within ContainerAtlas->ConfigData
    struct ImFontAtlas*                ContainerAtlas;     //              // What we has been loaded into
    float                       Ascent, Descent;    //              // Ascent: distance from top to bottom of e.g. 'A' [0..FontSize]
    int                         MetricsTotalSurface;//              // Total surface in pixels to get an idea of the font rasterization/texture cost (not exact, we approximate the cost of padding between glyphs)

};
typedef struct ImFont ImFont;

typedef struct ImDrawList ImDrawList;	
]]

-- glfw3 implementation and extras
ffi.cdef[[
float igGET_FLT_MAX();

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

--local lib = ffi.load[[C:\luaGL\gitsources\cimgui\buildcimgui2\libcimgui]]
--local lib = ffi.load[[C:\luaGL\gitsources\build_cimgui3\libcimgui]]
--lib = ffi.load[[C:\luaGL\gitsources\cimgui\builddebug\libcimguiMT]]
local lib = ffi.load[[libcimgui]]

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
sss = ImVec2(3,2)
local ImVec2_p = ffi.typeof("ImVec2[1]")
local ImVec4 = ffi.typeof("struct ImVec4")


-- hand written functions

local M = {ImVec2 = ImVec2, ImVec4 = ImVec4, lib = lib}
function M.Begin(name, p_open, flags)
	 return  lib.igBegin(name, p_open or nil,flags or 0);
end
function M.End()
	 return  lib.igEnd();
end
function M.Button(label, size)
	return lib.igButton(label, size or ImVec2(0, 0))
end

function M.CollapsingHeader(label,flags)
	return lib.igCollapsingHeader(label,flags or 0)
end

function M.GetCursorScreenPos()
	local pos = ImVec2_p()
	lib.igGetCursorScreenPos(pos)
	return pos[0]
end
function M.CalcItemRectClosestPoint(pos, on_edge, outward)
	if on_edge == nil then on_edge = false end
	local ret = ImVec2_p()
	lib.igCalcItemRectClosestPoint(ret, pos, on_edge, outward or 0);
	return ret[0]
end
function M.CalcTextSize(text, text_end, hide_text_after_double_hash, wrap_width)
	if hide_text_after_double_hash == nil then hide_text_after_double_hash = false end
	local ret = ImVec2_p()
	lib.igCalcTextSize(ret, text, text_end, hide_text_after_double_hash, wrap_width or -1)
	return ret[0]
end
function M.GetMouseDragDelta(button , lock_threshold)
	local pos = ImVec2_p()
	lib.igGetMouseDragDelta(pos, button or 0, lock_threshold or -1)
	return pos[0]
end
function M.SameLine(pos_x, spacing_w)
	return lib.igSameLine(pos_x or 0.0, spacing_w or -1.0)
end
function M.SliderInt(label,v, v_min, v_max, display_format)
	return lib.igSliderInt(label,v, v_min, v_max, display_format or "%.0f")
end
function M.PlotLines(label, values, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size, stride)
	lib.igPlotLines(label, values, values_count, values_offset or 0, overlay_text, scale_min or M.FLT_MAX, scale_max or M.FLT_MAX, graph_size or ImVec2(0,0), stride or ffi.sizeof"float")
end
function M.GetContentRegionAvail()
	local avail = ImVec2(0,0)
	lib.igGetContentRegionAvail(avail)
	return avail
end

function M.SetNextWindowPos(pos,cond,pivot)
	return lib.igSetNextWindowPos(pos, cond or 0, pivot or ImVec2(0,0));
end

function M.IsItemHovered(flags)
	return lib.igIsItemHovered(flags or 0)
end
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

----------- ImFontAtlas
local ImFontAtlas = {}
ImFontAtlas.__index = ImFontAtlas

function ImFontAtlas:AddFontDefault(font_cfg)
	return lib.ImFontAtlas_AddFontDefault(self, font_cfg)
end

function ImFontAtlas:AddFontFromFileTTF(filename, size_pixels, font_cfg, glyph_ranges)
	return lib.ImFontAtlas_AddFontFromFileTTF(self, filename, size_pixels, font_cfg, glyph_ranges);
end

function ImFontAtlas:GetTexDataAsRGBA32(out_pixels, out_width, out_height, out_bytes_per_pixel)
	lib.ImFontAtlas_GetTexDataAsRGBA32(self,out_pixels, out_width, out_height, out_bytes_per_pixel);
end

ffi.metatype("ImFontAtlas", ImFontAtlas)
------------ImFont
local ImFont = {}
ImFont.__index = ImFont

function ImFont:FindGlyph(codepoint)
	return lib.ImFont_FindGlyph(self, codepoint)
end

ffi.metatype("ImFont",ImFont)
----------ImFontConfig
local ImFontConfig = {}
ImFontConfig.__index = ImFontConfig
ImFontConfig.__new = function(tp)
	local ret = ffi.new(tp)
	
	--FontData = NULL;
    --FontDataSize = 0;
    ret.FontDataOwnedByAtlas = true;
    --FontNo = 0;
    --SizePixels = 0.0f;
    ret.OversampleH = 3;
    ret.OversampleV = 1;
    ret.PixelSnapH = false;
    ret.GlyphExtraSpacing = ImVec2(0.0, 0.0);
    ret.GlyphOffset = ImVec2(0.0, 0.0);
    --GlyphRanges = NULL;
    ret.MergeMode = false;
    --RasterizerFlags = 0x00;
    ret.RasterizerMultiply = 1.0;
    --memset(Name, 0, sizeof(Name));
    --DstFont = NULL;
	return ret
end
M.ImFontConfig = ffi.metatype("ImFontConfig",ImFontConfig)
-----------ImDrawList
local ImDrawList = {}
ImDrawList.__index = ImDrawList

function ImDrawList:AddLine(a, b, col,thickness)
	lib.ImDrawList_AddLine(self, a, b, col, thickness or 1)
end
function ImDrawList:AddRect(a,b,col,rounding,rounding_corners,thickness)
 return lib.ImDrawList_AddRect(self, a, b, col, rounding or 0, rounding_corners or 0, thickness or 1)
end

function ImDrawList:AddText(pos, col, text_begin, text_end)
	lib.ImDrawList_AddText(self, pos, col, text_begin, text_end)
end

function ImDrawList:AddCircleFilled(centre, radius, col, num_segments)
	lib.ImDrawList_AddCircleFilled(self, centre, radius, col, num_segments or 12)
end

function M.U32(a,b,c,d) return lib.igGetColorU32Vec(ImVec4(a,b,c,d or 1)) end

ffi.metatype("ImDrawList",ImDrawList)

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
---------------------------------
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
--------obsoletes
function M.GetItemsLineHeightWithSpacing() 
	return lib.igGetFrameHeightWithSpacing()
end
function M.PushIdStr(id) 
	return lib.igPushIDStr(id)
end
function M.PopId() 
	return lib.igPopID()
end
function M.ShowTestWindow(a)
	return lib.igShowDemoWindow(a)
end
----------- get ig.. functions without prefix
M = setmetatable(M,{
	__index = function(t,k) 
		local ok, obj = pcall(function(val) return lib[val] end, "ig"..k)
		if not ok then error("Couldn't find function "..k.." (are you accessing the right function?)",2) end
		rawset(M, k, obj)
		return obj
	end
})


return M