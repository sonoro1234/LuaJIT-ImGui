-----------------------------------------------
-- script to build lua classes
-- expects lua 5.1 or luajit
-- expects "../cimgui/generator/definitions.lua" to be generated in cimgui (master_auto2 branch)
-----------------------------------------------
package.path = package.path.."../cimgui/generator/?.lua"
local cpp2ffi = require"cpp2ffi"
local ffi = require"ffi"
--utility functions
local ffi_cdef = function(code)
    local ret,err = pcall(ffi.cdef,code)
    if not ret then
        local lineN = 1
        for line in code:gmatch("([^\n\r]*)\r?\n") do
            print(lineN, line)
            lineN = lineN + 1
        end
        print(err)
        error"bad cdef"
    end
end
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
-------------------------------------------------
local enumsvalues = {}



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
local function testcode(codestr)
	local fl,err = loadstring(codestr)
	if not fl then
		local linenum = err:match(":(%d+):")
		linenum = tonumber(linenum)
		--print("error on:",linenum,code[linenum])
		local lineN,codelines = 1,{}
        for line in codestr:gmatch("([^\n\r]*)\r?\n") do
            print(lineN, line)
			table.insert(codelines, line)
            lineN = lineN + 1
        end
		print("error is ",err)
		print("in line: ", codelines[linenum])
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
		--if type(v)=="number" then print("aver",def.cimguiname,type(v),k,v) end
		--do only if not a c string
		local is_cstring = v:sub(1,1)=='"' and v:sub(-1,-1) =='"'
		if not is_cstring then
			if v:match"::" then --could be nested enum
				local enumname = v:gsub("[%w:]-::([%w]+)","%1")
				local ok,val = pcall(cpp2ffi.parse_enum_value,enumname,enumsvalues)
				if ok then
					def.defaults[k] = val
				else
					print("deleting default ",v)
					def.defaults[k] = nil
				end
			elseif enumsvalues[v] then
				def.defaults[k] = enumsvalues[v]
			else
				local ok,val = pcall(cpp2ffi.parse_enum_value,v,enumsvalues,true)
				if ok then
				def.defaults[k] = val
				elseif def.defaults[k]:match"FLT_MAX" then
					def.defaults[k] = def.defaults[k]:gsub("FLT_MAX","M.FLT_MAX")
				elseif def.defaults[k]:match"FLT_MIN" then
					def.defaults[k] = def.defaults[k]:gsub("FLT_MIN","M.FLT_MIN")
				else
				--numbers without f in the end
				def.defaults[k] = v:gsub("([%d%.%-]+)[Ff]","%1")
				--+ in front of numbers
				def.defaults[k] = def.defaults[k]:gsub("^%+([%d%.%-]+)","%1")
				
				def.defaults[k] = def.defaults[k]:gsub("ImDrawCornerFlags_All","lib.ImDrawCornerFlags_All")
				def.defaults[k] = def.defaults[k]:gsub("sizeof%((%w+)%)",[[ffi.sizeof("%1")]])
				def.defaults[k] = def.defaults[k]:gsub("%(%(void%s*%*%)0%)","nil")
				def.defaults[k] = def.defaults[k]:gsub("NULL","nil")
				def.defaults[k] = def.defaults[k]:gsub("nullptr","nil")
				if def.defaults[k]:match"%(ImU32%)" then
					def.defaults[k] = CleanImU32(def.defaults[k])
				end
				end
				--if def.defaults[k]:match"~" then
				--	def.defaults[k] = bit.bnot
				--end
			end
		end
	end
end

local function ArgumentType(def,name)
	for i,arg in ipairs(def.argsT) do
		if arg.name == name then
			return arg.type
		end
	end
end

local function make_function(method,def)
	if def.skipped then return "" end
	if def.is_static_function then method = nil end
	sanitize_reserved(def)
	local fname = def.ov_cimguiname or def.cimguiname --overloaded or original
	local fname_m = method and fname:match(def.stname.."_(.*)") or fname:match("^ig(.*)") or fname --drop struct name part
	fname_m = fname_m:match("(.*)_nonUDT$") or fname_m --drop "_nonUDT" suffix
	if fname_m == "end" then fname_m = "_end" end
	--dump function code
	if def.nonUDT == 1 or next(def.defaults) then
		local call_args = def.call_args:gsub("%*","")
		local code = {}
		local args, fname_lua
		local empty = call_args:match("^%(%)") --no args
		if method and not def.is_static_function then
			args = call_args:gsub("^%(","(self"..(empty and "" or ","))
			fname_lua = def.stname..":"..fname_m
			empty = false
		else
			args = call_args
			fname_lua = "M."..fname_m
		end
		table.insert(code,"function "..fname_lua..call_args)
		--set defaults
		cpp2ffi.table_do_sorted(def.defaults, function(k,v)
		--for k,v in pairs(def.defaults) do
			--special default treatment for ImStrv
			if ArgumentType(def,k) == "ImStrv" then
				--print("default for ImStrv",v)
				if v:match"ImStrv()" then
					table.insert(code,"    "..k.." = "..k.." or M.ImStrv()")
				else
					table.insert(code,"    "..k.." = "..k.." or M.ImStrv("..v..")")
				end
			else
				if v == 'true' then
					table.insert(code,"    if "..k.." == nil then "..k.." = "..v.." end")
				else
					table.insert(code,"    "..k.." = "..k.." or "..v)
				end
			end
		--end
		end)
		if def.nonUDT == 1 then
			--allocate variable for return value
			local out_type = def.argsT[1].type:gsub("*", "")
			table.insert(code,'    local nonUDT_out = ffi.new("'..out_type..'")')
			--prepend nonUDT_out to args
			args = args:gsub("%(", "(nonUDT_out" .. (empty and "" or ","), 1)
			--call cimgui and return value of out variable
			table.insert(code,"    lib."..fname..args)
			table.insert(code,"    return nonUDT_out")
		else
			--call cimgui
			table.insert(code,"    return lib."..fname..args)
		end
		table.insert(code,"end")
		return table.concat(code,"\n")
	end
	--for no nonUDT and no defaults
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
	cpp2ffi.table_do_sorted(def.defaults, function(k,v)
	--for k,v in pairs(def.defaults) do
		table.insert(code,"    if "..k.." == nil then "..k.." = "..v.." end")
	--end
	end)
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

local cdefs = dofile("./imgui/cdefs.lua")
ffi_cdef(cdefs)
local function checktype(typ,va)
	if ffi.typeof(typ)==ffi.typeof"int" or 
		ffi.typeof(typ)==ffi.typeof"const int" or
		ffi.typeof(typ)==ffi.typeof"float" or
		ffi.typeof(typ)==ffi.typeof"double" then
		return "(ffi.istype('"..typ.."',"..va..") or type("..va..")=='number')"
	elseif ffi.typeof(typ)==ffi.typeof"bool" then
		return "(ffi.istype('"..typ.."',"..va..") or type("..va..")=='boolean')"
	elseif ffi.typeof(typ)==ffi.typeof"const char*" then
		return "(ffi.istype('"..typ.."',"..va..") or ffi.istype('char[]',"..va..") or type("..va..")=='string')"
	elseif ffi.typeof(typ)==ffi.typeof"const float*" then
		return "(ffi.istype('"..typ.."',"..va..") or ffi.istype('float[]',"..va.."))"
	elseif ffi.typeof(typ)==ffi.typeof"const double*" then
		return "(ffi.istype('"..typ.."',"..va..") or ffi.istype('double[]',"..va.."))"
	elseif ffi.typeof(typ)==ffi.typeof"int*" then
		return "(ffi.istype('"..typ.."',"..va..") or ffi.istype('int[]',"..va.."))"
	elseif ffi.typeof(typ)==ffi.typeof"void*" or ffi.typeof(typ)==ffi.typeof"const void*" then
		return "ffi.istype('"..typ.."',"..va..")"
	elseif typ=="ImU32" then
		return "(ffi.istype('"..typ.."',"..va..") or type("..va..")=='number')"
	else
		if typ:match"%*" and not typ:match"%(%*%)" then --pointer not function pointer
			local typsinptr = typ:gsub("(%*)","")
			local extra = " or ffi.istype('"..typsinptr.."',"..va..")"
			local extra2 = " or ffi.istype('"..typsinptr.."[]',"..va..")"
			return "(ffi.istype('"..typ.."',"..va..")"..extra..extra2..")"
		end
		return "ffi.istype('"..typ.."',"..va..")"
	end
end

local function gen_args(method,def,minvararg)
	local n = #def.argsT
	local args = ""
	local isvararg
	if minvararg < math.huge and n >= minvararg then
		n = minvararg - 1
		isvararg = true
	end
	local ini = 1
	if method then ini = ini + 1 end
	if def.nonUDT then ini = ini + 1 end
	for i=ini,n do
		args = args.."a"..i..","
	end
	if isvararg then
		args = args .. "...,"
	end
	args = args:sub(1,-2) --drop last 
	return args
end

--require"anima.utils" --gives us prtable
local function create_generic(code,defs,method)
	if defs[1].skipped then return end
	if defs[1].is_static_function then
		method = nil
	end
	
	if defs[1].nonUDT then print("create_generic nonUTD",defs[1].cimguiname) end
	
	local methodnotconst = method and not defs[1].constructor
	--find max number of arguments
	local maxnargs = -1
	local minvararg = math.huge
	local is_vararg
	for i,def in ipairs(defs) do
		if #def.argsT> 0 and def.argsT[#def.argsT].type == "..." then
			minvararg = minvararg > #def.argsT and #def.argsT or minvararg
			--print("...",def.cimguiname,#def.argsT)
		end
		maxnargs = maxnargs < #def.argsT and #def.argsT or maxnargs
	end
	is_vararg = minvararg < math.huge
	--if is_vararg then print("maxnargs",defs[1].cimguiname,maxnargs,minvararg) end
	--[[
	for i,def in ipairs(defs) do
		io.write(def.ov_cimguiname," , ")
	end
	print()
	for i=1,maxnargs do
		io.write(i," ")
		for j,def in ipairs(defs) do
			io.write(def.argsT[i] and def.argsT[i].type or "nil")
			io.write", "
		end 
		print()
	end
	--]]
	--find first different arg
	local keys = {}
	local done = {}
	local check = {}
	local maxnargs2 = is_vararg and minvararg-1 or maxnargs
	for i=1,maxnargs2 do
		keys[i] = {}
		for j=1,#defs do
			if not done[j] then
				local tt = defs[j].argsT[i] and defs[j].argsT[i].type or "nil"
				keys[i][tt] = (keys[i][tt] or 0) + 1
			end
		end
		local keycount = 0
		for k,v in pairs(keys[i]) do keycount = keycount + 1 end
		--print("keycount",i,keycount,#defs)
		for j=1,#defs do
			if not done[j] then
				local tt = defs[j].argsT[i] and defs[j].argsT[i].type or "nil"
				if keycount > 1 then
					check[j] = check[j] or {}
					check[j][i]=tt
				end
				if keys[i][tt] == 1 then 
					done[j]= true;
					--print(j,defs[j].ov_cimguiname,"done") 
				end
			end
		end
	end
	
	--if is_vararg then cpp2ffi.prtable(keys,done,check) end

	--do generic--------------
	local code2 = {}
	--create args
	if is_vararg then maxnargs = minvararg-1 end
	local args = "" --method and "self," or ""
	if methodnotconst then
		if defs[1].nonUDT then
			for i=3,maxnargs do
				args = args.."a"..i..","
			end
		else		
			for i=2,maxnargs do
				args = args.."a"..i..","
			end
		end
	elseif method then --constructor
		args = maxnargs==0 and "ctype" or "ctype,"
		for i=1,maxnargs do args = args.."a"..i.."," end
	else
		if defs[1].nonUDT then
			for i=2,maxnargs do
				args = args.."a"..i..","
			end
		else		
			for i=1,maxnargs do
				args = args.."a"..i..","
			end
		end
	end
	if is_vararg then args = args.."...," end
	args = args:sub(1,-2) --drop last ,
	
	local fname = defs[1].cimguiname 
	local fname_e = method and fname:match(defs[1].stname.."_(.*)") or fname:match("^ig(.*)") or fname--drop struct name part
	fname = method and (methodnotconst and defs[1].stname..":"..fname_e or defs[1].stname..".__new") or "M."..fname_e

	table.insert(code2, "function "..fname.."("..args..") -- generic version")
	
	for i=1,#check do
		local chk = check[i]
		table.insert(code2,"\n    if ")
		local addand = false
		for k,v in pairs(chk) do
			assert(k < minvararg, fname)
			if addand then table.insert(code2," and ") end
			if v=="nil" then
				table.insert(code2,"a"..k.."==nil")
			else
				local strcode = checktype(v,"a"..k)
				--if has a default take nil as valid check
				--print("defs[i].defaults[k]",defs[i].ov_cimguiname,defs[i].defaults[defs[i].argsT[k].name])
				if defs[i].defaults[defs[i].argsT[k].name]~=nil then
					--if defs[i].argsT[k].type~="ImStrv" then 
					strcode = "("..strcode.." or type(a"..k..")=='nil')"
					--end
				end
				table.insert(code2 , strcode)
				---table.insert(code2,"ffi.istype('"..v.."',a"..k..")")
			end
			addand = true
		end
		local fname2 = defs[i].ov_cimguiname 
		local fname2_e = method and fname2:match(defs[1].stname.."_(.*)") or fname2:match("^ig(.*)") or fname2 --drop struct name part
		fname2 = method and (methodnotconst and "self:"..fname2_e or defs[1].stname.."."..fname2_e) or "M."..fname2_e
		table.insert(code2," then return "..fname2.."("..gen_args(methodnotconst,defs[i],minvararg)..") end")
		if fname_e == fname2_e then
			print("--------error cimguiname equals ov_cimguiname in overloaded function",fname)
			--error"cimguiname equals ov_cimguiname"
		end
	end
	table.insert(code2,"\n    print("..args..")")
	table.insert(code2,"\n    error'"..fname.." could not find overloaded'\nend")
	table.insert(code, table.concat(code2))
end

--struct code generator
local function code_for_struct(st,fundefs,structs)
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
					struct_function_gen(code,def)
				end
			end
		end
		if #defs > 1 then
			create_generic(code,defs,true)
		end
	end
	table.insert(code,[[M.]]..st..[[ = ffi.metatype("]]..st..[[",]]..st..")")
	local codestr = table.concat(code,"\n")
	--test correctness of code
	testcode(codestr)
	return codestr
end

--ImGui namespace generator
local function code_for_imguifuns(st,fundefs,structs)
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
		--if has overloading create the generic
		if #defs > 1 then
			create_generic(code, defs)
		end
	end
	local codestr = table.concat(code,"\n")
	--test correctness of code
	testcode(codestr)
	return codestr
end

local function make_enums(sources)
	for i,v in ipairs(sources) do
		local standenu = dofile([[../]]..v..[[/generator/output/structs_and_enums.lua]])
		for k,enu in pairs(standenu.enums) do
			for i,v in ipairs(enu) do
				assert(v.calc_value)
				enumsvalues[v.name] = v.calc_value
			end
		end
	end
end

local function make_funcdefs(sources)
	local fundefs = {}
	for i,v in ipairs(sources) do
		local fundefs1 = dofile([[../]]..v..[[/generator/output/definitions.lua]])
		for fun,defs in pairs(fundefs1) do
			fundefs[fun] = defs
		end
	end
	return fundefs
end
--------------------------------------------------------------

local function class_gen(sources)
	--firs get enumsvalues table
	make_enums(sources)
	local fundefs = make_funcdefs(sources)
	--group them by structs
	local structs = {}
	local skipped = {}
	for fun,defs in pairs(fundefs) do
		local stname = defs[1].stname
		if not defs[1].templated then
			structs[stname] = structs[stname] or {}
			table.insert(structs[stname],fun)
		else
			skipped[stname] = true
		end
	end
	print"---skipped templated structs"
	for k,_ in pairs(skipped) do
		print(k)
	end
	--delete templated
	structs.ImVec4 = nil
	structs.ImVector = nil
	structs.ImChunkStream = nil
	structs.ImPool = nil
	---------------------------------------------------------------
	local strout = {}
	--Do generation
	table.insert(strout,"----------BEGIN_AUTOGENERATED_LUA---------------------------")
	cpp2ffi.table_do_sorted(structs, function(struct,funs)
		if struct ~= "ImGui" and struct ~= "ImVec2" and struct ~= "ImStrv" and struct ~= "" then
			table.insert(strout,code_for_struct(struct,fundefs, structs))
		end
	end)
	table.insert(strout,code_for_imguifuns("",fundefs, structs))--("ImGui"))
	
	table.insert(strout,"return M")
	table.insert(strout,"----------END_AUTOGENERATED_LUA-----------------------------")
	return table.concat(strout,"\n")
	end

return class_gen

