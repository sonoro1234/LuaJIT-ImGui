local igwin = require"imgui.window"

--local win = igwin:SDL(800,400, "widgets",{vsync=true})
local win = igwin:GLFW(800,400, "widgets",{vsync=true})

local ig = win.ig
local ffi = require"ffi"
local serializer = require"serializer"

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
            title = typen.name,
            output_id = editor:newid(),
            static_id = editor:newid(),
            value = ffi.new("float[?]",1,value)
        }
        node.inputs = {}
        node.input_names = {}
        for i,iname in ipairs(typen.input_names) do
            node.inputs[i] = editor:newid()
            node.input_names[i] = iname
        end
    else
        node = loadT
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
        ig.TextUnformatted(node.title);
        ig.imnodes_EndNodeTitleBar();

        for i, input_id in ipairs(node.inputs) do
            ig.imnodes_BeginInputAttribute(input_id)
            ig.TextUnformatted(node.input_names[i]);
            ig.imnodes_EndInputAttribute();
        end

        ig.imnodes_BeginStaticAttribute(node.static_id)
        ig.PushItemWidth(120.0);
        ig.DragFloat("value", node.value, 0.01);
        ig.PopItemWidth();
        ig.imnodes_EndStaticAttribute();

        ig.imnodes_BeginOutputAttribute(node.output_id)
        local text_width = ig.CalcTextSize("output").x;
        ig.Indent(120. + ig.CalcTextSize("value").x - text_width);
        ig.TextUnformatted("output");
        ig.imnodes_EndOutputAttribute();

        ig.imnodes_EndNode();
    end
    return node
end

local function show_editor(editor)
    ig.imnodes_EditorContextSet(editor.context);

    ig.Begin(editor.name);
    if ig.SmallButton("dump") then
        print"---------dump-----------------"
        for k,node in pairs(editor.nodes) do
            print("node",k,node.id,node.input_id,node.output_id)
        end
        for k,link in pairs(editor.links) do
            print("link",k,link.id,link.start_attr[0],link.end_attr[0])
        end
        print("current_id",editor.current_id)
    end

    ig.TextUnformatted("A -- add node");
    ig.TextUnformatted("X -- delete selected node or link");
    ig.imnodes_BeginNodeEditor();

    local user_key = ig.lib.ImGuiKey_A
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
                ig.imnodes_SetNodeScreenSpacePos(newnode.id, ig.GetMousePos());             
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
    ig.imnodes_MiniMap()
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
    local user_key = ig.lib.ImGuiKey_X
    if ig.IsWindowFocused(ig.lib.ImGuiFocusedFlags_RootAndChildWindows) and
        --ig.imnodes_IsEditorHovered() and 
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
end
local function Editor(name, nodetypes)
    local E = {nodes={},links={},current_id=0,name=name,nodetypes = nodetypes}
    function E:newid()
        E.current_id = E.current_id + 1
        return E.current_id
    end
    function E:Node(value,typen)
        local newnode = Node(value,self,typen)
        self.nodes[newnode.id] = newnode
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
        self.nodes[node_id] = nil
    end
    function E:addLink(link)
        link.id = self:newid();
        self.links[link.id] = link
        return link
    end
    function E:deleteLink(link_id)
        self.links[link_id] = nil
    end
    E.draw = show_editor
    function E:free()
        ig.imnodes_EditorContextFree(self.context);
    end
    function E:save_str()
        local str = [[local ffi = require"ffi"]]
        str = str .. "\n"
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
        str = str .. "}"
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
        local f,err = loadstring(str)
		assert(f,err)
        setfenv(f,setmetatable({ig=ig},{ __index = _G}))
        local loadedE = f()
        for k,v in pairs(loadedE.nodes) do
            local node = Node(0,self,nil,v)
            self.nodes[node.id] = node
        end
        for k,v in pairs(loadedE.links) do
            local link = Link()
            link:loadT(v)
            self.links[link.id] = link
        end
        self.current_id = loadedE.current_id
        self.name = loadedE.name
    end
    E.context = ig.imnodes_EditorContextCreate();
    return E
end
--------------------------------------------------------------------------------------------
ig.imnodes_CreateContext()

local nodetypes = {
    {   name = "node_t1",
        input_names = {"input_t1","input_t2"}
    },
    {   name = "node_t2",
        input_names = {"lhs","rhs"}
    }
}

local editor1 = Editor("editor1",nodetypes)
local editor2 = Editor("editor2",nodetypes)
editor1:load()
editor2:load()

ig.imnodes_PushAttributeFlag(ig.lib.ImNodesAttributeFlags_EnableLinkDetachWithDragClick);
local iog = ig.imnodes_GetIO();
local KeyCtrlPtr = ffi.cast("bool*", ffi.cast("char*",ig.GetIO()) + ffi.offsetof("ImGuiIO","KeyCtrl"))
iog.LinkDetachWithModifierClick.Modifier = KeyCtrlPtr --ig.lib.getIOKeyCtrlPtr();
iog.EmulateThreeButtonMouse.Modifier = KeyCtrlPtr

function win:draw(ig)
    editor1:draw()
    editor2:draw()
end

local function clean()
    editor1:save()
    editor2:save()
    ig.imnodes_PopAttributeFlag();
    editor1:free()
    editor2:free()
    ig.imnodes_DestroyContext()
end

win:start(clean)