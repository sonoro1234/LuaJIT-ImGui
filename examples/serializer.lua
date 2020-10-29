
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

local function SerializeTable(name, value, saved)
    
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

return SerializeTable