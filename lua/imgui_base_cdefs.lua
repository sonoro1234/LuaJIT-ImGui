

-- glfw3 implementation and extras ----------------------------------------
local cdecl = cdecl or ''
cdecl = cdecl..[[

//////////////// glfw3 gl3 custom multiwindow Implementation
int Do_gl3wInit(void);
typedef struct GLFWwindow GLFWwindow;
typedef struct {
    // Data
    GLFWwindow*  g_Window ;
    struct ImGuiContext* ctx;
    double       g_Time ;
    bool         g_MousePressed[3] ;
    float        g_MouseWheel;
    unsigned int g_FontTexture;
    int          g_ShaderHandle, g_VertHandle, g_FragHandle;
    int          g_AttribLocationTex, g_AttribLocationProjMtx;
    int          g_AttribLocationPosition, g_AttribLocationUV, g_AttribLocationColor;
    unsigned int g_VboHandle, g_VaoHandle, g_ElementsHandle;
}ImGui_ImplGlfwGL3;

ImGui_ImplGlfwGL3* ImGui_ImplGlfwGL3_new();
void ImGui_ImplGlfwGL3_delete(ImGui_ImplGlfwGL3*);
bool ImGui_ImplGlfwGL3_Init(ImGui_ImplGlfwGL3*,GLFWwindow* window, bool install_callbacks);
void ImGui_ImplGlfwGL3_NewFrame(ImGui_ImplGlfwGL3*);
void ImGui_ImplGlfwGL3_Render(ImGui_ImplGlfwGL3* impl);
// Use if you want to reset your rendering device without losing ImGui state.
void ImGui_ImplGlfwGL3_InvalidateDeviceObjects(ImGui_ImplGlfwGL3*);
void ImGui_ImplGlfwGL3_Set(ImGui_ImplGlfwGL3*);
//bool        ImGui_ImplGlfwGL3_CreateDeviceObjects();

// GLFW callbacks (installed by default if you enable 'install_callbacks' during initialization)
// Provided here if you want to chain callbacks.
// You can also handle inputs yourself and use those as a reference.
void ImGui_ImplGlfwGL3_MouseButtonCallback(GLFWwindow* window, int button, int action, int mods);
void ImGui_ImplGlfwGL3_ScrollCallback(GLFWwindow* window, double xoffset, double yoffset);
void ImGui_ImplGlfwGL3_KeyCallback(GLFWwindow* window, int key, int scancode, int action, int mods);
void ImGui_ImplGlfwGL3_CharCallback(GLFWwindow* window, unsigned int c);

//addons
bool Knob(const char* label, float* value_p, float minv, float maxv);
int Bezier( const char *label, float P[4] );
bool Curve(const char *label, const struct ImVec2& size, struct ImVec2 *points, const int maxpoints, float *data, int datalen,bool pressed_on_modified);
void CurveGetData(struct ImVec2 *points, const int maxpoints, float *data, int datalen);
                                
//Log
typedef struct Log Log;
Log* Log_new();
void Log_Add(Log* log,const char* fmt, ...);
void Log_Draw(Log* log, const char* title); //, bool* p_open = NULL
void Log_delete(Log* log);  

]]



if jit.os == "Windows" then
cdecl = cdecl..[[
 
// Helpers: UTF-8 <> wchar
int igImTextStrToUtf8(char* buf, int buf_size, const ImWchar* in_text, const ImWchar* in_text_end);      // return output UTF-8 bytes count 
int igImTextCharFromUtf8(unsigned int* out_char, const char* in_text, const char* in_text_end);          // return input UTF-8 bytes count 
int igImTextStrFromUtf8(ImWchar* buf, int buf_size, const char* in_text, const char* in_text_end, const char** in_remaining);   // return input UTF-8 bytes count 
int igImTextCountCharsFromUtf8(const char* in_text, const char* in_text_end);                            // return number of UTF-8 code-points (NOT bytes count) 
int igImTextCountUtf8BytesFromStr(const ImWchar* in_text, const ImWchar* in_text_end);                   // return number of bytes to express string as UTF-8 code-points 
 
]]
end

return cdecl