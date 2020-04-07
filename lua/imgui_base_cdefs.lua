

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

//ImGuiZMO.quat
typedef struct{
	float x,y,z,w;
}Vec4;
typedef struct{
	union {
		float f[16];
        Vec4 v[4];
        struct {      float m00, m01, m02, m03,
                        m10, m11, m12, m13,
                        m20, m21, m22, m23,
                        m30, m31, m32, m33; };
    };
}Mat4;
typedef struct{
	float x,y,z,w;
}quat;
void setDirectionColor(const ImVec4 color);
void restoreDirectionColor();
void resizeAxesOf(float sx,float sy, float sz);
void restoreAxesSize();
void mat4_cast( quat *q, Mat4 *m);
void quat_cast(float f[16], quat *q);
bool ImGuizmo3D(const char* label, quat *q, float size, const int mode);
bool ImGuizmo3Dquat(const char* label, float q[4], float size, const int mode);
bool ImGuizmo3Dvec4(const char* label, float a[4], float size, const int mode);
bool ImGuizmo3Dvec3(const char*label ,float v[3],float size,const int mode);
bool ImGuizmo3Dquatquat(const char*label,float q1[4],float q2[4],float size,const int mode);
bool ImGuizmo3Dquatvec4(const char* label,float q[4],float a[4],float size,const int mode);
bool ImGuizmo3Dquatvec3(const char* label, float q[4], float v[3],float size,const int mode);
typedef enum      {                            //0b0000'0000, //C++14 notation
                mode3Axes          = 0x01, //0b0000'0001, 
                modeDirection      = 0x02, //0b0000'0010,
                modeDirPlane       = 0x04, //0b0000'0010,
                modeDual           = 0x08, //0b0000'1000,
                modeMask           = 0x0f, //0b0000'1111,
                

                cubeAtOrigin       = 0x10, //0b0000'0000, 
                sphereAtOrigin     = 0x20, //0b0001'0000,
                noSolidAtOrigin    = 0x40, //0b0010'0000,
                modeFullAxes       = 0x80,
                axesModeMask       = 0xf0  //0b1111'0000
    } gizmo_modes;


//ImGuizmo
typedef enum {
	TRANSLATE,
	ROTATE,
	SCALE,
	BOUNDS,
}OPERATION;

typedef	enum {
	LOCAL,
	WORLD
}MODE;

void igzmoSetDrawlist();
void igzmoBeginFrame();
bool igzmoIsOver();
bool igzmoIsUsing();
void igzmoEnable(bool enable);
void igzmoSetOrthographic(bool isOrthographic);
void igzmoSetRect(float x, float y, float width, float height);
void igzmoDrawCube(const float *view, const float *projection, const float *matrix);
void igzmoDrawGrid(const float *view, const float *projection, const float *matrix , const float gridSize);
void igzmoManipulate(float cameraView[16], float cameraProjection[16],OPERATION operation, MODE mode, float objectMatrix[16],float deltaMatrix[16] , float snap[1] , float localBounds[6] , float boundsSnap[3] );
void igzmoViewManipulate(float cameraView[16], float camDistance, ImVec2 pos, ImVec2 size, ImU32 backgroundColor);
                                
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