return function(cimguimodule) --loader
local ffi = require"ffi"
local cdecl = require"imgui.cdefs"

local ffi_cdef = function(code)
    local ret,err = pcall(ffi.cdef,code)
    if not ret then
        local lineN = 1
        for line in code:gmatch("([^\n\r]*)\r?\n") do
            print(lineN, line)
            lineN = lineN + 1
        end
        print(err)
        error"bad cdef"
    end
end


assert(cdecl, "imgui.lua not properly build")
ffi.cdef(cdecl)


--load dll
local lib = ffi.load(cimguimodule)

-----------ImStr definition
local ImStrv
if pcall(function() local a = ffi.new("ImStrv")end) then

ImStrv= {}
function ImStrv.__new(ctype,a,b)
    b = b or ffi.new("const char*",a) + (a and #a or 0)
    return ffi.new(ctype,a,b)
end
function ImStrv.__tostring(is)
    return is.Begin~=nil and ffi.string(is.Begin,is.End~=nil and is.End-is.Begin or nil) or nil
end
ImStrv.__index = ImStrv
ImStrv = ffi.metatype("ImStrv",ImStrv)

end
-----------ImVec2 definition
local ImVec2
ImVec2 = {
    __add = function(a,b) return ImVec2(a.x + b.x, a.y + b.y) end,
    __sub = function(a,b) return ImVec2(a.x - b.x, a.y - b.y) end,
    __unm = function(a) return ImVec2(-a.x,-a.y) end,
    __mul = function(a, b) 
            if not ffi.istype(ImVec2, a) then a, b = b, a end
            if not ffi.istype(ImVec2, b) then
            assert(type(b)=="number", "ImVec2 multiplied by not number or ImVec2")
            return ImVec2(a.x * b, a.y * b) end
            return ImVec2(a.x * b.x , a.y * b.y)
    end,
    __div = function(a, b) 
            if not ffi.istype(ImVec2, b) then
            assert(type(b)=="number", "ImVec2 divided by not number or ImVec2")
            return ImVec2(a.x / b, a.y / b) end
            return ImVec2(a.x / b.x , a.y / b.y)
    end,
    __eq = function(a, b)
        if (not ffi.istype(ImVec2, b)) or (not ffi.istype(ImVec2, a)) then return false end
        return a.x == b.x and a.y == b.y end,
    __len = function(a) return math.sqrt(a.x*a.x+a.y*a.y) end,
    norm = function(a)
        return math.sqrt(a.x*a.x+a.y*a.y)
    end,
    __tostring = function(v) return 'ImVec2<'..v.x..','..v.y..'>' end
}
ImVec2.__index = ImVec2
ImVec2 = ffi.metatype("ImVec2",ImVec2)
local ImVec4= {}
ImVec4.__index = ImVec4
ImVec4 = ffi.metatype("ImVec4",ImVec4)
--the module
local M = {ImVec2 = ImVec2, ImVec4 = ImVec4 , ImStrv = ImStrv, lib = lib}

if jit.os == "Windows" then
    function M.ToUTF(unc_str)
        local buf_len = lib.igImTextCountUtf8BytesFromStr(unc_str, nil) + 1;
        local buf_local = ffi.new("char[?]",buf_len)
        lib.igImTextStrToUtf8(buf_local, buf_len, unc_str, nil);
        return buf_local
    end
    
    function M.FromUTF(utf_str)
        local wbuf_length = lib.igImTextCountCharsFromUtf8(utf_str, nil) + 1;
        local buf_local = ffi.new("ImWchar[?]",wbuf_length)
        lib.igImTextStrFromUtf8(buf_local, wbuf_length, utf_str, nil,nil);
        return buf_local
    end
end

M.FLT_MAX = lib.igGET_FLT_MAX()
M.FLT_MIN = lib.igGET_FLT_MIN()

-----------------------another Log
local Log = {}
Log.__index = Log
function Log.__new()
    local ptr = lib.Log_new()
    ffi.gc(ptr,lib.Log_delete)
    return ptr
end
function Log:Add(fmt,...)
    lib.Log_Add(self,fmt,...)
end
function Log:Draw(title)
    title = title or "Log"
    lib.Log_Draw(self,title)
end
function Log:Clear()
    lib.Log_Clear(self)
end
M.Log = ffi.metatype("Log",Log)

------------convenience function
function M.U32(a,b,c,d) return lib.igGetColorU32_Vec4(ImVec4(a,b,c,d or 1)) end

-------------ImGuiZMO.quat

function M.mat4_cast(q)
    local nonUDT_out = ffi.new("Mat4")
    lib.mat4_cast(q,nonUDT_out)
    return nonUDT_out
end
function M.mat4_pos_cast(q,pos)
    local nonUDT_out = ffi.new("Mat4")
    lib.mat4_pos_cast(q,pos,nonUDT_out)
    return nonUDT_out
end
function M.quat_cast(f)
    local nonUDT_out = ffi.new("quat")
    lib.quat_cast(f,nonUDT_out)
    return nonUDT_out
end
function M.quat_pos_cast(f)
    local nonUDT_out = ffi.new("quat")
    local nonUDT_pos = ffi.new("vec3")
    lib.quat_pos_cast(f,nonUDT_out,nonUDT_pos)
    return nonUDT_out,nonUDT_pos
end

--------------- several widgets------------
local sin, cos, atan2, pi, max, min,acos,sqrt = math.sin, math.cos, math.atan2, math.pi, math.max, math.min,math.acos,math.sqrt
function M.dial(label,value_p,sz, fac)

    fac = fac or 1
    sz = sz or 20
    local style = M.GetStyle()
    
    local p = M.GetCursorScreenPos();

    local radio =  sz*0.5
    local center = M.ImVec2(p.x + radio, p.y + radio)
    
    local x2 = cos(value_p[0]/fac)*radio + center.x
    local y2 = sin(value_p[0]/fac)*radio + center.y
    
    M.InvisibleButton(label.."t",M.ImVec2(sz, sz)) 
    local is_active = M.IsItemActive()
    local is_hovered = M.IsItemHovered()
    
    local touched = false
    if is_active then 
        touched = true
        local m = M.GetIO().MousePos
        local md = M.GetIO().MouseDelta
        if md.x == 0 and md.y == 0 then touched=false end
        local mp = M.ImVec2(m.x - md.x, m.y - md.y)
        local ax = mp.x - center.x
        local ay = mp.y - center.y
        local bx = m.x - center.x
        local by = m.y - center.y
        local ma = sqrt(ax*ax + ay*ay)
        local mb = sqrt(bx*bx + by*by)
        local ab  = ax * bx + ay * by;
        local vet = ax * by - bx * ay;
        ab = ab / (ma * mb);
        if not (ma == 0 or mb == 0 or ab < -1 or ab > 1) then

            if (vet>0) then
                value_p[0] = value_p[0] + acos(ab)*fac;
            else 
                value_p[0] = value_p[0] - acos(ab)*fac;
            end
        end
    end
    
    local col32idx = is_active and lib.ImGuiCol_FrameBgActive or (is_hovered and lib.ImGuiCol_FrameBgHovered or lib.ImGuiCol_FrameBg)
    local col32 = M.GetColorU32(col32idx, 1) 
    local col32line = M.GetColorU32(lib.ImGuiCol_SliderGrabActive, 1) 
    local draw_list = M.GetWindowDrawList();
    draw_list:AddCircleFilled( center, radio, col32, 16);
    draw_list:AddLine( center, M.ImVec2(x2, y2), col32line, 1);
    M.SameLine()
    M.PushItemWidth(50)
    if M.InputFloat(label, value_p, 0.0, 0.1) then
        touched = true
    end
    M.PopItemWidth()
    return touched
end

------------------------pad

function M.pad(label,value,sz,minv,maxv)
    minv = minv or -1
    maxv = maxv or 1
    local b = maxv - minv
    local function clip(val,mini,maxi) return math.min(maxi,math.max(mini,val)) end
    sz = sz or 300
    local canvas_pos = M.GetCursorScreenPos();
    M.InvisibleButton(label.."t",M.ImVec2(sz, sz)) -- + style.ItemInnerSpacing.y))
    local is_active = M.IsItemActive()
    local is_hovered = M.IsItemHovered()
    local touched = false
    if is_active then
        touched = true
        local m = M.GetIO().MousePos
        local md = M.GetIO().MouseDelta
        if md.x == 0 and md.y == 0 and not M.IsMouseClicked(0) then touched=false end
        value[0] = ((m.x - canvas_pos.x)/sz)*b + minv
        value[1] = (1.0 - (m.y - canvas_pos.y)/sz)*b + minv
        value[0] = clip(value[0], minv,maxv)
        value[1] = clip(value[1], minv,maxv)
    end
    local val0 = (value[0] - minv)/b 
    local val1 = (value[1] - minv)/b 
    local draw_list = M.GetWindowDrawList();
    draw_list:AddRect(canvas_pos,canvas_pos+M.ImVec2(sz,sz),M.U32(1,0,0,1))
    draw_list:AddLine(canvas_pos + M.ImVec2(0,sz/2),canvas_pos + M.ImVec2(sz,sz/2) ,M.U32(1,0,0,1))
    draw_list:AddLine(canvas_pos + M.ImVec2(sz/2,0),canvas_pos + M.ImVec2(sz/2,sz) ,M.U32(1,0,0,1))
    draw_list:AddCircleFilled(canvas_pos + M.ImVec2(val0*sz,(1-val1)*sz),5,M.U32(1,0,0,1))
    draw_list:AddText(canvas_pos, M.U32(1,1,1,1), label)
    return touched
end

function M.Plotter(xmin,xmax,nvals)
    local Graph = {xmin=xmin or 0,xmax=xmax or 1,nvals=nvals or 400}
    function Graph:init()
        self.values = ffi.new("float[?]",self.nvals)
    end
    function Graph:itox(i)
        return self.xmin + i/(self.nvals-1)*(self.xmax-self.xmin)
    end
    function Graph:calc(func,ymin1,ymax1)
        local vmin = math.huge
        local vmax = -math.huge
        for i=0,self.nvals-1 do
            self.values[i] = func(self:itox(i))
            vmin = (vmin < self.values[i]) and vmin or self.values[i]
            vmax = (vmax > self.values[i]) and vmax or self.values[i]
        end
        self.ymin = ymin1 or vmin
        self.ymax = ymax1 or vmax
    end
    function Graph:draw()
    
        local regionsize = M.GetContentRegionAvail()
        local desiredY = regionsize.y - M.GetFrameHeightWithSpacing()
        M.PushItemWidth(-1)
        M.PlotLines("##grafica",self.values,self.nvals,nil,nil,self.ymin,self.ymax,M.ImVec2(0,desiredY))
        local p = M.GetCursorScreenPos() 
        p.y = p.y - M.GetStyle().FramePadding.y
        local w = M.CalcItemWidth()
        self.origin = p
        self.size = M.ImVec2(w,desiredY)
        
        local draw_list = M.GetWindowDrawList()
        for i=0,4 do
            local ylab = i*desiredY/4 --+ M.GetStyle().FramePadding.y
            draw_list:AddLine(M.ImVec2(p.x, p.y - ylab), M.ImVec2(p.x + w,p.y - ylab), M.U32(1,0,0,1))
            local valy = self.ymin + (self.ymax - self.ymin)*i/4
            local labelY = string.format("%0.3f",valy)
            -- - M.CalcTextSize(labelY).x
            draw_list:AddText(M.ImVec2(p.x , p.y -ylab), M.U32(0,1,0,1),labelY)
        end
    
        for i=0,10 do
            local xlab = i*w/10
            draw_list:AddLine(M.ImVec2(p.x + xlab,p.y), M.ImVec2(p.x + xlab,p.y - desiredY), M.U32(1,0,0,1))
            local valx = self:itox(i/10*(self.nvals -1))
            draw_list:AddText(M.ImVec2(p.x + xlab,p.y + 2), M.U32(0,1,0,1),string.format("%0.3f",valx))
        end
        
        M.PopItemWidth()
        
        return w,desiredY
    end
    Graph:init()
    return Graph
end
------------------- LuaCombo
function M.LuaCombo(label,strs,action,args)
    args = args or {}
    action = action or function() end
    strs = strs or {"none"}
    local combo = {}
    local strings
    local IDbyname
    combo.currItem = ffi.new("int[?]",1)
    local Items, anchors
    local combowidth
    local function calcwidth()
        combowidth = 0
        for i = 1,#strings  do
            combowidth = math.max(combowidth, M.CalcTextSize(strings[i]).x)
        end
        combowidth = combowidth + M.GetStyle().FramePadding.x * 2.0 + M.GetFrameHeight() --for arrow width!!
    end
    function combo:set(strs, ini, newaction)
        action = newaction and newaction or action
        anchors = {}
        IDbyname = {}
        strings = strs or strings
        self.currItem[0] = ini and ini-1 or 0
        Items = ffi.new("const char*[?]",#strings)
        for i = 0,#strings-1  do
            anchors[#anchors+1] = ffi.new("const char*",strings[i+1])
            Items[i] = anchors[#anchors]
            IDbyname[strings[i+1]] = i+1
        end
        if args.calcwidth then combowidth = nil end
        action(ffi.string(Items[self.currItem[0]]),self.currItem[0]+1)
    end
    function combo:set_index(ind)
        self.currItem[0] = ind and ind-1 or 0
        action(ffi.string(Items[self.currItem[0]]),self.currItem[0]+1)
    end
    function combo:set_name(name)
        self:set_index(IDbyname[name])
    end
    combo:set(strs)
    function combo:draw()
        if args.calcwidth then 
            if not combowidth then calcwidth() end
            M.SetNextItemWidth(combowidth) 
        end
        if M.Combo(label,self.currItem,Items,#strings,-1) then
            action(ffi.string(Items[self.currItem[0]]),self.currItem[0]+1)
            return true
        end
    end
    function combo:get()
        return ffi.string(Items[self.currItem[0]]),self.currItem[0]+1
    end
    function combo:get_name()
        return ffi.string(Items[self.currItem[0]])
    end
    return combo
end
---------------------LuaCurve
local function gimp_curve_plot (points, p1,p2,p3,p4,data,datalen)
    local    i;
    local x0, x3;
    local y0, y1, y2, y3;
    local dx, dy;
    local slope;
    
    --/* the outer control points for the bezier curve. */
    x0 = points[p2].x;
    y0 = points[p2].y;
    x3 = points[p3].x;
    y3 = points[p3].y;
    
    -- /*
    -- * the x values of the inner control points are fixed at
    -- * x1 = 2/3*x0 + 1/3*x3   and  x2 = 1/3*x0 + 2/3*x3
    -- * this ensures that the x values increase linearily with the
    -- * parameter t and enables us to skip the calculation of the x
    -- * values altogehter - just calculate y(t) evenly spaced.
    -- */
    
    dx = x3 - x0;
    dy = y3 - y0;
    
    --assert(dx >= 0);
    if dx == 0 then dx = 0.00000001 end
    
    if (p1 == p2 and p3 == p4)
        then
        -- /* No information about the neighbors,
        -- * calculate y1 and y2 to get a straight line
        -- */
        y1 = y0 + dy / 3.0;
        y2 = y0 + dy * 2.0 / 3.0;
    elseif (p1 == p2 and p3 ~= p4)
        then
        -- /* only the right neighbor is available. Make the tangent at the
        -- * right endpoint parallel to the line between the left endpoint
        -- * and the right neighbor. Then point the tangent at the left towards
        -- * the control handle of the right tangent, to ensure that the curve
        -- * does not have an inflection point.
        -- */
        slope = (points[p4].y - y0) / (points[p4].x - x0);
    
        y2 = y3 - slope * dx / 3.0;
        y1 = y0 + (y2 - y0) / 2.0;
    elseif (p1 ~= p2 and p3 == p4)
        then
        --/* see previous case */
        slope = (y3 - points[p1].y) / (x3 - points[p1].x);
    
        y1 = y0 + slope * dx / 3.0;
        y2 = y3 + (y1 - y3) / 2.0;
    else --/* (p1 != p2 && p3 != p4) */
        -- /* Both neighbors are available. Make the tangents at the endpoints
        -- * parallel to the line between the opposite endpoint and the adjacent
        -- * neighbor.
        -- */
        slope = (y3 - points[p1].y) / (x3 - points[p1].x);
    
        y1 = y0 + slope * dx / 3.0;
    
        slope = (points[p4].y - y0) / (points[p4].x - x0);
    
        y2 = y3 - slope * dx / 3.0;
    end
    
        -- /*
        -- * finally calculate the y(t) values for the given bezier values. We can
        -- * use homogenously distributed values for t, since x(t) increases linearily.
        -- */
        --for (i = 0; i <= int (dx * (float) (datalen - 1) + 0.5); i++)
        for i=0, math.floor(dx *(datalen - 1) + 0.5) do
            local y, t;
            local    index;
        
            t = i / dx / (datalen - 1);
            y =     y0 * (1-t) * (1-t) * (1-t) +
                3 * y1 * (1-t) * (1-t) * t     +
                3 * y2 * (1-t) * t     * t     +
                    y3 * t     * t     * t;
        
            index = i + math.floor (x0 * (datalen - 1) + 0.5);
        
            if (index < datalen) then
                data[index] = math.max(0.0, math.min(y, 1.0));
            end
        end
    end
    
    local function CalcCurvesGimp(points, max, data, datalen)
        --//before x0
        local boundary = math.floor (points[0].x * (datalen - 1) + 0.5);
        for i=0,boundary-1 do
            data[i] = points[0].y;
        end
        --//after xn
        local boundary2 = math.floor (points[max - 1].x * (datalen - 1) + 0.5);
        for i=boundary2,datalen-1 do
            data[i] = points[max - 1].y;
        end
        local  p1, p2, p3, p4;
        for i = 0, max - 2 do
          p1 = math.max (i - 1, 0);
          p2 = i;
          p3 = i + 1;
          p4 = math.min (i + 2, max - 1);

          gimp_curve_plot (points, p1, p2, p3, p4, data, datalen);
        end
        --/* ensure that the control points are used exactly */
        for i = 0,max-1 do
          local x = points[i].x;
          local y = points[i].y;
          data[math.floor(x * (datalen - 1) + 0.5)] = y;
        end

    end


function M.LuaCurve(name,LUTsize)
    local points = {[0]={x=0,y=0},{x=1,y=1}}
    local LC = {points = points}
    LC.LUTsize = LUTsize
    LC.LUT = ffi.new("float[?]",LUTsize)
    local is_active = nil
    local delete_point
    local function ControlPoint(ID,graph,points,i,r)
        r = r or 5
        local pos = points[i]
        local origin = graph.origin
        local size = graph.size
        local x,y = pos.x,pos.y
        local xpos = size.x*x
        local ypos = size.y*y 
        local b_pos = M.ImVec2(origin.x + xpos - r,origin.y - ypos - r)
        M.SetCursorScreenPos(b_pos)
        M.InvisibleButton("pp"..i,M.ImVec2(r*2, r*2))
        local color = M.GetColorU32(M.lib.ImGuiCol_Button)
        if M.IsItemHovered(M.lib.ImGuiHoveredFlags_AllowWhenBlockedByActiveItem) then
            color = M.GetColorU32(M.lib.ImGuiCol_ButtonHovered)
            if M.IsMouseDown(0) then
                is_active = i
            elseif M.IsMouseClicked(1) then
                delete_point = i
                return true
            end
        end
    
        local draw_list = M.GetWindowDrawList()
        draw_list:AddCircleFilled(M.ImVec2(origin.x + xpos,origin.y - ypos), r, color)
        if is_active == i then
            local m = M.GetIO().MousePos
            local xval = (m.x - origin.x)/size.x
            local yval = (-m.y + origin.y)/size.y
            xval = math.max(0,math.min(1,xval))
            yval = math.max(0,math.min(1,yval))
            local xprev = points[i-1] and points[i-1].x
            local xpost = points[i+1] and points[i+1].x
            if xprev then xval = math.max(xval, xprev) end
            if xpost then xval = math.min(xval, xpost) end
            pos.x = xval
            pos.y = yval
        end
        return is_active == i
    end
function LC:setpoints(pts)
    points = pts
end
function LC:getpoints()
    return points
end
function LC:get_data()
    CalcCurvesGimp(points, #points+1, self.LUT, LUTsize )
end
function LC:calc(x)
	--value to bin
	x = math.min(1,math.max(0,x))
	local bin, frac = math.modf(x*(LUTsize-1))
	if frac > 0 then
		return self.LUT[bin]+frac*(self.LUT[bin+1]-self.LUT[bin])
	else
		return self.LUT[bin]
	end
end
--initial
LC:get_data()
function LC:plotter_draw(size)

        local desiredY = size.y
        local w = size.x
        
        local pp = M.GetCursorScreenPos()

        M.SetNextItemAllowOverlap()
        M.PlotLines("##grafica",self.LUT,LUTsize,nil,nil,0,1,size)
        local p = M.GetCursorScreenPos() 
        p.y = p.y - M.GetStyle().FramePadding.y

        self.origin = p
        self.size = size
        
        local draw_list = M.GetWindowDrawList()
        for i=0,10 do
            local ylab = i*desiredY/10
            draw_list:AddLine(M.ImVec2(p.x, p.y - ylab), M.ImVec2(p.x + w,p.y - ylab), M.U32(0.5,0.5,0.5,1))
        end
    
        for i=0,10 do
            local xlab = i*w/10
            draw_list:AddLine(M.ImVec2(p.x + xlab,p.y), M.ImVec2(p.x + xlab,p.y - desiredY), M.U32(0.5,0.5,0.5,1))
        end
        
end
local combo_presets = M.LuaCombo("presets",{"identity","inversion"},function(it,id)
    if it=="identity" then
        LC:setpoints({[0]={x=0,y=0},{x=1,y=1}})
    elseif it == "inversion" then
        LC:setpoints({[0]={x=0,y=1},{x=1,y=0}})
    end
end)
function LC:preset_init()
	combo_presets:set_index(1)
	self:get_data()
end
function LC:preset_set(strs,i,action)
	combo_presets:set(strs,1,action)
	--combo_presets:set_index(1)
	self:get_data()
end
function LC:draw(size)
    size = size or {x=200,y=200}
    M.PushID(name)

    --CalcCurvesGimp(points, #points+1, self.LUT, LUTsize )

    self:plotter_draw(size)
    local used = false
    if M.IsItemHovered() and M.IsMouseClicked(0) then
        used = true
        local m = M.GetIO().MousePos
        local xval = (m.x - self.origin.x)/size.x
        local yval = (-m.y + self.origin.y)/size.y
        local iins
        if xval <= points[0].x then
            iins = 0
        elseif xval >= points[#points].x then
            iins = #points + 1
        else    
            for i=0,#points-1 do
                if xval >= points[i].x and xval < points[i+1].x then
                    iins = i + 1
                    break
                end
            end
        end
        table.insert(points,iins,{x=xval,y=yval})
    end

    if M.IsMouseReleased(0) then is_active = nil end
    for i=0,#points do
        if ControlPoint("punto"..i,self,points,i) then
            used = true
        end
    end
    --point 0 never removed
    if delete_point then table.remove(points, delete_point); delete_point = nil; used = true end
    M.SetCursorScreenPos(self.origin)
    M.SetNextItemAllowOverlap()

    if combo_presets:draw() then used = true end
    M.PopID()

    if used then CalcCurvesGimp(points, #points+1, self.LUT, LUTsize ) end
    return used
end
    return LC
end



----------BEGIN_AUTOGENERATED_LUA---------------------------
--------------------------CanvasState----------------------------
local CanvasState= {}
CanvasState.__index = CanvasState
function CanvasState.__new(ctype)
    local ptr = lib.CanvasState_CanvasState()
    return ffi.gc(ptr,lib.CanvasState_destroy)
end
M.CanvasState = ffi.metatype("CanvasState",CanvasState)
--------------------------CodePoint----------------------------
local CodePoint= {}
CodePoint.__index = CodePoint
M.CodePoint_getGlyphWidth = lib.CodePoint_getGlyphWidth
M.CodePoint_isBracketCloser = lib.CodePoint_isBracketCloser
M.CodePoint_isBracketOpener = lib.CodePoint_isBracketOpener
M.CodePoint_isEastAsian = lib.CodePoint_isEastAsian
M.CodePoint_isLetter = lib.CodePoint_isLetter
M.CodePoint_isLower = lib.CodePoint_isLower
M.CodePoint_isMatchingBrackets = lib.CodePoint_isMatchingBrackets
M.CodePoint_isMatchingPair = lib.CodePoint_isMatchingPair
M.CodePoint_isNumber = lib.CodePoint_isNumber
M.CodePoint_isPairCloser = lib.CodePoint_isPairCloser
M.CodePoint_isPairOpener = lib.CodePoint_isPairOpener
M.CodePoint_isUpper = lib.CodePoint_isUpper
M.CodePoint_isWhiteSpace = lib.CodePoint_isWhiteSpace
M.CodePoint_isWord = lib.CodePoint_isWord
M.CodePoint_isXidContinue = lib.CodePoint_isXidContinue
M.CodePoint_isXidStart = lib.CodePoint_isXidStart


M.CodePoint_toLower = lib.CodePoint_toLower
M.CodePoint_toPairCloser = lib.CodePoint_toPairCloser
M.CodePoint_toPairOpener = lib.CodePoint_toPairOpener
M.CodePoint_toUpper = lib.CodePoint_toUpper
M.CodePoint_write = lib.CodePoint_write
M.CodePoint = ffi.metatype("CodePoint",CodePoint)
--------------------------Config----------------------------
local Config= {}
Config.__index = Config
function Config.__new(ctype)
    local ptr = lib.ax_NodeEditor_Config_Config_Config()
    return ffi.gc(ptr,lib.Config_destroy)
end
M.Config = ffi.metatype("Config",Config)
--------------------------DocPos----------------------------
local DocPos= {}
DocPos.__index = DocPos
function DocPos.DocPos_Nil()
    local ptr = lib.DocPos_DocPos_Nil()
    return ffi.gc(ptr,lib.DocPos_destroy)
end
function DocPos.DocPos_size_t(line,index)
    local ptr = lib.DocPos_DocPos_size_t(line,index)
    return ffi.gc(ptr,lib.DocPos_destroy)
end
function DocPos.__new(ctype,a1,a2) -- generic version
    if a1==nil then return DocPos.DocPos_Nil() end
    if (ffi.istype('uint64_t',a1) or type(a1)=='number') then return DocPos.DocPos_size_t(a1,a2) end
    print(ctype,a1,a2)
    error'DocPos.__new could not find overloaded'
end
M.DocPos = ffi.metatype("DocPos",DocPos)
--------------------------DocSelection----------------------------
local DocSelection= {}
DocSelection.__index = DocSelection
function DocSelection.DocSelection_Nil()
    local ptr = lib.DocSelection_DocSelection_Nil()
    return ffi.gc(ptr,lib.DocSelection_destroy)
end
function DocSelection.DocSelection_DocPos(start,_end)
    local ptr = lib.DocSelection_DocSelection_DocPos(start,_end)
    return ffi.gc(ptr,lib.DocSelection_destroy)
end
function DocSelection.__new(ctype,a1,a2) -- generic version
    if a1==nil then return DocSelection.DocSelection_Nil() end
    if ffi.istype('DocPos',a1) then return DocSelection.DocSelection_DocPos(a1,a2) end
    print(ctype,a1,a2)
    error'DocSelection.__new could not find overloaded'
end
M.DocSelection = ffi.metatype("DocSelection",DocSelection)
--------------------------EmulateThreeButtonMouse----------------------------
local EmulateThreeButtonMouse= {}
EmulateThreeButtonMouse.__index = EmulateThreeButtonMouse
function EmulateThreeButtonMouse.__new(ctype)
    local ptr = lib.EmulateThreeButtonMouse_EmulateThreeButtonMouse()
    return ffi.gc(ptr,lib.EmulateThreeButtonMouse_destroy)
end
M.EmulateThreeButtonMouse = ffi.metatype("EmulateThreeButtonMouse",EmulateThreeButtonMouse)
--------------------------Glyph----------------------------
local Glyph= {}
Glyph.__index = Glyph
function Glyph.Glyph_Nil()
    local ptr = lib.Glyph_Glyph_Nil()
    return ffi.gc(ptr,lib.Glyph_destroy)
end
function Glyph.Glyph_Wchar(cp)
    local ptr = lib.Glyph_Glyph_Wchar(cp)
    return ffi.gc(ptr,lib.Glyph_destroy)
end
function Glyph.Glyph_WcharColor(cp,col)
    local ptr = lib.Glyph_Glyph_WcharColor(cp,col)
    return ffi.gc(ptr,lib.Glyph_destroy)
end
function Glyph.__new(ctype,a1,a2) -- generic version
    if a1==nil then return Glyph.Glyph_Nil() end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') and a2==nil then return Glyph.Glyph_Wchar(a1) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') and (ffi.istype('Color',a2) or type(a2)=='number') then return Glyph.Glyph_WcharColor(a1,a2) end
    print(ctype,a1,a2)
    error'Glyph.__new could not find overloaded'
end
M.Glyph = ffi.metatype("Glyph",Glyph)
--------------------------ImBitVector----------------------------
local ImBitVector= {}
ImBitVector.__index = ImBitVector
ImBitVector.Clear = lib.ImBitVector_Clear
ImBitVector.ClearBit = lib.ImBitVector_ClearBit
ImBitVector.Create = lib.ImBitVector_Create
ImBitVector.SetBit = lib.ImBitVector_SetBit
ImBitVector.TestBit = lib.ImBitVector_TestBit
M.ImBitVector = ffi.metatype("ImBitVector",ImBitVector)
--------------------------ImColor----------------------------
local ImColor= {}
ImColor.__index = ImColor
function M.ImColor_HSV(h,s,v,a)
    a = a or 1.0
    return lib.ImColor_HSV(h,s,v,a)
end
function ImColor.ImColor_Nil()
    local ptr = lib.ImColor_ImColor_Nil()
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.ImColor_Float(r,g,b,a)
    if a == nil then a = 1.0 end
    local ptr = lib.ImColor_ImColor_Float(r,g,b,a)
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.ImColor_Vec4(col)
    local ptr = lib.ImColor_ImColor_Vec4(col)
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.ImColor_Int(r,g,b,a)
    if a == nil then a = 255 end
    local ptr = lib.ImColor_ImColor_Int(r,g,b,a)
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.ImColor_U32(rgba)
    local ptr = lib.ImColor_ImColor_U32(rgba)
    return ffi.gc(ptr,lib.ImColor_destroy)
end
function ImColor.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImColor.ImColor_Nil() end
    if (ffi.istype('float',a1) or type(a1)=='number') then return ImColor.ImColor_Float(a1,a2,a3,a4) end
    if ffi.istype('const ImVec4',a1) then return ImColor.ImColor_Vec4(a1) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return ImColor.ImColor_Int(a1,a2,a3,a4) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return ImColor.ImColor_U32(a1) end
    print(ctype,a1,a2,a3,a4)
    error'ImColor.__new could not find overloaded'
end
function ImColor:SetHSV(h,s,v,a)
    a = a or 1.0
    return lib.ImColor_SetHSV(self,h,s,v,a)
end
M.ImColor = ffi.metatype("ImColor",ImColor)
--------------------------ImDrawCmd----------------------------
local ImDrawCmd= {}
ImDrawCmd.__index = ImDrawCmd
ImDrawCmd.GetTexID = lib.ImDrawCmd_GetTexID
function ImDrawCmd.__new(ctype)
    local ptr = lib.ImDrawCmd_ImDrawCmd()
    return ffi.gc(ptr,lib.ImDrawCmd_destroy)
end
M.ImDrawCmd = ffi.metatype("ImDrawCmd",ImDrawCmd)
--------------------------ImDrawData----------------------------
local ImDrawData= {}
ImDrawData.__index = ImDrawData
ImDrawData.AddDrawList = lib.ImDrawData_AddDrawList
ImDrawData.Clear = lib.ImDrawData_Clear
ImDrawData.DeIndexAllBuffers = lib.ImDrawData_DeIndexAllBuffers
function ImDrawData.__new(ctype)
    local ptr = lib.ImDrawData_ImDrawData()
    return ffi.gc(ptr,lib.ImDrawData_destroy)
end
ImDrawData.ScaleClipRects = lib.ImDrawData_ScaleClipRects
M.ImDrawData = ffi.metatype("ImDrawData",ImDrawData)
--------------------------ImDrawDataBuilder----------------------------
local ImDrawDataBuilder= {}
ImDrawDataBuilder.__index = ImDrawDataBuilder
function ImDrawDataBuilder.__new(ctype)
    local ptr = lib.ImDrawDataBuilder_ImDrawDataBuilder()
    return ffi.gc(ptr,lib.ImDrawDataBuilder_destroy)
end
M.ImDrawDataBuilder = ffi.metatype("ImDrawDataBuilder",ImDrawDataBuilder)
--------------------------ImDrawList----------------------------
local ImDrawList= {}
ImDrawList.__index = ImDrawList
function ImDrawList:AddBezierCubic(p1,p2,p3,p4,col,thickness,num_segments,flags)
    flags = flags or 0
    num_segments = num_segments or 0
    return lib.ImDrawList_AddBezierCubic(self,p1,p2,p3,p4,col,thickness,num_segments,flags)
end
function ImDrawList:AddBezierQuadratic(p1,p2,p3,col,thickness,num_segments,flags)
    flags = flags or 0
    num_segments = num_segments or 0
    return lib.ImDrawList_AddBezierQuadratic(self,p1,p2,p3,col,thickness,num_segments,flags)
end
function ImDrawList:AddCallback(callback,userdata,userdata_size)
    userdata = userdata or nil
    userdata_size = userdata_size or 0
    return lib.ImDrawList_AddCallback(self,callback,userdata,userdata_size)
end
function ImDrawList:AddCircle(center,radius,col,num_segments,thickness,flags)
    flags = flags or 0
    num_segments = num_segments or 0
    thickness = thickness or 1.0
    return lib.ImDrawList_AddCircle(self,center,radius,col,num_segments,thickness,flags)
end
function ImDrawList:AddCircleFilled(center,radius,col,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_AddCircleFilled(self,center,radius,col,num_segments)
end
ImDrawList.AddConcavePolyFilled = lib.ImDrawList_AddConcavePolyFilled
function ImDrawList:AddConvexPolyFilled(points,num_points,col,flags)
    flags = flags or 0
    return lib.ImDrawList_AddConvexPolyFilled(self,points,num_points,col,flags)
end
ImDrawList.AddDrawCmd = lib.ImDrawList_AddDrawCmd
function ImDrawList:AddEllipse(center,radius,col,rot,num_segments,thickness,flags)
    flags = flags or 0
    num_segments = num_segments or 0
    rot = rot or 0.0
    thickness = thickness or 1.0
    return lib.ImDrawList_AddEllipse(self,center,radius,col,rot,num_segments,thickness,flags)
end
function ImDrawList:AddEllipseFilled(center,radius,col,rot,num_segments)
    num_segments = num_segments or 0
    rot = rot or 0.0
    return lib.ImDrawList_AddEllipseFilled(self,center,radius,col,rot,num_segments)
end
function ImDrawList:AddImage(tex_ref,p_min,p_max,uv_min,uv_max,col)
    col = col or 4294967295
    uv_max = uv_max or ImVec2(1,1)
    uv_min = uv_min or ImVec2(0,0)
    return lib.ImDrawList_AddImage(self,tex_ref,p_min,p_max,uv_min,uv_max,col)
end
function ImDrawList:AddImageQuad(tex_ref,p1,p2,p3,p4,uv1,uv2,uv3,uv4,col)
    col = col or 4294967295
    uv1 = uv1 or ImVec2(0,0)
    uv2 = uv2 or ImVec2(1,0)
    uv3 = uv3 or ImVec2(1,1)
    uv4 = uv4 or ImVec2(0,1)
    return lib.ImDrawList_AddImageQuad(self,tex_ref,p1,p2,p3,p4,uv1,uv2,uv3,uv4,col)
end
function ImDrawList:AddImageRounded(tex_ref,p_min,p_max,uv_min,uv_max,col,rounding,flags)
    flags = flags or 0
    return lib.ImDrawList_AddImageRounded(self,tex_ref,p_min,p_max,uv_min,uv_max,col,rounding,flags)
end
function ImDrawList:AddLine(p1,p2,col,thickness,flags)
    flags = flags or 0
    thickness = thickness or 1.0
    return lib.ImDrawList_AddLine(self,p1,p2,col,thickness,flags)
end
function ImDrawList:AddLineH(min_x,max_x,y,col,thickness,flags)
    flags = flags or 0
    thickness = thickness or 1.0
    return lib.ImDrawList_AddLineH(self,min_x,max_x,y,col,thickness,flags)
end
function ImDrawList:AddLineV(x,min_y,max_y,col,thickness,flags)
    flags = flags or 0
    thickness = thickness or 1.0
    return lib.ImDrawList_AddLineV(self,x,min_y,max_y,col,thickness,flags)
end
function ImDrawList:AddNgon(center,radius,col,num_segments,thickness,flags)
    flags = flags or 0
    thickness = thickness or 1.0
    return lib.ImDrawList_AddNgon(self,center,radius,col,num_segments,thickness,flags)
end
ImDrawList.AddNgonFilled = lib.ImDrawList_AddNgonFilled
function ImDrawList:AddPolyline(points,num_points,col,thickness,flags)
    flags = flags or 0
    return lib.ImDrawList_AddPolyline(self,points,num_points,col,thickness,flags)
end
function ImDrawList:AddQuad(p1,p2,p3,p4,col,thickness,flags)
    flags = flags or 0
    thickness = thickness or 1.0
    return lib.ImDrawList_AddQuad(self,p1,p2,p3,p4,col,thickness,flags)
end
ImDrawList.AddQuadFilled = lib.ImDrawList_AddQuadFilled
function ImDrawList:AddRect(p_min,p_max,col,rounding,thickness,flags)
    flags = flags or 0
    rounding = rounding or 0.0
    thickness = thickness or 1.0
    return lib.ImDrawList_AddRect(self,p_min,p_max,col,rounding,thickness,flags)
end
function ImDrawList:AddRectFilled(p_min,p_max,col,rounding,flags)
    flags = flags or 0
    rounding = rounding or 0.0
    return lib.ImDrawList_AddRectFilled(self,p_min,p_max,col,rounding,flags)
end
ImDrawList.AddRectFilledMultiColor = lib.ImDrawList_AddRectFilledMultiColor
function ImDrawList:AddText_Vec2(pos,col,text_begin,text_end)
    text_end = text_end or nil
    return lib.ImDrawList_AddText_Vec2(self,pos,col,text_begin,text_end)
end
function ImDrawList:AddText_FontPtr(font,font_size,pos,col,text_begin,text_end,wrap_width,cpu_fine_clip_rect)
    cpu_fine_clip_rect = cpu_fine_clip_rect or nil
    text_end = text_end or nil
    wrap_width = wrap_width or 0.0
    return lib.ImDrawList_AddText_FontPtr(self,font,font_size,pos,col,text_begin,text_end,wrap_width,cpu_fine_clip_rect)
end
function ImDrawList:AddText(a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if ffi.istype('const ImVec2',a2) then return self:AddText_Vec2(a2,a3,a4,a5) end
    if (ffi.istype('ImFont*',a2) or ffi.istype('ImFont',a2) or ffi.istype('ImFont[]',a2)) then return self:AddText_FontPtr(a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a2,a3,a4,a5,a6,a7,a8,a9)
    error'ImDrawList:AddText could not find overloaded'
end
function ImDrawList:AddTriangle(p1,p2,p3,col,thickness,flags)
    flags = flags or 0
    thickness = thickness or 1.0
    return lib.ImDrawList_AddTriangle(self,p1,p2,p3,col,thickness,flags)
end
ImDrawList.AddTriangleFilled = lib.ImDrawList_AddTriangleFilled
ImDrawList.ChannelsMerge = lib.ImDrawList_ChannelsMerge
ImDrawList.ChannelsSetCurrent = lib.ImDrawList_ChannelsSetCurrent
ImDrawList.ChannelsSplit = lib.ImDrawList_ChannelsSplit
ImDrawList.CloneOutput = lib.ImDrawList_CloneOutput
ImDrawList.GetClipRectMax = lib.ImDrawList_GetClipRectMax
ImDrawList.GetClipRectMin = lib.ImDrawList_GetClipRectMin
function ImDrawList.__new(ctype,shared_data)
    local ptr = lib.ImDrawList_ImDrawList(shared_data)
    return ffi.gc(ptr,lib.ImDrawList_destroy)
end
function ImDrawList:PathArcTo(center,radius,a_min,a_max,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_PathArcTo(self,center,radius,a_min,a_max,num_segments)
end
ImDrawList.PathArcToFast = lib.ImDrawList_PathArcToFast
function ImDrawList:PathBezierCubicCurveTo(p2,p3,p4,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_PathBezierCubicCurveTo(self,p2,p3,p4,num_segments)
end
function ImDrawList:PathBezierQuadraticCurveTo(p2,p3,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_PathBezierQuadraticCurveTo(self,p2,p3,num_segments)
end
ImDrawList.PathClear = lib.ImDrawList_PathClear
function ImDrawList:PathEllipticalArcTo(center,radius,rot,a_min,a_max,num_segments)
    num_segments = num_segments or 0
    return lib.ImDrawList_PathEllipticalArcTo(self,center,radius,rot,a_min,a_max,num_segments)
end
ImDrawList.PathFillConcave = lib.ImDrawList_PathFillConcave
function ImDrawList:PathFillConvex(col,flags)
    flags = flags or 0
    return lib.ImDrawList_PathFillConvex(self,col,flags)
end
ImDrawList.PathLineTo = lib.ImDrawList_PathLineTo
ImDrawList.PathLineToMergeDuplicate = lib.ImDrawList_PathLineToMergeDuplicate
function ImDrawList:PathRect(rect_min,rect_max,rounding,flags)
    flags = flags or 0
    rounding = rounding or 0.0
    return lib.ImDrawList_PathRect(self,rect_min,rect_max,rounding,flags)
end
function ImDrawList:PathStroke(col,thickness,flags)
    flags = flags or 0
    thickness = thickness or 1.0
    return lib.ImDrawList_PathStroke(self,col,thickness,flags)
end
ImDrawList.PopClipRect = lib.ImDrawList_PopClipRect
ImDrawList.PopDrawFlag = lib.ImDrawList_PopDrawFlag
ImDrawList.PopTexture = lib.ImDrawList_PopTexture
ImDrawList.PrimQuadUV = lib.ImDrawList_PrimQuadUV
ImDrawList.PrimRect = lib.ImDrawList_PrimRect
ImDrawList.PrimRectUV = lib.ImDrawList_PrimRectUV
ImDrawList.PrimReserve = lib.ImDrawList_PrimReserve
ImDrawList.PrimUnreserve = lib.ImDrawList_PrimUnreserve
ImDrawList.PrimVtx = lib.ImDrawList_PrimVtx
ImDrawList.PrimWriteIdx = lib.ImDrawList_PrimWriteIdx
ImDrawList.PrimWriteVtx = lib.ImDrawList_PrimWriteVtx
function ImDrawList:PushClipRect(clip_rect_min,clip_rect_max,intersect_with_current_clip_rect)
    intersect_with_current_clip_rect = intersect_with_current_clip_rect or false
    return lib.ImDrawList_PushClipRect(self,clip_rect_min,clip_rect_max,intersect_with_current_clip_rect)
end
ImDrawList.PushClipRectFullScreen = lib.ImDrawList_PushClipRectFullScreen
ImDrawList.PushDrawFlag = lib.ImDrawList_PushDrawFlag
ImDrawList.PushTexture = lib.ImDrawList_PushTexture
ImDrawList._AddLine = lib.ImDrawList__AddLine
ImDrawList._AddPolyline = lib.ImDrawList__AddPolyline
ImDrawList._AddRectBaked = lib.ImDrawList__AddRectBaked
ImDrawList._AddRectFilledBaked = lib.ImDrawList__AddRectFilledBaked
ImDrawList._AddRectTinyRounding = lib.ImDrawList__AddRectTinyRounding
ImDrawList._CalcCircleAutoSegmentCount = lib.ImDrawList__CalcCircleAutoSegmentCount
ImDrawList._CalculateCenterBiasedOffset = lib.ImDrawList__CalculateCenterBiasedOffset
ImDrawList._ClearFreeMemory = lib.ImDrawList__ClearFreeMemory
ImDrawList._OnChangedClipRect = lib.ImDrawList__OnChangedClipRect
ImDrawList._OnChangedTexture = lib.ImDrawList__OnChangedTexture
ImDrawList._OnChangedVtxOffset = lib.ImDrawList__OnChangedVtxOffset
ImDrawList._PathArcToFastEx = lib.ImDrawList__PathArcToFastEx
ImDrawList._PathArcToN = lib.ImDrawList__PathArcToN
ImDrawList._PopUnusedDrawCmd = lib.ImDrawList__PopUnusedDrawCmd
ImDrawList._ResetForNewFrame = lib.ImDrawList__ResetForNewFrame
ImDrawList._SelectLineTexture = lib.ImDrawList__SelectLineTexture
ImDrawList._SetDrawListSharedData = lib.ImDrawList__SetDrawListSharedData
ImDrawList._SetPixelDensity = lib.ImDrawList__SetPixelDensity
ImDrawList._SetTexture = lib.ImDrawList__SetTexture
ImDrawList._TryMergeDrawCmds = lib.ImDrawList__TryMergeDrawCmds
M.ImDrawList = ffi.metatype("ImDrawList",ImDrawList)
--------------------------ImDrawListSharedData----------------------------
local ImDrawListSharedData= {}
ImDrawListSharedData.__index = ImDrawListSharedData
function ImDrawListSharedData.__new(ctype)
    local ptr = lib.ImDrawListSharedData_ImDrawListSharedData()
    return ffi.gc(ptr,lib.ImDrawListSharedData_destroy)
end
ImDrawListSharedData.SetCircleTessellationMaxError = lib.ImDrawListSharedData_SetCircleTessellationMaxError
M.ImDrawListSharedData = ffi.metatype("ImDrawListSharedData",ImDrawListSharedData)
--------------------------ImDrawListSplitter----------------------------
local ImDrawListSplitter= {}
ImDrawListSplitter.__index = ImDrawListSplitter
ImDrawListSplitter.Clear = lib.ImDrawListSplitter_Clear
ImDrawListSplitter.ClearFreeMemory = lib.ImDrawListSplitter_ClearFreeMemory
function ImDrawListSplitter.__new(ctype)
    local ptr = lib.ImDrawListSplitter_ImDrawListSplitter()
    return ffi.gc(ptr,lib.ImDrawListSplitter_destroy)
end
ImDrawListSplitter.Merge = lib.ImDrawListSplitter_Merge
ImDrawListSplitter.SetCurrentChannel = lib.ImDrawListSplitter_SetCurrentChannel
ImDrawListSplitter.Split = lib.ImDrawListSplitter_Split
M.ImDrawListSplitter = ffi.metatype("ImDrawListSplitter",ImDrawListSplitter)
--------------------------ImFont----------------------------
local ImFont= {}
ImFont.__index = ImFont
ImFont.AddRemapCodepoint = lib.ImFont_AddRemapCodepoint
ImFont.AddRemapCodepointToGlyphIndex = lib.ImFont_AddRemapCodepointToGlyphIndex
function ImFont:CalcTextSizeA(size,max_width,wrap_width,text_begin,text_end,out_remaining)
    out_remaining = out_remaining or nil
    text_end = text_end or nil
    return lib.ImFont_CalcTextSizeA(self,size,max_width,wrap_width,text_begin,text_end,out_remaining)
end
ImFont.CalcWordWrapPosition = lib.ImFont_CalcWordWrapPosition
ImFont.ClearOutputData = lib.ImFont_ClearOutputData
ImFont.GetDebugName = lib.ImFont_GetDebugName
function ImFont:GetFontBaked(font_size,density)
    density = density or -1.0
    return lib.ImFont_GetFontBaked(self,font_size,density)
end
function ImFont.__new(ctype)
    local ptr = lib.ImFont_ImFont()
    return ffi.gc(ptr,lib.ImFont_destroy)
end
ImFont.IsGlyphInFont = lib.ImFont_IsGlyphInFont
ImFont.IsGlyphRangeUnused = lib.ImFont_IsGlyphRangeUnused
ImFont.IsLoaded = lib.ImFont_IsLoaded
function ImFont:RenderChar(draw_list,size,pos,col,c,cpu_fine_clip)
    cpu_fine_clip = cpu_fine_clip or nil
    return lib.ImFont_RenderChar(self,draw_list,size,pos,col,c,cpu_fine_clip)
end
function ImFont:RenderText(draw_list,size,pos,col,clip_rect,text_begin,text_end,wrap_width,flags)
    flags = flags or 0
    wrap_width = wrap_width or 0.0
    return lib.ImFont_RenderText(self,draw_list,size,pos,col,clip_rect,text_begin,text_end,wrap_width,flags)
end
M.ImFont = ffi.metatype("ImFont",ImFont)
--------------------------ImFontAtlas----------------------------
local ImFontAtlas= {}
ImFontAtlas.__index = ImFontAtlas
function ImFontAtlas:AddCustomRect(width,height,out_r)
    out_r = out_r or nil
    return lib.ImFontAtlas_AddCustomRect(self,width,height,out_r)
end
ImFontAtlas.AddFont = lib.ImFontAtlas_AddFont
function ImFontAtlas:AddFontDefault(font_cfg)
    font_cfg = font_cfg or nil
    return lib.ImFontAtlas_AddFontDefault(self,font_cfg)
end
function ImFontAtlas:AddFontDefaultBitmap(font_cfg)
    font_cfg = font_cfg or nil
    return lib.ImFontAtlas_AddFontDefaultBitmap(self,font_cfg)
end
function ImFontAtlas:AddFontDefaultVector(font_cfg)
    font_cfg = font_cfg or nil
    return lib.ImFontAtlas_AddFontDefaultVector(self,font_cfg)
end
function ImFontAtlas:AddFontFromFileTTF(filename,size_pixels,font_cfg,glyph_ranges)
    font_cfg = font_cfg or nil
    glyph_ranges = glyph_ranges or nil
    size_pixels = size_pixels or 0.0
    return lib.ImFontAtlas_AddFontFromFileTTF(self,filename,size_pixels,font_cfg,glyph_ranges)
end
function ImFontAtlas:AddFontFromMemoryCompressedBase85TTF(compressed_font_data_base85,size_pixels,font_cfg,glyph_ranges)
    font_cfg = font_cfg or nil
    glyph_ranges = glyph_ranges or nil
    size_pixels = size_pixels or 0.0
    return lib.ImFontAtlas_AddFontFromMemoryCompressedBase85TTF(self,compressed_font_data_base85,size_pixels,font_cfg,glyph_ranges)
end
function ImFontAtlas:AddFontFromMemoryCompressedTTF(compressed_font_data,compressed_font_data_size,size_pixels,font_cfg,glyph_ranges)
    font_cfg = font_cfg or nil
    glyph_ranges = glyph_ranges or nil
    size_pixels = size_pixels or 0.0
    return lib.ImFontAtlas_AddFontFromMemoryCompressedTTF(self,compressed_font_data,compressed_font_data_size,size_pixels,font_cfg,glyph_ranges)
end
function ImFontAtlas:AddFontFromMemoryTTF(font_data,font_data_size,size_pixels,font_cfg,glyph_ranges)
    font_cfg = font_cfg or nil
    glyph_ranges = glyph_ranges or nil
    size_pixels = size_pixels or 0.0
    return lib.ImFontAtlas_AddFontFromMemoryTTF(self,font_data,font_data_size,size_pixels,font_cfg,glyph_ranges)
end
ImFontAtlas.Clear = lib.ImFontAtlas_Clear
ImFontAtlas.ClearFonts = lib.ImFontAtlas_ClearFonts
ImFontAtlas.ClearInputData = lib.ImFontAtlas_ClearInputData
ImFontAtlas.ClearTexData = lib.ImFontAtlas_ClearTexData
ImFontAtlas.CompactCache = lib.ImFontAtlas_CompactCache
ImFontAtlas.GetCustomRect = lib.ImFontAtlas_GetCustomRect
ImFontAtlas.GetGlyphRangesDefault = lib.ImFontAtlas_GetGlyphRangesDefault
function ImFontAtlas.__new(ctype)
    local ptr = lib.ImFontAtlas_ImFontAtlas()
    return ffi.gc(ptr,lib.ImFontAtlas_destroy)
end
ImFontAtlas.RemoveCustomRect = lib.ImFontAtlas_RemoveCustomRect
ImFontAtlas.RemoveFont = lib.ImFontAtlas_RemoveFont
ImFontAtlas.SetFontLoader = lib.ImFontAtlas_SetFontLoader
M.ImFontAtlas = ffi.metatype("ImFontAtlas",ImFontAtlas)
--------------------------ImFontAtlasBuilder----------------------------
local ImFontAtlasBuilder= {}
ImFontAtlasBuilder.__index = ImFontAtlasBuilder
function ImFontAtlasBuilder.__new(ctype)
    local ptr = lib.ImFontAtlasBuilder_ImFontAtlasBuilder()
    return ffi.gc(ptr,lib.ImFontAtlasBuilder_destroy)
end
M.ImFontAtlasBuilder = ffi.metatype("ImFontAtlasBuilder",ImFontAtlasBuilder)
--------------------------ImFontAtlasRect----------------------------
local ImFontAtlasRect= {}
ImFontAtlasRect.__index = ImFontAtlasRect
function ImFontAtlasRect.__new(ctype)
    local ptr = lib.ImFontAtlasRect_ImFontAtlasRect()
    return ffi.gc(ptr,lib.ImFontAtlasRect_destroy)
end
M.ImFontAtlasRect = ffi.metatype("ImFontAtlasRect",ImFontAtlasRect)
--------------------------ImFontBaked----------------------------
local ImFontBaked= {}
ImFontBaked.__index = ImFontBaked
ImFontBaked.ClearOutputData = lib.ImFontBaked_ClearOutputData
ImFontBaked.FindGlyph = lib.ImFontBaked_FindGlyph
ImFontBaked.FindGlyphNoFallback = lib.ImFontBaked_FindGlyphNoFallback
ImFontBaked.GetCharAdvance = lib.ImFontBaked_GetCharAdvance
function ImFontBaked.__new(ctype)
    local ptr = lib.ImFontBaked_ImFontBaked()
    return ffi.gc(ptr,lib.ImFontBaked_destroy)
end
ImFontBaked.IsGlyphLoaded = lib.ImFontBaked_IsGlyphLoaded
M.ImFontBaked = ffi.metatype("ImFontBaked",ImFontBaked)
--------------------------ImFontConfig----------------------------
local ImFontConfig= {}
ImFontConfig.__index = ImFontConfig
function ImFontConfig.__new(ctype)
    local ptr = lib.ImFontConfig_ImFontConfig()
    return ffi.gc(ptr,lib.ImFontConfig_destroy)
end
M.ImFontConfig = ffi.metatype("ImFontConfig",ImFontConfig)
--------------------------ImFontGlyph----------------------------
local ImFontGlyph= {}
ImFontGlyph.__index = ImFontGlyph
function ImFontGlyph.__new(ctype)
    local ptr = lib.ImFontGlyph_ImFontGlyph()
    return ffi.gc(ptr,lib.ImFontGlyph_destroy)
end
M.ImFontGlyph = ffi.metatype("ImFontGlyph",ImFontGlyph)
--------------------------ImFontGlyphRangesBuilder----------------------------
local ImFontGlyphRangesBuilder= {}
ImFontGlyphRangesBuilder.__index = ImFontGlyphRangesBuilder
ImFontGlyphRangesBuilder.AddChar = lib.ImFontGlyphRangesBuilder_AddChar
ImFontGlyphRangesBuilder.AddRanges = lib.ImFontGlyphRangesBuilder_AddRanges
function ImFontGlyphRangesBuilder:AddText(text,text_end)
    text_end = text_end or nil
    return lib.ImFontGlyphRangesBuilder_AddText(self,text,text_end)
end
ImFontGlyphRangesBuilder.BuildRanges = lib.ImFontGlyphRangesBuilder_BuildRanges
ImFontGlyphRangesBuilder.Clear = lib.ImFontGlyphRangesBuilder_Clear
ImFontGlyphRangesBuilder.GetBit = lib.ImFontGlyphRangesBuilder_GetBit
function ImFontGlyphRangesBuilder.__new(ctype)
    local ptr = lib.ImFontGlyphRangesBuilder_ImFontGlyphRangesBuilder()
    return ffi.gc(ptr,lib.ImFontGlyphRangesBuilder_destroy)
end
ImFontGlyphRangesBuilder.SetBit = lib.ImFontGlyphRangesBuilder_SetBit
M.ImFontGlyphRangesBuilder = ffi.metatype("ImFontGlyphRangesBuilder",ImFontGlyphRangesBuilder)
--------------------------ImFontLoader----------------------------
local ImFontLoader= {}
ImFontLoader.__index = ImFontLoader
function ImFontLoader.__new(ctype)
    local ptr = lib.ImFontLoader_ImFontLoader()
    return ffi.gc(ptr,lib.ImFontLoader_destroy)
end
M.ImFontLoader = ffi.metatype("ImFontLoader",ImFontLoader)
--------------------------ImGuiBoxSelectState----------------------------
local ImGuiBoxSelectState= {}
ImGuiBoxSelectState.__index = ImGuiBoxSelectState
function ImGuiBoxSelectState.__new(ctype)
    local ptr = lib.ImGuiBoxSelectState_ImGuiBoxSelectState()
    return ffi.gc(ptr,lib.ImGuiBoxSelectState_destroy)
end
M.ImGuiBoxSelectState = ffi.metatype("ImGuiBoxSelectState",ImGuiBoxSelectState)
--------------------------ImGuiComboPreviewData----------------------------
local ImGuiComboPreviewData= {}
ImGuiComboPreviewData.__index = ImGuiComboPreviewData
function ImGuiComboPreviewData.__new(ctype)
    local ptr = lib.ImGuiComboPreviewData_ImGuiComboPreviewData()
    return ffi.gc(ptr,lib.ImGuiComboPreviewData_destroy)
end
M.ImGuiComboPreviewData = ffi.metatype("ImGuiComboPreviewData",ImGuiComboPreviewData)
--------------------------ImGuiContext----------------------------
local ImGuiContext= {}
ImGuiContext.__index = ImGuiContext
function ImGuiContext.__new(ctype,shared_font_atlas)
    local ptr = lib.ImGuiContext_ImGuiContext(shared_font_atlas)
    return ffi.gc(ptr,lib.ImGuiContext_destroy)
end
M.ImGuiContext = ffi.metatype("ImGuiContext",ImGuiContext)
--------------------------ImGuiContextHook----------------------------
local ImGuiContextHook= {}
ImGuiContextHook.__index = ImGuiContextHook
function ImGuiContextHook.__new(ctype)
    local ptr = lib.ImGuiContextHook_ImGuiContextHook()
    return ffi.gc(ptr,lib.ImGuiContextHook_destroy)
end
M.ImGuiContextHook = ffi.metatype("ImGuiContextHook",ImGuiContextHook)
--------------------------ImGuiDebugAllocInfo----------------------------
local ImGuiDebugAllocInfo= {}
ImGuiDebugAllocInfo.__index = ImGuiDebugAllocInfo
function ImGuiDebugAllocInfo.__new(ctype)
    local ptr = lib.ImGuiDebugAllocInfo_ImGuiDebugAllocInfo()
    return ffi.gc(ptr,lib.ImGuiDebugAllocInfo_destroy)
end
M.ImGuiDebugAllocInfo = ffi.metatype("ImGuiDebugAllocInfo",ImGuiDebugAllocInfo)
--------------------------ImGuiDebugItemPathQuery----------------------------
local ImGuiDebugItemPathQuery= {}
ImGuiDebugItemPathQuery.__index = ImGuiDebugItemPathQuery
function ImGuiDebugItemPathQuery.__new(ctype)
    local ptr = lib.ImGuiDebugItemPathQuery_ImGuiDebugItemPathQuery()
    return ffi.gc(ptr,lib.ImGuiDebugItemPathQuery_destroy)
end
M.ImGuiDebugItemPathQuery = ffi.metatype("ImGuiDebugItemPathQuery",ImGuiDebugItemPathQuery)
--------------------------ImGuiDockContext----------------------------
local ImGuiDockContext= {}
ImGuiDockContext.__index = ImGuiDockContext
function ImGuiDockContext.__new(ctype)
    local ptr = lib.ImGuiDockContext_ImGuiDockContext()
    return ffi.gc(ptr,lib.ImGuiDockContext_destroy)
end
M.ImGuiDockContext = ffi.metatype("ImGuiDockContext",ImGuiDockContext)
--------------------------ImGuiDockNode----------------------------
local ImGuiDockNode= {}
ImGuiDockNode.__index = ImGuiDockNode
function ImGuiDockNode.__new(ctype,id)
    local ptr = lib.ImGuiDockNode_ImGuiDockNode(id)
    return ffi.gc(ptr,lib.ImGuiDockNode_destroy)
end
ImGuiDockNode.IsCentralNode = lib.ImGuiDockNode_IsCentralNode
ImGuiDockNode.IsDockSpace = lib.ImGuiDockNode_IsDockSpace
ImGuiDockNode.IsEmpty = lib.ImGuiDockNode_IsEmpty
ImGuiDockNode.IsFloatingNode = lib.ImGuiDockNode_IsFloatingNode
ImGuiDockNode.IsHiddenTabBar = lib.ImGuiDockNode_IsHiddenTabBar
ImGuiDockNode.IsLeafNode = lib.ImGuiDockNode_IsLeafNode
ImGuiDockNode.IsNoTabBar = lib.ImGuiDockNode_IsNoTabBar
ImGuiDockNode.IsRootNode = lib.ImGuiDockNode_IsRootNode
ImGuiDockNode.IsSplitNode = lib.ImGuiDockNode_IsSplitNode
ImGuiDockNode.Rect = lib.ImGuiDockNode_Rect
ImGuiDockNode.SetLocalFlags = lib.ImGuiDockNode_SetLocalFlags
ImGuiDockNode.UpdateMergedFlags = lib.ImGuiDockNode_UpdateMergedFlags
M.ImGuiDockNode = ffi.metatype("ImGuiDockNode",ImGuiDockNode)
--------------------------ImGuiErrorRecoveryState----------------------------
local ImGuiErrorRecoveryState= {}
ImGuiErrorRecoveryState.__index = ImGuiErrorRecoveryState
function ImGuiErrorRecoveryState.__new(ctype)
    local ptr = lib.ImGuiErrorRecoveryState_ImGuiErrorRecoveryState()
    return ffi.gc(ptr,lib.ImGuiErrorRecoveryState_destroy)
end
M.ImGuiErrorRecoveryState = ffi.metatype("ImGuiErrorRecoveryState",ImGuiErrorRecoveryState)
--------------------------ImGuiIDStackTool----------------------------
local ImGuiIDStackTool= {}
ImGuiIDStackTool.__index = ImGuiIDStackTool
function ImGuiIDStackTool.__new(ctype)
    local ptr = lib.ImGuiIDStackTool_ImGuiIDStackTool()
    return ffi.gc(ptr,lib.ImGuiIDStackTool_destroy)
end
M.ImGuiIDStackTool = ffi.metatype("ImGuiIDStackTool",ImGuiIDStackTool)
--------------------------ImGuiIO----------------------------
local ImGuiIO= {}
ImGuiIO.__index = ImGuiIO
ImGuiIO.AddFocusEvent = lib.ImGuiIO_AddFocusEvent
ImGuiIO.AddInputCharacter = lib.ImGuiIO_AddInputCharacter
ImGuiIO.AddInputCharacterUTF16 = lib.ImGuiIO_AddInputCharacterUTF16
ImGuiIO.AddInputCharactersUTF8 = lib.ImGuiIO_AddInputCharactersUTF8
ImGuiIO.AddKeyAnalogEvent = lib.ImGuiIO_AddKeyAnalogEvent
ImGuiIO.AddKeyEvent = lib.ImGuiIO_AddKeyEvent
ImGuiIO.AddMouseButtonEvent = lib.ImGuiIO_AddMouseButtonEvent
ImGuiIO.AddMousePosEvent = lib.ImGuiIO_AddMousePosEvent
ImGuiIO.AddMouseSourceEvent = lib.ImGuiIO_AddMouseSourceEvent
ImGuiIO.AddMouseViewportEvent = lib.ImGuiIO_AddMouseViewportEvent
ImGuiIO.AddMouseWheelEvent = lib.ImGuiIO_AddMouseWheelEvent
ImGuiIO.ClearEventsQueue = lib.ImGuiIO_ClearEventsQueue
ImGuiIO.ClearInputKeys = lib.ImGuiIO_ClearInputKeys
ImGuiIO.ClearInputMouse = lib.ImGuiIO_ClearInputMouse
function ImGuiIO.__new(ctype)
    local ptr = lib.ImGuiIO_ImGuiIO()
    return ffi.gc(ptr,lib.ImGuiIO_destroy)
end
ImGuiIO.SetAppAcceptingEvents = lib.ImGuiIO_SetAppAcceptingEvents
function ImGuiIO:SetKeyEventNativeData(key,native_keycode,native_scancode,native_legacy_index)
    native_legacy_index = native_legacy_index or -1
    return lib.ImGuiIO_SetKeyEventNativeData(self,key,native_keycode,native_scancode,native_legacy_index)
end
M.ImGuiIO = ffi.metatype("ImGuiIO",ImGuiIO)
--------------------------ImGuiInputEvent----------------------------
local ImGuiInputEvent= {}
ImGuiInputEvent.__index = ImGuiInputEvent
function ImGuiInputEvent.__new(ctype)
    local ptr = lib.ImGuiInputEvent_ImGuiInputEvent()
    return ffi.gc(ptr,lib.ImGuiInputEvent_destroy)
end
M.ImGuiInputEvent = ffi.metatype("ImGuiInputEvent",ImGuiInputEvent)
--------------------------ImGuiInputTextCallbackData----------------------------
local ImGuiInputTextCallbackData= {}
ImGuiInputTextCallbackData.__index = ImGuiInputTextCallbackData
ImGuiInputTextCallbackData.ClearSelection = lib.ImGuiInputTextCallbackData_ClearSelection
ImGuiInputTextCallbackData.DeleteChars = lib.ImGuiInputTextCallbackData_DeleteChars
ImGuiInputTextCallbackData.HasSelection = lib.ImGuiInputTextCallbackData_HasSelection
function ImGuiInputTextCallbackData.__new(ctype)
    local ptr = lib.ImGuiInputTextCallbackData_ImGuiInputTextCallbackData()
    return ffi.gc(ptr,lib.ImGuiInputTextCallbackData_destroy)
end
function ImGuiInputTextCallbackData:InsertChars(pos,text,text_end)
    text_end = text_end or nil
    return lib.ImGuiInputTextCallbackData_InsertChars(self,pos,text,text_end)
end
ImGuiInputTextCallbackData.SelectAll = lib.ImGuiInputTextCallbackData_SelectAll
ImGuiInputTextCallbackData.SetSelection = lib.ImGuiInputTextCallbackData_SetSelection
M.ImGuiInputTextCallbackData = ffi.metatype("ImGuiInputTextCallbackData",ImGuiInputTextCallbackData)
--------------------------ImGuiInputTextDeactivatedState----------------------------
local ImGuiInputTextDeactivatedState= {}
ImGuiInputTextDeactivatedState.__index = ImGuiInputTextDeactivatedState
ImGuiInputTextDeactivatedState.ClearFreeMemory = lib.ImGuiInputTextDeactivatedState_ClearFreeMemory
function ImGuiInputTextDeactivatedState.__new(ctype)
    local ptr = lib.ImGuiInputTextDeactivatedState_ImGuiInputTextDeactivatedState()
    return ffi.gc(ptr,lib.ImGuiInputTextDeactivatedState_destroy)
end
M.ImGuiInputTextDeactivatedState = ffi.metatype("ImGuiInputTextDeactivatedState",ImGuiInputTextDeactivatedState)
--------------------------ImGuiInputTextState----------------------------
local ImGuiInputTextState= {}
ImGuiInputTextState.__index = ImGuiInputTextState
ImGuiInputTextState.ClearFreeMemory = lib.ImGuiInputTextState_ClearFreeMemory
ImGuiInputTextState.ClearSelection = lib.ImGuiInputTextState_ClearSelection
ImGuiInputTextState.ClearText = lib.ImGuiInputTextState_ClearText
ImGuiInputTextState.CursorAnimReset = lib.ImGuiInputTextState_CursorAnimReset
ImGuiInputTextState.CursorClamp = lib.ImGuiInputTextState_CursorClamp
ImGuiInputTextState.GetCursorPos = lib.ImGuiInputTextState_GetCursorPos
ImGuiInputTextState.GetPreferredOffsetX = lib.ImGuiInputTextState_GetPreferredOffsetX
ImGuiInputTextState.GetSelectionEnd = lib.ImGuiInputTextState_GetSelectionEnd
ImGuiInputTextState.GetSelectionStart = lib.ImGuiInputTextState_GetSelectionStart
ImGuiInputTextState.GetText = lib.ImGuiInputTextState_GetText
ImGuiInputTextState.HasSelection = lib.ImGuiInputTextState_HasSelection
function ImGuiInputTextState.__new(ctype)
    local ptr = lib.ImGuiInputTextState_ImGuiInputTextState()
    return ffi.gc(ptr,lib.ImGuiInputTextState_destroy)
end
ImGuiInputTextState.OnCharPressed = lib.ImGuiInputTextState_OnCharPressed
ImGuiInputTextState.OnKeyPressed = lib.ImGuiInputTextState_OnKeyPressed
ImGuiInputTextState.ReloadUserBufAndKeepSelection = lib.ImGuiInputTextState_ReloadUserBufAndKeepSelection
ImGuiInputTextState.ReloadUserBufAndMoveToEnd = lib.ImGuiInputTextState_ReloadUserBufAndMoveToEnd
ImGuiInputTextState.ReloadUserBufAndSelectAll = lib.ImGuiInputTextState_ReloadUserBufAndSelectAll
ImGuiInputTextState.SelectAll = lib.ImGuiInputTextState_SelectAll
ImGuiInputTextState.SetSelection = lib.ImGuiInputTextState_SetSelection
M.ImGuiInputTextState = ffi.metatype("ImGuiInputTextState",ImGuiInputTextState)
--------------------------ImGuiKeyOwnerData----------------------------
local ImGuiKeyOwnerData= {}
ImGuiKeyOwnerData.__index = ImGuiKeyOwnerData
function ImGuiKeyOwnerData.__new(ctype)
    local ptr = lib.ImGuiKeyOwnerData_ImGuiKeyOwnerData()
    return ffi.gc(ptr,lib.ImGuiKeyOwnerData_destroy)
end
M.ImGuiKeyOwnerData = ffi.metatype("ImGuiKeyOwnerData",ImGuiKeyOwnerData)
--------------------------ImGuiKeyRoutingData----------------------------
local ImGuiKeyRoutingData= {}
ImGuiKeyRoutingData.__index = ImGuiKeyRoutingData
function ImGuiKeyRoutingData.__new(ctype)
    local ptr = lib.ImGuiKeyRoutingData_ImGuiKeyRoutingData()
    return ffi.gc(ptr,lib.ImGuiKeyRoutingData_destroy)
end
M.ImGuiKeyRoutingData = ffi.metatype("ImGuiKeyRoutingData",ImGuiKeyRoutingData)
--------------------------ImGuiKeyRoutingTable----------------------------
local ImGuiKeyRoutingTable= {}
ImGuiKeyRoutingTable.__index = ImGuiKeyRoutingTable
ImGuiKeyRoutingTable.Clear = lib.ImGuiKeyRoutingTable_Clear
function ImGuiKeyRoutingTable.__new(ctype)
    local ptr = lib.ImGuiKeyRoutingTable_ImGuiKeyRoutingTable()
    return ffi.gc(ptr,lib.ImGuiKeyRoutingTable_destroy)
end
M.ImGuiKeyRoutingTable = ffi.metatype("ImGuiKeyRoutingTable",ImGuiKeyRoutingTable)
--------------------------ImGuiLastItemData----------------------------
local ImGuiLastItemData= {}
ImGuiLastItemData.__index = ImGuiLastItemData
function ImGuiLastItemData.__new(ctype)
    local ptr = lib.ImGuiLastItemData_ImGuiLastItemData()
    return ffi.gc(ptr,lib.ImGuiLastItemData_destroy)
end
M.ImGuiLastItemData = ffi.metatype("ImGuiLastItemData",ImGuiLastItemData)
--------------------------ImGuiListClipper----------------------------
local ImGuiListClipper= {}
ImGuiListClipper.__index = ImGuiListClipper
function ImGuiListClipper:Begin(items_count,items_height)
    items_height = items_height or -1.0
    return lib.ImGuiListClipper_Begin(self,items_count,items_height)
end
ImGuiListClipper.End = lib.ImGuiListClipper_End
function ImGuiListClipper.__new(ctype)
    local ptr = lib.ImGuiListClipper_ImGuiListClipper()
    return ffi.gc(ptr,lib.ImGuiListClipper_destroy)
end
ImGuiListClipper.IncludeItemByIndex = lib.ImGuiListClipper_IncludeItemByIndex
ImGuiListClipper.IncludeItemsByIndex = lib.ImGuiListClipper_IncludeItemsByIndex
ImGuiListClipper.SeekCursorForItem = lib.ImGuiListClipper_SeekCursorForItem
ImGuiListClipper.Step = lib.ImGuiListClipper_Step
M.ImGuiListClipper = ffi.metatype("ImGuiListClipper",ImGuiListClipper)
--------------------------ImGuiListClipperData----------------------------
local ImGuiListClipperData= {}
ImGuiListClipperData.__index = ImGuiListClipperData
function ImGuiListClipperData.__new(ctype)
    local ptr = lib.ImGuiListClipperData_ImGuiListClipperData()
    return ffi.gc(ptr,lib.ImGuiListClipperData_destroy)
end
ImGuiListClipperData.Reset = lib.ImGuiListClipperData_Reset
M.ImGuiListClipperData = ffi.metatype("ImGuiListClipperData",ImGuiListClipperData)
--------------------------ImGuiListClipperRange----------------------------
local ImGuiListClipperRange= {}
ImGuiListClipperRange.__index = ImGuiListClipperRange
M.ImGuiListClipperRange_FromIndices = lib.ImGuiListClipperRange_FromIndices
M.ImGuiListClipperRange_FromPositions = lib.ImGuiListClipperRange_FromPositions
M.ImGuiListClipperRange = ffi.metatype("ImGuiListClipperRange",ImGuiListClipperRange)
--------------------------ImGuiMenuColumns----------------------------
local ImGuiMenuColumns= {}
ImGuiMenuColumns.__index = ImGuiMenuColumns
ImGuiMenuColumns.CalcNextTotalWidth = lib.ImGuiMenuColumns_CalcNextTotalWidth
ImGuiMenuColumns.DeclColumns = lib.ImGuiMenuColumns_DeclColumns
function ImGuiMenuColumns.__new(ctype)
    local ptr = lib.ImGuiMenuColumns_ImGuiMenuColumns()
    return ffi.gc(ptr,lib.ImGuiMenuColumns_destroy)
end
ImGuiMenuColumns.Update = lib.ImGuiMenuColumns_Update
M.ImGuiMenuColumns = ffi.metatype("ImGuiMenuColumns",ImGuiMenuColumns)
--------------------------ImGuiMultiSelectState----------------------------
local ImGuiMultiSelectState= {}
ImGuiMultiSelectState.__index = ImGuiMultiSelectState
function ImGuiMultiSelectState.__new(ctype)
    local ptr = lib.ImGuiMultiSelectState_ImGuiMultiSelectState()
    return ffi.gc(ptr,lib.ImGuiMultiSelectState_destroy)
end
M.ImGuiMultiSelectState = ffi.metatype("ImGuiMultiSelectState",ImGuiMultiSelectState)
--------------------------ImGuiMultiSelectTempData----------------------------
local ImGuiMultiSelectTempData= {}
ImGuiMultiSelectTempData.__index = ImGuiMultiSelectTempData
ImGuiMultiSelectTempData.Clear = lib.ImGuiMultiSelectTempData_Clear
ImGuiMultiSelectTempData.ClearIO = lib.ImGuiMultiSelectTempData_ClearIO
function ImGuiMultiSelectTempData.__new(ctype)
    local ptr = lib.ImGuiMultiSelectTempData_ImGuiMultiSelectTempData()
    return ffi.gc(ptr,lib.ImGuiMultiSelectTempData_destroy)
end
M.ImGuiMultiSelectTempData = ffi.metatype("ImGuiMultiSelectTempData",ImGuiMultiSelectTempData)
--------------------------ImGuiNavItemData----------------------------
local ImGuiNavItemData= {}
ImGuiNavItemData.__index = ImGuiNavItemData
ImGuiNavItemData.Clear = lib.ImGuiNavItemData_Clear
function ImGuiNavItemData.__new(ctype)
    local ptr = lib.ImGuiNavItemData_ImGuiNavItemData()
    return ffi.gc(ptr,lib.ImGuiNavItemData_destroy)
end
M.ImGuiNavItemData = ffi.metatype("ImGuiNavItemData",ImGuiNavItemData)
--------------------------ImGuiNextItemData----------------------------
local ImGuiNextItemData= {}
ImGuiNextItemData.__index = ImGuiNextItemData
ImGuiNextItemData.ClearFlags = lib.ImGuiNextItemData_ClearFlags
function ImGuiNextItemData.__new(ctype)
    local ptr = lib.ImGuiNextItemData_ImGuiNextItemData()
    return ffi.gc(ptr,lib.ImGuiNextItemData_destroy)
end
M.ImGuiNextItemData = ffi.metatype("ImGuiNextItemData",ImGuiNextItemData)
--------------------------ImGuiNextWindowData----------------------------
local ImGuiNextWindowData= {}
ImGuiNextWindowData.__index = ImGuiNextWindowData
ImGuiNextWindowData.ClearFlags = lib.ImGuiNextWindowData_ClearFlags
function ImGuiNextWindowData.__new(ctype)
    local ptr = lib.ImGuiNextWindowData_ImGuiNextWindowData()
    return ffi.gc(ptr,lib.ImGuiNextWindowData_destroy)
end
M.ImGuiNextWindowData = ffi.metatype("ImGuiNextWindowData",ImGuiNextWindowData)
--------------------------ImGuiOldColumnData----------------------------
local ImGuiOldColumnData= {}
ImGuiOldColumnData.__index = ImGuiOldColumnData
function ImGuiOldColumnData.__new(ctype)
    local ptr = lib.ImGuiOldColumnData_ImGuiOldColumnData()
    return ffi.gc(ptr,lib.ImGuiOldColumnData_destroy)
end
M.ImGuiOldColumnData = ffi.metatype("ImGuiOldColumnData",ImGuiOldColumnData)
--------------------------ImGuiOldColumns----------------------------
local ImGuiOldColumns= {}
ImGuiOldColumns.__index = ImGuiOldColumns
function ImGuiOldColumns.__new(ctype)
    local ptr = lib.ImGuiOldColumns_ImGuiOldColumns()
    return ffi.gc(ptr,lib.ImGuiOldColumns_destroy)
end
M.ImGuiOldColumns = ffi.metatype("ImGuiOldColumns",ImGuiOldColumns)
--------------------------ImGuiOnceUponAFrame----------------------------
local ImGuiOnceUponAFrame= {}
ImGuiOnceUponAFrame.__index = ImGuiOnceUponAFrame
function ImGuiOnceUponAFrame.__new(ctype)
    local ptr = lib.ImGuiOnceUponAFrame_ImGuiOnceUponAFrame()
    return ffi.gc(ptr,lib.ImGuiOnceUponAFrame_destroy)
end
M.ImGuiOnceUponAFrame = ffi.metatype("ImGuiOnceUponAFrame",ImGuiOnceUponAFrame)
--------------------------ImGuiPackedDate----------------------------
local ImGuiPackedDate= {}
ImGuiPackedDate.__index = ImGuiPackedDate
function ImGuiPackedDate.ImGuiPackedDate_Nil()
    local ptr = lib.ImGuiPackedDate_ImGuiPackedDate_Nil()
    return ffi.gc(ptr,lib.ImGuiPackedDate_destroy)
end
function ImGuiPackedDate.ImGuiPackedDate_Int(yyyymmdd)
    local ptr = lib.ImGuiPackedDate_ImGuiPackedDate_Int(yyyymmdd)
    return ffi.gc(ptr,lib.ImGuiPackedDate_destroy)
end
function ImGuiPackedDate.__new(ctype,a1) -- generic version
    if a1==nil then return ImGuiPackedDate.ImGuiPackedDate_Nil() end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return ImGuiPackedDate.ImGuiPackedDate_Int(a1) end
    print(ctype,a1)
    error'ImGuiPackedDate.__new could not find overloaded'
end
ImGuiPackedDate.IsValid = lib.ImGuiPackedDate_IsValid
ImGuiPackedDate.SubtractMonths = lib.ImGuiPackedDate_SubtractMonths
ImGuiPackedDate.Unpack = lib.ImGuiPackedDate_Unpack
M.ImGuiPackedDate = ffi.metatype("ImGuiPackedDate",ImGuiPackedDate)
--------------------------ImGuiPayload----------------------------
local ImGuiPayload= {}
ImGuiPayload.__index = ImGuiPayload
ImGuiPayload.Clear = lib.ImGuiPayload_Clear
function ImGuiPayload.__new(ctype)
    local ptr = lib.ImGuiPayload_ImGuiPayload()
    return ffi.gc(ptr,lib.ImGuiPayload_destroy)
end
ImGuiPayload.IsDataType = lib.ImGuiPayload_IsDataType
ImGuiPayload.IsDelivery = lib.ImGuiPayload_IsDelivery
ImGuiPayload.IsPreview = lib.ImGuiPayload_IsPreview
M.ImGuiPayload = ffi.metatype("ImGuiPayload",ImGuiPayload)
--------------------------ImGuiPlatformIO----------------------------
local ImGuiPlatformIO= {}
ImGuiPlatformIO.__index = ImGuiPlatformIO
ImGuiPlatformIO.ClearPlatformHandlers = lib.ImGuiPlatformIO_ClearPlatformHandlers
ImGuiPlatformIO.ClearRendererHandlers = lib.ImGuiPlatformIO_ClearRendererHandlers
function ImGuiPlatformIO.__new(ctype)
    local ptr = lib.ImGuiPlatformIO_ImGuiPlatformIO()
    return ffi.gc(ptr,lib.ImGuiPlatformIO_destroy)
end
M.ImGuiPlatformIO = ffi.metatype("ImGuiPlatformIO",ImGuiPlatformIO)
--------------------------ImGuiPlatformImeData----------------------------
local ImGuiPlatformImeData= {}
ImGuiPlatformImeData.__index = ImGuiPlatformImeData
function ImGuiPlatformImeData.__new(ctype)
    local ptr = lib.ImGuiPlatformImeData_ImGuiPlatformImeData()
    return ffi.gc(ptr,lib.ImGuiPlatformImeData_destroy)
end
M.ImGuiPlatformImeData = ffi.metatype("ImGuiPlatformImeData",ImGuiPlatformImeData)
--------------------------ImGuiPlatformMonitor----------------------------
local ImGuiPlatformMonitor= {}
ImGuiPlatformMonitor.__index = ImGuiPlatformMonitor
function ImGuiPlatformMonitor.__new(ctype)
    local ptr = lib.ImGuiPlatformMonitor_ImGuiPlatformMonitor()
    return ffi.gc(ptr,lib.ImGuiPlatformMonitor_destroy)
end
M.ImGuiPlatformMonitor = ffi.metatype("ImGuiPlatformMonitor",ImGuiPlatformMonitor)
--------------------------ImGuiPopupData----------------------------
local ImGuiPopupData= {}
ImGuiPopupData.__index = ImGuiPopupData
function ImGuiPopupData.__new(ctype)
    local ptr = lib.ImGuiPopupData_ImGuiPopupData()
    return ffi.gc(ptr,lib.ImGuiPopupData_destroy)
end
M.ImGuiPopupData = ffi.metatype("ImGuiPopupData",ImGuiPopupData)
--------------------------ImGuiPtrOrIndex----------------------------
local ImGuiPtrOrIndex= {}
ImGuiPtrOrIndex.__index = ImGuiPtrOrIndex
function ImGuiPtrOrIndex.ImGuiPtrOrIndex_Ptr(ptr)
    local ptr = lib.ImGuiPtrOrIndex_ImGuiPtrOrIndex_Ptr(ptr)
    return ffi.gc(ptr,lib.ImGuiPtrOrIndex_destroy)
end
function ImGuiPtrOrIndex.ImGuiPtrOrIndex_Int(index)
    local ptr = lib.ImGuiPtrOrIndex_ImGuiPtrOrIndex_Int(index)
    return ffi.gc(ptr,lib.ImGuiPtrOrIndex_destroy)
end
function ImGuiPtrOrIndex.__new(ctype,a1) -- generic version
    if ffi.istype('void *',a1) then return ImGuiPtrOrIndex.ImGuiPtrOrIndex_Ptr(a1) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return ImGuiPtrOrIndex.ImGuiPtrOrIndex_Int(a1) end
    print(ctype,a1)
    error'ImGuiPtrOrIndex.__new could not find overloaded'
end
M.ImGuiPtrOrIndex = ffi.metatype("ImGuiPtrOrIndex",ImGuiPtrOrIndex)
--------------------------ImGuiSelectionBasicStorage----------------------------
local ImGuiSelectionBasicStorage= {}
ImGuiSelectionBasicStorage.__index = ImGuiSelectionBasicStorage
ImGuiSelectionBasicStorage.ApplyRequests = lib.ImGuiSelectionBasicStorage_ApplyRequests
ImGuiSelectionBasicStorage.Clear = lib.ImGuiSelectionBasicStorage_Clear
ImGuiSelectionBasicStorage.Contains = lib.ImGuiSelectionBasicStorage_Contains
ImGuiSelectionBasicStorage.GetNextSelectedItem = lib.ImGuiSelectionBasicStorage_GetNextSelectedItem
ImGuiSelectionBasicStorage.GetStorageIdFromIndex = lib.ImGuiSelectionBasicStorage_GetStorageIdFromIndex
function ImGuiSelectionBasicStorage.__new(ctype)
    local ptr = lib.ImGuiSelectionBasicStorage_ImGuiSelectionBasicStorage()
    return ffi.gc(ptr,lib.ImGuiSelectionBasicStorage_destroy)
end
ImGuiSelectionBasicStorage.SetItemSelected = lib.ImGuiSelectionBasicStorage_SetItemSelected
ImGuiSelectionBasicStorage.Swap = lib.ImGuiSelectionBasicStorage_Swap
M.ImGuiSelectionBasicStorage = ffi.metatype("ImGuiSelectionBasicStorage",ImGuiSelectionBasicStorage)
--------------------------ImGuiSelectionExternalStorage----------------------------
local ImGuiSelectionExternalStorage= {}
ImGuiSelectionExternalStorage.__index = ImGuiSelectionExternalStorage
ImGuiSelectionExternalStorage.ApplyRequests = lib.ImGuiSelectionExternalStorage_ApplyRequests
function ImGuiSelectionExternalStorage.__new(ctype)
    local ptr = lib.ImGuiSelectionExternalStorage_ImGuiSelectionExternalStorage()
    return ffi.gc(ptr,lib.ImGuiSelectionExternalStorage_destroy)
end
M.ImGuiSelectionExternalStorage = ffi.metatype("ImGuiSelectionExternalStorage",ImGuiSelectionExternalStorage)
--------------------------ImGuiSettingsHandler----------------------------
local ImGuiSettingsHandler= {}
ImGuiSettingsHandler.__index = ImGuiSettingsHandler
function ImGuiSettingsHandler.__new(ctype)
    local ptr = lib.ImGuiSettingsHandler_ImGuiSettingsHandler()
    return ffi.gc(ptr,lib.ImGuiSettingsHandler_destroy)
end
M.ImGuiSettingsHandler = ffi.metatype("ImGuiSettingsHandler",ImGuiSettingsHandler)
--------------------------ImGuiStackLevelInfo----------------------------
local ImGuiStackLevelInfo= {}
ImGuiStackLevelInfo.__index = ImGuiStackLevelInfo
function ImGuiStackLevelInfo.__new(ctype)
    local ptr = lib.ImGuiStackLevelInfo_ImGuiStackLevelInfo()
    return ffi.gc(ptr,lib.ImGuiStackLevelInfo_destroy)
end
M.ImGuiStackLevelInfo = ffi.metatype("ImGuiStackLevelInfo",ImGuiStackLevelInfo)
--------------------------ImGuiStorage----------------------------
local ImGuiStorage= {}
ImGuiStorage.__index = ImGuiStorage
ImGuiStorage.BuildSortByKey = lib.ImGuiStorage_BuildSortByKey
ImGuiStorage.Clear = lib.ImGuiStorage_Clear
function ImGuiStorage:GetBool(key,default_val)
    default_val = default_val or false
    return lib.ImGuiStorage_GetBool(self,key,default_val)
end
function ImGuiStorage:GetBoolRef(key,default_val)
    default_val = default_val or false
    return lib.ImGuiStorage_GetBoolRef(self,key,default_val)
end
function ImGuiStorage:GetFloat(key,default_val)
    default_val = default_val or 0.0
    return lib.ImGuiStorage_GetFloat(self,key,default_val)
end
function ImGuiStorage:GetFloatRef(key,default_val)
    default_val = default_val or 0.0
    return lib.ImGuiStorage_GetFloatRef(self,key,default_val)
end
function ImGuiStorage:GetInt(key,default_val)
    default_val = default_val or 0
    return lib.ImGuiStorage_GetInt(self,key,default_val)
end
function ImGuiStorage:GetIntRef(key,default_val)
    default_val = default_val or 0
    return lib.ImGuiStorage_GetIntRef(self,key,default_val)
end
ImGuiStorage.GetVoidPtr = lib.ImGuiStorage_GetVoidPtr
function ImGuiStorage:GetVoidPtrRef(key,default_val)
    default_val = default_val or nil
    return lib.ImGuiStorage_GetVoidPtrRef(self,key,default_val)
end
ImGuiStorage.SetAllInt = lib.ImGuiStorage_SetAllInt
ImGuiStorage.SetBool = lib.ImGuiStorage_SetBool
ImGuiStorage.SetFloat = lib.ImGuiStorage_SetFloat
ImGuiStorage.SetInt = lib.ImGuiStorage_SetInt
ImGuiStorage.SetVoidPtr = lib.ImGuiStorage_SetVoidPtr
M.ImGuiStorage = ffi.metatype("ImGuiStorage",ImGuiStorage)
--------------------------ImGuiStoragePair----------------------------
local ImGuiStoragePair= {}
ImGuiStoragePair.__index = ImGuiStoragePair
function ImGuiStoragePair.ImGuiStoragePair_Int(_key,_val)
    local ptr = lib.ImGuiStoragePair_ImGuiStoragePair_Int(_key,_val)
    return ffi.gc(ptr,lib.ImGuiStoragePair_destroy)
end
function ImGuiStoragePair.ImGuiStoragePair_Float(_key,_val)
    local ptr = lib.ImGuiStoragePair_ImGuiStoragePair_Float(_key,_val)
    return ffi.gc(ptr,lib.ImGuiStoragePair_destroy)
end
function ImGuiStoragePair.ImGuiStoragePair_Ptr(_key,_val)
    local ptr = lib.ImGuiStoragePair_ImGuiStoragePair_Ptr(_key,_val)
    return ffi.gc(ptr,lib.ImGuiStoragePair_destroy)
end
function ImGuiStoragePair.__new(ctype,a1,a2) -- generic version
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return ImGuiStoragePair.ImGuiStoragePair_Int(a1,a2) end
    if (ffi.istype('float',a2) or type(a2)=='number') then return ImGuiStoragePair.ImGuiStoragePair_Float(a1,a2) end
    if ffi.istype('void *',a2) then return ImGuiStoragePair.ImGuiStoragePair_Ptr(a1,a2) end
    print(ctype,a1,a2)
    error'ImGuiStoragePair.__new could not find overloaded'
end
M.ImGuiStoragePair = ffi.metatype("ImGuiStoragePair",ImGuiStoragePair)
--------------------------ImGuiStyle----------------------------
local ImGuiStyle= {}
ImGuiStyle.__index = ImGuiStyle
function ImGuiStyle.__new(ctype)
    local ptr = lib.ImGuiStyle_ImGuiStyle()
    return ffi.gc(ptr,lib.ImGuiStyle_destroy)
end
ImGuiStyle.ScaleAllSizes = lib.ImGuiStyle_ScaleAllSizes
M.ImGuiStyle = ffi.metatype("ImGuiStyle",ImGuiStyle)
--------------------------ImGuiStyleMod----------------------------
local ImGuiStyleMod= {}
ImGuiStyleMod.__index = ImGuiStyleMod
function ImGuiStyleMod.ImGuiStyleMod_Int(idx,v)
    local ptr = lib.ImGuiStyleMod_ImGuiStyleMod_Int(idx,v)
    return ffi.gc(ptr,lib.ImGuiStyleMod_destroy)
end
function ImGuiStyleMod.ImGuiStyleMod_Float(idx,v)
    local ptr = lib.ImGuiStyleMod_ImGuiStyleMod_Float(idx,v)
    return ffi.gc(ptr,lib.ImGuiStyleMod_destroy)
end
function ImGuiStyleMod.ImGuiStyleMod_Vec2(idx,v)
    local ptr = lib.ImGuiStyleMod_ImGuiStyleMod_Vec2(idx,v)
    return ffi.gc(ptr,lib.ImGuiStyleMod_destroy)
end
function ImGuiStyleMod.__new(ctype,a1,a2) -- generic version
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return ImGuiStyleMod.ImGuiStyleMod_Int(a1,a2) end
    if (ffi.istype('float',a2) or type(a2)=='number') then return ImGuiStyleMod.ImGuiStyleMod_Float(a1,a2) end
    if ffi.istype('ImVec2',a2) then return ImGuiStyleMod.ImGuiStyleMod_Vec2(a1,a2) end
    print(ctype,a1,a2)
    error'ImGuiStyleMod.__new could not find overloaded'
end
M.ImGuiStyleMod = ffi.metatype("ImGuiStyleMod",ImGuiStyleMod)
--------------------------ImGuiStyleVarInfo----------------------------
local ImGuiStyleVarInfo= {}
ImGuiStyleVarInfo.__index = ImGuiStyleVarInfo
ImGuiStyleVarInfo.GetVarPtr = lib.ImGuiStyleVarInfo_GetVarPtr
M.ImGuiStyleVarInfo = ffi.metatype("ImGuiStyleVarInfo",ImGuiStyleVarInfo)
--------------------------ImGuiTabBar----------------------------
local ImGuiTabBar= {}
ImGuiTabBar.__index = ImGuiTabBar
function ImGuiTabBar.__new(ctype)
    local ptr = lib.ImGuiTabBar_ImGuiTabBar()
    return ffi.gc(ptr,lib.ImGuiTabBar_destroy)
end
M.ImGuiTabBar = ffi.metatype("ImGuiTabBar",ImGuiTabBar)
--------------------------ImGuiTabItem----------------------------
local ImGuiTabItem= {}
ImGuiTabItem.__index = ImGuiTabItem
function ImGuiTabItem.__new(ctype)
    local ptr = lib.ImGuiTabItem_ImGuiTabItem()
    return ffi.gc(ptr,lib.ImGuiTabItem_destroy)
end
M.ImGuiTabItem = ffi.metatype("ImGuiTabItem",ImGuiTabItem)
--------------------------ImGuiTable----------------------------
local ImGuiTable= {}
ImGuiTable.__index = ImGuiTable
function ImGuiTable.__new(ctype)
    local ptr = lib.ImGuiTable_ImGuiTable()
    return ffi.gc(ptr,lib.ImGuiTable_destroy)
end
M.ImGuiTable = ffi.metatype("ImGuiTable",ImGuiTable)
--------------------------ImGuiTableColumn----------------------------
local ImGuiTableColumn= {}
ImGuiTableColumn.__index = ImGuiTableColumn
function ImGuiTableColumn.__new(ctype)
    local ptr = lib.ImGuiTableColumn_ImGuiTableColumn()
    return ffi.gc(ptr,lib.ImGuiTableColumn_destroy)
end
M.ImGuiTableColumn = ffi.metatype("ImGuiTableColumn",ImGuiTableColumn)
--------------------------ImGuiTableColumnSettings----------------------------
local ImGuiTableColumnSettings= {}
ImGuiTableColumnSettings.__index = ImGuiTableColumnSettings
function ImGuiTableColumnSettings.__new(ctype)
    local ptr = lib.ImGuiTableColumnSettings_ImGuiTableColumnSettings()
    return ffi.gc(ptr,lib.ImGuiTableColumnSettings_destroy)
end
M.ImGuiTableColumnSettings = ffi.metatype("ImGuiTableColumnSettings",ImGuiTableColumnSettings)
--------------------------ImGuiTableColumnSortSpecs----------------------------
local ImGuiTableColumnSortSpecs= {}
ImGuiTableColumnSortSpecs.__index = ImGuiTableColumnSortSpecs
function ImGuiTableColumnSortSpecs.__new(ctype)
    local ptr = lib.ImGuiTableColumnSortSpecs_ImGuiTableColumnSortSpecs()
    return ffi.gc(ptr,lib.ImGuiTableColumnSortSpecs_destroy)
end
M.ImGuiTableColumnSortSpecs = ffi.metatype("ImGuiTableColumnSortSpecs",ImGuiTableColumnSortSpecs)
--------------------------ImGuiTableInstanceData----------------------------
local ImGuiTableInstanceData= {}
ImGuiTableInstanceData.__index = ImGuiTableInstanceData
function ImGuiTableInstanceData.__new(ctype)
    local ptr = lib.ImGuiTableInstanceData_ImGuiTableInstanceData()
    return ffi.gc(ptr,lib.ImGuiTableInstanceData_destroy)
end
M.ImGuiTableInstanceData = ffi.metatype("ImGuiTableInstanceData",ImGuiTableInstanceData)
--------------------------ImGuiTableSettings----------------------------
local ImGuiTableSettings= {}
ImGuiTableSettings.__index = ImGuiTableSettings
ImGuiTableSettings.GetColumnSettings = lib.ImGuiTableSettings_GetColumnSettings
function ImGuiTableSettings.__new(ctype)
    local ptr = lib.ImGuiTableSettings_ImGuiTableSettings()
    return ffi.gc(ptr,lib.ImGuiTableSettings_destroy)
end
M.ImGuiTableSettings = ffi.metatype("ImGuiTableSettings",ImGuiTableSettings)
--------------------------ImGuiTableSortSpecs----------------------------
local ImGuiTableSortSpecs= {}
ImGuiTableSortSpecs.__index = ImGuiTableSortSpecs
function ImGuiTableSortSpecs.__new(ctype)
    local ptr = lib.ImGuiTableSortSpecs_ImGuiTableSortSpecs()
    return ffi.gc(ptr,lib.ImGuiTableSortSpecs_destroy)
end
M.ImGuiTableSortSpecs = ffi.metatype("ImGuiTableSortSpecs",ImGuiTableSortSpecs)
--------------------------ImGuiTableTempData----------------------------
local ImGuiTableTempData= {}
ImGuiTableTempData.__index = ImGuiTableTempData
function ImGuiTableTempData.__new(ctype)
    local ptr = lib.ImGuiTableTempData_ImGuiTableTempData()
    return ffi.gc(ptr,lib.ImGuiTableTempData_destroy)
end
M.ImGuiTableTempData = ffi.metatype("ImGuiTableTempData",ImGuiTableTempData)
--------------------------ImGuiTextBuffer----------------------------
local ImGuiTextBuffer= {}
ImGuiTextBuffer.__index = ImGuiTextBuffer
function ImGuiTextBuffer.__new(ctype)
    local ptr = lib.ImGuiTextBuffer_ImGuiTextBuffer()
    return ffi.gc(ptr,lib.ImGuiTextBuffer_destroy)
end
function ImGuiTextBuffer:append(str,str_end)
    str_end = str_end or nil
    return lib.ImGuiTextBuffer_append(self,str,str_end)
end
ImGuiTextBuffer.appendf = lib.ImGuiTextBuffer_appendf
ImGuiTextBuffer.appendfv = lib.ImGuiTextBuffer_appendfv
ImGuiTextBuffer.begin = lib.ImGuiTextBuffer_begin
ImGuiTextBuffer.c_str = lib.ImGuiTextBuffer_c_str
ImGuiTextBuffer.clear = lib.ImGuiTextBuffer_clear
ImGuiTextBuffer.empty = lib.ImGuiTextBuffer_empty
ImGuiTextBuffer._end = lib.ImGuiTextBuffer_end
ImGuiTextBuffer.reserve = lib.ImGuiTextBuffer_reserve
ImGuiTextBuffer.resize = lib.ImGuiTextBuffer_resize
ImGuiTextBuffer.size = lib.ImGuiTextBuffer_size
M.ImGuiTextBuffer = ffi.metatype("ImGuiTextBuffer",ImGuiTextBuffer)
--------------------------ImGuiTextFilter----------------------------
local ImGuiTextFilter= {}
ImGuiTextFilter.__index = ImGuiTextFilter
ImGuiTextFilter.Build = lib.ImGuiTextFilter_Build
ImGuiTextFilter.Clear = lib.ImGuiTextFilter_Clear
function ImGuiTextFilter:Draw(label)
    label = label or "Filter"
    return lib.ImGuiTextFilter_Draw(self,label)
end
function ImGuiTextFilter:DrawWithHint(label,hint)
    hint = hint or "incl -excl"
    label = label or "Filter"
    return lib.ImGuiTextFilter_DrawWithHint(self,label,hint)
end
function ImGuiTextFilter.__new(ctype,default_filter)
    if default_filter == nil then default_filter = "" end
    local ptr = lib.ImGuiTextFilter_ImGuiTextFilter(default_filter)
    return ffi.gc(ptr,lib.ImGuiTextFilter_destroy)
end
ImGuiTextFilter.IsActive = lib.ImGuiTextFilter_IsActive
function ImGuiTextFilter:PassFilter(text,text_end)
    text_end = text_end or nil
    return lib.ImGuiTextFilter_PassFilter(self,text,text_end)
end
M.ImGuiTextFilter = ffi.metatype("ImGuiTextFilter",ImGuiTextFilter)
--------------------------ImGuiTextFilterItem----------------------------
local ImGuiTextFilterItem= {}
ImGuiTextFilterItem.__index = ImGuiTextFilterItem
function ImGuiTextFilterItem.__new(ctype,b,e)
    local ptr = lib.ImGuiTextFilterItem_ImGuiTextFilterItem(b,e)
    return ffi.gc(ptr,lib.ImGuiTextFilterItem_destroy)
end
M.ImGuiTextFilterItem = ffi.metatype("ImGuiTextFilterItem",ImGuiTextFilterItem)
--------------------------ImGuiTextIndex----------------------------
local ImGuiTextIndex= {}
ImGuiTextIndex.__index = ImGuiTextIndex
ImGuiTextIndex.append = lib.ImGuiTextIndex_append
ImGuiTextIndex.clear = lib.ImGuiTextIndex_clear
ImGuiTextIndex.get_line_begin = lib.ImGuiTextIndex_get_line_begin
ImGuiTextIndex.get_line_end = lib.ImGuiTextIndex_get_line_end
ImGuiTextIndex.size = lib.ImGuiTextIndex_size
M.ImGuiTextIndex = ffi.metatype("ImGuiTextIndex",ImGuiTextIndex)
--------------------------ImGuiTypingSelectState----------------------------
local ImGuiTypingSelectState= {}
ImGuiTypingSelectState.__index = ImGuiTypingSelectState
ImGuiTypingSelectState.Clear = lib.ImGuiTypingSelectState_Clear
function ImGuiTypingSelectState.__new(ctype)
    local ptr = lib.ImGuiTypingSelectState_ImGuiTypingSelectState()
    return ffi.gc(ptr,lib.ImGuiTypingSelectState_destroy)
end
M.ImGuiTypingSelectState = ffi.metatype("ImGuiTypingSelectState",ImGuiTypingSelectState)
--------------------------ImGuiViewport----------------------------
local ImGuiViewport= {}
ImGuiViewport.__index = ImGuiViewport
ImGuiViewport.GetCenter = lib.ImGuiViewport_GetCenter
ImGuiViewport.GetDebugName = lib.ImGuiViewport_GetDebugName
ImGuiViewport.GetWorkCenter = lib.ImGuiViewport_GetWorkCenter
function ImGuiViewport.__new(ctype)
    local ptr = lib.ImGuiViewport_ImGuiViewport()
    return ffi.gc(ptr,lib.ImGuiViewport_destroy)
end
M.ImGuiViewport = ffi.metatype("ImGuiViewport",ImGuiViewport)
--------------------------ImGuiViewportP----------------------------
local ImGuiViewportP= {}
ImGuiViewportP.__index = ImGuiViewportP
ImGuiViewportP.CalcWorkRectPos = lib.ImGuiViewportP_CalcWorkRectPos
ImGuiViewportP.CalcWorkRectSize = lib.ImGuiViewportP_CalcWorkRectSize
ImGuiViewportP.ClearRequestFlags = lib.ImGuiViewportP_ClearRequestFlags
ImGuiViewportP.GetBuildWorkRect = lib.ImGuiViewportP_GetBuildWorkRect
ImGuiViewportP.GetMainRect = lib.ImGuiViewportP_GetMainRect
ImGuiViewportP.GetWorkRect = lib.ImGuiViewportP_GetWorkRect
function ImGuiViewportP.__new(ctype)
    local ptr = lib.ImGuiViewportP_ImGuiViewportP()
    return ffi.gc(ptr,lib.ImGuiViewportP_destroy)
end
ImGuiViewportP.UpdateWorkRect = lib.ImGuiViewportP_UpdateWorkRect
M.ImGuiViewportP = ffi.metatype("ImGuiViewportP",ImGuiViewportP)
--------------------------ImGuiWindow----------------------------
local ImGuiWindow= {}
ImGuiWindow.__index = ImGuiWindow
function ImGuiWindow:GetID_Str(str,str_end)
    str_end = str_end or nil
    return lib.ImGuiWindow_GetID_Str(self,str,str_end)
end
ImGuiWindow.GetID_Ptr = lib.ImGuiWindow_GetID_Ptr
ImGuiWindow.GetID_Int = lib.ImGuiWindow_GetID_Int
function ImGuiWindow:GetID(a2,a3) -- generic version
    if (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return self:GetID_Str(a2,a3) end
    if ffi.istype('void *',a2) then return self:GetID_Ptr(a2) end
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return self:GetID_Int(a2) end
    print(a2,a3)
    error'ImGuiWindow:GetID could not find overloaded'
end
ImGuiWindow.GetIDFromPos = lib.ImGuiWindow_GetIDFromPos
ImGuiWindow.GetIDFromRectangle = lib.ImGuiWindow_GetIDFromRectangle
function ImGuiWindow.__new(ctype,context,name)
    local ptr = lib.ImGuiWindow_ImGuiWindow(context,name)
    return ffi.gc(ptr,lib.ImGuiWindow_destroy)
end
ImGuiWindow.MenuBarRect = lib.ImGuiWindow_MenuBarRect
ImGuiWindow.Rect = lib.ImGuiWindow_Rect
ImGuiWindow.TitleBarRect = lib.ImGuiWindow_TitleBarRect
M.ImGuiWindow = ffi.metatype("ImGuiWindow",ImGuiWindow)
--------------------------ImGuiWindowClass----------------------------
local ImGuiWindowClass= {}
ImGuiWindowClass.__index = ImGuiWindowClass
function ImGuiWindowClass.__new(ctype)
    local ptr = lib.ImGuiWindowClass_ImGuiWindowClass()
    return ffi.gc(ptr,lib.ImGuiWindowClass_destroy)
end
M.ImGuiWindowClass = ffi.metatype("ImGuiWindowClass",ImGuiWindowClass)
--------------------------ImGuiWindowSettings----------------------------
local ImGuiWindowSettings= {}
ImGuiWindowSettings.__index = ImGuiWindowSettings
ImGuiWindowSettings.GetName = lib.ImGuiWindowSettings_GetName
function ImGuiWindowSettings.__new(ctype)
    local ptr = lib.ImGuiWindowSettings_ImGuiWindowSettings()
    return ffi.gc(ptr,lib.ImGuiWindowSettings_destroy)
end
M.ImGuiWindowSettings = ffi.metatype("ImGuiWindowSettings",ImGuiWindowSettings)
--------------------------ImNodesIO----------------------------
local ImNodesIO= {}
ImNodesIO.__index = ImNodesIO
function ImNodesIO.__new(ctype)
    local ptr = lib.ImNodesIO_ImNodesIO()
    return ffi.gc(ptr,lib.ImNodesIO_destroy)
end
M.ImNodesIO = ffi.metatype("ImNodesIO",ImNodesIO)
--------------------------ImNodesStyle----------------------------
local ImNodesStyle= {}
ImNodesStyle.__index = ImNodesStyle
function ImNodesStyle.__new(ctype)
    local ptr = lib.ImNodesStyle_ImNodesStyle()
    return ffi.gc(ptr,lib.ImNodesStyle_destroy)
end
M.ImNodesStyle = ffi.metatype("ImNodesStyle",ImNodesStyle)
--------------------------ImPlot3DBox----------------------------
local ImPlot3DBox= {}
ImPlot3DBox.__index = ImPlot3DBox
ImPlot3DBox.ClipLineSegment = lib.ImPlot3DBox_ClipLineSegment
ImPlot3DBox.Contains = lib.ImPlot3DBox_Contains
ImPlot3DBox.Expand = lib.ImPlot3DBox_Expand
function ImPlot3DBox.ImPlot3DBox_Nil()
    local ptr = lib.ImPlot3DBox_ImPlot3DBox_Nil()
    return ffi.gc(ptr,lib.ImPlot3DBox_destroy)
end
function ImPlot3DBox.ImPlot3DBox_Plot3DPoint(min,max)
    local ptr = lib.ImPlot3DBox_ImPlot3DBox_Plot3DPoint(min,max)
    return ffi.gc(ptr,lib.ImPlot3DBox_destroy)
end
function ImPlot3DBox.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImPlot3DBox.ImPlot3DBox_Nil() end
    if ffi.istype('const ImPlot3DPoint',a1) then return ImPlot3DBox.ImPlot3DBox_Plot3DPoint(a1,a2) end
    print(ctype,a1,a2)
    error'ImPlot3DBox.__new could not find overloaded'
end
M.ImPlot3DBox = ffi.metatype("ImPlot3DBox",ImPlot3DBox)
--------------------------ImPlot3DPoint----------------------------
local ImPlot3DPoint= {}
ImPlot3DPoint.__index = ImPlot3DPoint
ImPlot3DPoint.Cross = lib.ImPlot3DPoint_Cross
ImPlot3DPoint.Dot = lib.ImPlot3DPoint_Dot
function ImPlot3DPoint.ImPlot3DPoint_Nil()
    local ptr = lib.ImPlot3DPoint_ImPlot3DPoint_Nil()
    return ffi.gc(ptr,lib.ImPlot3DPoint_destroy)
end
function ImPlot3DPoint.ImPlot3DPoint_double(_x,_y,_z)
    local ptr = lib.ImPlot3DPoint_ImPlot3DPoint_double(_x,_y,_z)
    return ffi.gc(ptr,lib.ImPlot3DPoint_destroy)
end
function ImPlot3DPoint.__new(ctype,a1,a2,a3) -- generic version
    if a1==nil then return ImPlot3DPoint.ImPlot3DPoint_Nil() end
    if (ffi.istype('double',a1) or type(a1)=='number') then return ImPlot3DPoint.ImPlot3DPoint_double(a1,a2,a3) end
    print(ctype,a1,a2,a3)
    error'ImPlot3DPoint.__new could not find overloaded'
end
ImPlot3DPoint.IsNaN = lib.ImPlot3DPoint_IsNaN
ImPlot3DPoint.Length = lib.ImPlot3DPoint_Length
ImPlot3DPoint.LengthSquared = lib.ImPlot3DPoint_LengthSquared
ImPlot3DPoint.Normalize = lib.ImPlot3DPoint_Normalize
ImPlot3DPoint.Normalized = lib.ImPlot3DPoint_Normalized
M.ImPlot3DPoint = ffi.metatype("ImPlot3DPoint",ImPlot3DPoint)
--------------------------ImPlot3DQuat----------------------------
local ImPlot3DQuat= {}
ImPlot3DQuat.__index = ImPlot3DQuat
ImPlot3DQuat.Conjugate = lib.ImPlot3DQuat_Conjugate
ImPlot3DQuat.Dot = lib.ImPlot3DQuat_Dot
M.ImPlot3DQuat_FromElAz = lib.ImPlot3DQuat_FromElAz
M.ImPlot3DQuat_FromTwoVectors = lib.ImPlot3DQuat_FromTwoVectors
function ImPlot3DQuat.ImPlot3DQuat_Nil()
    local ptr = lib.ImPlot3DQuat_ImPlot3DQuat_Nil()
    return ffi.gc(ptr,lib.ImPlot3DQuat_destroy)
end
function ImPlot3DQuat.ImPlot3DQuat_doubledouble(_x,_y,_z,_w)
    local ptr = lib.ImPlot3DQuat_ImPlot3DQuat_doubledouble(_x,_y,_z,_w)
    return ffi.gc(ptr,lib.ImPlot3DQuat_destroy)
end
function ImPlot3DQuat.ImPlot3DQuat_doublePlot3DPoint(_angle,_axis)
    local ptr = lib.ImPlot3DQuat_ImPlot3DQuat_doublePlot3DPoint(_angle,_axis)
    return ffi.gc(ptr,lib.ImPlot3DQuat_destroy)
end
function ImPlot3DQuat.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImPlot3DQuat.ImPlot3DQuat_Nil() end
    if (ffi.istype('double',a1) or type(a1)=='number') and (ffi.istype('double',a2) or type(a2)=='number') then return ImPlot3DQuat.ImPlot3DQuat_doubledouble(a1,a2,a3,a4) end
    if (ffi.istype('double',a1) or type(a1)=='number') and ffi.istype('const ImPlot3DPoint',a2) then return ImPlot3DQuat.ImPlot3DQuat_doublePlot3DPoint(a1,a2) end
    print(ctype,a1,a2,a3,a4)
    error'ImPlot3DQuat.__new could not find overloaded'
end
ImPlot3DQuat.Inverse = lib.ImPlot3DQuat_Inverse
ImPlot3DQuat.Length = lib.ImPlot3DQuat_Length
ImPlot3DQuat.Normalize = lib.ImPlot3DQuat_Normalize
ImPlot3DQuat.Normalized = lib.ImPlot3DQuat_Normalized
M.ImPlot3DQuat_Slerp = lib.ImPlot3DQuat_Slerp
M.ImPlot3DQuat = ffi.metatype("ImPlot3DQuat",ImPlot3DQuat)
--------------------------ImPlot3DRange----------------------------
local ImPlot3DRange= {}
ImPlot3DRange.__index = ImPlot3DRange
ImPlot3DRange.Contains = lib.ImPlot3DRange_Contains
ImPlot3DRange.Expand = lib.ImPlot3DRange_Expand
function ImPlot3DRange.ImPlot3DRange_Nil()
    local ptr = lib.ImPlot3DRange_ImPlot3DRange_Nil()
    return ffi.gc(ptr,lib.ImPlot3DRange_destroy)
end
function ImPlot3DRange.ImPlot3DRange_double(min,max)
    local ptr = lib.ImPlot3DRange_ImPlot3DRange_double(min,max)
    return ffi.gc(ptr,lib.ImPlot3DRange_destroy)
end
function ImPlot3DRange.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImPlot3DRange.ImPlot3DRange_Nil() end
    if (ffi.istype('double',a1) or type(a1)=='number') then return ImPlot3DRange.ImPlot3DRange_double(a1,a2) end
    print(ctype,a1,a2)
    error'ImPlot3DRange.__new could not find overloaded'
end
ImPlot3DRange.Size = lib.ImPlot3DRange_Size
M.ImPlot3DRange = ffi.metatype("ImPlot3DRange",ImPlot3DRange)
--------------------------ImPlot3DSpec----------------------------
local ImPlot3DSpec= {}
ImPlot3DSpec.__index = ImPlot3DSpec
function ImPlot3DSpec.__new(ctype)
    local ptr = lib.ImPlot3DSpec_ImPlot3DSpec()
    return ffi.gc(ptr,lib.ImPlot3DSpec_destroy)
end
ImPlot3DSpec.SetProp_Float = lib.ImPlot3DSpec_SetProp_Float
ImPlot3DSpec.SetProp_double = lib.ImPlot3DSpec_SetProp_double
ImPlot3DSpec.SetProp_S8 = lib.ImPlot3DSpec_SetProp_S8
ImPlot3DSpec.SetProp_U8 = lib.ImPlot3DSpec_SetProp_U8
ImPlot3DSpec.SetProp_S16 = lib.ImPlot3DSpec_SetProp_S16
ImPlot3DSpec.SetProp_U16 = lib.ImPlot3DSpec_SetProp_U16
ImPlot3DSpec.SetProp_S32 = lib.ImPlot3DSpec_SetProp_S32
ImPlot3DSpec.SetProp_U32 = lib.ImPlot3DSpec_SetProp_U32
ImPlot3DSpec.SetProp_S64 = lib.ImPlot3DSpec_SetProp_S64
ImPlot3DSpec.SetProp_U64 = lib.ImPlot3DSpec_SetProp_U64
ImPlot3DSpec.SetProp_U32Ptr = lib.ImPlot3DSpec_SetProp_U32Ptr
ImPlot3DSpec.SetProp_FloatPtr = lib.ImPlot3DSpec_SetProp_FloatPtr
ImPlot3DSpec.SetProp_Vec4 = lib.ImPlot3DSpec_SetProp_Vec4
function ImPlot3DSpec:SetProp(a2,a3) -- generic version
    if (ffi.istype('float',a3) or type(a3)=='number') then return self:SetProp_Float(a2,a3) end
    if (ffi.istype('double',a3) or type(a3)=='number') then return self:SetProp_double(a2,a3) end
    if (ffi.istype('int8_t',a3) or type(a3)=='number') then return self:SetProp_S8(a2,a3) end
    if (ffi.istype('uint8_t',a3) or type(a3)=='number') then return self:SetProp_U8(a2,a3) end
    if (ffi.istype('int16_t',a3) or type(a3)=='number') then return self:SetProp_S16(a2,a3) end
    if (ffi.istype('uint16_t',a3) or type(a3)=='number') then return self:SetProp_U16(a2,a3) end
    if (ffi.istype('int32_t',a3) or type(a3)=='number') then return self:SetProp_S32(a2,a3) end
    if (ffi.istype('uint32_t',a3) or type(a3)=='number') then return self:SetProp_U32(a2,a3) end
    if (ffi.istype('int64_t',a3) or type(a3)=='number') then return self:SetProp_S64(a2,a3) end
    if (ffi.istype('uint64_t',a3) or type(a3)=='number') then return self:SetProp_U64(a2,a3) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) then return self:SetProp_U32Ptr(a2,a3) end
    if (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) then return self:SetProp_FloatPtr(a2,a3) end
    if ffi.istype('const ImVec4',a3) then return self:SetProp_Vec4(a2,a3) end
    print(a2,a3)
    error'ImPlot3DSpec:SetProp could not find overloaded'
end
M.ImPlot3DSpec = ffi.metatype("ImPlot3DSpec",ImPlot3DSpec)
--------------------------ImPlot3DStyle----------------------------
local ImPlot3DStyle= {}
ImPlot3DStyle.__index = ImPlot3DStyle
ImPlot3DStyle.GetColor = lib.ImPlot3DStyle_GetColor
function ImPlot3DStyle.ImPlot3DStyle_Nil()
    local ptr = lib.ImPlot3DStyle_ImPlot3DStyle_Nil()
    return ffi.gc(ptr,lib.ImPlot3DStyle_destroy)
end
function ImPlot3DStyle.ImPlot3DStyle_Plot3DStyle(other)
    local ptr = lib.ImPlot3DStyle_ImPlot3DStyle_Plot3DStyle(other)
    return ffi.gc(ptr,lib.ImPlot3DStyle_destroy)
end
function ImPlot3DStyle.__new(ctype,a1) -- generic version
    if a1==nil then return ImPlot3DStyle.ImPlot3DStyle_Nil() end
    if ffi.istype('const ImPlot3DStyle',a1) then return ImPlot3DStyle.ImPlot3DStyle_Plot3DStyle(a1) end
    print(ctype,a1)
    error'ImPlot3DStyle.__new could not find overloaded'
end
ImPlot3DStyle.SetColor = lib.ImPlot3DStyle_SetColor
M.ImPlot3DStyle = ffi.metatype("ImPlot3DStyle",ImPlot3DStyle)
--------------------------ImPlotAlignmentData----------------------------
local ImPlotAlignmentData= {}
ImPlotAlignmentData.__index = ImPlotAlignmentData
ImPlotAlignmentData.Begin = lib.ImPlotAlignmentData_Begin
ImPlotAlignmentData.End = lib.ImPlotAlignmentData_End
function ImPlotAlignmentData.__new(ctype)
    local ptr = lib.ImPlotAlignmentData_ImPlotAlignmentData()
    return ffi.gc(ptr,lib.ImPlotAlignmentData_destroy)
end
ImPlotAlignmentData.Reset = lib.ImPlotAlignmentData_Reset
ImPlotAlignmentData.Update = lib.ImPlotAlignmentData_Update
M.ImPlotAlignmentData = ffi.metatype("ImPlotAlignmentData",ImPlotAlignmentData)
--------------------------ImPlotAnnotation----------------------------
local ImPlotAnnotation= {}
ImPlotAnnotation.__index = ImPlotAnnotation
function ImPlotAnnotation.__new(ctype)
    local ptr = lib.ImPlotAnnotation_ImPlotAnnotation()
    return ffi.gc(ptr,lib.ImPlotAnnotation_destroy)
end
M.ImPlotAnnotation = ffi.metatype("ImPlotAnnotation",ImPlotAnnotation)
--------------------------ImPlotAnnotationCollection----------------------------
local ImPlotAnnotationCollection= {}
ImPlotAnnotationCollection.__index = ImPlotAnnotationCollection
ImPlotAnnotationCollection.Append = lib.ImPlotAnnotationCollection_Append
ImPlotAnnotationCollection.AppendV = lib.ImPlotAnnotationCollection_AppendV
ImPlotAnnotationCollection.GetText = lib.ImPlotAnnotationCollection_GetText
function ImPlotAnnotationCollection.__new(ctype)
    local ptr = lib.ImPlotAnnotationCollection_ImPlotAnnotationCollection()
    return ffi.gc(ptr,lib.ImPlotAnnotationCollection_destroy)
end
ImPlotAnnotationCollection.Reset = lib.ImPlotAnnotationCollection_Reset
M.ImPlotAnnotationCollection = ffi.metatype("ImPlotAnnotationCollection",ImPlotAnnotationCollection)
--------------------------ImPlotAxis----------------------------
local ImPlotAxis= {}
ImPlotAxis.__index = ImPlotAxis
ImPlotAxis.ApplyFit = lib.ImPlotAxis_ApplyFit
ImPlotAxis.CanInitFit = lib.ImPlotAxis_CanInitFit
ImPlotAxis.Constrain = lib.ImPlotAxis_Constrain
ImPlotAxis.ExtendFit = lib.ImPlotAxis_ExtendFit
ImPlotAxis.ExtendFitWith = lib.ImPlotAxis_ExtendFitWith
ImPlotAxis.GetAspect = lib.ImPlotAxis_GetAspect
ImPlotAxis.HasGridLines = lib.ImPlotAxis_HasGridLines
ImPlotAxis.HasLabel = lib.ImPlotAxis_HasLabel
ImPlotAxis.HasMenus = lib.ImPlotAxis_HasMenus
ImPlotAxis.HasTickLabels = lib.ImPlotAxis_HasTickLabels
ImPlotAxis.HasTickLabelsInside = lib.ImPlotAxis_HasTickLabelsInside
ImPlotAxis.HasTickMarks = lib.ImPlotAxis_HasTickMarks
function ImPlotAxis.__new(ctype)
    local ptr = lib.ImPlotAxis_ImPlotAxis()
    return ffi.gc(ptr,lib.ImPlotAxis_destroy)
end
ImPlotAxis.IsAutoFitting = lib.ImPlotAxis_IsAutoFitting
ImPlotAxis.IsForeground = lib.ImPlotAxis_IsForeground
ImPlotAxis.IsInputLocked = lib.ImPlotAxis_IsInputLocked
ImPlotAxis.IsInputLockedMax = lib.ImPlotAxis_IsInputLockedMax
ImPlotAxis.IsInputLockedMin = lib.ImPlotAxis_IsInputLockedMin
ImPlotAxis.IsInverted = lib.ImPlotAxis_IsInverted
ImPlotAxis.IsLocked = lib.ImPlotAxis_IsLocked
ImPlotAxis.IsLockedMax = lib.ImPlotAxis_IsLockedMax
ImPlotAxis.IsLockedMin = lib.ImPlotAxis_IsLockedMin
ImPlotAxis.IsOpposite = lib.ImPlotAxis_IsOpposite
ImPlotAxis.IsPanLocked = lib.ImPlotAxis_IsPanLocked
ImPlotAxis.IsRangeLocked = lib.ImPlotAxis_IsRangeLocked
ImPlotAxis.PixelSize = lib.ImPlotAxis_PixelSize
ImPlotAxis.PixelsToPlot = lib.ImPlotAxis_PixelsToPlot
ImPlotAxis.PlotToPixels = lib.ImPlotAxis_PlotToPixels
ImPlotAxis.PullLinks = lib.ImPlotAxis_PullLinks
ImPlotAxis.PushLinks = lib.ImPlotAxis_PushLinks
ImPlotAxis.Reset = lib.ImPlotAxis_Reset
ImPlotAxis.SetAspect = lib.ImPlotAxis_SetAspect
function ImPlotAxis:SetMax(_max,force)
    force = force or false
    return lib.ImPlotAxis_SetMax(self,_max,force)
end
function ImPlotAxis:SetMin(_min,force)
    force = force or false
    return lib.ImPlotAxis_SetMin(self,_min,force)
end
ImPlotAxis.SetRange_double = lib.ImPlotAxis_SetRange_double
ImPlotAxis.SetRange_PlotRange = lib.ImPlotAxis_SetRange_PlotRange
function ImPlotAxis:SetRange(a2,a3) -- generic version
    if (ffi.istype('double',a2) or type(a2)=='number') then return self:SetRange_double(a2,a3) end
    if ffi.istype('const ImPlotRange',a2) then return self:SetRange_PlotRange(a2) end
    print(a2,a3)
    error'ImPlotAxis:SetRange could not find overloaded'
end
ImPlotAxis.UpdateTransformCache = lib.ImPlotAxis_UpdateTransformCache
ImPlotAxis.WillRender = lib.ImPlotAxis_WillRender
M.ImPlotAxis = ffi.metatype("ImPlotAxis",ImPlotAxis)
--------------------------ImPlotColormapData----------------------------
local ImPlotColormapData= {}
ImPlotColormapData.__index = ImPlotColormapData
ImPlotColormapData.Append = lib.ImPlotColormapData_Append
ImPlotColormapData.GetIndex = lib.ImPlotColormapData_GetIndex
ImPlotColormapData.GetKeyColor = lib.ImPlotColormapData_GetKeyColor
ImPlotColormapData.GetKeyCount = lib.ImPlotColormapData_GetKeyCount
ImPlotColormapData.GetKeys = lib.ImPlotColormapData_GetKeys
ImPlotColormapData.GetName = lib.ImPlotColormapData_GetName
ImPlotColormapData.GetTable = lib.ImPlotColormapData_GetTable
ImPlotColormapData.GetTableColor = lib.ImPlotColormapData_GetTableColor
ImPlotColormapData.GetTableSize = lib.ImPlotColormapData_GetTableSize
function ImPlotColormapData.__new(ctype)
    local ptr = lib.ImPlotColormapData_ImPlotColormapData()
    return ffi.gc(ptr,lib.ImPlotColormapData_destroy)
end
ImPlotColormapData.IsQual = lib.ImPlotColormapData_IsQual
ImPlotColormapData.LerpTable = lib.ImPlotColormapData_LerpTable
ImPlotColormapData.RebuildTables = lib.ImPlotColormapData_RebuildTables
ImPlotColormapData.SetKeyColor = lib.ImPlotColormapData_SetKeyColor
ImPlotColormapData._AppendTable = lib.ImPlotColormapData__AppendTable
M.ImPlotColormapData = ffi.metatype("ImPlotColormapData",ImPlotColormapData)
--------------------------ImPlotDateTimeSpec----------------------------
local ImPlotDateTimeSpec= {}
ImPlotDateTimeSpec.__index = ImPlotDateTimeSpec
function ImPlotDateTimeSpec.ImPlotDateTimeSpec_Nil()
    local ptr = lib.ImPlotDateTimeSpec_ImPlotDateTimeSpec_Nil()
    return ffi.gc(ptr,lib.ImPlotDateTimeSpec_destroy)
end
function ImPlotDateTimeSpec.ImPlotDateTimeSpec_PlotDateFmt(date_fmt,time_fmt,use_24_hr_clk,use_iso_8601)
    if use_24_hr_clk == nil then use_24_hr_clk = false end
    if use_iso_8601 == nil then use_iso_8601 = false end
    local ptr = lib.ImPlotDateTimeSpec_ImPlotDateTimeSpec_PlotDateFmt(date_fmt,time_fmt,use_24_hr_clk,use_iso_8601)
    return ffi.gc(ptr,lib.ImPlotDateTimeSpec_destroy)
end
function ImPlotDateTimeSpec.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImPlotDateTimeSpec.ImPlotDateTimeSpec_Nil() end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return ImPlotDateTimeSpec.ImPlotDateTimeSpec_PlotDateFmt(a1,a2,a3,a4) end
    print(ctype,a1,a2,a3,a4)
    error'ImPlotDateTimeSpec.__new could not find overloaded'
end
M.ImPlotDateTimeSpec = ffi.metatype("ImPlotDateTimeSpec",ImPlotDateTimeSpec)
--------------------------ImPlotInputMap----------------------------
local ImPlotInputMap= {}
ImPlotInputMap.__index = ImPlotInputMap
function ImPlotInputMap.__new(ctype)
    local ptr = lib.ImPlotInputMap_ImPlotInputMap()
    return ffi.gc(ptr,lib.ImPlotInputMap_destroy)
end
M.ImPlotInputMap = ffi.metatype("ImPlotInputMap",ImPlotInputMap)
--------------------------ImPlotItem----------------------------
local ImPlotItem= {}
ImPlotItem.__index = ImPlotItem
function ImPlotItem.__new(ctype)
    local ptr = lib.ImPlotItem_ImPlotItem()
    return ffi.gc(ptr,lib.ImPlotItem_destroy)
end
M.ImPlotItem = ffi.metatype("ImPlotItem",ImPlotItem)
--------------------------ImPlotItemGroup----------------------------
local ImPlotItemGroup= {}
ImPlotItemGroup.__index = ImPlotItemGroup
ImPlotItemGroup.GetItem_ID = lib.ImPlotItemGroup_GetItem_ID
ImPlotItemGroup.GetItem_Str = lib.ImPlotItemGroup_GetItem_Str
function ImPlotItemGroup:GetItem(a2) -- generic version
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return self:GetItem_ID(a2) end
    if (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return self:GetItem_Str(a2) end
    print(a2)
    error'ImPlotItemGroup:GetItem could not find overloaded'
end
ImPlotItemGroup.GetItemByIndex = lib.ImPlotItemGroup_GetItemByIndex
ImPlotItemGroup.GetItemCount = lib.ImPlotItemGroup_GetItemCount
ImPlotItemGroup.GetItemID = lib.ImPlotItemGroup_GetItemID
ImPlotItemGroup.GetItemIndex = lib.ImPlotItemGroup_GetItemIndex
ImPlotItemGroup.GetLegendCount = lib.ImPlotItemGroup_GetLegendCount
ImPlotItemGroup.GetLegendItem = lib.ImPlotItemGroup_GetLegendItem
ImPlotItemGroup.GetLegendLabel = lib.ImPlotItemGroup_GetLegendLabel
ImPlotItemGroup.GetOrAddItem = lib.ImPlotItemGroup_GetOrAddItem
function ImPlotItemGroup.__new(ctype)
    local ptr = lib.ImPlotItemGroup_ImPlotItemGroup()
    return ffi.gc(ptr,lib.ImPlotItemGroup_destroy)
end
ImPlotItemGroup.Reset = lib.ImPlotItemGroup_Reset
M.ImPlotItemGroup = ffi.metatype("ImPlotItemGroup",ImPlotItemGroup)
--------------------------ImPlotLegend----------------------------
local ImPlotLegend= {}
ImPlotLegend.__index = ImPlotLegend
function ImPlotLegend.__new(ctype)
    local ptr = lib.ImPlotLegend_ImPlotLegend()
    return ffi.gc(ptr,lib.ImPlotLegend_destroy)
end
ImPlotLegend.Reset = lib.ImPlotLegend_Reset
M.ImPlotLegend = ffi.metatype("ImPlotLegend",ImPlotLegend)
--------------------------ImPlotNextItemData----------------------------
local ImPlotNextItemData= {}
ImPlotNextItemData.__index = ImPlotNextItemData
function ImPlotNextItemData.__new(ctype)
    local ptr = lib.ImPlotNextItemData_ImPlotNextItemData()
    return ffi.gc(ptr,lib.ImPlotNextItemData_destroy)
end
ImPlotNextItemData.Reset = lib.ImPlotNextItemData_Reset
M.ImPlotNextItemData = ffi.metatype("ImPlotNextItemData",ImPlotNextItemData)
--------------------------ImPlotNextPlotData----------------------------
local ImPlotNextPlotData= {}
ImPlotNextPlotData.__index = ImPlotNextPlotData
function ImPlotNextPlotData.__new(ctype)
    local ptr = lib.ImPlotNextPlotData_ImPlotNextPlotData()
    return ffi.gc(ptr,lib.ImPlotNextPlotData_destroy)
end
ImPlotNextPlotData.Reset = lib.ImPlotNextPlotData_Reset
M.ImPlotNextPlotData = ffi.metatype("ImPlotNextPlotData",ImPlotNextPlotData)
--------------------------ImPlotPlot----------------------------
local ImPlotPlot= {}
ImPlotPlot.__index = ImPlotPlot
ImPlotPlot.ClearTextBuffer = lib.ImPlotPlot_ClearTextBuffer
ImPlotPlot.EnabledAxesX = lib.ImPlotPlot_EnabledAxesX
ImPlotPlot.EnabledAxesY = lib.ImPlotPlot_EnabledAxesY
ImPlotPlot.GetAxisLabel = lib.ImPlotPlot_GetAxisLabel
ImPlotPlot.GetTitle = lib.ImPlotPlot_GetTitle
ImPlotPlot.HasTitle = lib.ImPlotPlot_HasTitle
function ImPlotPlot.__new(ctype)
    local ptr = lib.ImPlotPlot_ImPlotPlot()
    return ffi.gc(ptr,lib.ImPlotPlot_destroy)
end
ImPlotPlot.IsInputLocked = lib.ImPlotPlot_IsInputLocked
ImPlotPlot.SetAxisLabel = lib.ImPlotPlot_SetAxisLabel
ImPlotPlot.SetTitle = lib.ImPlotPlot_SetTitle
ImPlotPlot.XAxis_Nil = lib.ImPlotPlot_XAxis_Nil
ImPlotPlot.XAxis__const = lib.ImPlotPlot_XAxis__const
function ImPlotPlot:XAxis(a2) -- generic version
    do return self:XAxis_Nil(a2) end
    print(a2)
    error'ImPlotPlot:XAxis could not find overloaded'
end
ImPlotPlot.YAxis_Nil = lib.ImPlotPlot_YAxis_Nil
ImPlotPlot.YAxis__const = lib.ImPlotPlot_YAxis__const
function ImPlotPlot:YAxis(a2) -- generic version
    do return self:YAxis_Nil(a2) end
    print(a2)
    error'ImPlotPlot:YAxis could not find overloaded'
end
M.ImPlotPlot = ffi.metatype("ImPlotPlot",ImPlotPlot)
--------------------------ImPlotPoint----------------------------
local ImPlotPoint= {}
ImPlotPoint.__index = ImPlotPoint
function ImPlotPoint.ImPlotPoint_Nil()
    local ptr = lib.ImPlotPoint_ImPlotPoint_Nil()
    return ffi.gc(ptr,lib.ImPlotPoint_destroy)
end
function ImPlotPoint.ImPlotPoint_double(_x,_y)
    local ptr = lib.ImPlotPoint_ImPlotPoint_double(_x,_y)
    return ffi.gc(ptr,lib.ImPlotPoint_destroy)
end
function ImPlotPoint.ImPlotPoint_Vec2(p)
    local ptr = lib.ImPlotPoint_ImPlotPoint_Vec2(p)
    return ffi.gc(ptr,lib.ImPlotPoint_destroy)
end
function ImPlotPoint.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImPlotPoint.ImPlotPoint_Nil() end
    if (ffi.istype('double',a1) or type(a1)=='number') then return ImPlotPoint.ImPlotPoint_double(a1,a2) end
    if ffi.istype('const ImVec2',a1) then return ImPlotPoint.ImPlotPoint_Vec2(a1) end
    print(ctype,a1,a2)
    error'ImPlotPoint.__new could not find overloaded'
end
M.ImPlotPoint = ffi.metatype("ImPlotPoint",ImPlotPoint)
--------------------------ImPlotPointError----------------------------
local ImPlotPointError= {}
ImPlotPointError.__index = ImPlotPointError
function ImPlotPointError.ImPlotPointError_Nil()
    local ptr = lib.ImPlotPointError_ImPlotPointError_Nil()
    return ffi.gc(ptr,lib.ImPlotPointError_destroy)
end
function ImPlotPointError.ImPlotPointError_double(x,y,neg,pos)
    local ptr = lib.ImPlotPointError_ImPlotPointError_double(x,y,neg,pos)
    return ffi.gc(ptr,lib.ImPlotPointError_destroy)
end
function ImPlotPointError.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImPlotPointError.ImPlotPointError_Nil() end
    if (ffi.istype('double',a1) or type(a1)=='number') then return ImPlotPointError.ImPlotPointError_double(a1,a2,a3,a4) end
    print(ctype,a1,a2,a3,a4)
    error'ImPlotPointError.__new could not find overloaded'
end
M.ImPlotPointError = ffi.metatype("ImPlotPointError",ImPlotPointError)
--------------------------ImPlotRange----------------------------
local ImPlotRange= {}
ImPlotRange.__index = ImPlotRange
ImPlotRange.Clamp = lib.ImPlotRange_Clamp
ImPlotRange.Contains = lib.ImPlotRange_Contains
function ImPlotRange.ImPlotRange_Nil()
    local ptr = lib.ImPlotRange_ImPlotRange_Nil()
    return ffi.gc(ptr,lib.ImPlotRange_destroy)
end
function ImPlotRange.ImPlotRange_double(_min,_max)
    local ptr = lib.ImPlotRange_ImPlotRange_double(_min,_max)
    return ffi.gc(ptr,lib.ImPlotRange_destroy)
end
function ImPlotRange.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImPlotRange.ImPlotRange_Nil() end
    if (ffi.istype('double',a1) or type(a1)=='number') then return ImPlotRange.ImPlotRange_double(a1,a2) end
    print(ctype,a1,a2)
    error'ImPlotRange.__new could not find overloaded'
end
ImPlotRange.Size = lib.ImPlotRange_Size
M.ImPlotRange = ffi.metatype("ImPlotRange",ImPlotRange)
--------------------------ImPlotRect----------------------------
local ImPlotRect= {}
ImPlotRect.__index = ImPlotRect
ImPlotRect.Clamp_PlotPoint = lib.ImPlotRect_Clamp_PlotPoint
ImPlotRect.Clamp_double = lib.ImPlotRect_Clamp_double
function ImPlotRect:Clamp(a2,a3) -- generic version
    if ffi.istype('const ImPlotPoint',a2) then return self:Clamp_PlotPoint(a2) end
    if (ffi.istype('double',a2) or type(a2)=='number') then return self:Clamp_double(a2,a3) end
    print(a2,a3)
    error'ImPlotRect:Clamp could not find overloaded'
end
ImPlotRect.Contains_PlotPoint = lib.ImPlotRect_Contains_PlotPoint
ImPlotRect.Contains_double = lib.ImPlotRect_Contains_double
function ImPlotRect:Contains(a2,a3) -- generic version
    if ffi.istype('const ImPlotPoint',a2) then return self:Contains_PlotPoint(a2) end
    if (ffi.istype('double',a2) or type(a2)=='number') then return self:Contains_double(a2,a3) end
    print(a2,a3)
    error'ImPlotRect:Contains could not find overloaded'
end
function ImPlotRect.ImPlotRect_Nil()
    local ptr = lib.ImPlotRect_ImPlotRect_Nil()
    return ffi.gc(ptr,lib.ImPlotRect_destroy)
end
function ImPlotRect.ImPlotRect_double(x_min,x_max,y_min,y_max)
    local ptr = lib.ImPlotRect_ImPlotRect_double(x_min,x_max,y_min,y_max)
    return ffi.gc(ptr,lib.ImPlotRect_destroy)
end
function ImPlotRect.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImPlotRect.ImPlotRect_Nil() end
    if (ffi.istype('double',a1) or type(a1)=='number') then return ImPlotRect.ImPlotRect_double(a1,a2,a3,a4) end
    print(ctype,a1,a2,a3,a4)
    error'ImPlotRect.__new could not find overloaded'
end
ImPlotRect.Max = lib.ImPlotRect_Max
ImPlotRect.Min = lib.ImPlotRect_Min
ImPlotRect.Size = lib.ImPlotRect_Size
M.ImPlotRect = ffi.metatype("ImPlotRect",ImPlotRect)
--------------------------ImPlotSpec----------------------------
local ImPlotSpec= {}
ImPlotSpec.__index = ImPlotSpec
function ImPlotSpec.__new(ctype)
    local ptr = lib.ImPlotSpec_ImPlotSpec()
    return ffi.gc(ptr,lib.ImPlotSpec_destroy)
end
ImPlotSpec.SetProp_Float = lib.ImPlotSpec_SetProp_Float
ImPlotSpec.SetProp_double = lib.ImPlotSpec_SetProp_double
ImPlotSpec.SetProp_S8 = lib.ImPlotSpec_SetProp_S8
ImPlotSpec.SetProp_U8 = lib.ImPlotSpec_SetProp_U8
ImPlotSpec.SetProp_S16 = lib.ImPlotSpec_SetProp_S16
ImPlotSpec.SetProp_U16 = lib.ImPlotSpec_SetProp_U16
ImPlotSpec.SetProp_S32 = lib.ImPlotSpec_SetProp_S32
ImPlotSpec.SetProp_U32 = lib.ImPlotSpec_SetProp_U32
ImPlotSpec.SetProp_S64 = lib.ImPlotSpec_SetProp_S64
ImPlotSpec.SetProp_U64 = lib.ImPlotSpec_SetProp_U64
ImPlotSpec.SetProp_U32Ptr = lib.ImPlotSpec_SetProp_U32Ptr
ImPlotSpec.SetProp_FloatPtr = lib.ImPlotSpec_SetProp_FloatPtr
ImPlotSpec.SetProp_Vec4 = lib.ImPlotSpec_SetProp_Vec4
function ImPlotSpec:SetProp(a2,a3) -- generic version
    if (ffi.istype('float',a3) or type(a3)=='number') then return self:SetProp_Float(a2,a3) end
    if (ffi.istype('double',a3) or type(a3)=='number') then return self:SetProp_double(a2,a3) end
    if (ffi.istype('int8_t',a3) or type(a3)=='number') then return self:SetProp_S8(a2,a3) end
    if (ffi.istype('uint8_t',a3) or type(a3)=='number') then return self:SetProp_U8(a2,a3) end
    if (ffi.istype('int16_t',a3) or type(a3)=='number') then return self:SetProp_S16(a2,a3) end
    if (ffi.istype('uint16_t',a3) or type(a3)=='number') then return self:SetProp_U16(a2,a3) end
    if (ffi.istype('int32_t',a3) or type(a3)=='number') then return self:SetProp_S32(a2,a3) end
    if (ffi.istype('uint32_t',a3) or type(a3)=='number') then return self:SetProp_U32(a2,a3) end
    if (ffi.istype('int64_t',a3) or type(a3)=='number') then return self:SetProp_S64(a2,a3) end
    if (ffi.istype('uint64_t',a3) or type(a3)=='number') then return self:SetProp_U64(a2,a3) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) then return self:SetProp_U32Ptr(a2,a3) end
    if (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) then return self:SetProp_FloatPtr(a2,a3) end
    if ffi.istype('const ImVec4',a3) then return self:SetProp_Vec4(a2,a3) end
    print(a2,a3)
    error'ImPlotSpec:SetProp could not find overloaded'
end
M.ImPlotSpec = ffi.metatype("ImPlotSpec",ImPlotSpec)
--------------------------ImPlotStyle----------------------------
local ImPlotStyle= {}
ImPlotStyle.__index = ImPlotStyle
function ImPlotStyle.__new(ctype)
    local ptr = lib.ImPlotStyle_ImPlotStyle()
    return ffi.gc(ptr,lib.ImPlotStyle_destroy)
end
M.ImPlotStyle = ffi.metatype("ImPlotStyle",ImPlotStyle)
--------------------------ImPlotSubplot----------------------------
local ImPlotSubplot= {}
ImPlotSubplot.__index = ImPlotSubplot
function ImPlotSubplot.__new(ctype)
    local ptr = lib.ImPlotSubplot_ImPlotSubplot()
    return ffi.gc(ptr,lib.ImPlotSubplot_destroy)
end
M.ImPlotSubplot = ffi.metatype("ImPlotSubplot",ImPlotSubplot)
--------------------------ImPlotTag----------------------------
local ImPlotTag= {}
ImPlotTag.__index = ImPlotTag
function ImPlotTag.__new(ctype)
    local ptr = lib.ImPlotTag_ImPlotTag()
    return ffi.gc(ptr,lib.ImPlotTag_destroy)
end
M.ImPlotTag = ffi.metatype("ImPlotTag",ImPlotTag)
--------------------------ImPlotTagCollection----------------------------
local ImPlotTagCollection= {}
ImPlotTagCollection.__index = ImPlotTagCollection
ImPlotTagCollection.Append = lib.ImPlotTagCollection_Append
ImPlotTagCollection.AppendV = lib.ImPlotTagCollection_AppendV
ImPlotTagCollection.GetText = lib.ImPlotTagCollection_GetText
function ImPlotTagCollection.__new(ctype)
    local ptr = lib.ImPlotTagCollection_ImPlotTagCollection()
    return ffi.gc(ptr,lib.ImPlotTagCollection_destroy)
end
ImPlotTagCollection.Reset = lib.ImPlotTagCollection_Reset
M.ImPlotTagCollection = ffi.metatype("ImPlotTagCollection",ImPlotTagCollection)
--------------------------ImPlotTick----------------------------
local ImPlotTick= {}
ImPlotTick.__index = ImPlotTick
function ImPlotTick.ImPlotTick_Nil()
    local ptr = lib.ImPlotTick_ImPlotTick_Nil()
    return ffi.gc(ptr,lib.ImPlotTick_destroy)
end
function ImPlotTick.ImPlotTick_double(value,major,level,show_label)
    local ptr = lib.ImPlotTick_ImPlotTick_double(value,major,level,show_label)
    return ffi.gc(ptr,lib.ImPlotTick_destroy)
end
function ImPlotTick.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImPlotTick.ImPlotTick_Nil() end
    if (ffi.istype('double',a1) or type(a1)=='number') then return ImPlotTick.ImPlotTick_double(a1,a2,a3,a4) end
    print(ctype,a1,a2,a3,a4)
    error'ImPlotTick.__new could not find overloaded'
end
M.ImPlotTick = ffi.metatype("ImPlotTick",ImPlotTick)
--------------------------ImPlotTicker----------------------------
local ImPlotTicker= {}
ImPlotTicker.__index = ImPlotTicker
ImPlotTicker.AddTick_doubleStr = lib.ImPlotTicker_AddTick_doubleStr
ImPlotTicker.AddTick_doublePlotFormatter = lib.ImPlotTicker_AddTick_doublePlotFormatter
ImPlotTicker.AddTick_PlotTick = lib.ImPlotTicker_AddTick_PlotTick
function ImPlotTicker:AddTick(a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('double',a2) or type(a2)=='number') and (ffi.istype('const char*',a6) or ffi.istype('char[]',a6) or type(a6)=='string') then return self:AddTick_doubleStr(a2,a3,a4,a5,a6) end
    if (ffi.istype('double',a2) or type(a2)=='number') and ffi.istype('ImPlotFormatter',a6) then return self:AddTick_doublePlotFormatter(a2,a3,a4,a5,a6,a7) end
    if ffi.istype('ImPlotTick',a2) then return self:AddTick_PlotTick(a2) end
    print(a2,a3,a4,a5,a6,a7)
    error'ImPlotTicker:AddTick could not find overloaded'
end
ImPlotTicker.GetText_Int = lib.ImPlotTicker_GetText_Int
ImPlotTicker.GetText_PlotTick = lib.ImPlotTicker_GetText_PlotTick
function ImPlotTicker:GetText(a2) -- generic version
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return self:GetText_Int(a2) end
    if ffi.istype('const ImPlotTick',a2) then return self:GetText_PlotTick(a2) end
    print(a2)
    error'ImPlotTicker:GetText could not find overloaded'
end
function ImPlotTicker.__new(ctype)
    local ptr = lib.ImPlotTicker_ImPlotTicker()
    return ffi.gc(ptr,lib.ImPlotTicker_destroy)
end
ImPlotTicker.OverrideSizeLate = lib.ImPlotTicker_OverrideSizeLate
ImPlotTicker.Reset = lib.ImPlotTicker_Reset
ImPlotTicker.TickCount = lib.ImPlotTicker_TickCount
M.ImPlotTicker = ffi.metatype("ImPlotTicker",ImPlotTicker)
--------------------------ImPlotTime----------------------------
local ImPlotTime= {}
ImPlotTime.__index = ImPlotTime
M.ImPlotTime_FromDouble = lib.ImPlotTime_FromDouble
function ImPlotTime.ImPlotTime_Nil()
    local ptr = lib.ImPlotTime_ImPlotTime_Nil()
    return ffi.gc(ptr,lib.ImPlotTime_destroy)
end
function ImPlotTime.ImPlotTime_time_t(s,us)
    if us == nil then us = 0 end
    local ptr = lib.ImPlotTime_ImPlotTime_time_t(s,us)
    return ffi.gc(ptr,lib.ImPlotTime_destroy)
end
function ImPlotTime.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImPlotTime.ImPlotTime_Nil() end
    if (ffi.istype('int64_t',a1) or type(a1)=='number') then return ImPlotTime.ImPlotTime_time_t(a1,a2) end
    print(ctype,a1,a2)
    error'ImPlotTime.__new could not find overloaded'
end
ImPlotTime.RollOver = lib.ImPlotTime_RollOver
ImPlotTime.ToDouble = lib.ImPlotTime_ToDouble
M.ImPlotTime = ffi.metatype("ImPlotTime",ImPlotTime)
--------------------------ImRect----------------------------
local ImRect= {}
ImRect.__index = ImRect
ImRect.Add_Vec2 = lib.ImRect_Add_Vec2
ImRect.Add_Rect = lib.ImRect_Add_Rect
function ImRect:Add(a2) -- generic version
    if ffi.istype('const ImVec2',a2) then return self:Add_Vec2(a2) end
    if ffi.istype('const ImRect',a2) then return self:Add_Rect(a2) end
    print(a2)
    error'ImRect:Add could not find overloaded'
end
ImRect.AddX = lib.ImRect_AddX
ImRect.AddY = lib.ImRect_AddY
ImRect.AsVec4 = lib.ImRect_AsVec4
ImRect.ClipWith = lib.ImRect_ClipWith
ImRect.ClipWithFull = lib.ImRect_ClipWithFull
ImRect.Contains_Vec2 = lib.ImRect_Contains_Vec2
ImRect.Contains_Rect = lib.ImRect_Contains_Rect
function ImRect:Contains(a2) -- generic version
    if ffi.istype('const ImVec2',a2) then return self:Contains_Vec2(a2) end
    if ffi.istype('const ImRect',a2) then return self:Contains_Rect(a2) end
    print(a2)
    error'ImRect:Contains could not find overloaded'
end
ImRect.ContainsWithPad = lib.ImRect_ContainsWithPad
ImRect.Expand_Float = lib.ImRect_Expand_Float
ImRect.Expand_Vec2 = lib.ImRect_Expand_Vec2
function ImRect:Expand(a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return self:Expand_Float(a2) end
    if ffi.istype('const ImVec2',a2) then return self:Expand_Vec2(a2) end
    print(a2)
    error'ImRect:Expand could not find overloaded'
end
ImRect.GetArea = lib.ImRect_GetArea
ImRect.GetBL = lib.ImRect_GetBL
ImRect.GetBR = lib.ImRect_GetBR
ImRect.GetCenter = lib.ImRect_GetCenter
ImRect.GetHeight = lib.ImRect_GetHeight
ImRect.GetSize = lib.ImRect_GetSize
ImRect.GetTL = lib.ImRect_GetTL
ImRect.GetTR = lib.ImRect_GetTR
ImRect.GetWidth = lib.ImRect_GetWidth
function ImRect.ImRect_Nil()
    local ptr = lib.ImRect_ImRect_Nil()
    return ffi.gc(ptr,lib.ImRect_destroy)
end
function ImRect.ImRect_Vec2(min,max)
    local ptr = lib.ImRect_ImRect_Vec2(min,max)
    return ffi.gc(ptr,lib.ImRect_destroy)
end
function ImRect.ImRect_Vec4(v)
    local ptr = lib.ImRect_ImRect_Vec4(v)
    return ffi.gc(ptr,lib.ImRect_destroy)
end
function ImRect.ImRect_Float(x1,y1,x2,y2)
    local ptr = lib.ImRect_ImRect_Float(x1,y1,x2,y2)
    return ffi.gc(ptr,lib.ImRect_destroy)
end
function ImRect.__new(ctype,a1,a2,a3,a4) -- generic version
    if a1==nil then return ImRect.ImRect_Nil() end
    if ffi.istype('const ImVec2',a1) then return ImRect.ImRect_Vec2(a1,a2) end
    if ffi.istype('const ImVec4',a1) then return ImRect.ImRect_Vec4(a1) end
    if (ffi.istype('float',a1) or type(a1)=='number') then return ImRect.ImRect_Float(a1,a2,a3,a4) end
    print(ctype,a1,a2,a3,a4)
    error'ImRect.__new could not find overloaded'
end
ImRect.IsInverted = lib.ImRect_IsInverted
ImRect.Overlaps = lib.ImRect_Overlaps
ImRect.ToVec4 = lib.ImRect_ToVec4
ImRect.Translate = lib.ImRect_Translate
ImRect.TranslateX = lib.ImRect_TranslateX
ImRect.TranslateY = lib.ImRect_TranslateY
M.ImRect = ffi.metatype("ImRect",ImRect)
--------------------------ImTextureData----------------------------
local ImTextureData= {}
ImTextureData.__index = ImTextureData
ImTextureData.Create = lib.ImTextureData_Create
ImTextureData.DestroyPixels = lib.ImTextureData_DestroyPixels
ImTextureData.GetPitch = lib.ImTextureData_GetPitch
ImTextureData.GetPixels = lib.ImTextureData_GetPixels
ImTextureData.GetPixelsAt = lib.ImTextureData_GetPixelsAt
ImTextureData.GetSizeInBytes = lib.ImTextureData_GetSizeInBytes
ImTextureData.GetTexID = lib.ImTextureData_GetTexID
ImTextureData.GetTexRef = lib.ImTextureData_GetTexRef
function ImTextureData.__new(ctype)
    local ptr = lib.ImTextureData_ImTextureData()
    return ffi.gc(ptr,lib.ImTextureData_destroy)
end
ImTextureData.SetStatus = lib.ImTextureData_SetStatus
ImTextureData.SetTexID = lib.ImTextureData_SetTexID
M.ImTextureData = ffi.metatype("ImTextureData",ImTextureData)
--------------------------ImTextureRef----------------------------
local ImTextureRef= {}
ImTextureRef.__index = ImTextureRef
ImTextureRef.GetTexID = lib.ImTextureRef_GetTexID
function ImTextureRef.ImTextureRef_Nil()
    local ptr = lib.ImTextureRef_ImTextureRef_Nil()
    return ffi.gc(ptr,lib.ImTextureRef_destroy)
end
function ImTextureRef.ImTextureRef_TextureID(tex_id)
    local ptr = lib.ImTextureRef_ImTextureRef_TextureID(tex_id)
    return ffi.gc(ptr,lib.ImTextureRef_destroy)
end
function ImTextureRef.__new(ctype,a1) -- generic version
    if a1==nil then return ImTextureRef.ImTextureRef_Nil() end
    if (ffi.istype('uint64_t',a1) or type(a1)=='number') then return ImTextureRef.ImTextureRef_TextureID(a1) end
    print(ctype,a1)
    error'ImTextureRef.__new could not find overloaded'
end
M.ImTextureRef = ffi.metatype("ImTextureRef",ImTextureRef)
--------------------------ImVec1----------------------------
local ImVec1= {}
ImVec1.__index = ImVec1
function ImVec1.ImVec1_Nil()
    local ptr = lib.ImVec1_ImVec1_Nil()
    return ffi.gc(ptr,lib.ImVec1_destroy)
end
function ImVec1.ImVec1_Float(_x)
    local ptr = lib.ImVec1_ImVec1_Float(_x)
    return ffi.gc(ptr,lib.ImVec1_destroy)
end
function ImVec1.__new(ctype,a1) -- generic version
    if a1==nil then return ImVec1.ImVec1_Nil() end
    if (ffi.istype('float',a1) or type(a1)=='number') then return ImVec1.ImVec1_Float(a1) end
    print(ctype,a1)
    error'ImVec1.__new could not find overloaded'
end
M.ImVec1 = ffi.metatype("ImVec1",ImVec1)
--------------------------ImVec2i----------------------------
local ImVec2i= {}
ImVec2i.__index = ImVec2i
function ImVec2i.ImVec2i_Nil()
    local ptr = lib.ImVec2i_ImVec2i_Nil()
    return ffi.gc(ptr,lib.ImVec2i_destroy)
end
function ImVec2i.ImVec2i_Int(_x,_y)
    local ptr = lib.ImVec2i_ImVec2i_Int(_x,_y)
    return ffi.gc(ptr,lib.ImVec2i_destroy)
end
function ImVec2i.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImVec2i.ImVec2i_Nil() end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return ImVec2i.ImVec2i_Int(a1,a2) end
    print(ctype,a1,a2)
    error'ImVec2i.__new could not find overloaded'
end
M.ImVec2i = ffi.metatype("ImVec2i",ImVec2i)
--------------------------ImVec2ih----------------------------
local ImVec2ih= {}
ImVec2ih.__index = ImVec2ih
function ImVec2ih.ImVec2ih_Nil()
    local ptr = lib.ImVec2ih_ImVec2ih_Nil()
    return ffi.gc(ptr,lib.ImVec2ih_destroy)
end
function ImVec2ih.ImVec2ih_short(_x,_y)
    local ptr = lib.ImVec2ih_ImVec2ih_short(_x,_y)
    return ffi.gc(ptr,lib.ImVec2ih_destroy)
end
function ImVec2ih.ImVec2ih_Vec2(rhs)
    local ptr = lib.ImVec2ih_ImVec2ih_Vec2(rhs)
    return ffi.gc(ptr,lib.ImVec2ih_destroy)
end
function ImVec2ih.__new(ctype,a1,a2) -- generic version
    if a1==nil then return ImVec2ih.ImVec2ih_Nil() end
    if (ffi.istype('int16_t',a1) or type(a1)=='number') then return ImVec2ih.ImVec2ih_short(a1,a2) end
    if ffi.istype('const ImVec2',a1) then return ImVec2ih.ImVec2ih_Vec2(a1) end
    print(ctype,a1,a2)
    error'ImVec2ih.__new could not find overloaded'
end
M.ImVec2ih = ffi.metatype("ImVec2ih",ImVec2ih)
--------------------------Iterator----------------------------
local Iterator= {}
Iterator.__index = Iterator
function Iterator.Iterator_Nil()
    local ptr = lib.Iterator_Iterator_Nil()
    return ffi.gc(ptr,lib.Iterator_destroy)
end
function Iterator.Iterator_GlyphPtr(g)
    local ptr = lib.Iterator_Iterator_GlyphPtr(g)
    return ffi.gc(ptr,lib.Iterator_destroy)
end
function Iterator.__new(ctype,a1) -- generic version
    if a1==nil then return Iterator.Iterator_Nil() end
    if (ffi.istype('Glyph*',a1) or ffi.istype('Glyph',a1) or ffi.istype('Glyph[]',a1)) then return Iterator.Iterator_GlyphPtr(a1) end
    print(ctype,a1)
    error'Iterator.__new could not find overloaded'
end
M.Iterator = ffi.metatype("Iterator",Iterator)
--------------------------Language----------------------------
local Language= {}
Language.__index = Language
M.Language_AngelScript = lib.Language_AngelScript
M.Language_C = lib.Language_C
M.Language_Cpp = lib.Language_Cpp
M.Language_Cs = lib.Language_Cs
M.Language_Glsl = lib.Language_Glsl
M.Language_Hlsl = lib.Language_Hlsl
M.Language_Json = lib.Language_Json
M.Language_Lua = lib.Language_Lua
M.Language_Markdown = lib.Language_Markdown
M.Language_Python = lib.Language_Python
M.Language_Sql = lib.Language_Sql
M.Language = ffi.metatype("Language",Language)
--------------------------LinkDetachWithModifierClick----------------------------
local LinkDetachWithModifierClick= {}
LinkDetachWithModifierClick.__index = LinkDetachWithModifierClick
function LinkDetachWithModifierClick.__new(ctype)
    local ptr = lib.LinkDetachWithModifierClick_LinkDetachWithModifierClick()
    return ffi.gc(ptr,lib.LinkDetachWithModifierClick_destroy)
end
M.LinkDetachWithModifierClick = ffi.metatype("LinkDetachWithModifierClick",LinkDetachWithModifierClick)
--------------------------LinkId----------------------------
local LinkId= {}
LinkId.__index = LinkId
function LinkId.__new(ctype,val)
    return lib.ax_NodeEditor_LinkId(val)
end
LinkId.value = lib.ax_NodeEditor_LinkId_value
M.LinkId = ffi.metatype("LinkId",LinkId)
--------------------------MultipleSelectModifier----------------------------
local MultipleSelectModifier= {}
MultipleSelectModifier.__index = MultipleSelectModifier
function MultipleSelectModifier.__new(ctype)
    local ptr = lib.MultipleSelectModifier_MultipleSelectModifier()
    return ffi.gc(ptr,lib.MultipleSelectModifier_destroy)
end
M.MultipleSelectModifier = ffi.metatype("MultipleSelectModifier",MultipleSelectModifier)
--------------------------NodeId----------------------------
local NodeId= {}
NodeId.__index = NodeId
function NodeId.__new(ctype,val)
    return lib.ax_NodeEditor_NodeId(val)
end
NodeId.value = lib.ax_NodeEditor_NodeId_value
M.NodeId = ffi.metatype("NodeId",NodeId)
--------------------------Palette----------------------------
local Palette= {}
Palette.__index = Palette
function Palette.__new(ctype)
    local ptr = lib.Palette_Palette()
    return ffi.gc(ptr,lib.Palette_destroy)
end
Palette.const_get = lib.Palette_const_get
Palette.destroy = lib.Palette_destroy
Palette.get = lib.Palette_get
Palette.set = lib.Palette_set
M.Palette = ffi.metatype("Palette",Palette)
--------------------------PinId----------------------------
local PinId= {}
PinId.__index = PinId
function PinId.__new(ctype,val)
    return lib.ax_NodeEditor_PinId(val)
end
PinId.value = lib.ax_NodeEditor_PinId_value
M.PinId = ffi.metatype("PinId",PinId)
--------------------------Style----------------------------
local Style= {}
Style.__index = Style
function Style.__new(ctype)
    local ptr = lib.Style_Style()
    return ffi.gc(ptr,lib.Style_destroy)
end
M.Style = ffi.metatype("Style",Style)
--------------------------TextDiff----------------------------
local TextDiff= {}
TextDiff.__index = TextDiff
TextDiff.GetLanguage = lib.TextDiff_GetLanguage
TextDiff.GetLineSpacing = lib.TextDiff_GetLineSpacing
TextDiff.GetPalette = lib.TextDiff_GetPalette
TextDiff.GetSideBySideMode = lib.TextDiff_GetSideBySideMode
TextDiff.GetTabSize = lib.TextDiff_GetTabSize
TextDiff.IsShowScrollbarMiniMapEnabled = lib.TextDiff_IsShowScrollbarMiniMapEnabled
TextDiff.IsShowSpacesEnabled = lib.TextDiff_IsShowSpacesEnabled
TextDiff.IsShowTabsEnabled = lib.TextDiff_IsShowTabsEnabled
TextDiff.IsShowWhitespacesEnabled = lib.TextDiff_IsShowWhitespacesEnabled
TextDiff.IsWordWrapEnabled = lib.TextDiff_IsWordWrapEnabled
function TextDiff:Render(title,size,childFlags,windowFlags)
    childFlags = childFlags or 0
    size = size or ImVec2()
    windowFlags = windowFlags or 4
    return lib.TextDiff_Render(self,title,size,childFlags,windowFlags)
end
TextDiff.SetColors = lib.TextDiff_SetColors
TextDiff.SetFocus = lib.TextDiff_SetFocus
TextDiff.SetLanguage = lib.TextDiff_SetLanguage
TextDiff.SetLineSpacing = lib.TextDiff_SetLineSpacing
TextDiff.SetPalette = lib.TextDiff_SetPalette
TextDiff.SetShowScrollbarMiniMapEnabled = lib.TextDiff_SetShowScrollbarMiniMapEnabled
TextDiff.SetShowSpacesEnabled = lib.TextDiff_SetShowSpacesEnabled
TextDiff.SetShowTabsEnabled = lib.TextDiff_SetShowTabsEnabled
TextDiff.SetShowWhitespacesEnabled = lib.TextDiff_SetShowWhitespacesEnabled
TextDiff.SetSideBySideMode = lib.TextDiff_SetSideBySideMode
TextDiff.SetTabSize = lib.TextDiff_SetTabSize
TextDiff.SetText = lib.TextDiff_SetText
TextDiff.SetWordWrapEnabled = lib.TextDiff_SetWordWrapEnabled
function TextDiff.__new(ctype)
    local ptr = lib.TextDiff_TextDiff()
    return ffi.gc(ptr,lib.TextDiff_destroy)
end
M.TextDiff = ffi.metatype("TextDiff",TextDiff)
--------------------------TextEditor----------------------------
local TextEditor= {}
TextEditor.__index = TextEditor
TextEditor.AddMarker = lib.TextEditor_AddMarker
function TextEditor:AddNextOccurrence(wholeWord)
    wholeWord = wholeWord or false
    return lib.TextEditor_AddNextOccurrence(self,wholeWord)
end
function TextEditor:AddSquiggle(start,_end,type,color,tooltip,style)
    tooltip = tooltip or ""
    return lib.TextEditor_AddSquiggle(self,start,_end,type,color,tooltip,style)
end
TextEditor.AllCursorsHaveSelection = lib.TextEditor_AllCursorsHaveSelection
TextEditor.AnyCursorHasSelection = lib.TextEditor_AnyCursorHasSelection
TextEditor.CanRedo = lib.TextEditor_CanRedo
TextEditor.CanUndo = lib.TextEditor_CanUndo
TextEditor.ClearChangeCallback = lib.TextEditor_ClearChangeCallback
TextEditor.ClearCursors = lib.TextEditor_ClearCursors
TextEditor.ClearCustomCaretRenderer = lib.TextEditor_ClearCustomCaretRenderer
TextEditor.ClearCustomLineNumberRenderer = lib.TextEditor_ClearCustomLineNumberRenderer
TextEditor.ClearDeletor = lib.TextEditor_ClearDeletor
TextEditor.ClearInsertor = lib.TextEditor_ClearInsertor
TextEditor.ClearLineDecorator = lib.TextEditor_ClearLineDecorator
TextEditor.ClearLineNumberContextMenuCallback = lib.TextEditor_ClearLineNumberContextMenuCallback
TextEditor.ClearMarkers = lib.TextEditor_ClearMarkers
TextEditor.ClearSquiggles_DocPos = lib.TextEditor_ClearSquiggles_DocPos
TextEditor.ClearSquiggles_size_t = lib.TextEditor_ClearSquiggles_size_t
TextEditor.ClearSquiggles_Nil = lib.TextEditor_ClearSquiggles_Nil
function TextEditor:ClearSquiggles(a2,a3) -- generic version
    if ffi.istype('DocPos',a2) then return self:ClearSquiggles_DocPos(a2,a3) end
    if (ffi.istype('uint64_t',a2) or type(a2)=='number') then return self:ClearSquiggles_size_t(a2) end
    if a2==nil then return self:ClearSquiggles_Nil() end
    print(a2,a3)
    error'TextEditor:ClearSquiggles could not find overloaded'
end
TextEditor.ClearText = lib.TextEditor_ClearText
TextEditor.ClearTextContextMenuCallback = lib.TextEditor_ClearTextContextMenuCallback
TextEditor.ClearTextHoverCallback = lib.TextEditor_ClearTextHoverCallback
TextEditor.ClearTransactionCallback = lib.TextEditor_ClearTransactionCallback
TextEditor.CloseFindReplaceWindow = lib.TextEditor_CloseFindReplaceWindow
TextEditor.Copy = lib.TextEditor_Copy
TextEditor.CurrentCursorHasSelection = lib.TextEditor_CurrentCursorHasSelection
TextEditor.CursorHasSelection = lib.TextEditor_CursorHasSelection
TextEditor.Cut = lib.TextEditor_Cut
TextEditor.DeindentLines = lib.TextEditor_DeindentLines
TextEditor.DocPos2ScreenPos = lib.TextEditor_DocPos2ScreenPos
TextEditor.DocPos2VisPos = lib.TextEditor_DocPos2VisPos
TextEditor.FilterLines = lib.TextEditor_FilterLines
TextEditor.FilterSelections = lib.TextEditor_FilterSelections
TextEditor.FindAll = lib.TextEditor_FindAll
TextEditor.FindNext = lib.TextEditor_FindNext
function TextEditor:FindWordEnd(pos,wordOnly)
    wordOnly = wordOnly or false
    return lib.TextEditor_FindWordEnd(self,pos,wordOnly)
end
function TextEditor:FindWordStart(pos,wordOnly)
    wordOnly = wordOnly or false
    return lib.TextEditor_FindWordStart(self,pos,wordOnly)
end
TextEditor.FoldAroundLine = lib.TextEditor_FoldAroundLine
TextEditor.GetCurrentCursorPosition = lib.TextEditor_GetCurrentCursorPosition
TextEditor.GetCurrentCursorSelection = lib.TextEditor_GetCurrentCursorSelection
TextEditor.GetCursorPosition = lib.TextEditor_GetCursorPosition
TextEditor.GetCursorSelection = lib.TextEditor_GetCursorSelection
TextEditor.GetCursorText = lib.TextEditor_GetCursorText
M.TextEditor_GetDarkPalette = lib.TextEditor_GetDarkPalette
TextEditor.GetDecorationLeftMargin = lib.TextEditor_GetDecorationLeftMargin
M.TextEditor_GetDefaultPalette = lib.TextEditor_GetDefaultPalette
TextEditor.GetDocPosAtMousePos = lib.TextEditor_GetDocPosAtMousePos
TextEditor.GetFirstVisibleColumn = lib.TextEditor_GetFirstVisibleColumn
TextEditor.GetFirstVisibleRow = lib.TextEditor_GetFirstVisibleRow
TextEditor.GetGlyphWidth = lib.TextEditor_GetGlyphWidth
TextEditor.GetLanguage = lib.TextEditor_GetLanguage
TextEditor.GetLanguageName = lib.TextEditor_GetLanguageName
TextEditor.GetLastVisibleColumn = lib.TextEditor_GetLastVisibleColumn
TextEditor.GetLastVisibleRow = lib.TextEditor_GetLastVisibleRow
M.TextEditor_GetLightPalette = lib.TextEditor_GetLightPalette
TextEditor.GetLineCount = lib.TextEditor_GetLineCount
TextEditor.GetLineHeight = lib.TextEditor_GetLineHeight
TextEditor.GetLineNumberLeftMargin = lib.TextEditor_GetLineNumberLeftMargin
TextEditor.GetLineSpacing = lib.TextEditor_GetLineSpacing
TextEditor.GetLineText = lib.TextEditor_GetLineText
TextEditor.GetMainCursorPosition = lib.TextEditor_GetMainCursorPosition
TextEditor.GetMainCursorSelection = lib.TextEditor_GetMainCursorSelection
TextEditor.GetMiniMapColumns = lib.TextEditor_GetMiniMapColumns
TextEditor.GetNumberOfCursors = lib.TextEditor_GetNumberOfCursors
TextEditor.GetPalette = lib.TextEditor_GetPalette
TextEditor.GetSectionText_DocPos = lib.TextEditor_GetSectionText_DocPos
TextEditor.GetSectionText_DocSelection = lib.TextEditor_GetSectionText_DocSelection
function TextEditor:GetSectionText(a2,a3) -- generic version
    if ffi.istype('DocPos',a2) then return self:GetSectionText_DocPos(a2,a3) end
    if ffi.istype('const DocSelection',a2) then return self:GetSectionText_DocSelection(a2) end
    print(a2,a3)
    error'TextEditor:GetSectionText could not find overloaded'
end
TextEditor.GetTabSize = lib.TextEditor_GetTabSize
TextEditor.GetText = lib.TextEditor_GetText


TextEditor.GetTextLeftMargin = lib.TextEditor_GetTextLeftMargin
TextEditor.GetText_alloc = lib.TextEditor_GetText_alloc
TextEditor.GetText_free = lib.TextEditor_GetText_free
TextEditor.GetText_static = lib.TextEditor_GetText_static
TextEditor.GetUndoIndex = lib.TextEditor_GetUndoIndex
TextEditor.GetUserData = lib.TextEditor_GetUserData
TextEditor.GetWordAtMousePos = lib.TextEditor_GetWordAtMousePos
TextEditor.GrowSelections = lib.TextEditor_GrowSelections
TextEditor.HasChangeCallback = lib.TextEditor_HasChangeCallback
TextEditor.HasCustomCaretRenderer = lib.TextEditor_HasCustomCaretRenderer
TextEditor.HasCustomLineNumberRenderer = lib.TextEditor_HasCustomLineNumberRenderer
TextEditor.HasDeletor = lib.TextEditor_HasDeletor
TextEditor.HasFindString = lib.TextEditor_HasFindString
TextEditor.HasInsertor = lib.TextEditor_HasInsertor
TextEditor.HasLanguage = lib.TextEditor_HasLanguage
TextEditor.HasLineDecorator = lib.TextEditor_HasLineDecorator
TextEditor.HasLineNumberContextMenuCallback = lib.TextEditor_HasLineNumberContextMenuCallback
TextEditor.HasMarkers = lib.TextEditor_HasMarkers
TextEditor.HasSquiggles = lib.TextEditor_HasSquiggles
TextEditor.HasTextContextMenuCallback = lib.TextEditor_HasTextContextMenuCallback
TextEditor.HasTextHoverCallback = lib.TextEditor_HasTextHoverCallback
TextEditor.HasTransactionCallback = lib.TextEditor_HasTransactionCallback
TextEditor.IndentLines = lib.TextEditor_IndentLines
TextEditor.IsAutoIndentEnabled = lib.TextEditor_IsAutoIndentEnabled
TextEditor.IsCaretsVisible = lib.TextEditor_IsCaretsVisible
TextEditor.IsCompletingPairedGlyphs = lib.TextEditor_IsCompletingPairedGlyphs
TextEditor.IsDocPosVisible = lib.TextEditor_IsDocPosVisible
TextEditor.IsEmpty = lib.TextEditor_IsEmpty
TextEditor.IsFindReplaceEnabled = lib.TextEditor_IsFindReplaceEnabled
TextEditor.IsInsertSpacesOnTabs = lib.TextEditor_IsInsertSpacesOnTabs
TextEditor.IsLineFoldable = lib.TextEditor_IsLineFoldable
TextEditor.IsLineFolded = lib.TextEditor_IsLineFolded
TextEditor.IsLineFoldingEnabled = lib.TextEditor_IsLineFoldingEnabled
TextEditor.IsLineHidden = lib.TextEditor_IsLineHidden
TextEditor.IsLineVisible = lib.TextEditor_IsLineVisible
TextEditor.IsMiddleMousePanMode = lib.TextEditor_IsMiddleMousePanMode
TextEditor.IsMousePosOverGlyph = lib.TextEditor_IsMousePosOverGlyph
TextEditor.IsMousePosOverTextArea = lib.TextEditor_IsMousePosOverTextArea
TextEditor.IsOverwriteEnabled = lib.TextEditor_IsOverwriteEnabled
TextEditor.IsReadOnlyEnabled = lib.TextEditor_IsReadOnlyEnabled
TextEditor.IsShowCurrentLineHighlightEnabled = lib.TextEditor_IsShowCurrentLineHighlightEnabled
TextEditor.IsShowLineNumbersEnabled = lib.TextEditor_IsShowLineNumbersEnabled
TextEditor.IsShowMiniMapEnabled = lib.TextEditor_IsShowMiniMapEnabled
TextEditor.IsShowPanScrollIndicatorEnabled = lib.TextEditor_IsShowPanScrollIndicatorEnabled
TextEditor.IsShowScrollbarMiniMapEnabled = lib.TextEditor_IsShowScrollbarMiniMapEnabled
TextEditor.IsShowSpacesEnabled = lib.TextEditor_IsShowSpacesEnabled
TextEditor.IsShowTabsEnabled = lib.TextEditor_IsShowTabsEnabled
TextEditor.IsShowWhitespacesEnabled = lib.TextEditor_IsShowWhitespacesEnabled
TextEditor.IsShowingMatchingBrackets = lib.TextEditor_IsShowingMatchingBrackets
TextEditor.IsVisPosOverGlyph = lib.TextEditor_IsVisPosOverGlyph
TextEditor.IsWordWrapEnabled = lib.TextEditor_IsWordWrapEnabled
TextEditor.IterateIdentifiers = lib.TextEditor_IterateIdentifiers
TextEditor.IterateUserData = lib.TextEditor_IterateUserData
TextEditor.MainCursorHasSelection = lib.TextEditor_MainCursorHasSelection
TextEditor.MoveDownLines = lib.TextEditor_MoveDownLines
TextEditor.MoveUpLines = lib.TextEditor_MoveUpLines
TextEditor.OpenFindReplaceWindow = lib.TextEditor_OpenFindReplaceWindow
TextEditor.Paste = lib.TextEditor_Paste
TextEditor.Redo = lib.TextEditor_Redo
function TextEditor:Render(title,size,childFlags,windowFlags)
    childFlags = childFlags or 0
    size = size or ImVec2()
    windowFlags = windowFlags or 2052
    return lib.TextEditor_Render(self,title,size,childFlags,windowFlags)
end
TextEditor.ReplaceSectionText_DocPos = lib.TextEditor_ReplaceSectionText_DocPos
TextEditor.ReplaceSectionText_DocSelection = lib.TextEditor_ReplaceSectionText_DocSelection
function TextEditor:ReplaceSectionText(a2,a3,a4) -- generic version
    if ffi.istype('DocPos',a2) then return self:ReplaceSectionText_DocPos(a2,a3,a4) end
    if ffi.istype('const DocSelection',a2) then return self:ReplaceSectionText_DocSelection(a2,a3) end
    print(a2,a3,a4)
    error'TextEditor:ReplaceSectionText could not find overloaded'
end
TextEditor.ReplaceTextInAllCursors = lib.TextEditor_ReplaceTextInAllCursors
TextEditor.ReplaceTextInCurrentCursor = lib.TextEditor_ReplaceTextInCurrentCursor
function TextEditor:ScrollToLine(line,alignment)
    alignment = alignment or 1
    return lib.TextEditor_ScrollToLine(self,line,alignment)
end
TextEditor.SelectAll = lib.TextEditor_SelectAll
function TextEditor:SelectAllOccurrences(wholeWord)
    wholeWord = wholeWord or false
    return lib.TextEditor_SelectAllOccurrences(self,wholeWord)
end
function TextEditor:SelectAllOccurrencesOf(text,caseSensitive,wholeWord)
    if caseSensitive == nil then caseSensitive = true end
    wholeWord = wholeWord or false
    return lib.TextEditor_SelectAllOccurrencesOf(self,text,caseSensitive,wholeWord)
end
function TextEditor:SelectFirstOccurrenceOf(text,caseSensitive,wholeWord)
    if caseSensitive == nil then caseSensitive = true end
    wholeWord = wholeWord or false
    return lib.TextEditor_SelectFirstOccurrenceOf(self,text,caseSensitive,wholeWord)
end
TextEditor.SelectLine = lib.TextEditor_SelectLine
TextEditor.SelectLines = lib.TextEditor_SelectLines
function TextEditor:SelectNextOccurrenceOf(text,caseSensitive,wholeWord)
    if caseSensitive == nil then caseSensitive = true end
    wholeWord = wholeWord or false
    return lib.TextEditor_SelectNextOccurrenceOf(self,text,caseSensitive,wholeWord)
end
TextEditor.SelectRegion = lib.TextEditor_SelectRegion
function TextEditor:SelectToBrackets(includeBrackets)
    if includeBrackets == nil then includeBrackets = true end
    return lib.TextEditor_SelectToBrackets(self,includeBrackets)
end
TextEditor.SelectionToLowerCase = lib.TextEditor_SelectionToLowerCase
TextEditor.SelectionToUpperCase = lib.TextEditor_SelectionToUpperCase
TextEditor.SetAutoCompleteConfig = lib.TextEditor_SetAutoCompleteConfig

TextEditor.SetAutoIndentEnabled = lib.TextEditor_SetAutoIndentEnabled
TextEditor.SetCaretsVisible = lib.TextEditor_SetCaretsVisible
function TextEditor:SetChangeCallback(callback,delay)
    delay = delay or 0
    return lib.TextEditor_SetChangeCallback(self,callback,delay)
end
TextEditor.SetCompletePairedGlyphs = lib.TextEditor_SetCompletePairedGlyphs
TextEditor.SetCursor = lib.TextEditor_SetCursor
TextEditor.SetCustomCaretRenderer = lib.TextEditor_SetCustomCaretRenderer
TextEditor.SetCustomLineNumberRenderer = lib.TextEditor_SetCustomLineNumberRenderer
TextEditor.SetDecorationLeftMargin = lib.TextEditor_SetDecorationLeftMargin
M.TextEditor_SetDefaultPalette = lib.TextEditor_SetDefaultPalette
TextEditor.SetDeletor = lib.TextEditor_SetDeletor
TextEditor.SetFindAllButtonLabel = lib.TextEditor_SetFindAllButtonLabel
TextEditor.SetFindButtonLabel = lib.TextEditor_SetFindButtonLabel
TextEditor.SetFindReplaceEnabled = lib.TextEditor_SetFindReplaceEnabled
TextEditor.SetFocus = lib.TextEditor_SetFocus
M.TextEditor_SetImGuiContext = lib.TextEditor_SetImGuiContext
TextEditor.SetInsertSpacesOnTabs = lib.TextEditor_SetInsertSpacesOnTabs
TextEditor.SetInsertor = lib.TextEditor_SetInsertor
TextEditor.SetLanguage = lib.TextEditor_SetLanguage
TextEditor.SetLanguageChangeCallback = lib.TextEditor_SetLanguageChangeCallback
TextEditor.SetLineBreakConfig = lib.TextEditor_SetLineBreakConfig
TextEditor.SetLineDecorator = lib.TextEditor_SetLineDecorator
TextEditor.SetLineFoldingEnabled = lib.TextEditor_SetLineFoldingEnabled
TextEditor.SetLineNumberContextMenuCallback = lib.TextEditor_SetLineNumberContextMenuCallback
TextEditor.SetLineNumberLeftMargin = lib.TextEditor_SetLineNumberLeftMargin
TextEditor.SetLineSpacing = lib.TextEditor_SetLineSpacing
TextEditor.SetMiddleMousePanMode = lib.TextEditor_SetMiddleMousePanMode
TextEditor.SetMiddleMouseScrollMode = lib.TextEditor_SetMiddleMouseScrollMode
TextEditor.SetMiniMapColumns = lib.TextEditor_SetMiniMapColumns
TextEditor.SetOverwriteEnabled = lib.TextEditor_SetOverwriteEnabled
TextEditor.SetPalette = lib.TextEditor_SetPalette
TextEditor.SetReadOnlyEnabled = lib.TextEditor_SetReadOnlyEnabled
TextEditor.SetReplaceAllButtonLabel = lib.TextEditor_SetReplaceAllButtonLabel
TextEditor.SetReplaceButtonLabel = lib.TextEditor_SetReplaceButtonLabel
TextEditor.SetShowCurrentLineHighlightEnabled = lib.TextEditor_SetShowCurrentLineHighlightEnabled
TextEditor.SetShowLineNumbersEnabled = lib.TextEditor_SetShowLineNumbersEnabled
TextEditor.SetShowMatchingBrackets = lib.TextEditor_SetShowMatchingBrackets
TextEditor.SetShowMiniMapEnabled = lib.TextEditor_SetShowMiniMapEnabled
TextEditor.SetShowPanScrollIndicatorEnabled = lib.TextEditor_SetShowPanScrollIndicatorEnabled
TextEditor.SetShowScrollbarMiniMapEnabled = lib.TextEditor_SetShowScrollbarMiniMapEnabled
TextEditor.SetShowSpacesEnabled = lib.TextEditor_SetShowSpacesEnabled
TextEditor.SetShowTabsEnabled = lib.TextEditor_SetShowTabsEnabled
TextEditor.SetShowWhitespacesEnabled = lib.TextEditor_SetShowWhitespacesEnabled
TextEditor.SetTabSize = lib.TextEditor_SetTabSize
TextEditor.SetText_std_string_view = lib.TextEditor_SetText_std_string_view





function TextEditor:SetText(a2) -- generic version
    do return self:SetText_std_string_view(a2) end
    print(a2)
    error'TextEditor:SetText could not find overloaded'
end
TextEditor.SetTextContextMenuCallback = lib.TextEditor_SetTextContextMenuCallback
TextEditor.SetTextHoverCallback = lib.TextEditor_SetTextHoverCallback
TextEditor.SetTextLeftMargin = lib.TextEditor_SetTextLeftMargin

TextEditor.SetUserData = lib.TextEditor_SetUserData
TextEditor.SetWordWrapEnabled = lib.TextEditor_SetWordWrapEnabled
TextEditor.ShrinkSelections = lib.TextEditor_ShrinkSelections
TextEditor.SpacesToTabs = lib.TextEditor_SpacesToTabs
TextEditor.StripTrailingWhitespaces = lib.TextEditor_StripTrailingWhitespaces
TextEditor.TabsToSpaces = lib.TextEditor_TabsToSpaces
function TextEditor.__new(ctype)
    local ptr = lib.TextEditor_TextEditor()
    return ffi.gc(ptr,lib.TextEditor_destroy)
end
TextEditor.ToggleAtLine = lib.TextEditor_ToggleAtLine
TextEditor.ToggleComments = lib.TextEditor_ToggleComments
TextEditor.Undo = lib.TextEditor_Undo
TextEditor.UnfoldAll = lib.TextEditor_UnfoldAll
TextEditor.UnfoldAroundLine = lib.TextEditor_UnfoldAroundLine
TextEditor.VisPos2DocPos = lib.TextEditor_VisPos2DocPos
M.TextEditor = ffi.metatype("TextEditor",TextEditor)
--------------------------TrieAutoComplete----------------------------
local TrieAutoComplete= {}
TrieAutoComplete.__index = TrieAutoComplete
TrieAutoComplete.Connect = lib.TrieAutoComplete_Connect
TrieAutoComplete.Disconnect = lib.TrieAutoComplete_Disconnect
TrieAutoComplete.IsConnected = lib.TrieAutoComplete_IsConnected
function TrieAutoComplete.__new(ctype)
    local ptr = lib.TrieAutoComplete_TrieAutoComplete()
    return ffi.gc(ptr,lib.TrieAutoComplete_destroy)
end
M.TrieAutoComplete = ffi.metatype("TrieAutoComplete",TrieAutoComplete)
--------------------------VisPos----------------------------
local VisPos= {}
VisPos.__index = VisPos
function VisPos.VisPos_Nil()
    local ptr = lib.VisPos_VisPos_Nil()
    return ffi.gc(ptr,lib.VisPos_destroy)
end
function VisPos.VisPos_size_t(row,column)
    local ptr = lib.VisPos_VisPos_size_t(row,column)
    return ffi.gc(ptr,lib.VisPos_destroy)
end
function VisPos.__new(ctype,a1,a2) -- generic version
    if a1==nil then return VisPos.VisPos_Nil() end
    if (ffi.istype('uint64_t',a1) or type(a1)=='number') then return VisPos.VisPos_size_t(a1,a2) end
    print(ctype,a1,a2)
    error'VisPos.__new could not find overloaded'
end
M.VisPos = ffi.metatype("VisPos",VisPos)
--------------------------imguiGizmo----------------------------
local imguiGizmo= {}
imguiGizmo.__index = imguiGizmo
M.imguiGizmo_buildCone = lib.imguiGizmo_buildCone
M.imguiGizmo_buildCube = lib.imguiGizmo_buildCube
M.imguiGizmo_buildCylinder = lib.imguiGizmo_buildCylinder
function M.imguiGizmo_buildPlane(size,thickness)
    thickness = thickness or planeThickness
    return lib.imguiGizmo_buildPlane(size,thickness)
end
M.imguiGizmo_buildPolygon = lib.imguiGizmo_buildPolygon
M.imguiGizmo_buildSphere = lib.imguiGizmo_buildSphere
imguiGizmo.checkTowards_vec3 = lib.imguiGizmo_checkTowards_vec3
imguiGizmo.checkTowards_vec4 = lib.imguiGizmo_checkTowards_vec4
imguiGizmo.checkTowards_quat = lib.imguiGizmo_checkTowards_quat
function imguiGizmo:checkTowards(a2) -- generic version
    if ffi.istype('const vec3',a2) then return self:checkTowards_vec3(a2) end
    if ffi.istype('const vec4',a2) then return self:checkTowards_vec4(a2) end
    if ffi.istype('const quat',a2) then return self:checkTowards_quat(a2) end
    print(a2)
    error'imguiGizmo:checkTowards could not find overloaded'
end
imguiGizmo.drawFunc = lib.imguiGizmo_drawFunc
function M.imguiGizmo_flipRotOnX(b)
    if b == nil then b = true end
    return lib.imguiGizmo_flipRotOnX(b)
end
function M.imguiGizmo_flipRotOnY(b)
    if b == nil then b = true end
    return lib.imguiGizmo_flipRotOnY(b)
end
function M.imguiGizmo_flipRotOnZ(b)
    if b == nil then b = true end
    return lib.imguiGizmo_flipRotOnZ(b)
end
M.imguiGizmo_getDollyScale = lib.imguiGizmo_getDollyScale
M.imguiGizmo_getDollyWheelScale = lib.imguiGizmo_getDollyWheelScale
M.imguiGizmo_getFlipDolly = lib.imguiGizmo_getFlipDolly
M.imguiGizmo_getFlipPanX = lib.imguiGizmo_getFlipPanX
M.imguiGizmo_getFlipPanY = lib.imguiGizmo_getFlipPanY
M.imguiGizmo_getFlipRotOnX = lib.imguiGizmo_getFlipRotOnX
M.imguiGizmo_getFlipRotOnY = lib.imguiGizmo_getFlipRotOnY
M.imguiGizmo_getFlipRotOnZ = lib.imguiGizmo_getFlipRotOnZ
M.imguiGizmo_getGizmoFeelingRot = lib.imguiGizmo_getGizmoFeelingRot
M.imguiGizmo_getPanScale = lib.imguiGizmo_getPanScale
M.imguiGizmo_getReverseX = lib.imguiGizmo_getReverseX
M.imguiGizmo_getReverseY = lib.imguiGizmo_getReverseY
M.imguiGizmo_getReverseZ = lib.imguiGizmo_getReverseZ
imguiGizmo.getTransforms_vec3Ptr = lib.imguiGizmo_getTransforms_vec3Ptr
imguiGizmo.getTransforms_vec4Ptr = lib.imguiGizmo_getTransforms_vec4Ptr
function imguiGizmo:getTransforms(a2,a3,a4,a5) -- generic version
    if (ffi.istype('vec3*',a4) or ffi.istype('vec3',a4) or ffi.istype('vec3[]',a4)) then return self:getTransforms_vec3Ptr(a2,a3,a4,a5) end
    if (ffi.istype('vec4*',a4) or ffi.istype('vec4',a4) or ffi.istype('vec4[]',a4)) then return self:getTransforms_vec4Ptr(a2,a3,a4,a5) end
    print(a2,a3,a4,a5)
    error'imguiGizmo:getTransforms could not find overloaded'
end
imguiGizmo.modeSettings = lib.imguiGizmo_modeSettings
M.imguiGizmo_resizeAxesOf = lib.imguiGizmo_resizeAxesOf
M.imguiGizmo_resizeSolidOf = lib.imguiGizmo_resizeSolidOf
M.imguiGizmo_restoreAxesSize = lib.imguiGizmo_restoreAxesSize
M.imguiGizmo_restoreDirectionColor = lib.imguiGizmo_restoreDirectionColor
M.imguiGizmo_restoreSolidSize = lib.imguiGizmo_restoreSolidSize
M.imguiGizmo_restoreSphereColors = lib.imguiGizmo_restoreSphereColors
function M.imguiGizmo_reverseX(b)
    if b == nil then b = true end
    return lib.imguiGizmo_reverseX(b)
end
function M.imguiGizmo_reverseY(b)
    if b == nil then b = true end
    return lib.imguiGizmo_reverseY(b)
end
function M.imguiGizmo_reverseZ(b)
    if b == nil then b = true end
    return lib.imguiGizmo_reverseZ(b)
end
M.imguiGizmo_setDirectionColor_U32U32 = lib.imguiGizmo_setDirectionColor_U32U32
M.imguiGizmo_setDirectionColor_Vec4Vec4 = lib.imguiGizmo_setDirectionColor_Vec4Vec4
M.imguiGizmo_setDirectionColor_U32 = lib.imguiGizmo_setDirectionColor_U32
M.imguiGizmo_setDirectionColor_Vec4 = lib.imguiGizmo_setDirectionColor_Vec4
function M.imguiGizmo_setDirectionColor(a1,a2) -- generic version
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') and (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.imguiGizmo_setDirectionColor_U32U32(a1,a2) end
    if ffi.istype('const ImVec4',a1) and ffi.istype('const ImVec4',a2) then return M.imguiGizmo_setDirectionColor_Vec4Vec4(a1,a2) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') and a2==nil then return M.imguiGizmo_setDirectionColor_U32(a1) end
    if ffi.istype('const ImVec4',a1) and a2==nil then return M.imguiGizmo_setDirectionColor_Vec4(a1) end
    print(a1,a2)
    error'M.imguiGizmo_setDirectionColor could not find overloaded'
end
M.imguiGizmo_setDollyModifier = lib.imguiGizmo_setDollyModifier
M.imguiGizmo_setDollyScale = lib.imguiGizmo_setDollyScale
M.imguiGizmo_setDollyWheelScale = lib.imguiGizmo_setDollyWheelScale
imguiGizmo.setDualMode = lib.imguiGizmo_setDualMode
M.imguiGizmo_setFlipDolly = lib.imguiGizmo_setFlipDolly
M.imguiGizmo_setFlipPanX = lib.imguiGizmo_setFlipPanX
M.imguiGizmo_setFlipPanY = lib.imguiGizmo_setFlipPanY
M.imguiGizmo_setGizmoFeelingRot = lib.imguiGizmo_setGizmoFeelingRot
M.imguiGizmo_setPanModifier = lib.imguiGizmo_setPanModifier
M.imguiGizmo_setPanScale = lib.imguiGizmo_setPanScale
M.imguiGizmo_setSphereColors_Vec4 = lib.imguiGizmo_setSphereColors_Vec4
M.imguiGizmo_setSphereColors_U32 = lib.imguiGizmo_setSphereColors_U32
function M.imguiGizmo_setSphereColors(a1,a2) -- generic version
    if ffi.istype('const ImVec4',a1) then return M.imguiGizmo_setSphereColors_Vec4(a1,a2) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.imguiGizmo_setSphereColors_U32(a1,a2) end
    print(a1,a2)
    error'M.imguiGizmo_setSphereColors could not find overloaded'
end
M.imguiGizmo = ffi.metatype("imguiGizmo",imguiGizmo)
------------------------------------------------------
M.GetDejavu = lib.GetDejavu
M.Getnotosans = lib.Getnotosans
M.ImGuiFreeType_DebugEditFontLoaderFlags = lib.ImGuiFreeType_DebugEditFontLoaderFlags
M.ImGuiFreeType_GetFontLoader = lib.ImGuiFreeType_GetFontLoader
function M.ImGuiFreeType_SetAllocatorFunctions(alloc_func,free_func,user_data)
    user_data = user_data or nil
    return lib.ImGuiFreeType_SetAllocatorFunctions(alloc_func,free_func,user_data)
end
M.ImGuizmo_AllowAxisFlip = lib.ImGuizmo_AllowAxisFlip
M.ImGuizmo_BeginFrame = lib.ImGuizmo_BeginFrame
M.ImGuizmo_ComputeMouseRay = lib.ImGuizmo_ComputeMouseRay
M.ImGuizmo_DecomposeMatrixToComponents = lib.ImGuizmo_DecomposeMatrixToComponents
M.ImGuizmo_DrawAxes = lib.ImGuizmo_DrawAxes
M.ImGuizmo_DrawCubes = lib.ImGuizmo_DrawCubes
M.ImGuizmo_DrawGrid = lib.ImGuizmo_DrawGrid
M.ImGuizmo_DrawGridCustom = lib.ImGuizmo_DrawGridCustom
M.ImGuizmo_DrawGridCustomColor = lib.ImGuizmo_DrawGridCustomColor
M.ImGuizmo_Enable = lib.ImGuizmo_Enable
M.ImGuizmo_GetActiveHandleType = lib.ImGuizmo_GetActiveHandleType
M.ImGuizmo_GetActiveMoveType = lib.ImGuizmo_GetActiveMoveType
M.ImGuizmo_GetHoveredHandleType = lib.ImGuizmo_GetHoveredHandleType
M.ImGuizmo_GetHoveredMoveType = lib.ImGuizmo_GetHoveredMoveType
M.ImGuizmo_GetID_Str = lib.ImGuizmo_GetID_Str
M.ImGuizmo_GetID_StrStr = lib.ImGuizmo_GetID_StrStr
M.ImGuizmo_GetID_Ptr = lib.ImGuizmo_GetID_Ptr
function M.ImGuizmo_GetID(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a2==nil then return M.ImGuizmo_GetID_Str(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImGuizmo_GetID_StrStr(a1,a2) end
    if ffi.istype('void *',a1) then return M.ImGuizmo_GetID_Ptr(a1) end
    print(a1,a2)
    error'M.ImGuizmo_GetID could not find overloaded'
end
M.ImGuizmo_GetStyle = lib.ImGuizmo_GetStyle
M.ImGuizmo_IsOver_Nil = lib.ImGuizmo_IsOver_Nil
M.ImGuizmo_IsOver_OPERATION = lib.ImGuizmo_IsOver_OPERATION
M.ImGuizmo_IsOver_FloatPtr = lib.ImGuizmo_IsOver_FloatPtr
function M.ImGuizmo_IsOver(a1,a2) -- generic version
    if a1==nil then return M.ImGuizmo_IsOver_Nil() end
    if (ffi.istype('OPERATION',a1) or type(a1)=='number') then return M.ImGuizmo_IsOver_OPERATION(a1) end
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImGuizmo_IsOver_FloatPtr(a1,a2) end
    print(a1,a2)
    error'M.ImGuizmo_IsOver could not find overloaded'
end
M.ImGuizmo_IsUsing = lib.ImGuizmo_IsUsing
M.ImGuizmo_IsUsingAny = lib.ImGuizmo_IsUsingAny
M.ImGuizmo_IsUsingViewManipulate = lib.ImGuizmo_IsUsingViewManipulate
M.ImGuizmo_IsViewManipulateHovered = lib.ImGuizmo_IsViewManipulateHovered
function M.ImGuizmo_Manipulate(view,projection,operation,mode,matrix,deltaMatrix,snap,localBounds,boundsSnap)
    boundsSnap = boundsSnap or nil
    deltaMatrix = deltaMatrix or nil
    localBounds = localBounds or nil
    snap = snap or nil
    return lib.ImGuizmo_Manipulate(view,projection,operation,mode,matrix,deltaMatrix,snap,localBounds,boundsSnap)
end
M.ImGuizmo_PopID = lib.ImGuizmo_PopID
M.ImGuizmo_PushID_Str = lib.ImGuizmo_PushID_Str
M.ImGuizmo_PushID_StrStr = lib.ImGuizmo_PushID_StrStr
M.ImGuizmo_PushID_Ptr = lib.ImGuizmo_PushID_Ptr
M.ImGuizmo_PushID_Int = lib.ImGuizmo_PushID_Int
function M.ImGuizmo_PushID(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a2==nil then return M.ImGuizmo_PushID_Str(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImGuizmo_PushID_StrStr(a1,a2) end
    if ffi.istype('void *',a1) then return M.ImGuizmo_PushID_Ptr(a1) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImGuizmo_PushID_Int(a1) end
    print(a1,a2)
    error'M.ImGuizmo_PushID could not find overloaded'
end
M.ImGuizmo_RecomposeMatrixFromComponents = lib.ImGuizmo_RecomposeMatrixFromComponents
M.ImGuizmo_SetAlternativeWindow = lib.ImGuizmo_SetAlternativeWindow
M.ImGuizmo_SetAxisLimit = lib.ImGuizmo_SetAxisLimit
M.ImGuizmo_SetAxisMask = lib.ImGuizmo_SetAxisMask
function M.ImGuizmo_SetDrawlist(drawlist)
    drawlist = drawlist or nil
    return lib.ImGuizmo_SetDrawlist(drawlist)
end
M.ImGuizmo_SetGizmoSizeClipSpace = lib.ImGuizmo_SetGizmoSizeClipSpace
M.ImGuizmo_SetID = lib.ImGuizmo_SetID
M.ImGuizmo_SetImGuiContext = lib.ImGuizmo_SetImGuiContext
M.ImGuizmo_SetOrthographic = lib.ImGuizmo_SetOrthographic
M.ImGuizmo_SetPlaneLimit = lib.ImGuizmo_SetPlaneLimit
M.ImGuizmo_SetRect = lib.ImGuizmo_SetRect
M.ImGuizmo_ViewManipulate_Float = lib.ImGuizmo_ViewManipulate_Float
M.ImGuizmo_ViewManipulate_FloatPtr = lib.ImGuizmo_ViewManipulate_FloatPtr
function M.ImGuizmo_ViewManipulate(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.ImGuizmo_ViewManipulate_Float(a1,a2,a3,a4,a5) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImGuizmo_ViewManipulate_FloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.ImGuizmo_ViewManipulate could not find overloaded'
end
M.ImNodes_AutoPositionNode = lib.ImNodes_AutoPositionNode
M.ImNodes_BeginCanvas = lib.ImNodes_BeginCanvas
M.ImNodes_BeginInputSlot = lib.ImNodes_BeginInputSlot
M.ImNodes_BeginNode = lib.ImNodes_BeginNode
M.ImNodes_BeginOutputSlot = lib.ImNodes_BeginOutputSlot
M.ImNodes_BeginSlot = lib.ImNodes_BeginSlot
M.ImNodes_Connection = lib.ImNodes_Connection
M.ImNodes_EndCanvas = lib.ImNodes_EndCanvas
M.ImNodes_EndNode = lib.ImNodes_EndNode
M.ImNodes_EndSlot = lib.ImNodes_EndSlot
M.ImNodes_Ez_BeginCanvas = lib.ImNodes_Ez_BeginCanvas
M.ImNodes_Ez_BeginNode = lib.ImNodes_Ez_BeginNode
M.ImNodes_Ez_Connection = lib.ImNodes_Ez_Connection
M.ImNodes_Ez_CreateContext = lib.ImNodes_Ez_CreateContext
M.ImNodes_Ez_EndCanvas = lib.ImNodes_Ez_EndCanvas
M.ImNodes_Ez_EndNode = lib.ImNodes_Ez_EndNode
M.ImNodes_Ez_FreeContext = lib.ImNodes_Ez_FreeContext
M.ImNodes_Ez_GetState = lib.ImNodes_Ez_GetState
M.ImNodes_Ez_InputSlots = lib.ImNodes_Ez_InputSlots
M.ImNodes_Ez_OutputSlots = lib.ImNodes_Ez_OutputSlots
M.ImNodes_Ez_PopStyleColor = lib.ImNodes_Ez_PopStyleColor
function M.ImNodes_Ez_PopStyleVar(count)
    count = count or 1
    return lib.ImNodes_Ez_PopStyleVar(count)
end
M.ImNodes_Ez_PushStyleColor_U32 = lib.ImNodes_Ez_PushStyleColor_U32
M.ImNodes_Ez_PushStyleColor_Vec4 = lib.ImNodes_Ez_PushStyleColor_Vec4
function M.ImNodes_Ez_PushStyleColor(a1,a2) -- generic version
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.ImNodes_Ez_PushStyleColor_U32(a1,a2) end
    if ffi.istype('const ImVec4',a2) then return M.ImNodes_Ez_PushStyleColor_Vec4(a1,a2) end
    print(a1,a2)
    error'M.ImNodes_Ez_PushStyleColor could not find overloaded'
end
M.ImNodes_Ez_PushStyleVar_Float = lib.ImNodes_Ez_PushStyleVar_Float
M.ImNodes_Ez_PushStyleVar_Vec2 = lib.ImNodes_Ez_PushStyleVar_Vec2
function M.ImNodes_Ez_PushStyleVar(a1,a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.ImNodes_Ez_PushStyleVar_Float(a1,a2) end
    if ffi.istype('const ImVec2',a2) then return M.ImNodes_Ez_PushStyleVar_Vec2(a1,a2) end
    print(a1,a2)
    error'M.ImNodes_Ez_PushStyleVar could not find overloaded'
end
M.ImNodes_Ez_SetContext = lib.ImNodes_Ez_SetContext
M.ImNodes_GetCurrentCanvas = lib.ImNodes_GetCurrentCanvas
M.ImNodes_GetNewConnection = lib.ImNodes_GetNewConnection
M.ImNodes_GetPendingConnection = lib.ImNodes_GetPendingConnection
M.ImNodes_InputSlotKind = lib.ImNodes_InputSlotKind
M.ImNodes_IsConnectingCompatibleSlot = lib.ImNodes_IsConnectingCompatibleSlot
M.ImNodes_IsInputSlotKind = lib.ImNodes_IsInputSlotKind
M.ImNodes_IsNodeHovered = lib.ImNodes_IsNodeHovered
M.ImNodes_IsOutputSlotKind = lib.ImNodes_IsOutputSlotKind
M.ImNodes_IsSlotCurveHovered = lib.ImNodes_IsSlotCurveHovered
M.ImNodes_OutputSlotKind = lib.ImNodes_OutputSlotKind
function M.ImPlot3D_AddColormap_Vec4Ptr(name,cols,size,qual)
    if qual == nil then qual = true end
    return lib.ImPlot3D_AddColormap_Vec4Ptr(name,cols,size,qual)
end
function M.ImPlot3D_AddColormap_U32Ptr(name,cols,size,qual)
    if qual == nil then qual = true end
    return lib.ImPlot3D_AddColormap_U32Ptr(name,cols,size,qual)
end
function M.ImPlot3D_AddColormap(a1,a2,a3,a4) -- generic version
    if (ffi.istype('const ImVec4*',a2) or ffi.istype('const ImVec4',a2) or ffi.istype('const ImVec4[]',a2)) then return M.ImPlot3D_AddColormap_Vec4Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_AddColormap_U32Ptr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot3D_AddColormap could not find overloaded'
end
function M.ImPlot3D_BeginPlot(title_id,size,flags)
    flags = flags or 0
    size = size or ImVec2(-1,0)
    return lib.ImPlot3D_BeginPlot(title_id,size,flags)
end
M.ImPlot3D_CreateContext = lib.ImPlot3D_CreateContext
function M.ImPlot3D_DestroyContext(ctx)
    ctx = ctx or nil
    return lib.ImPlot3D_DestroyContext(ctx)
end
M.ImPlot3D_EndPlot = lib.ImPlot3D_EndPlot
function M.ImPlot3D_GetColormapColor(idx,cmap)
    cmap = cmap or -1
    return lib.ImPlot3D_GetColormapColor(idx,cmap)
end
M.ImPlot3D_GetColormapCount = lib.ImPlot3D_GetColormapCount
M.ImPlot3D_GetColormapIndex = lib.ImPlot3D_GetColormapIndex
M.ImPlot3D_GetColormapName = lib.ImPlot3D_GetColormapName
function M.ImPlot3D_GetColormapSize(cmap)
    cmap = cmap or -1
    return lib.ImPlot3D_GetColormapSize(cmap)
end
M.ImPlot3D_GetCurrentContext = lib.ImPlot3D_GetCurrentContext
M.ImPlot3D_GetPlotDrawList = lib.ImPlot3D_GetPlotDrawList
M.ImPlot3D_GetPlotRectPos = lib.ImPlot3D_GetPlotRectPos
M.ImPlot3D_GetPlotRectSize = lib.ImPlot3D_GetPlotRectSize
M.ImPlot3D_GetStyle = lib.ImPlot3D_GetStyle
M.ImPlot3D_GetStyleColorU32 = lib.ImPlot3D_GetStyleColorU32
M.ImPlot3D_GetStyleColorVec4 = lib.ImPlot3D_GetStyleColorVec4
M.ImPlot3D_NextColormapColor = lib.ImPlot3D_NextColormapColor
M.ImPlot3D_NextMarker = lib.ImPlot3D_NextMarker
function M.ImPlot3D_PixelsToPlotPlane_Vec2(pix,plane,mask)
    if mask == nil then mask = true end
    return lib.ImPlot3D_PixelsToPlotPlane_Vec2(pix,plane,mask)
end
function M.ImPlot3D_PixelsToPlotPlane_double(x,y,plane,mask)
    if mask == nil then mask = true end
    return lib.ImPlot3D_PixelsToPlotPlane_double(x,y,plane,mask)
end
function M.ImPlot3D_PixelsToPlotPlane(a1,a2,a3,a4) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.ImPlot3D_PixelsToPlotPlane_Vec2(a1,a2,a3) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot3D_PixelsToPlotPlane_double(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot3D_PixelsToPlotPlane could not find overloaded'
end
M.ImPlot3D_PixelsToPlotRay_Vec2 = lib.ImPlot3D_PixelsToPlotRay_Vec2
M.ImPlot3D_PixelsToPlotRay_double = lib.ImPlot3D_PixelsToPlotRay_double
function M.ImPlot3D_PixelsToPlotRay(a1,a2) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.ImPlot3D_PixelsToPlotRay_Vec2(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot3D_PixelsToPlotRay_double(a1,a2) end
    print(a1,a2)
    error'M.ImPlot3D_PixelsToPlotRay could not find overloaded'
end
function M.ImPlot3D_PlotDummy(label_id,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotDummy(label_id,spec)
end
function M.ImPlot3D_PlotImage_Vec2(label_id,tex_ref,center,axis_u,axis_v,uv0,uv1,tint_col,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    tint_col = tint_col or ImVec4(1,1,1,1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,1)
    return lib.ImPlot3D_PlotImage_Vec2(label_id,tex_ref,center,axis_u,axis_v,uv0,uv1,tint_col,spec)
end
function M.ImPlot3D_PlotImage_Plot3DPoint(label_id,tex_ref,p0,p1,p2,p3,uv0,uv1,uv2,uv3,tint_col,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    tint_col = tint_col or ImVec4(1,1,1,1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,0)
    uv2 = uv2 or ImVec2(1,1)
    uv3 = uv3 or ImVec2(0,1)
    return lib.ImPlot3D_PlotImage_Plot3DPoint(label_id,tex_ref,p0,p1,p2,p3,uv0,uv1,uv2,uv3,tint_col,spec)
end
function M.ImPlot3D_PlotImage(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12) -- generic version
    if (ffi.istype('const ImVec2',a6) or type(a6)=='nil') then return M.ImPlot3D_PlotImage_Vec2(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.istype('const ImPlot3DPoint',a6) then return M.ImPlot3D_PlotImage_Plot3DPoint(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12)
    error'M.ImPlot3D_PlotImage could not find overloaded'
end
function M.ImPlot3D_PlotLine_FloatPtr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotLine_FloatPtr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotLine_doublePtr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotLine_doublePtr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotLine_S8Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotLine_S8Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotLine_U8Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotLine_U8Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotLine_S16Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotLine_S16Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotLine_U16Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotLine_U16Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotLine_S32Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotLine_S32Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotLine_U32Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotLine_U32Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotLine_S64Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotLine_S64Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotLine_U64Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotLine_U64Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotLine(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot3D_PlotLine_FloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot3D_PlotLine_doublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot3D_PlotLine_S8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotLine_U8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotLine_S16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotLine_U16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotLine_S32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotLine_U32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotLine_S64Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotLine_U64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot3D_PlotLine could not find overloaded'
end
function M.ImPlot3D_PlotMesh_FloatPtr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotMesh_FloatPtr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
end
function M.ImPlot3D_PlotMesh_doublePtr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotMesh_doublePtr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
end
function M.ImPlot3D_PlotMesh_S8Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotMesh_S8Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
end
function M.ImPlot3D_PlotMesh_U8Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotMesh_U8Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
end
function M.ImPlot3D_PlotMesh_S16Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotMesh_S16Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
end
function M.ImPlot3D_PlotMesh_U16Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotMesh_U16Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
end
function M.ImPlot3D_PlotMesh_S32Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotMesh_S32Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
end
function M.ImPlot3D_PlotMesh_U32Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotMesh_U32Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
end
function M.ImPlot3D_PlotMesh_S64Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotMesh_S64Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
end
function M.ImPlot3D_PlotMesh_U64Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotMesh_U64Ptr(label_id,vtx_xs,vtx_ys,vtx_zs,idxs,vtx_count,idx_count,spec)
end
function M.ImPlot3D_PlotMesh(a1,a2,a3,a4,a5,a6,a7,a8) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot3D_PlotMesh_FloatPtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot3D_PlotMesh_doublePtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot3D_PlotMesh_S8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotMesh_U8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotMesh_S16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotMesh_U16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotMesh_S32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotMesh_U32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotMesh_S64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotMesh_U64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    print(a1,a2,a3,a4,a5,a6,a7,a8)
    error'M.ImPlot3D_PlotMesh could not find overloaded'
end
function M.ImPlot3D_PlotQuad_FloatPtr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotQuad_FloatPtr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotQuad_doublePtr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotQuad_doublePtr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotQuad_S8Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotQuad_S8Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotQuad_U8Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotQuad_U8Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotQuad_S16Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotQuad_S16Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotQuad_U16Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotQuad_U16Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotQuad_S32Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotQuad_S32Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotQuad_U32Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotQuad_U32Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotQuad_S64Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotQuad_S64Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotQuad_U64Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotQuad_U64Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotQuad(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot3D_PlotQuad_FloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot3D_PlotQuad_doublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot3D_PlotQuad_S8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotQuad_U8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotQuad_S16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotQuad_U16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotQuad_S32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotQuad_U32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotQuad_S64Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotQuad_U64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot3D_PlotQuad could not find overloaded'
end
function M.ImPlot3D_PlotScatter_FloatPtr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotScatter_FloatPtr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotScatter_doublePtr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotScatter_doublePtr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotScatter_S8Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotScatter_S8Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotScatter_U8Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotScatter_U8Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotScatter_S16Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotScatter_S16Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotScatter_U16Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotScatter_U16Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotScatter_S32Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotScatter_S32Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotScatter_U32Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotScatter_U32Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotScatter_S64Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotScatter_S64Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotScatter_U64Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotScatter_U64Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotScatter(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot3D_PlotScatter_FloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot3D_PlotScatter_doublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot3D_PlotScatter_S8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotScatter_U8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotScatter_S16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotScatter_U16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotScatter_S32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotScatter_U32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotScatter_S64Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotScatter_U64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot3D_PlotScatter could not find overloaded'
end
function M.ImPlot3D_PlotSurface_FloatPtr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotSurface_FloatPtr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
end
function M.ImPlot3D_PlotSurface_doublePtr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotSurface_doublePtr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
end
function M.ImPlot3D_PlotSurface_S8Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotSurface_S8Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
end
function M.ImPlot3D_PlotSurface_U8Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotSurface_U8Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
end
function M.ImPlot3D_PlotSurface_S16Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotSurface_S16Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
end
function M.ImPlot3D_PlotSurface_U16Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotSurface_U16Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
end
function M.ImPlot3D_PlotSurface_S32Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotSurface_S32Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
end
function M.ImPlot3D_PlotSurface_U32Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotSurface_U32Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
end
function M.ImPlot3D_PlotSurface_S64Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotSurface_S64Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
end
function M.ImPlot3D_PlotSurface_U64Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotSurface_U64Ptr(label_id,xs,ys,zs,x_count,y_count,scale_min,scale_max,spec)
end
function M.ImPlot3D_PlotSurface(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot3D_PlotSurface_FloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot3D_PlotSurface_doublePtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot3D_PlotSurface_S8Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotSurface_U8Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotSurface_S16Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotSurface_U16Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotSurface_S32Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotSurface_U32Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotSurface_S64Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotSurface_U64Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.ImPlot3D_PlotSurface could not find overloaded'
end
function M.ImPlot3D_PlotText(text,x,y,z,angle,pix_offset)
    angle = angle or 0
    pix_offset = pix_offset or ImVec2(0,0)
    return lib.ImPlot3D_PlotText(text,x,y,z,angle,pix_offset)
end
M.ImPlot3D_PlotToPixels_Plot3DPoint = lib.ImPlot3D_PlotToPixels_Plot3DPoint
M.ImPlot3D_PlotToPixels_double = lib.ImPlot3D_PlotToPixels_double
function M.ImPlot3D_PlotToPixels(a1,a2,a3) -- generic version
    if ffi.istype('const ImPlot3DPoint',a1) then return M.ImPlot3D_PlotToPixels_Plot3DPoint(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot3D_PlotToPixels_double(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.ImPlot3D_PlotToPixels could not find overloaded'
end
function M.ImPlot3D_PlotTriangle_FloatPtr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotTriangle_FloatPtr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotTriangle_doublePtr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotTriangle_doublePtr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotTriangle_S8Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotTriangle_S8Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotTriangle_U8Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotTriangle_U8Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotTriangle_S16Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotTriangle_S16Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotTriangle_U16Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotTriangle_U16Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotTriangle_S32Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotTriangle_S32Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotTriangle_U32Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotTriangle_U32Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotTriangle_S64Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotTriangle_S64Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotTriangle_U64Ptr(label_id,xs,ys,zs,count,spec)
    spec = spec or M.ImPlot3DSpec()[0]
    return lib.ImPlot3D_PlotTriangle_U64Ptr(label_id,xs,ys,zs,count,spec)
end
function M.ImPlot3D_PlotTriangle(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot3D_PlotTriangle_FloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot3D_PlotTriangle_doublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot3D_PlotTriangle_S8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotTriangle_U8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotTriangle_S16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotTriangle_U16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotTriangle_S32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotTriangle_U32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotTriangle_S64Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot3D_PlotTriangle_U64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot3D_PlotTriangle could not find overloaded'
end
function M.ImPlot3D_PopColormap(count)
    count = count or 1
    return lib.ImPlot3D_PopColormap(count)
end
function M.ImPlot3D_PopStyleColor(count)
    count = count or 1
    return lib.ImPlot3D_PopStyleColor(count)
end
function M.ImPlot3D_PopStyleVar(count)
    count = count or 1
    return lib.ImPlot3D_PopStyleVar(count)
end
M.ImPlot3D_PushColormap_Plot3DColormap = lib.ImPlot3D_PushColormap_Plot3DColormap
M.ImPlot3D_PushColormap_Str = lib.ImPlot3D_PushColormap_Str
function M.ImPlot3D_PushColormap(a1) -- generic version
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImPlot3D_PushColormap_Plot3DColormap(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot3D_PushColormap_Str(a1) end
    print(a1)
    error'M.ImPlot3D_PushColormap could not find overloaded'
end
M.ImPlot3D_PushStyleColor_U32 = lib.ImPlot3D_PushStyleColor_U32
M.ImPlot3D_PushStyleColor_Vec4 = lib.ImPlot3D_PushStyleColor_Vec4
function M.ImPlot3D_PushStyleColor(a1,a2) -- generic version
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.ImPlot3D_PushStyleColor_U32(a1,a2) end
    if ffi.istype('const ImVec4',a2) then return M.ImPlot3D_PushStyleColor_Vec4(a1,a2) end
    print(a1,a2)
    error'M.ImPlot3D_PushStyleColor could not find overloaded'
end
M.ImPlot3D_PushStyleVar_Float = lib.ImPlot3D_PushStyleVar_Float
M.ImPlot3D_PushStyleVar_Int = lib.ImPlot3D_PushStyleVar_Int
M.ImPlot3D_PushStyleVar_Vec2 = lib.ImPlot3D_PushStyleVar_Vec2
function M.ImPlot3D_PushStyleVar(a1,a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.ImPlot3D_PushStyleVar_Float(a1,a2) end
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return M.ImPlot3D_PushStyleVar_Int(a1,a2) end
    if ffi.istype('const ImVec2',a2) then return M.ImPlot3D_PushStyleVar_Vec2(a1,a2) end
    print(a1,a2)
    error'M.ImPlot3D_PushStyleVar could not find overloaded'
end
function M.ImPlot3D_SampleColormap(t,cmap)
    cmap = cmap or -1
    return lib.ImPlot3D_SampleColormap(t,cmap)
end
M.ImPlot3D_SetCurrentContext = lib.ImPlot3D_SetCurrentContext
M.ImPlot3D_SetStyle = lib.ImPlot3D_SetStyle
function M.ImPlot3D_SetupAxes(x_label,y_label,z_label,x_flags,y_flags,z_flags)
    x_flags = x_flags or 0
    y_flags = y_flags or 0
    z_flags = z_flags or 0
    return lib.ImPlot3D_SetupAxes(x_label,y_label,z_label,x_flags,y_flags,z_flags)
end
function M.ImPlot3D_SetupAxesLimits(x_min,x_max,y_min,y_max,z_min,z_max,cond)
    cond = cond or 2
    return lib.ImPlot3D_SetupAxesLimits(x_min,x_max,y_min,y_max,z_min,z_max,cond)
end
function M.ImPlot3D_SetupAxis(axis,label,flags)
    flags = flags or 0
    label = label or nil
    return lib.ImPlot3D_SetupAxis(axis,label,flags)
end
function M.ImPlot3D_SetupAxisFormat(axis,formatter,data)
    data = data or nil
    return lib.ImPlot3D_SetupAxisFormat(axis,formatter,data)
end
function M.ImPlot3D_SetupAxisLimits(axis,v_min,v_max,cond)
    cond = cond or 2
    return lib.ImPlot3D_SetupAxisLimits(axis,v_min,v_max,cond)
end
M.ImPlot3D_SetupAxisLimitsConstraints = lib.ImPlot3D_SetupAxisLimitsConstraints
M.ImPlot3D_SetupAxisScale_Plot3DScale = lib.ImPlot3D_SetupAxisScale_Plot3DScale
function M.ImPlot3D_SetupAxisScale_Plot3DTransform(axis,forward,inverse,data)
    data = data or nil
    return lib.ImPlot3D_SetupAxisScale_Plot3DTransform(axis,forward,inverse,data)
end
function M.ImPlot3D_SetupAxisScale(a1,a2,a3,a4) -- generic version
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return M.ImPlot3D_SetupAxisScale_Plot3DScale(a1,a2) end
    if ffi.istype('ImPlot3DTransform',a2) then return M.ImPlot3D_SetupAxisScale_Plot3DTransform(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot3D_SetupAxisScale could not find overloaded'
end
function M.ImPlot3D_SetupAxisTicks_doublePtr(axis,values,n_ticks,labels,keep_default)
    keep_default = keep_default or false
    labels = labels or nil
    return lib.ImPlot3D_SetupAxisTicks_doublePtr(axis,values,n_ticks,labels,keep_default)
end
function M.ImPlot3D_SetupAxisTicks_double(axis,v_min,v_max,n_ticks,labels,keep_default)
    keep_default = keep_default or false
    labels = labels or nil
    return lib.ImPlot3D_SetupAxisTicks_double(axis,v_min,v_max,n_ticks,labels,keep_default)
end
function M.ImPlot3D_SetupAxisTicks(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot3D_SetupAxisTicks_doublePtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('double',a2) or type(a2)=='number') then return M.ImPlot3D_SetupAxisTicks_double(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot3D_SetupAxisTicks could not find overloaded'
end
M.ImPlot3D_SetupAxisZoomConstraints = lib.ImPlot3D_SetupAxisZoomConstraints
M.ImPlot3D_SetupBoxInitialRotation_double = lib.ImPlot3D_SetupBoxInitialRotation_double
M.ImPlot3D_SetupBoxInitialRotation_Plot3DQuat = lib.ImPlot3D_SetupBoxInitialRotation_Plot3DQuat
function M.ImPlot3D_SetupBoxInitialRotation(a1,a2) -- generic version
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot3D_SetupBoxInitialRotation_double(a1,a2) end
    if ffi.istype('ImPlot3DQuat',a1) then return M.ImPlot3D_SetupBoxInitialRotation_Plot3DQuat(a1) end
    print(a1,a2)
    error'M.ImPlot3D_SetupBoxInitialRotation could not find overloaded'
end
function M.ImPlot3D_SetupBoxRotation_double(elevation,azimuth,animate,cond)
    animate = animate or false
    cond = cond or 2
    return lib.ImPlot3D_SetupBoxRotation_double(elevation,azimuth,animate,cond)
end
function M.ImPlot3D_SetupBoxRotation_Plot3DQuat(rotation,animate,cond)
    animate = animate or false
    cond = cond or 2
    return lib.ImPlot3D_SetupBoxRotation_Plot3DQuat(rotation,animate,cond)
end
function M.ImPlot3D_SetupBoxRotation(a1,a2,a3,a4) -- generic version
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot3D_SetupBoxRotation_double(a1,a2,a3,a4) end
    if ffi.istype('ImPlot3DQuat',a1) then return M.ImPlot3D_SetupBoxRotation_Plot3DQuat(a1,a2,a3) end
    print(a1,a2,a3,a4)
    error'M.ImPlot3D_SetupBoxRotation could not find overloaded'
end
M.ImPlot3D_SetupBoxScale = lib.ImPlot3D_SetupBoxScale
function M.ImPlot3D_SetupLegend(location,flags)
    flags = flags or 0
    return lib.ImPlot3D_SetupLegend(location,flags)
end
function M.ImPlot3D_ShowAboutWindow(p_open)
    p_open = p_open or nil
    return lib.ImPlot3D_ShowAboutWindow(p_open)
end
M.ImPlot3D_ShowAllDemos = lib.ImPlot3D_ShowAllDemos
M.ImPlot3D_ShowColormapSelector = lib.ImPlot3D_ShowColormapSelector
function M.ImPlot3D_ShowDemoWindow(p_open)
    p_open = p_open or nil
    return lib.ImPlot3D_ShowDemoWindow(p_open)
end
function M.ImPlot3D_ShowMetricsWindow(p_popen)
    p_popen = p_popen or nil
    return lib.ImPlot3D_ShowMetricsWindow(p_popen)
end
function M.ImPlot3D_ShowStyleEditor(ref)
    ref = ref or nil
    return lib.ImPlot3D_ShowStyleEditor(ref)
end
M.ImPlot3D_ShowStyleSelector = lib.ImPlot3D_ShowStyleSelector
function M.ImPlot3D_StyleColorsAuto(dst)
    dst = dst or nil
    return lib.ImPlot3D_StyleColorsAuto(dst)
end
function M.ImPlot3D_StyleColorsClassic(dst)
    dst = dst or nil
    return lib.ImPlot3D_StyleColorsClassic(dst)
end
function M.ImPlot3D_StyleColorsDark(dst)
    dst = dst or nil
    return lib.ImPlot3D_StyleColorsDark(dst)
end
function M.ImPlot3D_StyleColorsLight(dst)
    dst = dst or nil
    return lib.ImPlot3D_StyleColorsLight(dst)
end
function M.ImPlot_AddColormap_Vec4Ptr(name,cols,size,qual)
    if qual == nil then qual = true end
    return lib.ImPlot_AddColormap_Vec4Ptr(name,cols,size,qual)
end
function M.ImPlot_AddColormap_U32Ptr(name,cols,size,qual)
    if qual == nil then qual = true end
    return lib.ImPlot_AddColormap_U32Ptr(name,cols,size,qual)
end
function M.ImPlot_AddColormap(a1,a2,a3,a4) -- generic version
    if (ffi.istype('const ImVec4*',a2) or ffi.istype('const ImVec4',a2) or ffi.istype('const ImVec4[]',a2)) then return M.ImPlot_AddColormap_Vec4Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_AddColormap_U32Ptr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_AddColormap could not find overloaded'
end
function M.ImPlot_AddLineH(draw_list,x1,x2,y,col,thickness)
    thickness = thickness or 1.0
    return lib.ImPlot_AddLineH(draw_list,x1,x2,y,col,thickness)
end
function M.ImPlot_AddLineV(draw_list,x,y1,y2,col,thickness)
    thickness = thickness or 1.0
    return lib.ImPlot_AddLineV(draw_list,x,y1,y2,col,thickness)
end
function M.ImPlot_AddTextCentered(DrawList,top_center,col,text_begin,text_end)
    text_end = text_end or nil
    return lib.ImPlot_AddTextCentered(DrawList,top_center,col,text_begin,text_end)
end
function M.ImPlot_AddTextVertical(DrawList,pos,col,text_begin,text_end)
    text_end = text_end or nil
    return lib.ImPlot_AddTextVertical(DrawList,pos,col,text_begin,text_end)
end
M.ImPlot_AddTime = lib.ImPlot_AddTime
M.ImPlot_AllAxesInputLocked = lib.ImPlot_AllAxesInputLocked
function M.ImPlot_Annotation_Bool(x,y,col,pix_offset,clamp,round)
    round = round or false
    return lib.ImPlot_Annotation_Bool(x,y,col,pix_offset,clamp,round)
end
M.ImPlot_Annotation_Str = lib.ImPlot_Annotation_Str
function M.ImPlot_Annotation(a1,a2,a3,a4,a5,a6,...) -- generic version
    if ((ffi.istype('bool',a6) or type(a6)=='boolean') or type(a6)=='nil') then return M.ImPlot_Annotation_Bool(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const char*',a6) or ffi.istype('char[]',a6) or type(a6)=='string') then return M.ImPlot_Annotation_Str(a1,a2,a3,a4,a5,a6,...) end
    print(a1,a2,a3,a4,a5,a6,...)
    error'M.ImPlot_Annotation could not find overloaded'
end
M.ImPlot_AnnotationV = lib.ImPlot_AnnotationV
M.ImPlot_AnyAxesHeld = lib.ImPlot_AnyAxesHeld
M.ImPlot_AnyAxesHovered = lib.ImPlot_AnyAxesHovered
M.ImPlot_AnyAxesInputLocked = lib.ImPlot_AnyAxesInputLocked
function M.ImPlot_BeginAlignedPlots(group_id,vertical)
    if vertical == nil then vertical = true end
    return lib.ImPlot_BeginAlignedPlots(group_id,vertical)
end
function M.ImPlot_BeginDragDropSourceAxis(axis,flags)
    flags = flags or 0
    return lib.ImPlot_BeginDragDropSourceAxis(axis,flags)
end
function M.ImPlot_BeginDragDropSourceItem(label_id,flags)
    flags = flags or 0
    return lib.ImPlot_BeginDragDropSourceItem(label_id,flags)
end
function M.ImPlot_BeginDragDropSourcePlot(flags)
    flags = flags or 0
    return lib.ImPlot_BeginDragDropSourcePlot(flags)
end
M.ImPlot_BeginDragDropTargetAxis = lib.ImPlot_BeginDragDropTargetAxis
M.ImPlot_BeginDragDropTargetLegend = lib.ImPlot_BeginDragDropTargetLegend
M.ImPlot_BeginDragDropTargetPlot = lib.ImPlot_BeginDragDropTargetPlot
function M.ImPlot_BeginItem(label_id,spec,item_col,item_mkr)
    item_col = item_col or M.ImVec4(0,0,0,-1)
    item_mkr = item_mkr or -3
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_BeginItem(label_id,spec,item_col,item_mkr)
end
function M.ImPlot_BeginLegendPopup(label_id,mouse_button)
    mouse_button = mouse_button or 1
    return lib.ImPlot_BeginLegendPopup(label_id,mouse_button)
end
function M.ImPlot_BeginPlot(title_id,size,flags)
    flags = flags or 0
    size = size or ImVec2(-1,0)
    return lib.ImPlot_BeginPlot(title_id,size,flags)
end
function M.ImPlot_BeginSubplots(title_id,rows,cols,size,flags,row_ratios,col_ratios)
    col_ratios = col_ratios or nil
    flags = flags or 0
    row_ratios = row_ratios or nil
    return lib.ImPlot_BeginSubplots(title_id,rows,cols,size,flags,row_ratios,col_ratios)
end
function M.ImPlot_BustColorCache(plot_title_id)
    plot_title_id = plot_title_id or nil
    return lib.ImPlot_BustColorCache(plot_title_id)
end
M.ImPlot_BustItemCache = lib.ImPlot_BustItemCache
M.ImPlot_BustPlotCache = lib.ImPlot_BustPlotCache
M.ImPlot_CalcHoverColor = lib.ImPlot_CalcHoverColor
M.ImPlot_CalcLegendSize = lib.ImPlot_CalcLegendSize
M.ImPlot_CalcTextColor_Vec4 = lib.ImPlot_CalcTextColor_Vec4
M.ImPlot_CalcTextColor_U32 = lib.ImPlot_CalcTextColor_U32
function M.ImPlot_CalcTextColor(a1) -- generic version
    if ffi.istype('const ImVec4',a1) then return M.ImPlot_CalcTextColor_Vec4(a1) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.ImPlot_CalcTextColor_U32(a1) end
    print(a1)
    error'M.ImPlot_CalcTextColor could not find overloaded'
end
M.ImPlot_CalcTextSizeVertical = lib.ImPlot_CalcTextSizeVertical
M.ImPlot_CancelPlotSelection = lib.ImPlot_CancelPlotSelection
M.ImPlot_CeilTime = lib.ImPlot_CeilTime
M.ImPlot_ClampLabelPos = lib.ImPlot_ClampLabelPos
M.ImPlot_ClampLegendRect = lib.ImPlot_ClampLegendRect
function M.ImPlot_ColormapButton(label,size,cmap)
    cmap = cmap or -1
    size = size or ImVec2(0,0)
    return lib.ImPlot_ColormapButton(label,size,cmap)
end
M.ImPlot_ColormapIcon = lib.ImPlot_ColormapIcon
function M.ImPlot_ColormapScale(label,scale_min,scale_max,size,format,flags,cmap)
    cmap = cmap or -1
    flags = flags or 0
    format = format or "%g"
    size = size or ImVec2(0,0)
    return lib.ImPlot_ColormapScale(label,scale_min,scale_max,size,format,flags,cmap)
end
function M.ImPlot_ColormapSlider(label,t,out,format,cmap)
    cmap = cmap or -1
    format = format or ""
    out = out or nil
    return lib.ImPlot_ColormapSlider(label,t,out,format,cmap)
end
M.ImPlot_CombineDateTime = lib.ImPlot_CombineDateTime
M.ImPlot_CreateContext = lib.ImPlot_CreateContext
function M.ImPlot_DestroyContext(ctx)
    ctx = ctx or nil
    return lib.ImPlot_DestroyContext(ctx)
end
function M.ImPlot_DragLineX(id,x,col,thickness,flags,out_clicked,out_hovered,out_held)
    flags = flags or 0
    out_clicked = out_clicked or nil
    out_held = out_held or nil
    out_hovered = out_hovered or nil
    thickness = thickness or 1
    return lib.ImPlot_DragLineX(id,x,col,thickness,flags,out_clicked,out_hovered,out_held)
end
function M.ImPlot_DragLineY(id,y,col,thickness,flags,out_clicked,out_hovered,out_held)
    flags = flags or 0
    out_clicked = out_clicked or nil
    out_held = out_held or nil
    out_hovered = out_hovered or nil
    thickness = thickness or 1
    return lib.ImPlot_DragLineY(id,y,col,thickness,flags,out_clicked,out_hovered,out_held)
end
function M.ImPlot_DragPoint(id,x,y,col,size,flags,out_clicked,out_hovered,out_held)
    flags = flags or 0
    out_clicked = out_clicked or nil
    out_held = out_held or nil
    out_hovered = out_hovered or nil
    size = size or 4
    return lib.ImPlot_DragPoint(id,x,y,col,size,flags,out_clicked,out_hovered,out_held)
end
function M.ImPlot_DragRect(id,x1,y1,x2,y2,col,flags,out_clicked,out_hovered,out_held)
    flags = flags or 0
    out_clicked = out_clicked or nil
    out_held = out_held or nil
    out_hovered = out_hovered or nil
    return lib.ImPlot_DragRect(id,x1,y1,x2,y2,col,flags,out_clicked,out_hovered,out_held)
end
M.ImPlot_EndAlignedPlots = lib.ImPlot_EndAlignedPlots
M.ImPlot_EndDragDropSource = lib.ImPlot_EndDragDropSource
M.ImPlot_EndDragDropTarget = lib.ImPlot_EndDragDropTarget
M.ImPlot_EndItem = lib.ImPlot_EndItem
M.ImPlot_EndLegendPopup = lib.ImPlot_EndLegendPopup
M.ImPlot_EndPlot = lib.ImPlot_EndPlot
M.ImPlot_EndSubplots = lib.ImPlot_EndSubplots
M.ImPlot_FillRange_Vector_Float_Ptr = lib.ImPlot_FillRange_Vector_Float_Ptr
M.ImPlot_FillRange_Vector_double_Ptr = lib.ImPlot_FillRange_Vector_double_Ptr
M.ImPlot_FillRange_Vector_S8_Ptr = lib.ImPlot_FillRange_Vector_S8_Ptr
M.ImPlot_FillRange_Vector_U8_Ptr = lib.ImPlot_FillRange_Vector_U8_Ptr
M.ImPlot_FillRange_Vector_S16_Ptr = lib.ImPlot_FillRange_Vector_S16_Ptr
M.ImPlot_FillRange_Vector_U16_Ptr = lib.ImPlot_FillRange_Vector_U16_Ptr
M.ImPlot_FillRange_Vector_S32_Ptr = lib.ImPlot_FillRange_Vector_S32_Ptr
M.ImPlot_FillRange_Vector_U32_Ptr = lib.ImPlot_FillRange_Vector_U32_Ptr
M.ImPlot_FillRange_Vector_S64_Ptr = lib.ImPlot_FillRange_Vector_S64_Ptr
M.ImPlot_FillRange_Vector_U64_Ptr = lib.ImPlot_FillRange_Vector_U64_Ptr
function M.ImPlot_FillRange(a1,a2,a3,a4) -- generic version
    if (ffi.istype('ImVector_float *',a1) or ffi.istype('ImVector_float ',a1) or ffi.istype('ImVector_float []',a1)) then return M.ImPlot_FillRange_Vector_Float_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_double *',a1) or ffi.istype('ImVector_double ',a1) or ffi.istype('ImVector_double []',a1)) then return M.ImPlot_FillRange_Vector_double_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImS8 *',a1) or ffi.istype('ImVector_ImS8 ',a1) or ffi.istype('ImVector_ImS8 []',a1)) then return M.ImPlot_FillRange_Vector_S8_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImU8 *',a1) or ffi.istype('ImVector_ImU8 ',a1) or ffi.istype('ImVector_ImU8 []',a1)) then return M.ImPlot_FillRange_Vector_U8_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImS16 *',a1) or ffi.istype('ImVector_ImS16 ',a1) or ffi.istype('ImVector_ImS16 []',a1)) then return M.ImPlot_FillRange_Vector_S16_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImU16 *',a1) or ffi.istype('ImVector_ImU16 ',a1) or ffi.istype('ImVector_ImU16 []',a1)) then return M.ImPlot_FillRange_Vector_U16_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImS32 *',a1) or ffi.istype('ImVector_ImS32 ',a1) or ffi.istype('ImVector_ImS32 []',a1)) then return M.ImPlot_FillRange_Vector_S32_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImU32 *',a1) or ffi.istype('ImVector_ImU32 ',a1) or ffi.istype('ImVector_ImU32 []',a1)) then return M.ImPlot_FillRange_Vector_U32_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImS64 *',a1) or ffi.istype('ImVector_ImS64 ',a1) or ffi.istype('ImVector_ImS64 []',a1)) then return M.ImPlot_FillRange_Vector_S64_Ptr(a1,a2,a3,a4) end
    if (ffi.istype('ImVector_ImU64 *',a1) or ffi.istype('ImVector_ImU64 ',a1) or ffi.istype('ImVector_ImU64 []',a1)) then return M.ImPlot_FillRange_Vector_U64_Ptr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_FillRange could not find overloaded'
end
M.ImPlot_FitPoint = lib.ImPlot_FitPoint
M.ImPlot_FitPointX = lib.ImPlot_FitPointX
M.ImPlot_FitPointY = lib.ImPlot_FitPointY
M.ImPlot_FitThisFrame = lib.ImPlot_FitThisFrame
M.ImPlot_FloorTime = lib.ImPlot_FloorTime
M.ImPlot_FormatDate = lib.ImPlot_FormatDate
M.ImPlot_FormatDateTime = lib.ImPlot_FormatDateTime
M.ImPlot_FormatTime = lib.ImPlot_FormatTime
M.ImPlot_Formatter_Default = lib.ImPlot_Formatter_Default
M.ImPlot_Formatter_Logit = lib.ImPlot_Formatter_Logit
M.ImPlot_Formatter_Time = lib.ImPlot_Formatter_Time
M.ImPlot_GetAutoColor = lib.ImPlot_GetAutoColor
function M.ImPlot_GetColormapColor(idx,cmap)
    cmap = cmap or -1
    return lib.ImPlot_GetColormapColor(idx,cmap)
end
M.ImPlot_GetColormapColorU32 = lib.ImPlot_GetColormapColorU32
M.ImPlot_GetColormapCount = lib.ImPlot_GetColormapCount
M.ImPlot_GetColormapIndex = lib.ImPlot_GetColormapIndex
M.ImPlot_GetColormapName = lib.ImPlot_GetColormapName
function M.ImPlot_GetColormapSize(cmap)
    cmap = cmap or -1
    return lib.ImPlot_GetColormapSize(cmap)
end
M.ImPlot_GetCurrentContext = lib.ImPlot_GetCurrentContext
M.ImPlot_GetCurrentItem = lib.ImPlot_GetCurrentItem
M.ImPlot_GetCurrentPlot = lib.ImPlot_GetCurrentPlot
M.ImPlot_GetDaysInMonth = lib.ImPlot_GetDaysInMonth
M.ImPlot_GetGmtTime = lib.ImPlot_GetGmtTime
M.ImPlot_GetInputMap = lib.ImPlot_GetInputMap
M.ImPlot_GetItem = lib.ImPlot_GetItem
M.ImPlot_GetItemData = lib.ImPlot_GetItemData
M.ImPlot_GetLastItemColor = lib.ImPlot_GetLastItemColor
M.ImPlot_GetLocTime = lib.ImPlot_GetLocTime
function M.ImPlot_GetLocationPos(outer_rect,inner_size,location,pad)
    pad = pad or ImVec2(0,0)
    return lib.ImPlot_GetLocationPos(outer_rect,inner_size,location,pad)
end
M.ImPlot_GetMarkerName = lib.ImPlot_GetMarkerName
M.ImPlot_GetMonth = lib.ImPlot_GetMonth
M.ImPlot_GetPlot = lib.ImPlot_GetPlot
M.ImPlot_GetPlotDrawList = lib.ImPlot_GetPlotDrawList
function M.ImPlot_GetPlotLimits(x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    return lib.ImPlot_GetPlotLimits(x_axis,y_axis)
end
function M.ImPlot_GetPlotMousePos(x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    return lib.ImPlot_GetPlotMousePos(x_axis,y_axis)
end
M.ImPlot_GetPlotPos = lib.ImPlot_GetPlotPos
function M.ImPlot_GetPlotSelection(x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    return lib.ImPlot_GetPlotSelection(x_axis,y_axis)
end
M.ImPlot_GetPlotSize = lib.ImPlot_GetPlotSize
M.ImPlot_GetStyle = lib.ImPlot_GetStyle
M.ImPlot_GetStyleColorName = lib.ImPlot_GetStyleColorName
M.ImPlot_GetStyleColorU32 = lib.ImPlot_GetStyleColorU32
M.ImPlot_GetStyleColorVec4 = lib.ImPlot_GetStyleColorVec4
M.ImPlot_GetTime = lib.ImPlot_GetTime
M.ImPlot_GetYear = lib.ImPlot_GetYear
function M.ImPlot_HideNextItem(hidden,cond)
    cond = cond or 2
    if hidden == nil then hidden = true end
    return lib.ImPlot_HideNextItem(hidden,cond)
end
function M.ImPlot_ImAlmostEqual(v1,v2,ulp)
    ulp = ulp or 2
    return lib.ImPlot_ImAlmostEqual(v1,v2,ulp)
end
M.ImPlot_ImAlphaU32 = lib.ImPlot_ImAlphaU32
M.ImPlot_ImAsinh_Float = lib.ImPlot_ImAsinh_Float
M.ImPlot_ImAsinh_double = lib.ImPlot_ImAsinh_double
function M.ImPlot_ImAsinh(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_ImAsinh_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_ImAsinh_double(a1) end
    print(a1)
    error'M.ImPlot_ImAsinh could not find overloaded'
end
M.ImPlot_ImConstrainInf = lib.ImPlot_ImConstrainInf
M.ImPlot_ImConstrainLog = lib.ImPlot_ImConstrainLog
M.ImPlot_ImConstrainNan = lib.ImPlot_ImConstrainNan
M.ImPlot_ImConstrainTime = lib.ImPlot_ImConstrainTime
M.ImPlot_ImDoubleBits = lib.ImPlot_ImDoubleBits
M.ImPlot_ImLerpU32 = lib.ImPlot_ImLerpU32
M.ImPlot_ImLog10_Float = lib.ImPlot_ImLog10_Float
M.ImPlot_ImLog10_double = lib.ImPlot_ImLog10_double
function M.ImPlot_ImLog10(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_ImLog10_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_ImLog10_double(a1) end
    print(a1)
    error'M.ImPlot_ImLog10 could not find overloaded'
end
M.ImPlot_ImMaxArray_FloatPtr = lib.ImPlot_ImMaxArray_FloatPtr
M.ImPlot_ImMaxArray_doublePtr = lib.ImPlot_ImMaxArray_doublePtr
M.ImPlot_ImMaxArray_S8Ptr = lib.ImPlot_ImMaxArray_S8Ptr
M.ImPlot_ImMaxArray_U8Ptr = lib.ImPlot_ImMaxArray_U8Ptr
M.ImPlot_ImMaxArray_S16Ptr = lib.ImPlot_ImMaxArray_S16Ptr
M.ImPlot_ImMaxArray_U16Ptr = lib.ImPlot_ImMaxArray_U16Ptr
M.ImPlot_ImMaxArray_S32Ptr = lib.ImPlot_ImMaxArray_S32Ptr
M.ImPlot_ImMaxArray_U32Ptr = lib.ImPlot_ImMaxArray_U32Ptr
M.ImPlot_ImMaxArray_S64Ptr = lib.ImPlot_ImMaxArray_S64Ptr
M.ImPlot_ImMaxArray_U64Ptr = lib.ImPlot_ImMaxArray_U64Ptr
function M.ImPlot_ImMaxArray(a1,a2) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_ImMaxArray_FloatPtr(a1,a2) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_ImMaxArray_doublePtr(a1,a2) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_ImMaxArray_S8Ptr(a1,a2) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_U8Ptr(a1,a2) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_S16Ptr(a1,a2) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_U16Ptr(a1,a2) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_S32Ptr(a1,a2) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_U32Ptr(a1,a2) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_S64Ptr(a1,a2) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMaxArray_U64Ptr(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_ImMaxArray could not find overloaded'
end
M.ImPlot_ImMean_FloatPtr = lib.ImPlot_ImMean_FloatPtr
M.ImPlot_ImMean_doublePtr = lib.ImPlot_ImMean_doublePtr
M.ImPlot_ImMean_S8Ptr = lib.ImPlot_ImMean_S8Ptr
M.ImPlot_ImMean_U8Ptr = lib.ImPlot_ImMean_U8Ptr
M.ImPlot_ImMean_S16Ptr = lib.ImPlot_ImMean_S16Ptr
M.ImPlot_ImMean_U16Ptr = lib.ImPlot_ImMean_U16Ptr
M.ImPlot_ImMean_S32Ptr = lib.ImPlot_ImMean_S32Ptr
M.ImPlot_ImMean_U32Ptr = lib.ImPlot_ImMean_U32Ptr
M.ImPlot_ImMean_S64Ptr = lib.ImPlot_ImMean_S64Ptr
M.ImPlot_ImMean_U64Ptr = lib.ImPlot_ImMean_U64Ptr
function M.ImPlot_ImMean(a1,a2) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_ImMean_FloatPtr(a1,a2) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_ImMean_doublePtr(a1,a2) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_ImMean_S8Ptr(a1,a2) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_U8Ptr(a1,a2) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_S16Ptr(a1,a2) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_U16Ptr(a1,a2) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_S32Ptr(a1,a2) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_U32Ptr(a1,a2) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_S64Ptr(a1,a2) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMean_U64Ptr(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_ImMean could not find overloaded'
end
M.ImPlot_ImMinArray_FloatPtr = lib.ImPlot_ImMinArray_FloatPtr
M.ImPlot_ImMinArray_doublePtr = lib.ImPlot_ImMinArray_doublePtr
M.ImPlot_ImMinArray_S8Ptr = lib.ImPlot_ImMinArray_S8Ptr
M.ImPlot_ImMinArray_U8Ptr = lib.ImPlot_ImMinArray_U8Ptr
M.ImPlot_ImMinArray_S16Ptr = lib.ImPlot_ImMinArray_S16Ptr
M.ImPlot_ImMinArray_U16Ptr = lib.ImPlot_ImMinArray_U16Ptr
M.ImPlot_ImMinArray_S32Ptr = lib.ImPlot_ImMinArray_S32Ptr
M.ImPlot_ImMinArray_U32Ptr = lib.ImPlot_ImMinArray_U32Ptr
M.ImPlot_ImMinArray_S64Ptr = lib.ImPlot_ImMinArray_S64Ptr
M.ImPlot_ImMinArray_U64Ptr = lib.ImPlot_ImMinArray_U64Ptr
function M.ImPlot_ImMinArray(a1,a2) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_ImMinArray_FloatPtr(a1,a2) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_ImMinArray_doublePtr(a1,a2) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_ImMinArray_S8Ptr(a1,a2) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_U8Ptr(a1,a2) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_S16Ptr(a1,a2) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_U16Ptr(a1,a2) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_S32Ptr(a1,a2) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_U32Ptr(a1,a2) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_S64Ptr(a1,a2) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinArray_U64Ptr(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_ImMinArray could not find overloaded'
end
M.ImPlot_ImMinMaxArray_FloatPtr = lib.ImPlot_ImMinMaxArray_FloatPtr
M.ImPlot_ImMinMaxArray_doublePtr = lib.ImPlot_ImMinMaxArray_doublePtr
M.ImPlot_ImMinMaxArray_S8Ptr = lib.ImPlot_ImMinMaxArray_S8Ptr
M.ImPlot_ImMinMaxArray_U8Ptr = lib.ImPlot_ImMinMaxArray_U8Ptr
M.ImPlot_ImMinMaxArray_S16Ptr = lib.ImPlot_ImMinMaxArray_S16Ptr
M.ImPlot_ImMinMaxArray_U16Ptr = lib.ImPlot_ImMinMaxArray_U16Ptr
M.ImPlot_ImMinMaxArray_S32Ptr = lib.ImPlot_ImMinMaxArray_S32Ptr
M.ImPlot_ImMinMaxArray_U32Ptr = lib.ImPlot_ImMinMaxArray_U32Ptr
M.ImPlot_ImMinMaxArray_S64Ptr = lib.ImPlot_ImMinMaxArray_S64Ptr
M.ImPlot_ImMinMaxArray_U64Ptr = lib.ImPlot_ImMinMaxArray_U64Ptr
function M.ImPlot_ImMinMaxArray(a1,a2,a3,a4) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_ImMinMaxArray_FloatPtr(a1,a2,a3,a4) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_ImMinMaxArray_doublePtr(a1,a2,a3,a4) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_ImMinMaxArray_S8Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_U8Ptr(a1,a2,a3,a4) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_S16Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_U16Ptr(a1,a2,a3,a4) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_S32Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_U32Ptr(a1,a2,a3,a4) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_S64Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImMinMaxArray_U64Ptr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_ImMinMaxArray could not find overloaded'
end
M.ImPlot_ImMixU32 = lib.ImPlot_ImMixU32
M.ImPlot_ImNan = lib.ImPlot_ImNan
M.ImPlot_ImNanOrInf = lib.ImPlot_ImNanOrInf
M.ImPlot_ImOverlaps_Float = lib.ImPlot_ImOverlaps_Float
M.ImPlot_ImOverlaps_double = lib.ImPlot_ImOverlaps_double
M.ImPlot_ImOverlaps_S8 = lib.ImPlot_ImOverlaps_S8
M.ImPlot_ImOverlaps_U8 = lib.ImPlot_ImOverlaps_U8
M.ImPlot_ImOverlaps_S16 = lib.ImPlot_ImOverlaps_S16
M.ImPlot_ImOverlaps_U16 = lib.ImPlot_ImOverlaps_U16
M.ImPlot_ImOverlaps_S32 = lib.ImPlot_ImOverlaps_S32
M.ImPlot_ImOverlaps_U32 = lib.ImPlot_ImOverlaps_U32
M.ImPlot_ImOverlaps_S64 = lib.ImPlot_ImOverlaps_S64
M.ImPlot_ImOverlaps_U64 = lib.ImPlot_ImOverlaps_U64
function M.ImPlot_ImOverlaps(a1,a2,a3,a4) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_Float(a1,a2,a3,a4) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_double(a1,a2,a3,a4) end
    if (ffi.istype('int8_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_S8(a1,a2,a3,a4) end
    if (ffi.istype('uint8_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_U8(a1,a2,a3,a4) end
    if (ffi.istype('int16_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_S16(a1,a2,a3,a4) end
    if (ffi.istype('uint16_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_U16(a1,a2,a3,a4) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_S32(a1,a2,a3,a4) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_U32(a1,a2,a3,a4) end
    if (ffi.istype('int64_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_S64(a1,a2,a3,a4) end
    if (ffi.istype('uint64_t',a1) or type(a1)=='number') then return M.ImPlot_ImOverlaps_U64(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_ImOverlaps could not find overloaded'
end
M.ImPlot_ImPosMod = lib.ImPlot_ImPosMod
M.ImPlot_ImRemap_Float = lib.ImPlot_ImRemap_Float
M.ImPlot_ImRemap_double = lib.ImPlot_ImRemap_double
M.ImPlot_ImRemap_S8 = lib.ImPlot_ImRemap_S8
M.ImPlot_ImRemap_U8 = lib.ImPlot_ImRemap_U8
M.ImPlot_ImRemap_S16 = lib.ImPlot_ImRemap_S16
M.ImPlot_ImRemap_U16 = lib.ImPlot_ImRemap_U16
M.ImPlot_ImRemap_S32 = lib.ImPlot_ImRemap_S32
M.ImPlot_ImRemap_U32 = lib.ImPlot_ImRemap_U32
M.ImPlot_ImRemap_S64 = lib.ImPlot_ImRemap_S64
M.ImPlot_ImRemap_U64 = lib.ImPlot_ImRemap_U64
function M.ImPlot_ImRemap(a1,a2,a3,a4,a5) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_Float(a1,a2,a3,a4,a5) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_double(a1,a2,a3,a4,a5) end
    if (ffi.istype('int8_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_S8(a1,a2,a3,a4,a5) end
    if (ffi.istype('uint8_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_U8(a1,a2,a3,a4,a5) end
    if (ffi.istype('int16_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_S16(a1,a2,a3,a4,a5) end
    if (ffi.istype('uint16_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_U16(a1,a2,a3,a4,a5) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_S32(a1,a2,a3,a4,a5) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_U32(a1,a2,a3,a4,a5) end
    if (ffi.istype('int64_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_S64(a1,a2,a3,a4,a5) end
    if (ffi.istype('uint64_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap_U64(a1,a2,a3,a4,a5) end
    print(a1,a2,a3,a4,a5)
    error'M.ImPlot_ImRemap could not find overloaded'
end
M.ImPlot_ImRemap01_Float = lib.ImPlot_ImRemap01_Float
M.ImPlot_ImRemap01_double = lib.ImPlot_ImRemap01_double
M.ImPlot_ImRemap01_S8 = lib.ImPlot_ImRemap01_S8
M.ImPlot_ImRemap01_U8 = lib.ImPlot_ImRemap01_U8
M.ImPlot_ImRemap01_S16 = lib.ImPlot_ImRemap01_S16
M.ImPlot_ImRemap01_U16 = lib.ImPlot_ImRemap01_U16
M.ImPlot_ImRemap01_S32 = lib.ImPlot_ImRemap01_S32
M.ImPlot_ImRemap01_U32 = lib.ImPlot_ImRemap01_U32
M.ImPlot_ImRemap01_S64 = lib.ImPlot_ImRemap01_S64
M.ImPlot_ImRemap01_U64 = lib.ImPlot_ImRemap01_U64
function M.ImPlot_ImRemap01(a1,a2,a3) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_Float(a1,a2,a3) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_double(a1,a2,a3) end
    if (ffi.istype('int8_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_S8(a1,a2,a3) end
    if (ffi.istype('uint8_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_U8(a1,a2,a3) end
    if (ffi.istype('int16_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_S16(a1,a2,a3) end
    if (ffi.istype('uint16_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_U16(a1,a2,a3) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_S32(a1,a2,a3) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_U32(a1,a2,a3) end
    if (ffi.istype('int64_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_S64(a1,a2,a3) end
    if (ffi.istype('uint64_t',a1) or type(a1)=='number') then return M.ImPlot_ImRemap01_U64(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.ImPlot_ImRemap01 could not find overloaded'
end
M.ImPlot_ImSinh_Float = lib.ImPlot_ImSinh_Float
M.ImPlot_ImSinh_double = lib.ImPlot_ImSinh_double
function M.ImPlot_ImSinh(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_ImSinh_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_ImSinh_double(a1) end
    print(a1)
    error'M.ImPlot_ImSinh could not find overloaded'
end
M.ImPlot_ImStdDev_FloatPtr = lib.ImPlot_ImStdDev_FloatPtr
M.ImPlot_ImStdDev_doublePtr = lib.ImPlot_ImStdDev_doublePtr
M.ImPlot_ImStdDev_S8Ptr = lib.ImPlot_ImStdDev_S8Ptr
M.ImPlot_ImStdDev_U8Ptr = lib.ImPlot_ImStdDev_U8Ptr
M.ImPlot_ImStdDev_S16Ptr = lib.ImPlot_ImStdDev_S16Ptr
M.ImPlot_ImStdDev_U16Ptr = lib.ImPlot_ImStdDev_U16Ptr
M.ImPlot_ImStdDev_S32Ptr = lib.ImPlot_ImStdDev_S32Ptr
M.ImPlot_ImStdDev_U32Ptr = lib.ImPlot_ImStdDev_U32Ptr
M.ImPlot_ImStdDev_S64Ptr = lib.ImPlot_ImStdDev_S64Ptr
M.ImPlot_ImStdDev_U64Ptr = lib.ImPlot_ImStdDev_U64Ptr
function M.ImPlot_ImStdDev(a1,a2) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_ImStdDev_FloatPtr(a1,a2) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_ImStdDev_doublePtr(a1,a2) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_ImStdDev_S8Ptr(a1,a2) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_U8Ptr(a1,a2) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_S16Ptr(a1,a2) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_U16Ptr(a1,a2) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_S32Ptr(a1,a2) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_U32Ptr(a1,a2) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_S64Ptr(a1,a2) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImStdDev_U64Ptr(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_ImStdDev could not find overloaded'
end
M.ImPlot_ImSum_FloatPtr = lib.ImPlot_ImSum_FloatPtr
M.ImPlot_ImSum_doublePtr = lib.ImPlot_ImSum_doublePtr
M.ImPlot_ImSum_S8Ptr = lib.ImPlot_ImSum_S8Ptr
M.ImPlot_ImSum_U8Ptr = lib.ImPlot_ImSum_U8Ptr
M.ImPlot_ImSum_S16Ptr = lib.ImPlot_ImSum_S16Ptr
M.ImPlot_ImSum_U16Ptr = lib.ImPlot_ImSum_U16Ptr
M.ImPlot_ImSum_S32Ptr = lib.ImPlot_ImSum_S32Ptr
M.ImPlot_ImSum_U32Ptr = lib.ImPlot_ImSum_U32Ptr
M.ImPlot_ImSum_S64Ptr = lib.ImPlot_ImSum_S64Ptr
M.ImPlot_ImSum_U64Ptr = lib.ImPlot_ImSum_U64Ptr
function M.ImPlot_ImSum(a1,a2) -- generic version
    if (ffi.istype('float*',a1) or ffi.istype('float[]',a1)) then return M.ImPlot_ImSum_FloatPtr(a1,a2) end
    if (ffi.istype('double*',a1) or ffi.istype('double[]',a1)) then return M.ImPlot_ImSum_doublePtr(a1,a2) end
    if (ffi.istype('const ImS8*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_ImSum_S8Ptr(a1,a2) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a1) or ffi.typeof('const uint8_t*') == ffi.typeof(a1) or ffi.typeof('uint8_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_U8Ptr(a1,a2) end
    if ffi.typeof('int16_t*') == ffi.typeof(a1) or ffi.typeof('const int16_t*') == ffi.typeof(a1) or ffi.typeof('int16_t[?]') == ffi.typeof(a1) or ffi.typeof('const int16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_S16Ptr(a1,a2) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a1) or ffi.typeof('const uint16_t*') == ffi.typeof(a1) or ffi.typeof('uint16_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_U16Ptr(a1,a2) end
    if ffi.typeof('int32_t*') == ffi.typeof(a1) or ffi.typeof('const int32_t*') == ffi.typeof(a1) or ffi.typeof('int32_t[?]') == ffi.typeof(a1) or ffi.typeof('const int32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_S32Ptr(a1,a2) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a1) or ffi.typeof('const uint32_t*') == ffi.typeof(a1) or ffi.typeof('uint32_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_U32Ptr(a1,a2) end
    if ffi.typeof('int64_t*') == ffi.typeof(a1) or ffi.typeof('const int64_t*') == ffi.typeof(a1) or ffi.typeof('int64_t[?]') == ffi.typeof(a1) or ffi.typeof('const int64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_S64Ptr(a1,a2) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a1) or ffi.typeof('const uint64_t*') == ffi.typeof(a1) or ffi.typeof('uint64_t[?]') == ffi.typeof(a1) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a1) then return M.ImPlot_ImSum_U64Ptr(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_ImSum could not find overloaded'
end
M.ImPlot_Initialize = lib.ImPlot_Initialize
M.ImPlot_Intersection = lib.ImPlot_Intersection
M.ImPlot_IsAxisHovered = lib.ImPlot_IsAxisHovered
M.ImPlot_IsColorAuto_Vec4 = lib.ImPlot_IsColorAuto_Vec4
M.ImPlot_IsColorAuto_PlotCol = lib.ImPlot_IsColorAuto_PlotCol
function M.ImPlot_IsColorAuto(a1) -- generic version
    if ffi.istype('const ImVec4',a1) then return M.ImPlot_IsColorAuto_Vec4(a1) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImPlot_IsColorAuto_PlotCol(a1) end
    print(a1)
    error'M.ImPlot_IsColorAuto could not find overloaded'
end
M.ImPlot_IsItemHidden = lib.ImPlot_IsItemHidden
M.ImPlot_IsLastItemHidden = lib.ImPlot_IsLastItemHidden
M.ImPlot_IsLeapYear = lib.ImPlot_IsLeapYear
M.ImPlot_IsLegendEntryHovered = lib.ImPlot_IsLegendEntryHovered
M.ImPlot_IsPlotHovered = lib.ImPlot_IsPlotHovered
M.ImPlot_IsPlotSelected = lib.ImPlot_IsPlotSelected
M.ImPlot_IsSubplotsHovered = lib.ImPlot_IsSubplotsHovered
M.ImPlot_ItemIcon_Vec4 = lib.ImPlot_ItemIcon_Vec4
M.ImPlot_ItemIcon_U32 = lib.ImPlot_ItemIcon_U32
function M.ImPlot_ItemIcon(a1) -- generic version
    if ffi.istype('const ImVec4',a1) then return M.ImPlot_ItemIcon_Vec4(a1) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.ImPlot_ItemIcon_U32(a1) end
    print(a1)
    error'M.ImPlot_ItemIcon could not find overloaded'
end
function M.ImPlot_LabelAxisValue(axis,value,buff,size,round)
    round = round or false
    return lib.ImPlot_LabelAxisValue(axis,value,buff,size,round)
end
M.ImPlot_Locator_Default = lib.ImPlot_Locator_Default
M.ImPlot_Locator_Log10 = lib.ImPlot_Locator_Log10
M.ImPlot_Locator_SymLog = lib.ImPlot_Locator_SymLog
M.ImPlot_Locator_Time = lib.ImPlot_Locator_Time
function M.ImPlot_MakeTime(year,month,day,hour,min,sec,us)
    day = day or 1
    hour = hour or 0
    min = min or 0
    month = month or 0
    sec = sec or 0
    us = us or 0
    return lib.ImPlot_MakeTime(year,month,day,hour,min,sec,us)
end
function M.ImPlot_MapInputDefault(dst)
    dst = dst or nil
    return lib.ImPlot_MapInputDefault(dst)
end
function M.ImPlot_MapInputReverse(dst)
    dst = dst or nil
    return lib.ImPlot_MapInputReverse(dst)
end
M.ImPlot_MkGmtTime = lib.ImPlot_MkGmtTime
M.ImPlot_MkLocTime = lib.ImPlot_MkLocTime
M.ImPlot_MkTime = lib.ImPlot_MkTime
M.ImPlot_NextColormapColor = lib.ImPlot_NextColormapColor
M.ImPlot_NextColormapColorU32 = lib.ImPlot_NextColormapColorU32
M.ImPlot_NextMarker = lib.ImPlot_NextMarker
M.ImPlot_NiceNum = lib.ImPlot_NiceNum
M.ImPlot_Now = lib.ImPlot_Now
M.ImPlot_OrderOfMagnitude = lib.ImPlot_OrderOfMagnitude
M.ImPlot_OrderToPrecision = lib.ImPlot_OrderToPrecision
function M.ImPlot_PixelsToPlot_Vec2(pix,x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    return lib.ImPlot_PixelsToPlot_Vec2(pix,x_axis,y_axis)
end
function M.ImPlot_PixelsToPlot_Float(x,y,x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    return lib.ImPlot_PixelsToPlot_Float(x,y,x_axis,y_axis)
end
function M.ImPlot_PixelsToPlot(a1,a2,a3,a4) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.ImPlot_PixelsToPlot_Vec2(a1,a2,a3) end
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPlot_PixelsToPlot_Float(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_PixelsToPlot could not find overloaded'
end
function M.ImPlot_PlotBarGroups_FloatPtr(label_ids,values,item_count,group_count,group_size,shift,spec)
    group_size = group_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBarGroups_FloatPtr(label_ids,values,item_count,group_count,group_size,shift,spec)
end
function M.ImPlot_PlotBarGroups_doublePtr(label_ids,values,item_count,group_count,group_size,shift,spec)
    group_size = group_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBarGroups_doublePtr(label_ids,values,item_count,group_count,group_size,shift,spec)
end
function M.ImPlot_PlotBarGroups_S8Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
    group_size = group_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBarGroups_S8Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
end
function M.ImPlot_PlotBarGroups_U8Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
    group_size = group_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBarGroups_U8Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
end
function M.ImPlot_PlotBarGroups_S16Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
    group_size = group_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBarGroups_S16Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
end
function M.ImPlot_PlotBarGroups_U16Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
    group_size = group_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBarGroups_U16Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
end
function M.ImPlot_PlotBarGroups_S32Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
    group_size = group_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBarGroups_S32Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
end
function M.ImPlot_PlotBarGroups_U32Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
    group_size = group_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBarGroups_U32Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
end
function M.ImPlot_PlotBarGroups_S64Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
    group_size = group_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBarGroups_S64Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
end
function M.ImPlot_PlotBarGroups_U64Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
    group_size = group_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBarGroups_U64Ptr(label_ids,values,item_count,group_count,group_size,shift,spec)
end
function M.ImPlot_PlotBarGroups(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotBarGroups_FloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotBarGroups_doublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotBarGroups_S8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_U8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_S16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_U16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_S32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_U32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_S64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotBarGroups_U64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotBarGroups could not find overloaded'
end
function M.ImPlot_PlotBars_FloatPtrInt(label_id,values,count,bar_size,shift,spec)
    bar_size = bar_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_FloatPtrInt(label_id,values,count,bar_size,shift,spec)
end
function M.ImPlot_PlotBars_doublePtrInt(label_id,values,count,bar_size,shift,spec)
    bar_size = bar_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_doublePtrInt(label_id,values,count,bar_size,shift,spec)
end
function M.ImPlot_PlotBars_S8PtrInt(label_id,values,count,bar_size,shift,spec)
    bar_size = bar_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_S8PtrInt(label_id,values,count,bar_size,shift,spec)
end
function M.ImPlot_PlotBars_U8PtrInt(label_id,values,count,bar_size,shift,spec)
    bar_size = bar_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_U8PtrInt(label_id,values,count,bar_size,shift,spec)
end
function M.ImPlot_PlotBars_S16PtrInt(label_id,values,count,bar_size,shift,spec)
    bar_size = bar_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_S16PtrInt(label_id,values,count,bar_size,shift,spec)
end
function M.ImPlot_PlotBars_U16PtrInt(label_id,values,count,bar_size,shift,spec)
    bar_size = bar_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_U16PtrInt(label_id,values,count,bar_size,shift,spec)
end
function M.ImPlot_PlotBars_S32PtrInt(label_id,values,count,bar_size,shift,spec)
    bar_size = bar_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_S32PtrInt(label_id,values,count,bar_size,shift,spec)
end
function M.ImPlot_PlotBars_U32PtrInt(label_id,values,count,bar_size,shift,spec)
    bar_size = bar_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_U32PtrInt(label_id,values,count,bar_size,shift,spec)
end
function M.ImPlot_PlotBars_S64PtrInt(label_id,values,count,bar_size,shift,spec)
    bar_size = bar_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_S64PtrInt(label_id,values,count,bar_size,shift,spec)
end
function M.ImPlot_PlotBars_U64PtrInt(label_id,values,count,bar_size,shift,spec)
    bar_size = bar_size or 0.67
    shift = shift or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_U64PtrInt(label_id,values,count,bar_size,shift,spec)
end
function M.ImPlot_PlotBars_FloatPtrFloatPtr(label_id,xs,ys,count,bar_size,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_FloatPtrFloatPtr(label_id,xs,ys,count,bar_size,spec)
end
function M.ImPlot_PlotBars_doublePtrdoublePtr(label_id,xs,ys,count,bar_size,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_doublePtrdoublePtr(label_id,xs,ys,count,bar_size,spec)
end
function M.ImPlot_PlotBars_S8PtrS8Ptr(label_id,xs,ys,count,bar_size,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_S8PtrS8Ptr(label_id,xs,ys,count,bar_size,spec)
end
function M.ImPlot_PlotBars_U8PtrU8Ptr(label_id,xs,ys,count,bar_size,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_U8PtrU8Ptr(label_id,xs,ys,count,bar_size,spec)
end
function M.ImPlot_PlotBars_S16PtrS16Ptr(label_id,xs,ys,count,bar_size,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_S16PtrS16Ptr(label_id,xs,ys,count,bar_size,spec)
end
function M.ImPlot_PlotBars_U16PtrU16Ptr(label_id,xs,ys,count,bar_size,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_U16PtrU16Ptr(label_id,xs,ys,count,bar_size,spec)
end
function M.ImPlot_PlotBars_S32PtrS32Ptr(label_id,xs,ys,count,bar_size,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_S32PtrS32Ptr(label_id,xs,ys,count,bar_size,spec)
end
function M.ImPlot_PlotBars_U32PtrU32Ptr(label_id,xs,ys,count,bar_size,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_U32PtrU32Ptr(label_id,xs,ys,count,bar_size,spec)
end
function M.ImPlot_PlotBars_S64PtrS64Ptr(label_id,xs,ys,count,bar_size,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_S64PtrS64Ptr(label_id,xs,ys,count,bar_size,spec)
end
function M.ImPlot_PlotBars_U64PtrU64Ptr(label_id,xs,ys,count,bar_size,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBars_U64PtrU64Ptr(label_id,xs,ys,count,bar_size,spec)
end
function M.ImPlot_PlotBars(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_FloatPtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_doublePtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_S8PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_U8PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_S16PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_U16PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_S32PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_U32PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_S64PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotBars_U64PtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotBars_FloatPtrFloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotBars_doublePtrdoublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotBars_S8PtrS8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_U8PtrU8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_S16PtrS16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_U16PtrU16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_S32PtrS32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_U32PtrU32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_S64PtrS64Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotBars_U64PtrU64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot_PlotBars could not find overloaded'
end
function M.ImPlot_PlotBarsG(label_id,getter,data,count,bar_size,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBarsG(label_id,getter,data,count,bar_size,spec)
end
function M.ImPlot_PlotBarsG_LJ(label_id,getter,data,count,bar_size,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBarsG_LJ(label_id,getter,data,count,bar_size,spec)
end
function M.ImPlot_PlotBubbles_FloatPtrFloatPtrInt(label_id,values,szs,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotBubbles_FloatPtrFloatPtrInt(label_id,values,szs,count,xscale,xstart,spec)
end
function M.ImPlot_PlotBubbles_doublePtrdoublePtrInt(label_id,values,szs,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotBubbles_doublePtrdoublePtrInt(label_id,values,szs,count,xscale,xstart,spec)
end
function M.ImPlot_PlotBubbles_S8PtrS8PtrInt(label_id,values,szs,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotBubbles_S8PtrS8PtrInt(label_id,values,szs,count,xscale,xstart,spec)
end
function M.ImPlot_PlotBubbles_U8PtrU8PtrInt(label_id,values,szs,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotBubbles_U8PtrU8PtrInt(label_id,values,szs,count,xscale,xstart,spec)
end
function M.ImPlot_PlotBubbles_S16PtrS16PtrInt(label_id,values,szs,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotBubbles_S16PtrS16PtrInt(label_id,values,szs,count,xscale,xstart,spec)
end
function M.ImPlot_PlotBubbles_U16PtrU16PtrInt(label_id,values,szs,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotBubbles_U16PtrU16PtrInt(label_id,values,szs,count,xscale,xstart,spec)
end
function M.ImPlot_PlotBubbles_S32PtrS32PtrInt(label_id,values,szs,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotBubbles_S32PtrS32PtrInt(label_id,values,szs,count,xscale,xstart,spec)
end
function M.ImPlot_PlotBubbles_U32PtrU32PtrInt(label_id,values,szs,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotBubbles_U32PtrU32PtrInt(label_id,values,szs,count,xscale,xstart,spec)
end
function M.ImPlot_PlotBubbles_S64PtrS64PtrInt(label_id,values,szs,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotBubbles_S64PtrS64PtrInt(label_id,values,szs,count,xscale,xstart,spec)
end
function M.ImPlot_PlotBubbles_U64PtrU64PtrInt(label_id,values,szs,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotBubbles_U64PtrU64PtrInt(label_id,values,szs,count,xscale,xstart,spec)
end
function M.ImPlot_PlotBubbles_FloatPtrFloatPtrFloatPtr(label_id,xs,ys,szs,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBubbles_FloatPtrFloatPtrFloatPtr(label_id,xs,ys,szs,count,spec)
end
function M.ImPlot_PlotBubbles_doublePtrdoublePtrdoublePtr(label_id,xs,ys,szs,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBubbles_doublePtrdoublePtrdoublePtr(label_id,xs,ys,szs,count,spec)
end
function M.ImPlot_PlotBubbles_S8PtrS8PtrS8Ptr(label_id,xs,ys,szs,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBubbles_S8PtrS8PtrS8Ptr(label_id,xs,ys,szs,count,spec)
end
function M.ImPlot_PlotBubbles_U8PtrU8PtrU8Ptr(label_id,xs,ys,szs,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBubbles_U8PtrU8PtrU8Ptr(label_id,xs,ys,szs,count,spec)
end
function M.ImPlot_PlotBubbles_S16PtrS16PtrS16Ptr(label_id,xs,ys,szs,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBubbles_S16PtrS16PtrS16Ptr(label_id,xs,ys,szs,count,spec)
end
function M.ImPlot_PlotBubbles_U16PtrU16PtrU16Ptr(label_id,xs,ys,szs,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBubbles_U16PtrU16PtrU16Ptr(label_id,xs,ys,szs,count,spec)
end
function M.ImPlot_PlotBubbles_S32PtrS32PtrS32Ptr(label_id,xs,ys,szs,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBubbles_S32PtrS32PtrS32Ptr(label_id,xs,ys,szs,count,spec)
end
function M.ImPlot_PlotBubbles_U32PtrU32PtrU32Ptr(label_id,xs,ys,szs,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBubbles_U32PtrU32PtrU32Ptr(label_id,xs,ys,szs,count,spec)
end
function M.ImPlot_PlotBubbles_S64PtrS64PtrS64Ptr(label_id,xs,ys,szs,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBubbles_S64PtrS64PtrS64Ptr(label_id,xs,ys,szs,count,spec)
end
function M.ImPlot_PlotBubbles_U64PtrU64PtrU64Ptr(label_id,xs,ys,szs,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotBubbles_U64PtrU64PtrU64Ptr(label_id,xs,ys,szs,count,spec)
end
function M.ImPlot_PlotBubbles(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('int32_t',a4) or type(a4)=='number') then return M.ImPlot_PlotBubbles_FloatPtrFloatPtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('int32_t',a4) or type(a4)=='number') then return M.ImPlot_PlotBubbles_doublePtrdoublePtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('int32_t',a4) or type(a4)=='number') then return M.ImPlot_PlotBubbles_S8PtrS8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') then return M.ImPlot_PlotBubbles_U8PtrU8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') then return M.ImPlot_PlotBubbles_S16PtrS16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') then return M.ImPlot_PlotBubbles_U16PtrU16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') then return M.ImPlot_PlotBubbles_S32PtrS32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') then return M.ImPlot_PlotBubbles_U32PtrU32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') then return M.ImPlot_PlotBubbles_S64PtrS64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') then return M.ImPlot_PlotBubbles_U64PtrU64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('float*',a4) or ffi.istype('float[]',a4)) then return M.ImPlot_PlotBubbles_FloatPtrFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('double*',a4) or ffi.istype('double[]',a4)) then return M.ImPlot_PlotBubbles_doublePtrdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('const ImS8*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') then return M.ImPlot_PlotBubbles_S8PtrS8PtrS8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) and ffi.typeof('uint8_t*') == ffi.typeof(a4) or ffi.typeof('const uint8_t*') == ffi.typeof(a4) or ffi.typeof('uint8_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotBubbles_U8PtrU8PtrU8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) and ffi.typeof('int16_t*') == ffi.typeof(a4) or ffi.typeof('const int16_t*') == ffi.typeof(a4) or ffi.typeof('int16_t[?]') == ffi.typeof(a4) or ffi.typeof('const int16_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotBubbles_S16PtrS16PtrS16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) and ffi.typeof('uint16_t*') == ffi.typeof(a4) or ffi.typeof('const uint16_t*') == ffi.typeof(a4) or ffi.typeof('uint16_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotBubbles_U16PtrU16PtrU16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) and ffi.typeof('int32_t*') == ffi.typeof(a4) or ffi.typeof('const int32_t*') == ffi.typeof(a4) or ffi.typeof('int32_t[?]') == ffi.typeof(a4) or ffi.typeof('const int32_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotBubbles_S32PtrS32PtrS32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) and ffi.typeof('uint32_t*') == ffi.typeof(a4) or ffi.typeof('const uint32_t*') == ffi.typeof(a4) or ffi.typeof('uint32_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotBubbles_U32PtrU32PtrU32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) and ffi.typeof('int64_t*') == ffi.typeof(a4) or ffi.typeof('const int64_t*') == ffi.typeof(a4) or ffi.typeof('int64_t[?]') == ffi.typeof(a4) or ffi.typeof('const int64_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotBubbles_S64PtrS64PtrS64Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) and ffi.typeof('uint64_t*') == ffi.typeof(a4) or ffi.typeof('const uint64_t*') == ffi.typeof(a4) or ffi.typeof('uint64_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotBubbles_U64PtrU64PtrU64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotBubbles could not find overloaded'
end
function M.ImPlot_PlotDigital_FloatPtr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDigital_FloatPtr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotDigital_doublePtr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDigital_doublePtr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotDigital_S8Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDigital_S8Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotDigital_U8Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDigital_U8Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotDigital_S16Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDigital_S16Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotDigital_U16Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDigital_U16Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotDigital_S32Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDigital_S32Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotDigital_U32Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDigital_U32Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotDigital_S64Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDigital_S64Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotDigital_U64Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDigital_U64Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotDigital(a1,a2,a3,a4,a5) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotDigital_FloatPtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotDigital_doublePtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotDigital_S8Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_U8Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_S16Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_U16Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_S32Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_U32Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_S64Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotDigital_U64Ptr(a1,a2,a3,a4,a5) end
    print(a1,a2,a3,a4,a5)
    error'M.ImPlot_PlotDigital could not find overloaded'
end
function M.ImPlot_PlotDigitalG(label_id,getter,data,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDigitalG(label_id,getter,data,count,spec)
end
function M.ImPlot_PlotDigitalG_LJ(label_id,getter,data,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDigitalG_LJ(label_id,getter,data,count,spec)
end
function M.ImPlot_PlotDummy(label_id,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotDummy(label_id,spec)
end
function M.ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrInt(label_id,xs,ys,err,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrInt(label_id,xs,ys,err,count,spec)
end
function M.ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrInt(label_id,xs,ys,err,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrInt(label_id,xs,ys,err,count,spec)
end
function M.ImPlot_PlotErrorBars_S8PtrS8PtrS8PtrInt(label_id,xs,ys,err,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_S8PtrS8PtrS8PtrInt(label_id,xs,ys,err,count,spec)
end
function M.ImPlot_PlotErrorBars_U8PtrU8PtrU8PtrInt(label_id,xs,ys,err,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_U8PtrU8PtrU8PtrInt(label_id,xs,ys,err,count,spec)
end
function M.ImPlot_PlotErrorBars_S16PtrS16PtrS16PtrInt(label_id,xs,ys,err,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_S16PtrS16PtrS16PtrInt(label_id,xs,ys,err,count,spec)
end
function M.ImPlot_PlotErrorBars_U16PtrU16PtrU16PtrInt(label_id,xs,ys,err,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_U16PtrU16PtrU16PtrInt(label_id,xs,ys,err,count,spec)
end
function M.ImPlot_PlotErrorBars_S32PtrS32PtrS32PtrInt(label_id,xs,ys,err,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_S32PtrS32PtrS32PtrInt(label_id,xs,ys,err,count,spec)
end
function M.ImPlot_PlotErrorBars_U32PtrU32PtrU32PtrInt(label_id,xs,ys,err,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_U32PtrU32PtrU32PtrInt(label_id,xs,ys,err,count,spec)
end
function M.ImPlot_PlotErrorBars_S64PtrS64PtrS64PtrInt(label_id,xs,ys,err,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_S64PtrS64PtrS64PtrInt(label_id,xs,ys,err,count,spec)
end
function M.ImPlot_PlotErrorBars_U64PtrU64PtrU64PtrInt(label_id,xs,ys,err,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_U64PtrU64PtrU64PtrInt(label_id,xs,ys,err,count,spec)
end
function M.ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrFloatPtr(label_id,xs,ys,neg,pos,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrFloatPtr(label_id,xs,ys,neg,pos,count,spec)
end
function M.ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrdoublePtr(label_id,xs,ys,neg,pos,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrdoublePtr(label_id,xs,ys,neg,pos,count,spec)
end
function M.ImPlot_PlotErrorBars_S8PtrS8PtrS8PtrS8Ptr(label_id,xs,ys,neg,pos,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_S8PtrS8PtrS8PtrS8Ptr(label_id,xs,ys,neg,pos,count,spec)
end
function M.ImPlot_PlotErrorBars_U8PtrU8PtrU8PtrU8Ptr(label_id,xs,ys,neg,pos,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_U8PtrU8PtrU8PtrU8Ptr(label_id,xs,ys,neg,pos,count,spec)
end
function M.ImPlot_PlotErrorBars_S16PtrS16PtrS16PtrS16Ptr(label_id,xs,ys,neg,pos,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_S16PtrS16PtrS16PtrS16Ptr(label_id,xs,ys,neg,pos,count,spec)
end
function M.ImPlot_PlotErrorBars_U16PtrU16PtrU16PtrU16Ptr(label_id,xs,ys,neg,pos,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_U16PtrU16PtrU16PtrU16Ptr(label_id,xs,ys,neg,pos,count,spec)
end
function M.ImPlot_PlotErrorBars_S32PtrS32PtrS32PtrS32Ptr(label_id,xs,ys,neg,pos,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_S32PtrS32PtrS32PtrS32Ptr(label_id,xs,ys,neg,pos,count,spec)
end
function M.ImPlot_PlotErrorBars_U32PtrU32PtrU32PtrU32Ptr(label_id,xs,ys,neg,pos,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_U32PtrU32PtrU32PtrU32Ptr(label_id,xs,ys,neg,pos,count,spec)
end
function M.ImPlot_PlotErrorBars_S64PtrS64PtrS64PtrS64Ptr(label_id,xs,ys,neg,pos,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_S64PtrS64PtrS64PtrS64Ptr(label_id,xs,ys,neg,pos,count,spec)
end
function M.ImPlot_PlotErrorBars_U64PtrU64PtrU64PtrU64Ptr(label_id,xs,ys,neg,pos,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotErrorBars_U64PtrU64PtrU64PtrU64Ptr(label_id,xs,ys,neg,pos,count,spec)
end
function M.ImPlot_PlotErrorBars(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('float*',a4) or ffi.istype('float[]',a4)) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('double*',a4) or ffi.istype('double[]',a4)) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('const ImS8*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_S8PtrS8PtrS8PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) and ffi.typeof('uint8_t*') == ffi.typeof(a4) or ffi.typeof('const uint8_t*') == ffi.typeof(a4) or ffi.typeof('uint8_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_U8PtrU8PtrU8PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) and ffi.typeof('int16_t*') == ffi.typeof(a4) or ffi.typeof('const int16_t*') == ffi.typeof(a4) or ffi.typeof('int16_t[?]') == ffi.typeof(a4) or ffi.typeof('const int16_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_S16PtrS16PtrS16PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) and ffi.typeof('uint16_t*') == ffi.typeof(a4) or ffi.typeof('const uint16_t*') == ffi.typeof(a4) or ffi.typeof('uint16_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_U16PtrU16PtrU16PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) and ffi.typeof('int32_t*') == ffi.typeof(a4) or ffi.typeof('const int32_t*') == ffi.typeof(a4) or ffi.typeof('int32_t[?]') == ffi.typeof(a4) or ffi.typeof('const int32_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_S32PtrS32PtrS32PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) and ffi.typeof('uint32_t*') == ffi.typeof(a4) or ffi.typeof('const uint32_t*') == ffi.typeof(a4) or ffi.typeof('uint32_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_U32PtrU32PtrU32PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) and ffi.typeof('int64_t*') == ffi.typeof(a4) or ffi.typeof('const int64_t*') == ffi.typeof(a4) or ffi.typeof('int64_t[?]') == ffi.typeof(a4) or ffi.typeof('const int64_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_S64PtrS64PtrS64PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) and ffi.typeof('uint64_t*') == ffi.typeof(a4) or ffi.typeof('const uint64_t*') == ffi.typeof(a4) or ffi.typeof('uint64_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a4) and (ffi.istype('int32_t',a5) or type(a5)=='number') then return M.ImPlot_PlotErrorBars_U64PtrU64PtrU64PtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('float*',a4) or ffi.istype('float[]',a4)) and (ffi.istype('float*',a5) or ffi.istype('float[]',a5)) then return M.ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('double*',a4) or ffi.istype('double[]',a4)) and (ffi.istype('double*',a5) or ffi.istype('double[]',a5)) then return M.ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('const ImS8*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') and (ffi.istype('const ImS8*',a5) or ffi.istype('char[]',a5) or type(a5)=='string') then return M.ImPlot_PlotErrorBars_S8PtrS8PtrS8PtrS8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) and ffi.typeof('uint8_t*') == ffi.typeof(a4) or ffi.typeof('const uint8_t*') == ffi.typeof(a4) or ffi.typeof('uint8_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a4) and ffi.typeof('uint8_t*') == ffi.typeof(a5) or ffi.typeof('const uint8_t*') == ffi.typeof(a5) or ffi.typeof('uint8_t[?]') == ffi.typeof(a5) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_U8PtrU8PtrU8PtrU8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) and ffi.typeof('int16_t*') == ffi.typeof(a4) or ffi.typeof('const int16_t*') == ffi.typeof(a4) or ffi.typeof('int16_t[?]') == ffi.typeof(a4) or ffi.typeof('const int16_t[?]') == ffi.typeof(a4) and ffi.typeof('int16_t*') == ffi.typeof(a5) or ffi.typeof('const int16_t*') == ffi.typeof(a5) or ffi.typeof('int16_t[?]') == ffi.typeof(a5) or ffi.typeof('const int16_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_S16PtrS16PtrS16PtrS16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) and ffi.typeof('uint16_t*') == ffi.typeof(a4) or ffi.typeof('const uint16_t*') == ffi.typeof(a4) or ffi.typeof('uint16_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a4) and ffi.typeof('uint16_t*') == ffi.typeof(a5) or ffi.typeof('const uint16_t*') == ffi.typeof(a5) or ffi.typeof('uint16_t[?]') == ffi.typeof(a5) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_U16PtrU16PtrU16PtrU16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) and ffi.typeof('int32_t*') == ffi.typeof(a4) or ffi.typeof('const int32_t*') == ffi.typeof(a4) or ffi.typeof('int32_t[?]') == ffi.typeof(a4) or ffi.typeof('const int32_t[?]') == ffi.typeof(a4) and ffi.typeof('int32_t*') == ffi.typeof(a5) or ffi.typeof('const int32_t*') == ffi.typeof(a5) or ffi.typeof('int32_t[?]') == ffi.typeof(a5) or ffi.typeof('const int32_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_S32PtrS32PtrS32PtrS32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) and ffi.typeof('uint32_t*') == ffi.typeof(a4) or ffi.typeof('const uint32_t*') == ffi.typeof(a4) or ffi.typeof('uint32_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a4) and ffi.typeof('uint32_t*') == ffi.typeof(a5) or ffi.typeof('const uint32_t*') == ffi.typeof(a5) or ffi.typeof('uint32_t[?]') == ffi.typeof(a5) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_U32PtrU32PtrU32PtrU32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) and ffi.typeof('int64_t*') == ffi.typeof(a4) or ffi.typeof('const int64_t*') == ffi.typeof(a4) or ffi.typeof('int64_t[?]') == ffi.typeof(a4) or ffi.typeof('const int64_t[?]') == ffi.typeof(a4) and ffi.typeof('int64_t*') == ffi.typeof(a5) or ffi.typeof('const int64_t*') == ffi.typeof(a5) or ffi.typeof('int64_t[?]') == ffi.typeof(a5) or ffi.typeof('const int64_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_S64PtrS64PtrS64PtrS64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) and ffi.typeof('uint64_t*') == ffi.typeof(a4) or ffi.typeof('const uint64_t*') == ffi.typeof(a4) or ffi.typeof('uint64_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a4) and ffi.typeof('uint64_t*') == ffi.typeof(a5) or ffi.typeof('const uint64_t*') == ffi.typeof(a5) or ffi.typeof('uint64_t[?]') == ffi.typeof(a5) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a5) then return M.ImPlot_PlotErrorBars_U64PtrU64PtrU64PtrU64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotErrorBars could not find overloaded'
end
function M.ImPlot_PlotHeatmap_FloatPtr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHeatmap_FloatPtr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
end
function M.ImPlot_PlotHeatmap_doublePtr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHeatmap_doublePtr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
end
function M.ImPlot_PlotHeatmap_S8Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHeatmap_S8Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
end
function M.ImPlot_PlotHeatmap_U8Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHeatmap_U8Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
end
function M.ImPlot_PlotHeatmap_S16Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHeatmap_S16Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
end
function M.ImPlot_PlotHeatmap_U16Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHeatmap_U16Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
end
function M.ImPlot_PlotHeatmap_S32Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHeatmap_S32Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
end
function M.ImPlot_PlotHeatmap_U32Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHeatmap_U32Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
end
function M.ImPlot_PlotHeatmap_S64Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHeatmap_S64Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
end
function M.ImPlot_PlotHeatmap_U64Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
    bounds_max = bounds_max or ImPlotPoint(1,1)
    bounds_min = bounds_min or ImPlotPoint(0,0)
    label_fmt = label_fmt or "%.1f"
    scale_max = scale_max or 0
    scale_min = scale_min or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHeatmap_U64Ptr(label_id,values,rows,cols,scale_min,scale_max,label_fmt,bounds_min,bounds_max,spec)
end
function M.ImPlot_PlotHeatmap(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotHeatmap_FloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotHeatmap_doublePtr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotHeatmap_S8Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_U8Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_S16Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_U16Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_S32Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_U32Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_S64Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHeatmap_U64Ptr(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
    error'M.ImPlot_PlotHeatmap could not find overloaded'
end
function M.ImPlot_PlotHistogram_FloatPtr(label_id,values,count,bins,bar_scale,range,spec)
    bar_scale = bar_scale or 1
    bins = bins or -2
    range = range or ImPlotRange()
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHistogram_FloatPtr(label_id,values,count,bins,bar_scale,range,spec)
end
function M.ImPlot_PlotHistogram_doublePtr(label_id,values,count,bins,bar_scale,range,spec)
    bar_scale = bar_scale or 1
    bins = bins or -2
    range = range or ImPlotRange()
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHistogram_doublePtr(label_id,values,count,bins,bar_scale,range,spec)
end
function M.ImPlot_PlotHistogram_S8Ptr(label_id,values,count,bins,bar_scale,range,spec)
    bar_scale = bar_scale or 1
    bins = bins or -2
    range = range or ImPlotRange()
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHistogram_S8Ptr(label_id,values,count,bins,bar_scale,range,spec)
end
function M.ImPlot_PlotHistogram_U8Ptr(label_id,values,count,bins,bar_scale,range,spec)
    bar_scale = bar_scale or 1
    bins = bins or -2
    range = range or ImPlotRange()
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHistogram_U8Ptr(label_id,values,count,bins,bar_scale,range,spec)
end
function M.ImPlot_PlotHistogram_S16Ptr(label_id,values,count,bins,bar_scale,range,spec)
    bar_scale = bar_scale or 1
    bins = bins or -2
    range = range or ImPlotRange()
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHistogram_S16Ptr(label_id,values,count,bins,bar_scale,range,spec)
end
function M.ImPlot_PlotHistogram_U16Ptr(label_id,values,count,bins,bar_scale,range,spec)
    bar_scale = bar_scale or 1
    bins = bins or -2
    range = range or ImPlotRange()
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHistogram_U16Ptr(label_id,values,count,bins,bar_scale,range,spec)
end
function M.ImPlot_PlotHistogram_S32Ptr(label_id,values,count,bins,bar_scale,range,spec)
    bar_scale = bar_scale or 1
    bins = bins or -2
    range = range or ImPlotRange()
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHistogram_S32Ptr(label_id,values,count,bins,bar_scale,range,spec)
end
function M.ImPlot_PlotHistogram_U32Ptr(label_id,values,count,bins,bar_scale,range,spec)
    bar_scale = bar_scale or 1
    bins = bins or -2
    range = range or ImPlotRange()
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHistogram_U32Ptr(label_id,values,count,bins,bar_scale,range,spec)
end
function M.ImPlot_PlotHistogram_S64Ptr(label_id,values,count,bins,bar_scale,range,spec)
    bar_scale = bar_scale or 1
    bins = bins or -2
    range = range or ImPlotRange()
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHistogram_S64Ptr(label_id,values,count,bins,bar_scale,range,spec)
end
function M.ImPlot_PlotHistogram_U64Ptr(label_id,values,count,bins,bar_scale,range,spec)
    bar_scale = bar_scale or 1
    bins = bins or -2
    range = range or ImPlotRange()
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotHistogram_U64Ptr(label_id,values,count,bins,bar_scale,range,spec)
end
function M.ImPlot_PlotHistogram(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotHistogram_FloatPtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotHistogram_doublePtr(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotHistogram_S8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_U8Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_S16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_U16Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_S32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_U32Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_S64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram_U64Ptr(a1,a2,a3,a4,a5,a6,a7) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotHistogram could not find overloaded'
end
function M.ImPlot_PlotHistogram2D_FloatPtr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
    range = range or ImPlotRect()
    spec = spec or M.ImPlotSpec()[0]
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_FloatPtr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
end
function M.ImPlot_PlotHistogram2D_doublePtr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
    range = range or ImPlotRect()
    spec = spec or M.ImPlotSpec()[0]
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_doublePtr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
end
function M.ImPlot_PlotHistogram2D_S8Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
    range = range or ImPlotRect()
    spec = spec or M.ImPlotSpec()[0]
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_S8Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
end
function M.ImPlot_PlotHistogram2D_U8Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
    range = range or ImPlotRect()
    spec = spec or M.ImPlotSpec()[0]
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_U8Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
end
function M.ImPlot_PlotHistogram2D_S16Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
    range = range or ImPlotRect()
    spec = spec or M.ImPlotSpec()[0]
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_S16Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
end
function M.ImPlot_PlotHistogram2D_U16Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
    range = range or ImPlotRect()
    spec = spec or M.ImPlotSpec()[0]
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_U16Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
end
function M.ImPlot_PlotHistogram2D_S32Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
    range = range or ImPlotRect()
    spec = spec or M.ImPlotSpec()[0]
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_S32Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
end
function M.ImPlot_PlotHistogram2D_U32Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
    range = range or ImPlotRect()
    spec = spec or M.ImPlotSpec()[0]
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_U32Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
end
function M.ImPlot_PlotHistogram2D_S64Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
    range = range or ImPlotRect()
    spec = spec or M.ImPlotSpec()[0]
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_S64Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
end
function M.ImPlot_PlotHistogram2D_U64Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
    range = range or ImPlotRect()
    spec = spec or M.ImPlotSpec()[0]
    x_bins = x_bins or -2
    y_bins = y_bins or -2
    return lib.ImPlot_PlotHistogram2D_U64Ptr(label_id,xs,ys,count,x_bins,y_bins,range,spec)
end
function M.ImPlot_PlotHistogram2D(a1,a2,a3,a4,a5,a6,a7,a8) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotHistogram2D_FloatPtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotHistogram2D_doublePtr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotHistogram2D_S8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_U8Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_S16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_U16Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_S32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_U32Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_S64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotHistogram2D_U64Ptr(a1,a2,a3,a4,a5,a6,a7,a8) end
    print(a1,a2,a3,a4,a5,a6,a7,a8)
    error'M.ImPlot_PlotHistogram2D could not find overloaded'
end
function M.ImPlot_PlotImage(label_id,tex_ref,bounds_min,bounds_max,uv0,uv1,tint_col,spec)
    spec = spec or M.ImPlotSpec()[0]
    tint_col = tint_col or ImVec4(1,1,1,1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,1)
    return lib.ImPlot_PlotImage(label_id,tex_ref,bounds_min,bounds_max,uv0,uv1,tint_col,spec)
end
function M.ImPlot_PlotInfLines_FloatPtr(label_id,values,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotInfLines_FloatPtr(label_id,values,count,spec)
end
function M.ImPlot_PlotInfLines_doublePtr(label_id,values,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotInfLines_doublePtr(label_id,values,count,spec)
end
function M.ImPlot_PlotInfLines_S8Ptr(label_id,values,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotInfLines_S8Ptr(label_id,values,count,spec)
end
function M.ImPlot_PlotInfLines_U8Ptr(label_id,values,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotInfLines_U8Ptr(label_id,values,count,spec)
end
function M.ImPlot_PlotInfLines_S16Ptr(label_id,values,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotInfLines_S16Ptr(label_id,values,count,spec)
end
function M.ImPlot_PlotInfLines_U16Ptr(label_id,values,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotInfLines_U16Ptr(label_id,values,count,spec)
end
function M.ImPlot_PlotInfLines_S32Ptr(label_id,values,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotInfLines_S32Ptr(label_id,values,count,spec)
end
function M.ImPlot_PlotInfLines_U32Ptr(label_id,values,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotInfLines_U32Ptr(label_id,values,count,spec)
end
function M.ImPlot_PlotInfLines_S64Ptr(label_id,values,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotInfLines_S64Ptr(label_id,values,count,spec)
end
function M.ImPlot_PlotInfLines_U64Ptr(label_id,values,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotInfLines_U64Ptr(label_id,values,count,spec)
end
function M.ImPlot_PlotInfLines(a1,a2,a3,a4) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotInfLines_FloatPtr(a1,a2,a3,a4) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotInfLines_doublePtr(a1,a2,a3,a4) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotInfLines_S8Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_U8Ptr(a1,a2,a3,a4) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_S16Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_U16Ptr(a1,a2,a3,a4) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_S32Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_U32Ptr(a1,a2,a3,a4) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_S64Ptr(a1,a2,a3,a4) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotInfLines_U64Ptr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_PlotInfLines could not find overloaded'
end
function M.ImPlot_PlotLine_FloatPtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_FloatPtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotLine_doublePtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_doublePtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotLine_S8PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_S8PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotLine_U8PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_U8PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotLine_S16PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_S16PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotLine_U16PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_U16PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotLine_S32PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_S32PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotLine_U32PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_U32PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotLine_S64PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_S64PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotLine_U64PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotLine_U64PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotLine_FloatPtrFloatPtr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotLine_FloatPtrFloatPtr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotLine_doublePtrdoublePtr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotLine_doublePtrdoublePtr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotLine_S8PtrS8Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotLine_S8PtrS8Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotLine_U8PtrU8Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotLine_U8PtrU8Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotLine_S16PtrS16Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotLine_S16PtrS16Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotLine_U16PtrU16Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotLine_U16PtrU16Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotLine_S32PtrS32Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotLine_S32PtrS32Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotLine_U32PtrU32Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotLine_U32PtrU32Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotLine_S64PtrS64Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotLine_S64PtrS64Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotLine_U64PtrU64Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotLine_U64PtrU64Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotLine(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_FloatPtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_doublePtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_S8PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_U8PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_S16PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_U16PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_S32PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_U32PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_S64PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotLine_U64PtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotLine_FloatPtrFloatPtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotLine_doublePtrdoublePtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotLine_S8PtrS8Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_U8PtrU8Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_S16PtrS16Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_U16PtrU16Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_S32PtrS32Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_U32PtrU32Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_S64PtrS64Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotLine_U64PtrU64Ptr(a1,a2,a3,a4,a5) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot_PlotLine could not find overloaded'
end
function M.ImPlot_PlotLineG(label_id,getter,data,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotLineG(label_id,getter,data,count,spec)
end
function M.ImPlot_PlotLineG_LJ(label_id,getter,data,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotLineG_LJ(label_id,getter,data,count,spec)
end
function M.ImPlot_PlotPieChart_FloatPtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
    angle0 = angle0 or 90
    fmt_data = fmt_data or nil
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_FloatPtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
end
function M.ImPlot_PlotPieChart_doublePtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
    angle0 = angle0 or 90
    fmt_data = fmt_data or nil
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_doublePtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
end
function M.ImPlot_PlotPieChart_S8PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
    angle0 = angle0 or 90
    fmt_data = fmt_data or nil
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_S8PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
end
function M.ImPlot_PlotPieChart_U8PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
    angle0 = angle0 or 90
    fmt_data = fmt_data or nil
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_U8PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
end
function M.ImPlot_PlotPieChart_S16PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
    angle0 = angle0 or 90
    fmt_data = fmt_data or nil
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_S16PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
end
function M.ImPlot_PlotPieChart_U16PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
    angle0 = angle0 or 90
    fmt_data = fmt_data or nil
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_U16PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
end
function M.ImPlot_PlotPieChart_S32PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
    angle0 = angle0 or 90
    fmt_data = fmt_data or nil
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_S32PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
end
function M.ImPlot_PlotPieChart_U32PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
    angle0 = angle0 or 90
    fmt_data = fmt_data or nil
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_U32PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
end
function M.ImPlot_PlotPieChart_S64PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
    angle0 = angle0 or 90
    fmt_data = fmt_data or nil
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_S64PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
end
function M.ImPlot_PlotPieChart_U64PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
    angle0 = angle0 or 90
    fmt_data = fmt_data or nil
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_U64PtrPlotFormatter(label_ids,values,count,x,y,radius,fmt,fmt_data,angle0,spec)
end
function M.ImPlot_PlotPieChart_FloatPtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_FloatPtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
end
function M.ImPlot_PlotPieChart_doublePtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_doublePtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
end
function M.ImPlot_PlotPieChart_S8PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_S8PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
end
function M.ImPlot_PlotPieChart_U8PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_U8PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
end
function M.ImPlot_PlotPieChart_S16PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_S16PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
end
function M.ImPlot_PlotPieChart_U16PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_U16PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
end
function M.ImPlot_PlotPieChart_S32PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_S32PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
end
function M.ImPlot_PlotPieChart_U32PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_U32PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
end
function M.ImPlot_PlotPieChart_S64PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_S64PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
end
function M.ImPlot_PlotPieChart_U64PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
    angle0 = angle0 or 90
    label_fmt = label_fmt or "%.1f"
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPieChart_U64PtrStr(label_ids,values,count,x,y,radius,label_fmt,angle0,spec)
end
function M.ImPlot_PlotPieChart(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and (ffi.istype('const ImPlotSpec',a10) or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_FloatPtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and (ffi.istype('const ImPlotSpec',a10) or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_doublePtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and (ffi.istype('const ImPlotSpec',a10) or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S8PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and (ffi.istype('const ImPlotSpec',a10) or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U8PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and (ffi.istype('const ImPlotSpec',a10) or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S16PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and (ffi.istype('const ImPlotSpec',a10) or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U16PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and (ffi.istype('const ImPlotSpec',a10) or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S32PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and (ffi.istype('const ImPlotSpec',a10) or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U32PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and (ffi.istype('const ImPlotSpec',a10) or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S64PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.istype('ImPlotFormatter',a7) and (ffi.istype('void *',a8) or type(a8)=='nil') and (ffi.istype('const ImPlotSpec',a10) or type(a10)=='nil') and ((ffi.istype('double',a9) or type(a9)=='number') or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U64PtrPlotFormatter(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and (ffi.istype('const ImPlotSpec',a9) or type(a9)=='nil') then return M.ImPlot_PlotPieChart_FloatPtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and (ffi.istype('const ImPlotSpec',a9) or type(a9)=='nil') then return M.ImPlot_PlotPieChart_doublePtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and (ffi.istype('const ImPlotSpec',a9) or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S8PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and (ffi.istype('const ImPlotSpec',a9) or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U8PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and (ffi.istype('const ImPlotSpec',a9) or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S16PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and (ffi.istype('const ImPlotSpec',a9) or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U16PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and (ffi.istype('const ImPlotSpec',a9) or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S32PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and (ffi.istype('const ImPlotSpec',a9) or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U32PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and (ffi.istype('const ImPlotSpec',a9) or type(a9)=='nil') then return M.ImPlot_PlotPieChart_S64PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ((ffi.istype('const char*',a7) or ffi.istype('char[]',a7) or type(a7)=='string') or type(a7)=='nil') and ((ffi.istype('double',a8) or type(a8)=='number') or type(a8)=='nil') and a10==nil and (ffi.istype('const ImPlotSpec',a9) or type(a9)=='nil') then return M.ImPlot_PlotPieChart_U64PtrStr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
    error'M.ImPlot_PlotPieChart could not find overloaded'
end
function M.ImPlot_PlotPolygon_FloatPtr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPolygon_FloatPtr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotPolygon_doublePtr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPolygon_doublePtr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotPolygon_S8Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPolygon_S8Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotPolygon_U8Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPolygon_U8Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotPolygon_S16Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPolygon_S16Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotPolygon_U16Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPolygon_U16Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotPolygon_S32Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPolygon_S32Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotPolygon_U32Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPolygon_U32Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotPolygon_S64Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPolygon_S64Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotPolygon_U64Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotPolygon_U64Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotPolygon(a1,a2,a3,a4,a5) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.ImPlot_PlotPolygon_FloatPtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_PlotPolygon_doublePtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_PlotPolygon_S8Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotPolygon_U8Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotPolygon_S16Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotPolygon_U16Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotPolygon_S32Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotPolygon_U32Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotPolygon_S64Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.ImPlot_PlotPolygon_U64Ptr(a1,a2,a3,a4,a5) end
    print(a1,a2,a3,a4,a5)
    error'M.ImPlot_PlotPolygon could not find overloaded'
end
function M.ImPlot_PlotScatter_FloatPtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_FloatPtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotScatter_doublePtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_doublePtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotScatter_S8PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_S8PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotScatter_U8PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_U8PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotScatter_S16PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_S16PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotScatter_U16PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_U16PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotScatter_S32PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_S32PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotScatter_U32PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_U32PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotScatter_S64PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_S64PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotScatter_U64PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotScatter_U64PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotScatter_FloatPtrFloatPtr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotScatter_FloatPtrFloatPtr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotScatter_doublePtrdoublePtr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotScatter_doublePtrdoublePtr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotScatter_S8PtrS8Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotScatter_S8PtrS8Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotScatter_U8PtrU8Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotScatter_U8PtrU8Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotScatter_S16PtrS16Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotScatter_S16PtrS16Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotScatter_U16PtrU16Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotScatter_U16PtrU16Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotScatter_S32PtrS32Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotScatter_S32PtrS32Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotScatter_U32PtrU32Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotScatter_U32PtrU32Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotScatter_S64PtrS64Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotScatter_S64PtrS64Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotScatter_U64PtrU64Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotScatter_U64PtrU64Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotScatter(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_FloatPtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_doublePtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_S8PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_U8PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_S16PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_U16PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_S32PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_U32PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_S64PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotScatter_U64PtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotScatter_FloatPtrFloatPtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotScatter_doublePtrdoublePtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotScatter_S8PtrS8Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_U8PtrU8Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_S16PtrS16Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_U16PtrU16Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_S32PtrS32Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_U32PtrU32Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_S64PtrS64Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotScatter_U64PtrU64Ptr(a1,a2,a3,a4,a5) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot_PlotScatter could not find overloaded'
end
function M.ImPlot_PlotScatterG(label_id,getter,data,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotScatterG(label_id,getter,data,count,spec)
end
function M.ImPlot_PlotScatterG_LJ(label_id,getter,data,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotScatterG_LJ(label_id,getter,data,count,spec)
end
function M.ImPlot_PlotShaded_FloatPtrInt(label_id,values,count,yref,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_FloatPtrInt(label_id,values,count,yref,xscale,xstart,spec)
end
function M.ImPlot_PlotShaded_doublePtrInt(label_id,values,count,yref,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_doublePtrInt(label_id,values,count,yref,xscale,xstart,spec)
end
function M.ImPlot_PlotShaded_S8PtrInt(label_id,values,count,yref,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S8PtrInt(label_id,values,count,yref,xscale,xstart,spec)
end
function M.ImPlot_PlotShaded_U8PtrInt(label_id,values,count,yref,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U8PtrInt(label_id,values,count,yref,xscale,xstart,spec)
end
function M.ImPlot_PlotShaded_S16PtrInt(label_id,values,count,yref,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S16PtrInt(label_id,values,count,yref,xscale,xstart,spec)
end
function M.ImPlot_PlotShaded_U16PtrInt(label_id,values,count,yref,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U16PtrInt(label_id,values,count,yref,xscale,xstart,spec)
end
function M.ImPlot_PlotShaded_S32PtrInt(label_id,values,count,yref,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S32PtrInt(label_id,values,count,yref,xscale,xstart,spec)
end
function M.ImPlot_PlotShaded_U32PtrInt(label_id,values,count,yref,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U32PtrInt(label_id,values,count,yref,xscale,xstart,spec)
end
function M.ImPlot_PlotShaded_S64PtrInt(label_id,values,count,yref,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S64PtrInt(label_id,values,count,yref,xscale,xstart,spec)
end
function M.ImPlot_PlotShaded_U64PtrInt(label_id,values,count,yref,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U64PtrInt(label_id,values,count,yref,xscale,xstart,spec)
end
function M.ImPlot_PlotShaded_FloatPtrFloatPtrInt(label_id,xs,ys,count,yref,spec)
    spec = spec or M.ImPlotSpec()[0]
    yref = yref or 0
    return lib.ImPlot_PlotShaded_FloatPtrFloatPtrInt(label_id,xs,ys,count,yref,spec)
end
function M.ImPlot_PlotShaded_doublePtrdoublePtrInt(label_id,xs,ys,count,yref,spec)
    spec = spec or M.ImPlotSpec()[0]
    yref = yref or 0
    return lib.ImPlot_PlotShaded_doublePtrdoublePtrInt(label_id,xs,ys,count,yref,spec)
end
function M.ImPlot_PlotShaded_S8PtrS8PtrInt(label_id,xs,ys,count,yref,spec)
    spec = spec or M.ImPlotSpec()[0]
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S8PtrS8PtrInt(label_id,xs,ys,count,yref,spec)
end
function M.ImPlot_PlotShaded_U8PtrU8PtrInt(label_id,xs,ys,count,yref,spec)
    spec = spec or M.ImPlotSpec()[0]
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U8PtrU8PtrInt(label_id,xs,ys,count,yref,spec)
end
function M.ImPlot_PlotShaded_S16PtrS16PtrInt(label_id,xs,ys,count,yref,spec)
    spec = spec or M.ImPlotSpec()[0]
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S16PtrS16PtrInt(label_id,xs,ys,count,yref,spec)
end
function M.ImPlot_PlotShaded_U16PtrU16PtrInt(label_id,xs,ys,count,yref,spec)
    spec = spec or M.ImPlotSpec()[0]
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U16PtrU16PtrInt(label_id,xs,ys,count,yref,spec)
end
function M.ImPlot_PlotShaded_S32PtrS32PtrInt(label_id,xs,ys,count,yref,spec)
    spec = spec or M.ImPlotSpec()[0]
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S32PtrS32PtrInt(label_id,xs,ys,count,yref,spec)
end
function M.ImPlot_PlotShaded_U32PtrU32PtrInt(label_id,xs,ys,count,yref,spec)
    spec = spec or M.ImPlotSpec()[0]
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U32PtrU32PtrInt(label_id,xs,ys,count,yref,spec)
end
function M.ImPlot_PlotShaded_S64PtrS64PtrInt(label_id,xs,ys,count,yref,spec)
    spec = spec or M.ImPlotSpec()[0]
    yref = yref or 0
    return lib.ImPlot_PlotShaded_S64PtrS64PtrInt(label_id,xs,ys,count,yref,spec)
end
function M.ImPlot_PlotShaded_U64PtrU64PtrInt(label_id,xs,ys,count,yref,spec)
    spec = spec or M.ImPlotSpec()[0]
    yref = yref or 0
    return lib.ImPlot_PlotShaded_U64PtrU64PtrInt(label_id,xs,ys,count,yref,spec)
end
function M.ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr(label_id,xs,ys1,ys2,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr(label_id,xs,ys1,ys2,count,spec)
end
function M.ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr(label_id,xs,ys1,ys2,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr(label_id,xs,ys1,ys2,count,spec)
end
function M.ImPlot_PlotShaded_S8PtrS8PtrS8Ptr(label_id,xs,ys1,ys2,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotShaded_S8PtrS8PtrS8Ptr(label_id,xs,ys1,ys2,count,spec)
end
function M.ImPlot_PlotShaded_U8PtrU8PtrU8Ptr(label_id,xs,ys1,ys2,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotShaded_U8PtrU8PtrU8Ptr(label_id,xs,ys1,ys2,count,spec)
end
function M.ImPlot_PlotShaded_S16PtrS16PtrS16Ptr(label_id,xs,ys1,ys2,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotShaded_S16PtrS16PtrS16Ptr(label_id,xs,ys1,ys2,count,spec)
end
function M.ImPlot_PlotShaded_U16PtrU16PtrU16Ptr(label_id,xs,ys1,ys2,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotShaded_U16PtrU16PtrU16Ptr(label_id,xs,ys1,ys2,count,spec)
end
function M.ImPlot_PlotShaded_S32PtrS32PtrS32Ptr(label_id,xs,ys1,ys2,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotShaded_S32PtrS32PtrS32Ptr(label_id,xs,ys1,ys2,count,spec)
end
function M.ImPlot_PlotShaded_U32PtrU32PtrU32Ptr(label_id,xs,ys1,ys2,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotShaded_U32PtrU32PtrU32Ptr(label_id,xs,ys1,ys2,count,spec)
end
function M.ImPlot_PlotShaded_S64PtrS64PtrS64Ptr(label_id,xs,ys1,ys2,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotShaded_S64PtrS64PtrS64Ptr(label_id,xs,ys1,ys2,count,spec)
end
function M.ImPlot_PlotShaded_U64PtrU64PtrU64Ptr(label_id,xs,ys1,ys2,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotShaded_U64PtrU64PtrU64Ptr(label_id,xs,ys1,ys2,count,spec)
end
function M.ImPlot_PlotShaded(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and (ffi.istype('const ImPlotSpec',a7) or type(a7)=='nil') then return M.ImPlot_PlotShaded_FloatPtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and (ffi.istype('const ImPlotSpec',a7) or type(a7)=='nil') then return M.ImPlot_PlotShaded_doublePtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and (ffi.istype('const ImPlotSpec',a7) or type(a7)=='nil') then return M.ImPlot_PlotShaded_S8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and (ffi.istype('const ImPlotSpec',a7) or type(a7)=='nil') then return M.ImPlot_PlotShaded_U8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and (ffi.istype('const ImPlotSpec',a7) or type(a7)=='nil') then return M.ImPlot_PlotShaded_S16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and (ffi.istype('const ImPlotSpec',a7) or type(a7)=='nil') then return M.ImPlot_PlotShaded_U16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and (ffi.istype('const ImPlotSpec',a7) or type(a7)=='nil') then return M.ImPlot_PlotShaded_S32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and (ffi.istype('const ImPlotSpec',a7) or type(a7)=='nil') then return M.ImPlot_PlotShaded_U32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and (ffi.istype('const ImPlotSpec',a7) or type(a7)=='nil') then return M.ImPlot_PlotShaded_S64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') and ((ffi.istype('double',a4) or type(a4)=='number') or type(a4)=='nil') and ((ffi.istype('double',a6) or type(a6)=='number') or type(a6)=='nil') and (ffi.istype('const ImPlotSpec',a7) or type(a7)=='nil') then return M.ImPlot_PlotShaded_U64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('int32_t',a4) or type(a4)=='number') and (ffi.istype('const ImPlotSpec',a6) or type(a6)=='nil') and a7==nil then return M.ImPlot_PlotShaded_FloatPtrFloatPtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('int32_t',a4) or type(a4)=='number') and (ffi.istype('const ImPlotSpec',a6) or type(a6)=='nil') and a7==nil then return M.ImPlot_PlotShaded_doublePtrdoublePtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('int32_t',a4) or type(a4)=='number') and (ffi.istype('const ImPlotSpec',a6) or type(a6)=='nil') and a7==nil then return M.ImPlot_PlotShaded_S8PtrS8PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and (ffi.istype('const ImPlotSpec',a6) or type(a6)=='nil') and a7==nil then return M.ImPlot_PlotShaded_U8PtrU8PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and (ffi.istype('const ImPlotSpec',a6) or type(a6)=='nil') and a7==nil then return M.ImPlot_PlotShaded_S16PtrS16PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and (ffi.istype('const ImPlotSpec',a6) or type(a6)=='nil') and a7==nil then return M.ImPlot_PlotShaded_U16PtrU16PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and (ffi.istype('const ImPlotSpec',a6) or type(a6)=='nil') and a7==nil then return M.ImPlot_PlotShaded_S32PtrS32PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and (ffi.istype('const ImPlotSpec',a6) or type(a6)=='nil') and a7==nil then return M.ImPlot_PlotShaded_U32PtrU32PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and (ffi.istype('const ImPlotSpec',a6) or type(a6)=='nil') and a7==nil then return M.ImPlot_PlotShaded_S64PtrS64PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) and (ffi.istype('int32_t',a4) or type(a4)=='number') and (ffi.istype('const ImPlotSpec',a6) or type(a6)=='nil') and a7==nil then return M.ImPlot_PlotShaded_U64PtrU64PtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) and (ffi.istype('float*',a4) or ffi.istype('float[]',a4)) then return M.ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) and (ffi.istype('double*',a4) or ffi.istype('double[]',a4)) then return M.ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') and (ffi.istype('const ImS8*',a4) or ffi.istype('char[]',a4) or type(a4)=='string') then return M.ImPlot_PlotShaded_S8PtrS8PtrS8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) and ffi.typeof('uint8_t*') == ffi.typeof(a4) or ffi.typeof('const uint8_t*') == ffi.typeof(a4) or ffi.typeof('uint8_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_U8PtrU8PtrU8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) and ffi.typeof('int16_t*') == ffi.typeof(a4) or ffi.typeof('const int16_t*') == ffi.typeof(a4) or ffi.typeof('int16_t[?]') == ffi.typeof(a4) or ffi.typeof('const int16_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_S16PtrS16PtrS16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) and ffi.typeof('uint16_t*') == ffi.typeof(a4) or ffi.typeof('const uint16_t*') == ffi.typeof(a4) or ffi.typeof('uint16_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_U16PtrU16PtrU16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) and ffi.typeof('int32_t*') == ffi.typeof(a4) or ffi.typeof('const int32_t*') == ffi.typeof(a4) or ffi.typeof('int32_t[?]') == ffi.typeof(a4) or ffi.typeof('const int32_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_S32PtrS32PtrS32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) and ffi.typeof('uint32_t*') == ffi.typeof(a4) or ffi.typeof('const uint32_t*') == ffi.typeof(a4) or ffi.typeof('uint32_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_U32PtrU32PtrU32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) and ffi.typeof('int64_t*') == ffi.typeof(a4) or ffi.typeof('const int64_t*') == ffi.typeof(a4) or ffi.typeof('int64_t[?]') == ffi.typeof(a4) or ffi.typeof('const int64_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_S64PtrS64PtrS64Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) and ffi.typeof('uint64_t*') == ffi.typeof(a4) or ffi.typeof('const uint64_t*') == ffi.typeof(a4) or ffi.typeof('uint64_t[?]') == ffi.typeof(a4) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a4) then return M.ImPlot_PlotShaded_U64PtrU64PtrU64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotShaded could not find overloaded'
end
function M.ImPlot_PlotShadedG(label_id,getter1,data1,getter2,data2,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotShadedG(label_id,getter1,data1,getter2,data2,count,spec)
end
function M.ImPlot_PlotShadedG_LJ(label_id,getter1,data1,getter2,data2,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotShadedG_LJ(label_id,getter1,data1,getter2,data2,count,spec)
end
function M.ImPlot_PlotStairs_FloatPtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_FloatPtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotStairs_doublePtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_doublePtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotStairs_S8PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_S8PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotStairs_U8PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_U8PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotStairs_S16PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_S16PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotStairs_U16PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_U16PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotStairs_S32PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_S32PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotStairs_U32PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_U32PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotStairs_S64PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_S64PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotStairs_U64PtrInt(label_id,values,count,xscale,xstart,spec)
    spec = spec or M.ImPlotSpec()[0]
    xscale = xscale or 1
    xstart = xstart or 0
    return lib.ImPlot_PlotStairs_U64PtrInt(label_id,values,count,xscale,xstart,spec)
end
function M.ImPlot_PlotStairs_FloatPtrFloatPtr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStairs_FloatPtrFloatPtr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotStairs_doublePtrdoublePtr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStairs_doublePtrdoublePtr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotStairs_S8PtrS8Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStairs_S8PtrS8Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotStairs_U8PtrU8Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStairs_U8PtrU8Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotStairs_S16PtrS16Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStairs_S16PtrS16Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotStairs_U16PtrU16Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStairs_U16PtrU16Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotStairs_S32PtrS32Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStairs_S32PtrS32Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotStairs_U32PtrU32Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStairs_U32PtrU32Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotStairs_S64PtrS64Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStairs_S64PtrS64Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotStairs_U64PtrU64Ptr(label_id,xs,ys,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStairs_U64PtrU64Ptr(label_id,xs,ys,count,spec)
end
function M.ImPlot_PlotStairs(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_FloatPtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_doublePtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_S8PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_U8PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_S16PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_U16PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_S32PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_U32PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_S64PtrInt(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStairs_U64PtrInt(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotStairs_FloatPtrFloatPtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotStairs_doublePtrdoublePtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotStairs_S8PtrS8Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_U8PtrU8Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_S16PtrS16Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_U16PtrU16Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_S32PtrS32Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_U32PtrU32Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_S64PtrS64Ptr(a1,a2,a3,a4,a5) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStairs_U64PtrU64Ptr(a1,a2,a3,a4,a5) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot_PlotStairs could not find overloaded'
end
function M.ImPlot_PlotStairsG(label_id,getter,data,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStairsG(label_id,getter,data,count,spec)
end
function M.ImPlot_PlotStairsG_LJ(label_id,getter,data,count,spec)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStairsG_LJ(label_id,getter,data,count,spec)
end
function M.ImPlot_PlotStems_FloatPtrInt(label_id,values,count,ref,scale,start,spec)
    ref = ref or 0
    scale = scale or 1
    spec = spec or M.ImPlotSpec()[0]
    start = start or 0
    return lib.ImPlot_PlotStems_FloatPtrInt(label_id,values,count,ref,scale,start,spec)
end
function M.ImPlot_PlotStems_doublePtrInt(label_id,values,count,ref,scale,start,spec)
    ref = ref or 0
    scale = scale or 1
    spec = spec or M.ImPlotSpec()[0]
    start = start or 0
    return lib.ImPlot_PlotStems_doublePtrInt(label_id,values,count,ref,scale,start,spec)
end
function M.ImPlot_PlotStems_S8PtrInt(label_id,values,count,ref,scale,start,spec)
    ref = ref or 0
    scale = scale or 1
    spec = spec or M.ImPlotSpec()[0]
    start = start or 0
    return lib.ImPlot_PlotStems_S8PtrInt(label_id,values,count,ref,scale,start,spec)
end
function M.ImPlot_PlotStems_U8PtrInt(label_id,values,count,ref,scale,start,spec)
    ref = ref or 0
    scale = scale or 1
    spec = spec or M.ImPlotSpec()[0]
    start = start or 0
    return lib.ImPlot_PlotStems_U8PtrInt(label_id,values,count,ref,scale,start,spec)
end
function M.ImPlot_PlotStems_S16PtrInt(label_id,values,count,ref,scale,start,spec)
    ref = ref or 0
    scale = scale or 1
    spec = spec or M.ImPlotSpec()[0]
    start = start or 0
    return lib.ImPlot_PlotStems_S16PtrInt(label_id,values,count,ref,scale,start,spec)
end
function M.ImPlot_PlotStems_U16PtrInt(label_id,values,count,ref,scale,start,spec)
    ref = ref or 0
    scale = scale or 1
    spec = spec or M.ImPlotSpec()[0]
    start = start or 0
    return lib.ImPlot_PlotStems_U16PtrInt(label_id,values,count,ref,scale,start,spec)
end
function M.ImPlot_PlotStems_S32PtrInt(label_id,values,count,ref,scale,start,spec)
    ref = ref or 0
    scale = scale or 1
    spec = spec or M.ImPlotSpec()[0]
    start = start or 0
    return lib.ImPlot_PlotStems_S32PtrInt(label_id,values,count,ref,scale,start,spec)
end
function M.ImPlot_PlotStems_U32PtrInt(label_id,values,count,ref,scale,start,spec)
    ref = ref or 0
    scale = scale or 1
    spec = spec or M.ImPlotSpec()[0]
    start = start or 0
    return lib.ImPlot_PlotStems_U32PtrInt(label_id,values,count,ref,scale,start,spec)
end
function M.ImPlot_PlotStems_S64PtrInt(label_id,values,count,ref,scale,start,spec)
    ref = ref or 0
    scale = scale or 1
    spec = spec or M.ImPlotSpec()[0]
    start = start or 0
    return lib.ImPlot_PlotStems_S64PtrInt(label_id,values,count,ref,scale,start,spec)
end
function M.ImPlot_PlotStems_U64PtrInt(label_id,values,count,ref,scale,start,spec)
    ref = ref or 0
    scale = scale or 1
    spec = spec or M.ImPlotSpec()[0]
    start = start or 0
    return lib.ImPlot_PlotStems_U64PtrInt(label_id,values,count,ref,scale,start,spec)
end
function M.ImPlot_PlotStems_FloatPtrFloatPtr(label_id,xs,ys,count,ref,spec)
    ref = ref or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStems_FloatPtrFloatPtr(label_id,xs,ys,count,ref,spec)
end
function M.ImPlot_PlotStems_doublePtrdoublePtr(label_id,xs,ys,count,ref,spec)
    ref = ref or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStems_doublePtrdoublePtr(label_id,xs,ys,count,ref,spec)
end
function M.ImPlot_PlotStems_S8PtrS8Ptr(label_id,xs,ys,count,ref,spec)
    ref = ref or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStems_S8PtrS8Ptr(label_id,xs,ys,count,ref,spec)
end
function M.ImPlot_PlotStems_U8PtrU8Ptr(label_id,xs,ys,count,ref,spec)
    ref = ref or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStems_U8PtrU8Ptr(label_id,xs,ys,count,ref,spec)
end
function M.ImPlot_PlotStems_S16PtrS16Ptr(label_id,xs,ys,count,ref,spec)
    ref = ref or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStems_S16PtrS16Ptr(label_id,xs,ys,count,ref,spec)
end
function M.ImPlot_PlotStems_U16PtrU16Ptr(label_id,xs,ys,count,ref,spec)
    ref = ref or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStems_U16PtrU16Ptr(label_id,xs,ys,count,ref,spec)
end
function M.ImPlot_PlotStems_S32PtrS32Ptr(label_id,xs,ys,count,ref,spec)
    ref = ref or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStems_S32PtrS32Ptr(label_id,xs,ys,count,ref,spec)
end
function M.ImPlot_PlotStems_U32PtrU32Ptr(label_id,xs,ys,count,ref,spec)
    ref = ref or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStems_U32PtrU32Ptr(label_id,xs,ys,count,ref,spec)
end
function M.ImPlot_PlotStems_S64PtrS64Ptr(label_id,xs,ys,count,ref,spec)
    ref = ref or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStems_S64PtrS64Ptr(label_id,xs,ys,count,ref,spec)
end
function M.ImPlot_PlotStems_U64PtrU64Ptr(label_id,xs,ys,count,ref,spec)
    ref = ref or 0
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotStems_U64PtrU64Ptr(label_id,xs,ys,count,ref,spec)
end
function M.ImPlot_PlotStems(a1,a2,a3,a4,a5,a6,a7) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_FloatPtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_doublePtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_S8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_U8PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_S16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_U16PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_S32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_U32PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_S64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and (ffi.istype('int32_t',a3) or type(a3)=='number') then return M.ImPlot_PlotStems_U64PtrInt(a1,a2,a3,a4,a5,a6,a7) end
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) and (ffi.istype('float*',a3) or ffi.istype('float[]',a3)) then return M.ImPlot_PlotStems_FloatPtrFloatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) and (ffi.istype('double*',a3) or ffi.istype('double[]',a3)) then return M.ImPlot_PlotStems_doublePtrdoublePtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('const ImS8*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') and (ffi.istype('const ImS8*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_PlotStems_S8PtrS8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint8_t*') == ffi.typeof(a2) or ffi.typeof('const uint8_t*') == ffi.typeof(a2) or ffi.typeof('uint8_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a2) and ffi.typeof('uint8_t*') == ffi.typeof(a3) or ffi.typeof('const uint8_t*') == ffi.typeof(a3) or ffi.typeof('uint8_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint8_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_U8PtrU8Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int16_t*') == ffi.typeof(a2) or ffi.typeof('const int16_t*') == ffi.typeof(a2) or ffi.typeof('int16_t[?]') == ffi.typeof(a2) or ffi.typeof('const int16_t[?]') == ffi.typeof(a2) and ffi.typeof('int16_t*') == ffi.typeof(a3) or ffi.typeof('const int16_t*') == ffi.typeof(a3) or ffi.typeof('int16_t[?]') == ffi.typeof(a3) or ffi.typeof('const int16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_S16PtrS16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint16_t*') == ffi.typeof(a2) or ffi.typeof('const uint16_t*') == ffi.typeof(a2) or ffi.typeof('uint16_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a2) and ffi.typeof('uint16_t*') == ffi.typeof(a3) or ffi.typeof('const uint16_t*') == ffi.typeof(a3) or ffi.typeof('uint16_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint16_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_U16PtrU16Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) and ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_S32PtrS32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) and ffi.typeof('uint32_t*') == ffi.typeof(a3) or ffi.typeof('const uint32_t*') == ffi.typeof(a3) or ffi.typeof('uint32_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_U32PtrU32Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) and ffi.typeof('int64_t*') == ffi.typeof(a3) or ffi.typeof('const int64_t*') == ffi.typeof(a3) or ffi.typeof('int64_t[?]') == ffi.typeof(a3) or ffi.typeof('const int64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_S64PtrS64Ptr(a1,a2,a3,a4,a5,a6) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) and ffi.typeof('uint64_t*') == ffi.typeof(a3) or ffi.typeof('const uint64_t*') == ffi.typeof(a3) or ffi.typeof('uint64_t[?]') == ffi.typeof(a3) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a3) then return M.ImPlot_PlotStems_U64PtrU64Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6,a7)
    error'M.ImPlot_PlotStems could not find overloaded'
end
function M.ImPlot_PlotText(text,x,y,pix_offset,spec)
    pix_offset = pix_offset or ImVec2(0,0)
    spec = spec or M.ImPlotSpec()[0]
    return lib.ImPlot_PlotText(text,x,y,pix_offset,spec)
end
function M.ImPlot_PlotToPixels_PlotPoint(plt,x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    return lib.ImPlot_PlotToPixels_PlotPoint(plt,x_axis,y_axis)
end
function M.ImPlot_PlotToPixels_double(x,y,x_axis,y_axis)
    x_axis = x_axis or -1
    y_axis = y_axis or -1
    return lib.ImPlot_PlotToPixels_double(x,y,x_axis,y_axis)
end
function M.ImPlot_PlotToPixels(a1,a2,a3,a4) -- generic version
    if ffi.istype('const ImPlotPoint',a1) then return M.ImPlot_PlotToPixels_PlotPoint(a1,a2,a3) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPlot_PlotToPixels_double(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_PlotToPixels could not find overloaded'
end
function M.ImPlot_PopColormap(count)
    count = count or 1
    return lib.ImPlot_PopColormap(count)
end
M.ImPlot_PopPlotClipRect = lib.ImPlot_PopPlotClipRect
function M.ImPlot_PopStyleColor(count)
    count = count or 1
    return lib.ImPlot_PopStyleColor(count)
end
function M.ImPlot_PopStyleVar(count)
    count = count or 1
    return lib.ImPlot_PopStyleVar(count)
end
M.ImPlot_Precision = lib.ImPlot_Precision
M.ImPlot_PushColormap_PlotColormap = lib.ImPlot_PushColormap_PlotColormap
M.ImPlot_PushColormap_Str = lib.ImPlot_PushColormap_Str
function M.ImPlot_PushColormap(a1) -- generic version
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImPlot_PushColormap_PlotColormap(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.ImPlot_PushColormap_Str(a1) end
    print(a1)
    error'M.ImPlot_PushColormap could not find overloaded'
end
function M.ImPlot_PushPlotClipRect(expand)
    expand = expand or 0
    return lib.ImPlot_PushPlotClipRect(expand)
end
M.ImPlot_PushStyleColor_U32 = lib.ImPlot_PushStyleColor_U32
M.ImPlot_PushStyleColor_Vec4 = lib.ImPlot_PushStyleColor_Vec4
function M.ImPlot_PushStyleColor(a1,a2) -- generic version
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.ImPlot_PushStyleColor_U32(a1,a2) end
    if ffi.istype('const ImVec4',a2) then return M.ImPlot_PushStyleColor_Vec4(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_PushStyleColor could not find overloaded'
end
M.ImPlot_PushStyleVar_Float = lib.ImPlot_PushStyleVar_Float
M.ImPlot_PushStyleVar_Int = lib.ImPlot_PushStyleVar_Int
M.ImPlot_PushStyleVar_Vec2 = lib.ImPlot_PushStyleVar_Vec2
function M.ImPlot_PushStyleVar(a1,a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.ImPlot_PushStyleVar_Float(a1,a2) end
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return M.ImPlot_PushStyleVar_Int(a1,a2) end
    if ffi.istype('const ImVec2',a2) then return M.ImPlot_PushStyleVar_Vec2(a1,a2) end
    print(a1,a2)
    error'M.ImPlot_PushStyleVar could not find overloaded'
end
M.ImPlot_RangesOverlap = lib.ImPlot_RangesOverlap
function M.ImPlot_RegisterOrGetItem(label_id,flags,just_created)
    just_created = just_created or nil
    return lib.ImPlot_RegisterOrGetItem(label_id,flags,just_created)
end
M.ImPlot_RenderColorBar = lib.ImPlot_RenderColorBar
M.ImPlot_ResetCtxForNextAlignedPlots = lib.ImPlot_ResetCtxForNextAlignedPlots
M.ImPlot_ResetCtxForNextPlot = lib.ImPlot_ResetCtxForNextPlot
M.ImPlot_ResetCtxForNextSubplot = lib.ImPlot_ResetCtxForNextSubplot
M.ImPlot_RoundTime = lib.ImPlot_RoundTime
M.ImPlot_RoundTo = lib.ImPlot_RoundTo
function M.ImPlot_SampleColormap(t,cmap)
    cmap = cmap or -1
    return lib.ImPlot_SampleColormap(t,cmap)
end
M.ImPlot_SampleColormapU32 = lib.ImPlot_SampleColormapU32
M.ImPlot_SetAxes = lib.ImPlot_SetAxes
M.ImPlot_SetAxis = lib.ImPlot_SetAxis
M.ImPlot_SetCurrentContext = lib.ImPlot_SetCurrentContext
M.ImPlot_SetImGuiContext = lib.ImPlot_SetImGuiContext
function M.ImPlot_SetNextAxesLimits(x_min,x_max,y_min,y_max,cond)
    cond = cond or 2
    return lib.ImPlot_SetNextAxesLimits(x_min,x_max,y_min,y_max,cond)
end
M.ImPlot_SetNextAxesToFit = lib.ImPlot_SetNextAxesToFit
function M.ImPlot_SetNextAxisLimits(axis,v_min,v_max,cond)
    cond = cond or 2
    return lib.ImPlot_SetNextAxisLimits(axis,v_min,v_max,cond)
end
M.ImPlot_SetNextAxisLinks = lib.ImPlot_SetNextAxisLinks
M.ImPlot_SetNextAxisToFit = lib.ImPlot_SetNextAxisToFit
function M.ImPlot_SetupAxes(x_label,y_label,x_flags,y_flags)
    x_flags = x_flags or 0
    y_flags = y_flags or 0
    return lib.ImPlot_SetupAxes(x_label,y_label,x_flags,y_flags)
end
function M.ImPlot_SetupAxesLimits(x_min,x_max,y_min,y_max,cond)
    cond = cond or 2
    return lib.ImPlot_SetupAxesLimits(x_min,x_max,y_min,y_max,cond)
end
function M.ImPlot_SetupAxis(axis,label,flags)
    flags = flags or 0
    label = label or nil
    return lib.ImPlot_SetupAxis(axis,label,flags)
end
M.ImPlot_SetupAxisFormat_Str = lib.ImPlot_SetupAxisFormat_Str
function M.ImPlot_SetupAxisFormat_PlotFormatter(axis,formatter,data)
    data = data or nil
    return lib.ImPlot_SetupAxisFormat_PlotFormatter(axis,formatter,data)
end
function M.ImPlot_SetupAxisFormat(a1,a2,a3) -- generic version
    if (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.ImPlot_SetupAxisFormat_Str(a1,a2) end
    if ffi.istype('ImPlotFormatter',a2) then return M.ImPlot_SetupAxisFormat_PlotFormatter(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.ImPlot_SetupAxisFormat could not find overloaded'
end
function M.ImPlot_SetupAxisLimits(axis,v_min,v_max,cond)
    cond = cond or 2
    return lib.ImPlot_SetupAxisLimits(axis,v_min,v_max,cond)
end
M.ImPlot_SetupAxisLimitsConstraints = lib.ImPlot_SetupAxisLimitsConstraints
M.ImPlot_SetupAxisLinks = lib.ImPlot_SetupAxisLinks
M.ImPlot_SetupAxisScale_PlotScale = lib.ImPlot_SetupAxisScale_PlotScale
function M.ImPlot_SetupAxisScale_PlotTransform(axis,forward,inverse,data)
    data = data or nil
    return lib.ImPlot_SetupAxisScale_PlotTransform(axis,forward,inverse,data)
end
function M.ImPlot_SetupAxisScale(a1,a2,a3,a4) -- generic version
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return M.ImPlot_SetupAxisScale_PlotScale(a1,a2) end
    if ffi.istype('ImPlotTransform',a2) then return M.ImPlot_SetupAxisScale_PlotTransform(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ImPlot_SetupAxisScale could not find overloaded'
end
function M.ImPlot_SetupAxisTicks_doublePtr(axis,values,n_ticks,labels,keep_default)
    keep_default = keep_default or false
    labels = labels or nil
    return lib.ImPlot_SetupAxisTicks_doublePtr(axis,values,n_ticks,labels,keep_default)
end
function M.ImPlot_SetupAxisTicks_double(axis,v_min,v_max,n_ticks,labels,keep_default)
    keep_default = keep_default or false
    labels = labels or nil
    return lib.ImPlot_SetupAxisTicks_double(axis,v_min,v_max,n_ticks,labels,keep_default)
end
function M.ImPlot_SetupAxisTicks(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('double*',a2) or ffi.istype('double[]',a2)) then return M.ImPlot_SetupAxisTicks_doublePtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('double',a2) or type(a2)=='number') then return M.ImPlot_SetupAxisTicks_double(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ImPlot_SetupAxisTicks could not find overloaded'
end
M.ImPlot_SetupAxisZoomConstraints = lib.ImPlot_SetupAxisZoomConstraints
M.ImPlot_SetupFinish = lib.ImPlot_SetupFinish
function M.ImPlot_SetupLegend(location,flags)
    flags = flags or 0
    return lib.ImPlot_SetupLegend(location,flags)
end
M.ImPlot_SetupLock = lib.ImPlot_SetupLock
function M.ImPlot_SetupMouseText(location,flags)
    flags = flags or 0
    return lib.ImPlot_SetupMouseText(location,flags)
end
function M.ImPlot_ShowAltLegend(title_id,vertical,size,interactable)
    if interactable == nil then interactable = true end
    size = size or ImVec2(0,0)
    if vertical == nil then vertical = true end
    return lib.ImPlot_ShowAltLegend(title_id,vertical,size,interactable)
end
function M.ImPlot_ShowAxisContextMenu(axis,equal_axis,time_allowed)
    time_allowed = time_allowed or false
    return lib.ImPlot_ShowAxisContextMenu(axis,equal_axis,time_allowed)
end
M.ImPlot_ShowColormapSelector = lib.ImPlot_ShowColormapSelector
function M.ImPlot_ShowDatePicker(id,level,t,t1,t2)
    t1 = t1 or nil
    t2 = t2 or nil
    return lib.ImPlot_ShowDatePicker(id,level,t,t1,t2)
end
function M.ImPlot_ShowDemoWindow(p_open)
    p_open = p_open or nil
    return lib.ImPlot_ShowDemoWindow(p_open)
end
M.ImPlot_ShowInputMapSelector = lib.ImPlot_ShowInputMapSelector
M.ImPlot_ShowLegendContextMenu = lib.ImPlot_ShowLegendContextMenu
M.ImPlot_ShowLegendEntries = lib.ImPlot_ShowLegendEntries
function M.ImPlot_ShowMetricsWindow(p_popen)
    p_popen = p_popen or nil
    return lib.ImPlot_ShowMetricsWindow(p_popen)
end
M.ImPlot_ShowPlotContextMenu = lib.ImPlot_ShowPlotContextMenu
function M.ImPlot_ShowStyleEditor(ref)
    ref = ref or nil
    return lib.ImPlot_ShowStyleEditor(ref)
end
M.ImPlot_ShowStyleSelector = lib.ImPlot_ShowStyleSelector
M.ImPlot_ShowSubplotsContextMenu = lib.ImPlot_ShowSubplotsContextMenu
M.ImPlot_ShowTimePicker = lib.ImPlot_ShowTimePicker
M.ImPlot_ShowUserGuide = lib.ImPlot_ShowUserGuide
function M.ImPlot_StyleColorsAuto(dst)
    dst = dst or nil
    return lib.ImPlot_StyleColorsAuto(dst)
end
function M.ImPlot_StyleColorsClassic(dst)
    dst = dst or nil
    return lib.ImPlot_StyleColorsClassic(dst)
end
function M.ImPlot_StyleColorsDark(dst)
    dst = dst or nil
    return lib.ImPlot_StyleColorsDark(dst)
end
function M.ImPlot_StyleColorsLight(dst)
    dst = dst or nil
    return lib.ImPlot_StyleColorsLight(dst)
end
M.ImPlot_SubplotNextCell = lib.ImPlot_SubplotNextCell
function M.ImPlot_TagX_Bool(x,col,round)
    round = round or false
    return lib.ImPlot_TagX_Bool(x,col,round)
end
M.ImPlot_TagX_Str = lib.ImPlot_TagX_Str
function M.ImPlot_TagX(a1,a2,a3,...) -- generic version
    if ((ffi.istype('bool',a3) or type(a3)=='boolean') or type(a3)=='nil') then return M.ImPlot_TagX_Bool(a1,a2,a3) end
    if (ffi.istype('const char*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_TagX_Str(a1,a2,a3,...) end
    print(a1,a2,a3,...)
    error'M.ImPlot_TagX could not find overloaded'
end
M.ImPlot_TagXV = lib.ImPlot_TagXV
function M.ImPlot_TagY_Bool(y,col,round)
    round = round or false
    return lib.ImPlot_TagY_Bool(y,col,round)
end
M.ImPlot_TagY_Str = lib.ImPlot_TagY_Str
function M.ImPlot_TagY(a1,a2,a3,...) -- generic version
    if ((ffi.istype('bool',a3) or type(a3)=='boolean') or type(a3)=='nil') then return M.ImPlot_TagY_Bool(a1,a2,a3) end
    if (ffi.istype('const char*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.ImPlot_TagY_Str(a1,a2,a3,...) end
    print(a1,a2,a3,...)
    error'M.ImPlot_TagY could not find overloaded'
end
M.ImPlot_TagYV = lib.ImPlot_TagYV
M.ImPlot_Today = lib.ImPlot_Today
M.ImPlot_TransformForward_Log10 = lib.ImPlot_TransformForward_Log10
M.ImPlot_TransformForward_Logit = lib.ImPlot_TransformForward_Logit
M.ImPlot_TransformForward_SymLog = lib.ImPlot_TransformForward_SymLog
M.ImPlot_TransformInverse_Log10 = lib.ImPlot_TransformInverse_Log10
M.ImPlot_TransformInverse_Logit = lib.ImPlot_TransformInverse_Logit
M.ImPlot_TransformInverse_SymLog = lib.ImPlot_TransformInverse_SymLog
M.SetDejavu = lib.SetDejavu
M.ax_NodeEditor_AcceptCopy = lib.ax_NodeEditor_AcceptCopy
M.ax_NodeEditor_AcceptCreateNode = lib.ax_NodeEditor_AcceptCreateNode
M.ax_NodeEditor_AcceptCut = lib.ax_NodeEditor_AcceptCut
function M.ax_NodeEditor_AcceptDeletedItem(deleteDependencies)
    if deleteDependencies == nil then deleteDependencies = true end
    return lib.ax_NodeEditor_AcceptDeletedItem(deleteDependencies)
end
M.ax_NodeEditor_AcceptDuplicate = lib.ax_NodeEditor_AcceptDuplicate
M.ax_NodeEditor_AcceptNewItem_Nil = lib.ax_NodeEditor_AcceptNewItem_Nil
function M.ax_NodeEditor_AcceptNewItem_Vec4(color,thickness)
    thickness = thickness or 1.0
    return lib.ax_NodeEditor_AcceptNewItem_Vec4(color,thickness)
end
function M.ax_NodeEditor_AcceptNewItem(a1,a2) -- generic version
    if a1==nil then return M.ax_NodeEditor_AcceptNewItem_Nil() end
    if ffi.istype('const ImVec4',a1) then return M.ax_NodeEditor_AcceptNewItem_Vec4(a1,a2) end
    print(a1,a2)
    error'M.ax_NodeEditor_AcceptNewItem could not find overloaded'
end
M.ax_NodeEditor_AcceptPaste = lib.ax_NodeEditor_AcceptPaste
M.ax_NodeEditor_AreShortcutsEnabled = lib.ax_NodeEditor_AreShortcutsEnabled
function M.ax_NodeEditor_Begin(id,size)
    size = size or ImVec2(0,0)
    return lib.ax_NodeEditor_Begin(id,size)
end
function M.ax_NodeEditor_BeginCreate(color,thickness)
    color = color or ImVec4(1,1,1,1)
    thickness = thickness or 1.0
    return lib.ax_NodeEditor_BeginCreate(color,thickness)
end
M.ax_NodeEditor_BeginDelete = lib.ax_NodeEditor_BeginDelete
M.ax_NodeEditor_BeginGroupHint = lib.ax_NodeEditor_BeginGroupHint
M.ax_NodeEditor_BeginNode = lib.ax_NodeEditor_BeginNode
M.ax_NodeEditor_BeginPin = lib.ax_NodeEditor_BeginPin
M.ax_NodeEditor_BeginShortcut = lib.ax_NodeEditor_BeginShortcut
M.ax_NodeEditor_BreakLinks_NodeId = lib.ax_NodeEditor_BreakLinks_NodeId
M.ax_NodeEditor_BreakLinks_PinId = lib.ax_NodeEditor_BreakLinks_PinId
function M.ax_NodeEditor_BreakLinks(a1) -- generic version
    if ffi.istype('NodeId',a1) then return M.ax_NodeEditor_BreakLinks_NodeId(a1) end
    if ffi.istype('PinId',a1) then return M.ax_NodeEditor_BreakLinks_PinId(a1) end
    print(a1)
    error'M.ax_NodeEditor_BreakLinks could not find overloaded'
end
M.ax_NodeEditor_CanvasToScreen = lib.ax_NodeEditor_CanvasToScreen
M.ax_NodeEditor_CenterNodeOnScreen = lib.ax_NodeEditor_CenterNodeOnScreen
M.ax_NodeEditor_ClearSelection = lib.ax_NodeEditor_ClearSelection
function M.ax_NodeEditor_CreateEditor(config)
    config = config or nil
    return lib.ax_NodeEditor_CreateEditor(config)
end
M.ax_NodeEditor_DeleteLink = lib.ax_NodeEditor_DeleteLink
M.ax_NodeEditor_DeleteNode = lib.ax_NodeEditor_DeleteNode
M.ax_NodeEditor_DeselectLink = lib.ax_NodeEditor_DeselectLink
M.ax_NodeEditor_DeselectNode = lib.ax_NodeEditor_DeselectNode
M.ax_NodeEditor_DestroyEditor = lib.ax_NodeEditor_DestroyEditor
M.ax_NodeEditor_EnableShortcuts = lib.ax_NodeEditor_EnableShortcuts
M.ax_NodeEditor_End = lib.ax_NodeEditor_End
M.ax_NodeEditor_EndCreate = lib.ax_NodeEditor_EndCreate
M.ax_NodeEditor_EndDelete = lib.ax_NodeEditor_EndDelete
M.ax_NodeEditor_EndGroupHint = lib.ax_NodeEditor_EndGroupHint
M.ax_NodeEditor_EndNode = lib.ax_NodeEditor_EndNode
M.ax_NodeEditor_EndPin = lib.ax_NodeEditor_EndPin
M.ax_NodeEditor_EndShortcut = lib.ax_NodeEditor_EndShortcut
function M.ax_NodeEditor_Flow(linkId,direction)
    direction = direction or 0
    return lib.ax_NodeEditor_Flow(linkId,direction)
end
M.ax_NodeEditor_GetActionContextLinks = lib.ax_NodeEditor_GetActionContextLinks
M.ax_NodeEditor_GetActionContextNodes = lib.ax_NodeEditor_GetActionContextNodes
M.ax_NodeEditor_GetActionContextSize = lib.ax_NodeEditor_GetActionContextSize
M.ax_NodeEditor_GetBackgroundClickButtonIndex = lib.ax_NodeEditor_GetBackgroundClickButtonIndex
M.ax_NodeEditor_GetBackgroundDoubleClickButtonIndex = lib.ax_NodeEditor_GetBackgroundDoubleClickButtonIndex
function M.ax_NodeEditor_GetConfig(ctx)
    ctx = ctx or nil
    return lib.ax_NodeEditor_GetConfig(ctx)
end
M.ax_NodeEditor_GetCurrentEditor = lib.ax_NodeEditor_GetCurrentEditor
M.ax_NodeEditor_GetCurrentZoom = lib.ax_NodeEditor_GetCurrentZoom
M.ax_NodeEditor_GetDoubleClickedLink = lib.ax_NodeEditor_GetDoubleClickedLink
M.ax_NodeEditor_GetDoubleClickedNode = lib.ax_NodeEditor_GetDoubleClickedNode
M.ax_NodeEditor_GetDoubleClickedPin = lib.ax_NodeEditor_GetDoubleClickedPin
M.ax_NodeEditor_GetGroupMax = lib.ax_NodeEditor_GetGroupMax
M.ax_NodeEditor_GetGroupMin = lib.ax_NodeEditor_GetGroupMin
M.ax_NodeEditor_GetHintBackgroundDrawList = lib.ax_NodeEditor_GetHintBackgroundDrawList
M.ax_NodeEditor_GetHintForegroundDrawList = lib.ax_NodeEditor_GetHintForegroundDrawList
M.ax_NodeEditor_GetHoveredLink = lib.ax_NodeEditor_GetHoveredLink
M.ax_NodeEditor_GetHoveredNode = lib.ax_NodeEditor_GetHoveredNode
M.ax_NodeEditor_GetHoveredPin = lib.ax_NodeEditor_GetHoveredPin
M.ax_NodeEditor_GetLinkPins = lib.ax_NodeEditor_GetLinkPins
M.ax_NodeEditor_GetNodeBackgroundDrawList = lib.ax_NodeEditor_GetNodeBackgroundDrawList
M.ax_NodeEditor_GetNodeCount = lib.ax_NodeEditor_GetNodeCount
M.ax_NodeEditor_GetNodePosition = lib.ax_NodeEditor_GetNodePosition
M.ax_NodeEditor_GetNodeSize = lib.ax_NodeEditor_GetNodeSize
M.ax_NodeEditor_GetNodeZPosition = lib.ax_NodeEditor_GetNodeZPosition
M.ax_NodeEditor_GetOrderedNodeIds = lib.ax_NodeEditor_GetOrderedNodeIds
M.ax_NodeEditor_GetScreenSize = lib.ax_NodeEditor_GetScreenSize
M.ax_NodeEditor_GetSelectedLinks = lib.ax_NodeEditor_GetSelectedLinks
M.ax_NodeEditor_GetSelectedNodes = lib.ax_NodeEditor_GetSelectedNodes
M.ax_NodeEditor_GetSelectedObjectCount = lib.ax_NodeEditor_GetSelectedObjectCount
M.ax_NodeEditor_GetStyle = lib.ax_NodeEditor_GetStyle
M.ax_NodeEditor_GetStyleColorName = lib.ax_NodeEditor_GetStyleColorName
M.ax_NodeEditor_Group = lib.ax_NodeEditor_Group
M.ax_NodeEditor_HasAnyLinks_NodeId = lib.ax_NodeEditor_HasAnyLinks_NodeId
M.ax_NodeEditor_HasAnyLinks_PinId = lib.ax_NodeEditor_HasAnyLinks_PinId
function M.ax_NodeEditor_HasAnyLinks(a1) -- generic version
    if ffi.istype('NodeId',a1) then return M.ax_NodeEditor_HasAnyLinks_NodeId(a1) end
    if ffi.istype('PinId',a1) then return M.ax_NodeEditor_HasAnyLinks_PinId(a1) end
    print(a1)
    error'M.ax_NodeEditor_HasAnyLinks could not find overloaded'
end
M.ax_NodeEditor_HasSelectionChanged = lib.ax_NodeEditor_HasSelectionChanged
M.ax_NodeEditor_IsActive = lib.ax_NodeEditor_IsActive
M.ax_NodeEditor_IsBackgroundClicked = lib.ax_NodeEditor_IsBackgroundClicked
M.ax_NodeEditor_IsBackgroundDoubleClicked = lib.ax_NodeEditor_IsBackgroundDoubleClicked
M.ax_NodeEditor_IsLinkSelected = lib.ax_NodeEditor_IsLinkSelected
M.ax_NodeEditor_IsNodeSelected = lib.ax_NodeEditor_IsNodeSelected
M.ax_NodeEditor_IsSuspended = lib.ax_NodeEditor_IsSuspended
function M.ax_NodeEditor_Link(id,startPinId,endPinId,color,thickness)
    color = color or ImVec4(1,1,1,1)
    thickness = thickness or 1.0
    return lib.ax_NodeEditor_Link(id,startPinId,endPinId,color,thickness)
end
function M.ax_NodeEditor_NavigateToContent(duration)
    duration = duration or -1
    return lib.ax_NodeEditor_NavigateToContent(duration)
end
function M.ax_NodeEditor_NavigateToSelection(zoomIn,duration)
    duration = duration or -1
    zoomIn = zoomIn or false
    return lib.ax_NodeEditor_NavigateToSelection(zoomIn,duration)
end
M.ax_NodeEditor_PinHadAnyLinks = lib.ax_NodeEditor_PinHadAnyLinks
M.ax_NodeEditor_PinPivotAlignment = lib.ax_NodeEditor_PinPivotAlignment
M.ax_NodeEditor_PinPivotRect = lib.ax_NodeEditor_PinPivotRect
M.ax_NodeEditor_PinPivotScale = lib.ax_NodeEditor_PinPivotScale
M.ax_NodeEditor_PinPivotSize = lib.ax_NodeEditor_PinPivotSize
M.ax_NodeEditor_PinRect = lib.ax_NodeEditor_PinRect
function M.ax_NodeEditor_PopStyleColor(count)
    count = count or 1
    return lib.ax_NodeEditor_PopStyleColor(count)
end
function M.ax_NodeEditor_PopStyleVar(count)
    count = count or 1
    return lib.ax_NodeEditor_PopStyleVar(count)
end
M.ax_NodeEditor_PushStyleColor = lib.ax_NodeEditor_PushStyleColor
M.ax_NodeEditor_PushStyleVar_Float = lib.ax_NodeEditor_PushStyleVar_Float
M.ax_NodeEditor_PushStyleVar_Vec2 = lib.ax_NodeEditor_PushStyleVar_Vec2
M.ax_NodeEditor_PushStyleVar_Vec4 = lib.ax_NodeEditor_PushStyleVar_Vec4
function M.ax_NodeEditor_PushStyleVar(a1,a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.ax_NodeEditor_PushStyleVar_Float(a1,a2) end
    if ffi.istype('const ImVec2',a2) then return M.ax_NodeEditor_PushStyleVar_Vec2(a1,a2) end
    if ffi.istype('const ImVec4',a2) then return M.ax_NodeEditor_PushStyleVar_Vec4(a1,a2) end
    print(a1,a2)
    error'M.ax_NodeEditor_PushStyleVar could not find overloaded'
end
function M.ax_NodeEditor_QueryDeletedLink(linkId,startId,endId)
    endId = endId or nil
    startId = startId or nil
    return lib.ax_NodeEditor_QueryDeletedLink(linkId,startId,endId)
end
M.ax_NodeEditor_QueryDeletedNode = lib.ax_NodeEditor_QueryDeletedNode
M.ax_NodeEditor_QueryNewLink_Nil = lib.ax_NodeEditor_QueryNewLink_Nil
function M.ax_NodeEditor_QueryNewLink_Vec4(startId,endId,color,thickness)
    thickness = thickness or 1.0
    return lib.ax_NodeEditor_QueryNewLink_Vec4(startId,endId,color,thickness)
end
function M.ax_NodeEditor_QueryNewLink(a1,a2,a3,a4) -- generic version
    if a3==nil then return M.ax_NodeEditor_QueryNewLink_Nil(a1,a2) end
    if ffi.istype('const ImVec4',a3) then return M.ax_NodeEditor_QueryNewLink_Vec4(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.ax_NodeEditor_QueryNewLink could not find overloaded'
end
M.ax_NodeEditor_QueryNewNode_Nil = lib.ax_NodeEditor_QueryNewNode_Nil
function M.ax_NodeEditor_QueryNewNode_Vec4(pinId,color,thickness)
    thickness = thickness or 1.0
    return lib.ax_NodeEditor_QueryNewNode_Vec4(pinId,color,thickness)
end
function M.ax_NodeEditor_QueryNewNode(a1,a2,a3) -- generic version
    if a2==nil then return M.ax_NodeEditor_QueryNewNode_Nil(a1) end
    if ffi.istype('const ImVec4',a2) then return M.ax_NodeEditor_QueryNewNode_Vec4(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.ax_NodeEditor_QueryNewNode could not find overloaded'
end
M.ax_NodeEditor_RejectDeletedItem = lib.ax_NodeEditor_RejectDeletedItem
M.ax_NodeEditor_RejectNewItem_Nil = lib.ax_NodeEditor_RejectNewItem_Nil
function M.ax_NodeEditor_RejectNewItem_Vec4(color,thickness)
    thickness = thickness or 1.0
    return lib.ax_NodeEditor_RejectNewItem_Vec4(color,thickness)
end
function M.ax_NodeEditor_RejectNewItem(a1,a2) -- generic version
    if a1==nil then return M.ax_NodeEditor_RejectNewItem_Nil() end
    if ffi.istype('const ImVec4',a1) then return M.ax_NodeEditor_RejectNewItem_Vec4(a1,a2) end
    print(a1,a2)
    error'M.ax_NodeEditor_RejectNewItem could not find overloaded'
end
M.ax_NodeEditor_RestoreNodeState = lib.ax_NodeEditor_RestoreNodeState
M.ax_NodeEditor_Resume = lib.ax_NodeEditor_Resume
M.ax_NodeEditor_ScreenToCanvas = lib.ax_NodeEditor_ScreenToCanvas
function M.ax_NodeEditor_SelectLink(linkId,append)
    append = append or false
    return lib.ax_NodeEditor_SelectLink(linkId,append)
end
function M.ax_NodeEditor_SelectNode(nodeId,append)
    append = append or false
    return lib.ax_NodeEditor_SelectNode(nodeId,append)
end
M.ax_NodeEditor_SetCurrentEditor = lib.ax_NodeEditor_SetCurrentEditor
M.ax_NodeEditor_SetGroupSize = lib.ax_NodeEditor_SetGroupSize
M.ax_NodeEditor_SetNodePosition = lib.ax_NodeEditor_SetNodePosition
M.ax_NodeEditor_SetNodeZPosition = lib.ax_NodeEditor_SetNodeZPosition
M.ax_NodeEditor_ShowBackgroundContextMenu = lib.ax_NodeEditor_ShowBackgroundContextMenu
M.ax_NodeEditor_ShowLinkContextMenu = lib.ax_NodeEditor_ShowLinkContextMenu
M.ax_NodeEditor_ShowNodeContextMenu = lib.ax_NodeEditor_ShowNodeContextMenu
M.ax_NodeEditor_ShowPinContextMenu = lib.ax_NodeEditor_ShowPinContextMenu
M.ax_NodeEditor_Suspend = lib.ax_NodeEditor_Suspend
function M.AcceptDragDropPayload(type,flags)
    flags = flags or 0
    return lib.igAcceptDragDropPayload(type,flags)
end
M.ActivateItemByID = lib.igActivateItemByID
M.AddContextHook = lib.igAddContextHook
M.AddDrawListToDrawDataEx = lib.igAddDrawListToDrawDataEx
M.AddSettingsHandler = lib.igAddSettingsHandler
M.AlignTextToFramePadding = lib.igAlignTextToFramePadding
M.ArrowButton = lib.igArrowButton
function M.ArrowButtonEx(str_id,dir,size_arg,flags)
    flags = flags or 0
    return lib.igArrowButtonEx(str_id,dir,size_arg,flags)
end
function M.Begin(name,p_open,flags)
    flags = flags or 0
    p_open = p_open or nil
    return lib.igBegin(name,p_open,flags)
end
M.BeginBoxSelect = lib.igBeginBoxSelect
function M.BeginChild_Str(str_id,size,child_flags,window_flags)
    child_flags = child_flags or 0
    size = size or ImVec2(0,0)
    window_flags = window_flags or 0
    return lib.igBeginChild_Str(str_id,size,child_flags,window_flags)
end
function M.BeginChild_ID(id,size,child_flags,window_flags)
    child_flags = child_flags or 0
    size = size or ImVec2(0,0)
    window_flags = window_flags or 0
    return lib.igBeginChild_ID(id,size,child_flags,window_flags)
end
function M.BeginChild(a1,a2,a3,a4) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.BeginChild_Str(a1,a2,a3,a4) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.BeginChild_ID(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.BeginChild could not find overloaded'
end
M.BeginChildEx = lib.igBeginChildEx
function M.BeginColumns(str_id,count,flags)
    flags = flags or 0
    return lib.igBeginColumns(str_id,count,flags)
end
function M.BeginCombo(label,preview_value,flags)
    flags = flags or 0
    return lib.igBeginCombo(label,preview_value,flags)
end
M.BeginComboPopup = lib.igBeginComboPopup
M.BeginComboPreview = lib.igBeginComboPreview
function M.BeginDisabled(disabled)
    if disabled == nil then disabled = true end
    return lib.igBeginDisabled(disabled)
end
M.BeginDisabledOverrideReenable = lib.igBeginDisabledOverrideReenable
M.BeginDockableDragDropSource = lib.igBeginDockableDragDropSource
M.BeginDockableDragDropTarget = lib.igBeginDockableDragDropTarget
M.BeginDocked = lib.igBeginDocked
function M.BeginDragDropSource(flags)
    flags = flags or 0
    return lib.igBeginDragDropSource(flags)
end
M.BeginDragDropTarget = lib.igBeginDragDropTarget
M.BeginDragDropTargetCustom = lib.igBeginDragDropTargetCustom
function M.BeginDragDropTargetViewport(viewport,p_bb)
    p_bb = p_bb or nil
    return lib.igBeginDragDropTargetViewport(viewport,p_bb)
end
M.BeginErrorTooltip = lib.igBeginErrorTooltip
M.BeginGroup = lib.igBeginGroup
M.BeginItemTooltip = lib.igBeginItemTooltip
function M.BeginListBox(label,size)
    size = size or ImVec2(0,0)
    return lib.igBeginListBox(label,size)
end
M.BeginMainMenuBar = lib.igBeginMainMenuBar
function M.BeginMenu(label,enabled)
    if enabled == nil then enabled = true end
    return lib.igBeginMenu(label,enabled)
end
M.BeginMenuBar = lib.igBeginMenuBar
function M.BeginMenuEx(label,icon,enabled)
    if enabled == nil then enabled = true end
    return lib.igBeginMenuEx(label,icon,enabled)
end
function M.BeginMultiSelect(flags,selection_size,items_count)
    items_count = items_count or -1
    selection_size = selection_size or -1
    return lib.igBeginMultiSelect(flags,selection_size,items_count)
end
function M.BeginPopup(str_id,flags)
    flags = flags or 0
    return lib.igBeginPopup(str_id,flags)
end
function M.BeginPopupContextItem(str_id,popup_flags)
    popup_flags = popup_flags or 0
    str_id = str_id or nil
    return lib.igBeginPopupContextItem(str_id,popup_flags)
end
function M.BeginPopupContextVoid(str_id,popup_flags)
    popup_flags = popup_flags or 0
    str_id = str_id or nil
    return lib.igBeginPopupContextVoid(str_id,popup_flags)
end
function M.BeginPopupContextWindow(str_id,popup_flags)
    popup_flags = popup_flags or 0
    str_id = str_id or nil
    return lib.igBeginPopupContextWindow(str_id,popup_flags)
end
M.BeginPopupEx = lib.igBeginPopupEx
M.BeginPopupMenuEx = lib.igBeginPopupMenuEx
function M.BeginPopupModal(name,p_open,flags)
    flags = flags or 0
    p_open = p_open or nil
    return lib.igBeginPopupModal(name,p_open,flags)
end
function M.BeginTabBar(str_id,flags)
    flags = flags or 0
    return lib.igBeginTabBar(str_id,flags)
end
M.BeginTabBarEx = lib.igBeginTabBarEx
function M.BeginTabItem(label,p_open,flags)
    flags = flags or 0
    p_open = p_open or nil
    return lib.igBeginTabItem(label,p_open,flags)
end
function M.BeginTable(str_id,columns,flags,outer_size,inner_width)
    flags = flags or 0
    inner_width = inner_width or 0.0
    outer_size = outer_size or ImVec2(0.0,0.0)
    return lib.igBeginTable(str_id,columns,flags,outer_size,inner_width)
end
function M.BeginTableEx(name,id,columns_count,flags,outer_size,inner_width)
    flags = flags or 0
    inner_width = inner_width or 0.0
    outer_size = outer_size or ImVec2(0,0)
    return lib.igBeginTableEx(name,id,columns_count,flags,outer_size,inner_width)
end
M.BeginTooltip = lib.igBeginTooltip
M.BeginTooltipEx = lib.igBeginTooltipEx
M.BeginTooltipHidden = lib.igBeginTooltipHidden
M.BeginViewportSideBar = lib.igBeginViewportSideBar
M.BringWindowToDisplayBack = lib.igBringWindowToDisplayBack
M.BringWindowToDisplayBehind = lib.igBringWindowToDisplayBehind
M.BringWindowToDisplayFront = lib.igBringWindowToDisplayFront
M.BringWindowToFocusFront = lib.igBringWindowToFocusFront
M.Bullet = lib.igBullet
M.BulletText = lib.igBulletText
M.BulletTextV = lib.igBulletTextV
function M.Button(label,size)
    size = size or ImVec2(0,0)
    return lib.igButton(label,size)
end
function M.ButtonBehavior(bb,id,out_hovered,out_held,flags)
    flags = flags or 0
    return lib.igButtonBehavior(bb,id,out_hovered,out_held,flags)
end
function M.ButtonEx(label,size_arg,flags)
    flags = flags or 0
    size_arg = size_arg or ImVec2(0,0)
    return lib.igButtonEx(label,size_arg,flags)
end
M.CalcClipRectVisibleItemsY = lib.igCalcClipRectVisibleItemsY
M.CalcItemSize = lib.igCalcItemSize
M.CalcItemWidth = lib.igCalcItemWidth
M.CalcRoundingFlagsForRectInRect = lib.igCalcRoundingFlagsForRectInRect
function M.CalcTextSize(text,text_end,hide_text_after_double_hash,wrap_width)
    hide_text_after_double_hash = hide_text_after_double_hash or false
    text_end = text_end or nil
    wrap_width = wrap_width or -1.0
    return lib.igCalcTextSize(text,text_end,hide_text_after_double_hash,wrap_width)
end
M.CalcTypematicRepeatAmount = lib.igCalcTypematicRepeatAmount
M.CalcWindowNextAutoFitSize = lib.igCalcWindowNextAutoFitSize
M.CalcWrapWidthForPos = lib.igCalcWrapWidthForPos
M.CallContextHooks = lib.igCallContextHooks
M.Checkbox = lib.igCheckbox
M.CheckboxFlags_IntPtr = lib.igCheckboxFlags_IntPtr
M.CheckboxFlags_UintPtr = lib.igCheckboxFlags_UintPtr
M.CheckboxFlags_S64Ptr = lib.igCheckboxFlags_S64Ptr
M.CheckboxFlags_U64Ptr = lib.igCheckboxFlags_U64Ptr
function M.CheckboxFlags(a1,a2,a3) -- generic version
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.CheckboxFlags_IntPtr(a1,a2,a3) end
    if ffi.typeof('uint32_t*') == ffi.typeof(a2) or ffi.typeof('const uint32_t*') == ffi.typeof(a2) or ffi.typeof('uint32_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint32_t[?]') == ffi.typeof(a2) then return M.CheckboxFlags_UintPtr(a1,a2,a3) end
    if ffi.typeof('int64_t*') == ffi.typeof(a2) or ffi.typeof('const int64_t*') == ffi.typeof(a2) or ffi.typeof('int64_t[?]') == ffi.typeof(a2) or ffi.typeof('const int64_t[?]') == ffi.typeof(a2) then return M.CheckboxFlags_S64Ptr(a1,a2,a3) end
    if ffi.typeof('uint64_t*') == ffi.typeof(a2) or ffi.typeof('const uint64_t*') == ffi.typeof(a2) or ffi.typeof('uint64_t[?]') == ffi.typeof(a2) or ffi.typeof('const uint64_t[?]') == ffi.typeof(a2) then return M.CheckboxFlags_U64Ptr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.CheckboxFlags could not find overloaded'
end
M.CleanupIniSettings = lib.igCleanupIniSettings
M.ClearActiveID = lib.igClearActiveID
M.ClearDragDrop = lib.igClearDragDrop
M.ClearIniSettings = lib.igClearIniSettings
M.ClearWindowSettings = lib.igClearWindowSettings
M.CloseButton = lib.igCloseButton
M.CloseCurrentPopup = lib.igCloseCurrentPopup
M.ClosePopupToLevel = lib.igClosePopupToLevel
M.ClosePopupsExceptModals = lib.igClosePopupsExceptModals
M.ClosePopupsOverWindow = lib.igClosePopupsOverWindow
M.CollapseButton = lib.igCollapseButton
function M.CollapsingHeader_TreeNodeFlags(label,flags)
    flags = flags or 0
    return lib.igCollapsingHeader_TreeNodeFlags(label,flags)
end
function M.CollapsingHeader_BoolPtr(label,p_visible,flags)
    flags = flags or 0
    return lib.igCollapsingHeader_BoolPtr(label,p_visible,flags)
end
function M.CollapsingHeader(a1,a2,a3) -- generic version
    if ((ffi.istype('int32_t',a2) or type(a2)=='number') or type(a2)=='nil') then return M.CollapsingHeader_TreeNodeFlags(a1,a2) end
    if (ffi.istype('bool*',a2) or ffi.istype('bool[]',a2)) then return M.CollapsingHeader_BoolPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.CollapsingHeader could not find overloaded'
end
function M.ColorButton(desc_id,col,flags,size)
    flags = flags or 0
    size = size or ImVec2(0,0)
    return lib.igColorButton(desc_id,col,flags,size)
end
M.ColorConvertFloat4ToU32 = lib.igColorConvertFloat4ToU32
M.ColorConvertHSVtoRGB = lib.igColorConvertHSVtoRGB
M.ColorConvertRGBtoHSV = lib.igColorConvertRGBtoHSV
M.ColorConvertU32ToFloat4 = lib.igColorConvertU32ToFloat4
function M.ColorEdit3(label,col,flags)
    flags = flags or 0
    return lib.igColorEdit3(label,col,flags)
end
function M.ColorEdit4(label,col,flags)
    flags = flags or 0
    return lib.igColorEdit4(label,col,flags)
end
M.ColorEditOptionsPopup = lib.igColorEditOptionsPopup
function M.ColorPicker3(label,col,flags)
    flags = flags or 0
    return lib.igColorPicker3(label,col,flags)
end
function M.ColorPicker4(label,col,flags,ref_col)
    flags = flags or 0
    ref_col = ref_col or nil
    return lib.igColorPicker4(label,col,flags,ref_col)
end
M.ColorPickerOptionsPopup = lib.igColorPickerOptionsPopup
M.ColorTooltip = lib.igColorTooltip
function M.Columns(count,id,borders)
    if borders == nil then borders = true end
    count = count or 1
    id = id or nil
    return lib.igColumns(count,id,borders)
end
function M.Combo_Str_arr(label,current_item,items,items_count,popup_max_height_in_items)
    popup_max_height_in_items = popup_max_height_in_items or -1
    return lib.igCombo_Str_arr(label,current_item,items,items_count,popup_max_height_in_items)
end
function M.Combo_Str(label,current_item,items_separated_by_zeros,popup_max_height_in_items)
    popup_max_height_in_items = popup_max_height_in_items or -1
    return lib.igCombo_Str(label,current_item,items_separated_by_zeros,popup_max_height_in_items)
end
function M.Combo_FnStrPtr(label,current_item,getter,user_data,items_count,popup_max_height_in_items)
    popup_max_height_in_items = popup_max_height_in_items or -1
    return lib.igCombo_FnStrPtr(label,current_item,getter,user_data,items_count,popup_max_height_in_items)
end
function M.Combo(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('const char* const[]',a3) or ffi.istype('const char const[]',a3) or ffi.istype('const char const[][]',a3)) then return M.Combo_Str_arr(a1,a2,a3,a4,a5) end
    if (ffi.istype('const char*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.Combo_Str(a1,a2,a3,a4) end
    if ffi.istype('const char*(*)(void* user_data,int idx)',a3) then return M.Combo_FnStrPtr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.Combo could not find overloaded'
end
M.ConvertSingleModFlagToKey = lib.igConvertSingleModFlagToKey
function M.CreateContext(shared_font_atlas)
    shared_font_atlas = shared_font_atlas or nil
    return lib.igCreateContext(shared_font_atlas)
end
M.CreateNewWindowSettings = lib.igCreateNewWindowSettings
function M.DataTypeApplyFromText(buf,data_type,p_data,format,p_data_when_empty)
    p_data_when_empty = p_data_when_empty or nil
    return lib.igDataTypeApplyFromText(buf,data_type,p_data,format,p_data_when_empty)
end
M.DataTypeApplyOp = lib.igDataTypeApplyOp
M.DataTypeClamp = lib.igDataTypeClamp
M.DataTypeCompare = lib.igDataTypeCompare
M.DataTypeFormatString = lib.igDataTypeFormatString
M.DataTypeGetInfo = lib.igDataTypeGetInfo
M.DataTypeIsZero = lib.igDataTypeIsZero
M.DebugAllocHook = lib.igDebugAllocHook
M.DebugBreakButton = lib.igDebugBreakButton
M.DebugBreakButtonTooltip = lib.igDebugBreakButtonTooltip
M.DebugBreakClearData = lib.igDebugBreakClearData
M.DebugCheckVersionAndDataLayout = lib.igDebugCheckVersionAndDataLayout
function M.DebugDrawCursorPos(col)
    col = col or 4278190335
    return lib.igDebugDrawCursorPos(col)
end
function M.DebugDrawItemRect(col)
    col = col or 4278190335
    return lib.igDebugDrawItemRect(col)
end
function M.DebugDrawLineExtents(col)
    col = col or 4278190335
    return lib.igDebugDrawLineExtents(col)
end
M.DebugFlashStyleColor = lib.igDebugFlashStyleColor
M.DebugHookIdInfo = lib.igDebugHookIdInfo
M.DebugLocateItem = lib.igDebugLocateItem
M.DebugLocateItemOnHover = lib.igDebugLocateItemOnHover
M.DebugLocateItemResolveWithLastItem = lib.igDebugLocateItemResolveWithLastItem
M.DebugLog = lib.igDebugLog
M.DebugLogV = lib.igDebugLogV
M.DebugNodeColumns = lib.igDebugNodeColumns
M.DebugNodeDockNode = lib.igDebugNodeDockNode
M.DebugNodeDrawCmdShowMeshAndBoundingBox = lib.igDebugNodeDrawCmdShowMeshAndBoundingBox
M.DebugNodeDrawList = lib.igDebugNodeDrawList
M.DebugNodeFont = lib.igDebugNodeFont
M.DebugNodeFontGlyph = lib.igDebugNodeFontGlyph
M.DebugNodeFontGlyphsForSrcMask = lib.igDebugNodeFontGlyphsForSrcMask
M.DebugNodeInputTextState = lib.igDebugNodeInputTextState
M.DebugNodeMultiSelectState = lib.igDebugNodeMultiSelectState
M.DebugNodePlatformMonitor = lib.igDebugNodePlatformMonitor
M.DebugNodeStorage = lib.igDebugNodeStorage
M.DebugNodeTabBar = lib.igDebugNodeTabBar
M.DebugNodeTable = lib.igDebugNodeTable
M.DebugNodeTableSettings = lib.igDebugNodeTableSettings
function M.DebugNodeTexture(tex,int_id,highlight_rect)
    highlight_rect = highlight_rect or nil
    return lib.igDebugNodeTexture(tex,int_id,highlight_rect)
end
M.DebugNodeTypingSelectState = lib.igDebugNodeTypingSelectState
M.DebugNodeViewport = lib.igDebugNodeViewport
M.DebugNodeWindow = lib.igDebugNodeWindow
M.DebugNodeWindowSettings = lib.igDebugNodeWindowSettings
M.DebugNodeWindowsList = lib.igDebugNodeWindowsList
M.DebugNodeWindowsListByBeginStackParent = lib.igDebugNodeWindowsListByBeginStackParent
M.DebugRenderKeyboardPreview = lib.igDebugRenderKeyboardPreview
M.DebugRenderViewportThumbnail = lib.igDebugRenderViewportThumbnail
M.DebugStartItemPicker = lib.igDebugStartItemPicker
M.DebugTextEncoding = lib.igDebugTextEncoding
M.DebugTextUnformattedWithLocateItem = lib.igDebugTextUnformattedWithLocateItem
M.DebugTextureIDToU64 = lib.igDebugTextureIDToU64
M.DemoMarker = lib.igDemoMarker
function M.DestroyContext(ctx)
    ctx = ctx or nil
    return lib.igDestroyContext(ctx)
end
M.DestroyPlatformWindow = lib.igDestroyPlatformWindow
M.DestroyPlatformWindows = lib.igDestroyPlatformWindows
function M.DockBuilderAddNode(node_id,flags)
    flags = flags or 0
    node_id = node_id or 0
    return lib.igDockBuilderAddNode(node_id,flags)
end
M.DockBuilderCopyDockSpace = lib.igDockBuilderCopyDockSpace
M.DockBuilderCopyNode = lib.igDockBuilderCopyNode
M.DockBuilderCopyWindowSettings = lib.igDockBuilderCopyWindowSettings
M.DockBuilderDockWindow = lib.igDockBuilderDockWindow
M.DockBuilderFinish = lib.igDockBuilderFinish
M.DockBuilderGetCentralNode = lib.igDockBuilderGetCentralNode
M.DockBuilderGetNode = lib.igDockBuilderGetNode
M.DockBuilderRemoveNode = lib.igDockBuilderRemoveNode
M.DockBuilderRemoveNodeChildNodes = lib.igDockBuilderRemoveNodeChildNodes
function M.DockBuilderRemoveNodeDockedWindows(node_id,clear_settings_refs)
    if clear_settings_refs == nil then clear_settings_refs = true end
    return lib.igDockBuilderRemoveNodeDockedWindows(node_id,clear_settings_refs)
end
M.DockBuilderSetNodePos = lib.igDockBuilderSetNodePos
M.DockBuilderSetNodeSize = lib.igDockBuilderSetNodeSize
M.DockBuilderSplitNode = lib.igDockBuilderSplitNode
M.DockContextCalcDropPosForDocking = lib.igDockContextCalcDropPosForDocking
M.DockContextClearNodes = lib.igDockContextClearNodes
M.DockContextEndFrame = lib.igDockContextEndFrame
M.DockContextFindNodeByID = lib.igDockContextFindNodeByID
M.DockContextGenNodeID = lib.igDockContextGenNodeID
M.DockContextInitialize = lib.igDockContextInitialize
M.DockContextNewFrameUpdateDocking = lib.igDockContextNewFrameUpdateDocking
M.DockContextNewFrameUpdateUndocking = lib.igDockContextNewFrameUpdateUndocking
M.DockContextProcessUndockNode = lib.igDockContextProcessUndockNode
function M.DockContextProcessUndockWindow(ctx,window,clear_persistent_docking_ref)
    if clear_persistent_docking_ref == nil then clear_persistent_docking_ref = true end
    return lib.igDockContextProcessUndockWindow(ctx,window,clear_persistent_docking_ref)
end
M.DockContextQueueDock = lib.igDockContextQueueDock
M.DockContextQueueUndockNode = lib.igDockContextQueueUndockNode
M.DockContextQueueUndockWindow = lib.igDockContextQueueUndockWindow
M.DockContextRebuildNodes = lib.igDockContextRebuildNodes
M.DockContextShutdown = lib.igDockContextShutdown
M.DockNodeBeginAmendTabBar = lib.igDockNodeBeginAmendTabBar
M.DockNodeEndAmendTabBar = lib.igDockNodeEndAmendTabBar
M.DockNodeGetDepth = lib.igDockNodeGetDepth
M.DockNodeGetRootNode = lib.igDockNodeGetRootNode
M.DockNodeGetWindowMenuButtonId = lib.igDockNodeGetWindowMenuButtonId
M.DockNodeIsInHierarchyOf = lib.igDockNodeIsInHierarchyOf
M.DockNodeWindowMenuHandler_Default = lib.igDockNodeWindowMenuHandler_Default
function M.DockSpace(dockspace_id,size,flags,window_class)
    flags = flags or 0
    size = size or ImVec2(0,0)
    window_class = window_class or nil
    return lib.igDockSpace(dockspace_id,size,flags,window_class)
end
function M.DockSpaceOverViewport(dockspace_id,viewport,flags,window_class)
    dockspace_id = dockspace_id or 0
    flags = flags or 0
    viewport = viewport or nil
    window_class = window_class or nil
    return lib.igDockSpaceOverViewport(dockspace_id,viewport,flags,window_class)
end
M.DragBehavior = lib.igDragBehavior
function M.DragFloat(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    v_max = v_max or 0.0
    v_min = v_min or 0.0
    v_speed = v_speed or 1.0
    return lib.igDragFloat(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragFloat2(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    v_max = v_max or 0.0
    v_min = v_min or 0.0
    v_speed = v_speed or 1.0
    return lib.igDragFloat2(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragFloat3(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    v_max = v_max or 0.0
    v_min = v_min or 0.0
    v_speed = v_speed or 1.0
    return lib.igDragFloat3(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragFloat4(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    v_max = v_max or 0.0
    v_min = v_min or 0.0
    v_speed = v_speed or 1.0
    return lib.igDragFloat4(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragFloatRange2(label,v_current_min,v_current_max,v_speed,v_min,v_max,format,format_max,flags)
    flags = flags or 0
    format = format or "%.3f"
    format_max = format_max or nil
    v_max = v_max or 0.0
    v_min = v_min or 0.0
    v_speed = v_speed or 1.0
    return lib.igDragFloatRange2(label,v_current_min,v_current_max,v_speed,v_min,v_max,format,format_max,flags)
end
function M.DragInt(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    v_max = v_max or 0
    v_min = v_min or 0
    v_speed = v_speed or 1.0
    return lib.igDragInt(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragInt2(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    v_max = v_max or 0
    v_min = v_min or 0
    v_speed = v_speed or 1.0
    return lib.igDragInt2(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragInt3(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    v_max = v_max or 0
    v_min = v_min or 0
    v_speed = v_speed or 1.0
    return lib.igDragInt3(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragInt4(label,v,v_speed,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    v_max = v_max or 0
    v_min = v_min or 0
    v_speed = v_speed or 1.0
    return lib.igDragInt4(label,v,v_speed,v_min,v_max,format,flags)
end
function M.DragIntRange2(label,v_current_min,v_current_max,v_speed,v_min,v_max,format,format_max,flags)
    flags = flags or 0
    format = format or "%d"
    format_max = format_max or nil
    v_max = v_max or 0
    v_min = v_min or 0
    v_speed = v_speed or 1.0
    return lib.igDragIntRange2(label,v_current_min,v_current_max,v_speed,v_min,v_max,format,format_max,flags)
end
function M.DragScalar(label,data_type,p_data,v_speed,p_min,p_max,format,flags)
    flags = flags or 0
    format = format or nil
    p_max = p_max or nil
    p_min = p_min or nil
    v_speed = v_speed or 1.0
    return lib.igDragScalar(label,data_type,p_data,v_speed,p_min,p_max,format,flags)
end
function M.DragScalarN(label,data_type,p_data,components,v_speed,p_min,p_max,format,flags)
    flags = flags or 0
    format = format or nil
    p_max = p_max or nil
    p_min = p_min or nil
    v_speed = v_speed or 1.0
    return lib.igDragScalarN(label,data_type,p_data,components,v_speed,p_min,p_max,format,flags)
end
M.Dummy = lib.igDummy
M.End = lib.igEnd
M.EndBoxSelect = lib.igEndBoxSelect
M.EndChild = lib.igEndChild
M.EndColumns = lib.igEndColumns
M.EndCombo = lib.igEndCombo
M.EndComboPreview = lib.igEndComboPreview
M.EndDisabled = lib.igEndDisabled
M.EndDisabledOverrideReenable = lib.igEndDisabledOverrideReenable
M.EndDragDropSource = lib.igEndDragDropSource
M.EndDragDropTarget = lib.igEndDragDropTarget
M.EndErrorTooltip = lib.igEndErrorTooltip
M.EndFrame = lib.igEndFrame
M.EndGroup = lib.igEndGroup
M.EndListBox = lib.igEndListBox
M.EndMainMenuBar = lib.igEndMainMenuBar
M.EndMenu = lib.igEndMenu
M.EndMenuBar = lib.igEndMenuBar
M.EndMultiSelect = lib.igEndMultiSelect
M.EndPopup = lib.igEndPopup
M.EndTabBar = lib.igEndTabBar
M.EndTabItem = lib.igEndTabItem
M.EndTable = lib.igEndTable
M.EndTooltip = lib.igEndTooltip
M.ErrorCheckEndFrameFinalizeErrorTooltip = lib.igErrorCheckEndFrameFinalizeErrorTooltip
M.ErrorCheckUsingSetCursorPosToExtendParentBoundaries = lib.igErrorCheckUsingSetCursorPosToExtendParentBoundaries
M.ErrorLog = lib.igErrorLog
M.ErrorRecoveryStoreState = lib.igErrorRecoveryStoreState
M.ErrorRecoveryTryToRecoverState = lib.igErrorRecoveryTryToRecoverState
M.ErrorRecoveryTryToRecoverWindowState = lib.igErrorRecoveryTryToRecoverWindowState
M.ExtendHitBoxWhenNearViewportEdge = lib.igExtendHitBoxWhenNearViewportEdge
M.FindBestWindowPosForPopup = lib.igFindBestWindowPosForPopup
M.FindBestWindowPosForPopupEx = lib.igFindBestWindowPosForPopupEx
M.FindBlockingModal = lib.igFindBlockingModal
M.FindBottomMostVisibleWindowWithinBeginStack = lib.igFindBottomMostVisibleWindowWithinBeginStack
M.FindFrontMostVisibleChildWindow = lib.igFindFrontMostVisibleChildWindow
M.FindHoveredViewportFromPlatformWindowStack = lib.igFindHoveredViewportFromPlatformWindowStack
M.FindHoveredWindowEx = lib.igFindHoveredWindowEx
M.FindOrCreateColumns = lib.igFindOrCreateColumns
function M.FindRenderedTextEnd(text,text_end)
    text_end = text_end or nil
    return lib.igFindRenderedTextEnd(text,text_end)
end
M.FindSettingsHandler = lib.igFindSettingsHandler
M.FindViewportByID = lib.igFindViewportByID
M.FindViewportByPlatformHandle = lib.igFindViewportByPlatformHandle
M.FindWindowByID = lib.igFindWindowByID
M.FindWindowByName = lib.igFindWindowByName
M.FindWindowDisplayIndex = lib.igFindWindowDisplayIndex
M.FindWindowSettingsByID = lib.igFindWindowSettingsByID
M.FindWindowSettingsByWindow = lib.igFindWindowSettingsByWindow
M.FixupKeyChord = lib.igFixupKeyChord
M.FocusItem = lib.igFocusItem
M.FocusTopMostWindowUnderOne = lib.igFocusTopMostWindowUnderOne
function M.FocusWindow(window,flags)
    flags = flags or 0
    return lib.igFocusWindow(window,flags)
end
M.GcAwakeTransientWindowBuffers = lib.igGcAwakeTransientWindowBuffers
M.GcCompactTransientMiscBuffers = lib.igGcCompactTransientMiscBuffers
M.GcCompactTransientWindowBuffers = lib.igGcCompactTransientWindowBuffers
M.GetActiveID = lib.igGetActiveID
M.GetAllocatorFunctions = lib.igGetAllocatorFunctions
function M.GetBackgroundDrawList(viewport)
    viewport = viewport or nil
    return lib.igGetBackgroundDrawList(viewport)
end
M.GetBoxSelectState = lib.igGetBoxSelectState
M.GetClipboardText = lib.igGetClipboardText
function M.GetColorU32_Col(idx,alpha_mul)
    alpha_mul = alpha_mul or 1.0
    return lib.igGetColorU32_Col(idx,alpha_mul)
end
M.GetColorU32_Vec4 = lib.igGetColorU32_Vec4
function M.GetColorU32_U32(col,alpha_mul)
    alpha_mul = alpha_mul or 1.0
    return lib.igGetColorU32_U32(col,alpha_mul)
end
function M.GetColorU32(a1,a2) -- generic version
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.GetColorU32_Col(a1,a2) end
    if ffi.istype('const ImVec4',a1) then return M.GetColorU32_Vec4(a1) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.GetColorU32_U32(a1,a2) end
    print(a1,a2)
    error'M.GetColorU32 could not find overloaded'
end
M.GetColumnIndex = lib.igGetColumnIndex
M.GetColumnNormFromOffset = lib.igGetColumnNormFromOffset
function M.GetColumnOffset(column_index)
    column_index = column_index or -1
    return lib.igGetColumnOffset(column_index)
end
M.GetColumnOffsetFromNorm = lib.igGetColumnOffsetFromNorm
function M.GetColumnWidth(column_index)
    column_index = column_index or -1
    return lib.igGetColumnWidth(column_index)
end
M.GetColumnsCount = lib.igGetColumnsCount
M.GetColumnsID = lib.igGetColumnsID
M.GetContentRegionAvail = lib.igGetContentRegionAvail
M.GetCurrentContext = lib.igGetCurrentContext
M.GetCurrentFocusScope = lib.igGetCurrentFocusScope
M.GetCurrentTabBar = lib.igGetCurrentTabBar
M.GetCurrentTable = lib.igGetCurrentTable
M.GetCurrentWindow = lib.igGetCurrentWindow
M.GetCurrentWindowRead = lib.igGetCurrentWindowRead
M.GetCursorPos = lib.igGetCursorPos
M.GetCursorPosX = lib.igGetCursorPosX
M.GetCursorPosY = lib.igGetCursorPosY
M.GetCursorScreenPos = lib.igGetCursorScreenPos
M.GetCursorStartPos = lib.igGetCursorStartPos
M.GetDefaultFont = lib.igGetDefaultFont
M.GetDragDropPayload = lib.igGetDragDropPayload
M.GetDrawData = lib.igGetDrawData
M.GetDrawListSharedData = lib.igGetDrawListSharedData
M.GetFocusID = lib.igGetFocusID
M.GetFont = lib.igGetFont
M.GetFontBaked = lib.igGetFontBaked
M.GetFontSize = lib.igGetFontSize
M.GetFontTexUvWhitePixel = lib.igGetFontTexUvWhitePixel
function M.GetForegroundDrawList_ViewportPtr(viewport)
    viewport = viewport or nil
    return lib.igGetForegroundDrawList_ViewportPtr(viewport)
end
M.GetForegroundDrawList_WindowPtr = lib.igGetForegroundDrawList_WindowPtr
function M.GetForegroundDrawList(a1) -- generic version
    if ((ffi.istype('ImGuiViewport*',a1) or ffi.istype('ImGuiViewport',a1) or ffi.istype('ImGuiViewport[]',a1)) or type(a1)=='nil') then return M.GetForegroundDrawList_ViewportPtr(a1) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.GetForegroundDrawList_WindowPtr(a1) end
    print(a1)
    error'M.GetForegroundDrawList could not find overloaded'
end
M.GetFrameCount = lib.igGetFrameCount
M.GetFrameHeight = lib.igGetFrameHeight
M.GetFrameHeightWithSpacing = lib.igGetFrameHeightWithSpacing
M.GetHoveredID = lib.igGetHoveredID
M.GetID_Str = lib.igGetID_Str
M.GetID_StrStr = lib.igGetID_StrStr
M.GetID_Ptr = lib.igGetID_Ptr
M.GetID_Int = lib.igGetID_Int
function M.GetID(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a2==nil then return M.GetID_Str(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.GetID_StrStr(a1,a2) end
    if ffi.istype('void *',a1) then return M.GetID_Ptr(a1) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.GetID_Int(a1) end
    print(a1,a2)
    error'M.GetID could not find overloaded'
end
M.GetIDWithSeed_Str = lib.igGetIDWithSeed_Str
M.GetIDWithSeed_Int = lib.igGetIDWithSeed_Int
function M.GetIDWithSeed(a1,a2,a3) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.GetIDWithSeed_Str(a1,a2,a3) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.GetIDWithSeed_Int(a1,a2) end
    print(a1,a2,a3)
    error'M.GetIDWithSeed could not find overloaded'
end
M.GetIO_Nil = lib.igGetIO_Nil
M.GetIO_ContextPtr = lib.igGetIO_ContextPtr
function M.GetIO(a1) -- generic version
    if a1==nil then return M.GetIO_Nil() end
    if (ffi.istype('ImGuiContext*',a1) or ffi.istype('ImGuiContext',a1) or ffi.istype('ImGuiContext[]',a1)) then return M.GetIO_ContextPtr(a1) end
    print(a1)
    error'M.GetIO could not find overloaded'
end
M.GetInputTextState = lib.igGetInputTextState
function M.GetItemClickedCountWithSingleClickDelay(mouse_button,delay)
    delay = delay or -1.0
    mouse_button = mouse_button or 0
    return lib.igGetItemClickedCountWithSingleClickDelay(mouse_button,delay)
end
M.GetItemFlags = lib.igGetItemFlags
M.GetItemID = lib.igGetItemID
M.GetItemRectMax = lib.igGetItemRectMax
M.GetItemRectMin = lib.igGetItemRectMin
M.GetItemRectSize = lib.igGetItemRectSize
M.GetItemStatusFlags = lib.igGetItemStatusFlags
M.GetKeyChordName = lib.igGetKeyChordName
M.GetKeyData_ContextPtr = lib.igGetKeyData_ContextPtr
M.GetKeyData_Key = lib.igGetKeyData_Key
function M.GetKeyData(a1,a2) -- generic version
    if (ffi.istype('ImGuiContext*',a1) or ffi.istype('ImGuiContext',a1) or ffi.istype('ImGuiContext[]',a1)) then return M.GetKeyData_ContextPtr(a1,a2) end
    if (ffi.istype('ImGuiKey',a1) or type(a1)=='number') then return M.GetKeyData_Key(a1) end
    print(a1,a2)
    error'M.GetKeyData could not find overloaded'
end
M.GetKeyMagnitude2d = lib.igGetKeyMagnitude2d
M.GetKeyName = lib.igGetKeyName
M.GetKeyOwner = lib.igGetKeyOwner
M.GetKeyOwnerData = lib.igGetKeyOwnerData
M.GetKeyPressedAmount = lib.igGetKeyPressedAmount
M.GetMainViewport = lib.igGetMainViewport
M.GetMouseButtonFromPopupFlags = lib.igGetMouseButtonFromPopupFlags
M.GetMouseClickedCount = lib.igGetMouseClickedCount
M.GetMouseCursor = lib.igGetMouseCursor
function M.GetMouseDragDelta(button,lock_threshold)
    button = button or 0
    lock_threshold = lock_threshold or -1.0
    return lib.igGetMouseDragDelta(button,lock_threshold)
end
M.GetMousePos = lib.igGetMousePos
M.GetMousePosOnOpeningCurrentPopup = lib.igGetMousePosOnOpeningCurrentPopup
M.GetMultiSelectState = lib.igGetMultiSelectState
M.GetNavTweakPressedAmount = lib.igGetNavTweakPressedAmount
M.GetPixelDensity = lib.igGetPixelDensity
M.GetPlatformIO_Nil = lib.igGetPlatformIO_Nil
M.GetPlatformIO_ContextPtr = lib.igGetPlatformIO_ContextPtr
function M.GetPlatformIO(a1) -- generic version
    if a1==nil then return M.GetPlatformIO_Nil() end
    if (ffi.istype('ImGuiContext*',a1) or ffi.istype('ImGuiContext',a1) or ffi.istype('ImGuiContext[]',a1)) then return M.GetPlatformIO_ContextPtr(a1) end
    print(a1)
    error'M.GetPlatformIO could not find overloaded'
end
M.GetPopupAllowedExtentRect = lib.igGetPopupAllowedExtentRect
M.GetRoundedFontSize = lib.igGetRoundedFontSize
M.GetScale = lib.igGetScale
M.GetScrollMaxX = lib.igGetScrollMaxX
M.GetScrollMaxY = lib.igGetScrollMaxY
M.GetScrollX = lib.igGetScrollX
M.GetScrollY = lib.igGetScrollY
M.GetShortcutRoutingData = lib.igGetShortcutRoutingData
M.GetStateStorage = lib.igGetStateStorage
M.GetStyle = lib.igGetStyle
M.GetStyleColorName = lib.igGetStyleColorName
M.GetStyleColorVec4 = lib.igGetStyleColorVec4
M.GetStyleVarInfo = lib.igGetStyleVarInfo
M.GetTextLineHeight = lib.igGetTextLineHeight
M.GetTextLineHeightWithSpacing = lib.igGetTextLineHeightWithSpacing
M.GetTime = lib.igGetTime
M.GetTopMostAndVisiblePopupModal = lib.igGetTopMostAndVisiblePopupModal
M.GetTopMostPopupModal = lib.igGetTopMostPopupModal
M.GetTreeNodeToLabelSpacing = lib.igGetTreeNodeToLabelSpacing
M.GetTypematicRepeatRate = lib.igGetTypematicRepeatRate
function M.GetTypingSelectRequest(flags)
    flags = flags or 0
    return lib.igGetTypingSelectRequest(flags)
end
M.GetVersion = lib.igGetVersion
M.GetViewportPlatformMonitor = lib.igGetViewportPlatformMonitor
M.GetWindowAlwaysWantOwnTabBar = lib.igGetWindowAlwaysWantOwnTabBar
M.GetWindowDockID = lib.igGetWindowDockID
M.GetWindowDockNode = lib.igGetWindowDockNode
M.GetWindowDpiScale = lib.igGetWindowDpiScale
M.GetWindowDrawList = lib.igGetWindowDrawList
M.GetWindowHeight = lib.igGetWindowHeight
M.GetWindowPos = lib.igGetWindowPos
M.GetWindowResizeBorderID = lib.igGetWindowResizeBorderID
M.GetWindowResizeCornerID = lib.igGetWindowResizeCornerID
M.GetWindowScrollbarID = lib.igGetWindowScrollbarID
M.GetWindowScrollbarRect = lib.igGetWindowScrollbarRect
M.GetWindowSize = lib.igGetWindowSize
M.GetWindowViewport = lib.igGetWindowViewport
M.GetWindowWidth = lib.igGetWindowWidth
M.ImAbs_Int = lib.igImAbs_Int
M.ImAbs_Float = lib.igImAbs_Float
M.ImAbs_double = lib.igImAbs_double
function M.ImAbs(a1) -- generic version
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImAbs_Int(a1) end
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImAbs_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImAbs_double(a1) end
    print(a1)
    error'M.ImAbs could not find overloaded'
end
M.ImAlphaBlendColors = lib.igImAlphaBlendColors
M.ImBezierCubicCalc = lib.igImBezierCubicCalc
M.ImBezierCubicClosestPoint = lib.igImBezierCubicClosestPoint
M.ImBezierCubicClosestPointCasteljau = lib.igImBezierCubicClosestPointCasteljau
M.ImBezierQuadraticCalc = lib.igImBezierQuadraticCalc
M.ImBitArrayClearAllBits = lib.igImBitArrayClearAllBits
M.ImBitArrayClearBit = lib.igImBitArrayClearBit
M.ImBitArrayGetStorageSizeInBytes = lib.igImBitArrayGetStorageSizeInBytes
M.ImBitArraySetBit = lib.igImBitArraySetBit
M.ImBitArraySetBitRange = lib.igImBitArraySetBitRange
M.ImBitArrayTestBit = lib.igImBitArrayTestBit
M.ImCeilFast = lib.igImCeilFast
M.ImCharIsBlankA = lib.igImCharIsBlankA
M.ImCharIsBlankW = lib.igImCharIsBlankW
M.ImCharIsXdigitA = lib.igImCharIsXdigitA
M.ImClamp_Int = lib.igImClamp_Int
M.ImClamp_Float = lib.igImClamp_Float
M.ImClamp_Vec2 = lib.igImClamp_Vec2
function M.ImClamp(a1,a2,a3) -- generic version
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImClamp_Int(a1,a2,a3) end
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImClamp_Float(a1,a2,a3) end
    if ffi.istype('const ImVec2',a1) then return M.ImClamp_Vec2(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.ImClamp could not find overloaded'
end
M.ImCountSetBits = lib.igImCountSetBits
M.ImDot = lib.igImDot
M.ImExponentialMovingAverage = lib.igImExponentialMovingAverage
M.ImFileClose = lib.igImFileClose
M.ImFileGetSize = lib.igImFileGetSize
function M.ImFileLoadToMemory(filename,mode,out_file_size,padding_bytes)
    out_file_size = out_file_size or nil
    padding_bytes = padding_bytes or 0
    return lib.igImFileLoadToMemory(filename,mode,out_file_size,padding_bytes)
end
M.ImFileOpen = lib.igImFileOpen
M.ImFileRead = lib.igImFileRead
M.ImFileWrite = lib.igImFileWrite
M.ImFloor_Float = lib.igImFloor_Float
M.ImFloor_Vec2 = lib.igImFloor_Vec2
function M.ImFloor(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImFloor_Float(a1) end
    if ffi.istype('const ImVec2',a1) then return M.ImFloor_Vec2(a1) end
    print(a1)
    error'M.ImFloor could not find overloaded'
end
M.ImFontAtlasAddDrawListSharedData = lib.igImFontAtlasAddDrawListSharedData
M.ImFontAtlasBakedAdd = lib.igImFontAtlasBakedAdd
M.ImFontAtlasBakedAddFontGlyph = lib.igImFontAtlasBakedAddFontGlyph
M.ImFontAtlasBakedAddFontGlyphAdvancedX = lib.igImFontAtlasBakedAddFontGlyphAdvancedX
M.ImFontAtlasBakedDiscard = lib.igImFontAtlasBakedDiscard
M.ImFontAtlasBakedDiscardFontGlyph = lib.igImFontAtlasBakedDiscardFontGlyph
M.ImFontAtlasBakedGetClosestMatch = lib.igImFontAtlasBakedGetClosestMatch
M.ImFontAtlasBakedGetId = lib.igImFontAtlasBakedGetId
M.ImFontAtlasBakedGetOrAdd = lib.igImFontAtlasBakedGetOrAdd
M.ImFontAtlasBakedSetFontGlyphBitmap = lib.igImFontAtlasBakedSetFontGlyphBitmap
M.ImFontAtlasBuildClear = lib.igImFontAtlasBuildClear
M.ImFontAtlasBuildDestroy = lib.igImFontAtlasBuildDestroy
M.ImFontAtlasBuildDiscardBakes = lib.igImFontAtlasBuildDiscardBakes
M.ImFontAtlasBuildGetOversampleFactors = lib.igImFontAtlasBuildGetOversampleFactors
M.ImFontAtlasBuildInit = lib.igImFontAtlasBuildInit
M.ImFontAtlasBuildLegacyPreloadAllGlyphRanges = lib.igImFontAtlasBuildLegacyPreloadAllGlyphRanges
M.ImFontAtlasBuildMain = lib.igImFontAtlasBuildMain
M.ImFontAtlasBuildNotifySetFont = lib.igImFontAtlasBuildNotifySetFont
M.ImFontAtlasBuildRenderBitmapFromString = lib.igImFontAtlasBuildRenderBitmapFromString
M.ImFontAtlasBuildSetupFontLoader = lib.igImFontAtlasBuildSetupFontLoader
M.ImFontAtlasBuildSetupFontSpecialGlyphs = lib.igImFontAtlasBuildSetupFontSpecialGlyphs
M.ImFontAtlasBuildUpdatePointers = lib.igImFontAtlasBuildUpdatePointers
M.ImFontAtlasDebugLogTextureRequests = lib.igImFontAtlasDebugLogTextureRequests
M.ImFontAtlasFontDestroyOutput = lib.igImFontAtlasFontDestroyOutput
M.ImFontAtlasFontDestroySourceData = lib.igImFontAtlasFontDestroySourceData
M.ImFontAtlasFontDiscardBakes = lib.igImFontAtlasFontDiscardBakes
M.ImFontAtlasFontInitOutput = lib.igImFontAtlasFontInitOutput
M.ImFontAtlasFontRebuildOutput = lib.igImFontAtlasFontRebuildOutput
M.ImFontAtlasFontSourceAddToFont = lib.igImFontAtlasFontSourceAddToFont
M.ImFontAtlasFontSourceInit = lib.igImFontAtlasFontSourceInit
M.ImFontAtlasGetFontLoaderForStbTruetype = lib.igImFontAtlasGetFontLoaderForStbTruetype
M.ImFontAtlasGetMouseCursorTexData = lib.igImFontAtlasGetMouseCursorTexData
function M.ImFontAtlasPackAddRect(atlas,w,h,overwrite_entry)
    overwrite_entry = overwrite_entry or nil
    return lib.igImFontAtlasPackAddRect(atlas,w,h,overwrite_entry)
end
M.ImFontAtlasPackDiscardRect = lib.igImFontAtlasPackDiscardRect
M.ImFontAtlasPackGetRect = lib.igImFontAtlasPackGetRect
M.ImFontAtlasPackGetRectSafe = lib.igImFontAtlasPackGetRectSafe
M.ImFontAtlasPackInit = lib.igImFontAtlasPackInit
M.ImFontAtlasRectId_GetGeneration = lib.igImFontAtlasRectId_GetGeneration
M.ImFontAtlasRectId_GetIndex = lib.igImFontAtlasRectId_GetIndex
M.ImFontAtlasRectId_Make = lib.igImFontAtlasRectId_Make
M.ImFontAtlasRemoveDrawListSharedData = lib.igImFontAtlasRemoveDrawListSharedData
M.ImFontAtlasTextureAdd = lib.igImFontAtlasTextureAdd
M.ImFontAtlasTextureBlockConvert = lib.igImFontAtlasTextureBlockConvert
M.ImFontAtlasTextureBlockCopy = lib.igImFontAtlasTextureBlockCopy
M.ImFontAtlasTextureBlockFill = lib.igImFontAtlasTextureBlockFill
M.ImFontAtlasTextureBlockPostProcess = lib.igImFontAtlasTextureBlockPostProcess
M.ImFontAtlasTextureBlockPostProcessMultiply = lib.igImFontAtlasTextureBlockPostProcessMultiply
M.ImFontAtlasTextureBlockQueueUpload = lib.igImFontAtlasTextureBlockQueueUpload
M.ImFontAtlasTextureCompact = lib.igImFontAtlasTextureCompact
M.ImFontAtlasTextureGetSizeEstimate = lib.igImFontAtlasTextureGetSizeEstimate
function M.ImFontAtlasTextureGrow(atlas,old_w,old_h)
    old_h = old_h or -1
    old_w = old_w or -1
    return lib.igImFontAtlasTextureGrow(atlas,old_w,old_h)
end
M.ImFontAtlasTextureMakeSpace = lib.igImFontAtlasTextureMakeSpace
M.ImFontAtlasTextureRepack = lib.igImFontAtlasTextureRepack
M.ImFontAtlasUpdateDrawListsSharedData = lib.igImFontAtlasUpdateDrawListsSharedData
M.ImFontAtlasUpdateDrawListsTextures = lib.igImFontAtlasUpdateDrawListsTextures
M.ImFontAtlasUpdateNewFrame = lib.igImFontAtlasUpdateNewFrame
M.ImFontCalcTextSizeEx = lib.igImFontCalcTextSizeEx
function M.ImFontCalcWordWrapPositionEx(font,size,text,text_end,wrap_width,flags)
    flags = flags or 0
    return lib.igImFontCalcWordWrapPositionEx(font,size,text,text_end,wrap_width,flags)
end
M.ImFormatString = lib.igImFormatString
M.ImFormatStringToTempBuffer = lib.igImFormatStringToTempBuffer
M.ImFormatStringToTempBufferV = lib.igImFormatStringToTempBufferV
M.ImFormatStringV = lib.igImFormatStringV
function M.ImHashData(data,data_size,seed)
    seed = seed or 0
    return lib.igImHashData(data,data_size,seed)
end
M.ImHashSkipUncontributingPrefix = lib.igImHashSkipUncontributingPrefix
function M.ImHashStr(data,data_size,seed)
    data_size = data_size or 0
    seed = seed or 0
    return lib.igImHashStr(data,data_size,seed)
end
M.ImInvLength = lib.igImInvLength
M.ImIsFloatAboveGuaranteedIntegerPrecision = lib.igImIsFloatAboveGuaranteedIntegerPrecision
M.ImIsPowerOfTwo_Int = lib.igImIsPowerOfTwo_Int
M.ImIsPowerOfTwo_U64 = lib.igImIsPowerOfTwo_U64
function M.ImIsPowerOfTwo(a1) -- generic version
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImIsPowerOfTwo_Int(a1) end
    if (ffi.istype('uint64_t',a1) or type(a1)=='number') then return M.ImIsPowerOfTwo_U64(a1) end
    print(a1)
    error'M.ImIsPowerOfTwo could not find overloaded'
end
M.ImIsTruncated = lib.igImIsTruncated
M.ImIsTruncated4 = lib.igImIsTruncated4
M.ImLengthSqr_Vec2 = lib.igImLengthSqr_Vec2
M.ImLengthSqr_Vec4 = lib.igImLengthSqr_Vec4
function M.ImLengthSqr(a1) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.ImLengthSqr_Vec2(a1) end
    if ffi.istype('const ImVec4',a1) then return M.ImLengthSqr_Vec4(a1) end
    print(a1)
    error'M.ImLengthSqr could not find overloaded'
end
M.ImLerp_Vec2Float = lib.igImLerp_Vec2Float
M.ImLerp_Vec2Vec2 = lib.igImLerp_Vec2Vec2
M.ImLerp_Vec4 = lib.igImLerp_Vec4
function M.ImLerp(a1,a2,a3) -- generic version
    if ffi.istype('const ImVec2',a1) and (ffi.istype('float',a3) or type(a3)=='number') then return M.ImLerp_Vec2Float(a1,a2,a3) end
    if ffi.istype('const ImVec2',a1) and ffi.istype('const ImVec2',a3) then return M.ImLerp_Vec2Vec2(a1,a2,a3) end
    if ffi.istype('const ImVec4',a1) then return M.ImLerp_Vec4(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.ImLerp could not find overloaded'
end
M.ImLineClosestPoint = lib.igImLineClosestPoint
M.ImLinearRemapClamp = lib.igImLinearRemapClamp
M.ImLinearSweep = lib.igImLinearSweep
M.ImLog_Float = lib.igImLog_Float
M.ImLog_double = lib.igImLog_double
function M.ImLog(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImLog_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImLog_double(a1) end
    print(a1)
    error'M.ImLog could not find overloaded'
end
M.ImLowerBound = lib.igImLowerBound
M.ImMax_Int = lib.igImMax_Int
M.ImMax_Float = lib.igImMax_Float
M.ImMax_Vec2 = lib.igImMax_Vec2
function M.ImMax(a1,a2) -- generic version
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImMax_Int(a1,a2) end
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImMax_Float(a1,a2) end
    if ffi.istype('const ImVec2',a1) then return M.ImMax_Vec2(a1,a2) end
    print(a1,a2)
    error'M.ImMax could not find overloaded'
end
M.ImMemdup = lib.igImMemdup
M.ImMin_Int = lib.igImMin_Int
M.ImMin_Float = lib.igImMin_Float
M.ImMin_Vec2 = lib.igImMin_Vec2
function M.ImMin(a1,a2) -- generic version
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.ImMin_Int(a1,a2) end
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImMin_Float(a1,a2) end
    if ffi.istype('const ImVec2',a1) then return M.ImMin_Vec2(a1,a2) end
    print(a1,a2)
    error'M.ImMin could not find overloaded'
end
M.ImModPositive = lib.igImModPositive
M.ImMul = lib.igImMul
M.ImParseFormatFindEnd = lib.igImParseFormatFindEnd
M.ImParseFormatFindStart = lib.igImParseFormatFindStart
M.ImParseFormatPrecision = lib.igImParseFormatPrecision
M.ImParseFormatSanitizeForPrinting = lib.igImParseFormatSanitizeForPrinting
M.ImParseFormatSanitizeForScanning = lib.igImParseFormatSanitizeForScanning
M.ImParseFormatTrimDecorations = lib.igImParseFormatTrimDecorations
M.ImPow_Float = lib.igImPow_Float
M.ImPow_double = lib.igImPow_double
function M.ImPow(a1,a2) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImPow_Float(a1,a2) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImPow_double(a1,a2) end
    print(a1,a2)
    error'M.ImPow could not find overloaded'
end
M.ImQsort = lib.igImQsort
M.ImRotate = lib.igImRotate
M.ImRoundPositive64 = lib.igImRoundPositive64
M.ImRoundSigned64 = lib.igImRoundSigned64
M.ImRsqrt_Float = lib.igImRsqrt_Float
M.ImRsqrt_double = lib.igImRsqrt_double
function M.ImRsqrt(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImRsqrt_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImRsqrt_double(a1) end
    print(a1)
    error'M.ImRsqrt could not find overloaded'
end
M.ImRsqrtPrecise = lib.igImRsqrtPrecise
M.ImSaturate = lib.igImSaturate
M.ImSign_Float = lib.igImSign_Float
M.ImSign_double = lib.igImSign_double
function M.ImSign(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImSign_Float(a1) end
    if (ffi.istype('double',a1) or type(a1)=='number') then return M.ImSign_double(a1) end
    print(a1)
    error'M.ImSign could not find overloaded'
end
M.ImStrSkipBlank = lib.igImStrSkipBlank
M.ImStrTrimBlanks = lib.igImStrTrimBlanks
M.ImStrbol = lib.igImStrbol
M.ImStrchrRange = lib.igImStrchrRange
M.ImStrdup = lib.igImStrdup
M.ImStrdupcpy = lib.igImStrdupcpy
M.ImStreolRange = lib.igImStreolRange
M.ImStricmp = lib.igImStricmp
M.ImStristr = lib.igImStristr
M.ImStrlenW = lib.igImStrlenW
M.ImStrncpy = lib.igImStrncpy
M.ImStrnicmp = lib.igImStrnicmp
function M.ImTextCalcWordWrapNextLineStart(text,text_end,flags)
    flags = flags or 0
    return lib.igImTextCalcWordWrapNextLineStart(text,text_end,flags)
end
M.ImTextCharFromUtf8 = lib.igImTextCharFromUtf8
M.ImTextCharToUtf8 = lib.igImTextCharToUtf8
M.ImTextClassifierClear = lib.igImTextClassifierClear
M.ImTextClassifierSetCharClass = lib.igImTextClassifierSetCharClass
M.ImTextClassifierSetCharClassFromStr = lib.igImTextClassifierSetCharClassFromStr
M.ImTextCountCharsFromUtf8 = lib.igImTextCountCharsFromUtf8
M.ImTextCountLines = lib.igImTextCountLines
M.ImTextCountUtf8BytesFromChar = lib.igImTextCountUtf8BytesFromChar
M.ImTextCountUtf8BytesFromStr = lib.igImTextCountUtf8BytesFromStr
M.ImTextFindPreviousUtf8Codepoint = lib.igImTextFindPreviousUtf8Codepoint
M.ImTextFindValidUtf8CodepointEnd = lib.igImTextFindValidUtf8CodepointEnd
M.ImTextInitClassifiers = lib.igImTextInitClassifiers
function M.ImTextStrFromUtf8(out_buf,out_buf_size,in_text,in_text_end,in_remaining)
    in_remaining = in_remaining or nil
    return lib.igImTextStrFromUtf8(out_buf,out_buf_size,in_text,in_text_end,in_remaining)
end
M.ImTextStrToUtf8 = lib.igImTextStrToUtf8
M.ImTextureDataGetFormatBytesPerPixel = lib.igImTextureDataGetFormatBytesPerPixel
M.ImTextureDataGetFormatName = lib.igImTextureDataGetFormatName
M.ImTextureDataGetStatusName = lib.igImTextureDataGetStatusName
M.ImTextureDataQueueUpload = lib.igImTextureDataQueueUpload
M.ImTextureDataUpdateNewFrame = lib.igImTextureDataUpdateNewFrame
M.ImToUpper = lib.igImToUpper
M.ImTriangleArea = lib.igImTriangleArea
M.ImTriangleBarycentricCoords = lib.igImTriangleBarycentricCoords
M.ImTriangleClosestPoint = lib.igImTriangleClosestPoint
M.ImTriangleContainsPoint = lib.igImTriangleContainsPoint
M.ImTriangleIsClockwise = lib.igImTriangleIsClockwise
M.ImTrunc_Float = lib.igImTrunc_Float
M.ImTrunc_Vec2 = lib.igImTrunc_Vec2
function M.ImTrunc(a1) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.ImTrunc_Float(a1) end
    if ffi.istype('const ImVec2',a1) then return M.ImTrunc_Vec2(a1) end
    print(a1)
    error'M.ImTrunc could not find overloaded'
end
M.ImTrunc64 = lib.igImTrunc64
M.ImUpperPowerOfTwo = lib.igImUpperPowerOfTwo
function M.Image(tex_ref,image_size,uv0,uv1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,1)
    return lib.igImage(tex_ref,image_size,uv0,uv1)
end
function M.ImageButton(str_id,tex_ref,image_size,uv0,uv1,bg_col,tint_col)
    bg_col = bg_col or ImVec4(0,0,0,0)
    tint_col = tint_col or ImVec4(1,1,1,1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,1)
    return lib.igImageButton(str_id,tex_ref,image_size,uv0,uv1,bg_col,tint_col)
end
function M.ImageButtonEx(id,tex_ref,image_size,uv0,uv1,bg_col,tint_col,flags)
    flags = flags or 0
    return lib.igImageButtonEx(id,tex_ref,image_size,uv0,uv1,bg_col,tint_col,flags)
end
function M.ImageWithBg(tex_ref,image_size,uv0,uv1,bg_col,tint_col)
    bg_col = bg_col or ImVec4(0,0,0,0)
    tint_col = tint_col or ImVec4(1,1,1,1)
    uv0 = uv0 or ImVec2(0,0)
    uv1 = uv1 or ImVec2(1,1)
    return lib.igImageWithBg(tex_ref,image_size,uv0,uv1,bg_col,tint_col)
end
function M.Indent(indent_w)
    indent_w = indent_w or 0.0
    return lib.igIndent(indent_w)
end
M.Initialize = lib.igInitialize
function M.InputDouble(label,v,step,step_fast,format,flags)
    flags = flags or 0
    format = format or "%.6f"
    step = step or 0
    step_fast = step_fast or 0
    return lib.igInputDouble(label,v,step,step_fast,format,flags)
end
function M.InputFloat(label,v,step,step_fast,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    step = step or 0.0
    step_fast = step_fast or 0.0
    return lib.igInputFloat(label,v,step,step_fast,format,flags)
end
function M.InputFloat2(label,v,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igInputFloat2(label,v,format,flags)
end
function M.InputFloat3(label,v,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igInputFloat3(label,v,format,flags)
end
function M.InputFloat4(label,v,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igInputFloat4(label,v,format,flags)
end
function M.InputInt(label,v,step,step_fast,flags)
    flags = flags or 0
    step = step or 1
    step_fast = step_fast or 100
    return lib.igInputInt(label,v,step,step_fast,flags)
end
function M.InputInt2(label,v,flags)
    flags = flags or 0
    return lib.igInputInt2(label,v,flags)
end
function M.InputInt3(label,v,flags)
    flags = flags or 0
    return lib.igInputInt3(label,v,flags)
end
function M.InputInt4(label,v,flags)
    flags = flags or 0
    return lib.igInputInt4(label,v,flags)
end
function M.InputScalar(label,data_type,p_data,p_step,p_step_fast,format,flags)
    flags = flags or 0
    format = format or nil
    p_step = p_step or nil
    p_step_fast = p_step_fast or nil
    return lib.igInputScalar(label,data_type,p_data,p_step,p_step_fast,format,flags)
end
function M.InputScalarN(label,data_type,p_data,components,p_step,p_step_fast,format,flags)
    flags = flags or 0
    format = format or nil
    p_step = p_step or nil
    p_step_fast = p_step_fast or nil
    return lib.igInputScalarN(label,data_type,p_data,components,p_step,p_step_fast,format,flags)
end
function M.InputText(label,buf,buf_size,flags,callback,user_data)
    callback = callback or nil
    flags = flags or 0
    user_data = user_data or nil
    return lib.igInputText(label,buf,buf_size,flags,callback,user_data)
end
M.InputTextDeactivateHook = lib.igInputTextDeactivateHook
function M.InputTextEx(label,hint,buf,buf_size,size_arg,flags,callback,user_data)
    callback = callback or nil
    user_data = user_data or nil
    return lib.igInputTextEx(label,hint,buf,buf_size,size_arg,flags,callback,user_data)
end
function M.InputTextMultiline(label,buf,buf_size,size,flags,callback,user_data)
    callback = callback or nil
    flags = flags or 0
    size = size or ImVec2(0,0)
    user_data = user_data or nil
    return lib.igInputTextMultiline(label,buf,buf_size,size,flags,callback,user_data)
end
function M.InputTextWithHint(label,hint,buf,buf_size,flags,callback,user_data)
    callback = callback or nil
    flags = flags or 0
    user_data = user_data or nil
    return lib.igInputTextWithHint(label,hint,buf,buf_size,flags,callback,user_data)
end
function M.InvisibleButton(str_id,size,flags)
    flags = flags or 0
    return lib.igInvisibleButton(str_id,size,flags)
end
M.IsActiveIdUsingNavDir = lib.igIsActiveIdUsingNavDir
M.IsAliasKey = lib.igIsAliasKey
M.IsAnyItemActive = lib.igIsAnyItemActive
M.IsAnyItemFocused = lib.igIsAnyItemFocused
M.IsAnyItemHovered = lib.igIsAnyItemHovered
M.IsAnyMouseDown = lib.igIsAnyMouseDown
M.IsClippedEx = lib.igIsClippedEx
M.IsDragDropActive = lib.igIsDragDropActive
M.IsDragDropPayloadBeingAccepted = lib.igIsDragDropPayloadBeingAccepted
M.IsGamepadKey = lib.igIsGamepadKey
M.IsInNavFocusRoute = lib.igIsInNavFocusRoute
M.IsItemActivated = lib.igIsItemActivated
M.IsItemActive = lib.igIsItemActive
M.IsItemActiveAsInputText = lib.igIsItemActiveAsInputText
function M.IsItemClicked(mouse_button)
    mouse_button = mouse_button or 0
    return lib.igIsItemClicked(mouse_button)
end
M.IsItemDeactivated = lib.igIsItemDeactivated
M.IsItemDeactivatedAfterEdit = lib.igIsItemDeactivatedAfterEdit
M.IsItemEdited = lib.igIsItemEdited
M.IsItemFocused = lib.igIsItemFocused
function M.IsItemHovered(flags)
    flags = flags or 0
    return lib.igIsItemHovered(flags)
end
M.IsItemToggledOpen = lib.igIsItemToggledOpen
M.IsItemToggledSelection = lib.igIsItemToggledSelection
M.IsItemVisible = lib.igIsItemVisible
M.IsKeyChordPressed_Nil = lib.igIsKeyChordPressed_Nil
function M.IsKeyChordPressed_InputFlags(key_chord,flags,owner_id)
    owner_id = owner_id or 0
    return lib.igIsKeyChordPressed_InputFlags(key_chord,flags,owner_id)
end
function M.IsKeyChordPressed(a1,a2,a3) -- generic version
    if a2==nil then return M.IsKeyChordPressed_Nil(a1) end
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return M.IsKeyChordPressed_InputFlags(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.IsKeyChordPressed could not find overloaded'
end
M.IsKeyDown_Nil = lib.igIsKeyDown_Nil
M.IsKeyDown_ID = lib.igIsKeyDown_ID
function M.IsKeyDown(a1,a2) -- generic version
    if a2==nil then return M.IsKeyDown_Nil(a1) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsKeyDown_ID(a1,a2) end
    print(a1,a2)
    error'M.IsKeyDown could not find overloaded'
end
function M.IsKeyPressed_Bool(key,_repeat)
    if _repeat == nil then _repeat = true end
    return lib.igIsKeyPressed_Bool(key,_repeat)
end
function M.IsKeyPressed_InputFlags(key,flags,owner_id)
    owner_id = owner_id or 0
    return lib.igIsKeyPressed_InputFlags(key,flags,owner_id)
end
function M.IsKeyPressed(a1,a2,a3) -- generic version
    if ((ffi.istype('bool',a2) or type(a2)=='boolean') or type(a2)=='nil') then return M.IsKeyPressed_Bool(a1,a2) end
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return M.IsKeyPressed_InputFlags(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.IsKeyPressed could not find overloaded'
end
M.IsKeyReleased_Nil = lib.igIsKeyReleased_Nil
M.IsKeyReleased_ID = lib.igIsKeyReleased_ID
function M.IsKeyReleased(a1,a2) -- generic version
    if a2==nil then return M.IsKeyReleased_Nil(a1) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsKeyReleased_ID(a1,a2) end
    print(a1,a2)
    error'M.IsKeyReleased could not find overloaded'
end
M.IsKeyboardKey = lib.igIsKeyboardKey
M.IsLRModKey = lib.igIsLRModKey
M.IsLegacyKey = lib.igIsLegacyKey
function M.IsMouseClicked_Bool(button,_repeat)
    _repeat = _repeat or false
    return lib.igIsMouseClicked_Bool(button,_repeat)
end
function M.IsMouseClicked_InputFlags(button,flags,owner_id)
    owner_id = owner_id or 0
    return lib.igIsMouseClicked_InputFlags(button,flags,owner_id)
end
function M.IsMouseClicked(a1,a2,a3) -- generic version
    if ((ffi.istype('bool',a2) or type(a2)=='boolean') or type(a2)=='nil') then return M.IsMouseClicked_Bool(a1,a2) end
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return M.IsMouseClicked_InputFlags(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.IsMouseClicked could not find overloaded'
end
M.IsMouseDoubleClicked_Nil = lib.igIsMouseDoubleClicked_Nil
M.IsMouseDoubleClicked_ID = lib.igIsMouseDoubleClicked_ID
function M.IsMouseDoubleClicked(a1,a2) -- generic version
    if a2==nil then return M.IsMouseDoubleClicked_Nil(a1) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsMouseDoubleClicked_ID(a1,a2) end
    print(a1,a2)
    error'M.IsMouseDoubleClicked could not find overloaded'
end
M.IsMouseDown_Nil = lib.igIsMouseDown_Nil
M.IsMouseDown_ID = lib.igIsMouseDown_ID
function M.IsMouseDown(a1,a2) -- generic version
    if a2==nil then return M.IsMouseDown_Nil(a1) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsMouseDown_ID(a1,a2) end
    print(a1,a2)
    error'M.IsMouseDown could not find overloaded'
end
function M.IsMouseDragPastThreshold(button,lock_threshold)
    lock_threshold = lock_threshold or -1.0
    return lib.igIsMouseDragPastThreshold(button,lock_threshold)
end
function M.IsMouseDragging(button,lock_threshold)
    lock_threshold = lock_threshold or -1.0
    return lib.igIsMouseDragging(button,lock_threshold)
end
function M.IsMouseHoveringRect(r_min,r_max,clip)
    if clip == nil then clip = true end
    return lib.igIsMouseHoveringRect(r_min,r_max,clip)
end
M.IsMouseKey = lib.igIsMouseKey
function M.IsMousePosValid(mouse_pos)
    mouse_pos = mouse_pos or nil
    return lib.igIsMousePosValid(mouse_pos)
end
M.IsMouseReleased_Nil = lib.igIsMouseReleased_Nil
M.IsMouseReleased_ID = lib.igIsMouseReleased_ID
function M.IsMouseReleased(a1,a2) -- generic version
    if a2==nil then return M.IsMouseReleased_Nil(a1) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.IsMouseReleased_ID(a1,a2) end
    print(a1,a2)
    error'M.IsMouseReleased could not find overloaded'
end
function M.IsMouseReleasedWithDelay(button,delay)
    delay = delay or -1.
    return lib.igIsMouseReleasedWithDelay(button,delay)
end
M.IsNamedKey = lib.igIsNamedKey
M.IsNamedKeyOrMod = lib.igIsNamedKeyOrMod
function M.IsPopupOpen_Str(str_id,flags)
    flags = flags or 0
    return lib.igIsPopupOpen_Str(str_id,flags)
end
M.IsPopupOpen_ID = lib.igIsPopupOpen_ID
function M.IsPopupOpen(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.IsPopupOpen_Str(a1,a2) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.IsPopupOpen_ID(a1,a2) end
    print(a1,a2)
    error'M.IsPopupOpen could not find overloaded'
end
M.IsPopupOpenRequestForItem = lib.igIsPopupOpenRequestForItem
M.IsPopupOpenRequestForWindow = lib.igIsPopupOpenRequestForWindow
M.IsRectVisible_Nil = lib.igIsRectVisible_Nil
M.IsRectVisible_Vec2 = lib.igIsRectVisible_Vec2
function M.IsRectVisible(a1,a2) -- generic version
    if a2==nil then return M.IsRectVisible_Nil(a1) end
    if ffi.istype('const ImVec2',a2) then return M.IsRectVisible_Vec2(a1,a2) end
    print(a1,a2)
    error'M.IsRectVisible could not find overloaded'
end
M.IsWindowAbove = lib.igIsWindowAbove
M.IsWindowAppearing = lib.igIsWindowAppearing
M.IsWindowChildOf = lib.igIsWindowChildOf
M.IsWindowCollapsed = lib.igIsWindowCollapsed
function M.IsWindowContentHoverable(window,flags)
    flags = flags or 0
    return lib.igIsWindowContentHoverable(window,flags)
end
M.IsWindowDocked = lib.igIsWindowDocked
function M.IsWindowFocused(flags)
    flags = flags or 0
    return lib.igIsWindowFocused(flags)
end
function M.IsWindowHovered(flags)
    flags = flags or 0
    return lib.igIsWindowHovered(flags)
end
M.IsWindowInBeginStack = lib.igIsWindowInBeginStack
M.IsWindowNavFocusable = lib.igIsWindowNavFocusable
M.IsWindowWithinBeginStackOf = lib.igIsWindowWithinBeginStackOf
function M.ItemAdd(bb,id,nav_bb,extra_flags)
    extra_flags = extra_flags or 0
    nav_bb = nav_bb or nil
    return lib.igItemAdd(bb,id,nav_bb,extra_flags)
end
M.ItemHoverable = lib.igItemHoverable
function M.ItemSize_Vec2(size,text_baseline_y)
    text_baseline_y = text_baseline_y or -1.0
    return lib.igItemSize_Vec2(size,text_baseline_y)
end
function M.ItemSize_Rect(bb,text_baseline_y)
    text_baseline_y = text_baseline_y or -1.0
    return lib.igItemSize_Rect(bb,text_baseline_y)
end
function M.ItemSize(a1,a2) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.ItemSize_Vec2(a1,a2) end
    if ffi.istype('const ImRect',a1) then return M.ItemSize_Rect(a1,a2) end
    print(a1,a2)
    error'M.ItemSize could not find overloaded'
end
M.KeepAliveID = lib.igKeepAliveID
M.LabelText = lib.igLabelText
M.LabelTextV = lib.igLabelTextV
function M.ListBox_Str_arr(label,current_item,items,items_count,height_in_items)
    height_in_items = height_in_items or -1
    return lib.igListBox_Str_arr(label,current_item,items,items_count,height_in_items)
end
function M.ListBox_FnStrPtr(label,current_item,getter,user_data,items_count,height_in_items)
    height_in_items = height_in_items or -1
    return lib.igListBox_FnStrPtr(label,current_item,getter,user_data,items_count,height_in_items)
end
function M.ListBox(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('const char* const[]',a3) or ffi.istype('const char const[]',a3) or ffi.istype('const char const[][]',a3)) then return M.ListBox_Str_arr(a1,a2,a3,a4,a5) end
    if ffi.istype('const char*(*)(void* user_data,int idx)',a3) then return M.ListBox_FnStrPtr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.ListBox could not find overloaded'
end
M.LoadIniSettingsFromDisk = lib.igLoadIniSettingsFromDisk
function M.LoadIniSettingsFromMemory(ini_data,ini_size)
    ini_size = ini_size or 0
    return lib.igLoadIniSettingsFromMemory(ini_data,ini_size)
end
M.LocalizeGetMsg = lib.igLocalizeGetMsg
M.LocalizeRegisterEntries = lib.igLocalizeRegisterEntries
M.LogBegin = lib.igLogBegin
M.LogButtons = lib.igLogButtons
M.LogFinish = lib.igLogFinish
function M.LogRenderedText(ref_pos,text,text_end)
    text_end = text_end or nil
    return lib.igLogRenderedText(ref_pos,text,text_end)
end
M.LogSetNextTextDecoration = lib.igLogSetNextTextDecoration
M.LogText = lib.igLogText
M.LogTextV = lib.igLogTextV
function M.LogToBuffer(auto_open_depth)
    auto_open_depth = auto_open_depth or -1
    return lib.igLogToBuffer(auto_open_depth)
end
function M.LogToClipboard(auto_open_depth)
    auto_open_depth = auto_open_depth or -1
    return lib.igLogToClipboard(auto_open_depth)
end
function M.LogToFile(auto_open_depth,filename)
    auto_open_depth = auto_open_depth or -1
    filename = filename or nil
    return lib.igLogToFile(auto_open_depth,filename)
end
function M.LogToTTY(auto_open_depth)
    auto_open_depth = auto_open_depth or -1
    return lib.igLogToTTY(auto_open_depth)
end
M.MarkIniSettingsDirty_Nil = lib.igMarkIniSettingsDirty_Nil
M.MarkIniSettingsDirty_WindowPtr = lib.igMarkIniSettingsDirty_WindowPtr
function M.MarkIniSettingsDirty(a1) -- generic version
    if a1==nil then return M.MarkIniSettingsDirty_Nil() end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.MarkIniSettingsDirty_WindowPtr(a1) end
    print(a1)
    error'M.MarkIniSettingsDirty could not find overloaded'
end
M.MarkItemEdited = lib.igMarkItemEdited
M.MemAlloc = lib.igMemAlloc
M.MemFree = lib.igMemFree
function M.MenuItem_Bool(label,shortcut,selected,enabled)
    if enabled == nil then enabled = true end
    selected = selected or false
    shortcut = shortcut or nil
    return lib.igMenuItem_Bool(label,shortcut,selected,enabled)
end
function M.MenuItem_BoolPtr(label,shortcut,p_selected,enabled)
    if enabled == nil then enabled = true end
    return lib.igMenuItem_BoolPtr(label,shortcut,p_selected,enabled)
end
function M.MenuItem(a1,a2,a3,a4) -- generic version
    if ((ffi.istype('bool',a3) or type(a3)=='boolean') or type(a3)=='nil') then return M.MenuItem_Bool(a1,a2,a3,a4) end
    if (ffi.istype('bool*',a3) or ffi.istype('bool[]',a3)) then return M.MenuItem_BoolPtr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.MenuItem could not find overloaded'
end
function M.MenuItemEx(label,icon,shortcut,selected,enabled)
    if enabled == nil then enabled = true end
    selected = selected or false
    shortcut = shortcut or nil
    return lib.igMenuItemEx(label,icon,shortcut,selected,enabled)
end
M.MouseButtonToKey = lib.igMouseButtonToKey
M.MultiSelectAddSetAll = lib.igMultiSelectAddSetAll
M.MultiSelectAddSetRange = lib.igMultiSelectAddSetRange
function M.MultiSelectItemFooter(id,p_selected,p_pressed,extra_flags)
    extra_flags = extra_flags or 0
    return lib.igMultiSelectItemFooter(id,p_selected,p_pressed,extra_flags)
end
M.MultiSelectItemHeader = lib.igMultiSelectItemHeader
M.NavClearPreferredPosForAxis = lib.igNavClearPreferredPosForAxis
M.NavHighlightActivated = lib.igNavHighlightActivated
M.NavInitRequestApplyResult = lib.igNavInitRequestApplyResult
M.NavInitWindow = lib.igNavInitWindow
M.NavMoveRequestApplyResult = lib.igNavMoveRequestApplyResult
M.NavMoveRequestButNoResultYet = lib.igNavMoveRequestButNoResultYet
M.NavMoveRequestCancel = lib.igNavMoveRequestCancel
M.NavMoveRequestForward = lib.igNavMoveRequestForward
M.NavMoveRequestResolveWithLastItem = lib.igNavMoveRequestResolveWithLastItem
M.NavMoveRequestResolveWithPastTreeNode = lib.igNavMoveRequestResolveWithPastTreeNode
M.NavMoveRequestSubmit = lib.igNavMoveRequestSubmit
M.NavMoveRequestTryWrapping = lib.igNavMoveRequestTryWrapping
M.NavUpdateCurrentWindowIsScrollPushableX = lib.igNavUpdateCurrentWindowIsScrollPushableX
M.NewFrame = lib.igNewFrame
M.NewLine = lib.igNewLine
M.NextColumn = lib.igNextColumn
function M.OpenPopup_Str(str_id,popup_flags)
    popup_flags = popup_flags or 0
    return lib.igOpenPopup_Str(str_id,popup_flags)
end
function M.OpenPopup_ID(id,popup_flags)
    popup_flags = popup_flags or 0
    return lib.igOpenPopup_ID(id,popup_flags)
end
function M.OpenPopup(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.OpenPopup_Str(a1,a2) end
    if (ffi.istype('uint32_t',a1) or type(a1)=='number') then return M.OpenPopup_ID(a1,a2) end
    print(a1,a2)
    error'M.OpenPopup could not find overloaded'
end
function M.OpenPopupEx(id,popup_flags)
    popup_flags = popup_flags or 0
    return lib.igOpenPopupEx(id,popup_flags)
end
function M.OpenPopupOnItemClick(str_id,popup_flags)
    popup_flags = popup_flags or 0
    str_id = str_id or nil
    return lib.igOpenPopupOnItemClick(str_id,popup_flags)
end
M.PlotEx = lib.igPlotEx
function M.PlotHistogram_FloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
    graph_size = graph_size or ImVec2(0,0)
    overlay_text = overlay_text or nil
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    stride = stride or ffi.sizeof("float")
    values_offset = values_offset or 0
    return lib.igPlotHistogram_FloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
end
function M.PlotHistogram_FnFloatPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
    graph_size = graph_size or ImVec2(0,0)
    overlay_text = overlay_text or nil
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    values_offset = values_offset or 0
    return lib.igPlotHistogram_FnFloatPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
end
function M.PlotHistogram(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.PlotHistogram_FloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.istype('float(*)(void* data,int idx)',a2) then return M.PlotHistogram_FnFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.PlotHistogram could not find overloaded'
end
function M.PlotLines_FloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
    graph_size = graph_size or ImVec2(0,0)
    overlay_text = overlay_text or nil
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    stride = stride or ffi.sizeof("float")
    values_offset = values_offset or 0
    return lib.igPlotLines_FloatPtr(label,values,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size,stride)
end
function M.PlotLines_FnFloatPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
    graph_size = graph_size or ImVec2(0,0)
    overlay_text = overlay_text or nil
    scale_max = scale_max or M.FLT_MAX
    scale_min = scale_min or M.FLT_MAX
    values_offset = values_offset or 0
    return lib.igPlotLines_FnFloatPtr(label,values_getter,data,values_count,values_offset,overlay_text,scale_min,scale_max,graph_size)
end
function M.PlotLines(a1,a2,a3,a4,a5,a6,a7,a8,a9) -- generic version
    if (ffi.istype('float*',a2) or ffi.istype('float[]',a2)) then return M.PlotLines_FloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    if ffi.istype('float(*)(void* data,int idx)',a2) then return M.PlotLines_FnFloatPtr(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    print(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    error'M.PlotLines could not find overloaded'
end
M.PopClipRect = lib.igPopClipRect
M.PopColumnsBackground = lib.igPopColumnsBackground
M.PopFocusScope = lib.igPopFocusScope
M.PopFont = lib.igPopFont
M.PopID = lib.igPopID
M.PopItemFlag = lib.igPopItemFlag
M.PopItemWidth = lib.igPopItemWidth
M.PopPasswordFont = lib.igPopPasswordFont
function M.PopStyleColor(count)
    count = count or 1
    return lib.igPopStyleColor(count)
end
function M.PopStyleVar(count)
    count = count or 1
    return lib.igPopStyleVar(count)
end
M.PopTextWrapPos = lib.igPopTextWrapPos
function M.ProgressBar(fraction,size_arg,overlay)
    overlay = overlay or nil
    size_arg = size_arg or ImVec2(-M.FLT_MIN,0)
    return lib.igProgressBar(fraction,size_arg,overlay)
end
M.PushClipRect = lib.igPushClipRect
M.PushColumnClipRect = lib.igPushColumnClipRect
M.PushColumnsBackground = lib.igPushColumnsBackground
M.PushFocusScope = lib.igPushFocusScope
M.PushFont = lib.igPushFont
M.PushID_Str = lib.igPushID_Str
M.PushID_StrStr = lib.igPushID_StrStr
M.PushID_Ptr = lib.igPushID_Ptr
M.PushID_Int = lib.igPushID_Int
function M.PushID(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a2==nil then return M.PushID_Str(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.PushID_StrStr(a1,a2) end
    if ffi.istype('void *',a1) then return M.PushID_Ptr(a1) end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.PushID_Int(a1) end
    print(a1,a2)
    error'M.PushID could not find overloaded'
end
M.PushItemFlag = lib.igPushItemFlag
M.PushItemWidth = lib.igPushItemWidth
M.PushMultiItemsWidths = lib.igPushMultiItemsWidths
M.PushOverrideID = lib.igPushOverrideID
M.PushPasswordFont = lib.igPushPasswordFont
M.PushStyleColor_U32 = lib.igPushStyleColor_U32
M.PushStyleColor_Vec4 = lib.igPushStyleColor_Vec4
function M.PushStyleColor(a1,a2) -- generic version
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.PushStyleColor_U32(a1,a2) end
    if ffi.istype('const ImVec4',a2) then return M.PushStyleColor_Vec4(a1,a2) end
    print(a1,a2)
    error'M.PushStyleColor could not find overloaded'
end
M.PushStyleVar_Float = lib.igPushStyleVar_Float
M.PushStyleVar_Vec2 = lib.igPushStyleVar_Vec2
function M.PushStyleVar(a1,a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.PushStyleVar_Float(a1,a2) end
    if ffi.istype('const ImVec2',a2) then return M.PushStyleVar_Vec2(a1,a2) end
    print(a1,a2)
    error'M.PushStyleVar could not find overloaded'
end
M.PushStyleVarX = lib.igPushStyleVarX
M.PushStyleVarY = lib.igPushStyleVarY
function M.PushTextWrapPos(wrap_local_pos_x)
    wrap_local_pos_x = wrap_local_pos_x or 0.0
    return lib.igPushTextWrapPos(wrap_local_pos_x)
end
M.RadioButton_Bool = lib.igRadioButton_Bool
M.RadioButton_IntPtr = lib.igRadioButton_IntPtr
function M.RadioButton(a1,a2,a3) -- generic version
    if (ffi.istype('bool',a2) or type(a2)=='boolean') then return M.RadioButton_Bool(a1,a2) end
    if ffi.typeof('int32_t*') == ffi.typeof(a2) or ffi.typeof('const int32_t*') == ffi.typeof(a2) or ffi.typeof('int32_t[?]') == ffi.typeof(a2) or ffi.typeof('const int32_t[?]') == ffi.typeof(a2) then return M.RadioButton_IntPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.RadioButton could not find overloaded'
end
M.RegisterFontAtlas = lib.igRegisterFontAtlas
M.RegisterUserTexture = lib.igRegisterUserTexture
M.RemoveContextHook = lib.igRemoveContextHook
M.RemoveSettingsHandler = lib.igRemoveSettingsHandler
M.Render = lib.igRender
function M.RenderArrow(draw_list,pos,col,dir,scale)
    scale = scale or 1.0
    return lib.igRenderArrow(draw_list,pos,col,dir,scale)
end
M.RenderArrowDockMenu = lib.igRenderArrowDockMenu
M.RenderArrowPointingAt = lib.igRenderArrowPointingAt
M.RenderBullet = lib.igRenderBullet
M.RenderCheckMark = lib.igRenderCheckMark
M.RenderColorComponentMarker = lib.igRenderColorComponentMarker
function M.RenderColorRectWithAlphaCheckerboard(draw_list,p_min,p_max,col,alpha,grid_step,grid_off,rounding,flags)
    flags = flags or 0
    rounding = rounding or 0.0
    return lib.igRenderColorRectWithAlphaCheckerboard(draw_list,p_min,p_max,col,alpha,grid_step,grid_off,rounding,flags)
end
M.RenderDragDropTargetRectEx = lib.igRenderDragDropTargetRectEx
M.RenderDragDropTargetRectForItem = lib.igRenderDragDropTargetRectForItem
M.RenderDragDropTargetRectForViewport = lib.igRenderDragDropTargetRectForViewport
function M.RenderFrame(p_min,p_max,fill_col,borders,rounding)
    if borders == nil then borders = true end
    rounding = rounding or 0.0
    return lib.igRenderFrame(p_min,p_max,fill_col,borders,rounding)
end
function M.RenderFrameBorder(p_min,p_max,rounding)
    rounding = rounding or 0.0
    return lib.igRenderFrameBorder(p_min,p_max,rounding)
end
M.RenderMouseCursor = lib.igRenderMouseCursor
function M.RenderNavCursor(bb,id,flags,rounding)
    flags = flags or 0
    rounding = rounding or -1.0
    return lib.igRenderNavCursor(bb,id,flags,rounding)
end
function M.RenderPlatformWindowsDefault(platform_render_arg,renderer_render_arg)
    platform_render_arg = platform_render_arg or nil
    renderer_render_arg = renderer_render_arg or nil
    return lib.igRenderPlatformWindowsDefault(platform_render_arg,renderer_render_arg)
end
M.RenderRectFilledInRangeH = lib.igRenderRectFilledInRangeH
M.RenderRectFilledWithHole = lib.igRenderRectFilledWithHole
function M.RenderText(pos,text,text_end,hide_text_after_hash)
    if hide_text_after_hash == nil then hide_text_after_hash = true end
    text_end = text_end or nil
    return lib.igRenderText(pos,text,text_end,hide_text_after_hash)
end
function M.RenderTextClipped(pos_min,pos_max,text,text_end,text_size_if_known,align,clip_rect)
    align = align or ImVec2(0,0)
    clip_rect = clip_rect or nil
    return lib.igRenderTextClipped(pos_min,pos_max,text,text_end,text_size_if_known,align,clip_rect)
end
function M.RenderTextClippedEx(draw_list,pos_min,pos_max,text,text_end,text_size_if_known,align,clip_rect)
    align = align or ImVec2(0,0)
    clip_rect = clip_rect or nil
    return lib.igRenderTextClippedEx(draw_list,pos_min,pos_max,text,text_end,text_size_if_known,align,clip_rect)
end
M.RenderTextEllipsis = lib.igRenderTextEllipsis
M.RenderTextWrapped = lib.igRenderTextWrapped
function M.ResetMouseDragDelta(button)
    button = button or 0
    return lib.igResetMouseDragDelta(button)
end
function M.SameLine(offset_from_start_x,spacing)
    offset_from_start_x = offset_from_start_x or 0.0
    spacing = spacing or -1.0
    return lib.igSameLine(offset_from_start_x,spacing)
end
M.SaveIniSettingsToDisk = lib.igSaveIniSettingsToDisk
function M.SaveIniSettingsToMemory(out_ini_size)
    out_ini_size = out_ini_size or nil
    return lib.igSaveIniSettingsToMemory(out_ini_size)
end
M.ScaleWindowsInViewport = lib.igScaleWindowsInViewport
M.ScrollToBringRectIntoView = lib.igScrollToBringRectIntoView
function M.ScrollToItem(flags)
    flags = flags or 0
    return lib.igScrollToItem(flags)
end
function M.ScrollToRect(window,rect,flags)
    flags = flags or 0
    return lib.igScrollToRect(window,rect,flags)
end
function M.ScrollToRectEx(window,rect,flags)
    flags = flags or 0
    return lib.igScrollToRectEx(window,rect,flags)
end
M.Scrollbar = lib.igScrollbar
function M.ScrollbarEx(bb,id,axis,p_scroll_v,avail_v,contents_v,draw_rounding_flags)
    draw_rounding_flags = draw_rounding_flags or 0
    return lib.igScrollbarEx(bb,id,axis,p_scroll_v,avail_v,contents_v,draw_rounding_flags)
end
function M.Selectable_Bool(label,selected,flags,size)
    flags = flags or 0
    selected = selected or false
    size = size or ImVec2(0,0)
    return lib.igSelectable_Bool(label,selected,flags,size)
end
function M.Selectable_BoolPtr(label,p_selected,flags,size)
    flags = flags or 0
    size = size or ImVec2(0,0)
    return lib.igSelectable_BoolPtr(label,p_selected,flags,size)
end
function M.Selectable(a1,a2,a3,a4) -- generic version
    if ((ffi.istype('bool',a2) or type(a2)=='boolean') or type(a2)=='nil') then return M.Selectable_Bool(a1,a2,a3,a4) end
    if (ffi.istype('bool*',a2) or ffi.istype('bool[]',a2)) then return M.Selectable_BoolPtr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.Selectable could not find overloaded'
end
M.Separator = lib.igSeparator
function M.SeparatorEx(flags,thickness)
    thickness = thickness or 1.0
    return lib.igSeparatorEx(flags,thickness)
end
M.SeparatorText = lib.igSeparatorText
M.SeparatorTextEx = lib.igSeparatorTextEx
M.SetActiveID = lib.igSetActiveID
M.SetActiveIdUsingAllKeyboardKeys = lib.igSetActiveIdUsingAllKeyboardKeys
function M.SetAllocatorFunctions(alloc_func,free_func,user_data)
    user_data = user_data or nil
    return lib.igSetAllocatorFunctions(alloc_func,free_func,user_data)
end
M.SetClipboardText = lib.igSetClipboardText
M.SetColumnOffset = lib.igSetColumnOffset
M.SetColumnWidth = lib.igSetColumnWidth
M.SetContextName = lib.igSetContextName
M.SetCurrentContext = lib.igSetCurrentContext
M.SetCurrentFont = lib.igSetCurrentFont
M.SetCurrentViewport = lib.igSetCurrentViewport
M.SetCursorPos = lib.igSetCursorPos
M.SetCursorPosX = lib.igSetCursorPosX
M.SetCursorPosY = lib.igSetCursorPosY
M.SetCursorScreenPos = lib.igSetCursorScreenPos
function M.SetDragDropPayload(type,data,sz,cond)
    cond = cond or 0
    return lib.igSetDragDropPayload(type,data,sz,cond)
end
M.SetFocusID = lib.igSetFocusID
M.SetHoveredID = lib.igSetHoveredID
M.SetItemDefaultFocus = lib.igSetItemDefaultFocus
M.SetItemKeyOwner_Nil = lib.igSetItemKeyOwner_Nil
M.SetItemKeyOwner_InputFlags = lib.igSetItemKeyOwner_InputFlags
function M.SetItemKeyOwner(a1,a2) -- generic version
    if a2==nil then return M.SetItemKeyOwner_Nil(a1) end
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return M.SetItemKeyOwner_InputFlags(a1,a2) end
    print(a1,a2)
    error'M.SetItemKeyOwner could not find overloaded'
end
M.SetItemTooltip = lib.igSetItemTooltip
M.SetItemTooltipV = lib.igSetItemTooltipV
function M.SetKeyOwner(key,owner_id,flags)
    flags = flags or 0
    return lib.igSetKeyOwner(key,owner_id,flags)
end
function M.SetKeyOwnersForKeyChord(key,owner_id,flags)
    flags = flags or 0
    return lib.igSetKeyOwnersForKeyChord(key,owner_id,flags)
end
function M.SetKeyboardFocusHere(offset)
    offset = offset or 0
    return lib.igSetKeyboardFocusHere(offset)
end
M.SetLastItemData = lib.igSetLastItemData
M.SetMouseCursor = lib.igSetMouseCursor
M.SetNavCursorVisible = lib.igSetNavCursorVisible
M.SetNavCursorVisibleAfterMove = lib.igSetNavCursorVisibleAfterMove
M.SetNavFocusScope = lib.igSetNavFocusScope
M.SetNavID = lib.igSetNavID
M.SetNavWindow = lib.igSetNavWindow
M.SetNextFrameWantCaptureKeyboard = lib.igSetNextFrameWantCaptureKeyboard
M.SetNextFrameWantCaptureMouse = lib.igSetNextFrameWantCaptureMouse
M.SetNextItemAllowOverlap = lib.igSetNextItemAllowOverlap
M.SetNextItemColorMarker = lib.igSetNextItemColorMarker
function M.SetNextItemOpen(is_open,cond)
    cond = cond or 0
    return lib.igSetNextItemOpen(is_open,cond)
end
M.SetNextItemRefVal = lib.igSetNextItemRefVal
M.SetNextItemSelectionUserData = lib.igSetNextItemSelectionUserData
function M.SetNextItemShortcut(key_chord,flags)
    flags = flags or 0
    return lib.igSetNextItemShortcut(key_chord,flags)
end
M.SetNextItemStorageID = lib.igSetNextItemStorageID
M.SetNextItemWidth = lib.igSetNextItemWidth
M.SetNextWindowBgAlpha = lib.igSetNextWindowBgAlpha
M.SetNextWindowChildFlags = lib.igSetNextWindowChildFlags
M.SetNextWindowClass = lib.igSetNextWindowClass
function M.SetNextWindowCollapsed(collapsed,cond)
    cond = cond or 0
    return lib.igSetNextWindowCollapsed(collapsed,cond)
end
M.SetNextWindowContentSize = lib.igSetNextWindowContentSize
function M.SetNextWindowDockID(dock_id,cond)
    cond = cond or 0
    return lib.igSetNextWindowDockID(dock_id,cond)
end
M.SetNextWindowFlags = lib.igSetNextWindowFlags
M.SetNextWindowFocus = lib.igSetNextWindowFocus
function M.SetNextWindowPos(pos,cond,pivot)
    cond = cond or 0
    pivot = pivot or ImVec2(0,0)
    return lib.igSetNextWindowPos(pos,cond,pivot)
end
M.SetNextWindowRefreshPolicy = lib.igSetNextWindowRefreshPolicy
M.SetNextWindowScroll = lib.igSetNextWindowScroll
function M.SetNextWindowSize(size,cond)
    cond = cond or 0
    return lib.igSetNextWindowSize(size,cond)
end
function M.SetNextWindowSizeConstraints(size_min,size_max,custom_callback,custom_callback_data)
    custom_callback = custom_callback or nil
    custom_callback_data = custom_callback_data or nil
    return lib.igSetNextWindowSizeConstraints(size_min,size_max,custom_callback,custom_callback_data)
end
M.SetNextWindowViewport = lib.igSetNextWindowViewport
M.SetPixelDensity = lib.igSetPixelDensity
function M.SetScrollFromPosX_Float(local_x,center_x_ratio)
    center_x_ratio = center_x_ratio or 0.5
    return lib.igSetScrollFromPosX_Float(local_x,center_x_ratio)
end
M.SetScrollFromPosX_WindowPtr = lib.igSetScrollFromPosX_WindowPtr
function M.SetScrollFromPosX(a1,a2,a3) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.SetScrollFromPosX_Float(a1,a2) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetScrollFromPosX_WindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetScrollFromPosX could not find overloaded'
end
function M.SetScrollFromPosY_Float(local_y,center_y_ratio)
    center_y_ratio = center_y_ratio or 0.5
    return lib.igSetScrollFromPosY_Float(local_y,center_y_ratio)
end
M.SetScrollFromPosY_WindowPtr = lib.igSetScrollFromPosY_WindowPtr
function M.SetScrollFromPosY(a1,a2,a3) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.SetScrollFromPosY_Float(a1,a2) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetScrollFromPosY_WindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetScrollFromPosY could not find overloaded'
end
function M.SetScrollHereX(center_x_ratio)
    center_x_ratio = center_x_ratio or 0.5
    return lib.igSetScrollHereX(center_x_ratio)
end
function M.SetScrollHereY(center_y_ratio)
    center_y_ratio = center_y_ratio or 0.5
    return lib.igSetScrollHereY(center_y_ratio)
end
M.SetScrollX_Float = lib.igSetScrollX_Float
M.SetScrollX_WindowPtr = lib.igSetScrollX_WindowPtr
function M.SetScrollX(a1,a2) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.SetScrollX_Float(a1) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetScrollX_WindowPtr(a1,a2) end
    print(a1,a2)
    error'M.SetScrollX could not find overloaded'
end
M.SetScrollY_Float = lib.igSetScrollY_Float
M.SetScrollY_WindowPtr = lib.igSetScrollY_WindowPtr
function M.SetScrollY(a1,a2) -- generic version
    if (ffi.istype('float',a1) or type(a1)=='number') then return M.SetScrollY_Float(a1) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetScrollY_WindowPtr(a1,a2) end
    print(a1,a2)
    error'M.SetScrollY could not find overloaded'
end
M.SetShortcutRouting = lib.igSetShortcutRouting
M.SetStateStorage = lib.igSetStateStorage
M.SetTabItemClosed = lib.igSetTabItemClosed
M.SetTooltip = lib.igSetTooltip
M.SetTooltipV = lib.igSetTooltipV
M.SetWindowClipRectBeforeSetChannel = lib.igSetWindowClipRectBeforeSetChannel
function M.SetWindowCollapsed_Bool(collapsed,cond)
    cond = cond or 0
    return lib.igSetWindowCollapsed_Bool(collapsed,cond)
end
function M.SetWindowCollapsed_Str(name,collapsed,cond)
    cond = cond or 0
    return lib.igSetWindowCollapsed_Str(name,collapsed,cond)
end
function M.SetWindowCollapsed_WindowPtr(window,collapsed,cond)
    cond = cond or 0
    return lib.igSetWindowCollapsed_WindowPtr(window,collapsed,cond)
end
function M.SetWindowCollapsed(a1,a2,a3) -- generic version
    if (ffi.istype('bool',a1) or type(a1)=='boolean') then return M.SetWindowCollapsed_Bool(a1,a2) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.SetWindowCollapsed_Str(a1,a2,a3) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetWindowCollapsed_WindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetWindowCollapsed could not find overloaded'
end
M.SetWindowDock = lib.igSetWindowDock
M.SetWindowFocus_Nil = lib.igSetWindowFocus_Nil
M.SetWindowFocus_Str = lib.igSetWindowFocus_Str
function M.SetWindowFocus(a1) -- generic version
    if a1==nil then return M.SetWindowFocus_Nil() end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.SetWindowFocus_Str(a1) end
    print(a1)
    error'M.SetWindowFocus could not find overloaded'
end
M.SetWindowHiddenAndSkipItemsForCurrentFrame = lib.igSetWindowHiddenAndSkipItemsForCurrentFrame
M.SetWindowHitTestHole = lib.igSetWindowHitTestHole
M.SetWindowParentWindowForFocusRoute = lib.igSetWindowParentWindowForFocusRoute
function M.SetWindowPos_Vec2(pos,cond)
    cond = cond or 0
    return lib.igSetWindowPos_Vec2(pos,cond)
end
function M.SetWindowPos_Str(name,pos,cond)
    cond = cond or 0
    return lib.igSetWindowPos_Str(name,pos,cond)
end
function M.SetWindowPos_WindowPtr(window,pos,cond)
    cond = cond or 0
    return lib.igSetWindowPos_WindowPtr(window,pos,cond)
end
function M.SetWindowPos(a1,a2,a3) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.SetWindowPos_Vec2(a1,a2) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.SetWindowPos_Str(a1,a2,a3) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetWindowPos_WindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetWindowPos could not find overloaded'
end
function M.SetWindowSize_Vec2(size,cond)
    cond = cond or 0
    return lib.igSetWindowSize_Vec2(size,cond)
end
function M.SetWindowSize_Str(name,size,cond)
    cond = cond or 0
    return lib.igSetWindowSize_Str(name,size,cond)
end
function M.SetWindowSize_WindowPtr(window,size,cond)
    cond = cond or 0
    return lib.igSetWindowSize_WindowPtr(window,size,cond)
end
function M.SetWindowSize(a1,a2,a3) -- generic version
    if ffi.istype('const ImVec2',a1) then return M.SetWindowSize_Vec2(a1,a2) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.SetWindowSize_Str(a1,a2,a3) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.SetWindowSize_WindowPtr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.SetWindowSize could not find overloaded'
end
M.SetWindowViewport = lib.igSetWindowViewport
M.ShadeVertsLinearColorGradientKeepAlpha = lib.igShadeVertsLinearColorGradientKeepAlpha
M.ShadeVertsLinearUV = lib.igShadeVertsLinearUV
M.ShadeVertsTransformPos = lib.igShadeVertsTransformPos
function M.Shortcut_Nil(key_chord,flags)
    flags = flags or 0
    return lib.igShortcut_Nil(key_chord,flags)
end
M.Shortcut_ID = lib.igShortcut_ID
function M.Shortcut(a1,a2,a3) -- generic version
    if a3==nil then return M.Shortcut_Nil(a1,a2) end
    if (ffi.istype('uint32_t',a3) or type(a3)=='number') then return M.Shortcut_ID(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.Shortcut could not find overloaded'
end
function M.ShowAboutWindow(p_open)
    p_open = p_open or nil
    return lib.igShowAboutWindow(p_open)
end
function M.ShowDebugLogWindow(p_open)
    p_open = p_open or nil
    return lib.igShowDebugLogWindow(p_open)
end
function M.ShowDemoWindow(p_open)
    p_open = p_open or nil
    return lib.igShowDemoWindow(p_open)
end
M.ShowFontAtlas = lib.igShowFontAtlas
M.ShowFontSelector = lib.igShowFontSelector
function M.ShowIDStackToolWindow(p_open)
    p_open = p_open or nil
    return lib.igShowIDStackToolWindow(p_open)
end
function M.ShowMetricsWindow(p_open)
    p_open = p_open or nil
    return lib.igShowMetricsWindow(p_open)
end
function M.ShowStyleEditor(ref)
    ref = ref or nil
    return lib.igShowStyleEditor(ref)
end
M.ShowStyleSelector = lib.igShowStyleSelector
M.ShowUserGuide = lib.igShowUserGuide
M.ShrinkWidths = lib.igShrinkWidths
M.Shutdown = lib.igShutdown
function M.SliderAngle(label,v_rad,v_degrees_min,v_degrees_max,format,flags)
    flags = flags or 0
    format = format or "%.0f deg"
    v_degrees_max = v_degrees_max or 360.0
    v_degrees_min = v_degrees_min or -360.0
    return lib.igSliderAngle(label,v_rad,v_degrees_min,v_degrees_max,format,flags)
end
M.SliderBehavior = lib.igSliderBehavior
function M.SliderFloat(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igSliderFloat(label,v,v_min,v_max,format,flags)
end
function M.SliderFloat2(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igSliderFloat2(label,v,v_min,v_max,format,flags)
end
function M.SliderFloat3(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igSliderFloat3(label,v,v_min,v_max,format,flags)
end
function M.SliderFloat4(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igSliderFloat4(label,v,v_min,v_max,format,flags)
end
function M.SliderInt(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    return lib.igSliderInt(label,v,v_min,v_max,format,flags)
end
function M.SliderInt2(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    return lib.igSliderInt2(label,v,v_min,v_max,format,flags)
end
function M.SliderInt3(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    return lib.igSliderInt3(label,v,v_min,v_max,format,flags)
end
function M.SliderInt4(label,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    return lib.igSliderInt4(label,v,v_min,v_max,format,flags)
end
function M.SliderScalar(label,data_type,p_data,p_min,p_max,format,flags)
    flags = flags or 0
    format = format or nil
    return lib.igSliderScalar(label,data_type,p_data,p_min,p_max,format,flags)
end
function M.SliderScalarN(label,data_type,p_data,components,p_min,p_max,format,flags)
    flags = flags or 0
    format = format or nil
    return lib.igSliderScalarN(label,data_type,p_data,components,p_min,p_max,format,flags)
end
M.SmallButton = lib.igSmallButton
M.Spacing = lib.igSpacing
function M.SplitterBehavior(bb,id,axis,size1,size2,min_size1,min_size2,hover_extend,hover_visibility_delay,bg_col)
    bg_col = bg_col or 0
    hover_extend = hover_extend or 0.0
    hover_visibility_delay = hover_visibility_delay or 0.0
    return lib.igSplitterBehavior(bb,id,axis,size1,size2,min_size1,min_size2,hover_extend,hover_visibility_delay,bg_col)
end
M.StartMouseMovingWindow = lib.igStartMouseMovingWindow
M.StartMouseMovingWindowOrNode = lib.igStartMouseMovingWindowOrNode
M.StopMouseMovingWindow = lib.igStopMouseMovingWindow
function M.StyleColorsClassic(dst)
    dst = dst or nil
    return lib.igStyleColorsClassic(dst)
end
function M.StyleColorsDark(dst)
    dst = dst or nil
    return lib.igStyleColorsDark(dst)
end
function M.StyleColorsLight(dst)
    dst = dst or nil
    return lib.igStyleColorsLight(dst)
end
M.TabBarAddTab = lib.igTabBarAddTab
M.TabBarCloseTab = lib.igTabBarCloseTab
M.TabBarFindByID = lib.igTabBarFindByID
M.TabBarFindMostRecentlySelectedTabForActiveWindow = lib.igTabBarFindMostRecentlySelectedTabForActiveWindow
M.TabBarFindTabByID = lib.igTabBarFindTabByID
M.TabBarFindTabByOrder = lib.igTabBarFindTabByOrder
M.TabBarGetCurrentTab = lib.igTabBarGetCurrentTab
M.TabBarGetTabName = lib.igTabBarGetTabName
M.TabBarGetTabOrder = lib.igTabBarGetTabOrder
M.TabBarGetTabPos = lib.igTabBarGetTabPos
M.TabBarProcessReorder = lib.igTabBarProcessReorder
M.TabBarQueueFocus_TabItemPtr = lib.igTabBarQueueFocus_TabItemPtr
M.TabBarQueueFocus_Str = lib.igTabBarQueueFocus_Str
function M.TabBarQueueFocus(a1,a2) -- generic version
    if (ffi.istype('ImGuiTabItem*',a2) or ffi.istype('ImGuiTabItem',a2) or ffi.istype('ImGuiTabItem[]',a2)) then return M.TabBarQueueFocus_TabItemPtr(a1,a2) end
    if (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.TabBarQueueFocus_Str(a1,a2) end
    print(a1,a2)
    error'M.TabBarQueueFocus could not find overloaded'
end
M.TabBarQueueReorder = lib.igTabBarQueueReorder
M.TabBarQueueReorderFromMousePos = lib.igTabBarQueueReorderFromMousePos
M.TabBarRemove = lib.igTabBarRemove
M.TabBarRemoveTab = lib.igTabBarRemoveTab
M.TabItemBackground = lib.igTabItemBackground
function M.TabItemButton(label,flags)
    flags = flags or 0
    return lib.igTabItemButton(label,flags)
end
M.TabItemCalcSize_Str = lib.igTabItemCalcSize_Str
M.TabItemCalcSize_WindowPtr = lib.igTabItemCalcSize_WindowPtr
function M.TabItemCalcSize(a1,a2) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.TabItemCalcSize_Str(a1,a2) end
    if (ffi.istype('ImGuiWindow*',a1) or ffi.istype('ImGuiWindow',a1) or ffi.istype('ImGuiWindow[]',a1)) then return M.TabItemCalcSize_WindowPtr(a1) end
    print(a1,a2)
    error'M.TabItemCalcSize could not find overloaded'
end
M.TabItemEx = lib.igTabItemEx
M.TabItemLabelAndCloseButton = lib.igTabItemLabelAndCloseButton
M.TabItemSpacing = lib.igTabItemSpacing
M.TableAngledHeadersRow = lib.igTableAngledHeadersRow
M.TableAngledHeadersRowEx = lib.igTableAngledHeadersRowEx
M.TableApplyExternalUnclipRect = lib.igTableApplyExternalUnclipRect
M.TableApplyQueuedRequests = lib.igTableApplyQueuedRequests
M.TableBeginCell = lib.igTableBeginCell
M.TableBeginContextMenuPopup = lib.igTableBeginContextMenuPopup
M.TableBeginInitMemory = lib.igTableBeginInitMemory
M.TableBeginRow = lib.igTableBeginRow
M.TableCalcMaxColumnWidth = lib.igTableCalcMaxColumnWidth
M.TableDrawBorders = lib.igTableDrawBorders
M.TableDrawDefaultContextMenu = lib.igTableDrawDefaultContextMenu
M.TableEndCell = lib.igTableEndCell
M.TableEndRow = lib.igTableEndRow
M.TableFindByID = lib.igTableFindByID
M.TableFixColumnSortDirection = lib.igTableFixColumnSortDirection
M.TableFixDisplayOrder = lib.igTableFixDisplayOrder
M.TableGcCompactSettings = lib.igTableGcCompactSettings
M.TableGcCompactTransientBuffers_TablePtr = lib.igTableGcCompactTransientBuffers_TablePtr
M.TableGcCompactTransientBuffers_TableTempDataPtr = lib.igTableGcCompactTransientBuffers_TableTempDataPtr
function M.TableGcCompactTransientBuffers(a1) -- generic version
    if (ffi.istype('ImGuiTable*',a1) or ffi.istype('ImGuiTable',a1) or ffi.istype('ImGuiTable[]',a1)) then return M.TableGcCompactTransientBuffers_TablePtr(a1) end
    if (ffi.istype('ImGuiTableTempData*',a1) or ffi.istype('ImGuiTableTempData',a1) or ffi.istype('ImGuiTableTempData[]',a1)) then return M.TableGcCompactTransientBuffers_TableTempDataPtr(a1) end
    print(a1)
    error'M.TableGcCompactTransientBuffers could not find overloaded'
end
M.TableGetBoundSettings = lib.igTableGetBoundSettings
M.TableGetCellBgRect = lib.igTableGetCellBgRect
M.TableGetColumnCount = lib.igTableGetColumnCount
function M.TableGetColumnFlags(column_n)
    column_n = column_n or -1
    return lib.igTableGetColumnFlags(column_n)
end
M.TableGetColumnIndex = lib.igTableGetColumnIndex
function M.TableGetColumnName_Int(column_n)
    column_n = column_n or -1
    return lib.igTableGetColumnName_Int(column_n)
end
M.TableGetColumnName_TablePtr = lib.igTableGetColumnName_TablePtr
function M.TableGetColumnName(a1,a2) -- generic version
    if ((ffi.istype('int32_t',a1) or type(a1)=='number') or type(a1)=='nil') then return M.TableGetColumnName_Int(a1) end
    if (ffi.istype('const ImGuiTable*',a1) or ffi.istype('const ImGuiTable',a1) or ffi.istype('const ImGuiTable[]',a1)) then return M.TableGetColumnName_TablePtr(a1,a2) end
    print(a1,a2)
    error'M.TableGetColumnName could not find overloaded'
end
M.TableGetColumnNextSortDirection = lib.igTableGetColumnNextSortDirection
function M.TableGetColumnResizeID(table,column_n,instance_no)
    instance_no = instance_no or 0
    return lib.igTableGetColumnResizeID(table,column_n,instance_no)
end
M.TableGetColumnWidthAuto = lib.igTableGetColumnWidthAuto
M.TableGetHeaderAngledMaxLabelWidth = lib.igTableGetHeaderAngledMaxLabelWidth
M.TableGetHeaderRowHeight = lib.igTableGetHeaderRowHeight
M.TableGetHoveredColumn = lib.igTableGetHoveredColumn
M.TableGetHoveredRow = lib.igTableGetHoveredRow
M.TableGetInstanceData = lib.igTableGetInstanceData
M.TableGetInstanceID = lib.igTableGetInstanceID
M.TableGetRowIndex = lib.igTableGetRowIndex
M.TableGetSortSpecs = lib.igTableGetSortSpecs
M.TableHeader = lib.igTableHeader
M.TableHeadersRow = lib.igTableHeadersRow
M.TableInitColumnDefaults = lib.igTableInitColumnDefaults
M.TableLoadSettings = lib.igTableLoadSettings
M.TableLoadSettingsForColumn = lib.igTableLoadSettingsForColumn
M.TableLoadSettingsForColumns = lib.igTableLoadSettingsForColumns
M.TableMergeDrawChannels = lib.igTableMergeDrawChannels
M.TableNextColumn = lib.igTableNextColumn
function M.TableNextRow(row_flags,min_row_height)
    min_row_height = min_row_height or 0.0
    row_flags = row_flags or 0
    return lib.igTableNextRow(row_flags,min_row_height)
end
function M.TableOpenContextMenu(column_n)
    column_n = column_n or -1
    return lib.igTableOpenContextMenu(column_n)
end
M.TablePopBackgroundChannel = lib.igTablePopBackgroundChannel
M.TablePopColumnChannel = lib.igTablePopColumnChannel
M.TablePushBackgroundChannel = lib.igTablePushBackgroundChannel
M.TablePushColumnChannel = lib.igTablePushColumnChannel
M.TableQueueSetColumnDisplayOrder = lib.igTableQueueSetColumnDisplayOrder
M.TableReconcileColumns = lib.igTableReconcileColumns
M.TableRemove = lib.igTableRemove
M.TableResetSettings = lib.igTableResetSettings
M.TableSaveSettings = lib.igTableSaveSettings
function M.TableSetBgColor(target,color,column_n)
    column_n = column_n or -1
    return lib.igTableSetBgColor(target,color,column_n)
end
M.TableSetColumnDisplayOrder = lib.igTableSetColumnDisplayOrder
M.TableSetColumnEnabled = lib.igTableSetColumnEnabled
M.TableSetColumnIndex = lib.igTableSetColumnIndex
M.TableSetColumnSortDirection = lib.igTableSetColumnSortDirection
M.TableSetColumnWidth = lib.igTableSetColumnWidth
M.TableSetColumnWidthAutoAll = lib.igTableSetColumnWidthAutoAll
M.TableSetColumnWidthAutoSingle = lib.igTableSetColumnWidthAutoSingle
M.TableSettingsAddSettingsHandler = lib.igTableSettingsAddSettingsHandler
M.TableSettingsCreate = lib.igTableSettingsCreate
M.TableSettingsFindByID = lib.igTableSettingsFindByID
function M.TableSetupColumn(label,flags,init_width_or_weight,user_data)
    flags = flags or 0
    init_width_or_weight = init_width_or_weight or 0.0
    user_data = user_data or 0
    return lib.igTableSetupColumn(label,flags,init_width_or_weight,user_data)
end
M.TableSetupDrawChannels = lib.igTableSetupDrawChannels
M.TableSetupScrollFreeze = lib.igTableSetupScrollFreeze
M.TableSortSpecsBuild = lib.igTableSortSpecsBuild
M.TableSortSpecsSanitize = lib.igTableSortSpecsSanitize
M.TableUpdateBorders = lib.igTableUpdateBorders
M.TableUpdateColumnsWeightFromWidth = lib.igTableUpdateColumnsWeightFromWidth
M.TableUpdateLayout = lib.igTableUpdateLayout
M.TeleportMousePos = lib.igTeleportMousePos
M.TempInputIsActive = lib.igTempInputIsActive
function M.TempInputScalar(bb,id,label,data_type,p_data,format,p_clamp_min,p_clamp_max)
    p_clamp_max = p_clamp_max or nil
    p_clamp_min = p_clamp_min or nil
    return lib.igTempInputScalar(bb,id,label,data_type,p_data,format,p_clamp_min,p_clamp_max)
end
function M.TempInputText(bb,id,label,buf,buf_size,flags,callback,user_data)
    callback = callback or nil
    flags = flags or 0
    user_data = user_data or nil
    return lib.igTempInputText(bb,id,label,buf,buf_size,flags,callback,user_data)
end
M.TestKeyOwner = lib.igTestKeyOwner
M.TestShortcutRouting = lib.igTestShortcutRouting
M.Text = lib.igText
M.TextAligned = lib.igTextAligned
M.TextAlignedV = lib.igTextAlignedV
M.TextColored = lib.igTextColored
M.TextColoredV = lib.igTextColoredV
M.TextDisabled = lib.igTextDisabled
M.TextDisabledV = lib.igTextDisabledV
function M.TextEx(text,text_end,flags)
    flags = flags or 0
    text_end = text_end or nil
    return lib.igTextEx(text,text_end,flags)
end
M.TextLink = lib.igTextLink
function M.TextLinkOpenURL(label,url)
    url = url or nil
    return lib.igTextLinkOpenURL(label,url)
end
function M.TextUnformatted(text,text_end)
    text_end = text_end or nil
    return lib.igTextUnformatted(text,text_end)
end
M.TextV = lib.igTextV
M.TextWrapped = lib.igTextWrapped
M.TextWrappedV = lib.igTextWrappedV
M.TranslateWindowsInViewport = lib.igTranslateWindowsInViewport
M.TreeNode_Str = lib.igTreeNode_Str
M.TreeNode_StrStr = lib.igTreeNode_StrStr
M.TreeNode_Ptr = lib.igTreeNode_Ptr
function M.TreeNode(a1,a2,...) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a2==nil then return M.TreeNode_Str(a1) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a2) or ffi.istype('char[]',a2) or type(a2)=='string') then return M.TreeNode_StrStr(a1,a2,...) end
    if ffi.istype('void *',a1) then return M.TreeNode_Ptr(a1,a2,...) end
    print(a1,a2,...)
    error'M.TreeNode could not find overloaded'
end
function M.TreeNodeBehavior(id,flags,label,label_end)
    label_end = label_end or nil
    return lib.igTreeNodeBehavior(id,flags,label,label_end)
end
M.TreeNodeDrawLineToChildNode = lib.igTreeNodeDrawLineToChildNode
M.TreeNodeDrawLineToTreePop = lib.igTreeNodeDrawLineToTreePop
function M.TreeNodeEx_Str(label,flags)
    flags = flags or 0
    return lib.igTreeNodeEx_Str(label,flags)
end
M.TreeNodeEx_StrStr = lib.igTreeNodeEx_StrStr
M.TreeNodeEx_Ptr = lib.igTreeNodeEx_Ptr
function M.TreeNodeEx(a1,a2,a3,...) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and a3==nil then return M.TreeNodeEx_Str(a1,a2) end
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') and (ffi.istype('const char*',a3) or ffi.istype('char[]',a3) or type(a3)=='string') then return M.TreeNodeEx_StrStr(a1,a2,a3,...) end
    if ffi.istype('void *',a1) then return M.TreeNodeEx_Ptr(a1,a2,a3,...) end
    print(a1,a2,a3,...)
    error'M.TreeNodeEx could not find overloaded'
end
M.TreeNodeExV_Str = lib.igTreeNodeExV_Str
M.TreeNodeExV_Ptr = lib.igTreeNodeExV_Ptr
function M.TreeNodeExV(a1,a2,a3,a4) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.TreeNodeExV_Str(a1,a2,a3,a4) end
    if ffi.istype('void *',a1) then return M.TreeNodeExV_Ptr(a1,a2,a3,a4) end
    print(a1,a2,a3,a4)
    error'M.TreeNodeExV could not find overloaded'
end
M.TreeNodeGetOpen = lib.igTreeNodeGetOpen
M.TreeNodeSetOpen = lib.igTreeNodeSetOpen
M.TreeNodeUpdateNextOpen = lib.igTreeNodeUpdateNextOpen
M.TreeNodeV_Str = lib.igTreeNodeV_Str
M.TreeNodeV_Ptr = lib.igTreeNodeV_Ptr
function M.TreeNodeV(a1,a2,a3) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.TreeNodeV_Str(a1,a2,a3) end
    if ffi.istype('void *',a1) then return M.TreeNodeV_Ptr(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.TreeNodeV could not find overloaded'
end
M.TreePop = lib.igTreePop
M.TreePush_Str = lib.igTreePush_Str
M.TreePush_Ptr = lib.igTreePush_Ptr
function M.TreePush(a1) -- generic version
    if (ffi.istype('const char*',a1) or ffi.istype('char[]',a1) or type(a1)=='string') then return M.TreePush_Str(a1) end
    if ffi.istype('void *',a1) then return M.TreePush_Ptr(a1) end
    print(a1)
    error'M.TreePush could not find overloaded'
end
M.TreePushOverrideID = lib.igTreePushOverrideID
M.TypingSelectFindBestLeadingMatch = lib.igTypingSelectFindBestLeadingMatch
M.TypingSelectFindMatch = lib.igTypingSelectFindMatch
M.TypingSelectFindNextSingleCharMatch = lib.igTypingSelectFindNextSingleCharMatch
function M.Unindent(indent_w)
    indent_w = indent_w or 0.0
    return lib.igUnindent(indent_w)
end
M.UnregisterFontAtlas = lib.igUnregisterFontAtlas
M.UnregisterUserTexture = lib.igUnregisterUserTexture
M.UpdateCurrentFontSize = lib.igUpdateCurrentFontSize
M.UpdateHoveredWindowAndCaptureFlags = lib.igUpdateHoveredWindowAndCaptureFlags
M.UpdateInputEvents = lib.igUpdateInputEvents
M.UpdateMouseMovingWindowEndFrame = lib.igUpdateMouseMovingWindowEndFrame
M.UpdateMouseMovingWindowNewFrame = lib.igUpdateMouseMovingWindowNewFrame
M.UpdatePlatformWindows = lib.igUpdatePlatformWindows
M.UpdateWindowParentAndRootLinks = lib.igUpdateWindowParentAndRootLinks
M.UpdateWindowSkipRefresh = lib.igUpdateWindowSkipRefresh
function M.VSliderFloat(label,size,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%.3f"
    return lib.igVSliderFloat(label,size,v,v_min,v_max,format,flags)
end
function M.VSliderInt(label,size,v,v_min,v_max,format,flags)
    flags = flags or 0
    format = format or "%d"
    return lib.igVSliderInt(label,size,v,v_min,v_max,format,flags)
end
function M.VSliderScalar(label,size,data_type,p_data,p_min,p_max,format,flags)
    flags = flags or 0
    format = format or nil
    return lib.igVSliderScalar(label,size,data_type,p_data,p_min,p_max,format,flags)
end
M.Value_Bool = lib.igValue_Bool
M.Value_Int = lib.igValue_Int
M.Value_Uint = lib.igValue_Uint
function M.Value_Float(prefix,v,float_format)
    float_format = float_format or nil
    return lib.igValue_Float(prefix,v,float_format)
end
function M.Value(a1,a2,a3) -- generic version
    if (ffi.istype('bool',a2) or type(a2)=='boolean') then return M.Value_Bool(a1,a2) end
    if (ffi.istype('int32_t',a2) or type(a2)=='number') then return M.Value_Int(a1,a2) end
    if (ffi.istype('uint32_t',a2) or type(a2)=='number') then return M.Value_Uint(a1,a2) end
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.Value_Float(a1,a2,a3) end
    print(a1,a2,a3)
    error'M.Value could not find overloaded'
end
M.WindowPosAbsToRel = lib.igWindowPosAbsToRel
M.WindowPosRelToAbs = lib.igWindowPosRelToAbs
M.WindowRectAbsToRel = lib.igWindowRectAbsToRel
M.WindowRectRelToAbs = lib.igWindowRectRelToAbs
function M.gizmo3D_quatPtrFloat(t,q,sz,flag)
    flag = flag or 257
    return lib.iggizmo3D_quatPtrFloat(t,q,sz,flag)
end
function M.gizmo3D_vec4Ptr(t,v,sz,flag)
    flag = flag or 257
    return lib.iggizmo3D_vec4Ptr(t,v,sz,flag)
end
function M.gizmo3D_vec3PtrFloat(t,v,sz,flag)
    flag = flag or 2
    return lib.iggizmo3D_vec3PtrFloat(t,v,sz,flag)
end
function M.gizmo3D_quatPtrquatPtr(t,q,ql,sz,flag)
    flag = flag or 264
    return lib.iggizmo3D_quatPtrquatPtr(t,q,ql,sz,flag)
end
function M.gizmo3D_quatPtrvec4Ptr(t,q,v,sz,flag)
    flag = flag or 264
    return lib.iggizmo3D_quatPtrvec4Ptr(t,q,v,sz,flag)
end
function M.gizmo3D_quatPtrvec3Ptr(t,q,v,sz,flag)
    flag = flag or 264
    return lib.iggizmo3D_quatPtrvec3Ptr(t,q,v,sz,flag)
end
function M.gizmo3D_vec3PtrquatPtrFloat(t,vm,q,sz,flag)
    flag = flag or 257
    return lib.iggizmo3D_vec3PtrquatPtrFloat(t,vm,q,sz,flag)
end
function M.gizmo3D_vec3Ptrvec4Ptr(t,vm,v,sz,flag)
    flag = flag or 257
    return lib.iggizmo3D_vec3Ptrvec4Ptr(t,vm,v,sz,flag)
end
function M.gizmo3D_vec3Ptrvec3Ptr(t,vm,v,sz,flag)
    flag = flag or 2
    return lib.iggizmo3D_vec3Ptrvec3Ptr(t,vm,v,sz,flag)
end
function M.gizmo3D_vec3PtrquatPtrquatPtr(t,vm,q,ql,sz,flag)
    flag = flag or 264
    return lib.iggizmo3D_vec3PtrquatPtrquatPtr(t,vm,q,ql,sz,flag)
end
function M.gizmo3D_vec3PtrquatPtrvec4Ptr(t,vm,q,v,sz,flag)
    flag = flag or 264
    return lib.iggizmo3D_vec3PtrquatPtrvec4Ptr(t,vm,q,v,sz,flag)
end
function M.gizmo3D_vec3PtrquatPtrvec3Ptr(t,vm,q,v,sz,flag)
    flag = flag or 264
    return lib.iggizmo3D_vec3PtrquatPtrvec3Ptr(t,vm,q,v,sz,flag)
end
function M.gizmo3D(a1,a2,a3,a4,a5,a6) -- generic version
    if (ffi.istype('quat*',a2) or ffi.istype('quat',a2) or ffi.istype('quat[]',a2)) and (ffi.istype('float',a3) or type(a3)=='number') and ((ffi.istype('uint32_t',a4) or type(a4)=='number') or type(a4)=='nil') and a5==nil then return M.gizmo3D_quatPtrFloat(a1,a2,a3,a4) end
    if (ffi.istype('vec4*',a2) or ffi.istype('vec4',a2) or ffi.istype('vec4[]',a2)) then return M.gizmo3D_vec4Ptr(a1,a2,a3,a4) end
    if (ffi.istype('vec3*',a2) or ffi.istype('vec3',a2) or ffi.istype('vec3[]',a2)) and (ffi.istype('float',a3) or type(a3)=='number') and ((ffi.istype('uint32_t',a4) or type(a4)=='number') or type(a4)=='nil') and a5==nil then return M.gizmo3D_vec3PtrFloat(a1,a2,a3,a4) end
    if (ffi.istype('quat*',a2) or ffi.istype('quat',a2) or ffi.istype('quat[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('uint32_t',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3D_quatPtrquatPtr(a1,a2,a3,a4,a5) end
    if (ffi.istype('quat*',a2) or ffi.istype('quat',a2) or ffi.istype('quat[]',a2)) and (ffi.istype('vec4*',a3) or ffi.istype('vec4',a3) or ffi.istype('vec4[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('uint32_t',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3D_quatPtrvec4Ptr(a1,a2,a3,a4,a5) end
    if (ffi.istype('quat*',a2) or ffi.istype('quat',a2) or ffi.istype('quat[]',a2)) and (ffi.istype('vec3*',a3) or ffi.istype('vec3',a3) or ffi.istype('vec3[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('uint32_t',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3D_quatPtrvec3Ptr(a1,a2,a3,a4,a5) end
    if (ffi.istype('vec3*',a2) or ffi.istype('vec3',a2) or ffi.istype('vec3[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('uint32_t',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3D_vec3PtrquatPtrFloat(a1,a2,a3,a4,a5) end
    if (ffi.istype('vec3*',a2) or ffi.istype('vec3',a2) or ffi.istype('vec3[]',a2)) and (ffi.istype('vec4*',a3) or ffi.istype('vec4',a3) or ffi.istype('vec4[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('uint32_t',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3D_vec3Ptrvec4Ptr(a1,a2,a3,a4,a5) end
    if (ffi.istype('vec3*',a2) or ffi.istype('vec3',a2) or ffi.istype('vec3[]',a2)) and (ffi.istype('vec3*',a3) or ffi.istype('vec3',a3) or ffi.istype('vec3[]',a3)) and (ffi.istype('float',a4) or type(a4)=='number') and ((ffi.istype('uint32_t',a5) or type(a5)=='number') or type(a5)=='nil') then return M.gizmo3D_vec3Ptrvec3Ptr(a1,a2,a3,a4,a5) end
    if (ffi.istype('vec3*',a2) or ffi.istype('vec3',a2) or ffi.istype('vec3[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('quat*',a4) or ffi.istype('quat',a4) or ffi.istype('quat[]',a4)) then return M.gizmo3D_vec3PtrquatPtrquatPtr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('vec3*',a2) or ffi.istype('vec3',a2) or ffi.istype('vec3[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('vec4*',a4) or ffi.istype('vec4',a4) or ffi.istype('vec4[]',a4)) then return M.gizmo3D_vec3PtrquatPtrvec4Ptr(a1,a2,a3,a4,a5,a6) end
    if (ffi.istype('vec3*',a2) or ffi.istype('vec3',a2) or ffi.istype('vec3[]',a2)) and (ffi.istype('quat*',a3) or ffi.istype('quat',a3) or ffi.istype('quat[]',a3)) and (ffi.istype('vec3*',a4) or ffi.istype('vec3',a4) or ffi.istype('vec3[]',a4)) then return M.gizmo3D_vec3PtrquatPtrvec3Ptr(a1,a2,a3,a4,a5,a6) end
    print(a1,a2,a3,a4,a5,a6)
    error'M.gizmo3D could not find overloaded'
end
function M.imnodes_BeginInputAttribute(id,shape)
    shape = shape or 1
    return lib.imnodes_BeginInputAttribute(id,shape)
end
M.imnodes_BeginNode = lib.imnodes_BeginNode
M.imnodes_BeginNodeEditor = lib.imnodes_BeginNodeEditor
M.imnodes_BeginNodeTitleBar = lib.imnodes_BeginNodeTitleBar
function M.imnodes_BeginOutputAttribute(id,shape)
    shape = shape or 1
    return lib.imnodes_BeginOutputAttribute(id,shape)
end
M.imnodes_BeginStaticAttribute = lib.imnodes_BeginStaticAttribute
M.imnodes_ClearLinkSelection_Nil = lib.imnodes_ClearLinkSelection_Nil
M.imnodes_ClearLinkSelection_Int = lib.imnodes_ClearLinkSelection_Int
function M.imnodes_ClearLinkSelection(a1) -- generic version
    if a1==nil then return M.imnodes_ClearLinkSelection_Nil() end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.imnodes_ClearLinkSelection_Int(a1) end
    print(a1)
    error'M.imnodes_ClearLinkSelection could not find overloaded'
end
M.imnodes_ClearNodeSelection_Nil = lib.imnodes_ClearNodeSelection_Nil
M.imnodes_ClearNodeSelection_Int = lib.imnodes_ClearNodeSelection_Int
function M.imnodes_ClearNodeSelection(a1) -- generic version
    if a1==nil then return M.imnodes_ClearNodeSelection_Nil() end
    if (ffi.istype('int32_t',a1) or type(a1)=='number') then return M.imnodes_ClearNodeSelection_Int(a1) end
    print(a1)
    error'M.imnodes_ClearNodeSelection could not find overloaded'
end
M.imnodes_CreateContext = lib.imnodes_CreateContext
function M.imnodes_DestroyContext(ctx)
    ctx = ctx or nil
    return lib.imnodes_DestroyContext(ctx)
end
M.imnodes_EditorContextCreate = lib.imnodes_EditorContextCreate
M.imnodes_EditorContextFree = lib.imnodes_EditorContextFree
M.imnodes_EditorContextGetPanning = lib.imnodes_EditorContextGetPanning
M.imnodes_EditorContextMoveToNode = lib.imnodes_EditorContextMoveToNode
M.imnodes_EditorContextResetPanning = lib.imnodes_EditorContextResetPanning
M.imnodes_EditorContextSet = lib.imnodes_EditorContextSet
M.imnodes_EndInputAttribute = lib.imnodes_EndInputAttribute
M.imnodes_EndNode = lib.imnodes_EndNode
M.imnodes_EndNodeEditor = lib.imnodes_EndNodeEditor
M.imnodes_EndNodeTitleBar = lib.imnodes_EndNodeTitleBar
M.imnodes_EndOutputAttribute = lib.imnodes_EndOutputAttribute
M.imnodes_EndStaticAttribute = lib.imnodes_EndStaticAttribute
M.imnodes_GetCurrentContext = lib.imnodes_GetCurrentContext
M.imnodes_GetIO = lib.imnodes_GetIO
M.imnodes_GetNodeDimensions = lib.imnodes_GetNodeDimensions
M.imnodes_GetNodeEditorSpacePos = lib.imnodes_GetNodeEditorSpacePos
M.imnodes_GetNodeGridSpacePos = lib.imnodes_GetNodeGridSpacePos
M.imnodes_GetNodeScreenSpacePos = lib.imnodes_GetNodeScreenSpacePos
M.imnodes_GetSelectedLinks = lib.imnodes_GetSelectedLinks
M.imnodes_GetSelectedNodes = lib.imnodes_GetSelectedNodes
M.imnodes_GetStyle = lib.imnodes_GetStyle
M.imnodes_GetStyleColorName = lib.imnodes_GetStyleColorName
function M.imnodes_IsAnyAttributeActive(attribute_id)
    attribute_id = attribute_id or nil
    return lib.imnodes_IsAnyAttributeActive(attribute_id)
end
M.imnodes_IsAttributeActive = lib.imnodes_IsAttributeActive
M.imnodes_IsEditorHovered = lib.imnodes_IsEditorHovered
function M.imnodes_IsLinkCreated_BoolPtr(started_at_attribute_id,ended_at_attribute_id,created_from_snap)
    created_from_snap = created_from_snap or nil
    return lib.imnodes_IsLinkCreated_BoolPtr(started_at_attribute_id,ended_at_attribute_id,created_from_snap)
end
function M.imnodes_IsLinkCreated_IntPtr(started_at_node_id,started_at_attribute_id,ended_at_node_id,ended_at_attribute_id,created_from_snap)
    created_from_snap = created_from_snap or nil
    return lib.imnodes_IsLinkCreated_IntPtr(started_at_node_id,started_at_attribute_id,ended_at_node_id,ended_at_attribute_id,created_from_snap)
end
function M.imnodes_IsLinkCreated(a1,a2,a3,a4,a5) -- generic version
    if ((ffi.istype('bool*',a3) or ffi.istype('bool[]',a3)) or type(a3)=='nil') then return M.imnodes_IsLinkCreated_BoolPtr(a1,a2,a3) end
    if ffi.typeof('int32_t*') == ffi.typeof(a3) or ffi.typeof('const int32_t*') == ffi.typeof(a3) or ffi.typeof('int32_t[?]') == ffi.typeof(a3) or ffi.typeof('const int32_t[?]') == ffi.typeof(a3) then return M.imnodes_IsLinkCreated_IntPtr(a1,a2,a3,a4,a5) end
    print(a1,a2,a3,a4,a5)
    error'M.imnodes_IsLinkCreated could not find overloaded'
end
M.imnodes_IsLinkDestroyed = lib.imnodes_IsLinkDestroyed
function M.imnodes_IsLinkDropped(started_at_attribute_id,including_detached_links)
    if including_detached_links == nil then including_detached_links = true end
    started_at_attribute_id = started_at_attribute_id or nil
    return lib.imnodes_IsLinkDropped(started_at_attribute_id,including_detached_links)
end
M.imnodes_IsLinkHovered = lib.imnodes_IsLinkHovered
M.imnodes_IsLinkSelected = lib.imnodes_IsLinkSelected
M.imnodes_IsLinkStarted = lib.imnodes_IsLinkStarted
M.imnodes_IsNodeHovered = lib.imnodes_IsNodeHovered
M.imnodes_IsNodeSelected = lib.imnodes_IsNodeSelected
M.imnodes_IsPinHovered = lib.imnodes_IsPinHovered
M.imnodes_Link = lib.imnodes_Link
M.imnodes_LoadCurrentEditorStateFromIniFile = lib.imnodes_LoadCurrentEditorStateFromIniFile
M.imnodes_LoadCurrentEditorStateFromIniString = lib.imnodes_LoadCurrentEditorStateFromIniString
M.imnodes_LoadEditorStateFromIniFile = lib.imnodes_LoadEditorStateFromIniFile
M.imnodes_LoadEditorStateFromIniString = lib.imnodes_LoadEditorStateFromIniString
function M.imnodes_MiniMap(minimap_size_fraction,location,node_hovering_callback,node_hovering_callback_data)
    location = location or 2
    minimap_size_fraction = minimap_size_fraction or 0.2
    node_hovering_callback = node_hovering_callback or nil
    node_hovering_callback_data = node_hovering_callback_data or nil
    return lib.imnodes_MiniMap(minimap_size_fraction,location,node_hovering_callback,node_hovering_callback_data)
end
M.imnodes_NumSelectedLinks = lib.imnodes_NumSelectedLinks
M.imnodes_NumSelectedNodes = lib.imnodes_NumSelectedNodes
M.imnodes_PopAttributeFlag = lib.imnodes_PopAttributeFlag
M.imnodes_PopColorStyle = lib.imnodes_PopColorStyle
function M.imnodes_PopStyleVar(count)
    count = count or 1
    return lib.imnodes_PopStyleVar(count)
end
M.imnodes_PushAttributeFlag = lib.imnodes_PushAttributeFlag
M.imnodes_PushColorStyle = lib.imnodes_PushColorStyle
M.imnodes_PushStyleVar_Float = lib.imnodes_PushStyleVar_Float
M.imnodes_PushStyleVar_Vec2 = lib.imnodes_PushStyleVar_Vec2
function M.imnodes_PushStyleVar(a1,a2) -- generic version
    if (ffi.istype('float',a2) or type(a2)=='number') then return M.imnodes_PushStyleVar_Float(a1,a2) end
    if ffi.istype('const ImVec2',a2) then return M.imnodes_PushStyleVar_Vec2(a1,a2) end
    print(a1,a2)
    error'M.imnodes_PushStyleVar could not find overloaded'
end
M.imnodes_SaveCurrentEditorStateToIniFile = lib.imnodes_SaveCurrentEditorStateToIniFile
function M.imnodes_SaveCurrentEditorStateToIniString(data_size)
    data_size = data_size or nil
    return lib.imnodes_SaveCurrentEditorStateToIniString(data_size)
end
M.imnodes_SaveEditorStateToIniFile = lib.imnodes_SaveEditorStateToIniFile
function M.imnodes_SaveEditorStateToIniString(editor,data_size)
    data_size = data_size or nil
    return lib.imnodes_SaveEditorStateToIniString(editor,data_size)
end
M.imnodes_SelectLink = lib.imnodes_SelectLink
M.imnodes_SelectNode = lib.imnodes_SelectNode
M.imnodes_SetCurrentContext = lib.imnodes_SetCurrentContext
M.imnodes_SetImGuiContext = lib.imnodes_SetImGuiContext
M.imnodes_SetNodeDraggable = lib.imnodes_SetNodeDraggable
M.imnodes_SetNodeEditorSpacePos = lib.imnodes_SetNodeEditorSpacePos
M.imnodes_SetNodeGridSpacePos = lib.imnodes_SetNodeGridSpacePos
M.imnodes_SetNodeScreenSpacePos = lib.imnodes_SetNodeScreenSpacePos
M.imnodes_SnapNodeToGrid = lib.imnodes_SnapNodeToGrid
function M.imnodes_StyleColorsClassic(dest)
    dest = dest or nil
    return lib.imnodes_StyleColorsClassic(dest)
end
function M.imnodes_StyleColorsDark(dest)
    dest = dest or nil
    return lib.imnodes_StyleColorsDark(dest)
end
function M.imnodes_StyleColorsLight(dest)
    dest = dest or nil
    return lib.imnodes_StyleColorsLight(dest)
end
-- _LJ versions
M.ImPlot_PlotBarsG = M.ImPlot_PlotBarsG_LJ
M.ImPlot_PlotDigitalG = M.ImPlot_PlotDigitalG_LJ
M.ImPlot_PlotLineG = M.ImPlot_PlotLineG_LJ
M.ImPlot_PlotScatterG = M.ImPlot_PlotScatterG_LJ
M.ImPlot_PlotShadedG = M.ImPlot_PlotShadedG_LJ
M.ImPlot_PlotStairsG = M.ImPlot_PlotStairsG_LJ
return M
----------END_AUTOGENERATED_LUA-----------------------------
end --loader