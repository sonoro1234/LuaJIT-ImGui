local ffi = require"ffi"

--from https://github.com/sonoro1234/LuaJIT-SDL2
local sdl = require"sdl2_ffi"
--just to get gl functions
-- from https://github.com/sonoro1234/LuaJIT-GLFW
local gllib = require"gl"
gllib.set_loader(sdl)
local gl, glc, glu, glext = gllib.libraries()

local ig = require"imgui.sdl"

if (sdl.init(sdl.INIT_AUDIO+sdl.INIT_VIDEO+sdl.INIT_TIMER) ~= 0) then

        print(string.format("Error: %s\n", sdl.getError()));
        return -1;
end
-----audio stuff
local sampleHz = 48000

local function MyAudioCallback()
local ffi = require"ffi"
return function(ud,stream,len)
	local buf = ffi.cast("float*",stream)
	local udc = ffi.cast("struct {double Phase;double dPhase;}*",ud)
	local lenf = len/ffi.sizeof"float"

	for i=0,lenf-2,2 do
		local sample = math.sin(udc.Phase)*0.05
		udc.Phase = udc.Phase + udc.dPhase
		buf[i] = sample
		buf[i+1] = sample
	end
end
end

local ud = ffi.new"struct {double Phase;double dPhase;}"
local freqval = ffi.new("float[1]",100)
local function setFreq(ff)
	sdl.LockAudio() -- not really needed
	ud.dPhase = 2 * math.pi * ff / sampleHz
	sdl.UnlockAudio()
end
setFreq(freqval[0])

local want = ffi.new"SDL_AudioSpec[1]"
local have = ffi.new"SDL_AudioSpec[1]"
want[0].freq = sampleHz;
want[0].format = sdl.AUDIO_F32;
want[0].channels = 2;
want[0].samples = 4096;
want[0].callback = sdl.MakeAudioCallback(MyAudioCallback) 
want[0].userdata = ud

local dev = sdl.openAudioDevice(devwanted, 0, want, have, 0)
if (dev == 0) then
    sdl.log("Failed to open audio: %s", sdl.GetError());
	error"failed to open audio"
else 
    sdl.PauseAudioDevice(dev, 0); -- start audio playing. 
end
------------
    sdl.gL_SetAttribute(sdl.GL_CONTEXT_FLAGS, sdl.GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
    sdl.gL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, sdl.GL_CONTEXT_PROFILE_CORE);
    sdl.gL_SetAttribute(sdl.GL_DOUBLEBUFFER, 1);
    sdl.gL_SetAttribute(sdl.GL_DEPTH_SIZE, 24);
    sdl.gL_SetAttribute(sdl.GL_STENCIL_SIZE, 8);
    sdl.gL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, 3);
    sdl.gL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 2);
    local current = ffi.new("SDL_DisplayMode[1]")
    sdl.getCurrentDisplayMode(0, current);
    local window = sdl.createWindow("ImGui SDL2+OpenGL3 example", sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, 700, 500, sdl.WINDOW_OPENGL+sdl.WINDOW_RESIZABLE); 
    local gl_context = sdl.gL_CreateContext(window);
    sdl.gL_SetSwapInterval(1); -- Enable vsync
    
    local ig_Impl = ig.Imgui_Impl_SDL_opengl3()
    
    ig_Impl:Init(window, gl_context)

    local igio = ig.GetIO()
    
    local done = false;
    while (not done) do
        --SDL_Event 
        local event = ffi.new"SDL_Event"
        while (sdl.pollEvent(event) ~=0) do
            ig.lib.ImGui_ImplSDL2_ProcessEvent(event);
            if (event.type == sdl.QUIT) then
                done = true;
            end
            if (event.type == sdl.WINDOWEVENT and event.window.event == sdl.WINDOWEVENT_CLOSE and event.window.windowID == sdl.getWindowID(window)) then
                done = true;
            end
        end
        --standard rendering
        sdl.gL_MakeCurrent(window, gl_context);
        gl.glViewport(0, 0, igio.DisplaySize.x, igio.DisplaySize.y);
        gl.glClear(glc.GL_COLOR_BUFFER_BIT)

        ig_Impl:NewFrame()
        
        
        if ig.SliderFloat("frequency",freqval,100,2000) then
            setFreq(freqval[0])
        end
        ig.ShowDemoWindow(showdemo)
        
        ig_Impl:Render()
        sdl.gL_SwapWindow(window);
    end
    
    -- Cleanup
	sdl.PauseAudioDevice(dev, 1)
    sdl.CloseAudioDevice(dev);
    ig_Impl:destroy()

    sdl.gL_DeleteContext(gl_context);
    sdl.destroyWindow(window);
    sdl.quit();

