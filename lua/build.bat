rem this is used to rebuild imgui.lua
rem set your PATH if necessary for gcc and lua with:
set PATH=%PATH%;C:\mingw32\bin;C:\luaGL;

rem gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS -D"IMGUI_APIX=extern __declspec(dllexport)"  ../cimgui/cimgui/cimgui.h ../cimgui/imgui/examples/imgui_impl_glfw.h ../cimgui/imgui/examples/imgui_impl_opengl3.h | luajit.exe ./cdef.lua cimgui imgui_impl_glfw imgui_impl_opengl3 > tmp.txt

gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS ../cimgui/cimgui/cimgui.h | luajit.exe ./cdef.lua cimgui > tmp.txt
luajit.exe ./class_gen.lua > tmp2.lua
type tmp.txt imgui_base.lua tmp2.lua > imgui.lua

cmd /k

