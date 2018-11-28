:: this is used to rebuild imgui.lua
:: after generated adjust ffi.load path with basedir and move to lua directory

:: set your PATH if necessary for gcc and lua5.1 or luajit with:
set PATH=%PATH%;C:\mingw32\bin;C:\luaGL;
:: set PATH=%PATH%;C:\luaGL;C:\i686-7.2.0-release-posix-dwarf-rt_v5-rev1\mingw32\bin;


gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS ../cimgui/cimgui.h | luajit.exe ./cdef.lua false cimgui > tmp.txt
gcc -E -DCIMGUI_API="" ../cimgui/generator/output/cimgui_impl.h | luajit.exe ./cdef.lua true cimgui_impl > tmp2.txt
luajit.exe ./class_gen.lua > tmp_end.lua
type tmp.txt tmp2.txt imgui_base_cdefs.lua > imgui/cdefs.lua
echo local cimguimodule = 'cimgui_glfw' --set imgui directory location > tmp0glfw.txt
type tmp0glfw.txt imgui_base.lua tmp_end.lua > imgui/glfw.lua
echo local cimguimodule = 'cimgui_sdl' --set imgui directory location > tmp0sdl.txt
type tmp0sdl.txt imgui_base.lua tmp_end.lua > imgui/sdl.lua
del tmp0glfw.txt tmp0sdl.txt tmp.txt tmp2.txt tmp_end.lua
cmd /k

