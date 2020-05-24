#include "imgui.h"
#include "imgui_internal.h"
#include "ImGuizmo.h"

typedef ImGuizmo::OPERATION OPERATION;
typedef ImGuizmo::MODE MODE;


// call inside your own window and before Manipulate() in order to draw gizmo to that window.
IMGUI_IMPL_API void igzmoSetDrawlist()
{
	ImGuizmo::SetDrawlist();
}
	
IMGUI_IMPL_API void igzmoBeginFrame()
{
	ImGuizmo::BeginFrame();
}
// return true if mouse cursor is over any gizmo control (axis, plan or screen component)
IMGUI_IMPL_API bool igzmoIsOver()
{
	return ImGuizmo::IsOver();
}
// return true if mouse IsOver or if the gizmo is in moving state
IMGUI_IMPL_API bool igzmoIsUsing()
{
	return ImGuizmo::IsUsing();
}

// enable/disable the gizmo. Stay in the state until next call to Enable.
// gizmo is rendered with gray half transparent color when disabled
IMGUI_IMPL_API void igzmoEnable(bool enable)
{
	ImGuizmo::Enable(enable);
}

IMGUI_IMPL_API void igzmoSetOrthographic(bool isOrthographic)
{
	ImGuizmo::SetOrthographic(isOrthographic);
}

IMGUI_IMPL_API void igzmoSetRect(float x, float y, float width, float height)
{
	ImGuizmo::SetRect(x,y, width, height);
}


IMGUI_IMPL_API void igzmoDrawCubes(const float *view, const float *projection, const float *matrix, int matrixCount)
{
	ImGuizmo::DrawCubes(view, projection, matrix, matrixCount);
}

IMGUI_IMPL_API void igzmoDrawGrid(const float *view, const float *projection, const float *matrix , const float gridSize)
{
	ImGuizmo::DrawGrid(view, projection, matrix, gridSize);
}

IMGUI_IMPL_API void igzmoSetID(int id)
{
	ImGuizmo::SetID(id);
}

IMGUI_IMPL_API void igzmoManipulate(float cameraView[16], float cameraProjection[16],OPERATION operation, MODE mode, float objectMatrix[16],float deltaMatrix[16] , float snap[1] , float localBounds[6] , float boundsSnap[3] )
{
	
	ImGuizmo::Manipulate(cameraView, cameraProjection, operation, mode, objectMatrix, deltaMatrix, snap, localBounds, boundsSnap);
}

IMGUI_IMPL_API void igzmoViewManipulate(float cameraView[16], float camDistance, ImVec2 pos, ImVec2 size, ImU32 backgroundColor  )
{

	ImGuizmo::ViewManipulate(cameraView, camDistance, pos, size, backgroundColor);
}
