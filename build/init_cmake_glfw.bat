::set PATH=%PATH%;C:\mingw32\bin;C:\cmake-3.6.0\bin
:: build glfw alone

cmake -G"MinGW Makefiles" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DGLFW_PATH="../buildGLFW/install" -DIMPL_SDL=no -DLUAJIT_BIN="c:/anima" ../luajit-imgui

cmd /k