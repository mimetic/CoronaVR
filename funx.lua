-- funx.lua
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
-- USEFUL FUNCTIONS.
-- ===================

module(..., package.seeall)

-- Requires json library
local json = require("json")

-- Used by tellUser...the handler for the timed message
local timedMessage = nil
local timedMessageList = {}

-- Make a local copy of the application settings global
local screenW, screenH = display.contentWidth, display.contentHeight
local viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
local screenOffsetW, screenOffsetH = display.contentWidth -  display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
local midscreenX = screenW*(0.5) 
local midscreenY = screenH*(0.5) 

-- functions
local floor = math.floor



-----------------
-- Table is empty?
function tableIsEmpty(t)
	if (t and type(t) == "table" ) then
		if (next(t) == nil) then 
			return true 
		end
	end
	return false
end

-----------------
-- Length of a table, i.e. number elements in it.
function tablelength (t)
	local count = 0
	for _, _ in pairs(t) do
		count = count + 1 
	end
	return count
end


-- Delete fields of the form {x} in the string s
function removeFields (s)
	if (not s) then return nil end
	local r = string.gfind(s,"%b{}")
	local res = s
	for w in r do
		res = funx.trim(string.gsub(res, w, ""))
	end
	return res
end


-- Substitute for {x} with table.x from a table.
-- There can be multiple fields in the string, s.
-- Returns the string with the fields filled in.
function substitutions (s, t)
	if (not s or not t or t=={}) then
		--print ("funx.substitutions: No Values passed!")
		return s
	end
	local r = string.gfind(s,"%b{}")
	local res = s
	for w in r do
		local i,j = string.find(w, "{(.-)}")
		local k = string.sub(w,i+1,j-1)
		if (t[k]) then
			res = string.gsub(res, "{"..k.."}", t[k])
		end
		--print (res)	
	end
	return res
end


-- hasFieldCodes(s)
-- Return true/false if the string has field codes, i.e. {x} inside it
function hasFieldCodes(s)
	s = s or ""
	local r = string.find(s,"%b{}")
	if (r) then
		return true
	else
		return false
	end
end
	

-- Get element name from string.
-- If the string is {xxx} then the field name is "xxx"
function getElementName (s)
	local r = string.gfind(s,"%b{}")
	local res = "RESULT: "..s
	for w in r do
		local i,j = string.find(w, "{(.-)}")
		local k = string.sub(w,i+1,j-1)
		print ("extracted ",k)
		break
	end
	return k
end




--------------------------------------------------------
-- tableCopy
function tableCopy(object)
	local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local new_table = {}
		lookup_table[object] = new_table
		for index, value in pairs(object) do
			new_table[_copy(index)] = _copy(value)
		end
		return setmetatable(new_table, _copy(getmetatable(object)))
	end
	return _copy(object)
end

--------------------------------------------------------
-- Trim
-- Remove white space from a string
-- Only act on strings
function trim(s)
	if (s) then
		if (type(s) == "table") then
			for i,v in ipairs(s) do
				s[i] = v:gsub("^%s*(.-)%s*$", "%1")
			end
		elseif (type(s) == "string") then
			s = s:gsub("^%s*(.-)%s*$", "%1")
		end
	end
	return s
end



--------------------------------------------------------
-- table merge
-- Overwrite elements in the first table with the second table!
function tableMerge(t1, t2)
	if (type(t1) ~= "table") then
		return t2
	end

	if (type(t2) ~= "table") then
		return t1
	end

	for k,v in pairs(t2) do
		if type(v) == "table" then
				if type(t1[k] or false) == "table" then
						tableMerge(t1[k] or {}, t2[k] or {})
				else
						t1[k] = v
				end
		else
				t1[k] = v
		end
	end
	return t1
end

--------------------------------------------------------
-- File Exists
-- default directory is system.ResourceDirectory
-- not system.DocumentsDirectory
--------------------------------------------------------

function fileExists(f,d)
	if (f) then
		local fhd,path
		d = d or system.ResourceDirectory
		local path = system.pathForFile( f, d )
		-- Determine if file exists
		if (path ~= nil) then
		   return true
		else
		--	print ("Missing file: ",f)
		--	print ("in path: ",tostring(path))
			return false
		end
	else
		--print ("Missing path: ",tostring(path))
		return false
	end
end


--------------------------------------------------------
-- Load an image file. If it is not there, load a "missing image" file
-- default directory is system.ResourceDirectory
-- not system.DocumentsDirectory
--------------------------------------------------------
function loadImageFile(f, d)
	d = d or system.ResourceDirectory
	if (fileExists(f, d)) then
		local path = system.pathForFile( f, d )
		local image = display.newImage(f, d)
		return image
	else
		local i = display.newGroup()
		local image = display.newImage(i, "_ui/missing-image.png", system.ResourceDirectory)
		local t = display.newText(f)
		i:insert(t)
		image.x = midscreenX
		t:setReferencePoint(display.CenterReferencePoint)
		t.x = midscreenX
		t.y = midscreenY+40
		return i
	end
end


--------------------------------------------------------
-- Verify Net Connection OR QUIT!
-- WARNING, THIS QUITS THE APP IF NO CONNECTION!!!
--------------------------------------------------------
function verifyNetConnectionOrQuit()
	local http = require("socket.http")
	local ltn12 = require("ltn12")
	 
	if http.request( "http://www.google.com" ) == nil then
	 
		local function onCloseApp( event )
			if "clicked" == event.action then
				os.exit()
			end
		end
	 
		native.showAlert( "Alert", "An internet connection is required to use this application.", { "Exit" }, onCloseApp )
	end
end


--------------------------------------------------------
-- hasNetConnection: return true if connected, false if not.
--------------------------------------------------------
function hasNetConnection()
	local http = require("socket.http")
	local ltn12 = require("ltn12")
	 
	if http.request( "http://www.google.com" ) == nil then
		return false
	else
		return true
	end
	 
end





-------------------------------------------------
-- CHECK IMAGE DIMENSION & SCALE ACCORDINGLY
-------------------------------------------------
function checkScale(p)
	if p.width > viewableScreenW or p.height > viewableScreenH then
		if p.width/viewableScreenW > p.height/viewableScreenH then 
				p.xScale = viewableScreenW/p.width
				p.yScale = viewableScreenW/p.width
		else
				p.xScale = viewableScreenH/p.height
				p.yScale = viewableScreenH/p.height
		end
	end
end
	
-------------------------------------------------
-- RESCALE AN IMAGE THAT WAS DESIGNED FOR THE IPAD (1024X768) FOR THE CURRENT PLATFORM
-- Assuming the graphic was made for a different platform
-- this resizes it 
-------------------------------------------------
function resizeFromIpad(p)
	local currentR = viewableScreenW/viewableScreenH
	local ipadR = 1024/768
	local r

	if (currentR > ipadR) then
		-- use ration based on different heights
		r = viewableScreenH / 768
	else
		r = viewableScreenW / 1024
	end
	if (r ~= 1) then
		p:scale(r,r)
		--print ("Resize image by (viewableScreenW/1024) = "..r)
	end


end


-------------------------------------------------
-- RESCALE COORDINATES THAT WERE DESIGNED FOR THE IPAD (1024X768) FOR THE CURRENT PLATFORM
-- Used to reposition coordinates that were set up for the iPad, e.g. x,y positions
-- If the screen is a different shape, pad the x to make up for it
-- iPad is 1024/768 = 133/100 (1.33)
-- CONVERT results to integer (math.floor)
function rescaleFromIpad(x,y)
	
	-- Do nothing if this is an iPad screen!
	if (screenW == 1024 and screenH == 768) then
		return x,y
	end

	if (x == nil) then
		return 0,0
	end
	--print ("viewableScreenW="..viewableScreenW..", viewableScreenH="..viewableScreenH)

	local currentR = viewableScreenW/viewableScreenH
	local ipadR = 1024/768
	local r

	if (currentR > ipadR) then
		-- use ration based on different heights
		r = viewableScreenH / 768
	else
		r = viewableScreenW / 1024
	end

	-- Pad for different shape
	local screenR = floor((viewableScreenW / viewableScreenH) * 100 )/100
	local px = 0
	--print ("screenR="..screenR)
	if (y and (screenR ~= floor((ipadR)*100)/100)) then
		px = floor((viewableScreenW - (viewableScreenH * ipadR))/2)
	end
	x = floor((x * r) + (px))
	--print ("Padding x="..px)
	if (y ~= nil) then
		y = floor(y * r)
		return x,y
	else
		return x
	end
end


-------------------------------------------------
-- POPUP: popup image with close button
-- We have white and black popups. Default is white.
-- If the first param is a table, then we assume all params are in that table, IN ORDER!!!,
-- starting with filename, e.g. { "filename.jpg", "white", 1000, true}
-------------------------------------------------
function popup(filename, color, bkgdAlpha, time, cancelOnTouch)
	local mainImage
	local pgroup = display.newGroup()
	local closing = false

	if (type(filename) == "table") then
		color = trim(filename[2])
		bkgdAlpha = tonumber(filename[3])
		time = tonumber(filename[4])
		cancelOnTouch =  filename[5] or false
		filename = trim(filename[1])
	end

	color = color or "white"
	
	bkgdAlpha = bkgdAlpha or 0.95
	time = time or 300
	cancelOnTouch = cancelOnTouch or false
	
	local function killme()
		if (pgroup ~= nil) then
			display.remove(pgroup)
			pgroup=nil
			--print "Killed it"
		else
			--print ("Tried to kill pGroup, but it was dead.")
		end
	end
		
	local function closeMe(event)
		if (not closing and pgroup ~= nil) then
			transition.to (pgroup, {alpha=0, time=time, onComplete=killme} )
			closing = true
		end
		return true
	end

	-- cover all rect, darken background
	local bkgdrect = display.newRect(0,0,screenW,screenH)
	pgroup:insert(bkgdrect)
	bkgdrect:setFillColor( 55, 55, 55, 190 )
	
	-- background graphic for popup
	local bkgd = display.newImage("_ui/popup-"..color..".png")
	checkScale(bkgd)
	pgroup:insert (bkgd)
	bkgd:setReferencePoint(display.CenterReferencePoint)
	bkgd.x = midscreenX
	bkgd.y = midscreenY
	bkgd.alpha = bkgdAlpha
	
	mainImage = display.newImage(filename)
	checkScale(mainImage)
	pgroup:insert (mainImage)
	mainImage:setReferencePoint(display.CenterReferencePoint)
	mainImage.x = midscreenX
	mainImage.y = midscreenY
	
	local closeButton = ui.newButton{
		default = "_ui/button-cancel-round.png",
		over = "_ui/button-cancel-round-over.png",
		onRelease = closeMe,
		x=0,
		y=0,
	}
	pgroup:insert(closeButton)
	closeButton:setReferencePoint(display.TopRightReferencePoint)
	--closeButton.x = midscreenX + (bkgd.width/2) - closeButton.width
	--closeButton.y = midscreenY - (bkgd.height)/2 + closeButton.height
	-- allow 10 px for the shadow of the popup background
	closeButton.x = midscreenX + (bkgd.width/2) + 10
	closeButton.y = midscreenY - (bkgd.height)/2 - 10
	
	pgroup.alpha = 0
	
	-- Capture touch events and do nothing.
	if (cancelOnTouch) then
		pgroup:addEventListener( "touch", closeMe )
	else
		pgroup:addEventListener( "touch", function() return true end )
	end
	
	transition.to (pgroup, {alpha=1, time=time } )

end



-------------------------------------------------
-- POPUP: popup image with close button
-- We have white and black popups. Default is white.
-- If the first param is a table, then we assume all params are in that table, IN ORDER!!!,
-- starting with filename, e.g. { "filename.jpg", "white", 1000, true}
-------------------------------------------------
function popupWebpage(targetURL, color, bkgdAlpha, time)
	local mainImage
	local pgroup = display.newGroup()
	local closing = false

	if (type(targetURL) == "table") then
		color = trim(targetURL[2])
		bkgdAlpha = tonumber(targetURL[3])
		time = tonumber(targetURL[4])
		targetURL = trim(targetURL[1])
	end

	color = color or "white"
	
	bkgdAlpha = bkgdAlpha or 0.95
	time = time or 300
	
	local function killme()
		if (pgroup ~= nil) then
			display.remove(pgroup)
			pgroup=nil
			--print "Killed it"
		else
			--print ("Tried to kill pGroup, but it was dead.")
		end
	end
		
	local function closeMe(event)
		if (not closing and pgroup ~= nil) then
			native.cancelWebPopup()
			transition.to (pgroup, {alpha=0, time=time, onComplete=killme} )
			closing = true
		end
		return true
	end
	
	
	-- cover all rect, darken background
	local bkgdrect = display.newRect(0,0,screenW,screenH)
	pgroup:insert(bkgdrect)
	bkgdrect:setFillColor( 55, 55, 55, 190 )
	
	-- background graphic for popup
	local bkgd = display.newImage("_ui/popup-"..color..".png")
	checkScale(bkgd)
	pgroup:insert (bkgd)
	bkgd:setReferencePoint(display.CenterReferencePoint)
	bkgd.x = midscreenX
	bkgd.y = midscreenY
	bkgd.alpha = bkgdAlpha
	
	local closeButton = ui.newButton{
		default = "_ui/button-cancel-round.png",
		over = "_ui/button-cancel-round-over.png",
		onRelease = closeMe,
		x=0,
		y=0,
	}
	pgroup:insert(closeButton)
	closeButton:setReferencePoint(display.TopRightReferencePoint)
	--closeButton.x = midscreenX + (bkgd.width/2) - closeButton.width
	--closeButton.y = midscreenY - (bkgd.height)/2 + closeButton.height
	-- allow 10 px for the shadow of the popup background
	closeButton.x = midscreenX + (bkgd.width/2) + 10
	closeButton.y = midscreenY - (bkgd.height)/2 - 10
	
	pgroup.alpha = 0
	
	-- Capture touch events and do nothing.
	pgroup:addEventListener( "touch", function() return true end )
	
	local function showMyWebPopup()
		-- web popup
		local x = (screenW - bkgd.width)/2 + (closeButton.width)
		local y = (screenH - bkgd.height)/2 + (closeButton.height)
		local w = bkgd.width - (2 * closeButton.width)
		local h = bkgd.height - (2 * closeButton.width)
		
		--print ("showWebMap: go to ",targetURL)
		--print (x, y, w, h, targetURL)
		local options = { 
			hasBackground=true,
			baseUrl=system.ResourceDirectory,
		}
		native.showWebPopup(x, y, w, h, targetURL, options )
	end
	time = tonumber(time)
	transition.to (pgroup, {alpha=1, time=time, onComplete=showMyWebPopup } )
end



------------------------------------------------------------------------
-- OPEN a URL
------------------------------------------------------------------------        
function openURLWithConfirm(urlToOpen, title, msg)

	-- Handler that gets notified when the alert closes
	local function onComplete( event )
		if "clicked" == event.action then
				local i = event.index
				if 1 == i then
						system.openURL(urlToOpen)
				elseif 2 == i then
						-- do nothing, dialog with close
				end
		end
	end
	
	-- Show alert with five buttons
	local alert = native.showAlert(title, msg , { "OK", "Cancel" }, onComplete )

	
	
end
	

------------------------------------------------------------------------
-- SHADOW
-- Build a drop shadow
------------------------------------------------------------------------        

function buildShadow(w,h)
	local ceil = math.ceil
	local shadow = display.newGroup()
	
	--print ("buildShadow: ",w,h)
	
	local tl = display.newImage(shadow, "_ui/shadow_tl.png")
	local tr = display.newImage(shadow, "_ui/shadow_tl.png")
	local bl = display.newImage(shadow, "_ui/shadow_tl.png")
	local br = display.newImage(shadow, "_ui/shadow_tl.png")

	local left = display.newImage(shadow, "_ui/shadow_l.png")
	local right = display.newImage(shadow, "_ui/shadow_l.png")
	local top = display.newImage(shadow, "_ui/shadow_l.png")
	local bottom = display.newImage(shadow, "_ui/shadow_l.png")

	local corner = tl.width
	local cornerPad = corner/2
	local edge = left.width
	local edgePad = edge/2

	-- Start with a solid rect
	local srect = display.newRect(shadow, corner,corner,w-(2*corner),h-(2*corner))
	srect:setFillColor( 0,0,0,255 )

	
	-- rotate
	tr:rotate( 90 )
	bl:rotate( -90 )
	br:rotate( 180 )

	right:rotate( 180 )
	top:rotate( 90 )
	bottom:rotate( -90 )
	
	if (h<(2*corner) or w<(2*corner)) then
		print ("funx.buildShadow: ERROR! The shadow box is to small..I can't compute this one")
	end
	--scale
	-- 50 = 20+20+3 is min side
	
	local r = (h/2) / corner
	if (r < 1) then
		--print ("Resize to "..r)
		tl:scale(r,r)
		tr:scale(r,r)
		bl:scale(r,r)
		br:scale(r,r)

		top:scale(1,r)
		bottom:scale(1,r)

		corner = (corner * r)
		cornerPad = (cornerPad * r)
		edge = (edge * r)
		edgePad = (edgePad * r)

	end
	
	if (r == 1) then
		display.remove(left)
		left = nil
		
		display.remove(right)
		right = nil
	end
	
	if (w <= (2*corner)) then
		display.remove(top)
		top = nil
		
		display.remove(bottom)
		bottom = nil
	end
	
	if (h > (2*corner) and left) then
		left.height = h-40
		right.height = h-40
	end
	
	if (w > (2*corner) and top) then
		top.height = w-40
		bottom.height = w-40
	end
	
	-- position
	--[[
	tl:setReferencePoint(display.TopLeftReferencePoint)
	tr:setReferencePoint(display.TopLeftReferencePoint)
	bl:setReferencePoint(display.TopLeftReferencePoint)
	br:setReferencePoint(display.TopLeftReferencePoint)

	left:setReferencePoint(display.TopLeftReferencePoint)
	right:setReferencePoint(display.TopLeftReferencePoint)
	top:setReferencePoint(display.TopLeftReferencePoint)
	bottom:setReferencePoint(display.TopLeftReferencePoint)
	]]
	
	if (top) then
		top.x = w/2
		top.y = cornerPad
		bottom.x = w/2
		bottom.y = h-cornerPad
	end	
	if (left) then
		left.y = h/2
		right.x = w-cornerPad
		right.y = h/2
	end	

	tr.x = w-cornerPad
	bl.y = h-cornerPad
	br.x = w-cornerPad
	br.y = h-cornerPad

	return shadow
	
end

------------------------------------------------------------------------        
-- Functions to do on a system event,
-- e.g. load or exit
------------------------------------------------------------------------

function initSystemEventHandler(options)

	---------------------
	local function shouldResume()
		return true
	end
	---------------------
		
	---------------------
	local function onSystemEvent( event )
		
		if (options == nil) then
			return true
		end
	
		if ( event.type == "applicationExit" or event.type == "applicationSuspend" ) then
			options.onAppExit()
		elseif (event.type == "applicationStart" or event.type == "applicationResume" ) then
			if shouldResume() then 
				options.onAppStart()
			else
				-- start app up normally
			end
		end
	end
	---------------------

	Runtime:addEventListener( "system", onSystemEvent );
end


--=====================================================
-- the reason this routine is needed is because lua does not 
-- have a sort indexed table function
function table_sort(a, sortfield)
	local new1 = {}
	local new2 = {}
	for k,v in a do
		table.insert(new1, { key=k, val=v } ) 		
	end
	table.sort(new1, function (a,b) return (a.val[sortfield] < b.val[sortfield]) end)  
	for k,v in new1 do
		table.insert(new2, v.val)
	end
	return new2
end

--[[
As a more advanced solution, we can write an iterator that traverses a table following the order of its keys. An optional parameter f allows the specification of an alternative order. It first sorts the keys into an array, and then iterates on the array. At each step, it returns the key and value from the original table:
	t : the table
	f : the key
]]
function pairsByKeys (t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0			 -- iterator variable
	local iter = function ()	 -- iterator function
		i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
end

--[[
	With this function, it is easy to print those function names in alphabetical order. The loop
		for name, line in pairsByKeys(lines) do
			print(name, line)
		end
]]

--========================================================================
-- Order objects in a display group by the "layer" field of each object
-- We can't use "z-index" cuz the hyphen doesn't work in XML.
-- This allows for ordered layering.
function zSort(myGroup)

 	local n = myGroup.numChildren
 	local kids = {}
 	for i=1,n do
 		kids[i] = myGroup[i]
 	end
 	
 	--print ("Zsort: "..n.." children")
	table.sort(kids,  
		function(a, b)
			local al = a.layer
			local bl = b.layer
			--print ("zSort:", al, bl, a.index, a.name)
			if (al=="top" or bl=="bottom") then return false end			
			if (bl=="top" or al=="bottom") then return true end		
			return (al or 1) < (bl or 1) -- "layer" is your custom z-index field
		end
	)
	
 	for i = 1,n do
		myGroup:insert(kids[i])
		--print ("zSort result:",i, kids[i].name, " Layer:", kids[i].layer)
	end
	return myGroup
end



--========================================================================
-- get date parts for a given ISO 8601 date format (http://richard.warburton.it )
function get_date_parts(date_str)
	if (date_str) then
		_,_,y,m,d=string.find(date_str, "(%d+)-(%d+)-(%d+)")
		return tonumber(y),tonumber(m),tonumber(d)
	else
		return nil,nil,nil
	end
end

--====================================================
function getmonth(month)
	local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
	return months[tonumber(month)]
end

--====================================================
function getday_posfix(day)
local idd = math.mod(day,10)
       return	(idd==1 and day~=11 and "st")  or (idd==2 and day~=12 and "nd") or (idd==3 and day~=13 and "rd") or "th"
end


--========================================================================
-- Format a STRING date, e.g. 2005-10-4 in ISO format, into a human format.
-- Default for stripZeros is TRUE.
function formatDate(s, f, stripZeros)
	if (stripZeros == nil) then stripZeros = true end
	if (s ~= "") then
		f = f or "%x"
		local y,m,d = get_date_parts(s)
		if (y..m..d) then
			local t = os.time({year=y,month=m,day=d})
			s = os.date(f, t)
			if (stripZeros) then
				s = s:gsub("/0", "/")
				s = s:gsub("%.0", ".")
				s = s:gsub("%, 0", ", ")
				s = s:gsub("^0", "")
			end
		else
			print ("Warning: the dates provided for formatting are not in xx-xx-xx format...perhaps in xx/xx/xx ???")
		end
		return s
	else
		return ""
	end
end
		



------------------------------------------------------------------------        
-- Save table, load table, default from documents directory
------------------------------------------------------------------------
function saveTable(t, filename, path)
	if (not t or not filename) then
		return true
	end
	
	path = path or system.DocumentsDirectory
	--print ("funx.saveTable: save to "..filename)

	local json = json.encode (t)
	local filePath = system.pathForFile( filename, system.DocumentsDirectory )
	saveData(filePath, json)
end

function loadTable(filename, path)
	path = path or system.DocumentsDirectory

	local filePath = system.pathForFile( filename, path )
	--print ("funx.loadTable: load from "..filePath)
	
	local t = {}
	local f = loadData(filePath)
	if (f and f ~= "") then
		t = json.decode(f)
	end
	--print ("loadTable: end")
	return t
end


----------------------
-- Save/load functions

function saveData(filePath, text)

	--local levelseq = table.concat( levelArray, "-" )
	local file = io.open( filePath, "w" )
	if (file) then
		file:write( text )
		io.close( file )
		return true
	else
		print ("Error: funx.saveData: Could not create file "..tostring(filePath))
		return false
	end
end

function loadData(filePath)
	local t = nil
	--local levelseq = table.concat( levelArray, "-" )
	local file = io.open( filePath, "r" )
	if (file) then
		t = file:read( "*a" )
		io.close( file )
	else
		print ("funx.loadData: No file found at "..tostring(filePath))
	end
	return t
end

function saveTableFromFile(filePath, dataTable)

	--local levelseq = table.concat( levelArray, "-" )
	file = io.open( filePath, "w" )
	
	for k,v in pairs( dataTable ) do
		file:write( k .. "=" .. v .. "," )
	end
	
	io.close( file )
end



function loadTableFromFile(filePath)	
	local file = io.open( filePath, "r" )
	
	if file then

		-- Read file contents into a string
		local dataStr = file:read( "*a" )
		
		-- Break string into separate variables and construct new table from resulting data
		local datavars = split(dataStr, ",")
		
		dataTableNew = {}
		
		for i = 1, #datavars do
			-- split each name/value pair
			local onevalue = split(datavars[i], "=")
			dataTableNew[onevalue[1]] = onevalue[2]
		end
	
		io.close( file ) -- important!

		-- Note: all values arrive as strings; cast to numbers where numbers are expected
		dataTableNew["numValue"] = tonumber(dataTableNew["numValue"])
		dataTableNew["randomValue"] = tonumber(dataTableNew["randomValue"])	
	
	else
		print ("no file found")
	end
end

function split(str, pat, doTrim)
	if (not str) then
		return nil
	end
	
	local t = {}
	local fpat = "(.-)" .. pat
	local last_end = 1
	local s, e, cap = str:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
		if doTrim then cap = trim(cap) end
		table.insert(t,cap)
		end
		last_end = e+1
		s, e, cap = str:find(fpat, last_end)
	end
	if last_end <= #str then
		cap = str:sub(last_end)
		if doTrim then cap = trim(cap) end
		table.insert(t,cap)
	end
	return t	 
end

------------------------------------------------------------------------        
-- Show a message, then fade away
------------------------------------------------------------------------
function tellUser(message, x,y)

	if (not message) then
		return true
	end


	local screenW, screenH = display.contentWidth, display.contentHeight
	local viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
	local screenOffsetW, screenOffsetH = display.contentWidth -  display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
	local midscreenX = screenW*(0.5) 
	local midscreenY = screenH*(0.5) 

	local TimeToShowMessage = 2000
	local FadeMessageTime = 500

	-- message object
	local msg = display.newGroup()

	local x = x or 0
	local y = y or 0
	
	-- msg corner radius
	local r = 10
	
	------------------------------------------------------------------------
	local function closeMessage( event )
		-- remove from display hierarchy
		msg.parent:remove( msg )
		return true
	end
	
	------------------------------------------------------------------------
	local function fadeAwayThenClose()
		transition.to( msg,  { time=FadeMessageTime, alpha=0, onComplete=closeMessage} )
		timedMessage = nil
		timedMessageList[1] = nil
		-- remove first element
		table.remove(timedMessageList, 1)
		--print ("Messages:", #timedMessageList)
	end
	
	------------------------------------------------------------------------
	
	-- Create empty text box, using default bold font of device (Helvetica on iPhone)
	local textObject = display.newText( message, 0, 0, native.systemFontBold, 24 )
	textObject:setTextColor( 255,255,255 )


	-- A trick to get text to be centered
	msg.x = midscreenX
	msg.y = screenH/3
	msg:insert( textObject, true )

	-- hide initially
	msg.alpha = 0

	-- Insert rounded rect behind textObject
	local bkgd = display.newRoundedRect( 0, 0, textObject.contentWidth + 2*r, textObject.contentHeight + 2*r, r )
	bkgd:setFillColor( 55, 55, 55, 190 )
	msg:insert( 1, bkgd, true )
	msg.bkgd = bkgd
	msg.textObject = textObject
	
	
	-- Show message
	msg.textObject.text = message
	msg.bkgd.width = msg.textObject.width + 2*r

	-- If there is a current message showing, cancel it
	if (timedMessage) then
		--timer.cancel(timedMessage)
	end


	msg.y = msg.y + (#timedMessageList - 1) * msg.bkgd.height


	--print ("msg:show width = "..msg.textObject.width)
	transition.to( msg,  { time=FadeMessageTime, alpha=1} ) 
	timedMessage = timer.performWithDelay( TimeToShowMessage, fadeAwayThenClose )
	timedMessageList[#timedMessageList + 1] = timedMessage
	
end


------------------------------------------------------------------------	
-- CLEAN GROUP
------------------------------------------------------------------------
 
function cleanGroups ( curGroup, level )
	if curGroup.numChildren then
		while curGroup.numChildren > 0 do
			cleanGroups ( curGroup[curGroup.numChildren], level+1 )
		end
		if level > 0 then
			display.remove(curGroup)
		end
	else
		display.remove(curGroup)
		curGroup = nil
		return true
	end
end

------------------------------------------------------------------------        
-- CALL CLEAN FUNCTION
------------------------------------------------------------------------

function callClean ( moduleName )
	if type(package.loaded[moduleName]) == "table" then
		if string.lower(moduleName) ~= "main" then
			for k,v in pairs(package.loaded[moduleName]) do
				if k == "clean" and type(v) == "function" then
					package.loaded[moduleName].clean()
				end
			end
		end
	end
end

------------------------------------------------------------------------        
-- UNLOAD SCENE
------------------------------------------------------------------------

function unloadModule ( moduleName )
	fxTime = fxTime or 200
	if type(package.loaded[moduleName]) == "table" then
		package.loaded[moduleName] = nil
		local function garbage ( event )
			collectgarbage("collect")
		end
		garbage()
		timer.performWithDelay(fxTime,garbage)
	end
end








function spinner()
	local isAndroid = "Android" == system.getInfo("platformName")
					 
	if(isAndroid) then
		 local alert = native.showAlert( "Information", "Activity indicator API not yet available on Android devices.", { "OK"})    
	end	
	-- 
	 
	local label = display.newText( "Activity indicator will disappear in:", 0, 0, system.systemFont, 16 )
	label.x = display.contentWidth * 0.5
	label.y = display.contentHeight * 0.3
	label:setTextColor( 10, 10, 255 )
	 
	local numSeconds = 5
	local counterSize = 36
	local counter = display.newText( tostring( numSeconds ), 0, 0, system.systemFontBold, counterSize )
	counter.x = label.x
	counter.y = label.y + counterSize
	counter:setTextColor( 10, 10, 255 )
	 
	function counter:timer( event )
		numSeconds = numSeconds - 1
		counter.text = tostring( numSeconds )
	 
		if 0 == numSeconds then
			native.setActivityIndicator( false );
		end
	end
	 
	timer.performWithDelay( 1000, counter, numSeconds )
	 
	native.setActivityIndicator( true );
end













-------------------------------------------------
-- Toggle an object, transitioning between a given alpha, and zero.
function toggleObject(obj, fxTime, opacity, onComplete)
	fxTime = tonumber(fxTime)
	opacity = tonumber(opacity)
	--print ()
	--print ()
	--print ("------------- ToggleObject Begin (opacity: "..opacity)
	
	-- Actual alpha of a display object is not exact
	local currentAlpha = math.ceil(obj.alpha * 100)/100
	
	-- be sure these properties exist
	obj.tween = obj.tween or {}
	if (obj.isTweening == nil) then
		obj.isTweening = false
	end
	
		local function transitionComplete(obj)
			local currentAlpha = math.ceil(obj.alpha * 100)/100
			if (currentAlpha == 0) then
				obj.isVisible = false
			else
				obj.isVisible = true
			end
			obj.isTweening = false
			obj.tweenDirection = nil
			
			if (onComplete) then
				onComplete()
			end		
		end

	-- Cancel transition if caught in the middle
	if (obj.tween and obj.isTweening) then
		transition.cancel(obj.tween)
		obj.isTweening = false
		obj.tween = nil
		--print ("toggleObject: CANCELLED TRANSITION")
	end
	
	if (obj.alpha == 0 or (obj.alpha > 0 and obj.tweenDirection == "going") ) then
		-- Fade in
		--print ("toggleObject: fade In")
		obj.isVisible = true
		obj.tween = transition.to( obj,  { time=fxTime, alpha=opacity, onComplete=transitionComplete } )
		if (obj.tweenDirection) then
			--print ("Fade in because we were : "..obj.tweenDirection)
		end
		obj.tweenDirection = "coming"
	else
		-- Fade out
		obj.tween = transition.to( obj,  { time=fxTime, alpha=0, onComplete=transitionComplete } )
		--print ("toggleObject: fade Out")
		if (obj.tweenDirection) then
			--print ("Fade out because we are : "..obj.tweenDirection)
		end
		obj.tweenDirection = "going"
	end
	--print ("obj alpha = "..obj.alpha)
	--print ("obj.tweenDirection: "..obj.tweenDirection)
	obj.isTweening = true
	--print "------------- END"
end


-------------------------------------------------
-- Hide an object, transitioning between a given alpha, and zero.
function hideObject(obj, fxTime, opacity, onComplete)
	fxTime = tonumber(fxTime)
	opacity = tonumber(opacity)
	
	-- Actual alpha of a display object is not exact
	local currentAlpha = math.ceil(obj.alpha * 100)/100
	
	-- be sure these properties exist
	obj.tween = obj.tween or {}
	if (obj.isTweening == nil) then
		obj.isTweening = false
	end
	
		local function transitionComplete(obj)
			local currentAlpha = math.ceil(obj.alpha * 100)/100
			if (currentAlpha == 0) then
				obj.isVisible = false
			else
				obj.isVisible = true
			end
			obj.isTweening = false
			obj.tweenDirection = nil
			
			if (onComplete) then
				onComplete()
			end		
		end

	-- Cancel transition if caught in the middle
	if (obj.tween and obj.isTweening) then
		transition.cancel(obj.tween)
		obj.isTweening = false
		obj.tween = nil
		--print ("toggleObject: CANCELLED TRANSITION")
	end
	
		-- Fade out
		obj.tween = transition.to( obj,  { time=fxTime, alpha=0, onComplete=transitionComplete } )
		--print ("toggleObject: fade Out")
		if (obj.tweenDirection) then
			--print ("Fade out because we are : "..obj.tweenDirection)
		end
		obj.tweenDirection = "going"

	obj.isTweening = true

end


-- returns true/false depending whether value is a percent
function isPercent (x)
	v,s = string.match(x, "(%d+)(%%)$")
	if (s == "%") then
		return true
	else
		return false
	end
end


-- Return x%, e.g. 10% returns .10
function percent (x)
	v = string.match(x, "(%d+)%%$")
	if v then
		v = v / 100
	end
	return v
end

-- If the value is a percentage, multiply by the 2nd param, else return the 1st param
-- value is rounded to nearest integer, UNLESS the 2nd param is less than 1
-- or noRound = true
-- If nil, then return nil
function applyPercent (x,y,noRound)
	if (x == nil and y == nil) then
		return nil
	end

	if (x == nil and y ~= nil) then
		return y
	end
	
	x = x or 0
	y = y or 0
	v = string.match(trim(x), "(.+)%%$")
	if v then
		v = (v / 100) * y
		if ((not noRound) and (y>1)) then
			v = math.floor(v+0.5)
		end
	else
		v = x
	end
	return v
end

function applyPercentIfSet(x,y,noRound)
	if (x ~= nil) then
		return applyPercent (x,y,noRound)
	else
		return nil
	end
end

----------
-- Find new width/height to margins within an x,y
-- x,y default to the screen
-- Return ration r, the amount to use for rescaling, e.g. obj:scale(r,r)
function ratioToFitMargins (w,h, t,b,l,r, x,y)
	local x = x or screenW
	local y = y or screenH

	local ww = w - l - r
	local hh = h - t - b
	
	local wr = ww/w
	local wh = hh/h
	
	if (wr < wh) then
		r = wr
	else
		r = wh
	end
	return r
end
	



----------
-- Reduce an element if necessary so it fits
-- with margins insdie of an space of xMax by yMax.
-- xMax,yMax default to the screen
-- DEFAULT: do not resize larger!
-- RETURNS THE RATIO for scaling. Why? Because it seems there's a bug in Corona
-- that means rescaling inside of this function screws up positioning.
function scaleObjectToMargins (obj, t,b,l,r, xMax,yMax, reduceOnly)
	local ratio
	
	if (reduceOnly == nil) then
		reduceOnly = true
	end
	
	xMax = xMax or 0
	yMax = yMax or 0

	if (xMax <= 0) then xMax = screenW end
	if (yMax <= 0) then yMax = screenH end

	local w = obj.contentWidth
	local h = obj.contentHeight

	if reduceOnly then
		if (w < screenW and h < screenH) then
			return 1
		end
	end
	
	local ww = xMax - l - r
	local hh = yMax - t - b
	
	--print (xMax,l,r,ww)
	--print (yMax,t,b,hh)
	
	local wr = ww/w
	local hr = hh/h

	if (wr < hr) then
		ratio = wr
	else
		ratio = hr
	end
	
	return ratio
	--if (ratio ~= 1) then
	--	obj:scale(ratio,ratio)
	--end
	--print ("ratio", ratio, obj.contentWidth, obj.contentHeight)
end
	


-------
-- getFinalSizes
-- Return the final width/height based on the original width/height and new values.
-- The new values are w,h. They could be percentages, and if only one is present, the other is the same.
-- If the Proportional flag is true, then if both width and height
-- are set, resize proportionally to fit INSIDE of width/height
function getFinalSizes (w,h, originalW, originalH, p)
	local wPercent, hPercent
	if p == nil then p = true end

	if (w and not h) then
		if (isPercent(w)) then
			h = applyPercent(w,originalH)
			w = applyPercent(w,originalW)
		else
			h = originalH * (w/originalW)
		end
	elseif (h and not w) then
		if (isPercent(h)) then
			w = applyPercent(h,originalW)
			h = applyPercent(h,originalH)
		else
			w = originalW * (h/originalH)
		end
	elseif (h and w) then
		if (p) then
			if (originalW > originalH) then
				w = applyPercent(w, originalW)
				h = originalH * (w/originalW)
			else
				h = applyPercent(h, originalH)
				w = originalW * (h/originalH)
			end
		else
			h = applyPercent(h, originalH)
			w = applyPercent(w, originalW)
		end
	else
		w = originalW
		h = originalH
	end
	return w,h
end


-------
-- ScaleObjToSize
-- Scale an object to width/height settings.
-- The new values are w,h. They could be percentages, and if only one is present, the other is the same.
function ScaleObjToSize (obj, w,h)
	local wPercent, hPercent
	local originalW = obj.contentWidth
	local originalH = obj.contentHeight
	
	if (w and not h) then
		if (isPercent(w)) then
			h = applyPercent(w,originalH)
			w = applyPercent(w,originalW)
		else
			h = originalH * (w/originalW)
		end
	elseif (h and not w) then
		if (isPercent(h)) then
			w = applyPercent(h,originalW)
			h = applyPercent(h,originalH)
		else
			w = originalW * (h/originalH)
		end
	elseif (h and w) then
		h = applyPercent(h, originalH)
		w = applyPercent(w, originalW)
	else
		w = originalW
		h = originalH
	end
	local ratio = w/originalW
	obj:scale(ratio,ratio)
end




function AddCommas( number, maxPos )
	
	local s = tostring( number )
	local len = string.len( s )
	
	if len > maxPos then
		-- Add comma to the string
		local s2 = string.sub( s, -maxPos )		
		local s1 = string.sub( s, 1, len - maxPos )		
		s = (s1 .. "," .. s2)
	end
	
	maxPos = maxPos - 3		-- next comma position
	
	if maxPos > 0 then
		return AddCommas( s, maxPos )
	else
		return s
	end
 
end

function lines(str)
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end

function loadFile(filename)
	local filePath = system.pathForFile( filename, system.ResourceDirectory )

	local hFile,err = io.open(filePath,"r");
	if (not err) then
		local contents = hFile:read("*a");
		io.close(hFile);
		return contents,nil;
	else
		return nil,err;
	end
end


----------------
-- buildTextDisplayObjectFromTemplate
-- Build a display object using a template and a table
-- Each line of the template is settings for text the display object
-- Each line is comma separated, starting with the name of the field in the obj to use
function buildTextDisplayObjectsFromTemplate (template, obj)
	-- split the template
	local objs = {}
	for i,line in pairs(lines(funx.trim(template))) do  
		--print ("Line : "..line)
		local params = funx.split (line, ",")
		local name = params[1]
		--print (name)
		-- Set the text and size
		local t = "BLANK"
		if obj then
			local t = obj[name]
			--print ("OBJ.NAME = " .. t)
		end
		
		local o = display.newText(t, 0, 0, native.systemFontBold, params[4])
		-- color
		o:setTextColor(0, 0, 0)
		-- Set the coordinates
		o.x = params[2]
		o.y = params[3]
		-- opacity
		o.alpha = 1.0
		objs[name] = o
		--print ("Params for "..name..":")
		funx.dump(params)
		
	end
	return objs
end




-- Dump an XML table
function dump(_class, no_func, depth)
	if (not _class) then 
		print ("dump: not a class.");
		return;
	end
	
	if(depth==nil) then depth=0; end
	local str="";
	for n=0,depth,1 do
		str=str.."\t";
	end
	
	if (depth > 10) then
		print ("Oops, running away! Depth is "..depth)
		return
	end
	
	print (str.."["..type(_class).."]");
	print (str.."{");
	
	if (type(_class) == "table") then
		for i,field in pairs(_class) do
			if(type(field)=="table") then
				local fn = tostring(i)
				if (string.sub(fn,1,2) == "__") then
								print (str.."\t"..tostring(i).." = (not expanding this internal table)");
				else
					print (str.."\t"..tostring(i).." =");
					dump(field, no_func, depth+1);
				end
			else 
				if(type(field)=="number") then
					print (str.."\t"..tostring(i).."="..field);
				elseif(type(field) == "string") then
					print (str.."\t"..tostring(i).."=".."\""..field.."\"");
				elseif(type(field) == "boolean") then
					print (str.."\t"..tostring(i).."=".."\""..tostring(field).."\"");
				else
					if(not no_func)then
						if(type(field)=="function")then
							print (str.."\t"..tostring(i).."()");
						else
							print (str.."\t"..tostring(i).."<userdata=["..type(field).."]>");
						end
					end
				end
			end
		end
	end
	print (str.."}");
end

--------------------------------------------------------
--

function stripCommandLinesFromText(text)
	local substring = string.sub
	local cleanText = ""
	for line in string.gmatch(text, "[^\n]+") do
		line = trim(line)
		if (substring(line,1,3) ~= "###") then
			cleanText = cleanText .. "\n" .. line
		end
	end
	return cleanText
end
		


--------------------------------------------------------
-- Wrap text to a width
-- Blank lines are ignored.
-- *** To show a blank line, put a space on it.
-- The minCharCount is the number of chars to assume are in the line, which means
-- fewer calculations to figure out first line's.
-- It starts at 25, about 5 words or so, which is probabaly fine in 99% of the cases.
-- You can raise lower this for very narrow columns.
-- opacity : 0.0-1.0
-- NOTE: the "floor" is crucial in the y-position of the lines. If they are not integer values, the text blurs!
--------------------------------------------------------

function autoWrappedText(text, font, size, lineHeight, color, width, textAlignment, opacity, minCharCount, targetDeviceScreenSize)
	--if text == '' then return false end
	local strlen = string.len
	local substring = string.sub
	local stringFind = string.find
	local floor = math.floor
	local result = display.newGroup()
	
	text = text or ""
	if (text == "") then
		return result
	end
	
	local textDisplayReferencePoint
	if (textAlignment and textAlignment ~= "") then
		textAlignment = fixCapsForReferencePoint(textAlignment)
		textDisplayReferencePoint = display["Center"..textAlignment.."ReferencePoint"]
	else
		textDisplayReferencePoint = display.TopLeftReferencePoint
	end
	--local textDisplayReferencePoint = display.CenterRightReferencePoint
	
	-- Min text size
	local minTextSize = 12
	
	-- Minimum number of characters per line. Start low.	
	local minLineCharCount = minCharCount or 5

		local function getFirstWords(s, n)
			local a = 1
			local b = 0
			--print (s)
			for i=1,n do
				a,b = string.find(s, "([^%s%-]+[%s%-]*)", b)
				--print ("begin at ="..b)
			end
			return string.sub(s,1,b)
		end
		
		-- scaleToScreenSize: scale settings to match the screen size
		-- noLowerLimit means don't set a lower limit.
		local function scaleToScreenSize(s,r, noLowerLimit)
			local newsize = floor(s*r)
			if (not noLowerLimit and newsize < minTextSize) then	
				newsize = minTextSize
			end
			return newsize
		end

	font = font or native.systemFont
	size = tonumber(size) or 12
	color = color or {255, 255, 255}
	width = applyPercent(width, screenW) or display.contentWidth
	opacity = applyPercent(opacity, 1) or 1
	targetDeviceScreenSize = targetDeviceScreenSize or screenW..","..screenH

 	lineHeight = applyPercent(lineHeight, size) or floor(size * 1.3)

	-- Scaling for device
	-- Scale the text proportionally
	-- We don't need this if we set use the Corona Dynamic Content Scaling!
	-- Set in the config.lua
	-- Actually, we do, for the width, because that doesn't seem to be shrinking!
	-- WHAT TO DO? WIDTH DOES NOT ADJUST, AND WE DON'T KNOW THE
	-- ACTUAL SCREEN WIDTH. WHAT NOW?
	targetDeviceScreenSize = funx.split(targetDeviceScreenSize,",")
	local scalingRatio = targetDeviceScreenSize[1] / screenW
	if (false) then
		local oldsize = size
		size = scaleToScreenSize(size,scalingRatio)
		-- Adjust the line height in proportion to the font size
	 	lineHeight = lineHeight * (size/oldsize)
	 	width = scaleToScreenSize(width,scalingRatio)
	end
	local currentLine = ''
	local currentLineLength = 0
	local lineCount = 0
	-- x is start of line
	local x = 0
	local nextLineY = 0
	
	local defaultSettings = {
		font=font,
		size=size,
		lineHeight=lineHeight,
		color=color,
		width=width,
		opacity=opacity,
	}
	
	for line in string.gmatch(text, "[^\n]+") do
		local command, commandline
		
		line = trim(line)
		-- command line
		-- reset
		-- set
		-- set is followed by: font, size, red,green,blue, width, opacity
		if (currentLine == "" and substring(line,1,3) == "###") then
			currentLine = ''
			currentLineLength = 0
			commandline = substring(line,4,-1)	-- get end of line
			local params = split(commandline, ",", true)
			command = trim(params[1])
			if (command == "reset") then
				font = defaultSettings.font
				size = defaultSettings.size
				lineHeight = defaultSettings.lineHeight
				color = defaultSettings.color
				width = defaultSettings.width
				opacity = defaultSettings.opacity
				textAlignment = "Left"
				x = 0
			elseif (command == "set") then
				-- font
				if (params[2] and params[2] ~= "") then font = trim(params[2]) end
				-- font size
				if (params[3] and params[3] ~= "") then 
					size = scaleToScreenSize(tonumber(params[3]), scalingRatio) 
					-- reset min char count in case we loaded a BIG font
					minLineCharCount = minCharCount or 5
				end
				-- line height
				if (params[4] and params[4] ~= "") then 
					lineHeight = scaleToScreenSize(tonumber(params[4]), scalingRatio) 
				end
				-- color
				if ((params[5] and params[5] ~= "") and (params[6] and params[6] ~= "") and (params[7] and params[7] ~= "")) then color = {tonumber(params[5]), tonumber(params[6]), tonumber(params[7])} end
				-- width of the text block
				if (params[8] and params[8] ~= "") then 
					if (params[8] == "reset" or params[8] == "r") then	
						width = defaultSettings.width
					else
						width = tonumber(applyPercent(params[8], screenW) or defaultSettings.width)
					end
					minLineCharCount = minCharCount or 5
				end
				-- opacity
				if (params[9] and params[9] ~= "") then opacity = funx.applyPercent(params[9],1) end
			elseif (command == "textalign") then
				-- alignment
				if (params[2] and params[2] ~= "") then
					textAlignment = fixCapsForReferencePoint(params[2])
					textDisplayReferencePoint = display["Center"..textAlignment.."ReferencePoint"]
					
					-- set the line starting point to match the alignment
					if (textAlignment == "Right") then
						x = width
					elseif (textAlignment == "Left") then
						x = 0
					else
						x = floor(width/2)
					end
				end
				
				
				
			elseif (command == "blank") then
				local lh
				if (params[2]) then
					lh = scaleToScreenSize(tonumber(params[2]), scalingRatio, true)
				else
					lh = lineHeight
				end
				lineCount = lineCount + 1
				nextLineY = nextLineY + lh
			elseif (command == "setline") then
				-- set the x of the line
				if (params[2]) then
					x = tonumber(params[2])
				end
				-- set the y of the line
				if (params[3]) then
					nextLineY = tonumber(params[3])
				end
				-- set the y based on the line count, i.e. the line to write to
				if (params[4]) then
					lineCount = tonumber(params[4])
					nextLineY = floor(lineHeight * (lineCount - 1))
				end
				
				
				
			end			
		else
			restOLine = substring(line, strlen(currentLine)+1)
			for word, spacer in string.gmatch(restOLine, "([^%s%-]+)([%s%-]*)") do
				local tempLine = currentLine..word..spacer
				-- Grab the first words of the line, until "minLineCharCount" hit
				if (strlen(currentLine) > minLineCharCount) then	
					-- Allow for lines with beginning spaces, for positioning
					if (substring(currentLine,1,1) == ".") then
						currentLine = substring(currentLine,2,-1)
					end	
					--print ("currentLine: ["..currentLine.."]")
					-- add a word
					local tempLine = currentLine..word..spacer
					local tempDisplayLine = display.newText(tempLine, x, 0, font, size)
	
					if tempDisplayLine.width <= width then
						currentLine = tempLine
						currentLineLength = tempDisplayLine.width
					else
						-- Check the line for fit
						--local newDisplayLine = display.newText(currentLine, 0, floor(lineHeight * (lineCount - 1)), font, size)
						local newDisplayLine = display.newText(currentLine, x, nextLineY, font, size)
						newDisplayLine:setTextColor(color[1], color[2], color[3])
						newDisplayLine.alpha = opacity
						result:insert(newDisplayLine)
						newDisplayLine:setReferencePoint(textDisplayReferencePoint)
						newDisplayLine.x = x
						lineCount = lineCount + 1
						nextLineY = nextLineY + lineHeight
						minLineCharCount = strlen(currentLine)
	
						-- If next word fits in the line, start the new line with it
						-- otherwise make a whole new line from it.
						local wordlen = strlen(word)
						if (wordlen <= width) then
							currentLine = word..spacer
							currentLineLength = wordlen
						else
							local newDisplayLine = display.newText(word, x, nextLineY, font, size)
							newDisplayLine:setTextColor(color[1], color[2], color[3])
							newDisplayLine.alpha = opacity
							result:insert(newDisplayLine)
							newDisplayLine:setReferencePoint(textDisplayReferencePoint)
							newDisplayLine.x = x
							lineCount = lineCount + 1
							nextLineY = nextLineY + lineHeight
							currentLine = ''
							currentLineLength = 0
						end
	
						-- Get stats for next line
						-- Set the new min char count to the current line length, minus a few for protection
						-- (20 is chosen from a few tests)
						minLineCharCount = minLineCharCount - 20
						if (minLineCharCount<0) then
							minLineCharCount = 1
						end
						--[[
						print ("--------------------------")
						print ("k=",k)
						print ("CurrentLine: "..currentLine)
						print ("Final minLineCharCount =", minLineCharCount)
						print ("CurrentLine length: ", strlen(currentLine))
						-- reset counters
						k = 0
						]]
					end
					
					display.remove(tempDisplayLine);
					tempDisplayLine=nil;
				else
					currentLine = tempLine
					--k = k + 1
				end
			end
			
			-- Allow for lines with beginning spaces, for positioning
			if (substring(currentLine,1,1) == ".") then
				currentLine = substring(currentLine,2,-1)
			end	

			-- Add final line that didn't need wrapping
			-- Add a space to deal with a weirdo bug that was deleting
			-- final words.
			--print ("currentLine: ["..currentLine.."]")
			currentLine = currentLine .. " "
			local newDisplayLine = display.newText(currentLine, 0, nextLineY, font, size)
			newDisplayLine.alpha = opacity
			result:insert(newDisplayLine)
			newDisplayLine:setReferencePoint(textDisplayReferencePoint)
			newDisplayLine.x = x
			newDisplayLine:setTextColor(color[1], color[2], color[3])
			lineCount = lineCount + 1
			nextLineY = nextLineY + lineHeight
			currentLine = ''
			currentLineLength = 0
		end
	end
	result:setReferencePoint(display.CenterReferencePoint)
	return result
end


function capitalize(str)
	local function tchelper(first, rest)
	  return first:upper()..rest:lower()
	end
	-- Add extra characters to the pattern if you need to. _ and ' are
	--  found in the middle of identifiers and English words.
	-- We must also put %w_' into [%w_'] to make it handle normal stuff
	-- and extra stuff the same.
	-- This also turns hex numbers into, eg. 0Xa7d4
	str = str:gsub("(%a)([%w_']*)", tchelper)
	return str
end


--------------------------------------------------------
-- Adjust x,y for a shadow thickness.
-- If an object has a drop shadow, the corner of the object will be inside the shadow area.
-- So, to position the object properly at x,y we need to find the x,y that includes the shadowing.
-- Scale doesn't seem to work right, so ignore it, and it will be 1, which is OK.
--------------------------------------------------------

function adjustXYforShadow (x, y, rp, shadowOffset, scale)
	local stringFind = string.find

	if (shadowOffset) then
		local shadowOffsetX = 0
		local shadowOffsetY = 0
		
		scale = scale or 1
		
		--print ("a) adjustXYforShadow", x, y, rp)

		rp = rp:lower()
	
		-- Horizontal offsets
		if (stringFind(rp, "left")) then
			shadowOffsetX = shadowOffset
		elseif (stringFind(rp, "right")) then
			shadowOffsetX = (-1*shadowOffset)
		else
			offsetX = 0
		end
		
		-- Vertical offsets
		if (stringFind(rp, "top")) then
			shadowOffsetY = shadowOffset
		elseif (stringFind(rp, "bottom")) then
			shadowOffsetY = (-1*shadowOffset)
		else
			offsetY = 0
		end

		x = math.floor((x + shadowOffsetX) * scale)
		y = math.floor((y + shadowOffsetY) * scale)
		--print ("b) adjustXYforShadow adjustedment:", x, y, scale)
	end	
	return x,y
end


--------------------------------------------------------
-- referenceAdjustedXY
-- Calculate the x,y of an object when offset by a new reference point
-- but without resetting the reference point of the object.
-- This allow the user to spec the position of an object with x,y and
-- a reference alignement, e.g. BottomRight. We do the calculations
-- to correct the x,y so the object is correctly positioned, based on the
-- the provided newReferencePoint (e.g. center).
--------------------------------------------------------

function referenceAdjustedXY (obj, x, y, newReferencePoint, scale, shadowOffset)
	local stringFind = string.find
	
	rx = obj.xReference
	ry = obj.yReference
	
	if (obj and newReferencePoint) then
		scale = scale or 1
		local w = obj.width
		local h = obj.height

--print ("a) referenceAdjustedXY adjustedment:  x, y, newReferencePoint, scale, shadowOffset",  x, y, newReferencePoint, scale, shadowOffset)

		rp = newReferencePoint:lower()
	
		-- Horizontal offsets
		if (stringFind(rp, "left")) then
			offsetX = w/2 - shadowOffset
		elseif (stringFind(rp, "right")) then
			offsetX = (w/-2) + shadowOffset
		else
			offsetX = 0
		end
		
		-- Vertical offsets
		if (stringFind(rp, "top")) then
			offsetY = h/2 - shadowOffset
		elseif (stringFind(rp, "bottom")) then
			offsetY = (h/-2) + shadowOffset
		else
			offsetY = 0
		end
		
		--x = math.floor( (x + offsetX) * scale)
		--y = math.floor( (y + offsetY) * scale)

		x = math.floor( x + (offsetX * scale))
		y = math.floor( y + (offsetY * scale))

--print ("b) referenceAdjustedXY adjustedment:", x, y, scale, shadowOffset)
	end	
	return x,y
end


function fixCapsForReferencePoint(r)
	if (r) then
		r = tostring(r)
		r = r:gsub("top", "Top")
		r = r:gsub("bottom", "Bottom")
		r = r:gsub("left", "Left")
		r = r:gsub("right", "Right")
		r = r:gsub("center", "Center")
	end
	return r
end


---------------
-- positionObject
-- Given user settings for x,y, return the real x,y in the space of width x height
-- margins = {top,bottom,left,right} margins/padding
-- x can be left, center, right, a number, or a percent
-- y can be top, center, bottom, a number, or a percent
-- ref is the reference point, used like this: display[ref]
-- Example: x,y = positionObject("left", "center", screenW, screenH)
-- This is based on 0,0 being the center of the space defined by w x h
-- Default w,h is the screen.

function positionObject(x,y,w,h,margins)
	w = w or screenW
	h = h or screenH

	x = funx.applyPercent(x,w) or 0
	y = funx.applyPercent(y,h) or 0
	
	-- Horizontal offsets
	if (x == "left") then
		xpos = w/-2 + margins.left
	elseif (x == "right") then
		xpos = (w/2) - margins.right
	elseif (x == "center") then
		xpos = 0
	else
		xpos = x
	end
	
	-- Vertical offsets
	if (y == "top") then
		ypos = h/-2 + margins.top
	elseif (y == "bottom") then
		ypos = (h/2) - margins.bottom
	elseif (y == "center") then
		ypos = 0
	else
		ypos = y
	end
	
	return xpos, ypos
end

---------------
-- positionObjectWithReferencePoint
-- Given user settings for x,y, return the real x,y in the space of width x height
-- margins = {top,bottom,left,right} margins/padding
-- x can be left, center, right, a number, or a percent
-- y can be top, center, bottom, a number, or a percent
-- ref is the reference point, used like this: display[ref]
-- Example: x,y = positionObject("left", "center", screenW, screenH)
-- This is based on 0,0 being the center of the space defined by w x h
-- Default w,h is the screen.
-- refPointSimpleText=true means do NOT return "ReferencePoint" with the position text,
-- i.e. instead of "TopLeftReferencePoint" just return "TopLeft"
-- Default is FALSE
--
-- WHY BE BASED ON THE CENTER OF THE PARENT OBJECT?
-- The reason we want to position based on center of the space provided is that we 
-- can easily center objects that way.
-- Also, we can easily position something inside another group this way. If you have a 
-- picture inside a box, this function returns its proper position in the box, so you
-- only need to set the x,y.

function positionObjectWithReferencePoint(x,y,w,h,margins, absoluteflag, refPointSimpleText)
	w = w or screenW
	h = h or screenH
	absoluteflag = absoluteflag or false
	
	if (not margins or absoluteflag) then
		margins = {left = 0, right=0, top=0, bottom=0 }
	end

	x = funx.applyPercent(x,w) or 0
	y = funx.applyPercent(y,h) or 0

	local xref = "Left"
	local yref = "Top"
	
	-- Horizontal offsets
	if (x == "left") then
		xpos = w/-2 + margins.left
		xref = "Left"
	elseif (x == "right") then
		xpos = (w/2) - margins.right
		xref = "Right"
	elseif (x == "center") then
		xpos = 0
		xref = "Center"
	else
		xpos = x - (w/2) + margins.left
		xref = "Left"
	end
	
	-- Vertical offsets
	if (y == "top") then
		ypos = h/-2 + margins.top
	elseif (y == "bottom") then
		ypos = (h/2) - margins.bottom
		yref = "Bottom"
	elseif (y == "center") then
		ypos = 0
		yref = "Center"
	else
		ypos = y - (h/2) + margins.top
		yref = "Top"
	end
	
	-- avoid "CenterCenter"...
	if (xref == "Center" and yref == "Center") then yref="" end
	
	--print (xpos, ypos, yref..xref.."ReferencePoint")	
	if (refPointSimpleText) then
		return xpos, ypos, yref..xref
	else
		return xpos, ypos, yref..xref.."ReferencePoint"
	end
end

--------------
-- Check that a key in table 1 exists in table 2.
-- Useful for making sure the a setting value in the user settings is correctly named.
-- example: keysExistInTable(usersettings,settings)
function keysExistInTable(t1,t2)
	for k,v in pairs (t1) do
		if (type(v) == "table") then
			for kk,vv in pairs (v) do
				if (t2[k] == nil or t2[k][kk] == nil) then
					print ("WARNING: '"..k.." . "..kk.." is an unknown key.")
				end
			end
		end
	end

end
