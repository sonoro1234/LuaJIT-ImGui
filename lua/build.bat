:: this is used to rebuild imgui.lua
:: after generated adjust ffi.load path with basedir and move to lua directory

:: set your PATH if necessary for gcc and lua5.1 or luajit with:
set PATH=%PATH%;C:\mingw32\bin;C:\luaGL;
:: set PATH=%PATH%;C:\luaGL;C:\i686-7.2.0-release-posix-dwarf-rt_v5-rev1\mingw32\bin;

luajit.exe ./generator.lua

cmd /k

