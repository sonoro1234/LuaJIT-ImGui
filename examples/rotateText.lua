--https://gist.github.com/carasuca/e72aacadcf6cf8139de46f97158f790f

local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "rotate demo")
local win = igwin:GLFW(800,400, "rotate demo")
local ig = win.ig

function ImMin(lhs, rhs)                 
	return ig.ImVec2(lhs.x < rhs.x and lhs.x or rhs.x, lhs.y < rhs.y and lhs.y or rhs.y); 
end
function ImMax(lhs, rhs)
	return ig.ImVec2(lhs.x >= rhs.x and lhs.x or rhs.x, lhs.y >= rhs.y and lhs.y or rhs.y); 
end

function ImRotate(v, cos_a, sin_a)        
	return ig.ImVec2(v.x * cos_a - v.y * sin_a, v.x * sin_a + v.y * cos_a); 
end

local rotation_start_index; 
function ImRotateStart() 
	rotation_start_index = ig.GetWindowDrawList().VtxBuffer.Size; 
end

function ImRotationCenter()

	local l,u = ig.ImVec2(math.huge, math.huge), ig.ImVec2(-math.huge, -math.huge); -- bounds

	local buf = ig.GetWindowDrawList().VtxBuffer;
	for i = rotation_start_index,buf.Size-1 do
		l = ImMin(l, buf.Data[i].pos); u = ImMax(u, buf.Data[i].pos);
	end

	return ig.ImVec2((l.x+u.x)/2, (l.y+u.y)/2); -- or use _ClipRectStack?
end

--ImVec2 operator-(const ImVec2& l, const ImVec2& r) { return{ l.x - r.x, l.y - r.y }; }

function ImRotateEnd(rad, center)
	center = center or ImRotationCenter()
	local s,c = math.sin(rad),math.cos(rad);
	center = ImRotate(center, s, c) - center;

	local buf = ig.GetWindowDrawList().VtxBuffer;
	for i = rotation_start_index,buf.Size-1 do
		buf.Data[i].pos = ImRotate(buf.Data[i].pos, s, c) - center;
	end
end

local function secs_now()
	return ig.GetTime()
end

function win:draw(ig)

	ImRotateStart();
	ig.Text("ImRotateDemo");
	ImRotateEnd(0.5*secs_now());

	ImRotateStart(); ig.SameLine();
	if ig.Button("hola") then print"hola" end
	ImRotateEnd(5*secs_now()*(ig.IsItemHovered() and 0 or 1));
end

win:start()