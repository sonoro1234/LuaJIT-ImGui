local igwin = require"imgui.window"

--local win = igwin:SDL(800,400, "widgets",{vsync=true,use_imnodes=true})
local win = igwin:GLFW(800,400, "widgets",{vsync=true,use_imnodes=true})


function win:draw(ig)
    ig.Begin("node editor")
    ig.imnodes_BeginNodeEditor();
    ig.imnodes_BeginNode(1);
    ig.imnodes_BeginNodeTitleBar();
    ig.TextUnformatted("output node");
    ig.imnodes_EndNodeTitleBar();
    ig.imnodes_BeginInputAttribute(2);
    ig.Text("input pin");
    ig.imnodes_EndInputAttribute();
    ig.imnodes_BeginOutputAttribute(3);
    ig.Indent(40)
    ig.Text("output pin");
    ig.imnodes_EndOutputAttribute();
    ig.imnodes_EndNode();
    ig.imnodes_EndNodeEditor();
    ig.End()
end

win:start()