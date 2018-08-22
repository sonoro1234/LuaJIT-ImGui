-----------------------------------------------
-- script to build lua classes
-- expects lua 5.1 or luajit
-- expects "../cimgui/generator/definitions.lua" to be generated in cimgui (master_auto2 branch)
-----------------------------------------------

--load function definitions
local dir = [[../cimgui/generator/generated/]]
local fundefs = dofile(dir..[[definitions.lua]])

--clean nonUDT functions
for fun,defs in pairs(fundefs) do
	for i,def in ipairs(defs) do
		if def.nonUDT then
			table.remove(defs,i)
		end
	end
end


--group them by structs
local structs = {}
for fun,defs in pairs(fundefs) do
	local stname = defs[1].stname
	structs[stname] = structs[stname] or {}
	table.insert(structs[stname],fun)
end
structs.ImVec4 = nil



--[[ tests
require"anima.utils" --gives us prtable
-- prtable(structs.ImFontConfig)
-- prtable(fundefs.igCombo)
local defaults = {}
for fun,defs in pairs(fundefs) do
	for i,def in ipairs(defs) do
		for k,v in pairs(def.defaults) do
			defaults[v]=true
		end
	end
end
prtable(defaults)
do return end
--]]

--test correctness of generated lua code
local function testcode(codestr,code)
	local fl,err = loadstring(codestr)
	if not fl then
		print"--error codestr--------------------"
		print(codestr)
		print"--end error codestr--------------------"
		local linenum = err:match(":(%d+):")
		linenum = tonumber(linenum)
		print("error on:",linenum,code[linenum])
		for i=-2,2 do
			print("error on:",linenum+i,code[linenum+i])
		end
		error(err)
	end
end

--this replaces reserved lua words and not valid tokens
function sanitize_reserved(def)
	local words = {["in"]="_in",["repeat"]="_repeat"}
	for k,w in pairs(words) do
		local pat = "([%(,])("..k..")([,%)])"
		if def.call_args:match(pat) then
			--print("found",def.cimguiname,def.call_args,def.call_args:match(pat))
			def.call_args = def.call_args:gsub(pat,"%1"..w.."%3")
			--print(def.call_args)
			--sanitize defaults
			if def.defaults[k] then
				def.defaults[w] = def.defaults[k]
				def.defaults[k] = nil
			end
		end
	end
	--correct default vals
	for k,v in pairs(def.defaults) do
		--do only if not a c string
		local is_cstring = v:sub(1,1)=='"' and v:sub(-1,-1) =='"'
		if not is_cstring then
			--numbers without f in the end
			def.defaults[k] = v:gsub("([%d%.%-]+)f","%1")
			--+ in front of numbers
			def.defaults[k] = def.defaults[k]:gsub("^%+([%d%.%-]+)","%1")
			--FLT_MAX
			def.defaults[k] = def.defaults[k]:gsub("3%.40282346638528859812e%+38F","M.FLT_MAX")
			def.defaults[k] = def.defaults[k]:gsub("ImDrawCornerFlags_All","lib.ImDrawCornerFlags_All")
			def.defaults[k] = def.defaults[k]:gsub("sizeof%((%w+)%)",[[ffi.sizeof("%1")]])
			def.defaults[k] = def.defaults[k]:gsub("%(%(void %*%)0%)","nil")
		end
	end
end

--struct function generator
local function struct_function_gen(code,def)
	sanitize_reserved(def)
	local fname = def.ov_cimguiname or def.cimguiname --overloaded or original
	local fname_m = fname:match("_(.*)") --drop struct name part
	--add self to args
	local empty = def.call_args:match("^%(%)") --no args
	local args = def.call_args:gsub("^%(","(self"..(empty and "" or ","))
	--end is reserved in lua so make it _end
	if fname_m == "end" then fname_m = "_end" end
	--dump function code
	table.insert(code,"function " .. def.stname .. ":" .. fname_m .. def.call_args)
	--set defaults
	for k,v in pairs(def.defaults) do
		table.insert(code,"    "..k.." = "..k.." or "..v)
	end
	--call cimgui
	table.insert(code,"    return lib."..fname..args)
	table.insert(code,"end")
end


--top level function generator (ImGui namespace)
local function function_gen(code,def)
	sanitize_reserved(def)
	local fname = def.ov_cimguiname or def.cimguiname --overloaded or original
	local fname_m = fname:match("^ig(.*)") --drop struct name part
	--end is reserved in lua so make it _end
	if fname_m == "end" then fname_m = "_end" end
	--dump function code
	table.insert(code,"function M." .. fname_m .. def.call_args)
	--set defaults
	for k,v in pairs(def.defaults) do
		table.insert(code,"    "..k.." = "..k.." or "..v)
	end
	--call cimgui
	table.insert(code,"    return lib."..fname..def.call_args)
	table.insert(code,"end")
end

--struct code generator
local function code_for_struct(st)
	local funs = structs[st]
	table.sort(funs)
	local code = {}
	table.insert(code,"--------------------------"..st.."----------------------------")
	--declare struct
	table.insert(code,"local "..st.."= {}")
	table.insert(code,st..".__index = "..st)
	for _,f in ipairs(funs) do
		local defs = fundefs[f]
		for _,def in ipairs(defs) do
			if def.ret then --avoid constructors and destructors
				struct_function_gen(code,def)
			end
		end
	end
	table.insert(code,[[M.]]..st..[[ = ffi.metatype("]]..st..[[",]]..st..")")
	local codestr = table.concat(code,"\n")
	--test correctness of code
	testcode(codestr,code)
	return codestr
end

--ImGui namespace generator
local function code_for_imguifuns(st)
	local funs = structs[st]
	table.sort(funs)
	local code = {}
	table.insert(code,"--------------------------"..st.."----------------------------")

	for _,f in ipairs(funs) do
		local defs = fundefs[f]
		for _,def in ipairs(defs) do
			def.stname = "M"
			function_gen(code,def)
		end
	end
	local codestr = table.concat(code,"\n")
	--test correctness of code
	testcode(codestr,code)
	return codestr
end

--Do generation
print("----------BEGIN_AUTOGENERATED_LUA---------------------------")
for struct,funs in pairs(structs) do
	if struct ~= "ImGui" and struct ~= "ImVec2" and struct ~="ImFontConfig" and struct ~= "" then
		print(code_for_struct(struct))
	end
end
print(code_for_imguifuns("ImGui"))

print("return M")
print("----------END_AUTOGENERATED_LUA-----------------------------")


