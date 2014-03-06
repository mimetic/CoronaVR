-- Show a virtual reality through the device by displaying parts of 
-- an image depending on the device attitute.





display.setStatusBar( display.HiddenStatusBar )

local panorama = require("panorama")
local onswipe = require("onSwipe")
local funx = require("funx")
local ui = require("ui")



----ULTIMOTE CODE
local useUltimote = true

local isSimulator = "simulator" == system.getInfo("environment")
if (isSimulator and useUltimote) then
	local ultimote = require("Ultimote")
	ultimote.connect()
end


------------------------------------------------------------
------------------------------------------------------------
-- HOT SPOTS

function makeHotSpot()
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
	
	return hs1
end


local screenW, screenH = display.contentWidth, display.contentHeight
local midscreenX = screenW*(0.5) 
local midscreenY = screenH*(0.5) 



--- sample group
local panogroup = display.newGroup()
local b = display.newRect(panogroup, 0,0,1540*6,800)
b.alpha = 0
local r = display.newRect(panogroup, 0,0,250,250)
r:setFillColor(130,250,130)
r.alpha = 1
r.x = panogroup.width/2
r.y = panogroup.height/2

local overlay = display.newRect(0,0,200,100)
overlayX = 0
overlayY = 0

local params = {
	filename = "panorama/panorama.jpg",
	panogroup = panogroup,
	backgroundcolor = {250,250,250},
	orientation = "landscape",
	x = midscreenX,
	y = midscreenY,
	zoom = 1,
	tiltAngle = 90,
	imageScaleX = 1,
	imageScaleY = 1,
	touchonly = false,
	navtype = "accelerometer",
	maxDistanceToSlide = screenW,
	showCloseButton = false,
	overlay = overlay,
	overlayX = overlayX,
	overlayY = overlayY,
	margins = margins,
	absolute = absolute,
	}
	
local myPano = panorama.new(params)
myPano.x = midscreenX
myPano.y = midscreenY