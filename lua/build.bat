rem this is used to rebuild imgui.lua
rem set your PATH if necessary for gcc and lua with:
rem set PATH=%PATH%;C:\mingw32\bin;C:\luaGL;

gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS  ../cimgui/cimgui.h | luajit.exe ./cdef.lua > tmp.lua
type tmp.lua imgui_base.lua > imgui.lua
del tmp.lua

