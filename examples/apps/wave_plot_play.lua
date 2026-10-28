local ffi = require"ffi"

function PrepareAudioRT(args)--asio,dev_id)
    args = args or {}
    offset = offset or 0
    local dev_id = args.dev_id or 0
    local rt = require 'rtaudio_ffi'
    local AudioPlayer = require("rtAudioPlayer")
    local sndf = require"sndfile_ffi"
    
    local api
    if args.api then
        api = rt.compiled_api_by_name(args.api)
    else
        local RtAudioInfo = rt.GetAllInfo()
        local API, device = RtAudioInfo.first_out()
        local apis = rt.compiled_api()
        --api = apis[0]
        api = rt.compiled_api_by_name(API)
        print"available RtAudio APIs"
        for i=0,rt.get_num_compiled_apis() do
            print(i,ffi.string(rt.api_name(apis[i])))
        end
    end
    
    local dac = rt.create(api)
    local device = rt.get_default_output_device(dac)
    print("dac using",ffi.string(rt.api_name(api)))
--copy specs from file
    --local info = sndf.get_info(soundfile)
    local audioplayer,err = AudioPlayer({
    dac = dac,
    device = device,
    freq = 48000, --info.samplerate, 
    format = rt.FORMAT_FLOAT32,
    channels = 2, --info.channels, 
    samples = 1024})
    
    assert(audioplayer,err)
    
    
    --audioplayer:insert(soundfile,1,offset)
    --local DURAMUSICA = info.frames/info.samplerate
    
    return audioplayer
end

local function Do_gc()
    print("DO_gc====================================================",collectgarbage"count")
    collectgarbage()
    collectgarbage()
    print(collectgarbage"count")
end
Do_gc()

----------------
local dac = PrepareAudioRT()
dac:start()

--- load soundfile

local buffer
local function load_sound(filename)
    for node in dac:nodes() do
        dac:erase(node)
    end
    local sndf = require"sndfile_ffi"
    --local filename = [[C:\Users\sonor\Desktop\musicas victor\morning_in_india.wav]]--"african_room.wav";
    --local filename = [[C:\Users\sonor\Desktop\musicas victor\kyrie5d-2_peli.wav]]--"african_room.wav";
    local ok,info = pcall(sndf.get_info,filename)
    if not ok then print(info); return end
    print(info.frames,info.channels)
    buffer = ffi.new("float[?]",info.frames*info.channels)
    local sf = sndf.Sndfile(filename)
    sf:readf(buffer)
    sf:close()
    dac:insert(filename)
    return info
end


--[[
----normalize buffer
local maxi = -math.huge
local abs = math.abs
for i=0,tonumber(info.frames*info.channels)-1 do
    local val = abs(buffer[i])
    maxi = maxi > val and maxi or val
end
local invmaxi = 1/maxi
for i=0,tonumber(info.frames*info.channels)-1 do
    buffer[i] = buffer[i]*invmaxi
end
--]]
--- resample functions
local max,min = math.max, math.min
local function clip(v,l,h)
    return max(l,min(h,v))
end
local function Resample(W,t1,t2,info,Buf)
    local Byl = ffi.new("float[?]",W) --amplitude low
    local Byh = ffi.new("float[?]",W) --amplitude hight

    local BylR = ffi.new("float[?]",W) --amplitude low
    local ByhR = ffi.new("float[?]",W) --amplitude hight

    local Bt = ffi.new("float[?]",W) -- time
    local nbins = math.floor((t2-t1)*info.samplerate)
    local facx = tonumber(nbins/W)
    local binle = math.floor(facx+0.5)
    local frames = tonumber(info.frames)
    --print(nbins,facx,binle)
    for i=0,W-1 do
        local binini = math.floor(t1*info.samplerate+i*facx)
        local inibin = clip(binini,0,frames-1)
        local endbin = clip(binini+binle,0,frames-1)
        Bt[i] = t1+ i*(t2-t1)/(W-1)
        Byl[i] = math.huge
        Byh[i] = -math.huge
        BylR[i] = math.huge
        ByhR[i] = -math.huge
        for j=inibin,endbin do
            local j1 = j*info.channels
            local value = Buf[j1]
            Byl[i] = Byl[i] < value and Byl[i] or value
            Byh[i] = Byh[i] > value and Byh[i] or value
            j1 = j*info.channels + 1
            value = Buf[j1]
            BylR[i] = BylR[i] < value and BylR[i] or value
            ByhR[i] = ByhR[i] > value and ByhR[i] or value
        end
    end
    return Bt,Byl,Byh,BylR,ByhR
end

-- imgui
local igwin = require"imgui.window"

local win = igwin:GLFW(800,400, "wav",{vsync=true})
win.ig.ImPlot_CreateContext()

local info,audioLengthInSeconds,dummyX,dummyY
local a,b,c
local Bt,Byl,Byh,BylR,ByhR
local filename
local gui = require"imgui.libs.filebrowser"(win.ig)
local inipath = [[C:\Users\sonor\Desktop\musicas victor]]
local fB = gui.FileBrowser(nil,{curr_dir=inipath},
    function(f,dir) 
        info = load_sound(f)
        if not info then return end
        audioLengthInSeconds = tonumber(info.frames/info.samplerate)
        dummyX = ffi.new("float[?]",2,{0, audioLengthInSeconds});
        dummyY = ffi.new("float[?]",2,{1, -1})
        dac:set_stream_time(0)
        a = nil --to trigger resample
        filename = f
    end)


-- specs
local ig = win.ig
local spec1 = ig.ImPlotSpec()
spec1.FillAlpha = 0.15
spec1.FillColor = ig.ImVec4(0,0.5,1,1)
spec1.LineColor = ig.ImVec4(0,0.5,1,1)
local specR = ig.ImPlotSpec()
specR.FillAlpha = 0.15
specR.FillColor = ig.ImVec4(0,1,0.5,1)
specR.LineColor = ig.ImVec4(0,1,0.5,1)
local spec_dummy = ig.ImPlotSpec()
spec_dummy.LineColor = ig.ImVec4(0,0,0,0)

local spec_ti = ig.ImPlotSpec()
spec_ti.Flags = ig.lib.ImPlotItemFlags_NoLegend
spec_ti.LineColor = ig.ImVec4(1,0,0,1)

-- for setting time limits next frame
local t1n,t2n
function win:draw(ig)
    --ig.ImPlot_ShowDemoWindow()
    --ig.ShowDemoWindow()
    local viewport = ig.GetMainViewport();
    ig.SetNextWindowPos(viewport.WorkPos);
    ig.SetNextWindowSize(viewport.WorkSize);
    ig.Begin("Waveform")
        ig.Text("(%05.1f Mb)", collectgarbage("count")/1024)
        ig.SameLine()
        if ig.SmallButton("Do_gc") then Do_gc() end
        ig.SameLine()
        local playing = dac:is_playing()
        local play_but_text = playing and " || " or "  > "
        if ig.SmallButton(play_but_text) then
            if playing then dac:stop() else dac:start() end
        end
        ig.SameLine()
        if ig.SmallButton("load") then fB.open() end
        fB.draw()
        ig.SameLine()
        ig.TextUnformatted(filename or "")
        if info then
        if ig.ImPlot_BeginPlot("wav",ig.ImVec2(-1,-1)) then
            ig.ImPlot_SetupAxes("Time [s]","Amplitude");
            ig.ImPlot_SetupAxisLimits(ig.lib.ImAxis_Y1, -1, 1, ig.lib.ImPlotCond_Always);
            if t1n then
                ig.ImPlot_SetupAxisLimits(ig.lib.ImAxis_X1,t1n,t2n, ig.lib.ImPlotCond_Always)
                t1n = nil
            end
            if (ig.ImPlot_IsPlotHovered() and ig.IsMouseClicked(0) and ig.GetIO().KeyCtrl) then
                local pt = ig.ImPlot_GetPlotMousePos();
                dac:set_stream_time(pt.x)
            end
            local widthPix = ig.ImPlot_GetPlotSize().x;
            local Xrect = ig.ImPlot_GetPlotLimits().X
            local t1 = Xrect.Min;
            local t2 = Xrect.Max;
            ---------------------
            local ti = math.fmod(dac:get_stream_time() , audioLengthInSeconds)
            dac:set_stream_time(ti)
            if ti>=t2 then
                local siz = Xrect:Size()
                -- set X range for next frame
                t1n = ti; t2n = ti+siz
            end
            ------------------------
            if a~=widthPix or b~=t1 or c~=t2 then
                Bt,Byl,Byh,BylR,ByhR = Resample(widthPix,t1,t2,info,buffer)
                a=widthPix;b=t1;c=t2
            end
            ig.ImPlot_PlotShaded("L",Bt, Byl,Byh,widthPix, spec1[0]);
            ig.ImPlot_PlotLine("L",Bt, Byl,widthPix, spec1[0]);
            ig.ImPlot_PlotLine("L",Bt, Byh,widthPix, spec1[0]);
            ig.ImPlot_PlotShaded("R",Bt, BylR,ByhR,widthPix, specR[0]);
            ig.ImPlot_PlotLine("R",Bt, BylR,widthPix, specR[0]);
            ig.ImPlot_PlotLine("R",Bt, ByhR,widthPix, specR[0]);
            ig.ImPlot_PlotLine("##DummyPointsForFitting",dummyX,dummyY,2, spec_dummy[0])
            local ti2 = ffi.new("double[?]",1,ti)
            ig.ImPlot_PlotInfLines("ti",ti2,1,spec_ti[0])
            ig.ImPlot_EndPlot();
        end
        end --info
    ig.End()
end


win:start()

win.ig.ImPlot_DestroyContext()