local ffi = require"ffi"

local Sleep
if ffi.os == "Windows" then
	ffi.cdef[[void Sleep(uint32_t);]]
	Sleep = function(ti)
		ffi.C.Sleep(ti*1000)
	end
else
	ffi.cdef[[unsigned int sleep(unsigned int);]]
	Sleep = function(ti)
		ffi.C.sleep(ti)
	end
end
-- local nothing = require"nothing"
-- KK = II.bad
-- Klocal rrr = 1

local a = 0
local function run()
	local i = 0
	while i < 5 do

		print("hello",i)
		i = i + 1
		Sleep(1)
		 error"debug"
		-- while true do  end
	end
	print(a)
end
-- aa 0
--FINALIZER = function(ok,val) print("---i am loop finalizer",ok,val) end
print("jit.status",jit.status())
run()
