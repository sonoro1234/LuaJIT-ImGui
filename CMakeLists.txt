Project(cimgui)
cmake_minimum_required(VERSION 2.8)

if (WIN32)
FIND_LIBRARY(GLFW_LIBRARY NAMES glfw3.dll PATHS ${GLFW_PATH})
#add_definitions("-DIMGUI_API=__declspec(dllexport)")
endif(WIN32)

include_directories(cimgui/imgui/examples/libs/gl3w)
include_directories(cimgui/imgui)
include_directories(cimgui/imgui/examples/libs/glfw/include)

add_compile_options(-std=c++11) # CMake 2.8.12 or newer

add_library(cimgui SHARED ./cimgui/imgui/examples/libs/gl3w/GL/gl3w.c 
./cimgui/imgui/imgui.cpp ./cimgui/imgui/imgui_draw.cpp ./cimgui/imgui/imgui_demo.cpp 
./cimgui/cimgui/cimgui.cpp
./extras/cimgui_extras.cpp ./extras/impl_glfw3/imgui_impl_glfw_gl3.cpp ./extras/knob.cpp  ./extras/curve.cpp ./extras/Bezier.cpp)

target_link_libraries(cimgui ${GLFW_LIBRARY} opengl32)