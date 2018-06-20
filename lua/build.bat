:: this is used to rebuild imgui.lua
:: after generated adjust ffi.load path and move to lua directory

:: set your PATH if necessary for gcc and lua5.1 or luajit with:
set PATH=%PATH%;C:\mingw32\bin;C:\luaGL;

gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS ../cimgui/cimgui/cimgui.h | luajit.exe ./cdef.lua cimgui > tmp.txt
luajit.exe ./class_gen.lua > tmp2.lua
type tmp.txt imgui_base.lua tmp2.lua > imgui.lua

cmd /k

