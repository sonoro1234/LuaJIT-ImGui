:: this is used to rebuild imgui.lua
:: after generated adjust ffi.load path and move to lua directory

:: set your PATH if necessary for gcc and lua5.1 or luajit with:
set PATH=%PATH%;C:\mingw32\bin;C:\luaGL;

gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS ../cimgui/cimgui/cimgui.h | luajit.exe ./cdef.lua false cimgui > tmp.txt
gcc -E -DCIMGUI_API="" ../cimgui/cimgui/generator/cimgui_impl.h | luajit.exe ./cdef.lua true cimgui_impl > tmp2.txt
luajit.exe ./class_gen.lua > tmp_end.lua
type tmp.txt tmp2.txt imgui_base.lua tmp_end.lua > imgui.lua

cmd /k

