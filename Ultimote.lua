--[[
Corona® Ultimote v 1.31
--added google earth feature
--fixed hidden box/hittestable problem
Author: M.Y. Developers
Copyright (C) 2011 M.Y. Developers All Rights Reserved
Support: mydevelopergames@gmail.com
Website: http://www.mygamedevelopers.com/Corona-Ultimote.html
License: Many hours of genuine hard work have gone into this project and we kindly ask you not to redistribute or illegally sell this package. If you
have not purchased the companion Android/iOS app then you must use this work for evaluation purposes only and you may not use the given macros for debugging your own
commercial or free projects. You are not allowed to reverse engineer any protocols specified by this work or produce an app of your own that interfaces with this program.
We are constantly developing this software to provide you with a better development experience and any suggestions are welcome. Thanks for you support.

-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
-- DEALINGS IN THE SOFTWARE.
--]]
module (..., package.seeall)
local _H = display.contentHeight 
local _W = display.contentWidth
local clientH,clientW = _H,_W
local socket = require "socket"
local json = require("json")
local connectToDevice = false
local registeredEvents =  {}
local macroFilesRecord = {}
local eventsToRecord = {}
local macroFilesPlay = {}
local options = {}
local objects = {}
local frames = {}
local focusTable = {}
local state = {}
state.system = {}
local deviceInfo = nil
local currentTouchID,tcpClientMessage,payload,sendMessage,sendImages,tcpServer,myIP,myPort,broadcast,orientationMatch,allMacros,connectedToDevice

local xScale, yScale = 1,1 --scale of the screen based on the device
--replace display.getcurrentstage to enable setfocus to work over network
displayNet = {}


local function debugPrint(...)
	if not options.noDebug then
		print(unpack(arg))
	end
end

------------------------------------Options save/load
local path = system.pathForFile(  "UltimoteOptions.txt", system.DocumentsDirectory )
local file = io.open( path, "r" )
if file then
		-- read all contents of file into a string 
		local contents = file:read( "*a" ) 
		options = json.decode(contents);
		io.close( file )	
else

	options.noDebug  = false 
	options.overrideSystem = true
	options.sendAllObjects = false	
	options.noUDPBroadcast = false
	options.fps = 30
end	

local function SaveState(event)
	if( event.type ~= "applicationStart" ) then
        local path = system.pathForFile( "UltimoteOptions.txt", system.DocumentsDirectory )
        
        -- create file b/c it doesn't exist yet 
        local file = io.open( path, "w" ) 
 
        if file then
                file:write( json.encode(options) ) 
                io.close( file )
        end	
	end
end
local function SaveStateNow()
        local path = system.pathForFile( "UltimoteOptions.txt", system.DocumentsDirectory )
        
        -- create file b/c it doesn't exist yet 
        local file = io.open( path, "w" ) 
 
        if file then
                file:write( json.encode(options) ) 
                io.close( file )
        end	
end

Runtime:addEventListener( "system", SaveState );

display.getCurrentStageNative = display.getCurrentStage
display.setFocusNative =  display.getCurrentStage().setFocus
---[[
display.getCurrentStage = function()
	local stage = display.getCurrentStageNative()
	---[[
	function stage:setFocus(object, id)
	---[[
	--	self:setFocusNative(object, id)
		if id then
			focusTable[id] = object
		else
			if(currentTouchID) then
			focusTable[currentTouchID] = object		
			end
		end

		return display.setFocusNative(self, object, id)
		--]]
	end--]]
	return stage
end--]]
--re
function registerEvents (events)
	state.system.registerEvents = events
	registeredEvents = events
end
local function overrideSystem() 
system.hasEventSource = function()
	return true
end

--place acceleration intervels and stuff to go to device
local oldOpenURL = system.openURL
system.openURL = function( url )
	if(connectedToDevice) then
	state.system.openURL = url
	else
	oldOpenURL(url)
	end
end

system.setAccelerometerInterval = function ( frequency )

	state.system.setAccelerometerInterval = frequency
end
system.setGyroscopeInterval = function ( frequency )

	state.system.setGyroscopeInterval = frequency
end

system.setIdleTimer = function ( enabled )
	state.system.setIdleTimer = enabled
end
system.setLocationAccuracy = function ( distance )
	state.system.setLocationAccuracy = distance
end
system.setLocationThreshold = function ( distance )
	state.system.setLocationThreshold = distance
end
system.vibrate = function (  )
	state.system.vibrate = true
end

system.getInfoNative = system.getInfo
system.getInfo = function(param)
	if(options.deviceInfo and options.deviceInfo.getInfo ~= nil and options.deviceInfo.getInfo[param] ~= nil) then
		return options.deviceInfo.getInfo[param]
	else
		return system.getInfoNative(param)
	end
end
system.getPreference = function(category,name)
	return deviceInfo.getPreference[category][name]
end
end
if(options.overrideSystem) then
	overrideSystem() 
end

local function createTCPServer( ip, port )
        local tcpServerSocket , err = socket.tcp()
        local backlog = 5
        if tcpServerSocket == nil then 
                return nil , err
        end
        tcpServerSocket:setoption( "reuseaddr" , true )
		tcpServerSocket:setoption( "tcp-nodelay" , true )
        local res, err = tcpServerSocket:bind( ip , port )
        if res == nil then
                return nil , err
        end
        res , err = tcpServerSocket:listen( backlog )
        if res == nil then 
                return nil , err
        end
        
        return tcpServerSocket
        
end

--first time lets set the timeout high to allow device to connect so all the deviceInfo is right from the start

local tcpClient
local waitForConnection
local function setScreenSize(payload)
	if(payload.screenHeight) then
		clientH = payload.screenHeight
		clientW = payload.screenWidth
	end
	_H = display.contentHeight 
	_W = display.contentWidth

	local serverPortrait = _H>_W
	local clientPortrait =  clientH>clientW
	if(serverPortrait == clientPortrait) then
		orientationMatch = true
			
	else
		orientationMatch = false
	
	end
		yScale = clientH/_H
		xScale = clientW/_W 
end
Runtime:addEventListener("orientation", setScreenSize)
local circles = {}
local function drawTouchCirle(e)
	if(e.phase == "began") then
		circles[e.id] = display.newCircle(e.x,e.y,20)
		circles[e.id]:setFillColor(math.random(155)+100, math.random(155)+100, math.random(155)+100)
		transition.from(circles[e.id], {time = 500, xScale = 0.001, yScale = 0.001, transition = easing.outExpo})
	elseif(e.phase == "moved") then
		if(circles[e.id]) then
		circles[e.id].x, circles[e.id].y = e.x,e.y
		end
	elseif(e.phase == "ended" or e.phase == "cancelled") then
		display.remove(circles[e.id])
	end	
end
local function sendImages(params, isScreenshot)
	if(state.sendImages == nil) then state.sendImages = {} end
	for i,filename in ipairs(params) do		
		local index = #state.sendImages+1
		local path

			path = system.pathForFile(filename, system.DocumentsDirectory )		
			local file = io.open( path, "rb" )			
		if(file==nil) then 
			path = system.pathForFile(filename, system.ResourcesDirectory ) 
			if(file) then
				file = io.open( path, "rb" )	
			end
		end				

		
		
		if(file) then
			state.sendImages[index] = {}
			state.sendImages[index].name = filename		
			--get number of frames in this file
			local file = io.open( path, "rb" )
			state.sendImages[index].imageSize =  file:seek("end")
			if(isScreenshot) then
				state.sendImages[index].isScreenshot = true
			end
			file.close(file)
		end
	end
end

local function sendRemoteImages(payload)
	if(payload.getImage) then

		sendImages({payload.getImage})
	end
	
end

local function expandGroup(object, objectTable)
	if(object.numChildren and object.numChildren>0) then
		for j = object.numChildren, 1,-1 do
			objectTable[#objectTable+1] = object
			expandGroup(object[j],objectTable)
		end				
	else
		objectTable[#objectTable+1] = object
	end
end

local function dispatchEvents(payload)
					

	local events = payload.events
	if(events) then

	for i = 1, #events do

		local event = events[i]
		
		if(event.name:find("touch") or event.name:find("tap")) then
--			if(orientationMatch==false) then
--			event.x, event.y = event.y, event.x
--			end
			event.x, event.y = event.x/xScale, event.y/yScale
			--now draw marker circles if wanted
			drawTouchCirle(event)
			currentTouchID = event.id
			
			--if stagefocus then just send the event directly
			if(focusTable[currentTouchID]) then
				local object = focusTable[currentTouchID]
				if(object.dispatchEvent) then
				event.target = object
				object:dispatchEvent( event )
				else
				focusTable[currentTouchID] = nil
				end
			else
			--we must figure out what object was touched

			local handled = false
				for j = 1, #objects do
					
					local object  = objects[j]	
					local x,y = event.x, event.y
					local bounds = object.contentBounds 
					if( x > bounds.xMin and x < bounds.xMax and y > bounds.yMin and y < bounds.yMax) then
						event.target = object
						if( (object.isVisible or object.isHitTestable) and object:dispatchEvent( event )) then handled = true; break;	end
					end
					--
				end
					if(not handled) then
						Runtime:dispatchEvent( event )
					end
				end
			else
				Runtime:dispatchEvent( event )
			end
		end				
	end
end
local screenshotnum = 10
local function generateBoundingBoxes()
	state.boundingBoxes = {}
	local stage =  display.getCurrentStageNative()
	local sin,rad = math.sin, math.rad
	
	for j = #objects, 1,-1 do
		
		local object  = objects[j]
	
		if(options.sendAllObjects or object.ultimoteObject and object.isVisible) then
			
			state.boundingBoxes[j] = {}
			local x,y = object:localToContent(0,0)
			state.boundingBoxes[j].x = x*xScale
			state.boundingBoxes[j].y = y*yScale	
			local rotationScaleCorrection = 1/((sin(rad(((object.rotation)*4-90)))+1)*.4141/2+1)
			state.boundingBoxes[j].w = object.contentWidth*xScale*rotationScaleCorrection
			state.boundingBoxes[j].h = object.contentHeight*yScale*rotationScaleCorrection
			state.boundingBoxes[j].r = object.rotation	
			state.boundingBoxes[j].xr = object.xReference
			state.boundingBoxes[j].yr = object.yReference
			if(not options.sendAllObjects) then
			if(object.ultimoteImage==nil) then
			local name = string.sub(tostring(object),8)..math.random(1,10000)..".jpg" --ensure a unique name
			debugPrint("sending ", name)
			display.save( object, name, system.DocumentsDirectory )
			
			local path = system.pathForFile(name, system.DocumentsDirectory )		
			local file = io.open( path, "rb" )	
				if(file) then
					state.boundingBoxes[j].remoteImage = name
					object.ultimoteImage = name
				end
			end
			state.boundingBoxes[j].remoteImage = object.ultimoteImage	
			end
		end
	end
end
local timeout = 0 -- in frames
local runTCPServer
local function UDPBroadcast()
	if( not options.noUDPBroadcast) then
	local udp = socket.udp()
	udp:setoption("broadcast", true)
	udp:sendto(json.encode(broadcast), "255.255.255.255", 8080)
	udp:close()	
	end
end
local maxTimeout = 5
local function waitForConnection()

	UDPBroadcast()
tcpServer:settimeout( 0.1 )
	tcpClient , err = tcpServer:accept()	
		
	debugPrint("waiting for device...")

	if(tcpClient) then
		tcpClient:settimeout(0.1)	
		tcpClient:setoption( "tcp-nodelay" , true )
		--state.deviceInfo = true --get device info
		local message = tcpClient:receive('*l')

		if(message == nil) then tcpClient = nil; return; end
		payload = json.decode(message)
		setScreenSize(payload)
		options.deviceInfo = payload.deviceInfo
		allMacros = payload.allMacros

	--	tcpClient:send(json.encode(state).."\n")
		timeout = maxTimeout
		debugPrint("Connected!")
	else
	
	end
end

local retryTimer
local timeoutValue =1
local function runTCPThread()
		
		local startTimer = system.getTimer()
		if(tcpClient == nil) then
					connectedToDevice = false
					waitForConnection()
					return
		end
      --	
        if (tcpClient) then
				connectedToDevice = true
				startTimer = system.getTimer()
								state.sendMessage = sendMessage
							
			tcpClient:settimeout(0)	
			--tcpClient:send(json.encode(state).."\n");
			state.match = orientationMatch
			tcpClient:settimeout(0.0)	
			if(state.getAllMacros) then
				state.getMacros = allMacros
			end
  			if(timeout == maxTimeout) then  tcpClient:send(json.encode(state).."\n"); end
			tcpClient:settimeout(0.016)	
             tcpClientMessage , err = tcpClient:receive('*l')	

				--if(err) then debugPrint("TCP ERROR",err) end
				if(err == "closed") then
					waitForConnection()
					return
				end

                if ( tcpClientMessage ~= nil ) then
--				tcpClient:settimeout(0)	
--				local flushMessages = tcpClient:receive('*l')
--				while(flushMessages) do
--				flushMessages = tcpClient:receive('*l')
--				end
						if(payload == nil) then --flag that payload has been processed.
							payload = json.decode(tcpClientMessage)	
						end
						
						timeout = maxTimeout
					

						--------------do misc transactions--------------------------
						--see if there any macros to recieve
						if(state.getMacros) then
							tcpClient:settimeout(5)						
							for i, macro in ipairs(state.getMacros) do
		
								--first recieve size
								local size = tcpClient:receive('*l')			
								debugPrint("getting macro", macro)
								if(tonumber(size) == 1 and size ~= nil) then
									debugPrint("Macro "..macro.." not found on device. Check case sensitive name.")
								else
								local path = system.pathForFile( macro..".txt", system.DocumentsDirectory )	
								local file = io.open( path, "wb" ) 									
								local recieved = tcpClient:receive(size)								
								file:write(recieved)
								io.close(file)										
								end
													
							end
						end						
						
						--see if there is an image to send

						if(state.sendImages) then

							tcpClient:settimeout(5) --allow time to send image
							for i, image in ipairs(state.sendImages) do
								
								local path = system.pathForFile( image.name, system.DocumentsDirectory )		
								local file = io.open( path, "rb" )			
							if(file==nil) then 
								path = system.pathForFile( image.name, system.ResourcesDirectory ) 
								file = io.open( path, "rb" )	
							end	
								debugPrint("sending image ", image.name,path)
								tcpClient:send(file:read("*a"))
								file.close(file)	
															
							end
							state.sendImages = {}
						end
											
						state = {}
						state.system = {}
                else

				--we got a nil message b/c client was reset, look for client
						if( timeout == 0) then
							tcpClient:close()
							tcpClient = nil
						else
						 timeout =  timeout -1
							--debugPrint("connection error",timeout)
							--runTCPThread()
								
						end

				end
        else
                -- Error

        end
	local timeElapsed = system.getTimer() - startTimer 

	--[[
	if(maxTimeout-timeElapsed > 0) then
		timer.performWithDelay(maxTimeout-timeElapsed, 	runTCPThread)
	else
		timer.performWithDelay(maxTimeout, 	runTCPThread)
	end--]]
end


local function enterFrame()

	local stage =  display.getCurrentStageNative()
	objects = {}
	expandGroup(stage,objects)

	if(connectToDevice) then
		generateBoundingBoxes()	
		runTCPThread()
	end
	sendMessage = "connected. "
	
	--play events
	local playingMacro = false
	for i,macro in pairs(macroFilesPlay) do
		playingMacro = true
		if(macro.data == nil) then --first line, read regardless
			local line = macro.file:read("*l") 
			if(line) then macro.data = json.decode(line)	end
			if(macro.frame == 0) then  
				macro.fpsFraction = macro.data.fps/options.fps 
				local line = macro.file:read("*l") 	
				if(line) then macro.data = json.decode(line)	end					
			end --- first line has fps data
		end
			
			macro.frame = macro.frame+macro.fpsFraction	
			debugPrint("playing "..macro.name.." frame #".. macro.frame)
		if(macro.data and macro.data.frameNum<=macro.frame) then	
			dispatchEvents(macro.data) 
			sendMessage = sendMessage.."play macro ".. i .." frame "..macro.frame.."/"..macro.totalFrames.." . "
			local line = macro.file:read("*l") 
			if(line) then 
				macro.data = json.decode(line)
			else
				stopPlayingMacro({name = i})				
			end
						
		end
		
	end	
---[[

		if(timeout == maxTimeout) then
	for i,macro in pairs(macroFilesRecord) do
		local file = macro.file

		sendMessage = sendMessage.."record macro ".. i
		if(macro.frames) then
			debugPrint("recording "..macro.name.." frame #".. macro.frames)
			local data = {}
			if(macro.frames == 1) then --put id information like fps
				file:write(json.encode({["fps"] = options.fps}).."\n")
			end
			sendMessage = sendMessage.." frame "..macro.frames.."/" ..macro.initFrames
			if(next(payload.events) ~= nil) then
				data.events = payload.events
				data.frameNum = macro.frames
				file:write(json.encode(data).."\n")
			end

			macro.frames = macro.frames+1	
			if(macro.frames == macro.initFrames) then
				stopRecordingMacro({name = i})
			end
		end
		sendMessage = sendMessage..". "
	end
	--]]
	if(payload) then
			sendRemoteImages(payload)	
		if(payload.screenWidth and payload.screenHeight) then
			setScreenSize(payload)
		end
		if(not playingMacro ) then								
			dispatchEvents(payload)
			payload = nil
		end	

	end
	end
	--timer.performWithDelay(0,runTCPThread,1)

end

--timer.performWithDelay(16,runTCPThread,1)
	
function screenCapture(params)
	if(params==nil) then params = {}; end
	local name = params.name or "default.jpg"
	display.save( display.getCurrentStage() , name, system.DocumentsDirectory )	
	sendImages({params.name},true)
end

local screenCaptureTimer
function autoScreenCapture(params)
	if(params==nil) then params = {}; end
	params.name = params.name or "default.jpg"
	params.period = params.period or 6000
	if(screenCaptureTimer) then timer.cancel(screenCaptureTimer); end
	 screenCapture(params)
	screenCaptureTimer = timer.performWithDelay(params.period, function() if(connectedToDevice) then screenCapture(params); end end, -1)
end
function stopAutoScreenCapture()
	timer.cancel(screenCaptureTimer)
end


--params = name, 
function playMacro(params)

	if(params == nil) then params = {} end
	local name = params.name or "default"
	local path = system.pathForFile( name..".txt", system.DocumentsDirectory )
	--get number of frames in this file
	local file = io.open( path, "r" )
	if(file == nil) then 
		path = system.pathForFile( name..".txt", system.ResourcesDirectory )
		--get number of frames in this file
		file = io.open( path, "r" )
		if(file == nil) then 
			debugPrint("Macro "..params.name.." not found, getting from device")
			getMacros({params.name});
			timer.performWithDelay(1000, function() playMacro({name = params.name}) end)
			return 
		end
	end
	local numLines = 0
	for line in file:lines() do numLines = numLines+1 end
	io.close( file )

	macroFilesPlay[name] = {}
	macroFilesPlay[name].name = name
	macroFilesPlay[name].file = io.open( path, "r" )	
	macroFilesPlay[name].frame = 0
	macroFilesPlay[name].totalFrames = numLines		
	macroFilesPlay[name].onComplete = params.onComplete
end

function stopPlayingMacro(params)
	local name = params.name or "default"
	io.close( macroFilesPlay[name].file )
	local onComplete = macroFilesPlay[name].onComplete	

	macroFilesPlay[name] = nil
	if(onComplete) then
		onComplete(name)
	end		
end
function recordMacro(params)
	if(params == nil) then params = {} end
	local name = params.name or "default"
	local frames = params.frames or 1000
	local path = system.pathForFile( name..".txt", system.DocumentsDirectory )
	macroFilesRecord[name] = {}
	macroFilesRecord[name].file = io.open( path, "w" )
	macroFilesRecord[name].frames = 1
	macroFilesRecord[name].initFrames = frames	
	macroFilesRecord[name].name = name
	macroFilesRecord[name].onComplete = params.onComplete
end

function stopRecordingMacro(params)
	local name = params.name or "default"
	io.close( macroFilesRecord[name].file )
	local onComplete = macroFilesRecord[name].onComplete	
	macroFilesRecord[name] = nil
	if(onComplete) then
		onComplete(name)
	end	
end



function getMacros(params)
	if(state.getMacros == nil) then
		state.getMacros = {}
	end
	for i,v in ipairs(params) do
		state.getMacros[#state.getMacros+1] = v
	end
end
function connect()
connectToDevice = true
tcpServer , _ = createTCPServer( "*", 0 )

myIP,myPort = tcpServer:getsockname()
print("ultimote server ip=", myIP, "server port= ", myPort)
broadcast = {["version"] = "1.0", ["application"] = "corona ultimote",["port"]=myPort}

waitForConnection()

end
function disconnect()
connectToDevice = false
end
Runtime:addEventListener("enterFrame", enterFrame)

function getAllMacros()
	state.getAllMacros = true
end
function setTimeouts(params)
	state.timeout = params
end
function setOption(input)
	for i,v in pairs(input) do
		options[i] = v
	end
	if(options.overrideSystem) then
		overrideSystem() 
	end
end

function sendObject(params)
	if(params and params.object) then
		params.object.ultimoteObject = true
		params.object.ultimoteImage = params.image
	end
end

function playGoogleEarthMacro(params)
	--first parse and write the macro text file from kml
	if(params == nil) then params = {} end
	local name = params.name or "default"
	local path = system.pathForFile( name..".kml", system.DocumentsDirectory )
	--get number of frames in this file
	local file = io.open( path, "r" )
	if(file == nil) then 
		path = system.pathForFile( name..".kml", system.ResourcesDirectory )
		--get number of frames in this file
		file = io.open( path, "r" )
		if(file == nil) then 
			debugPrint("Google macro "..params.name..".kml not found")
			return 
		end
	end

	path = system.pathForFile( "UltimoteGPSPath.txt", system.DocumentsDirectory )
	--path = system.pathForFile( "test.txt", system.DocumentsDirectory )
	local fileout = io.open( path, "w" )
	fileout:write(json.encode({["fps"] = options.fps}).."\n")	--first file should be fps data
	
	local line = file:read()
	local frame = {["events"] = {[1] = {}}, ["frameNum"] = 1}
	local framdelt = params.frameRatio or 30
	while(line) do
		if(line:find("coordinates")) then
			line = file:read() --this contains the coordinates
			--now being parsing
			--{"events":["altitude":-4.9521527290344,"direction":254.51319885254,"name":"location","accuracy":14.340000152588,"longitude":-95.394081967865,"latitude":29.697387010166,"speed":14,"time":-1869915168}],"frameNum":44}
			
			 local stringit = string.gmatch(line, "[%d-%.]+")
			 local previouslat,previouslong,previousalt = 0,0,0
			 local r = 6378100*3.14159/180 -- in meters
			for long,i in stringit do
				local lat, alt =   stringit(), stringit()
				local difflong,difflat,diffalt = long-previouslong,lat-previouslat,alt-previousalt
				local dir = math.atan2(difflong,difflat)*57
				if(dir<0) then dir = dir+360 end
				frame.events[1] ={		["longitude"] = long,
										["latitude"] = lat,
										["altitude"] = alt,
										["speed"] = params.speed or (((difflat*difflat)+(difflong*difflong))*r*r+(diffalt*diffalt)),
										["direction"] = params.direction or dir+90,
										["name"] = "location",
										["time"] = frame.frameNum,
										["accuracy"] = params.accuracy or 10
								}
				frame.frameNum = frame.frameNum+framdelt
				previouslat,previouslong,previousAlt =lat,long,alt
				fileout:write(json.encode(frame).."\n")
			end
		end
		line = file:read()
	end
	io.close( file )
	io.close(fileout)

	--now play the macro
	playMacro({name = "UltimoteGPSPath"})
				

	
end
