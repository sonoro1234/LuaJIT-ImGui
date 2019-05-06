-----------------------------------------------
-- script to build lua classes
-- expects lua 5.1 or luajit
-- expects "../cimgui/generator/definitions.lua" to be generated in cimgui (master_auto2 branch)
-----------------------------------------------
--utility functions
function strsplit(str, pat)
    local t = {} 
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
        table.insert(t,cap)
        last_end = e+1
        s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    elseif str:sub(-1)==pat then
        table.insert(t, "")
    end
    return t
end
function deleteOuterPars(def)
	local w = def:match("^%b()$")
	if w then
		w = w:gsub("^%((.+)%)$","%1")
		return w
	else 
		return def 
	end
end
function CleanImU32(def)
	def = def:gsub("%(ImU32%)","")
	--quitar () de numeros
	def = def:gsub("%((%d+)%)","%1")
	def = deleteOuterPars(def)
	local bb=strsplit(def,"|")
	for i=1,#bb do
		local val = deleteOuterPars(bb[i])
		if val:match"<<" then
			local v1,v2 = val:match("(%d+)%s*<<%s*(%d+)")
			val = v1*2^v2
			bb[i] = val
		end
		assert(type(bb[i])=="number")
	end
	local res = 0 
	for i=1,#bb do res = res + bb[i] end 
	return res
end
-------------------------------------------------
--load function definitions
local dir = [[../cimgui/generator/output/]]
local fundefs = dofile(dir..[[definitions.lua]])

--group them by structs
local structs = {}
for fun,defs in pairs(fundefs) do
	local stname = defs[1].stname
	structs[stname] = structs[stname] or {}
	table.insert(structs[stname],fun)
end
structs.ImVec4 = nil
structs.ImVector = nil



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
		print("error is ",err)
		error("error in testcode",2)
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
			def.defaults[k] = def.defaults[k]:gsub("FLT_MAX","M.FLT_MAX")
			def.defaults[k] = def.defaults[k]:gsub("ImDrawCornerFlags_All","lib.ImDrawCornerFlags_All")
			def.defaults[k] = def.defaults[k]:gsub("sizeof%((%w+)%)",[[ffi.sizeof("%1")]])
			def.defaults[k] = def.defaults[k]:gsub("%(%(void%s*%*%)0%)","nil")
			if def.defaults[k]:match"%(ImU32%)" then
				def.defaults[k] = CleanImU32(def.defaults[k])
			end
		end
	end
end

local function make_function(method,def)
	sanitize_reserved(def)
	local fname = def.ov_cimguiname or def.cimguiname --overloaded or original
	local fname_m = method and fname:match(def.stname.."_(.*)") or fname:match("^ig(.*)") --drop struct name part
	fname_m = fname_m:match("(.*)_nonUDT$") or fname_m --drop "_nonUDT" suffix
	if fname_m == "end" then fname_m = "_end" end
	--dump function code
	if def.nonUDT == 1 or next(def.defaults) then
		local code = {}
		local args, fname_lua
		local empty = def.call_args:match("^%(%)") --no args
		if method then
			args = def.call_args:gsub("^%(","(self"..(empty and "" or ","))
			fname_lua = def.stname..":"..fname_m
			empty = false
		else
			args = def.call_args
			fname_lua = "M."..fname_m
		end
		table.insert(code,"function "..fname_lua..def.call_args)
		--set defaults
		for k,v in pairs(def.defaults) do
			if v == 'true' then
				table.insert(code,"    if "..k.." == nil then "..k.." = "..v.." end")
			else
				table.insert(code,"    "..k.." = "..k.." or "..v)
			end
		end
		if def.nonUDT == 1 then
			--allocate variable for return value
			local out_type = def.argsT[1].type:gsub("*", "[1]")
			table.insert(code,'    local nonUDT_out = ffi.new(\"'..out_type..'")')
			--prepend nonUDT_out to args
			args = args:gsub("%(", "(nonUDT_out" .. (empty and "" or ","), 1)
			--call cimgui and return value of out variable
			table.insert(code,"    lib."..fname..args)
			table.insert(code,"    return nonUDT_out[0]")
		else
			--call cimgui
			table.insert(code,"    return lib."..fname..args)
		end
		table.insert(code,"end")
		return table.concat(code,"\n")
	end
	return (method and def.stname or "M").."."..fname_m.." = lib."..fname
end

--struct constructor generator
local function constructor_gen(code,def)
	sanitize_reserved(def)
	--dump function code
	if def.cimguiname == def.ov_cimguiname then --default constructor
		local args = (def.call_args == "()") and "(ctype)" or "(ctype,"..def.call_args:sub(2)
		table.insert(code,"function "..def.stname..".__new"..args)
	else
		local name = def.ov_cimguiname:match(def.stname.."_(.*)") --drop struct name part
		table.insert(code,"function "..def.stname.."."..name..def.call_args)
	end
	--set defaults
	for k,v in pairs(def.defaults) do
		table.insert(code,"    if "..k.." == nil then "..k.." = "..v.." end")
	end
	local fname = def.ov_cimguiname or def.cimguiname
	table.insert(code,"    local ptr = lib."..fname..def.call_args)
	table.insert(code,"    return ffi.gc(ptr,lib."..def.stname.."_destroy)")
	table.insert(code,"end")
end

--struct function generator
local function struct_function_gen(code,def)
	table.insert(code,make_function(true,def))
end

--top level function generator (ImGui namespace)
local function function_gen(code,def)
	table.insert(code,make_function(false,def))
end

local function find_nonudt_def(defs,name)
	for _,def in ipairs(defs) do
		if def.nonUDT == 1 then
			local fname = def.ov_cimguiname or def.cimguiname
			if fname:sub(1,#name) == name then
				return def
			end
		end
	end
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
			if not def.destructor then
				if def.constructor then
					constructor_gen(code,def)
				else
					if def.nonUDT ~= 1 then
						local fname = def.ov_cimguiname or def.cimguiname
						--prefer nonUDT1 defs
						local nonudt_def = find_nonudt_def(defs,fname)
						struct_function_gen(code,nonudt_def or def)
					end
				end
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
			if def.nonUDT ~= 1 then
				def.stname = "M"
				local fname = def.ov_cimguiname or def.cimguiname
				--prefer nonUDT1 defs
				local nonudt_def = find_nonudt_def(defs,fname)
				function_gen(code,nonudt_def or def)
			end
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
	if struct ~= "ImGui" and struct ~= "ImVec2" and struct ~= "" then
		print(code_for_struct(struct))
	end
end
print(code_for_imguifuns(""))--("ImGui"))

print("return M")
print("----------END_AUTOGENERATED_LUA-----------------------------")


