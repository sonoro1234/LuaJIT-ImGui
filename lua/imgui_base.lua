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



