#include "imgui.h"
#include "imgui_internal.h"
#include "imGuIZMOquat.h"


IMGUI_IMPL_API void resizeAxesOf(float sx,float sy, float sz)
{
	imguiGizmo::resizeAxesOf(vec3(sx,sy,sz));
}

IMGUI_IMPL_API void restoreAxesSize()
{
	imguiGizmo::restoreAxesSize();
}

IMGUI_IMPL_API void setDirectionColor(const ImVec4 color)
{
	imguiGizmo::setDirectionColor(color);
}

IMGUI_IMPL_API void restoreDirectionColor()
{
	imguiGizmo::restoreDirectionColor();
}

IMGUI_IMPL_API Mat4 mat4_cast( quat *q)
{
	return mat4_cast(*q);
}

struct m16 {
    union {
        float v[16];
        struct {      float m00, m01, m02, m03,
                        m10, m11, m12, m13,
                        m20, m21, m22, m23,
                        m30, m31, m32, m33; };
    };
};

//https://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/
IMGUI_IMPL_API quat quat_cast(float f[16])
{
	m16 m = *(m16*)f;
	float qw, qx, qy, qz;
	float tr = m.m00 + m.m11 + m.m22;

	if (tr > 0) { 
	float S = sqrt(tr+1.0f) * 2.0f; // S=4*qw 
	qw = 0.25f * S;
	qx = (m.m21 - m.m12) / S;
	qy = (m.m02 - m.m20) / S; 
	qz = (m.m10 - m.m01) / S; 
	} else if ((m.m00 > m.m11)&&(m.m00 > m.m22)) { 
	float S = sqrt(1.0f + m.m00 - m.m11 - m.m22) * 2.0f; // S=4*qx 
	qw = (m.m21 - m.m12) / S;
	qx = 0.25f * S;
	qy = (m.m01 + m.m10) / S; 
	qz = (m.m02 + m.m20) / S; 
	} else if (m.m11 > m.m22) { 
	float S = sqrt(1.0f + m.m11 - m.m00 - m.m22) * 2.0f; // S=4*qy
	qw = (m.m02 - m.m20) / S;
	qx = (m.m01 + m.m10) / S; 
	qy = 0.25f * S;
	qz = (m.m12 + m.m21) / S; 
	} else { 
	float S = sqrt(1.0f + m.m22 - m.m00 - m.m11) * 2.0f; // S=4*qz
	qw = (m.m10 - m.m01) / S;
	qx = (m.m02 + m.m20) / S;
	qy = (m.m12 + m.m21) / S;
	qz = 0.25f * S;
	}
	return quat(qw, qx, qy, qz);
}

IMGUI_IMPL_API bool ImGuizmo3D(const char* label, quat *q, float size, const int mode)
{

	return ImGui::gizmo3D(label,*q,size,mode);

}

IMGUI_IMPL_API bool ImGuizmo3Dquat(const char* label, float q[4], float size, const int mode)
{
    quat qq = quat(q[0],q[1],q[2],q[3]);
	bool ret = ImGui::gizmo3D(label,qq,size,mode);
	q[0] = qq.w;q[1] = qq.x;q[2] = qq.y;q[3] = qq.z;
	return ret;
}

IMGUI_IMPL_API bool ImGuizmo3Dvec4(const char* label, float a[4], float size, const int mode)
{
    vec4 axis_angle = vec4(a[0],a[1],a[2],a[3]);
	bool ret = ImGui::gizmo3D(label,axis_angle,size,mode);
	a[0] = axis_angle.x;a[1] = axis_angle.y;a[2] = axis_angle.z;a[3] = axis_angle.w;
	return ret;
}

IMGUI_IMPL_API bool ImGuizmo3Dvec3(const char*label ,float v[3],float size,const int mode)
{
   vec3 dir = vec3(v[0],v[1],v[2]);
   bool ret =ImGui::gizmo3D(label,dir,size,mode);
   v[0] = dir[0]; v[1] = dir[1]; v[2] = dir[2];
   return ret;
   
}

IMGUI_IMPL_API bool ImGuizmo3Dquatquat(const char*label,float q1[4],float q2[4],float size,const int mode)
{
    quat qq1 = quat(q1[0],q1[1],q1[2],q1[3]);
	quat qq2 = quat(q2[0],q2[1],q2[2],q2[3]);
	bool ret = ImGui::gizmo3D(label, qq1, qq2,size,mode);
	q1[0] = qq1.w;q1[1] = qq1.x;q1[2] = qq1.y;q1[3] = qq1.z;
	q2[0] = qq2.w;q2[1] = qq2.x;q2[2] = qq2.y;q2[3] = qq2.z;
	return ret;
}
IMGUI_IMPL_API bool ImGuizmo3Dquatvec4(const char* label,float q[4],float a[4],float size,const int mode)
{
    quat qq = quat(q[0],q[1],q[2],q[3]);
	vec4 axis_angle = vec4(a[0],a[1],a[2],a[3]);
	bool ret = ImGui::gizmo3D(label, qq, axis_angle, size, mode);
	q[0] = qq.w;q[1] = qq.x;q[2] = qq.y;q[3] = qq.z;
	a[0] = axis_angle.x;a[1] = axis_angle.y;a[2] = axis_angle.z;a[3] = axis_angle.w;
	return ret;
}
IMGUI_IMPL_API bool ImGuizmo3Dquatvec3(const char* label, float q[4], float v[3],float size,const int mode)
{
    quat qq = quat(q[0],q[1],q[2],q[3]);
	vec3 dir = vec3(v[0],v[1],v[2]);
	bool ret = ImGui::gizmo3D(label, qq, dir, size, mode);
	q[0] = qq.w;q[1] = qq.x;q[2] = qq.y;q[3] = qq.z;
	v[0] = dir[0]; v[1] = dir[1]; v[2] = dir[2];
	return ret;
}
