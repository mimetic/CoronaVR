-- Show a virtual reality through the device by displaying parts of 
-- an image depending on the device attitute.



display.setStatusBar( display.HiddenStatusBar )

----ULTIMOTE CODE
local ultimote = require("Ultimote")
ultimote.connect()
--ultimote.playMacro({name = "macros/accelerometer"})
--ultimote.playMacro({name = "macros/multitouch"}) --play multiple macros at once
----ULTIMOTE CODE
-------------------------------------------------


local imagefile = "panorama.jpg"





local screenW, screenH = display.contentWidth, display.contentHeight
local viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
local screenOffsetW, screenOffsetH = display.contentWidth -  display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
	-- Useful constant:
local midscreenX = screenW*(0.5) 
local midscreenY = screenH*(0.5) 


local x = "0"
local y = "0"
local z = "0"

local g = display.newGroup()
local i = display.newImage(imagefile, true)
g:insert(i)
local ileft = display.newImage(imagefile, true)
g:insert(ileft)
local iright = display.newImage(imagefile, true)
g:insert(iright)

i.x = 0
i.y = 0

ileft.x = - i.width
ileft.y = 0

iright.x = i.width
iright.y = 0

-- four directions to fill up
local fullRotationPixels = screenW * 4
local screenPixelsPerDegree = fullRotationPixels / 360

local imageWidthPixelsPerDegree = i.width / 360
-- let's see... how about from looking down, to up, 90 degrees?
local imageHeightPixelsPerDegree = (i.height - screenH) / 90

local textGroup = display.newGroup()
textGroup.x = 0
textGroup.y = 0
local tx = display.newText(textGroup, math.floor(x), 100,100)
local ty = display.newText(textGroup, math.floor(y), 100,150)
local tz = display.newText(textGroup, math.floor(z), 100,200)
local xpostxt = display.newText(textGroup, math.floor(z), 200,100)
local ypostxt = display.newText(textGroup, math.floor(z), 200,150)






-- Beginning of the rotating 360 degree picture
local beginX = -180
local endX = 180

local minY = screenH -  ( i.height/2 )
local maxY = ( i.height/2 )




-- drift vars
local xDrift, yDrift, zDrift = 0,0,0


-- Called when a new gyroscope measurement has been received.
local function gyroDegrees ( event )
    -- Calculate approximate z rotation traveled via deltaTime.
    -- Remember that rotation rate is in radians per second.
    local deltaZRadians = event.zRotation * event.deltaTime
    local deltaZDegrees = deltaZRadians * (180 / math.pi)

    local deltaXRadians = event.xRotation * event.deltaTime
    local deltaXDegrees = deltaXRadians * (180 / math.pi)

    local deltaYRadians = event.yRotation * event.deltaTime
    local deltaYDegrees = deltaYRadians * (180 / math.pi)
	
	return deltaXDegrees, deltaYDegrees, deltaZDegrees
end

local function updateText(x,y,z, xpos, ypos)
	tx.text = "X:" .. math.floor(x)
	ty.text = "Y".. math.floor(y)
	tz.text = "Z".. math.floor(z)

	xpostxt.text = "XPOS:".. math.floor(xpos)
	ypostxt.text = "YPOS:".. math.floor(ypos)
end


local function onGyroscopeDataReceived( event )
	local dx, dy, dz
	dx,dy,dz = gyroDegrees(event)
		
	x = x + dx
	y = y + dy
	z = z + dz
	
	-- left/right?
	-- z is for testing, use x in real world.
	-- This is really for testing, because it is much easier to test
	-- using the 'z' axis...you just spin your device on the desk.
	local xAxis = z
	g.x =  xAxis * imageWidthPixelsPerDegree

	-- up/down
	local yAxis = y
	local newY =  yAxis * imageHeightPixelsPerDegree
	if (newY > minY and newY < maxY) then
		g.y =  newY
	end

	
	-- If we hit the end of the image, loop around
	-- 'z' is for TESTING! Should be x
	if (xAxis > endX) then
		xAxis = beginX
	elseif (xAxis < beginX) then
		xAxis = endX
	end
	
	-- Restore our temp value to its rightful owner.
	-- This is really for testing, because it is much easier to test
	-- using the 'z' axis...you just spin your device on the desk.
	z = xAxis

	updateText(x,y,z, g.x, g.y)

	--print ("x,y,z", dx, dy, dz)
end
	




-- Set up the above function to receive gyroscope events if the sensor exists.
if system.hasEventSource( "gyroscope" ) then
	system.setGyroscopeInterval( 60 )
    Runtime:addEventListener( "gyroscope", onGyroscopeDataReceived )
end
