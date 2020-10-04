local igwin = require"imgui.window"

--local win = igwin:SDL(800,400, "widgets",{vsync=true,use_imnodes=true})
local win = igwin:GLFW(800,400, "widgets",{vsync=true})
local ig = win.ig
local ffi = require"ffi"

ig.imnodes_Initialize()

local function Link()
    return {id=0,start_attr=ffi.new("int[?]",1),end_attr=ffi.new("int[?]",1)}
end
local function Editor()
    local E = {nodes={},links={},current_id=0}
    function E:newid()
        E.current_id = E.current_id + 1
        return E.current_id
    end
    function E:Node(value)
        local newnode = {
            id = self:newid(),
            input_id = self:newid(),
            output_id = self:newid(),
            static_id = self:newid(),
            value=ffi.new("float[?]",1,value)
        }
        table.insert(self.nodes,newnode)
        return newnode
    end
    function E:addLink(link)
        link.id = self:newid();
        self.links[link.id] = link
    end
    E.context = ig.imnodes_EditorContextCreate();
    return E
end

local function show_editor(editor_name,editor)
    ig.imnodes_EditorContextSet(editor.context);

    ig.Begin(editor_name);
    ig.TextUnformatted("A -- add node");

    ig.imnodes_BeginNodeEditor();

    local user_key = ig.GetKeyIndex(ig.lib.ImGuiKey_A)
    if (ig.IsWindowFocused(ig.lib.ImGuiFocusedFlags_RootAndChildWindows) and
        ig.imnodes_IsEditorHovered() and ig.IsKeyReleased(user_key))
    then
        local newnode = editor:Node(0)
        ig.imnodes_SetNodeScreenSpacePos(newnode.id, ig.GetMousePos());
    end


    for _, node in ipairs(editor.nodes) do
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
    
    for _, link in pairs(editor.links) do
        ig.imnodes_Link(link.id, link.start_attr[0], link.end_attr[0]);
    end

    ig.imnodes_EndNodeEditor();

    local link = Link()
    if (ig.imnodes_IsLinkCreated(link.start_attr, link.end_attr, ffi.new("bool[1]"))) then
        editor:addLink(link)
    end


    local link_id = ffi.new("int[?]",1)
    if (ig.imnodes_IsLinkDestroyed(link_id)) then
        editor.links[link_id[0]] = nil
    end


    ig.End();
end

local editor1 = Editor()
local editor2 = Editor()

ig.imnodes_PushAttributeFlag(ig.lib.AttributeFlags_EnableLinkDetachWithDragClick);
local iog = ig.imnodes_GetIO();
iog.link_detach_with_modifier_click.modifier = ig.lib.getIOKeyCtrlPtr();

function win:draw(ig)
    show_editor("editor1", editor1);
    show_editor("editor2", editor2);
end

local function clean()
    ig.imnodes_PopAttributeFlag();
    ig.imnodes_EditorContextFree(editor1.context);
    ig.imnodes_EditorContextFree(editor2.context);
    ig.imnodes_Shutdown()
end

win:start(clean)