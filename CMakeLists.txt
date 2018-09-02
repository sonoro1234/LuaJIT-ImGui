Project(cimgui)
cmake_minimum_required(VERSION 2.8)

#general settings
include_directories(cimgui/imgui)
add_definitions("-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS=1")
#set(IMGUI_SOURCES ./cimgui/cimgui.cpp ./cimgui/imgui/imgui.cpp ./cimgui/imgui/imgui_draw.cpp ./cimgui/imgui/imgui_demo.cpp)
include_directories(cimgui)
set(IMGUI_SOURCES ./cimgui/cimgui_auto.cpp ./cimgui/imgui/imgui.cpp ./cimgui/imgui/imgui_draw.cpp ./cimgui/imgui/imgui_demo.cpp ./cimgui/imgui/imgui_widgets.cpp)

set(IMGUI_LIBRARIES )

if (WIN32)
    add_definitions("-DIMGUI_IMPL_API=extern \"C\" __declspec\(dllexport\)")
else(WIN32)
    add_definitions("-DIMGUI_IMPL_API=extern \"C\" ")
endif(WIN32)

#optional adding implementations
option(IMPL_GLFW "add GLFW implementation" OFF)
option(IMPL_SDL "add SDL implementation" OFF)
option(IMPL_OPENGL2 "add OPENGL2 implementation" OFF)
option(IMPL_OPENGL3 "add OPENGL3 implementation" OFF)

if(IMPL_GLFW)
    list(APPEND IMGUI_SOURCES ./cimgui/imgui/examples/imgui_impl_glfw.cpp)
    FIND_PACKAGE(glfw3 3.2 REQUIRED PATHS ${GLFW_PATH})
    list(APPEND IMGUI_LIBRARIES glfw)
endif(IMPL_GLFW)

if(IMPL_SDL)
    list(APPEND IMGUI_SOURCES ./cimgui/imgui/examples/imgui_impl_sdl.cpp)
    include_directories(${SDL_INCLUDE})
    list(APPEND IMGUI_LIBRARIES ${SDL_LIBRARY})
endif(IMPL_SDL)

if(IMPL_OPENGL3)
    list(APPEND IMGUI_SOURCES ./cimgui/imgui/examples/imgui_impl_opengl3.cpp
    ./cimgui/imgui/examples/libs/gl3w/GL/gl3w.c)
    list(APPEND IMGUI_SOURCES ./extras/cimgui_extras.cpp)
    include_directories(cimgui/imgui/examples/libs/gl3w)
    list(APPEND IMGUI_LIBRARIES opengl32)
endif(IMPL_OPENGL3)

if(IMPL_OPENGL2)
    list(APPEND IMGUI_SOURCES ./cimgui/imgui/examples/imgui_impl_opengl2.cpp)
    list(APPEND IMGUI_LIBRARIES opengl32)
endif(IMPL_OPENGL2)

if(IMPL_EXTRAS)
    list(APPEND IMGUI_SOURCES ./extras/impl_glfw3/imgui_impl_glfw_gl3.cpp
    ./extras/knob.cpp  ./extras/curve.cpp)
endif(IMPL_EXTRAS)

#add library and link
add_library(cimgui SHARED ${IMGUI_SOURCES})
target_link_libraries(cimgui ${IMGUI_LIBRARIES})

#install
install(TARGETS cimgui
              RUNTIME DESTINATION  .
              LIBRARY DESTINATION  .
              #ARCHIVE DESTINATION lib 
              )
install(FILES lua/imgui.lua DESTINATION lua)