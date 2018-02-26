rem this is used to rebuild imgui.lua
set your PATH if necessary for gcc and lua with:
set PATH=%PATH%;C:\mingw32\bin;C:\luaGL;

gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS  ../cimgui/cimgui/cimgui.h | luajit.exe ./cdef.lua > tmp.lua
type tmp.lua imgui_base.lua > imgui.lua
rem del tmp.lua

