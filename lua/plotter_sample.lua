local ffi = require "ffi"
local lj_glfw = require"glfw"
local gl, glc, glu, glfw, glext = lj_glfw.libraries()
local ig = require"imgui"
-----------Ploter--------------------------
local function Plotter(xmin,xmax,nvals)
	local Graph = {xmin=xmin or 0,xmax=xmax or 1,nvals=nvals or 400}
	function Graph:init()
		self.values = ffi.new("float[?]",self.nvals)
	end
	function Graph:itox(i)
		return self.xmin + i/(self.nvals-1)*(self.xmax-self.xmin)
	end
	function Graph:calc(func,ymin1,ymax1)
		local vmin = math.huge
		local vmax = -math.huge
		for i=0,self.nvals-1 do
			self.values[i] = func(self:itox(i))
			vmin = (vmin < self.values[i]) and vmin or self.values[i]
			vmax = (vmax > self.values[i]) and vmax or self.values[i]
		end
		self.ymin = ymin1 or vmin
		self.ymax = ymax1 or vmax
	end
	function Graph:draw()
	
		local regionsize = ig.GetContentRegionAvail()
		local desiredY = regionsize.y - ig.GetFrameHeightWithSpacing()
		ig.PushItemWidth(-1)
		ig.PlotLines("##grafica",self.values,self.nvals,nil,nil,self.ymin,self.ymax,ig.ImVec2(0,desiredY))
		local p = ig.GetCursorScreenPos() 
		p.y = p.y - ig.GetStyle().FramePadding.y
		local w = ig.CalcItemWidth()
		self.origin = p
		self.size = ig.ImVec2(w,desiredY)
		
		local draw_list = ig.GetWindowDrawList()
		for i=0,4 do
			local ylab = i*desiredY/4 --+ ig.GetStyle().FramePadding.y
			draw_list:AddLine(ig.ImVec2(p.x, p.y - ylab), ig.ImVec2(p.x + w,p.y - ylab), ig.U32(1,0,0,1))
			local valy = self.ymin + (self.ymax - self.ymin)*i/4
			local labelY = string.format("%0.3f",valy)
			-- - ig.CalcTextSize(labelY).x
			draw_list:AddText(ig.ImVec2(p.x , p.y -ylab), ig.U32(0,1,0,1),labelY)
		end
	
		for i=0,10 do
			local xlab = i*w/10
			draw_list:AddLine(ig.ImVec2(p.x + xlab,p.y), ig.ImVec2(p.x + xlab,p.y - desiredY), ig.U32(1,0,0,1))
			local valx = self:itox(i/10*(self.nvals -1))
			draw_list:AddText(ig.ImVec2(p.x + xlab,p.y + 2), ig.U32(0,1,0,1),string.format("%0.3f",valx))
		end
		
		ig.PopItemWidth()
		
		return w,desiredY
	end
	Graph:init()
	return Graph
end
local Graph = Plotter(-1,1)
--Graph:calc(function(x) return math.exp(x) end)
Graph:calc(function(x) return 1/x end)
--Graph:calc(function(x) return x*(x+1)/x end)
-------------------------------------------
glfw.glfwSetErrorCallback(function(error,description)
    print("GLFW error:",error,ffi.string(description or ""));
end)

lj_glfw.init()
local window = lj_glfw.Window(700,500)
window:makeContextCurrent()	

--ig.CreateContext(nil)	
local ig_gl3 = ig.ImplGlfwGL3()
ig_gl3:Init(window, true)

local showdemo = ffi.new("bool[1]",false)
while not window:shouldClose() do

	lj_glfw.pollEvents()
	
	gl.glClear(glc.GL_COLOR_BUFFER_BIT)
	
	--print(ig.GetIO().MousePosPrev)
	
	ig_gl3:NewFrame()
	
	Graph:draw()
	
	ig_gl3:Render()
	
	window:swapBuffers()					
end

ig_gl3:destroy()
window:destroy()
lj_glfw.terminate()