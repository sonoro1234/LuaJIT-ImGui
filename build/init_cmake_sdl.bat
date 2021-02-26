::set PATH=%PATH%;C:\mingw32\bin;C:\cmake-3.6.0\bin
:: build SDL alone

cmake -G"MinGW Makefiles" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DIMPL_GLFW=no -DSDL_PATH="../buildSDL/install" -DLUAJIT_BIN="c:/anima"  ../LuaJIT-ImGui

cmd /k