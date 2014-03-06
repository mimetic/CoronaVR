-- panorama.lua
-- 
-- Abstract: show panoramic images library
-- This library is for showing panoramic images larger than the screen. It also includes
-- Basically, it shows a virtual reality through the device by displaying parts of 
-- an image depending on the device attitute.
-- tools for using the gyroscope for navigation.
-- Version: 0.1
-- 
-- Copyright (C) 2011 David Gross. All Rights Reserved.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of 
-- this software and associated documentation files (the "Software"), to deal in the 
-- Software without restriction, including without limitation the rights to use, copy, 
-- modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, 
-- and to permit persons to whom the Software is furnished to do so, subject to the 
-- following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all copies 
-- or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
-- INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
-- PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
-- DEALINGS IN THE SOFTWARE.

-- panorama.lua (a convenience library for showing panoramic images)

--[[


Make an overlay group for the panorama, including buttons, etc.
Then make the panorama.
The base filename, e.g. "mypano.jpg" is used to find "mypano-1.jpg", "mypano-2.jpg", to "mypano-4.jpg".
There is no file, "mypano.jpg"...it is just used to find the others.


--- sample group
local panoOverlay = display.newGroup()
local b = display.newRect(panoOverlay, 0,0,1540*6,800)
b.alpha = 0
local r = display.newRect(panoOverlay, 0,0,250,250)
r:setFillColor(130,250,130)
r.alpha = 1
r.x = panoOverlay.width/2
r.y = panoOverlay.height/2


local params = {
	filename = "panorama.jpg",
	panoOverlay = panoOverlay,
	backgroundcolor = {250,250,250},
	orientation = "landscape",
	x = midscreenX,
	y = midscreenY,
	zoom = 1,
	tiltAngle = 90,
	imageScaleX = 0.2,
	imageScaleY = 0.2,
	touchonly = false,
	navtype = "gyrovr",
	maxDistanceToSlide = screenW,
	activateTime = settings.slideview.panoramaActivateTime or 1000,
	closeButtonDefault = settings.slideview.panoramaCloseDefault ,
	closeButtonOver = settings.slideview.panoramaCloseOver,
	closeButtonX = funx.applyPercent(settings.slideview.panoramaCloseButtonX,screenW),
	closeButtonY = funx.applyPercent(settings.slideview.panoramaCloseButtonY,screenH),
	}
	
local myPano = panorama.new(params)

*****
Warning! This will mess up if images are smaller than the screen size!!!

It is risky to set the maxDistanceToSlide to greater than a screen width!

*****


]]

module(..., package.seeall)


-- These scalers let me use a squished panoramic file. It turns out, 
-- a 1000 pixel high image is simply massive. 
-- This code will require memory management and image swapping to handle the real thing, I fear.



function new(params)

	local screenW, screenH = display.contentWidth, display.contentHeight
	local midscreenX = screenW*(0.5) 
	local midscreenY = screenH*(0.5) 

	local imageScaleX = params.imageScaleX or 1
	local imageScaleY = params.imageScaleY or 1
	
	local panoGroup = display.newGroup()
	local pano = display.newGroup()	
	
	-- Set the touch navigation to false initially
	local useTouch = false
	
	local doScaling = params.doScaling or false
	-- options: gyrotilt, gyrovr, accelerometer
	local navtype = params.navtype or "accelerometer"
	
	local maxMomentusDx = tonumber(params.maxDistanceToSlide) or 0
	if (maxMomentusDx == 0) then
		if (params.orientation == "portrait") then
			maxMomentusDx = screenH
		else
			maxMomentusDx = screenW
		end
	end
		
	-------------------------------------------------
	-- Useful device values
	local screenW, screenH = display.contentWidth, display.contentHeight
	local viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
	local screenOffsetW, screenOffsetH = display.contentWidth -  display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
		-- Useful constant:
	local midscreenX = screenW*(0.5) 
	local midscreenY = screenH*(0.5) 
	-------------------------------------------------
	
	
	-- Init x,y,z
	local x = 0
	local y = 0
	local z = 0
	
	-- Beginning of the rotating 360 degree picture
	local beginX = -180
	local endX = 180
	
	-- drift vars
	local xDrift, yDrift, zDrift = 0,0,0
	
	-- Width of main pano pic, composed of four panes
	local panoWidth = 0
	local panoHeight = 0
	local leftpanewidth, rightpanewidth, leftpaneheight, rightpaneheight
	
	-------------------------------------------------
	-- Make a repeating 360 degree image display group from an image.
	-- The panoOverlay parameter is a display group of its own that is 
	-- put over the image. It might contain hotspots or pictures, too.
	-- Either we repeat the main image for wrap around,
	-- or if available, we use filename-left and filename-right.
	-------------------------------------------------
	function buildRepeatingImage(filename, panoOverlay, backgroundcolor, zoom, tiltAngle, orientation)
		
		zoom = zoom or 1
		orientation = orientation or "landscape"
		
		-- let's see... how about from looking down, to up, 90 degrees?
		local tiltAngle = tiltAngle or 90
		
		local g = display.newGroup()

		-- Load 4 images, one for each direction
		-- They should all be same size
		
		local xoff = 0
		local yoff = 0
		
		-- panes to add — repeat first and last on ends for wrapping.
		local panoimage = display.newGroup()
		local ext = {4,1,2,3,4,1}
		for k,i in ipairs(ext) do
			local f = string.sub(filename,1,-5) .. "-" .. i .. string.sub(filename,-4,-1)
			local pane = display.newImage(f, true)
			if (not pane) then
				print ("WARNING: The image file "..filename.." was not found!")
				return false
			end
			panoimage:insert(pane)
			pane:setReferencePoint(display.TopLeftReferencePoint)
			if (orientation == "landscape") then
				pane.x = xoff
				pane.y = 0
				xoff = xoff + pane.contentWidth
			else
				pane.y = yoff
				pane.x = 0
				yoff = yoff + pane.contentHeight
			end
			
			-- Calc. the total width, not including the overlap panels at beginning and end
			if (k == 1 or k == 6) then
				--pane.alpha = 0.5
			else
				panoWidth = panoWidth + (pane.contentWidth * imageScaleX)
				panoHeight = panoHeight + (pane.contentHeight * imageScaleY)
			end
			
			if (k == 1) then
				leftpanewidth = pane.width
				leftpaneheight = pane.height
			elseif (k == 6) then
				rightpanewidth = pane.width
				rightpaneheight = pane.height
			end
		end
		
		g:insert(panoimage)
		g.backgroundimage = panoimage
		
		
		-- Assume all panes the same width!
		
		-- TESTING BACKGROUND
		local backgroundrect
		if (backgroundcolor ~= nil) then
			local imagewidth = g.contentWidth
			local imageheight = g.contentHeight
			backgroundrect = display.newRect(0, 0, imagewidth, imageheight)
			--backgroundrect:scale(imageScaleX, imageScaleY)
			if (type(backgroundcolor) ~= "table") then
				backgroundcolor = funx.split(backgroundcolor, ",") or {0,0,0}
			end
			backgroundrect:setFillColor(backgroundcolor[1], backgroundcolor[2], backgroundcolor[3])
			backgroundrect.alpha = 1
			g:insert(1, backgroundrect)
			backgroundrect:setReferencePoint(display.TopLeftReferencePoint)
			backgroundrect.x = 0
			backgroundrect.y = 0
		end

		if (panoOverlay) then
			g:insert(panoOverlay)
			--g.panoOverlay = panoOverlay
			panoOverlay:setReferencePoint(display.TopLeftReferencePoint)
			if (orientation == "landscape") then
				panoOverlay.x = leftpanewidth
				panoOverlay.y = 0
			else
				panoOverlay.x = 0
				panoOverlay.y = leftpaneheight
			end
			
			--[[
			panoOverlay:setReferencePoint(display.CenterReferencePoint)
			panoOverlay.x = g.width/2
			panoOverlay.y = g.height/2
			]]
		else
			g.panoOverlay = nil
		end
		g.overlay = panoOverlay
		g:scale(imageScaleX, imageScaleY)

		return g
	end
	

	------------------------------------------------------------
	-------------------------------------------------
	-- Alert the user that something significant has happened
	local function flashscreen()
		local function screenFullOpaque()
			transition.to(pano.imagelayer.backgroundimage, { alpha = 1, time=300 } )
		end
		transition.to(pano.imagelayer.backgroundimage, { alpha = 0.5, time=300, onComplete = screenFullOpaque } )
	end
	
	
	-------------------------------------------------
	-- Switch navigation methods, touch and gyro
	-- true then non gyro or accelerometer
	local function switchNavMethod(t)
		if (t) then
			if (navtype == "gyrotilt" or navtype == "gyrovr") then
				Runtime:removeEventListener( "gyroscope", pano )
			else
				Runtime:removeEventListener( "accelerometer", pano )
			end
			flashscreen()
			--print ("Touch ",useTouch)
		else
			if (navtype == "gyrotilt" or navtype == "gyrovr") then
				Runtime:addEventListener( "gyroscope", pano )
			else
				Runtime:addEventListener( "accelerometer", pano )
			end
			flashscreen()
			funx.tellUser("Tilting is On.")
			--print ("Touch ",useTouch)
		end
	end
	


	-------------------------------------------------
	-- Update the position of the pano to handle wrapping
	-------------------------------------------------
	local function updateWrapping(pano)
		if (pano.x > panoWidth/2 ) then
			local extra = pano.x - panoWidth/2
			pano.x = -(panoWidth/2) + extra
		elseif (pano.x < -(panoWidth/2) ) then
			local extra = panoWidth/2 + pano.x
			pano.x = panoWidth/2 + extra
		end	
	end
	



	-------------------------------------------------
	-- TOUCH
	-------------------------------------------------
	local swipeHorizontal, swipeVertical
	local mX, mY
	local abs = math.abs
	local floor = math.floor
	local momentum
	local momentumMultiplier = 30
	
	-------------------------------------------------
	local function doNothing()
	end
	
	-------------------------------------------------
	local function initSwipe()
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
	local function followSwipe(self, dX, dY)
		if (not dX) then
			dX = 0
		end
	
		if (not dY) then
			dY = 0
		end
		local newY = pano.y + dY
		if (newY > pano.minY and newY < pano.maxY) then
			pano.y =  newY
			mY = dY
		end
	
		pano.x = pano.x + dX
		mX = dX
		
		-- wrap around
		--print ("pano.x:", pano.x, pano.contentWidth, panoWidth, pano.contentWidth - panoWidth)
		updateWrapping(pano)
		--[[
		if (pano.x > panoWidth/2 ) then
			pano.x = -(panoWidth/2)
		elseif (pano.x < -(panoWidth/2) ) then
			pano.x = panoWidth/2
		end	
		]]
	end
	
	
	-------------------------------------------------
	-- Slide Screen Left
	-------------------------------------------------
	local function goLeft()
		local dx = (momentumMultiplier * mX)
		if (dx < -maxMomentusDx) then
			dx = -maxMomentusDx
		end
		local params = {
			x = pano.x + dx,
			transition = easing.outQuad,
			onComplete = updateWrapping,
		}
		momentum = transition.to(pano, params )
	end
	
	-------------------------------------------------
	-- Slide Screen Right
	-------------------------------------------------
	local function goRight()
		local dx = momentumMultiplier * mX
		if (dx > maxMomentusDx) then
			dx = maxMomentusDx
		end
		local params = {
			x = pano.x + dx,
			transition = easing.outQuad,
			onComplete = updateWrapping,
		}
		momentum = transition.to(pano, params )
	end
	
	-------------------------------------------------
	local function goUp()
	end
	
	-------------------------------------------------
	local function goDown()
	end
	
	
	-------------------------------------------------
	local function keepGoing (mX, mY)
	end
	
	-------------------------------------------------
	local function onTap ()
		if (not params.touchonly) then
			useTouch = not useTouch
			switchNavMethod(useTouch)
		end
	end
	
	-------------------------------------------------
	-- END Touch
	-------------------------------------------------



	-------------------------------------------------
	-- Gyroscope Listener
	-- x,y,z are in degrees, not cartesian!
	-------------------------------------------------
	function panoGroup:gyroscope( event )
	
	--[[
		if (not panoGroup.isActive) then
			funx.tellUser("Gyro is Off.")
			return
		else
			funx.tellUser("Gyro is On.")
		end
	]]
	print ("GYRO")
		-------------------------------------------------
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
			
			--[[
			if (deltaXDegrees < 1) then
				xDrift = xDrift + deltaXDegrees
			else
				deltaXDegrees = deltaXDegrees - xDrift
			end
	
			if (deltaYDegrees < 1) then
				yDrift = yDrift + deltaYDegrees
			else
				deltaYDegrees = deltaYDegrees - yDrift
			end
	
			if (deltaZDegrees < 1) then
				zDrift = zDrift + deltaZDegrees
			else
				deltaZDegrees = deltaZDegrees - zDrift
			end
			]]
			
			--[[
			deltaXDegrees = floor(deltaXDegrees)
			deltaYDegrees = floor(deltaYDegrees)
			deltaZDegrees = floor(deltaZDegrees)
			]]
			return deltaXDegrees, deltaYDegrees, deltaZDegrees
		end

		local dX, dY, dZ
		dX,dY,dZ = gyroDegrees(event)
		
--		x = self.x
--		y = self.y
--		z = self.zoom
		
		x = x - dX
		y = y + dY
		z = z + dZ
		
		
		self.x =  x * self.imageWidthPixelsPerDegree
	
		-- up/down
		local newY =  y * self.imageHeightPixelsPerDegree
		if (newY > pano.minY and newY < pano.maxY) then
			self.y =  newY
		end
	
		
		-- If we hit the end of the image, loop around
		--[[
		-- wrap around
		--print ("pano.x:", pano.x, pano.contentWidth, panoWidth, pano.contentWidth - panoWidth)
		if (self.x > panoWidth/2 ) then
			self.x = -(panoWidth/2)
			x = beginX
		elseif (self.x < -(panoWidth/2) ) then
			self.x = panoWidth/2
			x = endX
		end	
		--]]
--print ("x,z degrees:", x,y)
		if (x > endX) then
			x = beginX
		elseif (x < beginX) then
			x = endX
		end

	end
	-------------------------------------------------
	-- END Gyroscope
	-------------------------------------------------



	-------------------------------------------------
	-- accelerometer Listener
	-------------------------------------------------
	function panoGroup:accelerometer( event )
	--[[
		if (not panoGroup.isActive) then
			return
		end
	]]
	
		tiltThreshold = 0.1
		
		if (params.orientation == "portrait") then
			dX = event.xGravity
			dY = event.yGravity
			xMagnifier = 10
			yMagnifier = 20
		else
			dY = event.xGravity
			dX = event.yGravity * -1
			xMagnifier = 20
			yMagnifier = 10
		end
		
		-- ignore if great that than this -- they have turned it too far.
		local extremeTilt = 0.5
		
		dX = floor(dX * 100)/100
		dY = floor(dY * 100)/100
		if (dX < extremeTilt and dY < extremeTilt) then 
			local newX = self.x
			local newY = self.y
			
			-- Display message and sound beep if Shake'n
			--
			if event.isShake == true then
				--print ("SHAKE!")
				self.x = params.y
				self.y = params.x
				funx.tellUser("Reset position.")
				
			elseif ( (abs(dX) > tiltThreshold) or (abs(dY) > tiltThreshold) ) then 
			if (abs(dX) > tiltThreshold) then
				newX = newX + (dX * xMagnifier)
--print ("newX", newX)
				-- wrap around
				--print ("pano.x:", pano.x, pano.contentWidth, panoWidth, pano.contentWidth - panoWidth)
				if (newX > panoWidth/2 ) then
					newX = -(panoWidth/2)
				elseif (newX < -(panoWidth/2) ) then
					newX = panoWidth/2
				end	
			end				
		
			if (abs(dY) > tiltThreshold) then
				newY = newY + (dY * yMagnifier)
--print ("newY", newY)
				if (newY > pano.minY and newY < pano.maxY) then
					pano.y =  newY
					mY = dY
				end
			end	

			--[[
			if (abs(dX) > tiltThreshold) then
				newX = self.x + (dX * xMagnifier)
				print ("X")
			end
	
			if (abs(dY) > tiltThreshold) then
				newY = self.y + (dY * yMagnifier)
				print ("Y")
			end
			]]
	
			-- up/down
			if (newY > pano.minY and newY < pano.maxY) then
				self.y =  newY
			end

			if (newX > pano.minX and newX < pano.maxX) then
				self.x =  newX
			end
			
			
			--print ("xAxis,yAxis, maxX, maxY", xAxis,yAxis, pano.maxX, pano.maxY)
			--print ("dX,dY",dX,dY,"self:", self.x, self.y)
			--]]
			
			-- Zoom!
			if (doScaling) then
				local sx = self.xScale - (dZ * damper)
				local sy = self.yScale - (dZ * damper)
				self:scale(sx,sy)
			end
			
		end
		end
	end
	-------------------------------------------------
	-- END accelerometer
	-------------------------------------------------


	-------------------------------------------------
	-- Zoom to fill screen
	-------------------------------------------------
	function panoGroup:init()
		panoGroup.alpha = 0
		panoGroup.isVisible = false
		panoGroup.isActive = false
		switchNavMethod(true)
	end


	-------------------------------------------------
	-- Activate: zoom or fade in
	-------------------------------------------------
	function panoGroup:activate(x,y)
		params = {
			alpha = 1,
			time = params.activateTime or 1000,
		}
		transition.to(panoGroup, params)
		panoGroup.isActive = true
		switchNavMethod(false)
	end
	
	
	-------------------------------------------------
	-- Deactivate:  zoom or fade out
	-------------------------------------------------
	function panoGroup:deactivate(x,y)
		local function alldone()
			panoGroup.isVisible = false
		end
		
		params = {
			alpha = 0,
			time = params.activateTime or 1000,
			onComplete = alldone,
		}
		transition.to(panoGroup, params)
		panoGroup.isActive = false
		switchNavMethod(true)
	end
	
	
	
	local function addCloseButton(params)
		local default = params.closeButtonDefault or "_ui/button-cancel-round.png"
		local over = params.closeButtonOver or "_ui/button-cancel-round-over.png"
		-- Now make close button
		closeButton = ui.newButton{
			default = default,
			over = over,
			onRelease = panoGroup.deactivate,
			x=0,
			y=0,
		}
		
		closeButton:setReferencePoint(display.TopLeftReferencePoint)
		-- allow 10 px for the shadow of the popup background
		local x = params.closeButtonX or (screenW - closeButton.width - 10)
		local y = params.closeButtonY or (screenH - closeButton.height - 10)
		local x, y, ref = funx.positionObjectWithReferencePoint(x, y, screenW, screenH, params.margins, params.absolute)
		
		closeButton:toFront()
		panoGroup:insert(closeButton)
		panoGroup.closeButton = closeButton
		closeButton:setReferencePoint(display[ref])

		closeButton.x = x
		closeButton.y = y
	end
	
	

	-------------------------------------------------
	-------------------------------------------------
	-------------------------------------------------

	params.filename = params.filename or "panorama.jpg"
	
	if (not params.filename) then 
		return false
	end

	params.x = params.x or midscreenX
	params.y = params.y or midscreenY
	params.zoom = params.zoom or 1
	params.tiltAngle = params.tiltAngle or 90
	params.orientation = params.orientation or "landscape"
	local panoImage = buildRepeatingImage(params.filename, params.panoOverlay, params.backgroundcolor, params.zoom, params.tiltAngle, params.orientation)
	
	navtype = params.navtype or "accelerometer"
	
	pano:insert(panoImage)
	pano.imagelayer = panoImage
	
	pano:setReferencePoint(display.CenterReferencePoint)
	pano.x = params.x
	pano.y = params.y
	
	-- Values for scrolling
	pano.minX = midscreenX -  ( panoImage.contentWidth/2 )
	pano.maxX = ( panoImage.contentWidth/2 ) + midscreenX
	pano.minY = midscreenY -  ( panoImage.contentHeight/2 )
	pano.maxY = ( panoImage.contentHeight/2 ) - midscreenY
	-- four directions to fill up, N,S,E,W
	pano.imageWidthPixelsPerDegree = panoWidth / 360
	--print ("imageWidthPixelsPerDegree", imageWidthPixelsPerDegree)

	pano.imageHeightPixelsPerDegree = (panoHeight - screenH) / params.tiltAngle
		
	pano.originalScale = params.originalScale or 1

	-------------------------------------------------
	-- Add touch listeners
	local touchActions = {
				init = initSwipe,
				swipeLeft = goLeft,
				swipeRight = goRight,
				swipeUp = goUp,
				swipeDown = goDown,
				cancelSwipe = doNothing,
				swiping = followSwipe,
				tap = onTap,
				endSwipe = doNothing,
				allowHVSwiping = true,
				}
	
	local swipeListener = onSwipe.new(touchActions)
	pano.touch = swipeListener
	pano:addEventListener( "touch", pano )
	
	
	if (not params.touchonly) then
		if (navtype == "gyrotilt" or navtype == "gyrovr") then
			-------------------------------------------------
			-- Add gyro listeners
			system.setGyroscopeInterval( 62 )
			Runtime:addEventListener( "gyroscope", panoGroup )
		else
			-------------------------------------------------
			-- Add accelerometer listeners
			pano.damper = 10
			system.setAccelerometerInterval( 62.0 )	-- default: 75.0 (30fps) or 62.0 for 60 fps
			Runtime:addEventListener( "accelerometer", panoGroup )
		end
	end
	
	if (params.showCloseButton) then
		addCloseButton(params)
	end
	panoGroup:insert(pano)
	pano.x = 0
	pano.y = 0
	
	-- Static Overlay
	if (params.overlay) then
		panoGroup:insert(params.overlay)
		local x, y, ref = funx.positionObjectWithReferencePoint(params.overlayX, params.overlayY, screenW, screenH, params.margins, params.absolute)
		params.overlay:setReferencePoint(display[ref])
		--print (x,y,ref)
		params.overlay.x = x or 0
		params.overlay.y = y + midscreenY
	end
	if (params.showCloseButton) then
		panoGroup.closeButton:toFront()
	end
	return panoGroup
	
end -- new