# LuaJIT-ImGui

![sample](sample.png)

This is a LuaJIT binding for the excellent C++ intermediate gui [imgui](https://github.com/ocornut/imgui).
Uses the cimgui_auto_implementations branch of cimgui to be the most "up to date" as possible.

Notes:
* currently this wrapper is based on version [1.62WIP of imgui](https://github.com/ocornut/imgui/releases/tag/v1.62)

# compiling

* run one of the scripts in the build directory from a sibling folder to the repo.
* make
* set basedir variable in imgui.lua to the directory libimgui is found (except if it is on luajit directory)

# binding generation

* if cimgui is updated the binding can be remade with ./lua/build.bat