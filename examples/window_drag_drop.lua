
local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "drag and drop",{gl2=false})
local win = igwin:GLFW(800,400, "drag and drop",{gl2=false})

local butnum = {} 
for i=1,16 do butnum[i] = i end
local anchor ={}

local ffi = require"ffi"
function win:draw(ig)
    for i = 1,16 do
    
        ig.Button("but"..butnum[i].."###"..i, ig.ImVec2(50,50))
    
        if ig.BeginDragDropSource() then
            anchor.data = ffi.new("int[1]",i)
            ig.SetDragDropPayload("ITEMN",anchor.data, ffi.sizeof"int")--, C.ImGuiCond_Once);
            ig.Button("drag"..butnum[i], ig.ImVec2(50,50));
            ig.EndDragDropSource();
        end
        if ig.BeginDragDropTarget() then
            local payload = ig.AcceptDragDropPayload("ITEMN")
            if (payload~=nil) then
                assert(payload.DataSize == ffi.sizeof"int");
                local num = ffi.cast("int*",payload.Data)[0]
                local tmp = butnum[num]
                table.remove(butnum,num)
                table.insert(butnum, i,tmp)
            end
            ig.EndDragDropTarget();
        end
        if (((i-1) % 4) < 3) then ig.SameLine() end
    end

end

win:start()