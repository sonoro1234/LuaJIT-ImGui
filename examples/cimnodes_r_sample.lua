local igwin = require"imgui.window"

--local win = igwin:SDL(800,400, "widgets",{vsync=true})
local win = igwin:GLFW(800,400, "widgets",{vsync=true})
local ig = win.ig
local ffi = require"ffi"

----------------------------serialization
local function cdataSerialize(cd)
    if ffi.istype("float[1]", cd) then
        return table.concat{[[ffi.new('float[1]',]],cd[0],[[)]]}
    elseif ffi.istype("int[1]", cd) then
        return table.concat{[[ffi.new('int[1]',]],cd[0],[[)]]}
    elseif ffi.istype("bool[1]", cd) then
        return table.concat{[[ffi.new('bool[1]',]],tostring(cd[0]),[[)]]}
    elseif ffi.istype("float[]",cd) then
        local size = ffi.sizeof(cd)/ffi.sizeof"float"
        local tab = {[[ffi.new("float[?]",]],size}
        for i=0,size-1 do tab[#tab+1] = ",";tab[#tab+1] = cd[i] end
        tab[#tab+1] = [[)]]
        return table.concat(tab)
    elseif ffi.istype("void*",cd) then
        return table.concat{[[ffi.cast('void*',]],tonumber(ffi.cast("uintptr_t",cd)),[[)]]}
    elseif ffi.istype("void*[1]",cd) then
        return table.concat{[[ffi.new('void*[1]',ffi.cast('void*',]],tonumber(ffi.cast("uintptr_t",cd[0])),[[))]]}
    elseif ffi.istype("const char*[1]",cd) then
        return table.concat{[[ffi.new('const char*[1]',{']],ffi.string(cd[0]),[['})]]}
    elseif ffi.istype("SlotInfo[]",cd) then
        local size = ffi.sizeof(cd)/ffi.sizeof"SlotInfo"
        local tab = {[[ffi.new("SlotInfo[?]",]],size,",{"}
        for i=0,size-1 do
            tab[#tab+1]="{'"
            tab[#tab+1]= ffi.string(cd[i].title)
            tab[#tab+1]= "',"
            tab[#tab+1]= cd[i].kind
            tab[#tab+1]= "},"
        end
        tab[#tab+1] = "})"
        return table.concat(tab)
    elseif ffi.istype("ImVec2",cd) then
        return table.concat{[[ig.ImVec2(]],cd.x,",",cd.y,")"}
    else
        print(cd,"not serialized")
        error"serialization error"
    end
end

local function basicSerialize (o)
    if type(o) == "number" then
        return string.format("%.17g", o)
    elseif type(o)=="boolean" then
        return tostring(o)
    elseif type(o) == "string" then
        return string.format("%q", o)
    elseif type(o)=="cdata" then
        return cdataSerialize(o)
    else
        return tostring(nil) --"nil"
    end
end

function SerializeTable(name, value, saved)
    
    local string_table = {}
    if not saved then 
        table.insert(string_table, "local "..name.." = ") 
    else
        table.insert(string_table, name.." = ") 
    end
    
    saved = saved or {}       -- initial value
    
    if type(value)~= "table" then
        table.insert(string_table,basicSerialize(value).."\n")
    elseif type(value) == "table" then
        if saved[value] then    -- value already saved?
            table.insert(string_table,saved[value].."\n")          
        else
            saved[value] = name   -- save name for next time
            table.insert(string_table, "{}\n")          
            for k,v in pairs(value) do      -- save its fields
                local fieldname = string.format("%s[%s]", name,basicSerialize(k))
                table.insert(string_table, SerializeTable(fieldname, v, saved))
            end
        end
    end
    
    return table.concat(string_table)
end
--------------------------------------

local function Connection()
    local link = {
        input_node=ffi.new("void*[1]"),
        input_slot=ffi.new("const char*[1]"),
        output_node=ffi.new("void*[1]"),
        output_slot=ffi.new("const char*[1]")
    }
    return link
end
local function idtokey(v)
    return tonumber(ffi.cast("uintptr_t",v))
end
local function Node(value,editor,typen,loadT)
    local node
    if not loadT then
    node = {
        id = ffi.cast("void*",editor:newid()),
        pos = ig.ImVec2(20,20),
        selected = ffi.new"bool[1]",
        title = "node",
        nins = 1,
        nouts = 1
    }
    local ins = {{"input1",1},{"input2",2}}
    local outs = {{"output1",1},{"output2",2}}
    node.nins = #ins
    node.nouts = #outs
    node.input_slots = ffi.new("SlotInfo[?]",node.nins,ins)
    node.output_slots = ffi.new("SlotInfo[?]",node.nouts,outs)
    node.connections = {}
    else
        node = loadT
    end
    
    function node:delete_connection(conn)
        for i,c in ipairs(self.connections) do
            if c.input_node==conn.input_node and
            c.input_slot==conn.input_slot and
            c.output_node==conn.output_node and
            c.output_slot==conn.output_slot then
                table.remove(self.connections,i)
                return
            end
        end
    end
    function node:save_str(name)
        return SerializeTable(name,self)
    end
    function node:draw()

        if ig.ImNodes_Ez_BeginNode(node.id,node.title,node.pos,node.selected) then

            ig.ImNodes_Ez_InputSlots(node.input_slots, node.nins);
            ig.Text("Content of %s", node.title);
            ig.ImNodes_Ez_OutputSlots(node.output_slots, node.nouts);
            
            local conn = Connection()
            if (ig.ImNodes_GetNewConnection(conn.input_node, conn.input_slot, conn.output_node, conn.output_slot)) then
                table.insert(editor.nodes[idtokey(conn.input_node[0])].connections,conn)
                table.insert(editor.nodes[idtokey(conn.output_node[0])].connections,conn)
                print(ffi.string(conn.input_slot[0]))
            end
            
            for i,conn in ipairs(node.connections) do
                --print(conn.output_node[0] ,node.id)
                if conn.output_node[0] == node.id then
                    if not ig.ImNodes_Connection(conn.input_node[0], conn.input_slot[0], conn.output_node[0], conn.output_slot[0]) then
                        editor.nodes[idtokey(conn.input_node[0])]:delete_connection(conn)
                        editor.nodes[idtokey(conn.output_node[0])]:delete_connection(conn)
                    end
                end
            end
        end
        ig.ImNodes_Ez_EndNode();
        
        local dodelete = false
        local user_key = ig.GetKeyIndex(ig.lib.ImGuiKey_X)
        if ig.IsWindowFocused(ig.lib.ImGuiFocusedFlags_RootAndChildWindows) and ig.IsKeyReleased(user_key)
        then
            dodelete = true
        end
        if node.selected[0] and dodelete then
            for i,conn in ipairs(node.connections) do
                if conn.output_node[0] == node.id then
                    editor.nodes[idtokey(conn.input_node[0])]:delete_connection(conn)
                else
                    editor.nodes[idtokey(conn.output_node[0])]:delete_connection(conn)
                end
            end
            node.connections = {}
            editor.nodes[idtokey(node.id)] = nil
        end
    end
    return node
end

local function show_editor(editor)
    
    ig.Begin(editor.name);
    if ig.SmallButton("dump") then
        print"---------dump-----------------"
        for k,node in pairs(editor.nodes) do
            print("node",k,node.id,editor.nodes[k].id)
        end
        print("current_id",editor.current_id)
    end

    ig.TextUnformatted("A -- add node");
    ig.TextUnformatted("X -- delete selected node or link");

    ig.ImNodes_BeginCanvas(editor.context);

    for _, node in pairs(editor.nodes) do
        node:draw()
    end
    
    local user_key = ig.GetKeyIndex(ig.lib.ImGuiKey_A)
    if (ig.IsWindowFocused(ig.lib.ImGuiFocusedFlags_RootAndChildWindows) and ig.IsKeyReleased(user_key))
    then
        local newnode = editor:Node(0)
        newnode.pos = ig.GetMousePos()  - ig.GetWindowPos()
    end
    ig.ImNodes_EndCanvas()
    ig.End();
end
local function Editor(name)
    local E = {nodes={},current_id=0,name=name}
    function E:newid()
        E.current_id = E.current_id + 1
        return E.current_id
    end
    function E:Node(value)
        local newnode = Node(value,self)
        self.nodes[idtokey(newnode.id)] = newnode
        return newnode
    end
    
    E.draw = show_editor

    function E:save_str()
        local str = [[local ffi = require"ffi"]]
        str = str .. "\n" .. [[local ig = require"imgui.]] .. win.kind .. [["
        ]]
        for k,node in pairs(self.nodes) do
            str = str .. node:save_str("node"..k) .. "\n"
        end
        str = str .. "return {nodes = {"
        for k,node in pairs(self.nodes) do
            local kst = type(k)=="number" and "["..k.."]" or k
            str = str .. kst .. "=" .. ("node"..k) .. ","
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
        local loadedE = loadstring(str)()
        for k,v in pairs(loadedE.nodes) do
            local node = Node(0,self,nil,v)
            self.nodes[idtokey(node.id)] = node
        end
        self.current_id = loadedE.current_id
        self.name = loadedE.name
    end
    E.context = ig.CanvasState();
    return E
end
--------------------------------------------------------------------------------------------


local editor1 = Editor"editor1_r"
editor1:load()

function win:draw(ig)
    editor1:draw()
end

local function clean()
  editor1:save()
end

win:start(clean)