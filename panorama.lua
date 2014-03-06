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
	noWrap = false,
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

--module(..., package.seeall)

local funx = require ("funx")

local onSwipe = require ("onSwipe")


local P = {}


function P.new(params)
	
	params = params or {}
	
	-- Group to return from new()
	local panoGroup = display.newGroup()
	--panoGroup.anchorChildren = true
	
	-- A way to track all added Runtime handlers so we can properly delete the object
	panoGroup._mb_runtimeHandlers = {}
	


	-- Ultimote simulator
	local isSimulator = "simulator" == system.getInfo("environment")
	local mysetAccelerometerInterval
	if (isSimulator and params.ultimote) then
		mysetAccelerometerInterval = 15
	else
		mysetAccelerometerInterval = 62
	end


	--local widget = require "widget-v1"
	local widget = require "widget"

	local max = math.max
	local min = math.min

	local screenW, screenH = display.contentWidth, display.contentHeight
	local midscreenX = screenW*(0.5) 
	local midscreenY = screenH*(0.5) 

	local imageScaleX = params.imageScaleX or 1
	local imageScaleY = params.imageScaleY or 1
	
	
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
		
	local maxMomentusDy = tonumber(params.maxDistanceToSlide) or 0
	if (maxMomentusDy == 0) then
		if (params.orientation == "portrait") then
			maxMomentusDy = screenH
		else
			maxMomentusDy = screenW
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
	local leftpanewidth, leftpaneHeight, rightpanewidth, leftpaneheight, rightpaneheight
	
	-------------------------------------------------
	-- Make a repeating 360 degree image display group from an image.
	-- The panoOverlay parameter is a display group of its own that is 
	-- put over the image. It might contain hotspots or pictures, too.
	-- Either we repeat the main image for wrap around,
	-- or if available, we use filename-left and filename-right.
	-------------------------------------------------
	local function buildRepeatingImage(filename, path, basedir, panoOverlay, backgroundcolor, zoom, tiltAngle, orientation, noWrap, multifile)
		
		if (multifile ~= false) then
			multifile = true
		end
		
		zoom = zoom or 1
		orientation = orientation or "landscape"
		-- let's see... how about from looking down, to up, 90 degrees?
		local tiltAngle = tiltAngle or 90
		
		local g = display.newGroup()
		g.anchorChildren = true

		-- Load 4 images, one for each direction
		-- They should all be same size
		
		local xoff = 0
		local yoff = 0
		
		-- panes to add — repeat first and last on ends for wrapping.
		local panoimage
		
		if (multifile ~= false) then
		
			panoimage = display.newGroup()
			panoimage.anchorChildren = true

			local ext, panestart,panend
			
			if (noWrap) then
				panestart = 1
				panend = 4
				ext = {1,2,3,4}
			else
				panestart = 1
				panend = 6
				ext = {4,1,2,3,4,1}
			end
			
			--for k,i in ipairs(ext) do
			for k=panestart,panend,1 do
				local i = ext[k]
				local f = string.sub(filename,1,-5) .. "-" .. i .. string.sub(filename,-4,-1)
				local pane = funx.loadImageFile(f, path, basedir)
				if (not pane) then
					print ("WARNING: The image file "..filename.." was not found!")
					return false
				end
				panoimage:insert(pane)
				funx.anchorTopLeft(pane)
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
					if (orientation == "landscape") then
						panoWidth = panoWidth + (pane.contentWidth * imageScaleX)
					else
						panoHeight = panoHeight + (pane.contentHeight * imageScaleY)
					end
				end
				
				if (k == 1) then
					leftpanewidth = pane.width
					leftpaneheight = pane.height
				elseif (k == 6) then
					rightpanewidth = pane.width
					rightpaneheight = pane.height
				end
			end
		else
			-- true = don't rescale to fit screen
			panoimage = funx.loadImageFile(params.filename, path, basedir)

			if (not panoimage) then
				print ("ERROR: the file '",params.filename,"' is missing!")
				return display.newGroup()
			end
			panoWidth = panoimage.width
			panoHeight = panoimage.height
			leftpanewidth = 0
			leftpaneheight = 0
		end
		
		g:insert(panoimage)
		g.backgroundimage = panoimage
		funx.anchorTopLeftZero(panoimage)
		
		-- Assume all panes the same width!
		
		-- BACKGROUND
		local backgroundrect
		if (backgroundcolor ~= nil) then
			local imagewidth = max(g.contentWidth, funx.percentOfScreenWidth(funx.getValue(params.backgroundWidth)) or g.contentWidth)
			imagewidth = imagewidth * imageScaleX
			local imageheight = max(g.contentHeight, funx.percentOfScreenHeight(funx.getValue(params.backgroundHeight)) or g.contentHeight)
			imageheight = imageheight * imageScaleY

			backgroundrect = display.newRect(0, 0, imagewidth, imageheight)
			--backgroundrect:scale(imageScaleX, imageScaleY)
			backgroundcolor = funx.stringToColorTable(backgroundcolor)
			backgroundrect:setFillColor( unpack(backgroundcolor) )
			backgroundrect.alpha = 1 --backgroundcolor[4]/255 or 1
			g:insert(1, backgroundrect)
			funx.anchorTopLeftZero(backgroundrect)
		end
		if (panoOverlay) then
			-- Should have been hidden previously so it won't appear until built!
			-- Now we must make it visible.
			panoOverlay.isVisible = true
			g:insert(panoOverlay)
			g.panoOverlay = panoOverlay
			funx.anchorTopLeftZero(panoOverlay)
			
			local zeroX, zeroY
			if (noWrap) then
				zeroX = 0
				zeroY = 0
			else
				zeroX = leftpanewidth
				zeroY = leftpaneheight
			end
			
			if (orientation == "landscape") then
				panoOverlay.x = zeroX or panoWidth
				panoOverlay.y = 0
			else
				panoOverlay.x = 0
				panoOverlay.y = zeroY or panoHeight
			end
			--[[
			funx.anchorCenter(panoOverlay)
			panoOverlay.x = g.width/2
			panoOverlay.y = g.height/2
			]]
		else
			g.panoOverlay = nil
		end
		
		g.overlay = panoOverlay
		if (imageScaleX ~= 1 and imageScaleY ~= 1) then
			g:scale(imageScaleX, imageScaleY)
		end
		if (orientation == "landscape") then
			panoHeight = g.contentHeight
		else
			panoWidth = g.contentWidth
		end

		return g
	end
	

	-------------------------------------------------
	-- Switch navigation methods, touch and gyro
	-- true then non gyro or accelerometer
	-- ANDROID DOES NOT HAVE GYRO!
	local function switchNavMethod(useTouch)
		local isAndroid = "Android" == system.getInfo("platformName")

		if (panoGroup.technique ~= "widget") then
			if (useTouch) then
				if (navtype == "gyrotilt" or navtype == "gyrovr") then
					Runtime:removeEventListener( "gyroscope", panoGroup )
				else
					Runtime:removeEventListener( "accelerometer", panoGroup )
				end
				funx.flashscreen()
				if (not panoGroup.settings.touchonly) then
					funx.tellUser("Tilt Navigation is Off.")
				end
				--print ("Touch ",useTouch)
			elseif (not panoGroup.settings.touchonly and not isAndroid and panoGroup.tilting and panoGroup.technique) then
				if (navtype == "gyrotilt" or navtype == "gyrovr") then
					system.setGyroscopeInterval( mysetAccelerometerInterval )
					Runtime:addEventListener( "gyroscope", panoGroup )
					panoGroup._mb_runtimeHandlers[#panoGroup._mb_runtimeHandlers+1] = { "gyroscope", panoGroup }
				else
					system.setAccelerometerInterval( mysetAccelerometerInterval )	-- default: 75.0 (30fps) or 62.0 for 60 fps
					Runtime:addEventListener( "accelerometer", panoGroup )
					panoGroup._mb_runtimeHandlers[#panoGroup._mb_runtimeHandlers+1] = { "accelerometer", panoGroup }
				end
				funx.flashscreen()
				funx.tellUser("Tilt Navigation is On.")
				--print ("Touch ",useTouch)
			end
		end
	end
	


	-------------------------------------------------
	-- Update the position of the pano to handle wrapping
	-------------------------------------------------
	local function updateWrapping(pano)
		if (not pano.noWrap) then
			if (pano.x > panoWidth/2 ) then
				local extra = pano.x - panoWidth/2
				pano.x = -(panoWidth/2) + extra
			elseif (pano.x < -(panoWidth/2) ) then
				local extra = panoWidth/2 + pano.x
				pano.x = panoWidth/2 + extra
			end	
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
		return true
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
		
		local newY = self.y + dY
		local newX = self.x + dX

		--print (newX, newY, self.minX, self.maxX)
		if (self.settings.orientation ~= "portrait") then
			-- NO vertical wrapping
			if (newY > self.minY and newY < self.maxY) then
				self.y =  newY
				mY = dY
			end
			
			-- YES horizontal wrapping
			if (self.noWrap) then
				if (newX > self.minX and newX < self.maxX) then
					self.x =  newX
					mX = dX
				end
			else
				self.x = self.x + dX
				mX = dX
				updateWrapping(self)
			end
		else

			-- NO vertical wrapping
			if (newY > self.minY and newY < self.maxY) then
				self.y =  newY
				mY = dY
			end
			
			-- YES horizontal wrapping
			if (self.noWrap) then
				if (newX > self.minX and newX < self.maxX) then
					self.x =  newX
					mX = dX
				end
			else
				self.x = self.x + dX
				mX = dX
				updateWrapping(self)
			end
		end
		
	end
	
	
	-------------------------------------------------
	-- Slide Screen
	-------------------------------------------------
	local function goOnSliding(event)

		local pano = event.target
		
		-- X direction
		local dx = momentumMultiplier * mX
		if (dx > maxMomentusDx) then
			dx = maxMomentusDx
		end
		if (dx < -maxMomentusDx) then
			dx = -maxMomentusDx
		end
		local newX = max(pano.x + dx, pano.minX)
		newX = min(newX, pano.maxX)
		
		-- Y direction
		local dy = (momentumMultiplier * mY)
		if (dy < -maxMomentusDy) then
			dy = -maxMomentusDy
		end
		if (dy > maxMomentusDy) then
			dy = maxMomentusDy
		end
		local newY = max(pano.y + dy, pano.minY)
		newY = min(newY, pano.maxY)

		local params = {
			x = newX,
			y = newY,
			transition = easing.outQuad,
			onComplete = updateWrapping,
		}
		momentum = transition.to(pano, params )
	end
	
	
	-------------------------------------------------
	-- Slide Screen Left
	-------------------------------------------------
	local function goLeft(event)
		goOnSliding(event)
	end
	
	-------------------------------------------------
	-- Slide Screen Right
	-------------------------------------------------
	local function goRight(event)
		goOnSliding(event)
	end
	
	-------------------------------------------------
	local function goUp(event)
		goOnSliding(event)
	end
	
	-------------------------------------------------
	local function goDown(event)
		goOnSliding(event)
	end
	
	-------------------------------------------------
	local function onTap (event)
		local pano = event.target
		local w = pano.contentWidth
		local h = pano.contentHeight
		local x = event.x
		local y = event.y

		if (not pano.settings.touchonly) then
			useTouch = not useTouch
			switchNavMethod(useTouch)
		end
		
		--[[
		------- FOR DEVELOPMENT: SHOW POINT WHERE TAPPED
		local mapx = w - (pano.x + (w/2) ) - (screenW/2)
		local mapy = h - (pano.y + (h/2) ) - (screenH/2)
		mapx = mapx + x
		mapy = mapy + y
		
		-- offset for item size 150x50
		local itemsize = {w=150, h=50}
		mapx2 = mapx - (itemsize.w/2)
		mapy2 = mapy - (itemsize.h/2)
		
		local px = mapx/w
		local px2 = mapx2/w
		
		local py = mapy2/h
		local py2 = (mapy2+(itemsize.h/2))/h
		
		px = math.floor( px * 1000)/10
		px2 = math.floor( px2 * 1000)/10
		py = math.floor( py * 1000)/10
		py2 = math.floor( py2 * 1000)/10
		
print ("panorama: onTap: For item "..itemsize.w.."x"..itemsize.h..", LEFT x,y on tap:",px.."%", py.."%", ", CENTER X: x="..px2.."% TOP Y=", py2.."%")
--print ("panorama: onTap: x,y on tap:",x,y, mapx, mapy, px.."%", py.."%")
		]]

	end
	
	-------------------------------------------------
	-- END Touch
	-------------------------------------------------



	-------------------------------------------------
	-- Gyroscope Listener
	-- x,y,z are in degrees, not cartesian!
	-------------------------------------------------
	local function gyroscope( event )
	
	
	--print ("GYRO")
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

		local pano = event.target
		local dX, dY, dZ
		dX,dY,dZ = gyroDegrees(event)
		
--		x = self.x
--		y = self.y
--		z = self.zoom
		
		-- Stored x,y,z values based on initial settings.
		x = x - dX
		y = y + dY
		z = z + dZ
		
		-- up/down
		local newY =  y * pano.imageHeightPixelsPerDegree
		if (newY > pano.minY and newY < pano.maxY) then
			pano.y =  newY
		end
	
		-- Wrapping:
		
		if (not pano.noWrap) then
			pano.x =  x * pano.imageWidthPixelsPerDegree
			-- If we hit the end of the image, loop around
			if (x > endX) then
				x = beginX
			elseif (x < beginX) then
				x = endX
			end
		else
			local newX = x * pano.imageWidthPixelsPerDegree
			if (newX > pano.minX and newX < pano.maxX) then
				pano.x =  newX
			end
		end

	end
	-------------------------------------------------
	-- END Gyroscope
	-------------------------------------------------



	-------------------------------------------------
	-- accelerometer Listener
	-------------------------------------------------
	local function accelerometer( event )
	--[[
		if (not panoGroup.isActive) then
			return
		end
	]]
	
	--print ("Accel called")
		local dX, dY, dZ, xMagnifier, yMagnifier
	
		local tiltThreshold = 0.1
		
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
		local pano = event.pano
		
		dX = floor(dX * 100)/100
		dY = floor(dY * 100)/100
		if (dX < extremeTilt and dY < extremeTilt) then 
			local newX = pano.x
			local newY = pano.y
			
			-- Display message and sound beep if Shake'n
			--
			if event.isShake == true then
				--print ("SHAKE!")
				pano.x = params.y
				pano.y = params.x
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

			-- up/down
			if (newY > pano.minY and newY < pano.maxY) then
				pano.y =  newY
			end

			if (newX > pano.minX and newX < pano.maxX) then
				pano.x =  newX
			end
			
			
			-- Zoom!
			if (doScaling) then
				local sx = pano.xScale - (dZ * pano.damper)
				local sy = pano.yScale - (dZ * pano.damper)
				pano:scale(sx,sy)
			end
			
		end
		end
	end
	-------------------------------------------------
	-- END accelerometer
	-------------------------------------------------

	-------------------------------------------------
	-- add a close button to the pano group
	function panoGroup:addCloseButton(params)
		
		local function closePanoGroup(event)
			self:deactivate()
		end
	
		
		local default = params.closeButtonDefault or "_ui/button-cancel-round.png"
		local over = params.closeButtonOver or "_ui/button-cancel-round-over.png"
		-- Now make close button
		local closeButton = widget.newButton{
			id = "closepanorama",
			defaultFile = default,
			overFile = over,
			onRelease = closePanoGroup,
		}
		funx.anchorTopLeft(closeButton)
		-- allow 10 px for the shadow of the popup background
		local ref = "TopLeft"
		local x = params.closeButtonX or (screenW - closeButton.width - 10)
		local y = params.closeButtonY or (screenH - closeButton.height - 10)
		x, y, ref = funx.positionObjectWithReferencePoint(x, y, screenW, screenH, params.margins, params.absolute)
		
		self:insert(closeButton)
		closeButton:toFront()
		
		self.closeButton = closeButton

		funx.setAnchorFromReferencePoint(closeButton, ref)
		closeButton.x = x
		closeButton.y = y 
	end
	
	

	-------------------------------------------------
	-- Load the images into the panoGroup
	-- Must call "buildPanoStructure" first, to get the structure in
	function panoGroup:loadImages()
		
		--funx.activityIndicator(true)

		local settings = self.settings

		local pano
		local panoImage
		
--for i=1,1000 do		
		panoImage = buildRepeatingImage(params.filename, panoGroup.path, panoGroup.basedir, settings.panoOverlay, settings.backgroundcolor, settings.zoom, settings.tiltAngle, settings.orientation, settings.noWrap, settings.multifile)

		if (true or not settings.noWrap) then
			------------------------------------
			-- USE MY 360 WRAPPING, TILTING METHOD
			pano  = display.newGroup()
			pano.anchorChildren = true
			
			pano:insert(panoImage)
			pano.content = panoImage
			funx.anchorTopLeftZero(panoImage)

			pano.orientation = settings.orientation
			
			-- Values for scrolling
			pano.noWrap = settings.noWrap or false
			
			pano.originalScale = settings.originalScale or 1

			if (settings.orientation == "landscape") then
				if (pano.noWrap) then
					pano.minX = midscreenX -  ( panoImage.contentWidth/2 )
					pano.maxX = ( panoImage.contentWidth/2 ) - midscreenX
					pano.minY = midscreenY -  ( panoImage.contentHeight/2 )
					pano.maxY = ( panoImage.contentHeight/2 ) - midscreenY
				else
					pano.minX = midscreenX -  ( panoImage.contentWidth/2 )
					pano.maxX = ( panoImage.contentWidth/2 ) + midscreenX
					pano.minY = midscreenY -  ( panoImage.contentHeight/2 )
					pano.maxY = ( panoImage.contentHeight/2 ) - midscreenY
				end
			else
				-- PORTRAIT
				if (pano.noWrap) then
					pano.minX = midscreenX -  ( panoImage.contentWidth/2 )
					pano.maxX = ( panoImage.contentWidth/2 ) - midscreenX
					pano.minY = midscreenY -  ( panoImage.contentHeight/2 )
					pano.maxY = ( panoImage.contentHeight/2 ) - midscreenY
				else
					pano.minX = midscreenX -  ( panoImage.contentWidth/2 )
					pano.maxX = ( panoImage.contentWidth/2 ) + midscreenX
					pano.minY = midscreenY -  ( panoImage.contentHeight/2 )
					pano.maxY = ( panoImage.contentHeight/2 ) - midscreenY
				end
			end
			-- four directions to fill up, N,S,E,W
			pano.imageWidthPixelsPerDegree = panoWidth / 360
			--print ("imageWidthPixelsPerDegree", imageWidthPixelsPerDegree)
		
			pano.imageHeightPixelsPerDegree = (panoHeight - screenH) / settings.tiltAngle
				
			pano.originalScale = settings.originalScale or 1

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
			
			-- Slows down zooming which doesn't work right now
			pano.damper = 10
			
		else
			------------------------------------
			-- USE WIDGET SCROLLVIEW
--print ("Panorama: loadImages: Using widget technique")
			self.technique = "widget"
			self.tilting = false
			-- WRONG...pano = ...
			pano = widget.newScrollView{
				width = screenW,
				height = screenH,
				scrollWidth = panoImage.contentWidth,
				scrollHeight = panoImage.contentHeight,
				backgroundColor = settings.slideview.panoramaBackgroundColor,
			}
	
			pano:insert(panoImage)
			funx.anchorTopLeftZero(panoImage)
			pano:scrollToPosition(-pano.contentWidth/2 + midscreenX,-pano.contentHeight/2 + midscreenY,0)
	
		
		end
		
		pano.settings = settings
		
		self:insert(pano)
		self.pano = pano
		pano:toBack()
		
		-- Set the pano orientation
		if (settings.orientation == "landscape") then
			funx.anchorCenter(pano)
			pano.x = 0
			pano.y = 0
		else
			funx.anchorCenter(pano)
			pano.x = 0
			pano.y = 0
		end

		self.loaded = true

	end


	-------------------------------------------------
	-- Load the images into the panoGroup
	function panoGroup:buildPanoStructure()

		local settings = self.settings
		
		if (true or not settings.noWrap) then
			------------------------------------
			-- USE MY 360 WRAPPING, TILTING METHOD

			self.technique = "custom"
			self.tilting = true
			
			navtype = settings.navtype or "accelerometer"
		else
			------------------------------------
			-- USE WIDGET SCROLLVIEW
			
			self.technique = "widget"
			self.tilting = false

		end


		-- Create before adding the overlay...can't remember why...
		if (settings.showCloseButton) then
			self:addCloseButton(settings)
		end

		self.loaded = false
		
		-- Add invisible rect for positioning
		--funx.addPosRect(self)
		
		-- Add static Overlay - Does not move
		if (settings.overlay) then
			self:insert(settings.overlay)
			self.overlay = settings.overlay
			local x, y, ref = funx.positionObjectWithReferencePoint(settings.overlayX, settings.overlayY, screenW, screenH, settings.margins, settings.absolute)
			funx.setAnchorFromReferencePoint(settings.overlay, ref)
			--print (x,y,ref)
			settings.overlay.x = x or 0
			settings.overlay.y = y + midscreenY
		end
		
		if (settings.showCloseButton) then
			self.closeButton:toFront()
		end
		
	end


	-------------------------------------------------
	-- Initialize the panorama
	-------------------------------------------------
	function panoGroup:init(params)
		self.alpha = 0
		self.isVisible = false
		self.isActive = false
		--switchNavMethod(true)
	end



	-------------------------------------------------
	-- PUBLIC
	-------------------------------------------------

	-------------------------------------------------
	-- Activate: show and make active the panorama
	-- If the preBuild is not set, we have to build it now.
	-- Turns out, it is a slow load, so better to do just when we need it.
	-------------------------------------------------
	function panoGroup:activate()
		if (not self.loaded) then
			self:loadImages()
		end

		self.isVisible = true
		
		params = {
			alpha = 1,
			time = params.activateTime or 1000,
		}
		transition.to(self, params)
		self.isActive = true
		switchNavMethod(false)
	end
	
	
	-------------------------------------------------
	-- Deactivate:  zoom or fade out
	-------------------------------------------------
	function panoGroup:deactivate()

			local function alldone()
				self.isVisible = false
			end
		
		local params = {
			alpha = 0,
			time = params.activateTime or 1000,
			onComplete = alldone,
		}
		transition.to(self, params)
		self.isActive = false
		
		-- This will remove Runtime events
		switchNavMethod(true)
	end
		
	
	-------------------------------------------------
	-- Remove all runtime handlers from the slideview object.
	-- This has to be done if you want to destroy it.
	-- *** Probably not needed, since deactivate will do this! ***
	-------------------------------------------------
	function panoGroup:removeRuntimeHandlers()
		for i, myHandler in ipairs(self._mb_runtimeHandlers) do
			Runtime:removeEventListener( myHandler[1], myHandler[2] )
		end
	end
	
	

	-------------------------------------------------
	-- MAIN
	-------------------------------------------------
	
	panoGroup.path = params.bookpath or "_user"
	panoGroup.basedir = params.basedir or system.ResourceDirectory
	
	params.filename = params.filename or "panorama.jpg"
	--params.filename = funx.replaceWildcard(params.filename, panoGroup.path)
	
	if (not params.filename) then 
		return false
	end

	params.x = params.x or midscreenX
	params.y = params.y or midscreenY
	params.zoom = params.zoom or 1
	params.tiltAngle = params.tiltAngle or 90
	params.orientation = params.orientation or "landscape"
	
	panoGroup.settings = params
	panoGroup.loaded = false

	panoGroup:buildPanoStructure()

	if (panoGroup.preload) then
		panoGroup:loadImages()
	end
	
	panoGroup:init(params)
	return panoGroup
	
end -- new


	

return P