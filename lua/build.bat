:: this is used to rebuild imgui.lua
:: after generated adjust ffi.load path with basedir and move to lua directory

:: set your PATH if necessary for gcc and lua5.1 or luajit with:
:: set PATH=%PATH%;C:\mingw32\bin;C:\luaGL;
:: set PATH=%PATH%;C:\luaGL;C:\i686-7.2.0-release-posix-dwarf-rt_v5-rev1\mingw32\bin;

echo local basedir = '' --set imgui directory location > tmp0.txt
gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS ../cimgui/cimgui.h | luajit.exe ./cdef.lua false cimgui > tmp.txt
gcc -E -DCIMGUI_API="" ../cimgui/generator/output/cimgui_impl.h | luajit.exe ./cdef.lua true cimgui_impl > tmp2.txt
luajit.exe ./class_gen.lua > tmp_end.lua
type tmp0.txt tmp.txt tmp2.txt imgui_base.lua tmp_end.lua > imgui.lua
del tmp0.txt tmp.txt tmp2.txt tmp_end.lua
cmd /k

