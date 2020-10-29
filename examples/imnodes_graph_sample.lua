local igwin = require"imgui.window"

--local win = igwin:SDL(800,400, "compute graph",{vsync=true})
local win = igwin:GLFW(800,400, "compute graph",{vsync=true})
local ig = win.ig
local ffi = require"ffi"
local serializer = require"serializer"

local function DFS(G,v)
    G.nodes_explored[v] = true
    local values = {}
    for i,id in ipairs(G.nodes[v].fromedges) do
        local value
        if not G.nodes_explored[id] then
            value = DFS(G,id)
            G.nodes_values[id] = value
        else
            value = G.nodes_values[id]
            if not value then 
                value = G.old_nodes_values[id]
                --print("cicle found",value)
            end
        end
        table.insert(values,value)
    end
    return G.nodes[v].compute(values)
end

local function Graph()
    local G = {nodes={},edges={}}
    function G:insert_nodeIn(id, compute)
        self.nodes[id] = {fromedges={},compute=compute,kind="in"}
    end
    function G:insert_nodeOut(id, compute)
        self.nodes[id] = {fromedges={},compute=compute,kind="out"}
    end
    function G:insert_node(id, compute)
        self.nodes[id] = {fromedges={},compute=compute,kind="?"}
    end
    function G:delete_node(id)
        local fromedges = self.nodes[id].fromedges
        for i,id1 in ipairs(fromedges) do
            self:delete_edge(id1,id)
        end
        self.nodes[id] = nil
    end
    function G:insert_edge(id1,id2)
        local fromedgs = self.nodes[id2].fromedges
        table.insert(fromedgs,id1)
    end
    function G:delete_edge(id1,id2)
        local fromedgs = self.nodes[id2].fromedges
        for i,id in ipairs(fromedgs) do
            if id == id1 then table.remove(fromedgs,i) end
        end
    end
    function G:DFS(root)
        G.nodes_explored = {}
        G.old_nodes_values = G.nodes_values or {}
        G.nodes_values = {}
        return DFS(self,root)
    end
    return G
end

local function Link()
    local link = {id=0,start_attr=ffi.new("int[?]",1),end_attr=ffi.new("int[?]",1)}
    function link:save_str()
        return "{id = " .. self.id .. 
        ", start_attr = " .. self.start_attr[0] .. 
        ", end_attr = " .. self.end_attr[0] .. "}"
    end
    function link:loadT(t)
        self.id = t.id
        self.start_attr[0] = t.start_attr
        self.end_attr[0] = t.end_attr
    end
    return link
end

local function Node(value,editor,typen,loadT)
    local node
    if not loadT then
        node = {
            id = editor:newid(),
            type = typen.name
        }
        node.inputs = {}
        node.input_names = {}
        for i,iname in ipairs(typen.input_names) do
            node.inputs[i] = editor:newid()
            node.input_names[i] = iname
        end
        if not typen.is_root then
            node.output_id = node.id 
        end
        -- create static_id
        node.values = {}
        for i ,input_id in ipairs(node.inputs) do
            node.values[i] = ffi.new("float[?]",1,value)
        end
    else
        node = loadT
    end
    local typename = node.type
    for i,typ in ipairs(editor.nodetypes) do
        if typename==typ.name then
            node.compute = typ.compute
            break
        end
    end
    -------------add pins to Graph
    local function computeIn(i)
        return function(t)
            if t[1] then
                return t[1]
            else
                return node.values[i][0]
            end
        end
    end
    
    for i ,input_id in ipairs(node.inputs) do
        editor.G:insert_node(input_id,computeIn(i))
    end
    if node.output_id then 
        editor.G:insert_node(node.output_id,node.compute)
        for _ ,input_id in ipairs(node.inputs) do
            editor.G:insert_edge(input_id,node.output_id)
        end
    end
    --add root node
    if node.type=="output" then
        editor.G:insert_node(node.id,node.compute)
        for _ ,input_id in ipairs(node.inputs) do
            editor.G:insert_edge(input_id,node.id)
        end
    end
    ----------------------
    function node:delete()
        --delete pins from graph
        for _ ,input_id in ipairs(self.inputs) do
            editor.G:delete_node(input_id)
        end
        if node.output_id then 
            editor.G:delete_node(self.output_id)
        end
        if node.type=="output" then
            editor.G:delete_node(node.id)
        end
    end
    function node:hasLink(link)
        for i ,input_id in ipairs(self.inputs) do
            if link.end_attr[0] == input_id then return true end
        end
        return link.start_attr[0] == self.output_id 
    end
    function node:save_str(name)
        self.pos = ig.imnodes_GetNodeGridSpacePos(self.id)
        return serializer(name,self)
    end
    function node:draw()
        if self.pos then -- for reset position of saved and loaded node
            ig.imnodes_SetNodeGridSpacePos(self.id, self.pos)
            self.pos = nil
        end
        ig.imnodes_BeginNode(node.id);
        ig.imnodes_BeginNodeTitleBar();
        ig.TextUnformatted(node.type);
        ig.imnodes_EndNodeTitleBar();
        
        for i, input_id in ipairs(node.inputs) do
            ig.imnodes_BeginInputAttribute(input_id)
            ig.TextUnformatted(node.input_names[i]);
            ig.imnodes_EndInputAttribute();
            --if there is no input
            local orig = editor.G.nodes[input_id].fromedges
            if #orig==0 then
                ig.SameLine()
                ig.imnodes_BeginStaticAttribute(input_id)
                ig.PushItemWidth(80.0);
                ig.DragFloat("##value"..i, node.values[i], 0.01);
                ig.PopItemWidth();
                ig.imnodes_EndStaticAttribute();
            end
        end

        if node.output_id then
            ig.imnodes_BeginOutputAttribute(node.output_id)
            local text_width = ig.CalcTextSize("output").x;
            ig.Indent(80. + ig.CalcTextSize("value").x - text_width);
            ig.TextUnformatted("output");
            ig.imnodes_EndOutputAttribute();
        end
        
        ig.imnodes_EndNode();
    end
    return node
end

local function show_editor(editor)

    ig.imnodes_EditorContextSet(editor.context);

    ig.Begin(editor.name);
   
    local enab = ffi.new("bool[1]",ig.imnodes_GetIO().emulate_three_button_mouse.enabled)
    ig.Checkbox("emulate three button mouse",enab)
    ig.imnodes_GetIO().emulate_three_button_mouse.enabled = enab[0]

    ig.TextUnformatted("A -- add node");
    ig.TextUnformatted("X -- delete selected node or link");
    ig.imnodes_BeginNodeEditor();

    local user_key = ig.GetKeyIndex(ig.lib.ImGuiKey_A)
    local open_popup
    if (ig.IsWindowFocused(ig.lib.ImGuiFocusedFlags_RootAndChildWindows) and
        ig.imnodes_IsEditorHovered() and ig.IsKeyReleased(user_key))
    then
        open_popup = true
    end

    ig.PushStyleVar(ig.lib.ImGuiStyleVar_WindowPadding, ig.ImVec2(8, 8))
    if open_popup then ig.OpenPopup("add node") end
    if ig.BeginPopup"add node" then
        local click_pos = ig.GetMousePosOnOpeningCurrentPopup();
        for i,ntype in ipairs(editor.nodetypes) do
            if ig.MenuItem(ntype.name) then
                local newnode = editor:Node(0,ntype)
                if newnode then
                    ig.imnodes_SetNodeScreenSpacePos(newnode.id, click_pos)
                end
            end
        end
        ig.EndPopup()
    end
    ig.PopStyleVar()

    for _, node in pairs(editor.nodes) do
        node:draw()
    end
    
    for _, link in pairs(editor.links) do
        ig.imnodes_Link(link.id, link.start_attr[0], link.end_attr[0]);
    end

    ig.imnodes_EndNodeEditor();

    --[[
    local hovid = ffi.new("int[1]")
    if ig.imnodes_IsNodeHovered(hovid) then
        print(hovid[0],"hovered")
    end
    
    local hovid = ffi.new("int[1]")
    if ig.imnodes_IsLinkHovered(hovid) then
        print(hovid[0],"hovered link")
    end
    
    local hovid = ffi.new("int[1]")
    if ig.imnodes_IsPinHovered(hovid) then
        print(hovid[0],"hovered pin")
    end
    --]]

    local link = Link()
    if (ig.imnodes_IsLinkCreated(link.start_attr, link.end_attr)) then
        editor:addLink(link)
    end

    local link_id = ffi.new("int[?]",1)
    if (ig.imnodes_IsLinkDestroyed(link_id)) then
        editor:deleteLink(link_id[0])
    end
    
    local dodelete = false
    local user_key = ig.GetKeyIndex(ig.lib.ImGuiKey_X)
    if ig.IsWindowFocused(ig.lib.ImGuiFocusedFlags_RootAndChildWindows) and 
        ig.IsKeyReleased(user_key)
    then
        dodelete = true
    end
    
    local num_selected = ig.imnodes_NumSelectedLinks();
    if (num_selected > 0 and dodelete) then
        local selected_links = ffi.new("int[?]",num_selected)
        ig.imnodes_GetSelectedLinks(selected_links);
        for i=0,num_selected-1 do
            editor:deleteLink(selected_links[i])
        end
    end
    
    local num_selected = ig.imnodes_NumSelectedNodes();
    if (num_selected > 0 and dodelete) then
        local selected_nodes = ffi.new("int[?]",num_selected)
        ig.imnodes_GetSelectedNodes(selected_nodes);
        for i=0,num_selected-1 do
            editor:deleteNode(selected_nodes[i])
        end
    end

    ig.End();
    
    -- The color output window
    local color = (editor.root_node_id == -1) and ig.U32(1, 20/255, 147/255, 1) or editor:evaluate()
    ig.PushStyleColorU32(ig.lib.ImGuiCol_WindowBg, color);
    ig.Begin("output color");
    ig.End();
    ig.PopStyleColor();
end

local function Editor(name, nodetypes)
    local E = {nodes={},links={},current_id=0,name=name,root_node_id=-1, nodetypes= nodetypes}
    E.G = Graph()
    function E:evaluate()
        return self.G:DFS(self.root_node_id)
    end
    function E:newid()
        E.current_id = E.current_id + 1
        return E.current_id
    end
    function E:Node(value,typen)
        if self.root_node_id~=-1 and typen.is_root then return end
        local newnode = Node(value,self,typen)
        self.nodes[newnode.id] = newnode
        if typen.is_root then self.root_node_id = newnode.id end
        return newnode
    end
    function E:deleteNode(node_id)
        --delete links from this node
        local node = self.nodes[node_id]
        for _,link in pairs(self.links) do
            if node:hasLink(link) then
                self:deleteLink(link.id)
            end
        end
        node:delete() --delete pins in graph
        if node.type == "output" then self.root_node_id = -1 end
        self.nodes[node_id] = nil
    end
    function E:addLink(link)
        --only one link for input
        local dest = self.G.nodes[link.end_attr[0]].fromedges
        if #dest==0 then
            link.id = self:newid();
            self.links[link.id] = link
            self.G:insert_edge(link.start_attr[0],link.end_attr[0])
            return link
        end
    end
    function E:deleteLink(link_id)
        local link = self.links[link_id]
        self.G:delete_edge(link.start_attr[0],link.end_attr[0])
        self.links[link_id] = nil
    end
    E.draw = show_editor
    function E:free()
        ig.imnodes_EditorContextFree(self.context);
    end
    function E:save_str()
        local str = [[local ffi = require"ffi"]]
        str = str .. "\n" .. [[local ig = require"imgui.]] .. win.kind .. [["]]
        for k,node in pairs(self.nodes) do
            str = str .. node:save_str("node"..k) .. "\n"
        end
        str = str .. "return {nodes = {"
        for k,node in pairs(self.nodes) do
            local kst = type(k)=="number" and "["..k.."]" or k
            str = str .. kst .. "=" .. ("node"..k) .. ","
        end
        str = str .. "},links = {"
        for k,link in pairs(self.links) do
            local kst = type(k)=="number" and "["..k.."]" or k
            str = str .. kst .. "=" .. link:save_str() .. ","
        end
        str = str .. "},name='"..self.name
        str = str .. "',current_id = " .. self.current_id 
        str = str .. ",root_node_id = " .. self.root_node_id .. "}"
        return str
    end
    function E:save()
        local str = self:save_str()
        local file,err = io.open(self.name.."_saved","w")
        if not file then print(err);error"opening file" end
        file:write(str)
        file:close()
    end
    function E:load()
        local file,err = io.open(self.name.."_saved","r")
        if file then
            local str = file:read"*a"
            file:close()
            self:load_str(str)
        end
    end
    function E:load_str(str)
        self.nodes = {}
        self.links = {}
        local loadedE = loadstring(str)()
        for k,v in pairs(loadedE.nodes) do
            local node = Node(0,self,nil,v)
            self.nodes[node.id] = node
        end
        for k,v in pairs(loadedE.links) do
            local link = Link()
            link:loadT(v)
            self.links[link.id] = link
            self.G:insert_edge(link.start_attr[0],link.end_attr[0])
        end
        self.current_id = loadedE.current_id
        self.name = loadedE.name
        self.root_node_id = loadedE.root_node_id
    end
    E.context = ig.imnodes_EditorContextCreate();
    return E
end
-----------------------------------use it!!--------------------------------------------
ig.imnodes_Initialize()

local function clamp(v)
    return math.max(0,math.min(1,v))
end

local nodetypes = {
{   name = "add",
    input_names = {"lhs","rhs"},
    compute = function(t)
        return t[1] + t[2]
    end
},{
    name = "multiply",
    input_names = {"lhs","rhs"},
    compute = function(t)
        return t[1] * t[2]
    end
},{
    name = "output",
    input_names = {"r","g","b"},
    is_root = true,
    compute = function(t)
        local a,b,c = clamp(t[1]),clamp(t[2]),clamp(t[3])
        return ig.U32(a,b,c)
    end
},{
    name = "sine",
    input_names = {"input"},
    compute = function(t)
        return math.sin(t[1])
    end
},{
    name = "time",
    input_names = {},
    compute = function(t)
        return os.clock()
    end
}
}

local editor1 = Editor("color_editor", nodetypes)
editor1:load()

ig.imnodes_PushAttributeFlag(ig.lib.AttributeFlags_EnableLinkDetachWithDragClick);
local iog = ig.imnodes_GetIO();
local KeyCtrlPtr = ffi.cast("bool*", ffi.cast("char*",ig.GetIO()) + ffi.offsetof("ImGuiIO","KeyCtrl"))
iog.link_detach_with_modifier_click.modifier = KeyCtrlPtr --ig.lib.getIOKeyCtrlPtr();


function win:draw(ig)
    editor1:draw()
    --ig.ShowDemoWindow()
end

local function clean()
    editor1:save()
    ig.imnodes_PopAttributeFlag();
    editor1:free()
    ig.imnodes_Shutdown()
end

win:start(clean)