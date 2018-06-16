rem this is used to rebuild imgui.lua
rem set your PATH if necessary for gcc and lua with:
set PATH=%PATH%;C:\mingw32\bin;C:\luaGL;

gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS  ../cimgui/cimgui/cimgui.h | luajit.exe ./cdef.lua > tmp.txt
luajit.exe ./class_gen.lua > tmp2.lua
type tmp.txt imgui_base.lua tmp2.lua > imgui.lua

cmd /k

