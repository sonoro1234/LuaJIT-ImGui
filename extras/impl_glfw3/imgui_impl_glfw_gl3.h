// ImGui GLFW binding with OpenGL3 + shaders
// In this binding, ImTextureID is used to store an OpenGL 'GLuint' texture identifier. Read the FAQ about ImTextureID in imgui.cpp.

// You can copy and use unmodified imgui_impl_* files in your project. See main.cpp for an example of using this.
// If you use this binding you'll need to call 4 functions: ImGui_ImplXXXX_Init(), ImGui_ImplXXXX_NewFrame(), ImGui::Render() and ImGui_ImplXXXX_Shutdown().
// If you are new to ImGui, see examples/README.txt and documentation at the top of imgui.cpp.
// https://github.com/ocornut/imgui



struct GLFWwindow;
typedef unsigned int GLuint;
ImGuiContext*     pGImDefaultContext=NULL;
struct ImGui_ImplGlfwGL3{
	// Data
	GLFWwindow*  g_Window ;
	ImGuiContext* ctx;
	double       g_Time ;
	bool         g_MousePressed[3] ;
	float        g_MouseWheel;
	GLuint       g_FontTexture;
	int          g_ShaderHandle, g_VertHandle, g_FragHandle;
	int          g_AttribLocationTex, g_AttribLocationProjMtx;
	int          g_AttribLocationPosition, g_AttribLocationUV, g_AttribLocationColor;
	unsigned int g_VboHandle, g_VaoHandle, g_ElementsHandle;
	
	bool        Init(GLFWwindow* window, bool install_callbacks);
	void        NewFrame();
	void        InvalidateDeviceObjects();
	bool        CreateDeviceObjects();
	void 		RenderDrawLists(ImDrawData* draw_data);
	bool 		CreateFontsTexture();
	void 		Render();
	void 		Set();
	ImGui_ImplGlfwGL3(){
		g_Window = NULL;
		//if it is first time save default context
		if (pGImDefaultContext == NULL)
			pGImDefaultContext = ImGui::GetCurrentContext();
		ctx = ImGui::CreateContext();
		g_Time = 0.0f;
		g_MousePressed[0] = false;g_MousePressed[1] = false;g_MousePressed[2] = false;
		g_MouseWheel = 0.0f;
		g_FontTexture = 0;
		g_ShaderHandle = 0, g_VertHandle = 0, g_FragHandle = 0;
		g_AttribLocationTex = 0, g_AttribLocationProjMtx = 0;
		g_AttribLocationPosition = 0, g_AttribLocationUV = 0, g_AttribLocationColor = 0;
		g_VboHandle = 0, g_VaoHandle = 0, g_ElementsHandle = 0;
	};
	~ImGui_ImplGlfwGL3(){
		InvalidateDeviceObjects();
		ImGui::SetCurrentContext(pGImDefaultContext);
		ImGui::DestroyContext(ctx);
	};
};

#if defined _WIN32 || defined __CYGWIN__
#define IMGUI_APIX extern "C" __declspec( dllexport )
#else
#define IMGUI_APIX extern "C" 
#endif

IMGUI_APIX ImGui_ImplGlfwGL3* ImGui_ImplGlfwGL3_new(){ return new ImGui_ImplGlfwGL3();};
IMGUI_APIX ImGui_ImplGlfwGL3* ImGui_ImplGlfwGL3_delete(ImGui_ImplGlfwGL3* impl){ delete impl;};
IMGUI_APIX bool        ImGui_ImplGlfwGL3_Init(ImGui_ImplGlfwGL3* impl,GLFWwindow* window, bool install_callbacks){return impl->Init( window, install_callbacks);};
IMGUI_APIX void        ImGui_ImplGlfwGL3_NewFrame(ImGui_ImplGlfwGL3* impl){impl->NewFrame();};
IMGUI_APIX void        ImGui_ImplGlfwGL3_Render(ImGui_ImplGlfwGL3* impl){impl->Render();};
// Use if you want to reset your rendering device without losing ImGui state.
IMGUI_APIX void        ImGui_ImplGlfwGL3_InvalidateDeviceObjects(ImGui_ImplGlfwGL3*impl){impl->InvalidateDeviceObjects();};
IMGUI_APIX void        ImGui_ImplGlfwGL3_Set(ImGui_ImplGlfwGL3*impl){impl->Set();};
//IMGUI_APIX bool        ImGui_ImplGlfwGL3_CreateDeviceObjectsC(ImGui_ImplGlfwGL3*impl){impl->ImGui_ImplGlfwGL3_CreateDeviceObjects();};

// GLFW callbacks (installed by default if you enable 'install_callbacks' during initialization)
// Provided here if you want to chain callbacks.
// You can also handle inputs yourself and use those as a reference.
IMGUI_APIX void        ImGui_ImplGlfwGL3_MouseButtonCallback(GLFWwindow* window, int button, int action, int mods);
IMGUI_APIX void        ImGui_ImplGlfwGL3_ScrollCallback(GLFWwindow* window, double xoffset, double yoffset);
IMGUI_APIX void        ImGui_ImplGlfwGL3_KeyCallback(GLFWwindow* window, int key, int scancode, int action, int mods);
IMGUI_APIX void        ImGui_ImplGlfwGL3_CharCallback(GLFWwindow* window, unsigned int c);
