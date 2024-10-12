

-- glfw3 implementation and extras ----------------------------------------
local cdecl = cdecl or ''
cdecl = cdecl..[[


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