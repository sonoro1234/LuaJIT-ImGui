
-----------------------Imgui_Impl_SDL3_opengl3
local Imgui_Impl_SDL3_opengl3 = {}
Imgui_Impl_SDL3_opengl3.__index = Imgui_Impl_SDL3_opengl3

function Imgui_Impl_SDL3_opengl3.__call()
    return setmetatable({ctx = lib.igCreateContext(nil)},Imgui_Impl_SDL3_opengl3)
end

function Imgui_Impl_SDL3_opengl3:Init(window, gl_context, glsl_version)
    self.window = window
	glsl_version = glsl_version or "#version 130"
    lib.ImGui_ImplSDL3_InitForOpenGL(window, gl_context);
    lib.ImGui_ImplOpenGL3_Init(glsl_version);
end

function Imgui_Impl_SDL3_opengl3:destroy()
    lib.ImGui_ImplOpenGL3_Shutdown();
    lib.ImGui_ImplSDL3_Shutdown();
    lib.igDestroyContext(self.ctx);
end

function Imgui_Impl_SDL3_opengl3:NewFrame()
    lib.ImGui_ImplOpenGL3_NewFrame();
    lib.ImGui_ImplSDL3_NewFrame();
    lib.igNewFrame();
end

function Imgui_Impl_SDL3_opengl3:Render()
    lib.igRender()
    lib.ImGui_ImplOpenGL3_RenderDrawData(lib.igGetDrawData());
end
M.Imgui_Impl_SDL3_opengl3 = setmetatable({},Imgui_Impl_SDL3_opengl3)
-----------------------Imgui_Impl_SDL3_opengl2
local Imgui_Impl_SDL3_opengl2 = {}
Imgui_Impl_SDL3_opengl2.__index = Imgui_Impl_SDL3_opengl2

function Imgui_Impl_SDL3_opengl2.__call()
    return setmetatable({ctx = lib.igCreateContext(nil)},Imgui_Impl_SDL3_opengl2)
end

function Imgui_Impl_SDL3_opengl2:Init(window, gl_context)
    self.window = window
    lib.ImGui_ImplSDL3_InitForOpenGL(window, gl_context);
    lib.ImGui_ImplOpenGL2_Init();
end

function Imgui_Impl_SDL3_opengl2:destroy()
    lib.ImGui_ImplOpenGL2_Shutdown();
    lib.ImGui_ImplSDL3_Shutdown();
    lib.igDestroyContext(self.ctx);
end

function Imgui_Impl_SDL3_opengl2:NewFrame()
    lib.ImGui_ImplOpenGL2_NewFrame();
    lib.ImGui_ImplSDL3_NewFrame();
    lib.igNewFrame();
end

function Imgui_Impl_SDL3_opengl2:Render()
    lib.igRender()
    lib.ImGui_ImplOpenGL2_RenderDrawData(lib.igGetDrawData());
end
M.Imgui_Impl_SDL3_opengl2 = setmetatable({},Imgui_Impl_SDL3_opengl2)
