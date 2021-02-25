Project(cimgui)
cmake_minimum_required(VERSION 2.8)
if(WIN32) #to mingw work as all the others
set(CMAKE_SHARED_LIBRARY_PREFIX "")
endif(WIN32)
#general settings
include_directories(cimgui/imgui)
include_directories(cimplot/implot)
include_directories(cimguizmo/ImGuizmo)
include_directories(./cimguizmo_quat/imGuIZMO.quat/imGuIZMO.quat)
include_directories(cimnodes/imnodes)
add_definitions("-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS=1")

include_directories(cimgui)
set(IMGUI_SOURCES ./cimgui/cimgui.cpp 
./cimgui/imgui/imgui.cpp 
./cimgui/imgui/imgui_draw.cpp 
./cimgui/imgui/imgui_demo.cpp 
./cimgui/imgui/imgui_widgets.cpp 
./cimplot/cimplot.cpp 
./cimplot/implot/implot.cpp
./cimplot/implot/implot_items.cpp  
./cimplot/implot/implot_demo.cpp
./cimguizmo/cimguizmo.cpp
./cimguizmo/ImGuizmo/ImGuizmo.cpp
./cimguizmo_quat/cimguizmo_quat.cpp
./cimguizmo_quat/imGuIZMO.quat/imGuIZMO.quat/imGuIZMOquat.cpp  
./cimnodes/cimnodes.cpp
./cimnodes/imnodes/imnodes.cpp
./cimnodes_r/cimnodes_r.cpp
./cimnodes_r/ImNodes/ImNodes.cpp
./cimnodes_r/ImNodes/ImNodesEz.cpp
)

if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/cimgui/imgui/imgui_tables.cpp)
	list(APPEND IMGUI_SOURCES ./cimgui/imgui/imgui_tables.cpp)
endif()

if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/cimgui/imgui/backends)
	set(BAKENDS_FOLDER "./cimgui/imgui/backends/")
else()
	set(BAKENDS_FOLDER "./cimgui/imgui/examples/")
endif()


set(IMGUI_SOURCES_glfw)
set(IMGUI_SOURCES_sdl)
set(IMGUI_LIBRARIES )
set(IMGUI_ft_LIBRARIES )

if (WIN32)
    add_definitions("-DIMGUI_IMPL_API=extern \"C\" __declspec\(dllexport\)")
else(WIN32)
    add_definitions("-DIMGUI_IMPL_API=extern \"C\" ")
endif(WIN32)

add_compile_definitions("IMGUI_IMPL_OPENGL_LOADER_GL3W")
add_definitions("-DIMGUIZMO_IMGUI_FOLDER=")
#optional adding implementations
option(IMPL_GLFW "add GLFW implementation" ON)
option(IMPL_SDL "add SDL implementation" ON)
option(IMPL_OPENGL2 "add OPENGL2 implementation" ON)
option(IMPL_OPENGL3 "add OPENGL3 implementation" ON)
option(IMGUI_FREETYPE "add Freetype2" OFF)
option(IMPL_EXTRAS "knob and curve" ON)


if(IMGUI_FREETYPE)
	FIND_PACKAGE(freetype REQUIRED PATHS ${FREETYPE_PATH})
	list(APPEND IMGUI_ft_LIBRARIES freetype)
	list(APPEND IMGUI_LIBRARIES freetype)
	list(APPEND IMGUI_SOURCES ./cimgui/imgui/misc/freetype/imgui_freetype.cpp)
	add_definitions("-DCIMGUI_FREETYPE=1")
endif(IMGUI_FREETYPE)

if(IMPL_OPENGL3)
    list(APPEND IMGUI_SOURCES ${BAKENDS_FOLDER}imgui_impl_opengl3.cpp
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
    list(APPEND IMGUI_SOURCES ${BAKENDS_FOLDER}imgui_impl_opengl2.cpp)
    if(WIN32)
        list(APPEND IMGUI_LIBRARIES opengl32)
	else(WIN32)#Unix
        list(APPEND IMGUI_LIBRARIES GL)
	endif(WIN32)
endif(IMPL_OPENGL2)

if(IMPL_EXTRAS)
    list(APPEND IMGUI_SOURCES ./extras/knob.cpp  ./extras/curve.cpp)
endif(IMPL_EXTRAS)

add_library(cimgui_base OBJECT ${IMGUI_SOURCES})
target_link_libraries(cimgui_base PUBLIC ${IMGUI_ft_LIBRARIES})

if(UNIX)
set_property(TARGET cimgui_base PROPERTY POSITION_INDEPENDENT_CODE ON)
endif(UNIX)


if(IMPL_GLFW)
    list(APPEND IMGUI_SOURCES_glfw ${BAKENDS_FOLDER}imgui_impl_glfw.cpp)
	if (DEFINED GLFW_PATH)
		message(STATUS GLFW_PATH defined as ${GLFW_PATH})
        FIND_PACKAGE(glfw3 3.2 REQUIRED PATHS ${GLFW_PATH})
		message( glfw include is ${GLFW_INCLUDE})
	else (DEFINED GLFW_PATH)
		message(STATUS GLFW_PATH not defined)
		#include_directories(${GLFW_INCLUDE})
	endif(DEFINED GLFW_PATH)
	add_library(cimgui_glfw SHARED ${IMGUI_SOURCES_glfw} $<TARGET_OBJECTS:cimgui_base>)
	target_link_libraries(cimgui_glfw PUBLIC ${IMGUI_LIBRARIES} glfw)
	install(TARGETS cimgui_glfw
              RUNTIME DESTINATION  ${LUAJIT_BIN}
              LIBRARY DESTINATION  ${LUAJIT_BIN}
              #ARCHIVE DESTINATION lib 
              )
endif(IMPL_GLFW)

if(IMPL_SDL)
    list(APPEND IMGUI_SOURCES_sdl ${BAKENDS_FOLDER}imgui_impl_sdl.cpp)
	if(DEFINED SDL_PATH)
		message(STATUS "SDL_PATH defined as " ${SDL_PATH})
		FIND_PACKAGE(SDL2 REQUIRED PATHS ${SDL_PATH})
		message(STATUS "sdlfound")
		get_target_property(SDL_INCLUDE SDL2::SDL2 INTERFACE_INCLUDE_DIRECTORIES)
		message(STATUS "sdlinclude is " ${SDL_INCLUDE} " or " ${SDL2_INCLUDE_DIRS})
		#if not found latest SDL2 cmake config use older
		if (("${SDL_INCLUDE}" STREQUAL "") OR ("${SDL_INCLUDE}" STREQUAL "SDL_INCLUDE-NOTFOUND"))
			message(STATUS "sdlinclude2 is " ${SDL2_INCLUDE_DIRS})
			include_directories(${SDL2_INCLUDE_DIRS})
			set(IMGUI_SDL_LIBRARY ${SDL2_LIBRARIES})
		else()#use new one SDL2 config
			include_directories(${SDL_INCLUDE})
			set(IMGUI_SDL_LIBRARY SDL2::SDL2)
		endif()
	else(DEFINED SDL_PATH) #using SDL2 submodule from anima
		message(STATUS "SDL_PATH not defined")
		set(IMGUI_SDL_LIBRARY SDL2)
	endif(DEFINED SDL_PATH)
	add_library(cimgui_sdl SHARED  ${IMGUI_SOURCES_sdl} $<TARGET_OBJECTS:cimgui_base>)
	target_link_libraries(cimgui_sdl PUBLIC ${IMGUI_LIBRARIES} ${IMGUI_SDL_LIBRARY})
	install(TARGETS cimgui_sdl
              RUNTIME DESTINATION  ${LUAJIT_BIN}
              LIBRARY DESTINATION  ${LUAJIT_BIN}
              #ARCHIVE DESTINATION lib 
              )
endif(IMPL_SDL)


#install

install(DIRECTORY lua/imgui DESTINATION ${LUAJIT_BIN}/lua)
