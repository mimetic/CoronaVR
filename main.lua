-- Show a virtual reality through the device by displaying parts of 
-- an image depending on the device attitute.



--display.setDrawMode( "wireframe", false )

display.setStatusBar( display.HiddenStatusBar )

local panorama = require("panorama")
local onswipe = require("onSwipe")
local funx = require("funx")
local widget = require("widget")



----ULTIMOTE CODE
local useUltimote = false

local isSimulator = "simulator" == system.getInfo("environment")
if (isSimulator and useUltimote) then
	local ultimote = require("Ultimote")
	ultimote.connect()
end


-- ----------------------------------------------------------
-- ----------------------------------------------------------
-- HOT SPOTS

local function makeHotSpot()
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
	
	local hs1 = widget.newButton{
		id = 1,
		defaultFile = "button-help-helv.png",
		overFile = "button-help-helv-over.png",
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



-- ----------------------------------------------------------
-- Sample overlay object
local overlay = display.newGroup()
overlay.anchorChildren = true
local overlaybg = display.newRect(overlay, 0,0,200,100)
overlaybg:setFillColor(1,1,1,0.8)
funx.anchorCenterZero(overlay)

local options = 
{
    parent = overlay,
    text = "This is an overlay object.",     
    x = 20,
    y = 20,
    width = 160,     --required for multi-line and alignment
    font = native.systemFontBold,   
    fontSize = 18,
    align = "center"  --new alignment parameter
}

local myText = display.newText( options )
myText:setFillColor( 1, 0, 0 )
myText.x, myText.y = 0,0

local overlayX = 100
local overlayY = 0
-- ----------------------------------------------------------



local absolute = true
local margins = {top = 50, left = 50, bottom = 50, right = 50, }

local params = {
	filename = "panorama/panorama.jpg",
	backgroundcolor = {250,250,250},
	orientation = "landscape",
	x = midscreenX,
	y = midscreenY,
	zoom = 1,
	tiltAngle = 90,
	imageScaleX = 1,
	imageScaleY = 1,
	touchonly = true,
	navtype = "accelerometer",
	maxDistanceToSlide = screenW,
	showCloseButton = true,
	closeButtonX = 960,
	closeButtonY = 20,
	overlay = overlay,
	overlayX = overlayX,
	overlayY = overlayY,
	margins = margins,
	absolute = absolute,
	ultimote = useUltimote,
	}
	
local myPano = panorama.new(params)
funx.anchorCenter(myPano)
myPano.x = midscreenX
myPano.y = midscreenY

myPano:activate()