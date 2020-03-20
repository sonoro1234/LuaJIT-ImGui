Project(cimgui)
cmake_minimum_required(VERSION 2.8)
if(WIN32) #to mingw work as all the others
set(CMAKE_SHARED_LIBRARY_PREFIX "")
endif(WIN32)
#general settings
include_directories(cimgui/imgui)
add_definitions("-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS=1")
#set(IMGUI_SOURCES ./cimgui/cimgui.cpp ./cimgui/imgui/imgui.cpp ./cimgui/imgui/imgui_draw.cpp ./cimgui/imgui/imgui_demo.cpp)
include_directories(cimgui)
set(IMGUI_SOURCES ./cimgui/cimgui.cpp ./cimgui/imgui/imgui.cpp ./cimgui/imgui/imgui_draw.cpp ./cimgui/imgui/imgui_demo.cpp ./cimgui/imgui/imgui_widgets.cpp)

set(IMGUI_SOURCES_glfw)
set(IMGUI_SOURCES_sdl)
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


if(IMPL_OPENGL3)
    list(APPEND IMGUI_SOURCES ./cimgui/imgui/examples/imgui_impl_opengl3.cpp
    ./cimgui/imgui/examples/libs/gl3w/GL/gl3w.c)
    list(APPEND IMGUI_SOURCES ./extras/cimgui_extras.cpp)
    include_directories(cimgui/imgui/examples/libs/gl3w)
	if(WIN32)
        list(APPEND IMGUI_LIBRARIES opengl32)
	else(WIN32)#Unix
        list(APPEND IMGUI_LIBRARIES GL)
	endif(WIN32)
endif(IMPL_OPENGL3)

if(IMPL_OPENGL2)
    list(APPEND IMGUI_SOURCES ./cimgui/imgui/examples/imgui_impl_opengl2.cpp)
    if(WIN32)
        list(APPEND IMGUI_LIBRARIES opengl32)
	else(WIN32)#Unix
        list(APPEND IMGUI_LIBRARIES GL)
	endif(WIN32)
endif(IMPL_OPENGL2)

if(IMPL_EXTRAS)
    #list(APPEND IMGUI_SOURCES_glfw ./extras/impl_glfw3/imgui_impl_glfw_gl3.cpp)
    list(APPEND IMGUI_SOURCES ./extras/knob.cpp  ./extras/curve.cpp)
	include_directories(extras/imGuIZMO.quat/imGuIZMO.quat/)
	list(APPEND IMGUI_SOURCES ./extras/imGuIZMO.quat/imGuIZMO.quat/imGuIZMOquat.cpp  ./extras/imGuIZMO.quat.cpp)
	include_directories(extras/imGuizmo/)
	list(APPEND IMGUI_SOURCES ./extras/ImGuizmo/ImGuizmo.cpp ./extras/imGuizmo.cpp)
endif(IMPL_EXTRAS)

if(IMPL_GLFW)
    list(APPEND IMGUI_SOURCES_glfw ./cimgui/imgui/examples/imgui_impl_glfw.cpp)
	if (DEFINED GLFW_PATH)
		message(STATUS GLFW_PATH defined as ${GLFW_PATH})
        FIND_PACKAGE(glfw3 3.2 REQUIRED PATHS ${GLFW_PATH})
		message( glfw include is ${GLFW_INCLUDE})
	else (DEFINED GLFW_PATH)
		message(STATUS GLFW_PATH not defined)
		#include_directories(${GLFW_INCLUDE})
	endif(DEFINED GLFW_PATH)
    #list(APPEND IMGUI_LIBRARIES glfw)
	add_library(cimgui_glfw SHARED ${IMGUI_SOURCES} ${IMGUI_SOURCES_glfw})
	target_link_libraries(cimgui_glfw ${IMGUI_LIBRARIES} glfw)
	install(TARGETS cimgui_glfw
              RUNTIME DESTINATION  ${LUAJIT_BIN}
              LIBRARY DESTINATION  ${LUAJIT_BIN}
              #ARCHIVE DESTINATION lib 
              )
endif(IMPL_GLFW)

if(IMPL_SDL)
    list(APPEND IMGUI_SOURCES_sdl ./cimgui/imgui/examples/imgui_impl_sdl.cpp)
	if(DEFINED SDL_PATH)
		message(STATUS "SDL_PATH defined as " ${SDL_PATH})
		FIND_PACKAGE(SDL2 REQUIRED PATHS ${SDL_PATH})
		message(STATUS "sdlfound")
		get_target_property(SDL_INCLUDE SDL2::SDL2 INTERFACE_INCLUDE_DIRECTORIES)
		message(STATUS "sdlinclude is " ${SDL_INCLUDE})
		include_directories(${SDL_INCLUDE})
		set(IMGUI_SDL_LIBRARY SDL2::SDL2)
	else(DEFINED SDL_PATH)
		message(STATUS "SDL_PATH not defined")
		set(IMGUI_SDL_LIBRARY SDL2)
	endif(DEFINED SDL_PATH)
    #list(APPEND IMGUI_LIBRARIES ${SDL_LIBRARY})
	add_library(cimgui_sdl SHARED ${IMGUI_SOURCES} ${IMGUI_SOURCES_sdl})
	target_link_libraries(cimgui_sdl ${IMGUI_LIBRARIES} ${IMGUI_SDL_LIBRARY})
	install(TARGETS cimgui_sdl
              RUNTIME DESTINATION  ${LUAJIT_BIN}
              LIBRARY DESTINATION  ${LUAJIT_BIN}
              #ARCHIVE DESTINATION lib 
              )
endif(IMPL_SDL)


#install

install(DIRECTORY lua/imgui DESTINATION ${LUAJIT_BIN}/lua)