-- Show a virtual reality through the device by displaying parts of 
-- an image depending on the device attitute.



display.setStatusBar( display.HiddenStatusBar )

----ULTIMOTE CODE
local useUltimote = true

local isSimulator = "simulator" == system.getInfo("environment")
if (isSimulator and useUltimote) then
	local ultimote = require("Ultimote")
	ultimote.connect()
end

local dump = require("dump")

local ui = require("ui")

local onSwipe = require("onSwipe")


--ultimote.playMacro({name = "macros/accelerometer"})
--ultimote.playMacro({name = "macros/multitouch"}) --play multiple macros at once
----ULTIMOTE CODE
-------------------------------------------------

-- Show readout of x,y,z
local showInfo = false

local imagefile = "panorama.jpg"
-- For swiping, is this a portrait image or landscape?
local isPortrait = false

-- These scalers let me use a squished panoramic file. It turns out, a 1000 pixel high image is simply
-- massive. 
-- This code will require memory management and image swapping to handle the real thing, I fear.
local imageScaleX = 4
local imageScaleY = 4

local useTouch = false

local screenW, screenH = display.contentWidth, display.contentHeight
local viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
local screenOffsetW, screenOffsetH = display.contentWidth -  display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
	-- Useful constant:
local midscreenX = screenW*(0.5) 
local midscreenY = screenH*(0.5) 


local x = 0
local y = 0
local z = 0

local g = display.newGroup()
local i = display.newImage(imagefile, true)
g:insert(i)

local ileft = display.newImage(imagefile, true)
g:insert(ileft)

local iright = display.newImage(imagefile, true)
g:insert(iright)

i.x = 0
i.y = midscreenY
i:scale(imageScaleX, imageScaleY)

ileft.x = - i.contentWidth
ileft.y = midscreenY
ileft:scale(imageScaleX, imageScaleY)

iright.x = i.contentWidth
iright.y = midscreenY
iright:scale(imageScaleX, imageScaleY)

-- four directions to fill up
local fullRotationPixels = screenW * 4
local screenPixelsPerDegree = fullRotationPixels / 360

local imageWidthPixelsPerDegree = i.contentWidth / 360
--print ("imageWidthPixelsPerDegree", imageWidthPixelsPerDegree)

-- let's see... how about from looking down, to up, 90 degrees?
local imageHeightPixelsPerDegree = (i.contentHeight - screenH) / 90

local textGroup, textRect, tx, ty, tz, xpostxt, ypostxt
if (showInfo) then
	textGroup = display.newGroup()
	textRect = display.newRect(textGroup, 0,0,200,150)
	textRect.x = 50
	
	textRect:setFillColor(10,10,10,180)
	
	tx = display.newText(textGroup, math.floor(x), 0,0)
	ty = display.newText(textGroup, math.floor(y), 0,50)
	tz = display.newText(textGroup, math.floor(z), 0,100)
	xpostxt = display.newText(textGroup, math.floor(z), 100,0)
	ypostxt = display.newText(textGroup, math.floor(z), 100,50)
	
	textGroup.x = 70
	textGroup.y = 70
end



-- Beginning of the rotating 360 degree picture
local beginX = -180
local endX = 180

local minY = midscreenY -  ( i.contentHeight/2 )
local maxY = ( i.contentHeight/2 ) - midscreenY

--print (minY, maxY)


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
		
	x = x - dx
	y = y + dy
	z = z + dz
	
	-- left/right?
	-- z is for testing, use x in real world.
	-- This is really for testing, because it is much easier to test
	-- using the 'z' axis...you just spin your device on the desk.
	local xAxis = x
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
	x = xAxis

	if (showInfo) then
		updateText(x,y,z, g.x, g.y)
	end

	--print ("x,y,z", dx, dy, dz)
end
	




-- Set up the above function to receive gyroscope events if the sensor exists.
if system.hasEventSource( "gyroscope" ) then
	system.setGyroscopeInterval( 60 )
	if (not useTouch) then
	    Runtime:addEventListener( "gyroscope", onGyroscopeDataReceived )
	end
end


-------------------------------------------------
-- I hope this helps reset the viewer...
-------------------------------------------------
local function onSystemEvent( event )
	if ( event.type == "applicationExit" or event.type == "applicationSuspend" ) then
		x = 0
		y = 0
		z = 0
		touchOffsetX = 0
		g.y = 0
		if (showInfo) then
			updateText(x,y,z, 0, 0)
		end
	end
end
Runtime:addEventListener( "system", onSystemEvent );


local function flashscreen()
	local function screenFullOpaque()
		transition.to(g, { alpha = 1, time=300 } )
	end
		
	transition.to(g, { alpha = 0.5, time=300, onComplete = screenFullOpaque } )
end


local function switchNavMethod(t)
	if (t) then
	    Runtime:removeEventListener( "gyroscope", onGyroscopeDataReceived )
		flashscreen()
		--print ("Touch ",useTouch)
	else
	    Runtime:addEventListener( "gyroscope", onGyroscopeDataReceived )
		flashscreen()
		--print ("Touch ",useTouch)
	end
end


-- TOUCH
local swipeHorizontal, swipeVertical
local mX, mY
local abs = math.abs
local momentum
local momentumMultiplier = 50

function g:doNothing()
end

function g:initSwipe()
		--print ("slideview: initSwipe")
		swipeHorizontal = nil
		swipeVertical = nil
		mX = 0
		mY = 0
		if (momentum) then
			transition.cancel(momentum)
		end
		
	end

-------------------------------------------------
-- MAKE IMAGES FOLLOW FINGER DURING A SWIPE
-------------------------------------------------
function g:followSwipe(dX, dY)

	if (not dX) then
		dX = 0
	end

	if (not dY) then
		dY = 0
	end

	if (swipeHorizontal == nil and swipeVertical == nil) then
		if (abs(dX) > abs(dY)) then
			swipeHorizontal = true
			swipeVertical = false
		else
			swipeVertical = true
			swipeHorizontal = false
		end
	end
	
	local newY = g.y + dY
	if (newY > minY and newY < maxY) then
		g.y =  newY
		mY = dY
	end

	g.x = g.x + dX
	mX = dX

	-- wrap around
	if (abs(g.x) > i.contentWidth) then
		g.x = 0
	end	
	
end


function g:goLeft()
	local params = {
		x = g.x + (momentumMultiplier * mX),
		transition = easing.outQuad,
	}
	momentum = transition.to(g, params )
end

function g:goRight()
	local params = {
		x = g.x + (momentumMultiplier * mX),
		transition = easing.outQuad,
	}
	momentum = transition.to(g, params )
end

function g:goUp()
end

function g:goDown()
end


local function keepGoing (mX, mY)
end

function g:onTap ()
	useTouch = not useTouch
	switchNavMethod(useTouch)
end


local touchActions = {
			init = g.initSwipe,
			swipeLeft = g.goLeft,
			swipeRight = g.goRight,
			swipeUp = g.goUp,
			swipeDown = g.goDown,
			cancelSwipe = g.doNothing,
			swiping = g.followSwipe,
			tap = g.onTap,
			endSwipe = g.doNothing,
			}

local swipeListener = onSwipe.new(touchActions)
g.touch = swipeListener
g:addEventListener( "touch", g )


------------------------------------------------------------
------------------------------------------------------------
-- HOT SPOTS

local msg = {
	"This is a hotspot on the screen, which can show more information, jump to a page, or play a movie or sound. It can even open a website."
	}


-- Handler that gets notified when the alert closes
local function onComplete( event )
        if "clicked" == event.action then
                local i = event.index
                if 1 == i then
                        -- Do nothing; dialog will simply dismiss
                elseif 2 == i then
                        -- Open URL if "Learn More" (the 2nd button) was clicked
                        system.openURL( "http://http://www.montereybayaquarium.org/" )
                end
        end
end
local function showmsg(event)
	local alert = native.showAlert( "Info", msg[1], 
                                        { "OK", "Learn More" }, onComplete )
end

local hs1 = ui.newButton{
	default = "button-help-helv.png",
	over = "button-help-helv-over.png",
	id = 1,
	onRelease = showmsg,
	x=300,
	y=200,
}
hs1.alpha = 0.75
hs1:scale(2,2)

g:insert(hs1)


------------------------------------------------------------
------------------------------------------------------------
--switchNavMethod(t)
