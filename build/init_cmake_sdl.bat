::set PATH=%PATH%;C:\mingw32\bin;C:\cmake-3.6.0\bin

cmake -G"MinGW Makefiles" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DIMPL_SDL=yes -DIMPL_OPENGL2=yes -DIMPL_OPENGL3=yes -DSDL_PATH="../buildSDL/install" -DIMPL_EXTRAS=yes -DLUAJIT_BIN="c:/anima"  ../LuaJIT-ImGui

cmd /k