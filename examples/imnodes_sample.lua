local igwin = require"imgui.window"

--local win = igwin:SDL(800,400, "widgets",{vsync=true})
local win = igwin:GLFW(800,400, "widgets",{vsync=true})
local ig = win.ig
local ffi = require"ffi"


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

local function Node(value,editor)
    local node = {
        id = editor:newid(),
        input_id = editor:newid(),
        output_id = editor:newid(),
        static_id = editor:newid(),
        value = ffi.new("float[?]",1,value)
    }
    function node:hasLink(link)
        return link.start_attr[0] == self.output_id or link.end_attr[0] == self.input_id 
    end
    function node:save_str()
        local str = "{"
        for k,v in pairs(self) do
            if type(v)=="number" then
                str = str .. k .. "=" .. v ..","
            elseif type(v) == "cdata" then
                str = str .. k .. "=" .. v[0] ..","
            end
        end
        local pos = ig.imnodes_GetNodeGridSpacePos(self.id)
        str = str .. " pos = {" .. pos.x .. "," .. pos.y .. "}"
        str = str .. "}"
        return str
    end
    function node:loadT(t)
        for k,v in pairs(t) do
            if type(self[k]) == "cdata" then
                self[k][0] = v
            else
                self[k] = v
            end
        end
    end
    function node:draw()
        if self.pos then -- for reset position of saved and loaded node
            --print("self.pos",self.id,self.pos[1],self.pos[2])
            ig.imnodes_SetNodeGridSpacePos(self.id, ig.ImVec2(self.pos[1],self.pos[2]));
            self.pos = nil
        end
        ig.imnodes_BeginNode(node.id);
        ig.imnodes_BeginNodeTitleBar();
        ig.TextUnformatted("node");
        ig.imnodes_EndNodeTitleBar();

        ig.imnodes_BeginInputAttribute(node.input_id)
        ig.TextUnformatted("input");
        ig.imnodes_EndInputAttribute();

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
    ig.SameLine()
    local enab = ffi.new("bool[1]",ig.imnodes_GetIO().emulate_three_button_mouse.enabled)
    ig.Checkbox("emulate three button mouse",enab)
    ig.imnodes_GetIO().emulate_three_button_mouse.enabled = enab[0]
    --[[
    ig.SameLine()
    if ig.SmallButton("save") then
       local str = editor:save_str()
       print(str)
       editor:load_str(str)
    end
    --]]
    ig.TextUnformatted("A -- add node");
    ig.TextUnformatted("X -- delete selected node or link");
    ig.imnodes_BeginNodeEditor();

    local user_key = ig.GetKeyIndex(ig.lib.ImGuiKey_A)
    if (ig.IsWindowFocused(ig.lib.ImGuiFocusedFlags_RootAndChildWindows) and
        ig.imnodes_IsEditorHovered() and ig.IsKeyReleased(user_key))
    then
        local newnode = editor:Node(0)
        ig.imnodes_SetNodeScreenSpacePos(newnode.id, ig.GetMousePos());
    end


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
local function Editor(name)
    local E = {nodes={},links={},current_id=0,name=name}
    function E:newid()
        E.current_id = E.current_id + 1
        return E.current_id
    end
    function E:Node(value)
        local newnode = Node(value,self)
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
        local str = "return {nodes = {"
        for k,node in pairs(self.nodes) do
            local kst = type(k)=="number" and "["..k.."]" or k
            str = str .. kst .. "=" .. node:save_str() .. ","
        end
        str = str .. "},links = {"
        for k,link in pairs(self.links) do
            local kst = type(k)=="number" and "["..k.."]" or k
            str = str .. kst .. "=" .. link:save_str() .. ","
        end
        str = str .. "},name='"..self.name.."',current_id = " .. self.current_id .. "}"
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
            local node = Node(0,self)
            node:loadT(v)
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
ig.imnodes_Initialize()

local editor1 = Editor"editor1"
local editor2 = Editor"editor2"
editor1:load()
editor2:load()

ig.imnodes_PushAttributeFlag(ig.lib.AttributeFlags_EnableLinkDetachWithDragClick);
local iog = ig.imnodes_GetIO();
iog.link_detach_with_modifier_click.modifier = ig.lib.getIOKeyCtrlPtr();


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
    ig.imnodes_Shutdown()
end

win:start(clean)