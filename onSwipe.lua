-- onSwipe.lua
-- 
-- Version 0.1 
--
-- Copyright (C) 2010 David I. Gross. All Rights Reserved.
--
-- This software is is protected by the author's copyright, and may not be used, copied,
-- modified, merged, published, distributed, sublicensed, and/or sold, without
-- written permission of the author.
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
--
-- ===================
-- Capture swipes.
-- ===================

module(..., package.seeall)

local floor = math.floor
local abs = math.abs
local startPosX = 0
local startPosY = 0
local prevPosX = 0
local prevPosY = 0
local startTime = 0

local minTapTime = 10
local maxTapTime = 700

local swipeDistance = 40

local dragDistance = 0
local dragDistanceX = 0
local dragDistanceY = 0

function new(actions)  

	local allowHVSwiping = actions.allowHVSwiping or false

	local function swipeLeft(touch)
		if (actions.swipeLeft) then
			-- print ("swipeLeft")
			actions.swipeLeft(touch)
			return true
		else
			print ("Missing function for SwipeLeft")
			return false
		end
	end

	local function swipeRight(touch)
		if (actions.swipeRight) then
			-- print ("swipeRight")
			actions.swipeRight(touch)
			return true
		else
			print ("Missing function for swipeRight")
			return false
		end
	end

	local function swipeUp(touch)
		if (actions.swipeUp) then
			-- print ("swipeUp")
			actions.swipeUp(touch)
			return true
		else
			print ("Missing function for swipeUp")
			return false
		end
	end

	local function swipeDown(touch)
		if (actions.swipeDown) then
			-- print ("swipeDown")
			actions.swipeDown(touch)
			return true
		else
			print ("Missing function for swipeDown")
			return false
		end
	end

	local function cancelSwipe(touch)
		if (actions.cancelSwipe) then
			-- print ("cancelSwipe")
			actions.cancelSwipe(touch)
			return true
		else
			print ("Missing function for Cancel phase.")
			return false
		end
	end


	local function swiping(target, dX, dY, x, y)
		if (actions.swiping) then
			actions.swiping(target, dX, dY, x, y)
			return true
		else
			print ("Missing function for Swiping phase.")
			return false
		end
	end

	local function tap(touch)
		if (actions.tap) then
			actions.tap(touch)
			return true
		else
			print ("Missing tap function")
			return false
		end
	end

	local function initSwipe(touch)
		if (actions.init) then
			actions.init(touch)
			return true
		else
			print ("Missing init function")
			return false
		end
	end

	local function endSwipe(touch)
		if (actions.endSwipe) then
			actions.endSwipe(touch)
			return true
		else
			print ("Missing endSwipe function")
			return false
		end
	end


	function touchListener (self, touch) 
		local phase = touch.phase
		if ( phase == "began" ) then
			display.getCurrentStage():setFocus( self )
			self.isFocus = true
			startPosX = touch.x
			prevPosX = touch.x
			startPosY = touch.y
			prevPosY = touch.y
			startTime = touch.time
			initSwipe(touch)
			
		elseif( self.isFocus ) then

			if ( phase == "moved" ) then
				local deltaX = touch.x - prevPosX
				local deltaY = touch.y - prevPosY
				prevPosX = touch.x
				prevPosY = touch.y
				
				-- Unless this is some free-form swiping, then
				-- A vertical movement should not be confused with a horizontal
				if (not allowHVSwiping) then
					if (abs(deltaX) > abs(deltaY)) then
						deltaY = 0
					else
						deltaX = 0
					end
				end
				
				if (abs(deltaX) + abs(deltaY) > 0) then
					swiping(self, deltaX, deltaY, touch.x, touch.y)
				end

			elseif ( phase == "ended" or phase == "cancelled" ) then
				-- print("phase "..phase)

				-- drag distance in two dimensions
				dragDistance = math.floor(math.sqrt( math.pow(touch.x - startPosX,2) + math.pow(touch.y - startPosY,2)))
				-- drag distances for x and y
				dragDistanceX = touch.x - startPosX
				dragDistanceY = touch.y - startPosY
				
				-- tap, not a drag
				if (dragDistance < 10) then
					local timePassed = system.getTimer() - startTime
					--print ("Time for tap: "..timePassed)
					if ( timePassed > minTapTime and timePassed < maxTapTime ) then
						tap(touch)
					end
					cancelSwipe(touch)
				else
					-- must have dragged a minimum distance
					if (dragDistance < swipeDistance) then
						cancelSwipe(touch)
						-- print ("** Drag distance X ("..dragDistanceX.." < 100 : NO SWIPE!)")
					else 
						-- horizontal or vertical drag?
						local dragAxis = "vertical"
						if (abs(dragDistanceX) > abs(dragDistanceY)) then
							dragAxis = "horizontal"
						end
		
						-- print("onSwipe: Axis: " .. dragAxis .. " dragDistance: " .. dragDistance)
		
						-- Which way dragged?
						if (dragAxis == "horizontal") then
							if (dragDistanceX < (-1*swipeDistance)) then
								swipeLeft(touch)
							else
								swipeRight(touch)
							end
						elseif (dragDistance > swipeDistance) then
							-- Vertical
							if (dragDistanceY < (-1*swipeDistance)) then
								swipeUp(touch)
							else
								swipeDown(touch)
							end
						else
							cancelSwipe(touch)
							-- print ("dragAxis = " .. dragAxis .. " AND no vertical swipe. CancelSwipe called." )
						end
		
						if ( phase == "cancelled" ) then
							print ("onSwipe 195: phase = cancelled")
							cancelSwipe(touch)
						end
					end
				end
				-- Allow touch events to be sent normally to the objects they "hit"
				display.getCurrentStage():setFocus( nil )
				self.isFocus = false
				
				-- run end of swipe handler
				endSwipe(touch)
			end
		end

		return true

	end


	return touchListener

end