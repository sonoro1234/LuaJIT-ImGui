#include <imgui.h>
#include <imgui_internal.h> 

#if defined _WIN32 || defined __CYGWIN__
#define IMGUI_APIX extern "C" __declspec( dllexport )
#else
#define IMGUI_APIX extern "C" 
#endif

#ifndef M_PI
#define M_PI 3.14159f
#endif
IMGUI_APIX ImVec2 igGetCursorScreenPosORIG()
{
    return ImGui::GetCursorScreenPos();
}

typedef ImVec2 (*ImVec2returner)();

__declspec( dllexport)  ImVec2returner igGetCursorScreenPosORIG2 = ImGui::GetCursorScreenPos;
//extern "C"
 __declspec( dllexport ) ImVec2 ImGui::GetCursorScreenPos();

 //////////////
namespace ImGui
{
    bool Curve(const char *label, const ImVec2& size, ImVec2 *points, const int maxpoints, float *data, int datalen);
	void CurveGetData(ImVec2 *points, const int maxpoints, float *data, int datalen);
};

IMGUI_APIX bool Curve(const char *label, const ImVec2& size, ImVec2 *points, const int maxpoints, float *data, int datalen)
{
	return ImGui::Curve(label, size, points, maxpoints, data, datalen);
}

IMGUI_APIX void CurveGetData(ImVec2 *points, const int maxpoints, float *data, int datalen)
{
	return ImGui::CurveGetData(points, maxpoints, data, datalen);
}

/*
IMGUI_APIX float CurveValue(float p, int maxpoints, const ImVec2 *points)
{
	return ImGui::CurveValue(p, maxpoints, points);
}
IMGUI_APIX float CurveValueSmooth(float p, int maxpoints, const ImVec2 *points)
{
	return ImGui::CurveValueSmooth(p,maxpoints, points);
}
*/
 //////////////
namespace ImGui{
 int Bezier( const char *label, float P[4] );
};

IMGUI_APIX int Bezier( const char *label, float P[4] )
{
	return ImGui::Bezier(label,P);
}
////////////// Log
struct Log
{
    ImGuiTextBuffer     Buf;
    ImGuiTextFilter     Filter;
    ImVector<int>       LineOffsets;        // Index to lines offset
    bool                ScrollToBottom;

    void    Clear()     { Buf.clear(); LineOffsets.clear(); }

	
	void    vAddLog(const char* fmt, va_list args) //IM_PRINTFARGS(2)
    {
        int old_size = Buf.size();

        Buf.appendfv(fmt, args);

        for (int new_size = Buf.size(); old_size < new_size; old_size++)
            if (Buf[old_size] == '\n')
                LineOffsets.push_back(old_size);
        ScrollToBottom = true;
    }
	
    void    Draw(const char* title, bool* p_open = NULL)
    {
        ImGui::SetNextWindowSize(ImVec2(500,400), ImGuiCond_FirstUseEver);
        ImGui::Begin(title, p_open);
        if (ImGui::Button("Clear")) Clear();
        ImGui::SameLine();
        bool copy = ImGui::Button("Copy");
        ImGui::SameLine();
        Filter.Draw("Filter", -100.0f);
        ImGui::Separator();
        ImGui::BeginChild("scrolling", ImVec2(0,0), false, ImGuiWindowFlags_HorizontalScrollbar);
        if (copy) ImGui::LogToClipboard();

        if (Filter.IsActive())
        {
            const char* buf_begin = Buf.begin();
            const char* line = buf_begin;
            for (int line_no = 0; line != NULL; line_no++)
            {
                const char* line_end = (line_no < LineOffsets.Size) ? buf_begin + LineOffsets[line_no] : NULL;
                if (Filter.PassFilter(line, line_end))
                    ImGui::TextUnformatted(line, line_end);
                line = line_end && line_end[1] ? line_end + 1 : NULL;
            }
        }
        else
        {
            ImGui::TextUnformatted(Buf.begin());
        }

        if (ScrollToBottom)
            ImGui::SetScrollHere(1.0f);
        ScrollToBottom = false;
        ImGui::EndChild();
        ImGui::End();
    }
};

IMGUI_APIX Log* Log_new()
{
	return new Log;
}
IMGUI_APIX void Log_Add(Log* log,const char* fmt, ...)
{
	va_list args;
    va_start(args, fmt);
	log->vAddLog(fmt,args);
	va_end(args);
}

IMGUI_APIX void Log_Draw(Log* log, const char* title) 
{
	bool open = true;
	log->Draw(title,&open);
}

IMGUI_APIX void Log_delete(Log* log)
{
	delete log;
}
////////////////
IMGUI_APIX bool Knob(const char* label, float* value_p, float minv, float maxv)
{	
	ImGuiStyle& style = ImGui::GetStyle();
	float line_height = ImGui::GetTextLineHeight();
	//float M_PI = 3.141592f;
	
	ImVec2 p = ImGui::GetCursorScreenPos();
	float sz = 36.0f;
	float radio =  sz*0.5f;
	ImVec2 center = ImVec2(p.x + radio, p.y + radio);
	float val1 = (value_p[0] - minv)/(maxv - minv);
	//local textval = string.format("%04.1f",value_p[0])
	//ImVec2 texsize = ImGui::CalcTextSize(textval, NULL, true); 
	//ImVec2 textpos = ImVec2(center.x - texsize.x*0.5f, center.y - texsize.y*0.5f);
	char textval[32];
	ImFormatString(textval, IM_ARRAYSIZE(textval), "%04.1f", value_p[0]);
	
	ImVec2 textpos = p;
	float gamma = M_PI/4.0f;//0 value in knob
	float alpha = (M_PI-gamma)*val1*2.0f+gamma;
	
	float x2 = -sinf(alpha)*radio + center.x;
	float y2 = cosf(alpha)*radio + center.y;
	
	ImGui::InvisibleButton(label,ImVec2(sz, sz + line_height + style.ItemInnerSpacing.y));

	bool is_active = ImGui::IsItemActive();
    bool is_hovered = ImGui::IsItemHovered();
	bool touched = false;
	
	if (is_active)
	{		
		touched = true;
		ImVec2 mp = ImGui::GetIO().MousePos;
		alpha = atan2f(mp.x - center.x, center.y - mp.y) + M_PI;
		alpha = ImMax(gamma,ImMin((float)(2.0f*M_PI-gamma),alpha));
		float value = 0.5f*(alpha-gamma)/(M_PI-gamma);
		value_p[0] = value*(maxv - minv) + minv;
	}
	
	ImU32 col32 = ImGui::GetColorU32(is_active ? ImGuiCol_FrameBgActive : is_hovered ? ImGuiCol_FrameBgHovered : ImGuiCol_FrameBg);
	ImU32 col32line = ImGui::GetColorU32(ImGuiCol_SliderGrabActive); 
	ImU32 col32text = ImGui::GetColorU32(ImGuiCol_Text);
	ImDrawList* draw_list = ImGui::GetWindowDrawList();
	draw_list->AddCircleFilled(center, radio, col32, 16);
	draw_list->AddLine(center, ImVec2(x2, y2), col32line, 1);
	draw_list->AddText(textpos, col32text, textval);
	draw_list->AddText(ImVec2(p.x, p.y + sz + style.ItemInnerSpacing.y), col32text, label);
	
	return touched;
}

// Implementing a simple custom widget using the public API.
// You may also use the <imgui_internal.h> API to get raw access to more data/helpers, however the internal API isn't guaranteed to be forward compatible.
// FIXME: Need at least proper label centering + clipping (internal functions RenderTextClipped provides both but api is flaky/temporary)
static bool MyKnob(const char* label, float* p_value, float v_min, float v_max)
{
    ImGuiIO& io = ImGui::GetIO();
    ImGuiStyle& style = ImGui::GetStyle();

    float radius_outer = 20.0f;
    ImVec2 pos = ImGui::GetCursorScreenPos();
    ImVec2 center = ImVec2(pos.x + radius_outer, pos.y + radius_outer);
    float line_height = ImGui::GetTextLineHeight();
    ImDrawList* draw_list = ImGui::GetWindowDrawList();

    float ANGLE_MIN = 3.141592f * 0.75f;
    float ANGLE_MAX = 3.141592f * 2.25f;

    ImGui::InvisibleButton(label, ImVec2(radius_outer*2, radius_outer*2 + line_height + style.ItemInnerSpacing.y));
    bool value_changed = false;
    bool is_active = ImGui::IsItemActive();
    bool is_hovered = ImGui::IsItemActive();
    if (is_active && io.MouseDelta.x != 0.0f)
    {
        float step = (v_max - v_min) / 200.0f;
        *p_value += io.MouseDelta.x * step;
        if (*p_value < v_min) *p_value = v_min;
        if (*p_value > v_max) *p_value = v_max;
        value_changed = true;
    }

    float t = (*p_value - v_min) / (v_max - v_min);
    float angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t;
    float angle_cos = cosf(angle), angle_sin = sinf(angle);
    float radius_inner = radius_outer*0.40f;
    draw_list->AddCircleFilled(center, radius_outer, ImGui::GetColorU32(ImGuiCol_FrameBg), 16);
    draw_list->AddLine(ImVec2(center.x + angle_cos*radius_inner, center.y + angle_sin*radius_inner), ImVec2(center.x + angle_cos*(radius_outer-2), center.y + angle_sin*(radius_outer-2)), ImGui::GetColorU32(ImGuiCol_SliderGrabActive), 2.0f);
    draw_list->AddCircleFilled(center, radius_inner, ImGui::GetColorU32(is_active ? ImGuiCol_FrameBgActive : is_hovered ? ImGuiCol_FrameBgHovered : ImGuiCol_FrameBg), 16);
    draw_list->AddText(ImVec2(pos.x, pos.y + radius_outer * 2 + style.ItemInnerSpacing.y), ImGui::GetColorU32(ImGuiCol_Text), label);

    if (is_active || is_hovered)
    {
        ImGui::SetNextWindowPos(ImVec2(pos.x - style.WindowPadding.x, pos.y - line_height - style.ItemInnerSpacing.y - style.WindowPadding.y));
        ImGui::BeginTooltip();
        ImGui::Text("%.3f", *p_value);
        ImGui::EndTooltip();
    }

    return value_changed;
}