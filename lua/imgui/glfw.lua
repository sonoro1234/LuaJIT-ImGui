local cimguimodule = 'cimgui_glfw' --set imgui directory location 
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

function Imgui_Impl_SDL_opengl3:Init(window, gl_context)
    self.window = window
    lib.ImGui_ImplSDL2_InitForOpenGL(window, gl_context);
    lib.ImGui_ImplOpenGL3_Init("#version 150");
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

function Imgui_Impl_glfw_opengl3:Init(window, install_callbacks)
    lib.ImGui_ImplGlfw_InitForOpenGL(window, install_callbacks);
    lib.ImGui_ImplOpenGL3_Init("#version 150");
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

---------------for using nonUDT2 versions
function M.use_nonUDT2()
    for k,v in pairs(M) do
        if M[k.."_nonUDT2"] then
            M[k] = M[k.."_nonUDT2"]
        end
    end
end


----------BEGIN_AUTOGENERATED_LUA---------------------------
--------------------------ImVector_ImDrawVert----------------------------
local ImVector_ImDrawVert= {}
ImVector_ImDrawVert.__index = ImVector_ImDrawVert
function ImVector_ImDrawVert.__new()
    local ptr = lib.ImVector_ImDrawVert_ImVector_ImDrawVert()
    ffi.gc(ptr,lib.ImVector_ImDrawVert_destroy)
    return ptr
end
ImVector_ImDrawVert.ImDrawVert__grow_capacity = lib.ImVector_ImDrawVert__grow_capacity
ImVector_ImDrawVert.ImDrawVert_back = lib.ImVector_ImDrawVert_back
ImVector_ImDrawVert.ImDrawVert_back_const = lib.ImVector_ImDrawVert_back_const
ImVector_ImDrawVert.ImDrawVert_begin = lib.ImVector_ImDrawVert_begin
ImVector_ImDrawVert.ImDrawVert_begin_const = lib.ImVector_ImDrawVert_begin_const
ImVector_ImDrawVert.ImDrawVert_capacity = lib.ImVector_ImDrawVert_capacity
ImVector_ImDrawVert.ImDrawVert_clear = lib.ImVector_ImDrawVert_clear
ImVector_ImDrawVert.ImDrawVert_empty = lib.ImVector_ImDrawVert_empty
ImVector_ImDrawVert.ImDrawVert_end = lib.ImVector_ImDrawVert_end
ImVector_ImDrawVert.ImDrawVert_end_const = lib.ImVector_ImDrawVert_end_const
ImVector_ImDrawVert.ImDrawVert_erase = lib.ImVector_ImDrawVert_erase
ImVector_ImDrawVert.ImDrawVert_eraseTPtr = lib.ImVector_ImDrawVert_eraseTPtr
ImVector_ImDrawVert.ImDrawVert_erase_unsorted = lib.ImVector_ImDrawVert_erase_unsorted
ImVector_ImDrawVert.ImDrawVert_front = lib.ImVector_ImDrawVert_front
ImVector_ImDrawVert.ImDrawVert_front_const = lib.ImVector_ImDrawVert_front_const
ImVector_ImDrawVert.ImDrawVert_index_from_ptr = lib.ImVector_ImDrawVert_index_from_ptr
ImVector_ImDrawVert.ImDrawVert_insert = lib.ImVector_ImDrawVert_insert
ImVector_ImDrawVert.ImDrawVert_pop_back = lib.ImVector_ImDrawVert_pop_back
ImVector_ImDrawVert.ImDrawVert_push_back = lib.ImVector_ImDrawVert_push_back
ImVector_ImDrawVert.ImDrawVert_push_front = lib.ImVector_ImDrawVert_push_front
ImVector_ImDrawVert.ImDrawVert_reserve = lib.ImVector_ImDrawVert_reserve
ImVector_ImDrawVert.ImDrawVert_resize = lib.ImVector_ImDrawVert_resize
ImVector_ImDrawVert.ImDrawVert_resizeT = lib.ImVector_ImDrawVert_resizeT
ImVector_ImDrawVert.ImDrawVert_size = lib.ImVector_ImDrawVert_size
ImVector_ImDrawVert.ImDrawVert_size_in_bytes = lib.ImVector_ImDrawVert_size_in_bytes
ImVector_ImDrawVert.ImDrawVert_swap = lib.ImVector_ImDrawVert_swap
M.ImVector_ImDrawVert = ffi.metatype("ImVector_ImDrawVert",ImVector_ImDrawVert)
--------------------------ImFontConfig----------------------------
local ImFontConfig= {}
ImFontConfig.__index = ImFontConfig
function ImFontConfig.__new()
    local ptr = lib.ImFontConfig_ImFontConfig()
    ffi.gc(ptr,lib.ImFontConfig_destroy)
    return ptr
end
M.ImFontConfig = ffi.metatype("ImFontConfig",ImFontConfig)
--------------------------ImVector_TextRange----------------------------
local ImVector_TextRange= {}
ImVector_TextRange.__index = ImVector_TextRange
function ImVector_TextRange.__new()
    local ptr = lib.ImVector_TextRange_ImVector_TextRange()
    ffi.gc(ptr,lib.ImVector_TextRange_destroy)
    return ptr
end
ImVector_TextRange.TextRange__grow_capacity = lib.ImVector_TextRange__grow_capacity
ImVector_TextRange.TextRange_back = lib.ImVector_TextRange_back
ImVector_TextRange.TextRange_back_const = lib.ImVector_TextRange_back_const
ImVector_TextRange.TextRange_begin = lib.ImVector_TextRange_begin
ImVector_TextRange.TextRange_begin_const = lib.ImVector_TextRange_begin_const
ImVector_TextRange.TextRange_capacity = lib.ImVector_TextRange_capacity
ImVector_TextRange.TextRange_clear = lib.ImVector_TextRange_clear
ImVector_TextRange.TextRange_empty = lib.ImVector_TextRange_empty
ImVector_TextRange.TextRange_end = lib.ImVector_TextRange_end
ImVector_TextRange.TextRange_end_const = lib.ImVector_TextRange_end_const
ImVector_TextRange.TextRange_erase = lib.ImVector_TextRange_erase
ImVector_TextRange.TextRange_eraseTPtr = lib.ImVector_TextRange_eraseTPtr
ImVector_TextRange.TextRange_erase_unsorted = lib.ImVector_TextRange_erase_unsorted
ImVector_TextRange.TextRange_front = lib.ImVector_TextRange_front
ImVector_TextRange.TextRange_front_const = lib.ImVector_TextRange_front_const
ImVector_TextRange.TextRange_index_from_ptr = lib.ImVector_TextRange_index_from_ptr
ImVector_TextRange.TextRange_insert = lib.ImVector_TextRange_insert
ImVector_TextRange.TextRange_pop_back = lib.ImVector_TextRange_pop_back
ImVector_TextRange.TextRange_push_back = lib.ImVector_TextRange_push_back
ImVector_TextRange.TextRange_push_front = lib.ImVector_TextRange_push_front
ImVector_TextRange.TextRange_reserve = lib.ImVector_TextRange_reserve
ImVector_TextRange.TextRange_resize = lib.ImVector_TextRange_resize
ImVector_TextRange.TextRange_resizeT = lib.ImVector_TextRange_resizeT
ImVector_TextRange.TextRange_size = lib.ImVector_TextRange_size
ImVector_TextRange.TextRange_size_in_bytes = lib.ImVector_TextRange_size_in_bytes
ImVector_TextRange.TextRange_swap = lib.ImVector_TextRange_swap
M.ImVector_TextRange = ffi.metatype("ImVector_TextRange",ImVector_TextRange)
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
ImFontGlyphRangesBuilder.GetBit = lib.ImFontGlyphRangesBuilder_GetBit
function ImFontGlyphRangesBuilder.__new()
    local ptr = lib.ImFontGlyphRangesBuilder_ImFontGlyphRangesBuilder()
    ffi.gc(ptr,lib.ImFontGlyphRangesBuilder_destroy)
    return ptr
end
ImFontGlyphRangesBuilder.SetBit = lib.ImFontGlyphRangesBuilder_SetBit
M.ImFontGlyphRangesBuilder = ffi.metatype("ImFontGlyphRangesBuilder",ImFontGlyphRangesBuilder)
--------------------------CustomRect----------------------------
local CustomRect= {}
CustomRect.__index = CustomRect
function CustomRect.__new()
    local ptr = lib.CustomRect_CustomRect()
    ffi.gc(ptr,lib.CustomRect_destroy)
    return ptr
end
CustomRect.IsPacked = lib.CustomRect_IsPacked
M.CustomRect = ffi.metatype("CustomRect",CustomRect)
--------------------------ImVector_ImFontPtr----------------------------
local ImVector_ImFontPtr= {}
ImVector_ImFontPtr.__index = ImVector_ImFontPtr
function ImVector_ImFontPtr.__new()
    local ptr = lib.ImVector_ImFontPtr_ImVector_ImFontPtr()
    ffi.gc(ptr,lib.ImVector_ImFontPtr_destroy)
    return ptr
end
ImVector_ImFontPtr.ImFontPtr__grow_capacity = lib.ImVector_ImFontPtr__grow_capacity
ImVector_ImFontPtr.ImFontPtr_back = lib.ImVector_ImFontPtr_back
ImVector_ImFontPtr.ImFontPtr_back_const = lib.ImVector_ImFontPtr_back_const
ImVector_ImFontPtr.ImFontPtr_begin = lib.ImVector_ImFontPtr_begin
ImVector_ImFontPtr.ImFontPtr_begin_const = lib.ImVector_ImFontPtr_begin_const
ImVector_ImFontPtr.ImFontPtr_capacity = lib.ImVector_ImFontPtr_capacity
ImVector_ImFontPtr.ImFontPtr_clear = lib.ImVector_ImFontPtr_clear
ImVector_ImFontPtr.ImFontPtr_empty = lib.ImVector_ImFontPtr_empty
ImVector_ImFontPtr.ImFontPtr_end = lib.ImVector_ImFontPtr_end
ImVector_ImFontPtr.ImFontPtr_end_const = lib.ImVector_ImFontPtr_end_const
ImVector_ImFontPtr.ImFontPtr_erase = lib.ImVector_ImFontPtr_erase
ImVector_ImFontPtr.ImFontPtr_eraseTPtr = lib.ImVector_ImFontPtr_eraseTPtr
ImVector_ImFontPtr.ImFontPtr_erase_unsorted = lib.ImVector_ImFontPtr_erase_unsorted
ImVector_ImFontPtr.ImFontPtr_front = lib.ImVector_ImFontPtr_front
ImVector_ImFontPtr.ImFontPtr_front_const = lib.ImVector_ImFontPtr_front_const
ImVector_ImFontPtr.ImFontPtr_index_from_ptr = lib.ImVector_ImFontPtr_index_from_ptr
ImVector_ImFontPtr.ImFontPtr_insert = lib.ImVector_ImFontPtr_insert
ImVector_ImFontPtr.ImFontPtr_pop_back = lib.ImVector_ImFontPtr_pop_back
ImVector_ImFontPtr.ImFontPtr_push_back = lib.ImVector_ImFontPtr_push_back
ImVector_ImFontPtr.ImFontPtr_push_front = lib.ImVector_ImFontPtr_push_front
ImVector_ImFontPtr.ImFontPtr_reserve = lib.ImVector_ImFontPtr_reserve
ImVector_ImFontPtr.ImFontPtr_resize = lib.ImVector_ImFontPtr_resize
ImVector_ImFontPtr.ImFontPtr_resizeT = lib.ImVector_ImFontPtr_resizeT
ImVector_ImFontPtr.ImFontPtr_size = lib.ImVector_ImFontPtr_size
ImVector_ImFontPtr.ImFontPtr_size_in_bytes = lib.ImVector_ImFontPtr_size_in_bytes
ImVector_ImFontPtr.ImFontPtr_swap = lib.ImVector_ImFontPtr_swap
M.ImVector_ImFontPtr = ffi.metatype("ImVector_ImFontPtr",ImVector_ImFontPtr)
--------------------------ImGuiTextBuffer----------------------------
local ImGuiTextBuffer= {}
ImGuiTextBuffer.__index = ImGuiTextBuffer
function ImGuiTextBuffer.__new()
    local ptr = lib.ImGuiTextBuffer_ImGuiTextBuffer()
    ffi.gc(ptr,lib.ImGuiTextBuffer_destroy)
    return ptr
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
--------------------------ImGuiStyle----------------------------
local ImGuiStyle= {}
ImGuiStyle.__index = ImGuiStyle
function ImGuiStyle.__new()
    local ptr = lib.ImGuiStyle_ImGuiStyle()
    ffi.gc(ptr,lib.ImGuiStyle_destroy)
    return ptr
end
ImGuiStyle.ScaleAllSizes = lib.ImGuiStyle_ScaleAllSizes
M.ImGuiStyle = ffi.metatype("ImGuiStyle",ImGuiStyle)
--------------------------ImDrawData----------------------------
local ImDrawData= {}
ImDrawData.__index = ImDrawData
ImDrawData.Clear = lib.ImDrawData_Clear
ImDrawData.DeIndexAllBuffers = lib.ImDrawData_DeIndexAllBuffers
function ImDrawData.__new()
    local ptr = lib.ImDrawData_ImDrawData()
    ffi.gc(ptr,lib.ImDrawData_destroy)
    return ptr
end
ImDrawData.ScaleClipRects = lib.ImDrawData_ScaleClipRects
M.ImDrawData = ffi.metatype("ImDrawData",ImDrawData)
--------------------------ImVector_ImVec2----------------------------
local ImVector_ImVec2= {}
ImVector_ImVec2.__index = ImVector_ImVec2
function ImVector_ImVec2.__new()
    local ptr = lib.ImVector_ImVec2_ImVector_ImVec2()
    ffi.gc(ptr,lib.ImVector_ImVec2_destroy)
    return ptr
end
ImVector_ImVec2.ImVec2__grow_capacity = lib.ImVector_ImVec2__grow_capacity
ImVector_ImVec2.ImVec2_back = lib.ImVector_ImVec2_back
ImVector_ImVec2.ImVec2_back_const = lib.ImVector_ImVec2_back_const
ImVector_ImVec2.ImVec2_begin = lib.ImVector_ImVec2_begin
ImVector_ImVec2.ImVec2_begin_const = lib.ImVector_ImVec2_begin_const
ImVector_ImVec2.ImVec2_capacity = lib.ImVector_ImVec2_capacity
ImVector_ImVec2.ImVec2_clear = lib.ImVector_ImVec2_clear
ImVector_ImVec2.ImVec2_empty = lib.ImVector_ImVec2_empty
ImVector_ImVec2.ImVec2_end = lib.ImVector_ImVec2_end
ImVector_ImVec2.ImVec2_end_const = lib.ImVector_ImVec2_end_const
ImVector_ImVec2.ImVec2_erase = lib.ImVector_ImVec2_erase
ImVector_ImVec2.ImVec2_eraseTPtr = lib.ImVector_ImVec2_eraseTPtr
ImVector_ImVec2.ImVec2_erase_unsorted = lib.ImVector_ImVec2_erase_unsorted
ImVector_ImVec2.ImVec2_front = lib.ImVector_ImVec2_front
ImVector_ImVec2.ImVec2_front_const = lib.ImVector_ImVec2_front_const
ImVector_ImVec2.ImVec2_index_from_ptr = lib.ImVector_ImVec2_index_from_ptr
ImVector_ImVec2.ImVec2_insert = lib.ImVector_ImVec2_insert
ImVector_ImVec2.ImVec2_pop_back = lib.ImVector_ImVec2_pop_back
ImVector_ImVec2.ImVec2_push_back = lib.ImVector_ImVec2_push_back
ImVector_ImVec2.ImVec2_push_front = lib.ImVector_ImVec2_push_front
ImVector_ImVec2.ImVec2_reserve = lib.ImVector_ImVec2_reserve
ImVector_ImVec2.ImVec2_resize = lib.ImVector_ImVec2_resize
ImVector_ImVec2.ImVec2_resizeT = lib.ImVector_ImVec2_resizeT
ImVector_ImVec2.ImVec2_size = lib.ImVector_ImVec2_size
ImVector_ImVec2.ImVec2_size_in_bytes = lib.ImVector_ImVec2_size_in_bytes
ImVector_ImVec2.ImVec2_swap = lib.ImVector_ImVec2_swap
M.ImVector_ImVec2 = ffi.metatype("ImVector_ImVec2",ImVector_ImVec2)
--------------------------ImColor----------------------------
local ImColor= {}
ImColor.__index = ImColor
function ImColor:HSV(h,s,v,a)
    a = a or 1.0
    local nonUDT_out = ffi.new("ImColor[1]")
    lib.ImColor_HSV_nonUDT(nonUDT_out,self,h,s,v,a)
    return nonUDT_out[0]
end
function ImColor:HSV_nonUDT2(h,s,v,a)
    a = a or 1.0
    return lib.ImColor_HSV_nonUDT2(self,h,s,v,a)
end
function ImColor.__new()
    local ptr = lib.ImColor_ImColor()
    ffi.gc(ptr,lib.ImColor_destroy)
    return ptr
end
function ImColor:SetHSV(h,s,v,a)
    a = a or 1.0
    return lib.ImColor_SetHSV(self,h,s,v,a)
end
M.ImColor = ffi.metatype("ImColor",ImColor)
--------------------------ImVector_ImDrawChannel----------------------------
local ImVector_ImDrawChannel= {}
ImVector_ImDrawChannel.__index = ImVector_ImDrawChannel
function ImVector_ImDrawChannel.__new()
    local ptr = lib.ImVector_ImDrawChannel_ImVector_ImDrawChannel()
    ffi.gc(ptr,lib.ImVector_ImDrawChannel_destroy)
    return ptr
end
ImVector_ImDrawChannel.ImDrawChannel__grow_capacity = lib.ImVector_ImDrawChannel__grow_capacity
ImVector_ImDrawChannel.ImDrawChannel_back = lib.ImVector_ImDrawChannel_back
ImVector_ImDrawChannel.ImDrawChannel_back_const = lib.ImVector_ImDrawChannel_back_const
ImVector_ImDrawChannel.ImDrawChannel_begin = lib.ImVector_ImDrawChannel_begin
ImVector_ImDrawChannel.ImDrawChannel_begin_const = lib.ImVector_ImDrawChannel_begin_const
ImVector_ImDrawChannel.ImDrawChannel_capacity = lib.ImVector_ImDrawChannel_capacity
ImVector_ImDrawChannel.ImDrawChannel_clear = lib.ImVector_ImDrawChannel_clear
ImVector_ImDrawChannel.ImDrawChannel_empty = lib.ImVector_ImDrawChannel_empty
ImVector_ImDrawChannel.ImDrawChannel_end = lib.ImVector_ImDrawChannel_end
ImVector_ImDrawChannel.ImDrawChannel_end_const = lib.ImVector_ImDrawChannel_end_const
ImVector_ImDrawChannel.ImDrawChannel_erase = lib.ImVector_ImDrawChannel_erase
ImVector_ImDrawChannel.ImDrawChannel_eraseTPtr = lib.ImVector_ImDrawChannel_eraseTPtr
ImVector_ImDrawChannel.ImDrawChannel_erase_unsorted = lib.ImVector_ImDrawChannel_erase_unsorted
ImVector_ImDrawChannel.ImDrawChannel_front = lib.ImVector_ImDrawChannel_front
ImVector_ImDrawChannel.ImDrawChannel_front_const = lib.ImVector_ImDrawChannel_front_const
ImVector_ImDrawChannel.ImDrawChannel_index_from_ptr = lib.ImVector_ImDrawChannel_index_from_ptr
ImVector_ImDrawChannel.ImDrawChannel_insert = lib.ImVector_ImDrawChannel_insert
ImVector_ImDrawChannel.ImDrawChannel_pop_back = lib.ImVector_ImDrawChannel_pop_back
ImVector_ImDrawChannel.ImDrawChannel_push_back = lib.ImVector_ImDrawChannel_push_back
ImVector_ImDrawChannel.ImDrawChannel_push_front = lib.ImVector_ImDrawChannel_push_front
ImVector_ImDrawChannel.ImDrawChannel_reserve = lib.ImVector_ImDrawChannel_reserve
ImVector_ImDrawChannel.ImDrawChannel_resize = lib.ImVector_ImDrawChannel_resize
ImVector_ImDrawChannel.ImDrawChannel_resizeT = lib.ImVector_ImDrawChannel_resizeT
ImVector_ImDrawChannel.ImDrawChannel_size = lib.ImVector_ImDrawChannel_size
ImVector_ImDrawChannel.ImDrawChannel_size_in_bytes = lib.ImVector_ImDrawChannel_size_in_bytes
ImVector_ImDrawChannel.ImDrawChannel_swap = lib.ImVector_ImDrawChannel_swap
M.ImVector_ImDrawChannel = ffi.metatype("ImVector_ImDrawChannel",ImVector_ImDrawChannel)
--------------------------ImVector_int----------------------------
local ImVector_int= {}
ImVector_int.__index = ImVector_int
function ImVector_int.__new()
    local ptr = lib.ImVector_int_ImVector_int()
    ffi.gc(ptr,lib.ImVector_int_destroy)
    return ptr
end
ImVector_int.int__grow_capacity = lib.ImVector_int__grow_capacity
ImVector_int.int_back = lib.ImVector_int_back
ImVector_int.int_back_const = lib.ImVector_int_back_const
ImVector_int.int_begin = lib.ImVector_int_begin
ImVector_int.int_begin_const = lib.ImVector_int_begin_const
ImVector_int.int_capacity = lib.ImVector_int_capacity
ImVector_int.int_clear = lib.ImVector_int_clear
ImVector_int.int_contains = lib.ImVector_int_contains
ImVector_int.int_empty = lib.ImVector_int_empty
ImVector_int.int_end = lib.ImVector_int_end
ImVector_int.int_end_const = lib.ImVector_int_end_const
ImVector_int.int_erase = lib.ImVector_int_erase
ImVector_int.int_eraseTPtr = lib.ImVector_int_eraseTPtr
ImVector_int.int_erase_unsorted = lib.ImVector_int_erase_unsorted
ImVector_int.int_front = lib.ImVector_int_front
ImVector_int.int_front_const = lib.ImVector_int_front_const
ImVector_int.int_index_from_ptr = lib.ImVector_int_index_from_ptr
ImVector_int.int_insert = lib.ImVector_int_insert
ImVector_int.int_pop_back = lib.ImVector_int_pop_back
ImVector_int.int_push_back = lib.ImVector_int_push_back
ImVector_int.int_push_front = lib.ImVector_int_push_front
ImVector_int.int_reserve = lib.ImVector_int_reserve
ImVector_int.int_resize = lib.ImVector_int_resize
ImVector_int.int_resizeT = lib.ImVector_int_resizeT
ImVector_int.int_size = lib.ImVector_int_size
ImVector_int.int_size_in_bytes = lib.ImVector_int_size_in_bytes
ImVector_int.int_swap = lib.ImVector_int_swap
M.ImVector_int = ffi.metatype("ImVector_int",ImVector_int)
--------------------------ImDrawList----------------------------
local ImDrawList= {}
ImDrawList.__index = ImDrawList
function ImDrawList:AddBezierCurve(pos0,cp0,cp1,pos1,col,thickness,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_AddBezierCurve(self,pos0,cp0,cp1,pos1,col,thickness,num_segments)
end
ImDrawList.AddCallback = lib.ImDrawList_AddCallback
function ImDrawList:AddCircle(centre,radius,col,num_segments,thickness)
    num_segments = num_segments or 12
    thickness = thickness or 1.0
    return lib.ImDrawList_AddCircle(self,centre,radius,col,num_segments,thickness)
end
function ImDrawList:AddCircleFilled(centre,radius,col,num_segments)
    num_segments = num_segments or 12
    return lib.ImDrawList_AddCircleFilled(self,centre,radius,col,num_segments)
end
ImDrawList.AddConvexPolyFilled = lib.ImDrawList_AddConvexPolyFilled
ImDrawList.AddDrawCmd = lib.ImDrawList_AddDrawCmd
function ImDrawList:AddImage(user_texture_id,a,b,uv_a,uv_b,col)
    uv_b = uv_b or ImVec2(1,1)
    uv_a = uv_a or ImVec2(0,0)
    col = col or 0xFFFFFFFF
    return lib.ImDrawList_AddImage(self,user_texture_id,a,b,uv_a,uv_b,col)
end
function ImDrawList:AddImageQuad(user_texture_id,a,b,c,d,uv_a,uv_b,uv_c,uv_d,col)
    uv_c = uv_c or ImVec2(1,1)
    uv_a = uv_a or ImVec2(0,0)
    col = col or 0xFFFFFFFF
    uv_b = uv_b or ImVec2(1,0)
    uv_d = uv_d or ImVec2(0,1)
    return lib.ImDrawList_AddImageQuad(self,user_texture_id,a,b,c,d,uv_a,uv_b,uv_c,uv_d,col)
end
function ImDrawList:AddImageRounded(user_texture_id,a,b,uv_a,uv_b,col,rounding,rounding_corners)
    rounding_corners = rounding_corners or lib.ImDrawCornerFlags_All
    return lib.ImDrawList_AddImageRounded(self,user_texture_id,a,b,uv_a,uv_b,col,rounding,rounding_corners)
end
function ImDrawList:AddLine(a,b,col,thickness)
    thickness = thickness or 1.0
    return lib.ImDrawList_AddLine(self,a,b,col,thickness)
end
ImDrawList.AddPolyline = lib.ImDrawList_AddPolyline
function ImDrawList:AddQuad(a,b,c,d,col,thickness)
    thickness = thickness or 1.0
    return lib.ImDrawList_AddQuad(self,a,b,c,d,col,thickness)
end
ImDrawList.AddQuadFilled = lib.ImDrawList_AddQuadFilled
function ImDrawList:AddRect(a,b,col,rounding,rounding_corners_flags,thickness)
    rounding = rounding or 0.0
    thickness = thickness or 1.0
    rounding_corners_flags = rounding_corners_flags or lib.ImDrawCornerFlags_All
    return lib.ImDrawList_AddRect(self,a,b,col,rounding,rounding_corners_flags,thickness)
end
function ImDrawList:AddRectFilled(a,b,col,rounding,rounding_corners_flags)
    rounding = rounding or 0.0
    rounding_corners_flags = rounding_corners_flags or lib.ImDrawCornerFlags_All
    return lib.ImDrawList_AddRectFilled(self,a,b,col,rounding,rounding_corners_flags)
end
ImDrawList.AddRectFilledMultiColor = lib.ImDrawList_AddRectFilledMultiColor
function ImDrawList:AddText(pos,col,text_begin,text_end)
    text_end = text_end or nil
    return lib.ImDrawList_AddText(self,pos,col,text_begin,text_end)
end
function ImDrawList:AddTextFontPtr(font,font_size,pos,col,text_begin,text_end,wrap_width,cpu_fine_clip_rect)
    text_end = text_end or nil
    cpu_fine_clip_rect = cpu_fine_clip_rect or nil
    wrap_width = wrap_width or 0.0
    return lib.ImDrawList_AddTextFontPtr(self,font,font_size,pos,col,text_begin,text_end,wrap_width,cpu_fine_clip_rect)
end
function ImDrawList:AddTriangle(a,b,c,col,thickness)
    thickness = thickness or 1.0
    return lib.ImDrawList_AddTriangle(self,a,b,c,col,thickness)
end
ImDrawList.AddTriangleFilled = lib.ImDrawList_AddTriangleFilled
ImDrawList.ChannelsMerge = lib.ImDrawList_ChannelsMerge
ImDrawList.ChannelsSetCurrent = lib.ImDrawList_ChannelsSetCurrent
ImDrawList.ChannelsSplit = lib.ImDrawList_ChannelsSplit
ImDrawList.Clear = lib.ImDrawList_Clear
ImDrawList.ClearFreeMemory = lib.ImDrawList_ClearFreeMemory
ImDrawList.CloneOutput = lib.ImDrawList_CloneOutput
function ImDrawList:GetClipRectMax()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.ImDrawList_GetClipRectMax_nonUDT(nonUDT_out,self)
    return nonUDT_out[0]
end
ImDrawList.GetClipRectMax_nonUDT2 = lib.ImDrawList_GetClipRectMax_nonUDT2
function ImDrawList:GetClipRectMin()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.ImDrawList_GetClipRectMin_nonUDT(nonUDT_out,self)
    return nonUDT_out[0]
end
ImDrawList.GetClipRectMin_nonUDT2 = lib.ImDrawList_GetClipRectMin_nonUDT2
function ImDrawList:PathArcTo(centre,radius,a_min,a_max,num_segments)
    num_segments = num_segments or 10
    return lib.ImDrawList_PathArcTo(self,centre,radius,a_min,a_max,num_segments)
end
ImDrawList.PathArcToFast = lib.ImDrawList_PathArcToFast
function ImDrawList:PathBezierCurveTo(p1,p2,p3,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_PathBezierCurveTo(self,p1,p2,p3,num_segments)
end
ImDrawList.PathClear = lib.ImDrawList_PathClear
ImDrawList.PathFillConvex = lib.ImDrawList_PathFillConvex
ImDrawList.PathLineTo = lib.ImDrawList_PathLineTo
ImDrawList.PathLineToMergeDuplicate = lib.ImDrawList_PathLineToMergeDuplicate
function ImDrawList:PathRect(rect_min,rect_max,rounding,rounding_corners_flags)
    rounding = rounding or 0.0
    rounding_corners_flags = rounding_corners_flags or lib.ImDrawCornerFlags_All
    return lib.ImDrawList_PathRect(self,rect_min,rect_max,rounding,rounding_corners_flags)
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
ImDrawList.PrimVtx = lib.ImDrawList_PrimVtx
ImDrawList.PrimWriteIdx = lib.ImDrawList_PrimWriteIdx
ImDrawList.PrimWriteVtx = lib.ImDrawList_PrimWriteVtx
function ImDrawList:PushClipRect(clip_rect_min,clip_rect_max,intersect_with_current_clip_rect)
    intersect_with_current_clip_rect = intersect_with_current_clip_rect or false
    return lib.ImDrawList_PushClipRect(self,clip_rect_min,clip_rect_max,intersect_with_current_clip_rect)
end
ImDrawList.PushClipRectFullScreen = lib.ImDrawList_PushClipRectFullScreen
ImDrawList.PushTextureID = lib.ImDrawList_PushTextureID
ImDrawList.UpdateClipRect = lib.ImDrawList_UpdateClipRect
ImDrawList.UpdateTextureID = lib.ImDrawList_UpdateTextureID
M.ImDrawList = ffi.metatype("ImDrawList",ImDrawList)
--------------------------ImVector_ImFontGlyph----------------------------
local ImVector_ImFontGlyph= {}
ImVector_ImFontGlyph.__index = ImVector_ImFontGlyph
function ImVector_ImFontGlyph.__new()
    local ptr = lib.ImVector_ImFontGlyph_ImVector_ImFontGlyph()
    ffi.gc(ptr,lib.ImVector_ImFontGlyph_destroy)
    return ptr
end
ImVector_ImFontGlyph.ImFontGlyph__grow_capacity = lib.ImVector_ImFontGlyph__grow_capacity
ImVector_ImFontGlyph.ImFontGlyph_back = lib.ImVector_ImFontGlyph_back
ImVector_ImFontGlyph.ImFontGlyph_back_const = lib.ImVector_ImFontGlyph_back_const
ImVector_ImFontGlyph.ImFontGlyph_begin = lib.ImVector_ImFontGlyph_begin
ImVector_ImFontGlyph.ImFontGlyph_begin_const = lib.ImVector_ImFontGlyph_begin_const
ImVector_ImFontGlyph.ImFontGlyph_capacity = lib.ImVector_ImFontGlyph_capacity
ImVector_ImFontGlyph.ImFontGlyph_clear = lib.ImVector_ImFontGlyph_clear
ImVector_ImFontGlyph.ImFontGlyph_empty = lib.ImVector_ImFontGlyph_empty
ImVector_ImFontGlyph.ImFontGlyph_end = lib.ImVector_ImFontGlyph_end
ImVector_ImFontGlyph.ImFontGlyph_end_const = lib.ImVector_ImFontGlyph_end_const
ImVector_ImFontGlyph.ImFontGlyph_erase = lib.ImVector_ImFontGlyph_erase
ImVector_ImFontGlyph.ImFontGlyph_eraseTPtr = lib.ImVector_ImFontGlyph_eraseTPtr
ImVector_ImFontGlyph.ImFontGlyph_erase_unsorted = lib.ImVector_ImFontGlyph_erase_unsorted
ImVector_ImFontGlyph.ImFontGlyph_front = lib.ImVector_ImFontGlyph_front
ImVector_ImFontGlyph.ImFontGlyph_front_const = lib.ImVector_ImFontGlyph_front_const
ImVector_ImFontGlyph.ImFontGlyph_index_from_ptr = lib.ImVector_ImFontGlyph_index_from_ptr
ImVector_ImFontGlyph.ImFontGlyph_insert = lib.ImVector_ImFontGlyph_insert
ImVector_ImFontGlyph.ImFontGlyph_pop_back = lib.ImVector_ImFontGlyph_pop_back
ImVector_ImFontGlyph.ImFontGlyph_push_back = lib.ImVector_ImFontGlyph_push_back
ImVector_ImFontGlyph.ImFontGlyph_push_front = lib.ImVector_ImFontGlyph_push_front
ImVector_ImFontGlyph.ImFontGlyph_reserve = lib.ImVector_ImFontGlyph_reserve
ImVector_ImFontGlyph.ImFontGlyph_resize = lib.ImVector_ImFontGlyph_resize
ImVector_ImFontGlyph.ImFontGlyph_resizeT = lib.ImVector_ImFontGlyph_resizeT
ImVector_ImFontGlyph.ImFontGlyph_size = lib.ImVector_ImFontGlyph_size
ImVector_ImFontGlyph.ImFontGlyph_size_in_bytes = lib.ImVector_ImFontGlyph_size_in_bytes
ImVector_ImFontGlyph.ImFontGlyph_swap = lib.ImVector_ImFontGlyph_swap
M.ImVector_ImFontGlyph = ffi.metatype("ImVector_ImFontGlyph",ImVector_ImFontGlyph)
--------------------------TextRange----------------------------
local TextRange= {}
TextRange.__index = TextRange
function TextRange.__new()
    local ptr = lib.TextRange_TextRange()
    ffi.gc(ptr,lib.TextRange_destroy)
    return ptr
end
TextRange.begin = lib.TextRange_begin
TextRange.empty = lib.TextRange_empty
TextRange._end = lib.TextRange_end
TextRange.split = lib.TextRange_split
M.TextRange = ffi.metatype("TextRange",TextRange)
--------------------------ImGuiListClipper----------------------------
local ImGuiListClipper= {}
ImGuiListClipper.__index = ImGuiListClipper
function ImGuiListClipper:Begin(items_count,items_height)
    items_height = items_height or -1.0
    return lib.ImGuiListClipper_Begin(self,items_count,items_height)
end
ImGuiListClipper.End = lib.ImGuiListClipper_End
ImGuiListClipper.Step = lib.ImGuiListClipper_Step
M.ImGuiListClipper = ffi.metatype("ImGuiListClipper",ImGuiListClipper)
--------------------------ImVector_Pair----------------------------
local ImVector_Pair= {}
ImVector_Pair.__index = ImVector_Pair
function ImVector_Pair.__new()
    local ptr = lib.ImVector_Pair_ImVector_Pair()
    ffi.gc(ptr,lib.ImVector_Pair_destroy)
    return ptr
end
ImVector_Pair.Pair__grow_capacity = lib.ImVector_Pair__grow_capacity
ImVector_Pair.Pair_back = lib.ImVector_Pair_back
ImVector_Pair.Pair_back_const = lib.ImVector_Pair_back_const
ImVector_Pair.Pair_begin = lib.ImVector_Pair_begin
ImVector_Pair.Pair_begin_const = lib.ImVector_Pair_begin_const
ImVector_Pair.Pair_capacity = lib.ImVector_Pair_capacity
ImVector_Pair.Pair_clear = lib.ImVector_Pair_clear
ImVector_Pair.Pair_empty = lib.ImVector_Pair_empty
ImVector_Pair.Pair_end = lib.ImVector_Pair_end
ImVector_Pair.Pair_end_const = lib.ImVector_Pair_end_const
ImVector_Pair.Pair_erase = lib.ImVector_Pair_erase
ImVector_Pair.Pair_eraseTPtr = lib.ImVector_Pair_eraseTPtr
ImVector_Pair.Pair_erase_unsorted = lib.ImVector_Pair_erase_unsorted
ImVector_Pair.Pair_front = lib.ImVector_Pair_front
ImVector_Pair.Pair_front_const = lib.ImVector_Pair_front_const
ImVector_Pair.Pair_index_from_ptr = lib.ImVector_Pair_index_from_ptr
ImVector_Pair.Pair_insert = lib.ImVector_Pair_insert
ImVector_Pair.Pair_pop_back = lib.ImVector_Pair_pop_back
ImVector_Pair.Pair_push_back = lib.ImVector_Pair_push_back
ImVector_Pair.Pair_push_front = lib.ImVector_Pair_push_front
ImVector_Pair.Pair_reserve = lib.ImVector_Pair_reserve
ImVector_Pair.Pair_resize = lib.ImVector_Pair_resize
ImVector_Pair.Pair_resizeT = lib.ImVector_Pair_resizeT
ImVector_Pair.Pair_size = lib.ImVector_Pair_size
ImVector_Pair.Pair_size_in_bytes = lib.ImVector_Pair_size_in_bytes
ImVector_Pair.Pair_swap = lib.ImVector_Pair_swap
M.ImVector_Pair = ffi.metatype("ImVector_Pair",ImVector_Pair)
--------------------------ImVector_ImTextureID----------------------------
local ImVector_ImTextureID= {}
ImVector_ImTextureID.__index = ImVector_ImTextureID
function ImVector_ImTextureID.__new()
    local ptr = lib.ImVector_ImTextureID_ImVector_ImTextureID()
    ffi.gc(ptr,lib.ImVector_ImTextureID_destroy)
    return ptr
end
ImVector_ImTextureID.ImTextureID__grow_capacity = lib.ImVector_ImTextureID__grow_capacity
ImVector_ImTextureID.ImTextureID_back = lib.ImVector_ImTextureID_back
ImVector_ImTextureID.ImTextureID_back_const = lib.ImVector_ImTextureID_back_const
ImVector_ImTextureID.ImTextureID_begin = lib.ImVector_ImTextureID_begin
ImVector_ImTextureID.ImTextureID_begin_const = lib.ImVector_ImTextureID_begin_const
ImVector_ImTextureID.ImTextureID_capacity = lib.ImVector_ImTextureID_capacity
ImVector_ImTextureID.ImTextureID_clear = lib.ImVector_ImTextureID_clear
ImVector_ImTextureID.ImTextureID_empty = lib.ImVector_ImTextureID_empty
ImVector_ImTextureID.ImTextureID_end = lib.ImVector_ImTextureID_end
ImVector_ImTextureID.ImTextureID_end_const = lib.ImVector_ImTextureID_end_const
ImVector_ImTextureID.ImTextureID_erase = lib.ImVector_ImTextureID_erase
ImVector_ImTextureID.ImTextureID_eraseTPtr = lib.ImVector_ImTextureID_eraseTPtr
ImVector_ImTextureID.ImTextureID_erase_unsorted = lib.ImVector_ImTextureID_erase_unsorted
ImVector_ImTextureID.ImTextureID_front = lib.ImVector_ImTextureID_front
ImVector_ImTextureID.ImTextureID_front_const = lib.ImVector_ImTextureID_front_const
ImVector_ImTextureID.ImTextureID_index_from_ptr = lib.ImVector_ImTextureID_index_from_ptr
ImVector_ImTextureID.ImTextureID_insert = lib.ImVector_ImTextureID_insert
ImVector_ImTextureID.ImTextureID_pop_back = lib.ImVector_ImTextureID_pop_back
ImVector_ImTextureID.ImTextureID_push_back = lib.ImVector_ImTextureID_push_back
ImVector_ImTextureID.ImTextureID_push_front = lib.ImVector_ImTextureID_push_front
ImVector_ImTextureID.ImTextureID_reserve = lib.ImVector_ImTextureID_reserve
ImVector_ImTextureID.ImTextureID_resize = lib.ImVector_ImTextureID_resize
ImVector_ImTextureID.ImTextureID_resizeT = lib.ImVector_ImTextureID_resizeT
ImVector_ImTextureID.ImTextureID_size = lib.ImVector_ImTextureID_size
ImVector_ImTextureID.ImTextureID_size_in_bytes = lib.ImVector_ImTextureID_size_in_bytes
ImVector_ImTextureID.ImTextureID_swap = lib.ImVector_ImTextureID_swap
M.ImVector_ImTextureID = ffi.metatype("ImVector_ImTextureID",ImVector_ImTextureID)
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
--------------------------Pair----------------------------
local Pair= {}
Pair.__index = Pair
M.Pair = ffi.metatype("Pair",Pair)
--------------------------ImVector_ImWchar----------------------------
local ImVector_ImWchar= {}
ImVector_ImWchar.__index = ImVector_ImWchar
function ImVector_ImWchar.__new()
    local ptr = lib.ImVector_ImWchar_ImVector_ImWchar()
    ffi.gc(ptr,lib.ImVector_ImWchar_destroy)
    return ptr
end
ImVector_ImWchar.ImWchar__grow_capacity = lib.ImVector_ImWchar__grow_capacity
ImVector_ImWchar.ImWchar_back = lib.ImVector_ImWchar_back
ImVector_ImWchar.ImWchar_back_const = lib.ImVector_ImWchar_back_const
ImVector_ImWchar.ImWchar_begin = lib.ImVector_ImWchar_begin
ImVector_ImWchar.ImWchar_begin_const = lib.ImVector_ImWchar_begin_const
ImVector_ImWchar.ImWchar_capacity = lib.ImVector_ImWchar_capacity
ImVector_ImWchar.ImWchar_clear = lib.ImVector_ImWchar_clear
ImVector_ImWchar.ImWchar_contains = lib.ImVector_ImWchar_contains
ImVector_ImWchar.ImWchar_empty = lib.ImVector_ImWchar_empty
ImVector_ImWchar.ImWchar_end = lib.ImVector_ImWchar_end
ImVector_ImWchar.ImWchar_end_const = lib.ImVector_ImWchar_end_const
ImVector_ImWchar.ImWchar_erase = lib.ImVector_ImWchar_erase
ImVector_ImWchar.ImWchar_eraseTPtr = lib.ImVector_ImWchar_eraseTPtr
ImVector_ImWchar.ImWchar_erase_unsorted = lib.ImVector_ImWchar_erase_unsorted
ImVector_ImWchar.ImWchar_front = lib.ImVector_ImWchar_front
ImVector_ImWchar.ImWchar_front_const = lib.ImVector_ImWchar_front_const
ImVector_ImWchar.ImWchar_index_from_ptr = lib.ImVector_ImWchar_index_from_ptr
ImVector_ImWchar.ImWchar_insert = lib.ImVector_ImWchar_insert
ImVector_ImWchar.ImWchar_pop_back = lib.ImVector_ImWchar_pop_back
ImVector_ImWchar.ImWchar_push_back = lib.ImVector_ImWchar_push_back
ImVector_ImWchar.ImWchar_push_front = lib.ImVector_ImWchar_push_front
ImVector_ImWchar.ImWchar_reserve = lib.ImVector_ImWchar_reserve
ImVector_ImWchar.ImWchar_resize = lib.ImVector_ImWchar_resize
ImVector_ImWchar.ImWchar_resizeT = lib.ImVector_ImWchar_resizeT
ImVector_ImWchar.ImWchar_size = lib.ImVector_ImWchar_size
ImVector_ImWchar.ImWchar_size_in_bytes = lib.ImVector_ImWchar_size_in_bytes
ImVector_ImWchar.ImWchar_swap = lib.ImVector_ImWchar_swap
M.ImVector_ImWchar = ffi.metatype("ImVector_ImWchar",ImVector_ImWchar)
--------------------------ImVector_char----------------------------
local ImVector_char= {}
ImVector_char.__index = ImVector_char
function ImVector_char.__new()
    local ptr = lib.ImVector_char_ImVector_char()
    ffi.gc(ptr,lib.ImVector_char_destroy)
    return ptr
end
ImVector_char.char__grow_capacity = lib.ImVector_char__grow_capacity
ImVector_char.char_back = lib.ImVector_char_back
ImVector_char.char_back_const = lib.ImVector_char_back_const
ImVector_char.char_begin = lib.ImVector_char_begin
ImVector_char.char_begin_const = lib.ImVector_char_begin_const
ImVector_char.char_capacity = lib.ImVector_char_capacity
ImVector_char.char_clear = lib.ImVector_char_clear
ImVector_char.char_contains = lib.ImVector_char_contains
ImVector_char.char_empty = lib.ImVector_char_empty
ImVector_char.char_end = lib.ImVector_char_end
ImVector_char.char_end_const = lib.ImVector_char_end_const
ImVector_char.char_erase = lib.ImVector_char_erase
ImVector_char.char_eraseTPtr = lib.ImVector_char_eraseTPtr
ImVector_char.char_erase_unsorted = lib.ImVector_char_erase_unsorted
ImVector_char.char_front = lib.ImVector_char_front
ImVector_char.char_front_const = lib.ImVector_char_front_const
ImVector_char.char_index_from_ptr = lib.ImVector_char_index_from_ptr
ImVector_char.char_insert = lib.ImVector_char_insert
ImVector_char.char_pop_back = lib.ImVector_char_pop_back
ImVector_char.char_push_back = lib.ImVector_char_push_back
ImVector_char.char_push_front = lib.ImVector_char_push_front
ImVector_char.char_reserve = lib.ImVector_char_reserve
ImVector_char.char_resize = lib.ImVector_char_resize
ImVector_char.char_resizeT = lib.ImVector_char_resizeT
ImVector_char.char_size = lib.ImVector_char_size
ImVector_char.char_size_in_bytes = lib.ImVector_char_size_in_bytes
ImVector_char.char_swap = lib.ImVector_char_swap
M.ImVector_char = ffi.metatype("ImVector_char",ImVector_char)
--------------------------ImGuiIO----------------------------
local ImGuiIO= {}
ImGuiIO.__index = ImGuiIO
ImGuiIO.AddInputCharacter = lib.ImGuiIO_AddInputCharacter
ImGuiIO.AddInputCharactersUTF8 = lib.ImGuiIO_AddInputCharactersUTF8
ImGuiIO.ClearInputCharacters = lib.ImGuiIO_ClearInputCharacters
function ImGuiIO.__new()
    local ptr = lib.ImGuiIO_ImGuiIO()
    ffi.gc(ptr,lib.ImGuiIO_destroy)
    return ptr
end
M.ImGuiIO = ffi.metatype("ImGuiIO",ImGuiIO)
--------------------------ImFont----------------------------
local ImFont= {}
ImFont.__index = ImFont
ImFont.AddGlyph = lib.ImFont_AddGlyph
function ImFont:AddRemapChar(dst,src,overwrite_dst)
    overwrite_dst = overwrite_dst or true
    return lib.ImFont_AddRemapChar(self,dst,src,overwrite_dst)
end
ImFont.BuildLookupTable = lib.ImFont_BuildLookupTable
function ImFont:CalcTextSizeA(size,max_width,wrap_width,text_begin,text_end,remaining)
    text_end = text_end or nil
    remaining = remaining or nil
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.ImFont_CalcTextSizeA_nonUDT(nonUDT_out,self,size,max_width,wrap_width,text_begin,text_end,remaining)
    return nonUDT_out[0]
end
function ImFont:CalcTextSizeA_nonUDT2(size,max_width,wrap_width,text_begin,text_end,remaining)
    text_end = text_end or nil
    remaining = remaining or nil
    return lib.ImFont_CalcTextSizeA_nonUDT2(self,size,max_width,wrap_width,text_begin,text_end,remaining)
end
ImFont.CalcWordWrapPositionA = lib.ImFont_CalcWordWrapPositionA
ImFont.ClearOutputData = lib.ImFont_ClearOutputData
ImFont.FindGlyph = lib.ImFont_FindGlyph
ImFont.FindGlyphNoFallback = lib.ImFont_FindGlyphNoFallback
ImFont.GetCharAdvance = lib.ImFont_GetCharAdvance
ImFont.GetDebugName = lib.ImFont_GetDebugName
ImFont.GrowIndex = lib.ImFont_GrowIndex
function ImFont.__new()
    local ptr = lib.ImFont_ImFont()
    ffi.gc(ptr,lib.ImFont_destroy)
    return ptr
end
ImFont.IsLoaded = lib.ImFont_IsLoaded
ImFont.RenderChar = lib.ImFont_RenderChar
function ImFont:RenderText(draw_list,size,pos,col,clip_rect,text_begin,text_end,wrap_width,cpu_fine_clip)
    wrap_width = wrap_width or 0.0
    cpu_fine_clip = cpu_fine_clip or false
    return lib.ImFont_RenderText(self,draw_list,size,pos,col,clip_rect,text_begin,text_end,wrap_width,cpu_fine_clip)
end
ImFont.SetFallbackChar = lib.ImFont_SetFallbackChar
M.ImFont = ffi.metatype("ImFont",ImFont)
--------------------------ImVector_ImFontConfig----------------------------
local ImVector_ImFontConfig= {}
ImVector_ImFontConfig.__index = ImVector_ImFontConfig
function ImVector_ImFontConfig.__new()
    local ptr = lib.ImVector_ImFontConfig_ImVector_ImFontConfig()
    ffi.gc(ptr,lib.ImVector_ImFontConfig_destroy)
    return ptr
end
ImVector_ImFontConfig.ImFontConfig__grow_capacity = lib.ImVector_ImFontConfig__grow_capacity
ImVector_ImFontConfig.ImFontConfig_back = lib.ImVector_ImFontConfig_back
ImVector_ImFontConfig.ImFontConfig_back_const = lib.ImVector_ImFontConfig_back_const
ImVector_ImFontConfig.ImFontConfig_begin = lib.ImVector_ImFontConfig_begin
ImVector_ImFontConfig.ImFontConfig_begin_const = lib.ImVector_ImFontConfig_begin_const
ImVector_ImFontConfig.ImFontConfig_capacity = lib.ImVector_ImFontConfig_capacity
ImVector_ImFontConfig.ImFontConfig_clear = lib.ImVector_ImFontConfig_clear
ImVector_ImFontConfig.ImFontConfig_empty = lib.ImVector_ImFontConfig_empty
ImVector_ImFontConfig.ImFontConfig_end = lib.ImVector_ImFontConfig_end
ImVector_ImFontConfig.ImFontConfig_end_const = lib.ImVector_ImFontConfig_end_const
ImVector_ImFontConfig.ImFontConfig_erase = lib.ImVector_ImFontConfig_erase
ImVector_ImFontConfig.ImFontConfig_eraseTPtr = lib.ImVector_ImFontConfig_eraseTPtr
ImVector_ImFontConfig.ImFontConfig_erase_unsorted = lib.ImVector_ImFontConfig_erase_unsorted
ImVector_ImFontConfig.ImFontConfig_front = lib.ImVector_ImFontConfig_front
ImVector_ImFontConfig.ImFontConfig_front_const = lib.ImVector_ImFontConfig_front_const
ImVector_ImFontConfig.ImFontConfig_index_from_ptr = lib.ImVector_ImFontConfig_index_from_ptr
ImVector_ImFontConfig.ImFontConfig_insert = lib.ImVector_ImFontConfig_insert
ImVector_ImFontConfig.ImFontConfig_pop_back = lib.ImVector_ImFontConfig_pop_back
ImVector_ImFontConfig.ImFontConfig_push_back = lib.ImVector_ImFontConfig_push_back
ImVector_ImFontConfig.ImFontConfig_push_front = lib.ImVector_ImFontConfig_push_front
ImVector_ImFontConfig.ImFontConfig_reserve = lib.ImVector_ImFontConfig_reserve
ImVector_ImFontConfig.ImFontConfig_resize = lib.ImVector_ImFontConfig_resize
ImVector_ImFontConfig.ImFontConfig_resizeT = lib.ImVector_ImFontConfig_resizeT
ImVector_ImFontConfig.ImFontConfig_size = lib.ImVector_ImFontConfig_size
ImVector_ImFontConfig.ImFontConfig_size_in_bytes = lib.ImVector_ImFontConfig_size_in_bytes
ImVector_ImFontConfig.ImFontConfig_swap = lib.ImVector_ImFontConfig_swap
M.ImVector_ImFontConfig = ffi.metatype("ImVector_ImFontConfig",ImVector_ImFontConfig)
--------------------------ImVector_ImVec4----------------------------
local ImVector_ImVec4= {}
ImVector_ImVec4.__index = ImVector_ImVec4
function ImVector_ImVec4.__new()
    local ptr = lib.ImVector_ImVec4_ImVector_ImVec4()
    ffi.gc(ptr,lib.ImVector_ImVec4_destroy)
    return ptr
end
ImVector_ImVec4.ImVec4__grow_capacity = lib.ImVector_ImVec4__grow_capacity
ImVector_ImVec4.ImVec4_back = lib.ImVector_ImVec4_back
ImVector_ImVec4.ImVec4_back_const = lib.ImVector_ImVec4_back_const
ImVector_ImVec4.ImVec4_begin = lib.ImVector_ImVec4_begin
ImVector_ImVec4.ImVec4_begin_const = lib.ImVector_ImVec4_begin_const
ImVector_ImVec4.ImVec4_capacity = lib.ImVector_ImVec4_capacity
ImVector_ImVec4.ImVec4_clear = lib.ImVector_ImVec4_clear
ImVector_ImVec4.ImVec4_empty = lib.ImVector_ImVec4_empty
ImVector_ImVec4.ImVec4_end = lib.ImVector_ImVec4_end
ImVector_ImVec4.ImVec4_end_const = lib.ImVector_ImVec4_end_const
ImVector_ImVec4.ImVec4_erase = lib.ImVector_ImVec4_erase
ImVector_ImVec4.ImVec4_eraseTPtr = lib.ImVector_ImVec4_eraseTPtr
ImVector_ImVec4.ImVec4_erase_unsorted = lib.ImVector_ImVec4_erase_unsorted
ImVector_ImVec4.ImVec4_front = lib.ImVector_ImVec4_front
ImVector_ImVec4.ImVec4_front_const = lib.ImVector_ImVec4_front_const
ImVector_ImVec4.ImVec4_index_from_ptr = lib.ImVector_ImVec4_index_from_ptr
ImVector_ImVec4.ImVec4_insert = lib.ImVector_ImVec4_insert
ImVector_ImVec4.ImVec4_pop_back = lib.ImVector_ImVec4_pop_back
ImVector_ImVec4.ImVec4_push_back = lib.ImVector_ImVec4_push_back
ImVector_ImVec4.ImVec4_push_front = lib.ImVector_ImVec4_push_front
ImVector_ImVec4.ImVec4_reserve = lib.ImVector_ImVec4_reserve
ImVector_ImVec4.ImVec4_resize = lib.ImVector_ImVec4_resize
ImVector_ImVec4.ImVec4_resizeT = lib.ImVector_ImVec4_resizeT
ImVector_ImVec4.ImVec4_size = lib.ImVector_ImVec4_size
ImVector_ImVec4.ImVec4_size_in_bytes = lib.ImVector_ImVec4_size_in_bytes
ImVector_ImVec4.ImVec4_swap = lib.ImVector_ImVec4_swap
M.ImVector_ImVec4 = ffi.metatype("ImVector_ImVec4",ImVector_ImVec4)
--------------------------ImGuiOnceUponAFrame----------------------------
local ImGuiOnceUponAFrame= {}
ImGuiOnceUponAFrame.__index = ImGuiOnceUponAFrame
function ImGuiOnceUponAFrame.__new()
    local ptr = lib.ImGuiOnceUponAFrame_ImGuiOnceUponAFrame()
    ffi.gc(ptr,lib.ImGuiOnceUponAFrame_destroy)
    return ptr
end
M.ImGuiOnceUponAFrame = ffi.metatype("ImGuiOnceUponAFrame",ImGuiOnceUponAFrame)
--------------------------ImVector_ImDrawCmd----------------------------
local ImVector_ImDrawCmd= {}
ImVector_ImDrawCmd.__index = ImVector_ImDrawCmd
function ImVector_ImDrawCmd.__new()
    local ptr = lib.ImVector_ImDrawCmd_ImVector_ImDrawCmd()
    ffi.gc(ptr,lib.ImVector_ImDrawCmd_destroy)
    return ptr
end
ImVector_ImDrawCmd.ImDrawCmd__grow_capacity = lib.ImVector_ImDrawCmd__grow_capacity
ImVector_ImDrawCmd.ImDrawCmd_back = lib.ImVector_ImDrawCmd_back
ImVector_ImDrawCmd.ImDrawCmd_back_const = lib.ImVector_ImDrawCmd_back_const
ImVector_ImDrawCmd.ImDrawCmd_begin = lib.ImVector_ImDrawCmd_begin
ImVector_ImDrawCmd.ImDrawCmd_begin_const = lib.ImVector_ImDrawCmd_begin_const
ImVector_ImDrawCmd.ImDrawCmd_capacity = lib.ImVector_ImDrawCmd_capacity
ImVector_ImDrawCmd.ImDrawCmd_clear = lib.ImVector_ImDrawCmd_clear
ImVector_ImDrawCmd.ImDrawCmd_empty = lib.ImVector_ImDrawCmd_empty
ImVector_ImDrawCmd.ImDrawCmd_end = lib.ImVector_ImDrawCmd_end
ImVector_ImDrawCmd.ImDrawCmd_end_const = lib.ImVector_ImDrawCmd_end_const
ImVector_ImDrawCmd.ImDrawCmd_erase = lib.ImVector_ImDrawCmd_erase
ImVector_ImDrawCmd.ImDrawCmd_eraseTPtr = lib.ImVector_ImDrawCmd_eraseTPtr
ImVector_ImDrawCmd.ImDrawCmd_erase_unsorted = lib.ImVector_ImDrawCmd_erase_unsorted
ImVector_ImDrawCmd.ImDrawCmd_front = lib.ImVector_ImDrawCmd_front
ImVector_ImDrawCmd.ImDrawCmd_front_const = lib.ImVector_ImDrawCmd_front_const
ImVector_ImDrawCmd.ImDrawCmd_index_from_ptr = lib.ImVector_ImDrawCmd_index_from_ptr
ImVector_ImDrawCmd.ImDrawCmd_insert = lib.ImVector_ImDrawCmd_insert
ImVector_ImDrawCmd.ImDrawCmd_pop_back = lib.ImVector_ImDrawCmd_pop_back
ImVector_ImDrawCmd.ImDrawCmd_push_back = lib.ImVector_ImDrawCmd_push_back
ImVector_ImDrawCmd.ImDrawCmd_push_front = lib.ImVector_ImDrawCmd_push_front
ImVector_ImDrawCmd.ImDrawCmd_reserve = lib.ImVector_ImDrawCmd_reserve
ImVector_ImDrawCmd.ImDrawCmd_resize = lib.ImVector_ImDrawCmd_resize
ImVector_ImDrawCmd.ImDrawCmd_resizeT = lib.ImVector_ImDrawCmd_resizeT
ImVector_ImDrawCmd.ImDrawCmd_size = lib.ImVector_ImDrawCmd_size
ImVector_ImDrawCmd.ImDrawCmd_size_in_bytes = lib.ImVector_ImDrawCmd_size_in_bytes
ImVector_ImDrawCmd.ImDrawCmd_swap = lib.ImVector_ImDrawCmd_swap
M.ImVector_ImDrawCmd = ffi.metatype("ImVector_ImDrawCmd",ImVector_ImDrawCmd)
--------------------------ImVector_float----------------------------
local ImVector_float= {}
ImVector_float.__index = ImVector_float
function ImVector_float.__new()
    local ptr = lib.ImVector_float_ImVector_float()
    ffi.gc(ptr,lib.ImVector_float_destroy)
    return ptr
end
ImVector_float.float__grow_capacity = lib.ImVector_float__grow_capacity
ImVector_float.float_back = lib.ImVector_float_back
ImVector_float.float_back_const = lib.ImVector_float_back_const
ImVector_float.float_begin = lib.ImVector_float_begin
ImVector_float.float_begin_const = lib.ImVector_float_begin_const
ImVector_float.float_capacity = lib.ImVector_float_capacity
ImVector_float.float_clear = lib.ImVector_float_clear
ImVector_float.float_contains = lib.ImVector_float_contains
ImVector_float.float_empty = lib.ImVector_float_empty
ImVector_float.float_end = lib.ImVector_float_end
ImVector_float.float_end_const = lib.ImVector_float_end_const
ImVector_float.float_erase = lib.ImVector_float_erase
ImVector_float.float_eraseTPtr = lib.ImVector_float_eraseTPtr
ImVector_float.float_erase_unsorted = lib.ImVector_float_erase_unsorted
ImVector_float.float_front = lib.ImVector_float_front
ImVector_float.float_front_const = lib.ImVector_float_front_const
ImVector_float.float_index_from_ptr = lib.ImVector_float_index_from_ptr
ImVector_float.float_insert = lib.ImVector_float_insert
ImVector_float.float_pop_back = lib.ImVector_float_pop_back
ImVector_float.float_push_back = lib.ImVector_float_push_back
ImVector_float.float_push_front = lib.ImVector_float_push_front
ImVector_float.float_reserve = lib.ImVector_float_reserve
ImVector_float.float_resize = lib.ImVector_float_resize
ImVector_float.float_resizeT = lib.ImVector_float_resizeT
ImVector_float.float_size = lib.ImVector_float_size
ImVector_float.float_size_in_bytes = lib.ImVector_float_size_in_bytes
ImVector_float.float_swap = lib.ImVector_float_swap
M.ImVector_float = ffi.metatype("ImVector_float",ImVector_float)
--------------------------ImGuiInputTextCallbackData----------------------------
local ImGuiInputTextCallbackData= {}
ImGuiInputTextCallbackData.__index = ImGuiInputTextCallbackData
ImGuiInputTextCallbackData.DeleteChars = lib.ImGuiInputTextCallbackData_DeleteChars
ImGuiInputTextCallbackData.HasSelection = lib.ImGuiInputTextCallbackData_HasSelection
function ImGuiInputTextCallbackData.__new()
    local ptr = lib.ImGuiInputTextCallbackData_ImGuiInputTextCallbackData()
    ffi.gc(ptr,lib.ImGuiInputTextCallbackData_destroy)
    return ptr
end
function ImGuiInputTextCallbackData:InsertChars(pos,text,text_end)
    text_end = text_end or nil
    return lib.ImGuiInputTextCallbackData_InsertChars(self,pos,text,text_end)
end
M.ImGuiInputTextCallbackData = ffi.metatype("ImGuiInputTextCallbackData",ImGuiInputTextCallbackData)
--------------------------ImGuiPayload----------------------------
local ImGuiPayload= {}
ImGuiPayload.__index = ImGuiPayload
ImGuiPayload.Clear = lib.ImGuiPayload_Clear
function ImGuiPayload.__new()
    local ptr = lib.ImGuiPayload_ImGuiPayload()
    ffi.gc(ptr,lib.ImGuiPayload_destroy)
    return ptr
end
ImGuiPayload.IsDataType = lib.ImGuiPayload_IsDataType
ImGuiPayload.IsDelivery = lib.ImGuiPayload_IsDelivery
ImGuiPayload.IsPreview = lib.ImGuiPayload_IsPreview
M.ImGuiPayload = ffi.metatype("ImGuiPayload",ImGuiPayload)
--------------------------ImDrawCmd----------------------------
local ImDrawCmd= {}
ImDrawCmd.__index = ImDrawCmd
function ImDrawCmd.__new()
    local ptr = lib.ImDrawCmd_ImDrawCmd()
    ffi.gc(ptr,lib.ImDrawCmd_destroy)
    return ptr
end
M.ImDrawCmd = ffi.metatype("ImDrawCmd",ImDrawCmd)
--------------------------ImVector_CustomRect----------------------------
local ImVector_CustomRect= {}
ImVector_CustomRect.__index = ImVector_CustomRect
function ImVector_CustomRect.__new()
    local ptr = lib.ImVector_CustomRect_ImVector_CustomRect()
    ffi.gc(ptr,lib.ImVector_CustomRect_destroy)
    return ptr
end
ImVector_CustomRect.CustomRect__grow_capacity = lib.ImVector_CustomRect__grow_capacity
ImVector_CustomRect.CustomRect_back = lib.ImVector_CustomRect_back
ImVector_CustomRect.CustomRect_back_const = lib.ImVector_CustomRect_back_const
ImVector_CustomRect.CustomRect_begin = lib.ImVector_CustomRect_begin
ImVector_CustomRect.CustomRect_begin_const = lib.ImVector_CustomRect_begin_const
ImVector_CustomRect.CustomRect_capacity = lib.ImVector_CustomRect_capacity
ImVector_CustomRect.CustomRect_clear = lib.ImVector_CustomRect_clear
ImVector_CustomRect.CustomRect_empty = lib.ImVector_CustomRect_empty
ImVector_CustomRect.CustomRect_end = lib.ImVector_CustomRect_end
ImVector_CustomRect.CustomRect_end_const = lib.ImVector_CustomRect_end_const
ImVector_CustomRect.CustomRect_erase = lib.ImVector_CustomRect_erase
ImVector_CustomRect.CustomRect_eraseTPtr = lib.ImVector_CustomRect_eraseTPtr
ImVector_CustomRect.CustomRect_erase_unsorted = lib.ImVector_CustomRect_erase_unsorted
ImVector_CustomRect.CustomRect_front = lib.ImVector_CustomRect_front
ImVector_CustomRect.CustomRect_front_const = lib.ImVector_CustomRect_front_const
ImVector_CustomRect.CustomRect_index_from_ptr = lib.ImVector_CustomRect_index_from_ptr
ImVector_CustomRect.CustomRect_insert = lib.ImVector_CustomRect_insert
ImVector_CustomRect.CustomRect_pop_back = lib.ImVector_CustomRect_pop_back
ImVector_CustomRect.CustomRect_push_back = lib.ImVector_CustomRect_push_back
ImVector_CustomRect.CustomRect_push_front = lib.ImVector_CustomRect_push_front
ImVector_CustomRect.CustomRect_reserve = lib.ImVector_CustomRect_reserve
ImVector_CustomRect.CustomRect_resize = lib.ImVector_CustomRect_resize
ImVector_CustomRect.CustomRect_resizeT = lib.ImVector_CustomRect_resizeT
ImVector_CustomRect.CustomRect_size = lib.ImVector_CustomRect_size
ImVector_CustomRect.CustomRect_size_in_bytes = lib.ImVector_CustomRect_size_in_bytes
ImVector_CustomRect.CustomRect_swap = lib.ImVector_CustomRect_swap
M.ImVector_CustomRect = ffi.metatype("ImVector_CustomRect",ImVector_CustomRect)
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
ImGuiTextFilter.IsActive = lib.ImGuiTextFilter_IsActive
function ImGuiTextFilter:PassFilter(text,text_end)
    text_end = text_end or nil
    return lib.ImGuiTextFilter_PassFilter(self,text,text_end)
end
M.ImGuiTextFilter = ffi.metatype("ImGuiTextFilter",ImGuiTextFilter)
--------------------------ImVector_ImDrawIdx----------------------------
local ImVector_ImDrawIdx= {}
ImVector_ImDrawIdx.__index = ImVector_ImDrawIdx
function ImVector_ImDrawIdx.__new()
    local ptr = lib.ImVector_ImDrawIdx_ImVector_ImDrawIdx()
    ffi.gc(ptr,lib.ImVector_ImDrawIdx_destroy)
    return ptr
end
ImVector_ImDrawIdx.ImDrawIdx__grow_capacity = lib.ImVector_ImDrawIdx__grow_capacity
ImVector_ImDrawIdx.ImDrawIdx_back = lib.ImVector_ImDrawIdx_back
ImVector_ImDrawIdx.ImDrawIdx_back_const = lib.ImVector_ImDrawIdx_back_const
ImVector_ImDrawIdx.ImDrawIdx_begin = lib.ImVector_ImDrawIdx_begin
ImVector_ImDrawIdx.ImDrawIdx_begin_const = lib.ImVector_ImDrawIdx_begin_const
ImVector_ImDrawIdx.ImDrawIdx_capacity = lib.ImVector_ImDrawIdx_capacity
ImVector_ImDrawIdx.ImDrawIdx_clear = lib.ImVector_ImDrawIdx_clear
ImVector_ImDrawIdx.ImDrawIdx_empty = lib.ImVector_ImDrawIdx_empty
ImVector_ImDrawIdx.ImDrawIdx_end = lib.ImVector_ImDrawIdx_end
ImVector_ImDrawIdx.ImDrawIdx_end_const = lib.ImVector_ImDrawIdx_end_const
ImVector_ImDrawIdx.ImDrawIdx_erase = lib.ImVector_ImDrawIdx_erase
ImVector_ImDrawIdx.ImDrawIdx_eraseTPtr = lib.ImVector_ImDrawIdx_eraseTPtr
ImVector_ImDrawIdx.ImDrawIdx_erase_unsorted = lib.ImVector_ImDrawIdx_erase_unsorted
ImVector_ImDrawIdx.ImDrawIdx_front = lib.ImVector_ImDrawIdx_front
ImVector_ImDrawIdx.ImDrawIdx_front_const = lib.ImVector_ImDrawIdx_front_const
ImVector_ImDrawIdx.ImDrawIdx_index_from_ptr = lib.ImVector_ImDrawIdx_index_from_ptr
ImVector_ImDrawIdx.ImDrawIdx_insert = lib.ImVector_ImDrawIdx_insert
ImVector_ImDrawIdx.ImDrawIdx_pop_back = lib.ImVector_ImDrawIdx_pop_back
ImVector_ImDrawIdx.ImDrawIdx_push_back = lib.ImVector_ImDrawIdx_push_back
ImVector_ImDrawIdx.ImDrawIdx_push_front = lib.ImVector_ImDrawIdx_push_front
ImVector_ImDrawIdx.ImDrawIdx_reserve = lib.ImVector_ImDrawIdx_reserve
ImVector_ImDrawIdx.ImDrawIdx_resize = lib.ImVector_ImDrawIdx_resize
ImVector_ImDrawIdx.ImDrawIdx_resizeT = lib.ImVector_ImDrawIdx_resizeT
ImVector_ImDrawIdx.ImDrawIdx_size = lib.ImVector_ImDrawIdx_size
ImVector_ImDrawIdx.ImDrawIdx_size_in_bytes = lib.ImVector_ImDrawIdx_size_in_bytes
ImVector_ImDrawIdx.ImDrawIdx_swap = lib.ImVector_ImDrawIdx_swap
M.ImVector_ImDrawIdx = ffi.metatype("ImVector_ImDrawIdx",ImVector_ImDrawIdx)
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
    glyph_ranges = glyph_ranges or nil
    font_cfg = font_cfg or nil
    return lib.ImFontAtlas_AddFontFromFileTTF(self,filename,size_pixels,font_cfg,glyph_ranges)
end
function ImFontAtlas:AddFontFromMemoryCompressedBase85TTF(compressed_font_data_base85,size_pixels,font_cfg,glyph_ranges)
    glyph_ranges = glyph_ranges or nil
    font_cfg = font_cfg or nil
    return lib.ImFontAtlas_AddFontFromMemoryCompressedBase85TTF(self,compressed_font_data_base85,size_pixels,font_cfg,glyph_ranges)
end
function ImFontAtlas:AddFontFromMemoryCompressedTTF(compressed_font_data,compressed_font_size,size_pixels,font_cfg,glyph_ranges)
    glyph_ranges = glyph_ranges or nil
    font_cfg = font_cfg or nil
    return lib.ImFontAtlas_AddFontFromMemoryCompressedTTF(self,compressed_font_data,compressed_font_size,size_pixels,font_cfg,glyph_ranges)
end
function ImFontAtlas:AddFontFromMemoryTTF(font_data,font_size,size_pixels,font_cfg,glyph_ranges)
    glyph_ranges = glyph_ranges or nil
    font_cfg = font_cfg or nil
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
ImFontAtlas.GetMouseCursorTexData = lib.ImFontAtlas_GetMouseCursorTexData
function ImFontAtlas:GetTexDataAsAlpha8(out_pixels,out_width,out_height,out_bytes_per_pixel)
    out_bytes_per_pixel = out_bytes_per_pixel or nil
    return lib.ImFontAtlas_GetTexDataAsAlpha8(self,out_pixels,out_width,out_height,out_bytes_per_pixel)
end
function ImFontAtlas:GetTexDataAsRGBA32(out_pixels,out_width,out_height,out_bytes_per_pixel)
    out_bytes_per_pixel = out_bytes_per_pixel or nil
    return lib.ImFontAtlas_GetTexDataAsRGBA32(self,out_pixels,out_width,out_height,out_bytes_per_pixel)
end
function ImFontAtlas.__new()
    local ptr = lib.ImFontAtlas_ImFontAtlas()
    ffi.gc(ptr,lib.ImFontAtlas_destroy)
    return ptr
end
ImFontAtlas.IsBuilt = lib.ImFontAtlas_IsBuilt
ImFontAtlas.SetTexID = lib.ImFontAtlas_SetTexID
M.ImFontAtlas = ffi.metatype("ImFontAtlas",ImFontAtlas)
------------------------------------------------------
function M.AcceptDragDropPayload(type,flags)
    flags = flags or 0
    return lib.igAcceptDragDropPayload(type,flags)
end
M.AlignTextToFramePadding = lib.igAlignTextToFramePadding
M.ArrowButton = lib.igArrowButton
function M.Begin(name,p_open,flags)
    p_open = p_open or nil
    flags = flags or 0
    return lib.igBegin(name,p_open,flags)
end
function M.BeginChild(str_id,size,border,flags)
    border = border or false
    size = size or ImVec2(0,0)
    flags = flags or 0
    return lib.igBeginChild(str_id,size,border,flags)
end
function M.BeginChildID(id,size,border,flags)
    border = border or false
    size = size or ImVec2(0,0)
    flags = flags or 0
    return lib.igBeginChildID(id,size,border,flags)
end
function M.BeginChildFrame(id,size,flags)
    flags = flags or 0
    return lib.igBeginChildFrame(id,size,flags)
end
function M.BeginCombo(label,preview_value,flags)
    flags = flags or 0
    return lib.igBeginCombo(label,preview_value,flags)
end
function M.BeginDragDropSource(flags)
    flags = flags or 0
    return lib.igBeginDragDropSource(flags)
end
M.BeginDragDropTarget = lib.igBeginDragDropTarget
M.BeginGroup = lib.igBeginGroup
M.BeginMainMenuBar = lib.igBeginMainMenuBar
function M.BeginMenu(label,enabled)
    enabled = enabled or true
    return lib.igBeginMenu(label,enabled)
end
M.BeginMenuBar = lib.igBeginMenuBar
function M.BeginPopup(str_id,flags)
    flags = flags or 0
    return lib.igBeginPopup(str_id,flags)
end
function M.BeginPopupContextItem(str_id,mouse_button)
    mouse_button = mouse_button or 1
    str_id = str_id or nil
    return lib.igBeginPopupContextItem(str_id,mouse_button)
end
function M.BeginPopupContextVoid(str_id,mouse_button)
    mouse_button = mouse_button or 1
    str_id = str_id or nil
    return lib.igBeginPopupContextVoid(str_id,mouse_button)
end
function M.BeginPopupContextWindow(str_id,mouse_button,also_over_items)
    also_over_items = also_over_items or true
    mouse_button = mouse_button or 1
    str_id = str_id or nil
    return lib.igBeginPopupContextWindow(str_id,mouse_button,also_over_items)
end
function M.BeginPopupModal(name,p_open,flags)
    p_open = p_open or nil
    flags = flags or 0
    return lib.igBeginPopupModal(name,p_open,flags)
end
function M.BeginTabBar(str_id,flags)
    flags = flags or 0
    return lib.igBeginTabBar(str_id,flags)
end
function M.BeginTabItem(label,p_open,flags)
    p_open = p_open or nil
    flags = flags or 0
    return lib.igBeginTabItem(label,p_open,flags)
end
M.BeginTooltip = lib.igBeginTooltip
M.Bullet = lib.igBullet
M.BulletText = lib.igBulletText
M.BulletTextV = lib.igBulletTextV
function M.Button(label,size)
    size = size or ImVec2(0,0)
    return lib.igButton(label,size)
end
M.CalcItemWidth = lib.igCalcItemWidth
M.CalcListClipping = lib.igCalcListClipping
function M.CalcTextSize(text,text_end,hide_text_after_double_hash,wrap_width)
    text_end = text_end or nil
    wrap_width = wrap_width or -1.0
    hide_text_after_double_hash = hide_text_after_double_hash or false
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igCalcTextSize_nonUDT(nonUDT_out,text,text_end,hide_text_after_double_hash,wrap_width)
    return nonUDT_out[0]
end
function M.CalcTextSize_nonUDT2(text,text_end,hide_text_after_double_hash,wrap_width)
    text_end = text_end or nil
    wrap_width = wrap_width or -1.0
    hide_text_after_double_hash = hide_text_after_double_hash or false
    return lib.igCalcTextSize_nonUDT2(text,text_end,hide_text_after_double_hash,wrap_width)
end
function M.CaptureKeyboardFromApp(want_capture_keyboard_value)
    want_capture_keyboard_value = want_capture_keyboard_value or true
    return lib.igCaptureKeyboardFromApp(want_capture_keyboard_value)
end
function M.CaptureMouseFromApp(want_capture_mouse_value)
    want_capture_mouse_value = want_capture_mouse_value or true
    return lib.igCaptureMouseFromApp(want_capture_mouse_value)
end
M.Checkbox = lib.igCheckbox
M.CheckboxFlags = lib.igCheckboxFlags
M.CloseCurrentPopup = lib.igCloseCurrentPopup
function M.CollapsingHeader(label,flags)
    flags = flags or 0
    return lib.igCollapsingHeader(label,flags)
end
function M.CollapsingHeaderBoolPtr(label,p_open,flags)
    flags = flags or 0
    return lib.igCollapsingHeaderBoolPtr(label,p_open,flags)
end
function M.ColorButton(desc_id,col,flags,size)
    size = size or ImVec2(0,0)
    flags = flags or 0
    return lib.igColorButton(desc_id,col,flags,size)
end
M.ColorConvertFloat4ToU32 = lib.igColorConvertFloat4ToU32
M.ColorConvertHSVtoRGB = lib.igColorConvertHSVtoRGB
M.ColorConvertRGBtoHSV = lib.igColorConvertRGBtoHSV
function M.ColorConvertU32ToFloat4(_in)
    local nonUDT_out = ffi.new("ImVec4[1]")
    lib.igColorConvertU32ToFloat4_nonUDT(nonUDT_out,_in)
    return nonUDT_out[0]
end
M.ColorConvertU32ToFloat4_nonUDT2 = lib.igColorConvertU32ToFloat4_nonUDT2
function M.ColorEdit3(label,col,flags)
    flags = flags or 0
    return lib.igColorEdit3(label,col,flags)
end
function M.ColorEdit4(label,col,flags)
    flags = flags or 0
    return lib.igColorEdit4(label,col,flags)
end
function M.ColorPicker3(label,col,flags)
    flags = flags or 0
    return lib.igColorPicker3(label,col,flags)
end
function M.ColorPicker4(label,col,flags,ref_col)
    ref_col = ref_col or nil
    flags = flags or 0
    return lib.igColorPicker4(label,col,flags,ref_col)
end
function M.Columns(count,id,border)
    border = border or true
    count = count or 1
    id = id or nil
    return lib.igColumns(count,id,border)
end
function M.Combo(label,current_item,items,items_count,popup_max_height_in_items)
    popup_max_height_in_items = popup_max_height_in_items or -1
    return lib.igCombo(label,current_item,items,items_count,popup_max_height_in_items)
end
function M.ComboStr(label,current_item,items_separated_by_zeros,popup_max_height_in_items)
    popup_max_height_in_items = popup_max_height_in_items or -1
    return lib.igComboStr(label,current_item,items_separated_by_zeros,popup_max_height_in_items)
end
function M.ComboFnPtr(label,current_item,items_getter,data,items_count,popup_max_height_in_items)
    popup_max_height_in_items = popup_max_height_in_items or -1
    return lib.igComboFnPtr(label,current_item,items_getter,data,items_count,popup_max_height_in_items)
end
function M.CreateContext(shared_font_atlas)
    shared_font_atlas = shared_font_atlas or nil
    return lib.igCreateContext(shared_font_atlas)
end
M.DebugCheckVersionAndDataLayout = lib.igDebugCheckVersionAndDataLayout
function M.DestroyContext(ctx)
    ctx = ctx or nil
    return lib.igDestroyContext(ctx)
end
function M.DragFloat(label,v,v_speed,v_min,v_max,format,power)
    v_max = v_max or 0.0
    format = format or "%.3f"
    power = power or 1.0
    v_speed = v_speed or 1.0
    v_min = v_min or 0.0
    return lib.igDragFloat(label,v,v_speed,v_min,v_max,format,power)
end
function M.DragFloat2(label,v,v_speed,v_min,v_max,format,power)
    v_max = v_max or 0.0
    format = format or "%.3f"
    power = power or 1.0
    v_speed = v_speed or 1.0
    v_min = v_min or 0.0
    return lib.igDragFloat2(label,v,v_speed,v_min,v_max,format,power)
end
function M.DragFloat3(label,v,v_speed,v_min,v_max,format,power)
    v_max = v_max or 0.0
    format = format or "%.3f"
    power = power or 1.0
    v_speed = v_speed or 1.0
    v_min = v_min or 0.0
    return lib.igDragFloat3(label,v,v_speed,v_min,v_max,format,power)
end
function M.DragFloat4(label,v,v_speed,v_min,v_max,format,power)
    v_max = v_max or 0.0
    format = format or "%.3f"
    power = power or 1.0
    v_speed = v_speed or 1.0
    v_min = v_min or 0.0
    return lib.igDragFloat4(label,v,v_speed,v_min,v_max,format,power)
end
function M.DragFloatRange2(label,v_current_min,v_current_max,v_speed,v_min,v_max,format,format_max,power)
    format_max = format_max or nil
    format = format or "%.3f"
    power = power or 1.0
    v_speed = v_speed or 1.0
    v_min = v_min or 0.0
    v_max = v_max or 0.0
    return lib.igDragFloatRange2(label,v_current_min,v_current_max,v_speed,v_min,v_max,format,format_max,power)
end
function M.DragInt(label,v,v_speed,v_min,v_max,format)
    v_max = v_max or 0
    format = format or "%d"
    v_speed = v_speed or 1.0
    v_min = v_min or 0
    return lib.igDragInt(label,v,v_speed,v_min,v_max,format)
end
function M.DragInt2(label,v,v_speed,v_min,v_max,format)
    v_max = v_max or 0
    format = format or "%d"
    v_speed = v_speed or 1.0
    v_min = v_min or 0
    return lib.igDragInt2(label,v,v_speed,v_min,v_max,format)
end
function M.DragInt3(label,v,v_speed,v_min,v_max,format)
    v_max = v_max or 0
    format = format or "%d"
    v_speed = v_speed or 1.0
    v_min = v_min or 0
    return lib.igDragInt3(label,v,v_speed,v_min,v_max,format)
end
function M.DragInt4(label,v,v_speed,v_min,v_max,format)
    v_max = v_max or 0
    format = format or "%d"
    v_speed = v_speed or 1.0
    v_min = v_min or 0
    return lib.igDragInt4(label,v,v_speed,v_min,v_max,format)
end
function M.DragIntRange2(label,v_current_min,v_current_max,v_speed,v_min,v_max,format,format_max)
    format_max = format_max or nil
    format = format or "%d"
    v_speed = v_speed or 1.0
    v_max = v_max or 0
    v_min = v_min or 0
    return lib.igDragIntRange2(label,v_current_min,v_current_max,v_speed,v_min,v_max,format,format_max)
end
function M.DragScalar(label,data_type,v,v_speed,v_min,v_max,format,power)
    v_max = v_max or nil
    format = format or nil
    v_min = v_min or nil
    power = power or 1.0
    return lib.igDragScalar(label,data_type,v,v_speed,v_min,v_max,format,power)
end
function M.DragScalarN(label,data_type,v,components,v_speed,v_min,v_max,format,power)
    v_max = v_max or nil
    format = format or nil
    v_min = v_min or nil
    power = power or 1.0
    return lib.igDragScalarN(label,data_type,v,components,v_speed,v_min,v_max,format,power)
end
M.Dummy = lib.igDummy
M.End = lib.igEnd
M.EndChild = lib.igEndChild
M.EndChildFrame = lib.igEndChildFrame
M.EndCombo = lib.igEndCombo
M.EndDragDropSource = lib.igEndDragDropSource
M.EndDragDropTarget = lib.igEndDragDropTarget
M.EndFrame = lib.igEndFrame
M.EndGroup = lib.igEndGroup
M.EndMainMenuBar = lib.igEndMainMenuBar
M.EndMenu = lib.igEndMenu
M.EndMenuBar = lib.igEndMenuBar
M.EndPopup = lib.igEndPopup
M.EndTabBar = lib.igEndTabBar
M.EndTabItem = lib.igEndTabItem
M.EndTooltip = lib.igEndTooltip
M.GetClipboardText = lib.igGetClipboardText
function M.GetColorU32(idx,alpha_mul)
    alpha_mul = alpha_mul or 1.0
    return lib.igGetColorU32(idx,alpha_mul)
end
M.GetColorU32Vec4 = lib.igGetColorU32Vec4
M.GetColorU32U32 = lib.igGetColorU32U32
M.GetColumnIndex = lib.igGetColumnIndex
function M.GetColumnOffset(column_index)
    column_index = column_index or -1
    return lib.igGetColumnOffset(column_index)
end
function M.GetColumnWidth(column_index)
    column_index = column_index or -1
    return lib.igGetColumnWidth(column_index)
end
M.GetColumnsCount = lib.igGetColumnsCount
function M.GetContentRegionAvail()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetContentRegionAvail_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetContentRegionAvail_nonUDT2 = lib.igGetContentRegionAvail_nonUDT2
M.GetContentRegionAvailWidth = lib.igGetContentRegionAvailWidth
function M.GetContentRegionMax()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetContentRegionMax_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetContentRegionMax_nonUDT2 = lib.igGetContentRegionMax_nonUDT2
M.GetCurrentContext = lib.igGetCurrentContext
function M.GetCursorPos()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetCursorPos_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetCursorPos_nonUDT2 = lib.igGetCursorPos_nonUDT2
M.GetCursorPosX = lib.igGetCursorPosX
M.GetCursorPosY = lib.igGetCursorPosY
function M.GetCursorScreenPos()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetCursorScreenPos_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetCursorScreenPos_nonUDT2 = lib.igGetCursorScreenPos_nonUDT2
function M.GetCursorStartPos()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetCursorStartPos_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetCursorStartPos_nonUDT2 = lib.igGetCursorStartPos_nonUDT2
M.GetDragDropPayload = lib.igGetDragDropPayload
M.GetDrawData = lib.igGetDrawData
M.GetDrawListSharedData = lib.igGetDrawListSharedData
M.GetFont = lib.igGetFont
M.GetFontSize = lib.igGetFontSize
function M.GetFontTexUvWhitePixel()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetFontTexUvWhitePixel_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetFontTexUvWhitePixel_nonUDT2 = lib.igGetFontTexUvWhitePixel_nonUDT2
M.GetFrameCount = lib.igGetFrameCount
M.GetFrameHeight = lib.igGetFrameHeight
M.GetFrameHeightWithSpacing = lib.igGetFrameHeightWithSpacing
M.GetIDStr = lib.igGetIDStr
M.GetIDRange = lib.igGetIDRange
M.GetIDPtr = lib.igGetIDPtr
M.GetIO = lib.igGetIO
function M.GetItemRectMax()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetItemRectMax_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetItemRectMax_nonUDT2 = lib.igGetItemRectMax_nonUDT2
function M.GetItemRectMin()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetItemRectMin_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetItemRectMin_nonUDT2 = lib.igGetItemRectMin_nonUDT2
function M.GetItemRectSize()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetItemRectSize_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetItemRectSize_nonUDT2 = lib.igGetItemRectSize_nonUDT2
M.GetKeyIndex = lib.igGetKeyIndex
M.GetKeyPressedAmount = lib.igGetKeyPressedAmount
M.GetMouseCursor = lib.igGetMouseCursor
function M.GetMouseDragDelta(button,lock_threshold)
    lock_threshold = lock_threshold or -1.0
    button = button or 0
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetMouseDragDelta_nonUDT(nonUDT_out,button,lock_threshold)
    return nonUDT_out[0]
end
function M.GetMouseDragDelta_nonUDT2(button,lock_threshold)
    lock_threshold = lock_threshold or -1.0
    button = button or 0
    return lib.igGetMouseDragDelta_nonUDT2(button,lock_threshold)
end
function M.GetMousePos()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetMousePos_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetMousePos_nonUDT2 = lib.igGetMousePos_nonUDT2
function M.GetMousePosOnOpeningCurrentPopup()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetMousePosOnOpeningCurrentPopup_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetMousePosOnOpeningCurrentPopup_nonUDT2 = lib.igGetMousePosOnOpeningCurrentPopup_nonUDT2
M.GetOverlayDrawList = lib.igGetOverlayDrawList
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
M.GetTreeNodeToLabelSpacing = lib.igGetTreeNodeToLabelSpacing
M.GetVersion = lib.igGetVersion
function M.GetWindowContentRegionMax()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetWindowContentRegionMax_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetWindowContentRegionMax_nonUDT2 = lib.igGetWindowContentRegionMax_nonUDT2
function M.GetWindowContentRegionMin()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetWindowContentRegionMin_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetWindowContentRegionMin_nonUDT2 = lib.igGetWindowContentRegionMin_nonUDT2
M.GetWindowContentRegionWidth = lib.igGetWindowContentRegionWidth
M.GetWindowDrawList = lib.igGetWindowDrawList
M.GetWindowHeight = lib.igGetWindowHeight
function M.GetWindowPos()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetWindowPos_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetWindowPos_nonUDT2 = lib.igGetWindowPos_nonUDT2
function M.GetWindowSize()
    local nonUDT_out = ffi.new("ImVec2[1]")
    lib.igGetWindowSize_nonUDT(nonUDT_out)
    return nonUDT_out[0]
end
M.GetWindowSize_nonUDT2 = lib.igGetWindowSize_nonUDT2
M.GetWindowWidth = lib.igGetWindowWidth
function M.Image(user_texture_id,size,uv0,uv1,tint_col,border_col)
    border_col = border_col or ImVec4(0,0,0,0)
    tint_col = tint_col or ImVec4(1,1,1,1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,1)
    return lib.igImage(user_texture_id,size,uv0,uv1,tint_col,border_col)
end
function M.ImageButton(user_texture_id,size,uv0,uv1,frame_padding,bg_col,tint_col)
    uv1 = uv1 or ImVec2(1,1)
    bg_col = bg_col or ImVec4(0,0,0,0)
    uv0 = uv0 or ImVec2(0,0)
    tint_col = tint_col or ImVec4(1,1,1,1)
    frame_padding = frame_padding or -1
    return lib.igImageButton(user_texture_id,size,uv0,uv1,frame_padding,bg_col,tint_col)
end
function M.Indent(indent_w)
    indent_w = indent_w or 0.0
    return lib.igIndent(indent_w)
end
function M.InputDouble(label,v,step,step_fast,format,flags)
    step = step or 0.0
    format = format or "%.6f"
    step_fast = step_fast or 0.0
    flags = flags or 0
    return lib.igInputDouble(label,v,step,step_fast,format,flags)
end
function M.InputFloat(label,v,step,step_fast,format,flags)
    step = step or 0.0
    format = format or "%.3f"
    step_fast = step_fast or 0.0
    flags = flags or 0
    return lib.igInputFloat(label,v,step,step_fast,format,flags)
end
function M.InputFloat2(label,v,format,flags)
    format = format or "%.3f"
    flags = flags or 0
    return lib.igInputFloat2(label,v,format,flags)
end
function M.InputFloat3(label,v,format,flags)
    format = format or "%.3f"
    flags = flags or 0
    return lib.igInputFloat3(label,v,format,flags)
end
function M.InputFloat4(label,v,format,flags)
    format = format or "%.3f"
    flags = flags or 0
    return lib.igInputFloat4(label,v,format,flags)
end
function M.InputInt(label,v,step,step_fast,flags)
    step = step or 1
    step_fast = step_fast or 100
    flags = flags or 0
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
function M.InputScalar(label,data_type,v,step,step_fast,format,flags)
    step = step or nil
    format = format or nil
    step_fast = step_fast or nil
    flags = flags or 0
    return lib.igInputScalar(label,data_type,v,step,step_fast,format,flags)
end
function M.InputScalarN(label,data_type,v,components,step,step_fast,format,flags)
    step = step or nil
    format = format or nil
    step_fast = step_fast or nil
    flags = flags or 0
    return lib.igInputScalarN(label,data_type,v,components,step,step_fast,format,flags)
end
function M.InputText(label,buf,buf_size,flags,callback,user_data)
    callback = callback or nil
    user_data = user_data or nil
    flags = flags or 0
    return lib.igInputText(label,buf,buf_size,flags,callback,user_data)
end
function M.InputTextMultiline(label,buf,buf_size,size,flags,callback,user_data)
    callback = callback or nil
    user_data = user_data or nil
    size = size or ImVec2(0,0)
    flags = flags or 0
    return lib.igInputTextMultiline(label,buf,buf_size,size,flags,callback,user_data)
end
M.InvisibleButton = lib.igInvisibleButton
M.IsAnyItemActive = lib.igIsAnyItemActive
M.IsAnyItemFocused = lib.igIsAnyItemFocused
M.IsAnyItemHovered = lib.igIsAnyItemHovered
M.IsAnyMouseDown = lib.igIsAnyMouseDown
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
M.IsItemVisible = lib.igIsItemVisible
M.IsKeyDown = lib.igIsKeyDown
function M.IsKeyPressed(user_key_index,_repeat)
    _repeat = _repeat or true
    return lib.igIsKeyPressed(user_key_index,_repeat)
end
M.IsKeyReleased = lib.igIsKeyReleased
function M.IsMouseClicked(button,_repeat)
    _repeat = _repeat or false
    return lib.igIsMouseClicked(button,_repeat)
end
M.IsMouseDoubleClicked = lib.igIsMouseDoubleClicked
M.IsMouseDown = lib.igIsMouseDown
function M.IsMouseDragging(button,lock_threshold)
    lock_threshold = lock_threshold or -1.0
    button = button or 0
    return lib.igIsMouseDragging(button,lock_threshold)
end
function M.IsMouseHoveringRect(r_min,r_max,clip)
    clip = clip or true
    return lib.igIsMouseHoveringRect(r_min,r_max,clip)
end
function M.IsMousePosValid(mouse_pos)
    mouse_pos = mouse_pos or nil
    return lib.igIsMousePosValid(mouse_pos)
end
M.IsMouseReleased = lib.igIsMouseReleased
M.IsPopupOpen = lib.igIsPopupOpen
M.IsRectVisible = lib.igIsRectVisible
M.IsRectVisibleVec2 = lib.igIsRectVisibleVec2
M.IsWindowAppearing = lib.igIsWindowAppearing
M.IsWindowCollapsed = lib.igIsWindowCollapsed
function M.IsWindowFocused(flags)
    flags = flags or 0
    return lib.igIsWindowFocused(flags)
end
function M.IsWindowHovered(flags)
    flags = flags or 0
    return lib.igIsWindowHovered(flags)
end
M.LabelText = lib.igLabelText
M.LabelTextV = lib.igLabelTextV
function M.ListBoxStr_arr(label,current_item,items,items_count,height_in_items)
    height_in_items = height_in_items or -1
    return lib.igListBoxStr_arr(label,current_item,items,items_count,height_in_items)
end
function M.ListBoxFnPtr(label,current_item,items_getter,data,items_count,height_in_items)
    height_in_items = height_in_items or -1
    return lib.igListBoxFnPtr(label,current_item,items_getter,data,items_count,height_in_items)
end
M.ListBoxFooter = lib.igListBoxFooter
function M.ListBoxHeaderVec2(label,size)
    size = size or ImVec2(0,0)
    return lib.igListBoxHeaderVec2(label,size)
end
function M.ListBoxHeaderInt(label,items_count,height_in_items)
    height_in_items = height_in_items or -1
    return lib.igListBoxHeaderInt(label,items_count,height_in_items)
end
M.LoadIniSettingsFromDisk = lib.igLoadIniSettingsFromDisk
function M.LoadIniSettingsFromMemory(ini_data,ini_size)
    ini_size = ini_size or 0
    return lib.igLoadIniSettingsFromMemory(ini_data,ini_size)
end
M.LogButtons = lib.igLogButtons
M.LogFinish = lib.igLogFinish
M.LogText = lib.igLogText
function M.LogToClipboard(max_depth)
    max_depth = max_depth or -1
    return lib.igLogToClipboard(max_depth)
end
function M.LogToFile(max_depth,filename)
    filename = filename or nil
    max_depth = max_depth or -1
    return lib.igLogToFile(max_depth,filename)
end
function M.LogToTTY(max_depth)
    max_depth = max_depth or -1
    return lib.igLogToTTY(max_depth)
end
M.MemAlloc = lib.igMemAlloc
M.MemFree = lib.igMemFree
function M.MenuItemBool(label,shortcut,selected,enabled)
    enabled = enabled or true
    shortcut = shortcut or nil
    selected = selected or false
    return lib.igMenuItemBool(label,shortcut,selected,enabled)
end
function M.MenuItemBoolPtr(label,shortcut,p_selected,enabled)
    enabled = enabled or true
    return lib.igMenuItemBoolPtr(label,shortcut,p_selected,enabled)
end
M.NewFrame = lib.igNewFrame
M.NewLine = lib.igNewLine
M.NextColumn = lib.igNextColumn
M.OpenPopup = lib.igOpenPopup
function M.OpenPopupOnItemClick(str_id,mouse_button)
    mouse_button = mouse_button or 1
    str_id = str_id or nil
    return lib.igOpenPopupOnItemClick(str_id,mouse_button)
end
function M.PlotHistogramFloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
    graph_size = graph_size or ImVec2(0,0)
    values_offset = values_offset or 0
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    stride = stride or ffi.sizeof("float")
    overlay_text = overlay_text or nil
    return lib.igPlotHistogramFloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
end
function M.PlotHistogramFnPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
    graph_size = graph_size or ImVec2(0,0)
    values_offset = values_offset or 0
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    overlay_text = overlay_text or nil
    return lib.igPlotHistogramFnPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
end
function M.PlotLines(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
    graph_size = graph_size or ImVec2(0,0)
    values_offset = values_offset or 0
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    stride = stride or ffi.sizeof("float")
    overlay_text = overlay_text or nil
    return lib.igPlotLines(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
end
function M.PlotLinesFnPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
    graph_size = graph_size or ImVec2(0,0)
    values_offset = values_offset or 0
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    overlay_text = overlay_text or nil
    return lib.igPlotLinesFnPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
end
M.PopAllowKeyboardFocus = lib.igPopAllowKeyboardFocus
M.PopButtonRepeat = lib.igPopButtonRepeat
M.PopClipRect = lib.igPopClipRect
M.PopFont = lib.igPopFont
M.PopID = lib.igPopID
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
    size_arg = size_arg or ImVec2(-1,0)
    return lib.igProgressBar(fraction,size_arg,overlay)
end
M.PushAllowKeyboardFocus = lib.igPushAllowKeyboardFocus
M.PushButtonRepeat = lib.igPushButtonRepeat
M.PushClipRect = lib.igPushClipRect
M.PushFont = lib.igPushFont
M.PushIDStr = lib.igPushIDStr
M.PushIDRange = lib.igPushIDRange
M.PushIDPtr = lib.igPushIDPtr
M.PushIDInt = lib.igPushIDInt
M.PushItemWidth = lib.igPushItemWidth
M.PushStyleColorU32 = lib.igPushStyleColorU32
M.PushStyleColor = lib.igPushStyleColor
M.PushStyleVarFloat = lib.igPushStyleVarFloat
M.PushStyleVarVec2 = lib.igPushStyleVarVec2
function M.PushTextWrapPos(wrap_local_pos_x)
    wrap_local_pos_x = wrap_local_pos_x or 0.0
    return lib.igPushTextWrapPos(wrap_local_pos_x)
end
M.RadioButtonBool = lib.igRadioButtonBool
M.RadioButtonIntPtr = lib.igRadioButtonIntPtr
M.Render = lib.igRender
function M.ResetMouseDragDelta(button)
    button = button or 0
    return lib.igResetMouseDragDelta(button)
end
function M.SameLine(local_pos_x,spacing_w)
    local_pos_x = local_pos_x or 0.0
    spacing_w = spacing_w or -1.0
    return lib.igSameLine(local_pos_x,spacing_w)
end
M.SaveIniSettingsToDisk = lib.igSaveIniSettingsToDisk
function M.SaveIniSettingsToMemory(out_ini_size)
    out_ini_size = out_ini_size or nil
    return lib.igSaveIniSettingsToMemory(out_ini_size)
end
function M.Selectable(label,selected,flags,size)
    flags = flags or 0
    size = size or ImVec2(0,0)
    selected = selected or false
    return lib.igSelectable(label,selected,flags,size)
end
function M.SelectableBoolPtr(label,p_selected,flags,size)
    size = size or ImVec2(0,0)
    flags = flags or 0
    return lib.igSelectableBoolPtr(label,p_selected,flags,size)
end
M.Separator = lib.igSeparator
function M.SetAllocatorFunctions(alloc_func,free_func,user_data)
    user_data = user_data or nil
    return lib.igSetAllocatorFunctions(alloc_func,free_func,user_data)
end
M.SetClipboardText = lib.igSetClipboardText
M.SetColorEditOptions = lib.igSetColorEditOptions
M.SetColumnOffset = lib.igSetColumnOffset
M.SetColumnWidth = lib.igSetColumnWidth
M.SetCurrentContext = lib.igSetCurrentContext
M.SetCursorPos = lib.igSetCursorPos
M.SetCursorPosX = lib.igSetCursorPosX
M.SetCursorPosY = lib.igSetCursorPosY
M.SetCursorScreenPos = lib.igSetCursorScreenPos
function M.SetDragDropPayload(type,data,size,cond)
    cond = cond or 0
    return lib.igSetDragDropPayload(type,data,size,cond)
end
M.SetItemAllowOverlap = lib.igSetItemAllowOverlap
M.SetItemDefaultFocus = lib.igSetItemDefaultFocus
function M.SetKeyboardFocusHere(offset)
    offset = offset or 0
    return lib.igSetKeyboardFocusHere(offset)
end
M.SetMouseCursor = lib.igSetMouseCursor
function M.SetNextTreeNodeOpen(is_open,cond)
    cond = cond or 0
    return lib.igSetNextTreeNodeOpen(is_open,cond)
end
M.SetNextWindowBgAlpha = lib.igSetNextWindowBgAlpha
function M.SetNextWindowCollapsed(collapsed,cond)
    cond = cond or 0
    return lib.igSetNextWindowCollapsed(collapsed,cond)
end
M.SetNextWindowContentSize = lib.igSetNextWindowContentSize
M.SetNextWindowFocus = lib.igSetNextWindowFocus
function M.SetNextWindowPos(pos,cond,pivot)
    cond = cond or 0
    pivot = pivot or ImVec2(0,0)
    return lib.igSetNextWindowPos(pos,cond,pivot)
end
function M.SetNextWindowSize(size,cond)
    cond = cond or 0
    return lib.igSetNextWindowSize(size,cond)
end
function M.SetNextWindowSizeConstraints(size_min,size_max,custom_callback,custom_callback_data)
    custom_callback = custom_callback or nil
    custom_callback_data = custom_callback_data or nil
    return lib.igSetNextWindowSizeConstraints(size_min,size_max,custom_callback,custom_callback_data)
end
function M.SetScrollFromPosY(local_y,center_y_ratio)
    center_y_ratio = center_y_ratio or 0.5
    return lib.igSetScrollFromPosY(local_y,center_y_ratio)
end
function M.SetScrollHereY(center_y_ratio)
    center_y_ratio = center_y_ratio or 0.5
    return lib.igSetScrollHereY(center_y_ratio)
end
M.SetScrollX = lib.igSetScrollX
M.SetScrollY = lib.igSetScrollY
M.SetStateStorage = lib.igSetStateStorage
M.SetTabItemClosed = lib.igSetTabItemClosed
M.SetTooltip = lib.igSetTooltip
M.SetTooltipV = lib.igSetTooltipV
function M.SetWindowCollapsedBool(collapsed,cond)
    cond = cond or 0
    return lib.igSetWindowCollapsedBool(collapsed,cond)
end
function M.SetWindowCollapsedStr(name,collapsed,cond)
    cond = cond or 0
    return lib.igSetWindowCollapsedStr(name,collapsed,cond)
end
M.SetWindowFocus = lib.igSetWindowFocus
M.SetWindowFocusStr = lib.igSetWindowFocusStr
M.SetWindowFontScale = lib.igSetWindowFontScale
function M.SetWindowPosVec2(pos,cond)
    cond = cond or 0
    return lib.igSetWindowPosVec2(pos,cond)
end
function M.SetWindowPosStr(name,pos,cond)
    cond = cond or 0
    return lib.igSetWindowPosStr(name,pos,cond)
end
function M.SetWindowSizeVec2(size,cond)
    cond = cond or 0
    return lib.igSetWindowSizeVec2(size,cond)
end
function M.SetWindowSizeStr(name,size,cond)
    cond = cond or 0
    return lib.igSetWindowSizeStr(name,size,cond)
end
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
function M.SliderAngle(label,v_rad,v_degrees_min,v_degrees_max,format)
    v_degrees_min = v_degrees_min or -360.0
    v_degrees_max = v_degrees_max or 360.0
    format = format or "%.0f deg"
    return lib.igSliderAngle(label,v_rad,v_degrees_min,v_degrees_max,format)
end
function M.SliderFloat(label,v,v_min,v_max,format,power)
    power = power or 1.0
    format = format or "%.3f"
    return lib.igSliderFloat(label,v,v_min,v_max,format,power)
end
function M.SliderFloat2(label,v,v_min,v_max,format,power)
    power = power or 1.0
    format = format or "%.3f"
    return lib.igSliderFloat2(label,v,v_min,v_max,format,power)
end
function M.SliderFloat3(label,v,v_min,v_max,format,power)
    power = power or 1.0
    format = format or "%.3f"
    return lib.igSliderFloat3(label,v,v_min,v_max,format,power)
end
function M.SliderFloat4(label,v,v_min,v_max,format,power)
    power = power or 1.0
    format = format or "%.3f"
    return lib.igSliderFloat4(label,v,v_min,v_max,format,power)
end
function M.SliderInt(label,v,v_min,v_max,format)
    format = format or "%d"
    return lib.igSliderInt(label,v,v_min,v_max,format)
end
function M.SliderInt2(label,v,v_min,v_max,format)
    format = format or "%d"
    return lib.igSliderInt2(label,v,v_min,v_max,format)
end
function M.SliderInt3(label,v,v_min,v_max,format)
    format = format or "%d"
    return lib.igSliderInt3(label,v,v_min,v_max,format)
end
function M.SliderInt4(label,v,v_min,v_max,format)
    format = format or "%d"
    return lib.igSliderInt4(label,v,v_min,v_max,format)
end
function M.SliderScalar(label,data_type,v,v_min,v_max,format,power)
    power = power or 1.0
    format = format or nil
    return lib.igSliderScalar(label,data_type,v,v_min,v_max,format,power)
end
function M.SliderScalarN(label,data_type,v,components,v_min,v_max,format,power)
    power = power or 1.0
    format = format or nil
    return lib.igSliderScalarN(label,data_type,v,components,v_min,v_max,format,power)
end
M.SmallButton = lib.igSmallButton
M.Spacing = lib.igSpacing
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
M.Text = lib.igText
M.TextColored = lib.igTextColored
M.TextColoredV = lib.igTextColoredV
M.TextDisabled = lib.igTextDisabled
M.TextDisabledV = lib.igTextDisabledV
function M.TextUnformatted(text,text_end)
    text_end = text_end or nil
    return lib.igTextUnformatted(text,text_end)
end
M.TextV = lib.igTextV
M.TextWrapped = lib.igTextWrapped
M.TextWrappedV = lib.igTextWrappedV
M.TreeAdvanceToLabelPos = lib.igTreeAdvanceToLabelPos
M.TreeNodeStr = lib.igTreeNodeStr
M.TreeNodeStrStr = lib.igTreeNodeStrStr
M.TreeNodePtr = lib.igTreeNodePtr
function M.TreeNodeExStr(label,flags)
    flags = flags or 0
    return lib.igTreeNodeExStr(label,flags)
end
M.TreeNodeExStrStr = lib.igTreeNodeExStrStr
M.TreeNodeExPtr = lib.igTreeNodeExPtr
M.TreeNodeExVStr = lib.igTreeNodeExVStr
M.TreeNodeExVPtr = lib.igTreeNodeExVPtr
M.TreeNodeVStr = lib.igTreeNodeVStr
M.TreeNodeVPtr = lib.igTreeNodeVPtr
M.TreePop = lib.igTreePop
M.TreePushStr = lib.igTreePushStr
function M.TreePushPtr(ptr_id)
    ptr_id = ptr_id or nil
    return lib.igTreePushPtr(ptr_id)
end
function M.Unindent(indent_w)
    indent_w = indent_w or 0.0
    return lib.igUnindent(indent_w)
end
function M.VSliderFloat(label,size,v,v_min,v_max,format,power)
    power = power or 1.0
    format = format or "%.3f"
    return lib.igVSliderFloat(label,size,v,v_min,v_max,format,power)
end
function M.VSliderInt(label,size,v,v_min,v_max,format)
    format = format or "%d"
    return lib.igVSliderInt(label,size,v,v_min,v_max,format)
end
function M.VSliderScalar(label,size,data_type,v,v_min,v_max,format,power)
    power = power or 1.0
    format = format or nil
    return lib.igVSliderScalar(label,size,data_type,v,v_min,v_max,format,power)
end
M.ValueBool = lib.igValueBool
M.ValueInt = lib.igValueInt
M.ValueUint = lib.igValueUint
function M.ValueFloat(prefix,v,float_format)
    float_format = float_format or nil
    return lib.igValueFloat(prefix,v,float_format)
end
return M
----------END_AUTOGENERATED_LUA-----------------------------
