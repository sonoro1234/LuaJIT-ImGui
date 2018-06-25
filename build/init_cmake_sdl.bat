set PATH=%PATH%;C:\mingw32\bin;C:\cmake-3.6.0\bin

cmake -G"MinGW Makefiles" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DIMPL_SDL=yes -DIMPL_OPENGL2=yes -DIMPL_OPENGL3=yes -DSDL_INCLUDE="C:\luaGL\gitsources\SDL\include" -DSDL_LIBRARY="C:/luaGL/gitsources/buildSDL/libSDL2.dll"  ../luajit-imgui

cmd /k