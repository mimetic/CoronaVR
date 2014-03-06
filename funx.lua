-- funx.lua
--
-- Version 0.2
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

local FUNX = {}


-- Requires json library
local json = require ( "json" )
local lfs = require ( "lfs" )
local widget = require ("widget")

-- Used by tellUser...the handler for the timed message
local timedMessage = nil
local timedMessageList = {}

-- Make a local copy of the application settings global
local screenW, screenH = display.contentWidth, display.contentHeight
local viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
local screenOffsetW, screenOffsetH = display.contentWidth -	 display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
local midscreenX = screenW*(0.5)
local midscreenY = screenH*(0.5)

-- functions
local floor = math.floor
local min = math.min
local max = math.max
local random = math.random
local match = string.match
local gmatch = string.gmatch
local find = string.find
local gfind = string.gfind

-- ALPHA VALUES, can change for RGB or HDR systems
local OPAQUE = 255
local TRANSPARENT = 0







-- -------------------------------------------------------------
-- GRAPHICS 2.0 POSITIONING
-- ------------------------------------------------------------

-----------
-- Shortcut to set x,y to 0,0
local function toZero(o)
	o.x, o.y  = 0,0
end

-----------
-- Shortcut to set anchors to top-left
local function anchorTopLeft(o)
	o.anchorX, o.anchorY = 0,0
end

-----------
-- Shortcut to set anchors to top-left
local function anchorCenter(o)
	o.anchorX, o.anchorY = 0.5, 0.5
end

-----------
-- Shortcut to set anchors to top-left and x,y to 0,0
local function anchorTopLeftZero(o)
	o.anchorX, o.anchorY = 0,0
	o.x, o.y  = 0,0
end

-----------
-- Shortcut to set anchors to center and x,y to 0,0
local function anchorCenterZero(o)
	o.anchorX, o.anchorY = 0.5, 0.5
	o.x, o.y  = 0,0
end

-----------
-- Shortcut to set anchors to top-left and x,y to 0,0
local function anchorBottomRightZero(o)
	o.anchorX, o.anchorY = 1,1
	o.x, o.y  = 0,0
end

-- Add an invisible positioning rectangle for a group
local function addPosRect(g, vis, c)
	local r = display.newRect(g, 0,0,10,10)
	r.isVisible = vis
	c = c or {250,0,0,100}
	r:setFillColor(unpack(c))
	anchorTopLeftZero(r)
	return g
end



local function centerInParent(g)
	anchorCenter(g)
	g.x = g.parent.width/2
	g.y = g.parent.height/2
return g
end

-- ------------------------------------------------------------
-- Get index in system table of a system directory
-- ------------------------------------------------------------
local function indexOfSystemDirectory( systemPath )
	local i = ""
	if (systemPath == system.DocumentsDirectory) then
		i = "DocumentsDirectory"
	elseif (systemPath == system.ResourceDirectory) then
		i = "ResourceDirectory"
	elseif (systemPath == system.CachesDirectory) then
		i = "CachesDirectory"
	end
	return i
end



-- ------------------------------------------------------------
-- DEBUGGING Timer
-- ------------------------------------------------------------
local firstTime = system.getTimer()
local lastTimePassed = system.getTimer()
local function timePassed(msg)
	local t2 = system.getTimer()
	local t = t2 - lastTimePassed
	lastTimePassed = t2
	msg = msg or ""
	print ("funx.timePassed: ", math.floor(t) .. "ms", msg) --, "Total:", math.floor(t2-firstTime))
	io.flush( )
end


-----------------
-- 'n' is the call stack level to show
-- '2' will show the calling function
local function printFuncName(n)
	n = n or 2
	local info = debug.getinfo(n, "Snl")
	if info.what == "C" then   -- is a C function?
	  print(n, "C function")
	else   -- a Lua function
	  print(string.format("[%s]:%d", info.name, info.currentline))
	end
end


local function isTable(t)
	return (type(t) == "table")
end


-----------------
local function traceback ()
	print ("FUNX.TRACEBACK:")
	local level = 1
	while true do
		local info = debug.getinfo(level, "Sl")
		if not info then break end
		if info.what == "C" then	 -- is a C function?
			print(level, "C function")
		else	 -- a Lua function
			print(string.format("[%s]:%d",
								info.short_src, info.currentline))
		end
		level = level + 1
	end
end

-----------------
-- Fails for negatives, apparently
local function round2(num, idp)
	local mult = 10^(idp or 0)
	return floor(num * mult + 0.5) / mult
end

local function round(num, idp)
  return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

-----------------
-- Given a value from an XML element, it could be x=y or x.value=y
-- Return y in either case.
-- If asNil is true, then if the value is "" or nil, return nil
local function getValue(x,asNil)
	local r
	if (type(x) == "table") then
		if (x.value) then
			r = x.value
		elseif (x.Attributes and x.Attributes.value) then
			r = x.Attributes.value
		elseif (x._attr and x._attr.value) then
			r = x._attr.value
		end
	else
		r = x
	end
	if (asNil and (r == "" or r == nil or r == false)) then
		r = nil
	end
	return r
end


--------------
-- unescape/escape a hex string
local function unescape (s)
	if (not s) then
		return ""
	end
	s = string.gsub(s, "+", " ")
	s = string.gsub(s, "%%(%x%x)", function (h)
		return string.char(tonumber(h, 16))
	end)
	return s
end

local function escape(s)
	s = string.gsub(s, "([&=+%c])", function(c)return string.format("%%%02X", string.byte(c))end)
	s = string.gsub(s, " ", "+")
	return s
end

--=========
--- Remove a value from a table. The table is searched and the value removed from it.
local function removeFromTable(t,obj)
	for i,o in pairs(t) do
		if (o == obj) then
			t[i] = nil
			print ("removeFromTable: removed item #" .. i)
			return true
		end
	end
	return false
end


-----------------
-- Table is empty?
local function tableIsEmpty(t)
	if (t and type(t) == "table" ) then
		if (next(t) == nil) then
			return true
		end
	end
	return false
end

-----------------
-- Length of a table, i.e. number elements in it.
local function tablelength (t)
	if (type(t) ~= "table") then
		return 0
	end
	local count = 0
	for _, _ in pairs(t) do
		count = count + 1
	end
	return count
end


-- Delete fields of the form {{x}} in the string s
local function removeFields (s)
	if (not s) then return nil end
	local r = gfind(s,"%{%{.-%}%}")
	local res = s
	for w in r do
		res = trim(string.gsub(res, w, ""))
	end
	return res
end

-- Delete fields of the form {x} in the string s
local function removeFieldsSingle (s)
	if (not s) then return nil end
	local r = gfind(s,"%b{}")
	local res = s
	for w in r do
		res = trim(string.gsub(res, w, ""))
	end
	return res
end

--===========
--- Escape keys in tables so the key name can be used in a gsub search/replace
-- @param t Table with keys that might need escaping
-- @return	res	Key:value pairs: original key => clean key
-- e.g. { "icon-1" = "myicon.jpg" } ===> { "icon-1" = "icon%-1" }
local function getEscapedKeysForGsub(t)
	local gsub = string.gsub
	-- Chars to escape: ( ) . % + - * ? [ ^ $
	local res = {}
	for i,v in pairs(t) do
		res[i] = gsub(i, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
	end
	return res
end


--- Substitute for {{x}} with table.x from a table.
-- There can be multiple fields in the string, s.
-- Returns the string with the fields filled in.
-- @param s	String with codes to replace
-- @param t	Table of key:value pairs to use for replacement (search for key)
-- @param escapeTheKeys	if TRUE then escape the keys of the subsitutions table (t), if a table then use that table as the escaped keys table
-- @return s	string with replacements
local function substitutions (s, t, escapeTheKeys)
	local gsub = string.gsub

	if (not s or not t or t=={}) then
		--print ("funx.substitutions: No Values passed!")
		return s
	end

	local tclean = {}
	if (escapeTheKeys) then
		if (type(escapeTheKeys) == "table") then
			tclean = escapeTheKeys
		else
			tclean = getEscapedKeysForGsub(t)
		end
	end

	local r = gfind(s,"%{%{(.-)%}%}")
	for w in r do
		local searchTerm = tclean[w] or w
		if (t[w]) then
			s = gsub(s, "{{"..searchTerm.."}}", t[w])
--print ("{{"..searchTerm.."}}", t[w],s)
		end
	end
	return s
end



-- Substitute for {x} with table.x from a table.
-- There can be multiple fields in the string, s.
-- Returns the string with the fields filled in.
local function OLD_substitutionsSLOWER (s, t)
	if (not s or not t or t=={}) then
		--print ("funx.substitutions: No Values passed!")
		return s
	end
	--local r = gfind(s,"%b{}")
	local r = gfind(s,"%{%{.-%}%}")
	local res = s
	for w in r do
		local i,j = string.find(w, "%{%{(.-)%}%}")
		local k = string.sub(w,i+2,j-2)
		if (t[k]) then
			res = string.gsub(res, w, t[k])
		end
--print ("substitutions for in "..res.." for {{"..k.."}} with ",t[k], "RESULT:",res)


	end
	return res
end



--===========
--- Replace all substitutions in the entire table, including
-- nested tables.
-- @param t Table in which to substitute
-- @param subs table Table of substitutions
local function tableSubstitutions(t, subs, escapeTheKeys)
	if (type(t) ~= "table") then
		return t
	end

	if (type(subs) ~= "table" or not subs or subs == {} ) then
		return t
	end

	if (escapeTheKeys) then
		if (type(escapeTheKeys) == "table") then
			tclean = escapeTheKeys
		else
			tclean = getEscapedKeysForGsub(subs)
		end
	end


	for i,element in pairs(t) do
		if (i ~= "screen") then
			if (type(element) == "string") then
				 t[i] = substitutions (element, subs, tclean)
--print ("element:", element, t[i])
			elseif (type(element) == "table") then
				 tableSubstitutions( t[i], subs, tclean)
			elseif (element == "[[null]]" or element == "[[NULL]]" ) then
				 t[i] = nil
			end
		end
	end
end



--===========
--- Remove elements that contain unresolved {{}} codes.
-- @param t Table in which to substitute
local function tableRemoveUnusedCodedElements(t )
	if (type(t) ~= "table") then
		return t
	end

	for i,element in pairs(t) do
		if (i ~= "screen") then
			if (type(element) == "string" and string.find(element, "%{%{.-%}%}")) then
--print ("tableRemoveUnusedCodedElements: Remove ", t[i])
				t[i] = ""
			elseif (type(element) == "table") then
				 tableRemoveUnusedCodedElements( t[i] )
			end
		end
	end
end





-- hasFieldCodes(s)
-- Return true/false if the string has field codes, i.e. {x} inside it
local function hasFieldCodes(s)
	if (type(s) ~= "string") then
		return false
	end
	s = s or ""
	local r = string.find(s,"%{%{.-%}%}")
	if (r) then
		return true
	else
		return false
	end
end



-- hasFieldCodes(s)
-- Return true/false if the string has field codes, i.e. {x} inside it
local function hasFieldCodesSingle(s)
	if (type(s) ~= "string") then
		return false
	end
	s = s or ""
	local r = string.find(s,"%b{}")
	if (r) then
		return true
	else
		return false
	end
end


-- Get element name from string.
-- If the string is {{xxx}} then the field name is "xxx"
local function getElementName (s)
	local r = gfind(s,"%{%{(.-)%}%}")
	local res = "RESULT: "..s
	for w in r do
		print ("extracted ",w)
		break
	end
	return w
end


-- Dump an XML table
local function dump(_class, no_func, depth)
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
-- tableCopy
local function tableCopy(object)
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
-- Remove white space from a string, OR table of strings
-- recursively
-- Only act on strings
-- If flag set, return nil for an empty string
local function trim(s, returnNil)
	if (s) then
		if (type(s) == "table") then
			for i,v in ipairs(s) do
				s[i] = trim(v, returnNil)
			end
		elseif (type(s) == "string") then
			s = s:gsub("^%s*(.-)%s*$", "%1")
		end
	end
	if (returnNil and s == "") then
		return nil
	end
	return s
end


--------------------------------------------------------
-- ltrim
-- Remove white space from the start of a string, OR table of strings recursively
-- Only act on strings
-- If flag set, return nil for an empty string
local function ltrim(s, returnNil)
	if (s) then
		if (type(s) == "table") then
			for i,v in ipairs(s) do
				s[i] = ltrim(v, returnNil)
			end
		elseif (type(s) == "string") then
			s = s:gsub("^%s*(.-)", "%1")
		end
	end
	if (returnNil and s == "") then
		return nil
	end
	return s
end


--------------------------------------------------------
-- rtrim
-- Remove white space from the end of a string, OR table of strings recursively
-- Only act on strings
-- If flag set, return nil for an empty string
local function rtrim(s, returnNil)
	if (s) then
		if (type(s) == "table") then
			for i,v in ipairs(s) do
				s[i] = rtrim(v, returnNil)
			end
		elseif (type(s) == "string") then
			s = s:gsub("(.-)%s*$", "%1")
		end
	end
	if (returnNil and s == "") then
		return nil
	end
	return s
end



--------------------------------------------------------
-- table merge
-- Overwrite elements in the first table with the second table!
local function tableMerge(t1, t2)
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



local function split(str, pat, doTrim)
	pat = pat or ","
	if (not str) then
		return nil
	end
	str = tostring(str)
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




-------------------------------------------------
--- GET DEVICE SCALE FACTOR FOR RETINA RESIZING
--1 = no need to change anything
--2 = multiply by 2
-- examples:
--	local scalingRatio = scaleFactorForRetina()
--	local scalesuffix = "@"..scalingRatio.."x"
--
--	local scalingRatio = 1/scaleFactorForRetina()
--	width = width/scalingRatio
--	height = height/scalingRatio

-------------------------------------------------
local function scaleFactorForRetina()
	local deviceWidth = ( display.contentWidth - (display.screenOriginX * 2) ) / display.contentScaleX
	local scaleFactor = math.floor( deviceWidth / display.contentWidth )
	return scaleFactor
end


-------------------------------------------------
-- CHECK IMAGE DIMENSION & SCALE ACCORDINGLY
-------------------------------------------------
local function checkScale(p)
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
local function resizeFromIpad(p)
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
local function rescaleFromIpad(x,y)

	-- Do nothing if this is an iPad screen!
	if ( (screenW == 1024 and screenH == 768) or (screenW == 768 and screenH == 1024) )then
		return x,y
	end

	if (x == nil) then
		return 0,0
	end
	--print ("viewableScreenW="..viewableScreenW..", viewableScreenH="..viewableScreenH)

	local currentR = viewableScreenW/viewableScreenH
	local ipadR = 1024/768
	local fixedH = 768
	local fixedW = 1024


	if (currentR > 1) then
		ipadR = 1/ipadR
		fixedH = 1024
		fixedW = 768
	end
	local r

	if (currentR > ipadR) then
		-- use ration based on different heights
		r = viewableScreenH / fixedH
	else
		r = viewableScreenW / fixedW
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


-- If the value is a percentage, multiply by the 2nd param, else return the 1st param
-- value is rounded to nearest integer, UNLESS the 2nd param is less than 1
-- or noRound = true
-- If x is nil, but y is not, then return the y (i.e. assume 100%)
local function applyPercent (x,y,noRound)
	if (x == nil and y == nil) then
		return nil
	end

	if (x == nil and y ~= nil) then
		return tonumber(y)
	end

	x = x or 0
	y = y or 0
	local v = string.match(trim(x), "(.+)%%$")
	if v then
		v = (v / 100) * y
		if ((not noRound) and (y>1)) then
			v = math.floor(v+0.5)
		end
	else
		v = x
	end
	return tonumber(v)
end

-- ===========
--- Get a percentage of the screen height
-- @param y
-- @param noRound If false, value NOT rounded to nearest integer
local function percentOfScreenHeight (y,noRound)
	return applyPercent (y, screenH, noRound)
end

-- ===========
--- Get a percentage of the screen height
-- @param y
-- @param noRound If false, value NOT rounded to nearest integer
local function percentOfScreenWidth (x,noRound)
	return applyPercent (x, screenW, noRound)
end

--------------------------------------------------------
-- File Exists
-- default directory is system.ResourceDirectory
-- not system.DocumentsDirectory
--------------------------------------------------------

local function fileExists(f,d)
	if (f) then
		d = d or system.ResourceDirectory
		local filePath = system.pathForFile( f, d )
		local exists = false
		-- Determine if file exists
		if (filePath ~= nil) then
			local fileHandle = io.open( filePath, "r" )
			if (fileHandle) then -- nil if no file found
				exists = true
				io.close(fileHandle)
			else
				--print ("WARNING: Missing file: ",tostring(filePath))
			end
		end
	   return (exists)
	else
		--print ("WARNING: Missing file: ",tostring(filePath))
		return false
	end
end




------------------------------------------------------------------------
-- Save table, load table, default from documents directory
------------------------------------------------------------------------

----------------------
-- Save/load functions

local function saveData(filePath, text)
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

local function loadData(filePath)
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

local function saveTableToFile(filePath, dataTable)

	--local levelseq = table.concat( levelArray, "-" )
	file = io.open( filePath, "w" )

	for k,v in pairs( dataTable ) do
		file:write( k .. "=" .. v .. "," )
	end

	io.close( file )
end


-- Load a table form a text file.
-- The table is stored as comma-separated name=value pairs.
local function loadTableFromFile(filePath, s)
	local substring = string.sub

	if (not filePath) then
		print ("WARNING: loadTableFromFile: Missing file name.")
		return false
	end

	local file = io.open( filePath, "r" )

	-- separator, default is comma
	s = s or ","

	if file then

		-- Read file contents into a string
		local dataStr = file:read( "*a" )

		-- Break string into separate variables and construct new table from resulting data
		local datavars = split(dataStr, s)

		local dataTableNew = {}

		for i = 1, #datavars do
			local firstchar = substring(trim(datavars[i]),1,1)
			-- split each name/value pair
			if ( not ((firstchar == "#") or (firstchar == "/") or (firstchar == "-") ) ) then
				local onevalue = trim(split(datavars[i], "="))
				if (onevalue[1]) then
					dataTableNew[onevalue[1]] = onevalue[2]
				end
			end
		end

		io.close( file ) -- important!

		-- Note: all values arrive as strings; cast to numbers where numbers are expected
		dataTableNew["randomValue"] = tonumber(dataTableNew["randomValue"])

		return dataTableNew
	else
		print ("WARNING: loadTableFromFile: File not found ("..filePath..")")
		return false
	end
end

local function saveTable(t, filename, path)
	if (not t or not filename) then
		return true
	end

	path = path or system.DocumentsDirectory
	--print ("funx.saveTable: save to "..filename)

	local json = json.encode (t)
	local filePath = system.pathForFile( filename, path )
	return saveData(filePath, json)
end

local function loadTable(filename, path)
	path = path or system.DocumentsDirectory
	if (fileExists(filename,path)) then
		local filePath = system.pathForFile( filename, path )
		--print ("funx.loadTable: load from "..filePath)

		local t = {}
		local f = loadData(filePath)
		if (f and f ~= "") then
			t = json.decode(f)
		end
		--print ("loadTable: end")
		return t
	else
		return false
	end
end


------------------------------------------------------------------------
-- Image loading
------------------------------------------------------------------------
local function getScaledFilename(filename, d)
	local scalingRatio = scaleFactorForRetina()

	if (scalingRatio <= 1) then
		return filename, scalingRatio
	else
		local scalesuffix = "@"..scalingRatio.."x"

		-- Is there an other sized version?
		local suffix = string.sub(filename, string.len(filename)-3, -1)
		local name = string.sub(filename, 1, string.len(filename)-4)
		local f2 = name .. scalesuffix .. suffix

		-- If no scaled file, get original
		if (fileExists(f2,d)) then
			filename = f2
			return filename, scalingRatio
		else
			return filename, 1
		end
	end
end

----------------------------------------------------------------------
-- Get an image size (height, width)
-- We need this to use it for display.newImageRect
-- Let's keep a list of image sizes so we can avoid double-loading.align
-- Every time we load, save the size to a list we maintain.
----------------------------------------------------------------------
-- Get an image size (height, width)
-- We need this to use it for display.newImageRect
-- Let's keep a list of image sizes so we can avoid double-loading.align
-- Every time we load, save the size to a list we maintain.
-- *** The first time, the list will be taken from the resources directory!

local ImageInfoList = loadTable("images_info.json", system.CachesDirectory)
if (not ImageInfoList) then
	ImageInfoList = loadTable("_user/images_info.json", system.ResourceDirectory) or {}
end

local function getImageSize(f,d)
	d = d or system.ResourceDirectory

	-- load info table, if not loaded
	if (not ImageInfoList) then
		ImageInfoList = loadTable("images_info.json", system.CachesDirectory)
	end

	-- Check the sizes list for this image
	if (ImageInfoList[f]) then
		return ImageInfoList[f].width, ImageInfoList[f].height
	else
		-- add to the list
		local i = display.newImage(f,d,true)
		local w = i.contentWidth
		local h = i.contentHeight
		i:removeSelf()
		i = nil

		ImageInfoList[f] = { width = w, height = h }
		saveTable(ImageInfoList, "images_info.json", system.CachesDirectory)
		return w,h
	end
end


--------------------------------------------------------
-- An attempt to load images async, rather than force everything to wait.
-- SO FAR, IT DOESN'T QUITE WORK! IMAGES GET LOADED, BUT DON'T
-- END UP IN THE RIGHT PLACES.
local function getDisplayObjectParams(i)
	-- Save the useful values from the target we are replacing
	local params = {
		alpha = i.alpha,
		height = i.height,
		isHitTestMasked = i.isHitTestMasked,
		isHitTestable = i.isHitTestable,
		isVisible = i.isVisible,
		maskRotation = i.maskRotation,
		maskScaleX = i.maskScaleX,
		maskScaleY = i.maskScaleY,
		maskX = i.maskX,
		maskY = i.maskY,
		parent = i.parent,
		rotation = i.rotation,
		width = i.width,
		xReference = i.xReference,
		x = i.x,
		xOrigin = i.xOrigin,
		xScale = i.xScale,
		yReference = i.yReference,
		y = i.y,
		yOrigin = i.yOrigin,
		yScale = i.yScale,
	}
	return params
end


local function lazyLoad(target,f,w,h)

	local params, g
	if (target) then
		params = getDisplayObjectParams(target)
	end

	local function loadImage()
		if (target) then
			if (target.parent) then
				g = target.parent
			end
			target:removeSelf()
			--target = nil
		else
			target = {}
		end

		target = display.newImageRect(f,w,h)
		if (g) then
			g:insert(target)
		end

		for i,j in pairs (params) do
			if (i ~= "width" and i ~= "height") then
				target[i] = j
			end
		end
		print ("Loaded"..f )

	end

	timer.performWithDelay( 1000, loadImage )
end


--------------------------------------------------------
-- Replace placeholder directory in path name with real value
-- p : a single character placeholder, default is "*"
-- v : the real value, e.g. "mypath"
-- Any slashes must be in the original.
-- Example:
-- replaceWildcard ("*/images/pic.jpg", "mydir", "?")
--------------------------------------------------------

local function replaceWildcard(text, v, p)
--print ("funx.replaceWildcard", text, v, p)
	if (text and v) then
		p = p or "*"
		text = text:gsub("%"..p, v)
		end
	return text
end


--------------------------------------------------------
-- Load an image file. If it is not there, load a "missing image" file
-- filename is a full pathname, e.g. images/in/my/folder/pic.jpg
-- Default system directory is system.ResourceDirectory
-- If filepath is set, replace "*" in the filename with the filepath.
-- If no "*" in the filename, then the file MUST be a system file!
-- If there is a "*" in the filename, the file MUST be a user file, found in the CachesDirectory.
-- DEPRECATED: ALWAYS USE CORONA METHOD: method: true = use my method, false means use Corona method
--------------------------------------------------------
local function loadImageFile(filename, wildcardPath, whichSystemDirectory, showTraceOnFailure)
	local scalingRatio = 1
	local scaleFraction = 1
	local scalesuffix = ""
	local otherFound = false

	wildcardPath = wildcardPath or "_user"

	-- If the filename starts with a wildcard, then replace it with the wildcardPath
	local wc = string.sub(filename,1,1)
	if (wc == "*" and wildcardPath) then
		filename = replaceWildcard(filename, wildcardPath)

		-- Files inside _user are system files, everything else with a wildcard is
		-- a downloaded book.
		if (not find(wildcardPath, "^_user") ) then
		--if (wildcardPath ~= "_user") then
			whichSystemDirectory = whichSystemDirectory or system.CachesDirectory
		else
			whichSystemDirectory = whichSystemDirectory or system.ResourceDirectory
		end
	end

	-- default to system for files, e.g. _ui/mygraphic.jpg
	whichSystemDirectory = whichSystemDirectory or system.ResourceDirectory

	if (fileExists(filename, whichSystemDirectory)) then
		local image

		-- My method for loading images
		if (otherFound) then
		--local path = system.pathForFile( filename, whichSystemDirectory )
			image = display.newImage(filename, whichSystemDirectory, true)
			image:scale(scaleFraction, scaleFraction)
--print ("loadImageFile: Using my method:", filename)
		else
			-- Corona newImageRect version for loading images
			-- Check for a scaled file before loading it
			local f,s = getScaledFilename(filename, whichSystemDirectory)
--timePassed("loadImageFile start loading..."..filename)
			-- If scale comes back ~= 1 then there is a scaled version
			-- and there is need of one.
			if (s ~= 1) then
				local w,h = getImageSize(filename,whichSystemDirectory)
				image = display.newImageRect(filename, whichSystemDirectory, w, h)
--timePassed("loadImageFile, Loaded using newImageRect, C1:"..filename)
			else
				image = display.newImage(filename, whichSystemDirectory, true)
--timePassed("loadImageFile, loaded using newImage, C2:"..filename)
			end
--print ("loadImageFile: Using Corona method:", filename)
		end
		anchorCenterZero(image)

		return image, scaleFraction
	else
		
		-- DEBUGGING TOOL
		if (showTraceOnFailure) then
			print ("funx.loadImageFile called by:")
			traceback()
		end
	
		local i = display.newGroup()
		local image = display.newImage(i, "_ui/missing-image.png", system.ResourceDirectory, true)

		-- Write to the log!
		local syspath =  system.pathForFile( "", whichSystemDirectory )
		--print ("loadImageFile: whichSystemDirectory", syspath )
		if (syspath == "") then
				syspath = "ResourceDirectory"
		end
		print ("WARNING: loadImageFile cannot find ",filename," in ",syspath)

		local t = display.newText( "Cannot find:"..filename, 0, 0, native.systemFontBold, 24 )
		i:insert(t)
		image.x = midscreenX
		image.y = midscreenY
		t:setReferencePoint(display.CenterReferencePoint)
		t.x = midscreenX
		t.y = midscreenY+40
		i:setReferencePoint(display.CenterReferencePoint)
		i.x = 0
		i.y = 0
		-- second returned value is scaleFraction and 1 does nothing but won't crash stuff
		return i, 1
	end
end


--------------------------------------------------------
-- Verify Net Connection OR QUIT!
-- WARNING, THIS QUITS THE APP IF NO CONNECTION!!!
--------------------------------------------------------
local function verifyNetConnectionOrQuit()
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
-- url: a server to check (use http://...)
-- showActivity: Turn off the activity indicator (must be turned on before starting)
--------------------------------------------------------
local function hasNetConnection(url,showActivity)
	local socket = require("socket")
	local test = socket.tcp()
	test:settimeout(1, 't') -- timeout 1 sec

	url = url or "www.google.com"
	if (string.sub(url, 1, 4) == "http") then
		url = url:gsub("^https?://", "")
	end
	local testResult = test:connect(url,80)

	if (testResult == nil) then
		if (showActivity) then native.setActivityIndicator( false ) end
		return false
	else
		if (showActivity) then native.setActivityIndicator( false ) end
		return true
	end

end

--------------------------------------------------------
-- canConnectWithServer: return true if connected, false if not.
-- url: a server to check (use http://...)
-- showActivity: Turn off the activity indicator (must be turned on before starting)
--------------------------------------------------------
local function canConnectWithServer(url, showActivity, callback, testing)

			local function MyNetworkReachabilityListener(event)
				if (testing) then
					print( "url", url )
					print( "address", event.address )
					print( "isReachable", event.isReachable )
					print("isConnectionRequired", event.isConnectionRequired)
					print("isConnectionOnDemand", event.isConnectionOnDemand)
					print("IsInteractionRequired", event.isInteractionRequired)
					print("IsReachableViaCellular", event.isReachableViaCellular)
					print("IsReachableViaWiFi", event.isReachableViaWiFi)

					print("removing event listener")
				end
				network.setStatusListener( url, nil)

				-- Simulator bug or something...always returns failure
				local isSimulator = "simulator" == system.getInfo("environment")

				if (isSimulator) then
					event.isReachable = true
					print ("canConnectWithServer: Corona simulator: Forcing a TRUE for event.isReachable because this fails in simulator.")
				end

				-- Turn OFF native busy activity indicator
				if (showActivity) then
					native.setActivityIndicator( false )
				end


				if (type(callback) ~= "function") then
					return event.isReachable
				else
					callback(event.isReachable)
				end
			end

	if network.canDetectNetworkStatusChanges then
			network.setStatusListener( url, MyNetworkReachabilityListener )
	else
			print("funx.canConnectWithServer: network reachability not supported on this platform")
	end
end



--------------
--- Check that a key in table 1 exists in table 2.
-- Useful for making sure the a setting value in the user settings is correctly named.
-- example: keysExistInTable(usersettings,settings)
local function keysExistInTable(t1,t2)
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


--- Check if a value is in a table
-- Same as in_array(myarray, value)
local function inTable(needle, haystack) -- find element v of haystack satisfying f(v)
	if (haystack and type(haystack) == "table") then
		for _, v in ipairs(haystack) do
			if ( v == needle ) then
				return v
			end
		end
	end
	return nil
end

--------------
-- A Handy way to store an RGB or RGBA color is as a string, e.g. "250,250,10,50%"
-- The 4th value is an alpha, 0-255, or OPAQUE or TRANSPARENT
-- This returns a table from such a string.
-- If given a table, this does nothing (in case the value was already converted somewhere!)
--
-- If any value is between 0 & 1, then we must be dealing with HDR values, not RGB values
-- e.g. 0,0,2 must be RGB, but 0,0,0.1 must be HDR.
-- We only have a problem when the highest value is 1, but when would anyone use an RGB value of 1? Never.
-- Therefore, if all values <= 1 then it's and HDR value.
--
-- If toHDR, then force the result to be HDR. This is useful for widgets and other libraries
-- that don't let us redefine their display.setFillColor functions.

local function stringToColorTable(s, toHDR, isHDR)
	if (type(s) == "string") then
		s = trim(s, true)
		if (s) then
			s = split(s, ",")

			local maxVal = 255	-- RGB max
			--[[
			local valSum = ( tonumber(s[1]) or 0) + (tonumber(s[2]) or 0) + (tonumber(s[3]) or 0)
			if ( isHDR or  ( valSum > 0 and valSum <= 3 ) ) then
				maxVal = 1	-- HDR max
			end
			--]]
			
			local opacity = string.lower(s[4] or maxVal)
			if ( opacity == "opaque" ) then
				s[4] = maxVal
			elseif (opacity == "transparent") then
				s[4] = 0
			else
				s[4] = applyPercent(s[4], maxVal) or maxVal
			end
			-- force numeric
			for i,j in pairs(s) do
				s[i] = tonumber(j)
				s[i] = applyPercent(j,maxVal) or maxVal
			end
			
			if (toHDR) then
				s = { s[1]/255, s[2]/255, s[3]/255, s[4]/255 }
			end
		end
	end
	return s
end

-- *** Apparently, not necessary! I built this due to a bug in the dmc_kolor patch.
-- Here's a shortcut for getting an HDR color from RGB or HDR values
-- Set isHDR to true if the input string uses HDR values
local function stringToColorTableHDR(s, isHDR)
	return stringToColorTable(s, true, isHDR)
end


-------------------------------------------------
-- Darken the screen
-- by drawing a dark opaque rectangle over it.
-- Returns the darkening object.
-- Undim, below, will destroy the object.
-- Because the object which will contain the image might
-- be scaled, we need to include a scaling
-- factor, to adjust the screen image.
-- locked: default is no lock, if true then lock the screen from touches
-------------------------------------------------
local function dimScreen(transitionTime, color, scaling, locked)

	transitionTime = transitionTime or 300
	opacity = applyPercent(opacity,1) or 190/255
	scaling = scaling or 1
	local c = stringToColorTable(color or "55,55,55,75%")
	-- cover all rect, darken background
	local bkgdrect = display.newRect(0,0,screenW,screenH)
	bkgdrect.x, bkgdrect.y = midscreenX, midscreenY
	bkgdrect:setFillColor( unpack(c) )
	bkgdrect:scale(1/scaling, 1/scaling)
	transition.to (bkgdrect, {alpha=opacity, time=transitionTime } )

	bkgdrect:addEventListener("touch", function() return locked end )

	return bkgdrect
end

local function undimScreen(handle, transitionTime, f)
		local function killme()
			display.remove(handle)
			handle = nil
			if (type(transitionTime) == "function") then
				transitionTime()
			elseif (type(f) == "function") then
				f()
			end
		end

	local t
	if (type(transitionTime) == "number") then
		t = transitionTime
	else
		t = 300
	end

	transition.to (handle, {alpha=0, time=t, onComplete=killme } )
end


-------------------------------------------------
-- POPUP: popup image with close button
-- We have white and black popups. Default is white.
-- If the first param is a table, then we assume all params are in that table, IN ORDER!!!,
-- starting with filename, e.g. { "filename.jpg", "white", 1000, true}
-------------------------------------------------
local function popup(filename, color, bkgdAlpha, transitionTime, cancelOnTouch)

	local mainImage
	local pgroup = display.newGroup()
	pgroup.anchorChildren = true
	
	local closing = false

	if (type(filename) == "table") then
		color = filename.color
		bkgdAlpha = filename.bkgdAlpha
		transitionTime = tonumber(filename.time)
		cancelOnTouch =	 filename.cancelOnTouch or false
		filename = trim(filename.filename)
	end

	bkgdAlpha = applyPercent(bkgdAlpha, 1)

	color = trim(color)
	if (color == "") then
		color = "white"
	end

	bkgdAlpha = applyPercent(bkgdAlpha,1) or 0.95

	transitionTime = tonumber(transitionTime)
	transitionTime = transitionTime or 300

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
			transition.to (pgroup, {alpha=0, time=transitionTime, onComplete=killme} )
			closing = true
		end
		return true
	end
	-- cover all rect, darken background
	local bkgdrect = display.newRect(0,0,screenW,screenH)
	pgroup:insert(bkgdrect)
	bkgdrect:setFillColor( 55, 55, 55, 190 )
	-- background graphic for popup
	-- If the default fails, try using the value as a filename
	local bkgd = display.newImage("_ui/popup-"..color..".png", true)
	if (not bkgd) then
		bkgd = display.newImage(color, true)
		if (not bkgd) then
			print ("ERROR: Missing popup background image ("..color..")")
		end
	end
	local bkgdWidth, bkgdHeight
	if (bkgd) then
		checkScale(bkgd)
		pgroup:insert (bkgd)
		bkgd:setReferencePoint(display.CenterReferencePoint)
		bkgd.x = midscreenX
		bkgd.y = midscreenY
		bkgd.alpha = bkgdAlpha
		bkgdWidth = bkgd.width
		bkgdHeight = bkgd.height
	else
		bkgdWidth = screenW * 0.95
		bkgdHeight = screenH * 0.95
	end

	mainImage = display.newImage(filename, true)
	checkScale(mainImage)
	pgroup:insert (mainImage)
	mainImage:setReferencePoint(display.CenterReferencePoint)
	mainImage.x = midscreenX
	mainImage.y = midscreenY

	local closeButton = widget.newButton{
		defaultFile = "_ui/button-cancel-round.png",
		overFile = "_ui/button-cancel-round-over.png",
		onRelease = closeMe,
	}
	pgroup:insert(closeButton)
	anchorCenterZero(closeButton)
	closeButton.x = (bkgd.width/2) - closeButton.width/4
	closeButton.y = -(bkgd.height/2) + closeButton.height/4
	closeButton:toFront()

	pgroup.alpha = 0

	-- Capture touch events and do nothing.
	if (cancelOnTouch) then
		pgroup:addEventListener( "touch", closeMe )
	else
		pgroup:addEventListener( "touch", function() return true end )
	end

	transition.to (pgroup, {alpha=1, time=transitionTime } )

end



-------------------------------------------------
-- POPUP: popup image with close button
-- We have white and black popups. Default is white.
-- If the first param is a table, then we assume all params are in that table, IN ORDER!!!,
-- starting with filename, e.g. { "filename.jpg", "white", 1000, true}
-------------------------------------------------
local function popupWebpage(targetURL, color, bkgdAlpha, transitionTime, netrequired, noNetMsg)

	noNetMsg = noNetMsg or "No Internet"

	if (netrequired and not hasNetConnection() ) then
		tellUser(noNetMsg)
		return false
	end

	local mainImage
	local pgroup = display.newGroup()
	anchorCenter(pgroup)
	pgroup.x, pgroup.y = midscreenX, midscreenY
	
	local closing = false
	if (type(targetURL) == "table") then
		color = trim(targetURL[2])
		bkgdAlpha = tonumber(targetURL[3])
		transitionTime = tonumber(targetURL[4])
		targetURL = trim(targetURL[1])
	end

	color = color or "white"

	bkgdAlpha = bkgdAlpha or 0.95
	transitionTime = transitionTime or 300

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
			transition.to (pgroup, {alpha=0, time=transitionTime, onComplete=killme} )
			closing = true
		end
		return true
	end


	-- cover all rect, darken background
	local bkgdrect = display.newRect(0,0,screenW,screenH)
	pgroup:insert(bkgdrect)
	anchorCenter(bkgdrect)
	bkgdrect:setFillColor( 55, 55, 55, 190 )

	-- background graphic for popup
	local bkgd = display.newImage("_ui/popup-"..color..".png", true)
	checkScale(bkgd)
	pgroup:insert (bkgd)
	anchorCenter(bkgdrect)
	bkgd.alpha = bkgdAlpha

	local closeButton = widget.newButton {
	    id = "close",
	    defaultFile = "_ui/button-cancel-round.png",
	    overFile = "_ui/button-cancel-round-over.png",
	    onRelease = closeMe,
	}
	pgroup:insert(closeButton)
	closeButton:setReferencePoint(display.TopRightReferencePoint)
	anchorCenterZero(closeButton)
	closeButton.x = (bkgd.width/2) - closeButton.width/4
	closeButton.y = -(bkgd.height/2) + closeButton.height/4
	closeButton:toFront()
	
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
	transitionTime = tonumber(transitionTime)
	transition.to (pgroup, {alpha=1, time=transitionTime, onComplete=showMyWebPopup } )
end



------------------------------------------------------------------------
-- OPEN a URL
------------------------------------------------------------------------
local function openURLWithConfirm(urlToOpen, title, msg)

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
-- SHADOW - Image-based version for Graphics 1.0
-- Build a drop shadow
------------------------------------------------------------------------

local function buildShadow1(w,h)
	local ceil = math.ceil
	local shadow = display.newGroup()
	shadow.anchorChildren = true

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
	--local srect = display.newRect(shadow, corner,corner,w-(2*corner),h-(2*corner))
	-- Alpha visually matches the graphic pieces. Probably we should use another graphic
	--srect:setFillColor( 0,0,0,70 )

	local srect = display.newImage(shadow, "_ui/shadow_rect.png")
	srect.width = w - (2*corner)
	srect.height = h - (2*corner)
	srect:setReferencePoint(display.TopLeftReferencePoint)
	srect.x = corner
	srect.y = corner



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
-- SHADOW - Filter Effects based using Graphics 2.0
-- Build a drop shadow
------------------------------------------------------------------------


local function buildShadow(w,h,sw,opacity)

	sw = sw or 20
	local shadow = display.newSnapshot( w + 2*sw, h + 2*sw )
	
	opacity = opacity or OPAQUE
	opacity = applyPercent( opacity, OPAQUE)

	-- Start with a solid rect
	local srect = display.newRect(0,0,w + 1*sw,h + 1*sw)
	-- Alpha visually matches the graphic pieces. Probably we should use another graphic
	srect:setFillColor( 0,0,0, opacity )
	
	shadow.group:insert(srect)
	
	shadow.fill.effect = "filter.blurGaussian"
	shadow.fill.effect.horizontal.blurSize = sw
	shadow.fill.effect.horizontal.sigma = 140
	shadow.fill.effect.vertical.blurSize = sw
	shadow.fill.effect.vertical.sigma = 140

	--shadow.fill.effect = "filter.blur"

	return shadow

end



------------------------------------------------------------------------
-- Functions to do on a system event,
-- e.g. load or exit
-- Options:
-- options.onAppStart = function for start or resume
-- options.onAppExit = function for exit or suspend
------------------------------------------------------------------------

local function initSystemEventHandler(options)

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

		if (event.type == "applicationExit" ) then
			options.onAppExit()
		elseif ( event.type == "applicationSuspend" ) then
			options.onAppSuspend()
		elseif ( event.type == "applicationStart" ) then
			options.onAppStart()
		elseif ( event.type == "applicationResume" ) then
			options.onAppResume()
		end

		--[[
		if ( (event.type == "applicationExit" or event.type == "applicationSuspend") and type(options.onAppExit) == "function" ) then
			options.onAppExit()
		elseif ( (event.type == "applicationStart" or event.type == "applicationResume")  and type(options.onAppStart) == "function"  ) then
			if shouldResume() then
				options.onAppStart()
			else
				-- start app up normally
			end
		end
		--]]
	end
	---------------------

	Runtime:addEventListener( "system", onSystemEvent );
end


--=====================================================
-- the reason this routine is needed is because lua does not
-- have a sort indexed table function
-- reverse : if set, sort reverse
local function table_sort(a, sortfield, reverse)
	local new1 = {}
	local new2 = {}
	for k,v in pairs(a) do
		table.insert(new1, { key=k, val=v } )
	end

	if (reverse) then
		table.sort(new1, function (a,b) return ((a.val[sortfield] or '') > (b.val[sortfield] or '') ) end)
	else
		table.sort(new1, function (a,b) return ((a.val[sortfield] or '') < (b.val[sortfield] or '') ) end)
	end

	for k,v in pairs(new1) do
		table.insert(new2, v.val)
	end
	return new2
end

--[[
Sort a table of strings
As a more advanced solution, we can write an iterator that traverses a table following the order of its keys. An optional parameter f allows the specification of an alternative order. It first sorts the keys into an array, and then iterates on the array. At each step, it returns the key and value from the original table:
	t : the table
	f : a function which compares two keys, e.g.
		f = function(a,b) return a<b end

	With this function, it is easy to print those function names in alphabetical order. The loop
		for name, line in pairsByKeys(lines) do
			print(name, line)
		end
]]

local function pairsByKeys (t, f)
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
=====================================================
Multi-column table sort.

If returnNumericArray is false, returns an associated array, but there is a warning these are
unstable, whatever that really means.

If returnNumericArray is true, then returns a table with NUMERICAL indeces { 1,2,3 } instead
of the original keys because "The sort algorithm is not stable;
that is, elements considered equal by the given order may have
their relative positions changed by the sort."

So, if returnNumericArray is set, we return a table of this form:
t = { {key="key", val={whatever the value was}, .... }

The reverseSort parameter is a table that matches the sortfields, with true/false for each item,
indicating whether that item should be reverse sorted (true), e.g. lower->highest

** If NO reverseSort table is given, DEFAULT is all reverse sort, from low to high and A->Z!!!

Example:

	local t= {
		cows = { title = "cows", author="Zak", publisherid="2" },
		mice = { title = "Art", author="Bob", publisherid="2" },
		zebra = { title = "zebra", author="Gary", publisherid="3" },
	}

	t = table_multi_sort(t, {"publisherid", "title", "author" },{ true, false, false }, true  )

--]]
local function table_multi_sort(a, sortfields, reverseSort, returnNumericArray)

	if ( (not reverseSort) or #reverseSort == 0) then
		reverseSort = {}
		for i=1,#sortfields do
			reverseSort[i] = false
		end
	end

	local function cmp2 (a, b)
		for i=1,(#sortfields-1) do
			if (reverseSort[i]) then
				a,b = b,a
			end
			local colTitle = sortfields[i]
			local aa = a.val[colTitle] or ""
			local bb = b.val[colTitle] or ""
			if aa < bb then return true end
			if aa > bb then return false end
		end
		colTitle = sortfields[#sortfields]
		if (reverseSort[#sortfields]) then
			a,b = b,a
		end
		return a.val[colTitle] < b.val[colTitle]
	end


	local new1 = {}
	local new2 = {}
	for k,v in pairs(a) do
		table.insert(new1, { key=k, val=v } )
	end
	table.sort(new1, cmp2)
	if (returnNumericArray) then
		return new1
	else
		for k,v in ipairs(new1) do
			new2[v.key] = v.val
		end
		return new2
	end
end





--========================================================================
-- Order objects in a display group by the "layer" field of each object
-- We can't use "z-index" cuz the hyphen doesn't work in XML.
-- This allows for ordered layering.
local function zSort(myGroup)

	local n = myGroup.numChildren
	local kids = {}
	for i=1,n do
		kids[i] = myGroup[i]
	end

	--print ("Zsort: "..n.." children")
	table.sort(kids,
		function(a, b)
			local al = a.layer or 0
			local bl = b.layer or 0
			--print ("zSort:", al, bl, a.index, a.name)
			if (al=="top" or bl=="bottom") then return false end
			if (bl=="top" or al=="bottom") then return true end
--print ("a1, b1", al,bl)
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
local function get_date_parts(date_str)
	if (date_str) then
		_,_,y,m,d=string.find(date_str, "(%d+)-(%d+)-(%d+)")
		return tonumber(y),tonumber(m),tonumber(d)
	else
		return nil,nil,nil
	end
end


-- This converts a unix time stamp in GMT time to current local Lua time.
-- This is a string of the form, yyyy-mm-dd hh:mm:ss
local function datetime_to_unix_time(s)
	if (s) then
		local p="(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
		local year,month,day,hour,min,sec=s:match(p)
		local offset=os.time()-os.time(os.date("!*t"))
		local dateTable = {day=day,month=month,year=year,hour=hour,min=min,sec=sec}
		local t = os.time{day=day,month=month,year=year,hour=hour,min=min,sec=sec}
		return (t+offset)
	else
		return 0
	end
end

--====================================================
local function getmonth(month)
	local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
	return months[tonumber(month)]
end

--====================================================
local function getday_posfix(day)
local idd = math.mod(day,10)
	   return	(idd==1 and day~=11 and "st")  or (idd==2 and day~=12 and "nd") or (idd==3 and day~=13 and "rd") or "th"
end


--========================================================================
-- Format a STRING date, e.g. 2005-10-4 in ISO format, into a human format.
-- Default for stripZeros is TRUE.
local function formatDate(s, f, stripZeros)
	if (stripZeros == nil) then stripZeros = true end
	if (s ~= "") then
		f = f or "%x"
		local y,m,d = get_date_parts(s)
		if (y and m and d) then
			local t = os.time({year=y,month=m,day=d})
			s = os.date(f, t)
			if (stripZeros) then
				s = s:gsub("/0", "/")
				s = s:gsub("%.0", ".")
				s = s:gsub("%, 0", ", ")
				s = s:gsub("^0", "")
			end
		else
			--print ("Warning: funx.formatDate: the dates provided for formatting are not in xx-xx-xx format: ", s)
		end
		return s
	else
		return ""
	end
end


-------------------------------------------------
-- Shrink the obj away until it is small, then disappear it.
-- Restore its size when done, but leave it hidden
-- Default is shrink to center, but can set destX, destY
local function shrinkAway (obj, callback, transitionSpeed, destX, destY)

	destX = destX or midscreenX
	destY = destY or midscreenY

	local xs = obj.yScale
	local ys = obj.xScale
	local w = obj.width
	local h = obj.height
	local a = obj.alpha

		local function cb()
			obj.xScale = xs
			obj.yScale = ys
			obj.width = w
			obj.height = h
			obj.alpha = a
			obj.isVisible = false
			callback()
		end

	callback = callback or nil
	local t = transitionSpeed or (fadePageTime or 500)
	obj:setReferencePoint(display.CenterReferencePoint)
	transition.to( obj,  { time=t, xScale=0.01, yScale=0.01, alpha=0, x=destX, y=destY, onComplete=cb } )
end



-------------------------------------------------
local function fadeOut (obj, callback, transitionSpeed)
	--print ("fadeOut: time="..fadePageTime)
	callback = callback or nil
	if (type(callback) ~= "function") then callback = nil end

	local function myCallback()
		obj._isTweening = false
		if (callback) then callback() end
	end

	local t = transitionSpeed or (fadePageTime or 500)
	transition.to( obj,  { time=t, alpha=0, onComplete=myCallback } )
	obj._isTweening = true
end

-------------------------------------------------
local function fadeIn (obj, callback, transitionSpeed)
	--print ("fadeIn: time="..fadePageTime)
	callback = callback or nil
	if (type(callback) ~= "function") then callback = nil end

	local function myCallback()
		obj._isTweening = false
		if (callback) then callback() end
	end

	if (not obj.isVisible) then
		obj.alpha = 0
		obj.isVisible = true
	end

	local t = transitionSpeed or (fadePageTime or 500)
	transition.to( obj,  { time=t, alpha=1, onComplete=myCallback} )
	obj._isTweening = true

end


------------------------------------------------------------------------
-- Show a message, then fade away
------------------------------------------------------------------------
local function tellUser(message, x,y)

	if (not message) then
		return true
	end


	local screenW, screenH = display.contentWidth, display.contentHeight
	local viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
	local screenOffsetW, screenOffsetH = display.contentWidth -	 display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
	local midscreenX = screenW*(0.5)
	local midscreenY = screenH*(0.5)

	local TimeToShowMessage = 2000
	local FadeMessageTime = 500

	-- message object
	local msg = display.newGroup()

	local x = x or 0
	local y = y or 0

	local w = screenW - 40
	local h = 0	-- height matches text

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
		transition.to( msg,	 { time=FadeMessageTime, alpha=0, onComplete=closeMessage} )
		timedMessage = nil
		timedMessageList[1] = nil
		-- remove first element
		table.remove(timedMessageList, 1)
		--print ("Messages:", #timedMessageList)
	end

	------------------------------------------------------------------------

	-- Create empty text box, using default bold font of device (Helvetica on iPhone)
	-- Screen Width version:
	local textObject = display.newText( message, 0, 0, w/3,h, native.systemFontBold, 24 )

	-- Fitted width version, does NOT wrap text!
	--local textObject = display.newText( message, 0, 0, native.systemFontBold, 24 )
	textObject:setFillColor( 255,255,255 )

	w = textObject.width

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
	transition.to( msg,	 { time=FadeMessageTime, alpha=1} )
	timedMessage = timer.performWithDelay( TimeToShowMessage, fadeAwayThenClose )
	timedMessageList[#timedMessageList + 1] = timedMessage

end





-------------------------------------------------
-- loadingSpinner
-- Show a loading spinner graphic
-- Params is a table:
-- handle = a timer reference. If set, then this MUST be a command to cancel the timer and spinner.
-- delay = time to wait before showing message. If our loading happens fast enough, we don't need
-- the message to show.
-- Examples of the table:
-- { handle = mytimerhandle }
-- { message="message", delay=1000 }
--[[
	local p = { message="Loading", delay=1000}
	local myTimerHandle = spinner(p)
	...
	local p = { handle = myTimerHandle }
	spinner(p)
--]]
-------------------------------------------------
local function spinner(p)
	p = p or {}

	local delay = p.delay or 500
	local message = p.message or "Loading..."

	local r = display.newGroup()

	local function showMessage(event)
		--local message = event.source.params.message
		print ("Message",message)
		if (message) then
			tellUser(message)
		end
		native.setActivityIndicator( true );

	end


	local function showSpinner()
		print ("SHOW SPINNER")
		Runtime:removeEventListener( "enterFrame", showSpinner )
		r.isVisible = true
	end

	local function hideSpinner()
		print ("HIDE SPINNER")
		Runtime:removeEventListener( "enterFrame", hideSpinner )
		--r.isVisible = false
	end


	if (not p.handler) then
		--print ("start timer")
		print ("spinner started at",os.time(),"seconds")
		local t = timer.performWithDelay( 300, function() print ("Timer!");showMessage(message); end )
		t.starttime = os.time()

		rr = display.newRect(0,0,100,100)
		rr.x = midscreenX
		rr.y = midscreenY
		rr:setFillColor (255,0,0)
		r:insert(rr)

		t.recto = r

		Runtime:addEventListener( "enterFrame", showSpinner );

		return t
	else
		--print ("Spinner canceled!")
		print ("spinner cancelled at",os.time(),"seconds after ",os.time()-p.handler.starttime,"seconds.")

		p.handler.recto:removeSelf()
		p.handler.recto = nil

		Runtime:addEventListener( "enterFrame", hideSpinner );

		timer.cancel(p.handler)

		native.setActivityIndicator( false );

	end
end

local rr = display.newGroup()
local function showSpinner()
		rr = display.newRect(0,0,100,100)
		rr.x = midscreenX
		rr.y = midscreenY
		rr:setFillColor (255,0,0)
end

local function hideSpinner()
		rr:removeSelf()
		oogabooga.r = nil
end


local function activityIndicator( mode )
	if mode then
		native.setActivityIndicator( true )
	else
		native.setActivityIndicator( false )
	end
end

local function activityIndicatorOn( mode )
	timer.performWithDelay(1, function() native.setActivityIndicator( true ) end )
end

local function activityIndicatorOff( mode )
	timer.performWithDelay(1, function() native.setActivityIndicator( false ) end )
end


------------------------------------------------------------------------
-- CLEAN GROUP
------------------------------------------------------------------------

local function cleanGroups ( curGroup, level )
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

local function callClean ( moduleName )
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

local function unloadModule ( moduleName )
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







--[[
local function spinner()
	local isAndroid = "Android" == system.getInfo("platformName")

	if(isAndroid) then
		 local alert = native.showAlert( "Information", "Activity indicator API not yet available on Android devices.", { "OK"})
	end
	--

	local label = display.newText( "Activity indicator will disappear in:", 0, 0, system.systemFont, 16 )
	label.x = display.contentWidth * 0.5
	label.y = display.contentHeight * 0.3
	label:setFillColor( 10, 10, 255 )

	local numSeconds = 5
	local counterSize = 36
	local counter = display.newText( tostring( numSeconds ), 0, 0, system.systemFontBold, counterSize )
	counter.x = label.x
	counter.y = label.y + counterSize
	counter:setFillColor( 10, 10, 255 )

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
]]





-------------------------------------------------
-- Toggle an object, transitioning between a given alpha, and zero.
local function toggleObject(obj, fxTime, opacity, onComplete)
	fxTime = tonumber(fxTime)
	opacity = applyPercent(opacity,1)
	--print ()
	--print ()
	--print ("------------- ToggleObject Begin (opacity: "..opacity)

	-- Actual alpha of a display object is not exact
	local currentAlpha = math.ceil(obj.alpha * 100)/100

	-- be sure these properties exist
	obj.tween = obj.tween or {}
	if (obj._isTweening == nil) then
		obj._isTweening = false
	end

		local function transitionComplete(obj)
			local currentAlpha = math.ceil(obj.alpha * 100)/100
			if (currentAlpha == 0) then
				obj.isVisible = false
			else
				obj.isVisible = true
			end
			obj._isTweening = false
			obj.tweenDirection = nil

			if (onComplete) then
				onComplete()
			end
		end

	-- Cancel transition if caught in the middle
	if (obj.tween and obj._isTweening) then
		transition.cancel(obj.tween)
		obj._isTweening = false
		obj.tween = nil
		--print ("toggleObject: CANCELLED TRANSITION")
	end

	if (obj.alpha == 0 or (obj.alpha > 0 and obj.tweenDirection == "going") ) then
		-- Fade in
		--print ("toggleObject: fade In")
		obj.isVisible = true
		obj.tween = transition.to( obj,	 { time=fxTime, alpha=opacity, onComplete=transitionComplete } )
		if (obj.tweenDirection) then
			--print ("Fade in because we were : "..obj.tweenDirection)
		end
		obj.tweenDirection = "coming"
	else
		-- Fade out
		obj.tween = transition.to( obj,	 { time=fxTime, alpha=0, onComplete=transitionComplete } )
		--print ("toggleObject: fade Out")
		if (obj.tweenDirection) then
			--print ("Fade out because we are : "..obj.tweenDirection)
		end
		obj.tweenDirection = "going"
	end
	--print ("obj alpha = "..obj.alpha)
	--print ("obj.tweenDirection: "..obj.tweenDirection)
	obj._isTweening = true
	--print "------------- END"
end


-------------------------------------------------
-- Hide an object, transitioning between a given alpha, and zero.
local function hideObject(obj, fxTime, opacity, onComplete)
	fxTime = tonumber(fxTime)
	opacity = tonumber(opacity)

	if (not obj or type(obj) ~= "table") then
		print ("ERROR! : funx.hideObject : the object is missing, perhaps display object was removed but table not nil'ed?")
		return false
	end

	if (not obj.alpha) then
		obj.alpha = 0
	end

	-- Actual alpha of a display object is not exact
	local currentAlpha = math.ceil(obj.alpha * 100)/100

	-- be sure these properties exist
	obj.tween = obj.tween or {}
	if (obj._isTweening == nil) then
		obj._isTweening = false
	end

		local function transitionComplete(obj)
			if (not obj) then
				print ("funx.hideObject:transitionComplete: WARNING: object is gone!")
				return false
			end
			local currentAlpha = math.ceil(obj.alpha * 100)/100
			if (currentAlpha == 0) then
				obj.isVisible = false
			else
				obj.isVisible = true
			end
			obj._isTweening = false
			obj.tweenDirection = nil

			if (onComplete) then
				onComplete()
			end
		end

	-- Cancel transition if caught in the middle
	if (obj.tween and obj._isTweening) then
		transition.cancel(obj.tween)
		obj._isTweening = false
		obj.tween = nil
		--print ("toggleObject: CANCELLED TRANSITION")
	end

		-- Fade out
		obj.tween = transition.to( obj,	 { time=fxTime, alpha=0, onComplete=transitionComplete } )
		--print ("toggleObject: fade Out")
		if (obj.tweenDirection) then
			--print ("Fade out because we are : "..obj.tweenDirection)
		end
		obj.tweenDirection = "going"

	obj._isTweening = true

end


-- returns true/false depending whether value is a percent
local function isPercent (x)
	v,s = string.match(x, "(%d+)(%%)$")
	if (s == "%") then
		return true
	else
		return false
	end
end


-- Return x%, e.g. 10% returns .10
local function percent (x)
	v = string.match(x, "(%d+)%%$")
	if v then
		v = v / 100
	end
	return v
end

local function applyPercentIfSet(x,y,noRound)
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
local function ratioToFitMargins (w,h, t,b,l,r, x,y)
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
local function scaleObjectToMargins (obj, t,b,l,r, xMax,yMax, reduceOnly)
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
-- EXAMPLE:
--   w,h = maxWidth, maxHeight
--   pic = loadImageFile(filename)
--   pic.width, pic.height = funx.getFinalSizes (w,h, pic.width, pic.height, true)

local function getFinalSizes (w,h, originalW, originalH, p)
	local wPercent, hPercent
	if p == nil then p = true end
	w = tonumber(w)
	h = tonumber(h)
	originalW = tonumber(originalW)
	originalH = tonumber(originalH)

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
			local doScaleW = (originalH/h) <= (originalW/w)
			if (doScaleW) then
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
local function ScaleObjToSize (obj, w,h)
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




local function AddCommas( number, maxPos )

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

local function lines(str)
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end

local function loadFile(filename)
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
local function buildTextDisplayObjectsFromTemplate (template, obj)
	-- split the template
	local objs = {}
	for i,line in pairs(lines(trim(template))) do
		--print ("Line : "..line)
		local params = split (line, ",")
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
		o:setFillColor(0, 0, 0)
		-- Set the coordinates
		o.x = params[2]
		o.y = params[3]
		-- opacity
		o.alpha = 1.0
		objs[name] = o
		--print ("Params for "..name..":")
		dump(params)

	end
	return objs
end




--------------------------------------------------------
--

local function stripCommandLinesFromText(text)
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



-- Text styles used by autoWrappedText
--local textStyles = {}

--------------------------------------------------------
-- Styles for autoWrappedText, below.
-- Styles are simply the formatting lines, ### set, ....
-- We pass a table of styles:
-- styles = { stylename = stylestring, ... }
local function loadTextStyles(filename, path)
	if (filename) then
		path = path or system.DocumentsDirectory
		local filePath = system.pathForFile( filename, path )
		if (not filePath) then
			print ("WARNING: missing file ",filename)
			return {}
		end
		local textStyles = loadTableFromFile(filePath, "\n")
		-- split sub-arrays (rows) into tables
		local t = {}
		if (textStyles) then
			for n,v in pairs(textStyles) do
				if (type(v) ~= "table") then
					v = "set,"..v
					-- Record both Mixed Case and lowercase versions of the key
					-- to be sure we can find it.
					t[string.lower(n)] = split(v, ",", true)
					t[n] = split(v, ",", true)
				end
			end
		else
			t = {}
		end
		return t
	else
		return {}
	end
end

--[[
local function getTextStyles ()
	return textStyles or {}
end
]]
--[[
local function setTextStyles (t)
	textStyles = t or {}
	for n,v in pairs(textStyles) do
		if (type(v) ~= "table") then
			v = "set,"..v
			textStyles[n] = split(v, ",", true)
		end
	end
end
]]


-- Get an adjustment for a font, to position it closer to its real baseline
-- Assume x-height is about 60% of the font height.
local function getXHeightAdjustment (font,size)
	local c = "X"
	local t = display.newText(c,0,0,font,size)
	local h = t.height

	display.remove(t)
	t=nil

	local adj = h * 0.6

	--print ("getXHeightAdjustment of '"..c.."'	 "..font.." at size "..size.." is "..xHeight..", ratio", r)
	return adj
end


-- Testing function to show a line and insert into group g
local function showTestBox (g,x,y,len, font,size,lineHeight,fontMetrics)

	local fontInfo = fontMetrics.getMetrics(font)
	local baseline = fontInfo.baseline

	local yAdjustment = lineHeight -- + (-baseline * size)
	len = len or 100
	local b = display.newRect(g, x, y, x+len, y+yAdjustment)
	b:setReferencePoint(display.TopLeftReferencePoint)
	b.x = x
	b.y = y
	b:setFillColor(0,0,250, 0.3)
	print ("showTestLine: lineheight:",lineHeight)
end


-- Testing function to show a line and insert into group g
local function showTestLine (g,x,y,t,leading)
	y = math.floor(y)
	leading = leading or 0
	len = len or 100
	local b = display.newLine(g, x, y, x+len, y)
	b:setStrokeColor(0,0,100,0.9)
	local t = display.newText(g, "y="..y..":"..", "..leading..": "..t,x,y,"Georgia-Italic",9)
	t:setFillColor(0,0,0)
end


--------------------------------------------------------
-- Wrap text to a width
-- Blank lines are ignored.
--
-- Very important:
-- text: a table of named parameters OR the text.
--
-- *** To show a blank line, put a space on it.
-- The minCharCount is the number of chars to assume are in the line, which means
-- fewer calculations to figure out first line's.
-- It starts at 25, about 5 words or so, which is probabaly fine in 99% of the cases.
-- You can raise lower this for very narrow columns.
-- opacity : 0.0-1.0
-- "minWordLen" is the shortest word a line can end with, usually 2, i.e, don't end with single letter words.
-- NOTE: the "floor" is crucial in the y-position of the lines. If they are not integer values, the text blurs!
--
-- Look for CR codes. Since clumsy XML, such as that from inDesign, cannot include line breaks,
-- we have to allow for a special code for line breaks: [[[cr]]]
--------------------------------------------------------

local function autoWrappedText (text, font, size, lineHeight, color, width, textAlignment, opacity, minCharCount, targetDeviceScreenSize, letterspacing, maxHeight, minWordLen, textstyles, defaultStyle, cacheDir)

	local textwrap = require ("textwrap")

	return textwrap.autoWrappedText(text, font, size, lineHeight, color, width, textAlignment, opacity, minCharCount, targetDeviceScreenSize, letterspacing, maxHeight, minWordLen, textstyles, defaultStyle, cacheDir)

end




local function capitalize(str)
	local function tchelper(first, rest)
	  return first:upper()..rest:lower()
	end
	-- Add extra characters to the pattern if you need to. _ and ' are
	--	found in the middle of identifiers and English words.
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

local function adjustXYforShadow (x, y, rp, shadowOffset, scale)
	local stringFind = string.find

	if (shadowOffset) then
		local shadowOffsetX = 0
		local shadowOffsetY = 0
		local offsetX, offsetY

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
		x = x or 0
		y = y or 0
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

local function referenceAdjustedXY (obj, x, y, newReferencePoint, scale, shadowOffset)
	local stringFind = string.find

	rx = obj.xReference
	ry = obj.yReference

	if (obj and newReferencePoint) then
		scale = scale or 1
		local w = obj.width
		local h = obj.height

--print ("a) referenceAdjustedXY adjustedment:	x, y, newReferencePoint, scale, shadowOffset",	x, y, newReferencePoint, scale, shadowOffset)

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

		if (x == "center") then
			x = midscreenX
		elseif (x == "left") then
			x = 0
		elseif (x == "right") then
			x = screenW
		end

		if (y == "center") then
			y = midscreenY
		elseif (y == "top") then
			y = 0
		elseif (y == "bottom") then
			y = screenH
		end


		x = math.floor( x + (offsetX * scale))
		y = math.floor( y + (offsetY * scale))

--print ("b) referenceAdjustedXY adjustedment:", x, y, scale, shadowOffset)
	end
	return x,y
end


local function fixCapsForReferencePoint(r)
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
-- *** This is based on 0,0 being the center of the space defined by w x h ***
-- Default w,h is the screen.

local function positionObject(x,y,w,h,margins)
	w = w or screenW
	h = h or screenH

	--x = funx.applyPercent(x,w) or 0
	--y = funx.applyPercent(y,h) or 0

	margins = margins or {top=0, bottom=0,left=0,right=0}

	-- Horizontal offsets
	if (x == "left") then
		xpos = w/-2 + margins.left
	elseif (x == "right") then
		xpos = (w/2) - margins.right
	elseif (x == "center") then
		xpos = 0
	else
		xpos = applyPercent(x,w) or 0
	end

	-- Vertical offsets
	if (y == "top") then
		ypos = h/-2 + margins.top
	elseif (y == "bottom") then
		ypos = (h/2) - margins.bottom
	elseif (y == "center") then
		ypos = 0
	else
		ypos = applyPercent(y,h) or 0
	end

	return xpos, ypos
end

--=====
--- Make a margins table from a string, order is T/L/B/R, e.g. "10,20,40,20"
local function stringToMarginsTable(str, default)
	local m
	default = default or {0,0,0,0}

	if (type(default) == "string") then
		m = split ( (str or default), ",")
	elseif (not str or str == "") then
		m = split ( default, ",")
	else
		m = split ( str, ",")
	end

	local margins = {
		top=applyPercent(m[1], screenH),
		left=applyPercent(m[2], screenW),
		bottom=applyPercent(m[3], screenH),
		right=applyPercent(m[4], screenW),
	}
	return margins
end


---------------
-- positionObjectAroundCenter
-- Given user settings for x,y, return the real x,y in the space of width x height
-- margins = {top,bottom,left,right} margins/padding
-- x can be left, center, right, a number, or a percent
-- y can be top, center, bottom, a number, or a percent
-- ref is the reference point, used like this: display[ref]
-- Example: x,y = positionObject("left", "center", screenW, screenH)
-- *** This is based on 0,0 being the center of the space defined by w x h ***
-- Default w,h is the screen.

local function positionObjectAroundCenter(x,y,w,h,margins)
	w = w or screenW
	h = h or screenH

	--x = applyPercent(x,w) or 0
	--y = applyPercent(y,h) or 0

	margins = margins or {top=0, bottom=0,left=0,right=0}

	-- Horizontal offsets
	if (x == "left") then
		xpos = w/-2 + margins.left
	elseif (x == "right") then
		xpos = (w/2) - margins.right
	elseif (x == "center") then
		xpos = 0
	else
		xpos = applyPercent(x,w) or 0
	end

	-- Vertical offsets
	if (y == "top") then
		ypos = h/-2 + margins.top
	elseif (y == "bottom") then
		ypos = (h/2) - margins.bottom
	elseif (y == "center") then
		ypos = 0
	else
		ypos = applyPercent(y,h) or 0
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

local function positionObjectWithReferencePoint(x,y,w,h,margins, absoluteflag, refPointSimpleText)
	local xpos, ypos
	w = w or screenW
	h = h or screenH
	absoluteflag = absoluteflag or false

	if (not margins or absoluteflag) then
		margins = {left = 0, right=0, top=0, bottom=0 }
	end

	local xref = "Left"
	local yref = "Top"

	if (type(x) == "string") then
		x = string.lower(x)
	end
	if (type(y) == "string") then
		y = string.lower(y)
	end

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
		x = applyPercent(x,w) or 0
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
		y = applyPercent(y,h) or 0
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





local function setAnchorFromReferencePoint(obj, pos)
	pos = string.lower(pos)
	
	if 	   pos == "topleftreferencepoint"      then obj.anchorX, obj.anchorY = 0, 0
	elseif pos == "topcenterreferencepoint"    then obj.anchorX, obj.anchorY = 0.5, 0
	elseif pos == "toprightreferencepoint"     then obj.anchorX, obj.anchorY = 1, 0
	elseif pos == "centerleftreferencepoint"   then obj.anchorX, obj.anchorY = 0, 0.5
	elseif pos == "centerreferencepoint"       then obj.anchorX, obj.anchorY = 0.5, 0.5
	elseif pos == "centerrightreferencepoint"  then obj.anchorX, obj.anchorY = 1, 0.5
	elseif pos == "bottomleftreferencepoint"   then obj.anchorX, obj.anchorY = 0, 1
	elseif pos == "bottomcenterreferencepoint"  then obj.anchorX, obj.anchorY = 0.5, 1
	elseif pos == "bottomrightreferencepoint"  then obj.anchorX, obj.anchorY = 1, 1
	else obj.anchorX, obj.anchorY = 0.5, 0.5
	end
end


local function convertAnchorToReferencePointName (obj)
	local post = ""
	if ( {obj.anchorX, obj.anchorY} == {0, 0} ) then post = "TopLeftReferencePoint"
	elseif ( {obj.anchorX, obj.anchorY} == {0.5, 0} ) then post = "TopCenterReferencePoint"
	elseif ( {obj.anchorX, obj.anchorY} == {1, 0} ) then post = "TopRightReferencePoint"
	elseif ( {obj.anchorX, obj.anchorY} == {0, 0.5} ) then post = "CenterLeftReferencePoint"
	elseif ( {obj.anchorX, obj.anchorY} == {0.5, 0.5} ) then post = "CenterReferencePoint"
	elseif ( {obj.anchorX, obj.anchorY} == {1, 0.5} ) then post = "CenterRightReferencePoint"
	elseif ( {obj.anchorX, obj.anchorY} == {0.5, 1} ) then post = "BottomCenterReferencePoint"
	elseif ( {obj.anchorX, obj.anchorY} == {1, 1} ) then post = "BottomRightReferencePoint"
	end
	return post
end


-- Keep an object in the same place on screen while changing its anchor point.
-- This is useful if an object is positioned Top Left (0,0), then we want to change the
-- anchor point but not change the objects position on screen.
-- *** This depends on 
local function reanchorToCenter (obj, a, x, y)
	
	if not a then return x,y; end
	
	if (string.lower(a) == "centerreferencepoint") then
		return x,y
	end
		
	-- old anchor values, and x,y
	local oaX, oaY = obj.anchorX, obj.anchorY
--	x = x or obj.x
--	y = y or obj.y

	
	-- a is a table, then it is an anchor point, else it is the name of a reference point
--	if (type(a) == "table") then
--		obj.anchorX, obj.anchorY = a.x, a.y
--	else
--		setAnchorFromReferencePoint(obj, a)
--	end
	
	-- new anchor values
	local naX, naY = 0.5, 0.5
--
--	-- Get width/height
	local ac = obj.anchorChildren
	obj.anchorChildren = true
	local width, height = obj.width, obj.height
	obj.anchorChildren = ac
	
	-- distance from top-left
	local deltaX = (naX * width) - (oaX * width)
	local deltaY = (naY * height) - (oaY * height)
	
	local x = x + deltaX
	local y = y + deltaY
	
	return x,y
	
end

----------------------------------------------------------------------
-- Picture Corners
-- Given a width/height, build picture corners to fit.
-- filenames are of each corner
-- offsets specify positioning correction
local function buildPictureCorners (w,h, filenames, offsets)
	local g = display.newGroup()
	local imageTL = display.newImage(g, filenames.TL)
	local imageTR = display.newImage(g, filenames.TR)
	local imageBL = display.newImage(g, filenames.BL)
	local imageBR = display.newImage(g, filenames.BR)

	imageTL:setReferencePoint(display.TopLeftReferencePoint)
	imageTL.x = 0 + offsets.TLx; imageTL.y = 0 + offsets.TLy;

	imageTR:setReferencePoint(display.TopRightReferencePoint)
	imageTR.x = w + offsets.TRx; imageTR.y = 0 + offsets.TRy;

	imageBL:setReferencePoint(display.BottomLeftReferencePoint)
	imageBL.x = 0 + offsets.BLx; imageBL.y = h + offsets.BLy;

	imageBR:setReferencePoint(display.BottomRightReferencePoint)
	imageBR.x = w + offsets.BRx; imageBR.y = h + offsets.BRy;

	return g
end






----------------------------------------------------------------------
----------------------------------------------------------------------
-- TESTING TOOLS:
-- Print local vs. stage coordinates by touching an object.
local function showContentToLocal(obj, state)
	function showCoordinates( event )
	--		Get x, y of touch event in content coordinates
			local contentx, contenty = event.x, event.y
	--		Convert to local coordinates of
			local localx, localy = event.target:contentToLocal(contentx, contenty)
	--		Display content and local coordinate values
			print ("showContentToLocal (content=>local): ", contentx..", "..contenty, "=>", floor(localx) ..", ".. floor(localy), ":", obj.localX )
		return true
	end

	if (state == "toggle") then
		state = not obj._showContentToLocal
	end

	if (state) then
		print ("showContentToLocal: on")
		obj:addEventListener("touch", showCoordinates)
		obj._showContentToLocal = true
	else
		print ("showContentToLocal: off")
		obj:removeEventListener("touch", showCoordinates)
		obj._showContentToLocal = false
	end
end


------------------------------------------------------------
------------------------------------------------------------
-- Alert the user that something significant has happened by flashing the screen to white.
local function flashscreen(t,a)

	t = t or 100
	a = a or 0.5
	local r = display.newRect(0,0,screenW,screenH)
	anchorTopLeftZero(r)
	r.alpha = 0

		local function removeFlasher()
			r:removeSelf()
			r = nil
		end

		local function fadeOutAgain()
			transition.to(r, { alpha = 0, time=t, onComplete=removeFlasher } )
		end

	-- Fade In the white screen
	transition.to(r, { alpha = a, time=t, onComplete = fadeOutAgain } )

end

------------------------------------------------------------
------------------------------------------------------------
-- Use the file suffix to determine a file type,
-- e.g. xxx.m4a is sound, m4v is video, jpg is image
-- We only handle really common formats that iOS likes, so
-- don't expect to handle everything. And, mp4 could be either,
-- so I'm using audio for it.
-- Return FALSE if the type is unknown
-- NOTE: we're checking for 3 letter suffixes, so .html will mess up...use ".htm"
local function mediaFileType(f)
	local suffix = string.sub(f, string.len(f)-3, -1)
	local t = {
		jpg="image",
		png="image",

		mov="video",
		m4v="video",

		m4a="audio",
		mp4="audio",
		mp3="audio",
		aac="audio",
		wav="audio",

		txt="text",
		htm="html",


	}


	if (suffix) then
		return t[suffix]
	else
		return false
	end
end




-----------
-- Make a directory to hold something new
-- Use a handy prefix for future selecting of the type of dir,
-- e.g. all "o_..." dirs
-- dirname: path INSIDE the system.DocumentsDirecotyr (or systemdir)
-- unique: if the directory exists, make a unique version
-- systemdir: Default to the system.DocumentsDirectory
local function mkdir (dirname, prefix, unique, systemdir)

	local systemdir = systemdir or system.DocumentsDirectory

	if (prefix == nil) then
		prefix = "o_"
	end

	-- Use a unique-ish file name if necessary
	mydirname = dirname or os.time() .. "_" ..os.clock()

	local temp_path = system.pathForFile( mydirname, systemdir )
	if (unique) then
		-- Does the path already exist? If so, modify to be sure it is unique
		while ( lfs.chdir( temp_path ) ) do
			mydirname = dirname .. "_" .. os.time() .. "_" ..os.clock()
			temp_path = system.pathForFile( mydirname, systemdir )
		end
	elseif (lfs.chdir( temp_path )) then
		-- we're done, return the name of the directory
		return mydirname
	end

	-- Change to documents directory
	--local temp_path = system.pathForFile( "", system.TemporaryDirectory )
	local temp_path = system.pathForFile( "", systemdir )

	-- change current working directory
	local success = lfs.chdir( temp_path ) -- returns true on success
	local new_folder_path

	if success then
		lfs.mkdir( mydirname )
		new_folder_path = lfs.currentdir() .. "/"..mydirname
		return mydirname
	else
		return false
	end
end



------------------------------------------------------------
------------------------------------------------------------
-- Make cover up bars for differenly shaped screens
-- Color is a color string "R,G,B"
local function coverUpScreenEdges(color)

	color = color or "0,0,0"
--color = "200,30,30"
	local c = stringToColorTable(color)

	-- Put cover-up bars for a different screen shape.
	local deviceWidth = round(( display.contentWidth - (display.screenOriginX * 2) ) / display.contentScaleX)
	local deviceHeight = round(( display.contentHeight - (display.screenOriginY * 2) ) / display.contentScaleY)

	local actualWidth = deviceWidth * display.contentScaleX
	local actualHeight = deviceHeight * display.contentScaleY

	-- Don't make bars if no need for them
	if (screenW == actualWidth and screenH == actualHeight) then
		return false
	end

	local coverup = display.newGroup()

	local barWidth = (actualWidth - screenW)/2
	local barL = display.newRect(coverup, 0,0,barWidth,screenH)
	local barR = display.newRect(coverup, 0,0,barWidth,screenH)
	barL:setFillColor(c[1],c[2], c[3])
	barR:setFillColor(c[1],c[2], c[3])
	barL:setReferencePoint(display.TopLeftReferencePoint)
	barR:setReferencePoint(display.TopLeftReferencePoint)
	barL.x = -barWidth
	barL.y = 0
	barR.x = screenW
	barR.y = 0

	--[[
	local o = system.orientation
	if ( o == "portrait" or o == "portraitUpsideDown" ) then
		coverup.rotation = 90
	end
	--]]


	return coverup
end



-------------------------------------------------
-------------------------------------------------
-- Special Strokes around objects
-- params may include:
-- stroke width (stroke)
-- params MUST tell us what kind of object, e.g. "rectangle", etc.
-- Styles:
-- solid : a normal stroke
-- thin-thick : 25% inner stroke, 50% out, with 25% padding
local function strokeRectObject(o,params)
	local floor = math.floor

			local function framingObject(o,padding,fillcolor,strokeWidth,strokeColor)
				local dup = display.newRect(0,0,o.contentWidth+(2*padding), o.contentHeight+(2*padding))
				dup:setFillColor(fillcolor[1], fillcolor[2], fillcolor[3], fillcolor[4])
				dup.strokeWidth = strokeWidth
				dup:setStrokeColor(strokeColor[1], strokeColor[2], strokeColor[3], strokeColor[4])
				return dup
			end

	-- Default is transparent fill for stroking boxes
	local fillcolor = stringToColorTable(params.fillColor or "0,0,0,0")
	local color = stringToColorTable(params.color or "0,0,0")

	if (params.style == "Solid") then
		o.strokeWidth = params.stroke or 0
		o:setStrokeColor(color[1], color[2], color[3], color[4])
		return o
	elseif (params.style == "Thick - Thin") then
		local sw = params.stroke or 0
		local innerW = floor(sw * 0.25) or 1
		local outerW = floor(sw * 0.5) or 1
		local padding = (sw-(innerW + outerW)) or 1

		o.strokeWidth = innerW
		o:setStrokeColor(color[1], color[2], color[3], color[4])

		local outerObj = framingObject(o,padding, fillcolor, outerW,color)

		local g = display.newGroup()
		g:insert(outerObj)
		g:insert(o);
		outerObj.x = 0
		outerObj.y = 0
		o.x = 0
		o.y = 0
		return g
	elseif (params.style == "Thin - Thick") then
		local sw = params.stroke or 0
		local innerW = floor(sw * 0.5) or 1
		local outerW = floor(sw * 0.25) or 1
		local padding = (sw-(innerW + outerW)) or 1
--print (params.stroke, innerW,outerW,padding)

		o.strokeWidth = innerW
		o:setStrokeColor(color[1], color[2], color[3], color[4])

		local outerObj = framingObject(o,padding, fillcolor, outerW, color)

		local g = display.newGroup()
		g:insert(outerObj)
		g:insert(o);
		outerObj.x = 0
		outerObj.y = 0
		o.x = 0
		o.y = 0
		return g
	else
		-- return original item
		return o
	end

end



-------------------------------------------------
-- Convert "left", "center", "right" to numerics or percentages
local function positionByName(t, margins, absoluteflag)

	if (not margins or absoluteflag) then
		margins = {left = 0, right=0, top=0, bottom=0 }
	end

	local v = ""

	if (t == "left" ) then
		v = margins.left
	elseif (t == "top") then
		v = margins.top
	elseif (t == "center") then
		v = "50%"
	elseif (t == "bottom") then
		v = margins.bottom
	elseif (t == "right") then
		v = margins.right
	else
		v = t
	end

	return v
end



-------------------------------------------------
-- cleanPath: clean up a path
local function cleanPath (p)
	if (p) then
		local substring = string.sub
		p = p:gsub("/\./","/")
		p = p:gsub("//","/")
		p = p:gsub("/\.$","")
		return p
	end
end

-------------------------------------------------
-- joinAsPath: make a path from different elements of a table.
-- Useful to join pieces together, e.g. server + path + filename
-- If username/password are passed, add them to the URL, e.g. username:password@restofurl
local function joinAsPath( pieces, username, password)
	trim(pieces)
	for i = #pieces, 1, -1 do
		if (pieces[i] == nil or pieces[i] == "") then 
			table.remove(pieces, i)
		end
	end

	local path = cleanPath(table.concat(pieces, "/"))
	local pre = table.concat({username,password},":")
	if (pre ~= "") then
		path = pre .. "@" .. path
	end

	return path
end



-------------------------------------------------
-- Pure Lua version of dirname.
--
local function dirname(path)
	while true do
		if path == "" or
		   string.sub(path, -1) == "/" or
--		   string.find(path, "^/\..") or
--		   string.sub(path, -2) == "/." or
		   string.sub(path, -3) == "/.." or
		   (string.sub(path, -1) == "." and
			string.len(path) == 1) or
		   (string.sub(path, -2) == ".." and
			string.len(path) == 2) then
			break
		end
		path = string.sub(path, 1, -2)
	end
	if path == "" then
		path = "."
	end
	if string.sub(path, -1) ~= "/" then
		path = path .. "/"
	end

	return path
end


-------------------------------------------------
-- basename()
-- Returns trailing name component of path
-- Extract my/dir/bottomdir => bottomdir
local function basename (path)
	path = string.gsub(path, "%/$", "")
	path = "/"..path
	local d = string.gsub(path, "^.*/","")
	return d
end

-------------------------------------------------
-- Copy File (binary copy)
-- This is a binary file copy
local function copyFile (src, srcPath, srcBaseDir, target, targetBaseDir)

	local size = 2^13

	local sourcePath = system.pathForFile( nil, srcBaseDir ) .. "/"..srcPath.."/"..src
	local targetPath = system.pathForFile( nil, targetBaseDir ) .. "/"..target.."/"..src

	local f = assert(io.open(sourcePath, "rb"))
	local out = assert(io.open(targetPath, "wb"))

	while true do
		local block = f:read(size)
		if not block then break end
		out:write(block)
	end

	assert(f:close())
	assert(out:close())
end

-------------------------------------------------
-- Copy a directory
-- Create a copy of the directory 'src' inside of the directory 'target'
local function copyDir (src, srcBaseDir, target, targetBaseDir, newname)


	srcBaseDir = srcBaseDir or system.CachesDirectory
	targetBaseDir = targetBaseDir or system.CachesDirectory

	local srcBaseName = basename(src.."/")

	newname = newname or srcBaseName

	-- make a dir inside the target container directory,
	-- e.g. make "mydir" inside "mytarget" to get "mytarget/mydir"

	local sbase = system.pathForFile( nil, srcBaseDir )

	local tbase = system.pathForFile( nil, targetBaseDir )
	local targetPath = tbase .. "/" .. target .. "/"

print ("copyDir:",sbase, targetPath)

	local res, err = lfs.chdir(targetPath)
	if (not res) then
		print ("ERROR: copyDir tried to change directories to "..targetPath.." but failed: "..err)
		return false
	else
		res, err = lfs.mkdir( newname )
	end

	--if (err) then print (err) end

	local s = src
	local t = target

	local srcPath = sbase .. "/" .. src
	local res = lfs.chdir (srcPath)

	local allowDotFiles = false

	if (res) then
		for filename in lfs.dir(srcPath) do
			local res = lfs.chdir (srcPath)
			if (res and allowDotFiles or string.sub(filename, 1, 1) ~= ".") then
				if (filename ~= "." and filename ~= ".." ) then
					local attr = lfs.attributes (filename)
					if (attr.mode == "directory") then
						-- make dir in new location
						copyDir (s.."/"..filename, srcBaseDir, t.."/"..newname, targetBaseDir)
					else
						-- copy a file
						copyFile (filename, s, srcBaseDir, t.."/"..newname, targetBaseDir)
					end
				end
			end
		end
	end
end



-------------------------------------------------
-- Delete a directory even if not empty
-- If keepDir is true, then only delete the contents
local function rmDir(dir,path, keepDir)
	path = path or system.DocumentsDirectory

	local doc_path = system.pathForFile( dir, path )
	local res = lfs.chdir (doc_path)

	if (res) then
		for filename in lfs.dir(doc_path) do
			if (filename ~= "." and filename ~= ".." ) then
				lfs.chdir (doc_path)
				local attr = lfs.attributes (filename)
				if (attr.mode == "directory") then
					rmDir(dir.."/"..filename, path)
				else
					lfs.chdir (doc_path)
					local results, reason = os.remove(doc_path .. "/" .. filename, system.DocumentsDirectory)
				end
			end
		end
		if (not keepDir) then
			local results, reason = os.remove(doc_path)
		end
	end
end

-----------
-- Make a directory Tree
-- If we ask for "dirA/dirB/dirC", we might need to create dirA and dirB before creating
-- dirC.
local function mkdirTree (dirname, systemdir)

	systemdir = systemdir or system.CachesDirectory

	dirname = cleanPath(dirname)
	local dirs = split(dirname,"/")
	local nextDir
	local currDir = ""
	for i=1,#dirs do
		local nextDir = currDir.."/"..dirs[i]
		local fullpath = system.pathForFile( nextDir, systemdir )
		if (fullpath and lfs.chdir( fullpath ) ) then
			currDir = nextDir
		else
			local success = lfs.chdir( system.pathForFile( currDir, systemdir ) )
			if (success) then
				local success = lfs.mkdir( dirs[i] )
				if (success) then
					currDir = nextDir
				else
					print ("ERROR: mkdirTree: Cannot create directory: "..nextDir)
				end
			else
				print ("ERROR: mkdirTree: Cannot find directory: "..currDir)
			end
		end

	end
end




local function url_decode(str)
  str = string.gsub (str, "+", " ")
  str = string.gsub (str, "%%(%x%x)",
	  function(h) return string.char(tonumber(h,16)) end)
  str = string.gsub (str, "\r\n", "\n")
  return str
end


local function url_encode(str)
  if (str) then
	str = string.gsub (str, "\n", "\r\n")
	str = string.gsub (str, "([^%w ])",
		function (c) return string.format ("%%%02X", string.byte(c)) end)
	str = string.gsub (str, " ", "+")
  end
  return str
end


local function newArc(x,y,w,h,s,e)
	local xc,yc,cos,sin = x+w/2,y+h/2,math.cos,math.sin
	s,e = s or 0, e or 360
	s,e = math.rad(s),math.rad(e)
	w,h = w/2,h/2
	local l = display.newLine(0,0,0,0)
	for t=s,e,0.02 do l:append(xc + w*cos(t), yc - h*sin(t)) end
	return l
end

-- Call like this: setFillColorFromString(obj, "10,20,30,30%")
-- All values can be number or percent
local function setFillColorFromString(obj, cstring)
	local s = stringToColorTable(cstring)
	if (obj.setFillColor) then
		obj:setFillColor(s[1], s[2], s[3], s[4])
	else
		obj:setFillColor(s[1], s[2], s[3], s[4])
	end
end



local function getDeviceMetrics( )

	-- See: http://en.wikipedia.org/wiki/List_of_displays_by_pixel_density

	local corona_width	= -display.screenOriginX * 2 + display.contentWidth
	local corona_height = -display.screenOriginY * 2 + display.contentHeight
	--print("Corona unit width: " .. corona_width .. ", height: " .. corona_height)

	-- I was rounding these, on the theory that they would always round to the correct integer pixel
	-- size, but I noticed that in practice it rounded to an incorrect size sometimes, so I think it's
	-- better to use the computed fractional values instead of possibly introducing more error.
	--
	local pixel_width  = corona_width / display.contentScaleX
	local pixel_height = corona_height / display.contentScaleY
	--print("Pixel width: " .. pixel_width .. ", height: " .. pixel_height)

	local model = system.getInfo("model")
	local default_device =
		{ model = model,		  inchesDiagonal =	4.0, } -- Approximation (assumes average sized phone)
	local devices = {
		{ model = "iPhone",		  inchesDiagonal =	3.5, },
		{ model = "iPad",		  inchesDiagonal =	9.7, },
		{ model = "iPod touch",	  inchesDiagonal =	3.5, },
		{ model = "Nexus One",	  inchesDiagonal =	3.7, },
		{ model = "Nexus S",	  inchesDiagonal =	4.0, }, -- Unverified model value
		{ model = "Droid",		  inchesDiagonal =	3.7, },
		{ model = "Droid X",	  inchesDiagonal =	4.3, }, -- Unverified model value
		{ model = "Galaxy Tab",	  inchesDiagonal =	7.0, },
		{ model = "Galaxy Tab X", inchesDiagonal = 10.1, }, -- Unverified model value
		{ model = "Kindle Fire",  inchesDiagonal =	7.0, },
		{ model = "Nook Color",	  inchesDiagonal =	7.0, },
	}

	local device = default_device
	for _, deviceEntry in pairs(devices) do
		if deviceEntry.model == model then
			device = deviceEntry
		end
	end

	-- Pixel width, height, and pixels per inch
	device.pixelWidth = pixel_width
	device.pixelHeight = pixel_height
	device.ppi = math.sqrt((pixel_width^2) + (pixel_height^2)) / device.inchesDiagonal

	-- Corona unit width, height, and "Corona units per inch"
	device.coronaWidth = corona_width
	device.coronaHeight = corona_height
	device.cpi = math.sqrt(corona_width^2 + corona_height^2)/device.inchesDiagonal

	--print("Device: " .. device.model .. ", size: " .. device.inchesDiagonal .. " inches, ppi: " .. device.ppi .. ", cpi: " .. device.cpi)

	return device

end

-- This makes a mask for a widget.scrollView
local function makeMask(width, height, maskDirectory)

	-- Display.save uses the screen size, so a retina will save a double-size image than what we need


	maskDirectory = maskDirectory or "_masks"

	local baseDir = system.CachesDirectory
	local maskfilename = maskDirectory .. "/" .. "mask-"..width.."-"..height..".jpg"
	if (not fileExists(maskfilename, baseDir) ) then

		mkdirTree (maskDirectory, baseDir)

		local g = display.newGroup()

		local scalingRatio = scaleFactorForRetina()
		width = width * scalingRatio
		height = height * scalingRatio

		local mask = display.newRect(g, 0,0,width+4, height+4 )
		mask:setFillColor(0)

		local opening = display.newRect(g, 0,0,width, height )
		opening:setFillColor(255)
		opening:setReferencePoint(display.TopLeftReferencePoint)
		opening.x = 2
		opening.y = 2

		display.save( g, maskfilename, baseDir )
		g:removeSelf()
	end
	return maskfilename
end



-- This makes a mask for a rectangle on the screen at a particular x,y
local function makeMaskForRect(x,y,width, height, maskDirectory)

	-- Display.save uses the screen size, so a retina will save a double-size image than what we need

	x = math.max(x,0)
	y = math.max(y,0)

	maskDirectory = maskDirectory or "_masks"

	local baseDir = system.CachesDirectory
	local maskfilename = maskDirectory .. "/" .. "mask-" .. width .. "x" .. height .. "@" .. x .. "," .. y .. "-" ..screenW.."x"..screenH..".png"
	if (not fileExists(maskfilename, baseDir) ) then

		mkdirTree (maskDirectory, baseDir)

		local g = display.newGroup()

		local scalingRatio = scaleFactorForRetina()
		width = width * scalingRatio
		height = height * scalingRatio

		-- black background
		local mask = display.newRect(g, 0,0,screenW, screenH )
		mask:setFillColor(0)

		-- opening
		local opening = display.newRect(g, 0,0,width, height )
		opening:setFillColor(255)
		opening:setReferencePoint(display.TopLeftReferencePoint)
		opening.x = x
		opening.y = y

		display.save( g, maskfilename, baseDir )
		g:removeSelf()
	end
	return maskfilename
end

-- This requires a generic mask file!!!!
--- Masking using a single mask file, from the Corona SDK forum
-- @params (table) object = object to mask, width/height = of mask,
--[[
local OPTIONS_LIST_HEIGHT = 300
local OPTIONS_LIST_HEIGHT = 200
local thingToMask = somedisplayobject

applyMask({
	object = thingToMask,
	width = OPTIONS_LIST_WIDTH,
	height = OPTIONS_LIST_HEIGHT
})
--]]
local function applyMask(params)

	local GENERIC_MASK_FILE = "_ui/generic-mask-1024x768.png"
	local generic_mask_width = 1024
	local generic_mask_height = 768

	if params.object == nil then
		return
	end
	if params.width == nil then
		params.width = params.object.width
	end
	if params.height == nil then
		params.height = params.object.height
	end
	if params.mask == nil then
		params.mask = "_ui/generic-mask-1024x768.png"
	end

	local myMask = graphics.newMask(params.mask)
	params.object:setMask(myMask)
	params.object.maskScaleX = params.width/generic_mask_width
	params.object.maskScaleY = params.height/generic_mask_height
	--there may be a need in the future add logic to the positioning for different reference points
	params.object.maskX = 0	--params.width/2
	params.object.maskY = 0	--params.height/2

end




-- DOES NOT WORK
local function translateHTMLEntity(s)
    local _ENTITIES = {
					  ["&lt;"] = "<",
                      ["&gt;"] = ">",
                      ["&amp;"] = "&",
                      ["&quot;"] = '"',
                      ["&apos;"] = "'",
                      ["&bull;"] = string.char(149),
                      ["&dash;"] = string.char(150),
                      ["&mdash;"] = string.char(151),
                      ["&#(%d+);"] = function (x)
                                        local d = tonumber(x)
                                        if d >= 0 and d < 256 then
                                            return string.char(d)
                                        else
                                            return "&#"..d..";"
                                        end
                                     end,
                      ["&#x(%x+);"] = function (x)
                                        local d = tonumber(x,16)
                                        if d >= 0 and d < 256 then
                                            return string.char(d)
                                        else
                                            return "&#x"..x..";"
                                        end
                                      end,
                    }
	-- Replace the entities found in s
	for k,v in pairs(_ENTITIES) do
		--print (k, v)
		s = string.gsub(s,k,v)
	end
	return s
end



local function checksum(str)
   local temp = 0
   local weight = 10
   for i = 1, string.len(str) do
      local c = str:byte(i,i)
      temp = temp + c * weight
      weight = weight - 1
   end
   --[[
   temp = 11 - (temp % 11)
   if temp == 10 then
      return "X"
   else
      if temp == 11 then
         return "0"
      else
         return tostring(temp)
      end
   end
   --]]
	return temp
end


-- Get status bar height.
-- Problem is, if the bar is hidden, the height is zero
local function getStatusBarHeight()
	local t = display.topStatusBarContentHeight
	if (t == 0) then
		display.setStatusBar( display.DarkStatusBar )
		t = display.topStatusBarContentHeight
		display.setStatusBar( display.HiddenStatusBar )
	end
	return t
end

-----------------------------------
-- Clear all contents of the directory
local function deleteDirectoryContents(dir, whichSystemDirectory)
	whichSystemDirectory = whichSystemDirectory or system.CachesDirectory
	rmDir(dir, whichSystemDirectory, true)
	--print ("deleteDirectoryContents", dir)
end


--===================================
--- Frame a group by adding rectangle to a group, behind it.
local function frameGroup(g, s, color)

	local w,h = g.contentWidth or screenW, g.contentHeight or screenH

	local r = display.newRect(g, 0, 0, w, h)
	r.strokeWidth = s or 5

	color = color or "255,0,0"

	if (type(color) == "string") then
		color = stringToColorTable(color)
	end
	r:setStrokeColor(unpack(color))
	
	r:setFillColor(255,0,0, 50)
	
	r:toBack()
	r.anchorX, r.anchorY = 0, 0
	r.x, r.y = 0,0
end


--- Get a random set from a table
--  Check the validity of each key, does it exist in the db param?
--  The db should be  { key1 = value, key2 = value, ...}
--	@param	src	table = { key1, key2, ... }
--	@param	n	number of elements of src to use
--	@param	db	key-value table to check for validity
--  @param  indexOrdered	(Boolean) If true, index result using ordered numbers not source keys. If indexed by keys, the result will be a key/value set using keys from src. Otherwise, result will be indexed numerically, starting at 1.
local function getRandomSet(src, n, db, indexOrdered)
	local keys = {}
	local i = 1
	for k,v in pairs(src) do
		if ( (not db) or db[v]) then
			keys[i] = {key=k,val=v}
			i=i+1
		end
	end
	local set = {}
	n = min(n, #keys)
	for i = 1,n do
		local k = random(#keys)
		if (indexOrdered) then
			set[#set+1] = keys[k].val
		else
			set[ keys[k].key ] = keys[k].val
		end
		table.remove(keys,k)
	end
	return set
end


local function getFirstElement(t)
	local res
	for i,j in pairs (t) do
		res = {i,j}
		break
	end
	return res[1], res[2]
end



-- ====================================================================
-- Check multiple paths for a file
-- Used to look for book files in multiple places, hierarchically,
-- e.g. look first in _user/books/ then on shelves
-- Default with no values is to return the default book.
-- @param	locations	Table: { 1 = { path = "path/to/book/folders", bookDir = "bookfolder", systemDirectory = system.ResourceDirectory }, ... }
-- Example:
-- findFile ( "book.xml", "_user/books" , "_user" )
-- ====================================================================
local function findFile (filename, locations, default)

	default = default or "_user"
	if (not filename or not locations or type(locations) ~= "table") then
		return { path = default, systemDirectory = system.ResourceDirectory }
	end
	
	local p
	for i,loc in pairs(locations) do

		if (loc.bookDir == "default" or loc.bookDir == "" ) then
			return default, system.ResourceDirectory
		end
	

		--print ("Look for ", joinAsPath{loc.path, loc.bookDir, filename} )
		if ( fileExists( joinAsPath{loc.path, loc.bookDir, filename}, loc.systemDirectory) ) then
			--print ("Found ", filename, "in", loc.path .. loc.bookDir)
			return loc.path, loc.systemDirectory
		else
			--print ("NOT FOUND AT ", joinAsPath{loc.path, loc.bookDir, filename})
		end
	end
	return false
end

-- ====================================================================
-- Register new functions here
-- ====================================================================


FUNX.activityIndicator = activityIndicator
FUNX.activityIndicatorOff = activityIndicatorOff
FUNX.activityIndicatorOn = activityIndicatorOn
FUNX.AddCommas = AddCommas
FUNX.addPosRect = addPosRect
FUNX.adjustXYforShadow  = adjustXYforShadow 
FUNX.anchorBottomRightZero = anchorBottomRightZero
FUNX.anchorCenter = anchorCenter
FUNX.anchorCenterZero = anchorCenterZero
FUNX.anchorTopLeft = anchorTopLeft
FUNX.anchorTopLeftZero = anchorTopLeftZero
FUNX.applyMask = applyMask
FUNX.applyPercent  = applyPercent 
FUNX.applyPercentIfSet = applyPercentIfSet
FUNX.autoWrappedText  = autoWrappedText 
FUNX.basename  = basename 
FUNX.buildPictureCorners  = buildPictureCorners 
FUNX.buildShadow = buildShadow
FUNX.buildShadow1 = buildShadow1
FUNX.buildTextDisplayObjectsFromTemplate  = buildTextDisplayObjectsFromTemplate 
FUNX.callClean  = callClean 
FUNX.canConnectWithServer = canConnectWithServer
FUNX.capitalize = capitalize
FUNX.centerInParent = centerInParent
FUNX.checkScale = checkScale
FUNX.checksum = checksum
FUNX.cleanGroups  = cleanGroups 
FUNX.cleanPath  = cleanPath 
FUNX.copyDir  = copyDir 
FUNX.copyFile  = copyFile 
FUNX.coverUpScreenEdges = coverUpScreenEdges
FUNX.datetime_to_unix_time = datetime_to_unix_time
FUNX.deleteDirectoryContents = deleteDirectoryContents
FUNX.dimScreen = dimScreen
FUNX.dirname = dirname
FUNX.newArc = newArc
FUNX.dump = dump
FUNX.escape = escape
FUNX.fadeIn  = fadeIn 
FUNX.fadeOut  = fadeOut 
FUNX.fileExists = fileExists
FUNX.findFile = findFile
FUNX.fixCapsForReferencePoint = fixCapsForReferencePoint
FUNX.flashscreen = flashscreen
FUNX.formatDate = formatDate
FUNX.frameGroup = frameGroup
FUNX.get_date_parts = get_date_parts
FUNX.getday_posfix = getday_posfix
FUNX.getDeviceMetrics = getDeviceMetrics
FUNX.getDisplayObjectParams = getDisplayObjectParams
FUNX.getElementName  = getElementName 
FUNX.getEscapedKeysForGsub = getEscapedKeysForGsub
FUNX.getFinalSizes  = getFinalSizes 
FUNX.getFirstElement = getFirstElement
FUNX.getImageSize = getImageSize
FUNX.getmonth = getmonth
FUNX.getRandomSet = getRandomSet
FUNX.getScaledFilename = getScaledFilename
FUNX.getStatusBarHeight = getStatusBarHeight
FUNX.getTextStyles  = getTextStyles 
FUNX.getValue = getValue
FUNX.getXHeightAdjustment  = getXHeightAdjustment 
FUNX.hasFieldCodes = hasFieldCodes
FUNX.hasFieldCodesSingle = hasFieldCodesSingle
FUNX.hasNetConnection = hasNetConnection
FUNX.hideObject = hideObject
FUNX.hideSpinner = hideSpinner
FUNX.indexOfSystemDirectory = indexOfSystemDirectory
FUNX.initSystemEventHandler = initSystemEventHandler
FUNX.inTable = inTable
FUNX.isPercent  = isPercent 
FUNX.isTable = isTable
FUNX.joinAsPath = joinAsPath
FUNX.keysExistInTable = keysExistInTable
FUNX.lazyLoad = lazyLoad
FUNX.lines = lines
FUNX.loadData = loadData
FUNX.loadFile = loadFile
FUNX.loadImageFile = loadImageFile
FUNX.loadTable = loadTable
FUNX.loadTableFromFile = loadTableFromFile
FUNX.loadTextStyles = loadTextStyles
FUNX.ltrim = ltrim
FUNX.makeMask = makeMask
FUNX.makeMaskForRect = makeMaskForRect
FUNX.mediaFileType = mediaFileType
FUNX.mkdir  = mkdir 
FUNX.mkdirTree  = mkdirTree 
FUNX.OLD_substitutionsSLOWER  = OLD_substitutionsSLOWER 
FUNX.openURLWithConfirm = openURLWithConfirm
FUNX.pairsByKeys  = pairsByKeys 
FUNX.percent  = percent 
FUNX.percentOfScreenHeight  = percentOfScreenHeight 
FUNX.percentOfScreenWidth  = percentOfScreenWidth 
FUNX.popup = popup
FUNX.popupWebpage = popupWebpage
FUNX.positionByName = positionByName
FUNX.positionObject = positionObject
FUNX.positionObjectAroundCenter = positionObjectAroundCenter
FUNX.positionObjectWithReferencePoint = positionObjectWithReferencePoint
FUNX.setAnchorFromReferencePoint = setAnchorFromReferencePoint
FUNX.convertAnchorToReferencePointName = convertAnchorToReferencePointName
FUNX.reanchorToCenter = reanchorToCenter
FUNX.printFuncName = printFuncName
FUNX.ratioToFitMargins  = ratioToFitMargins 
FUNX.referenceAdjustedXY  = referenceAdjustedXY 
FUNX.removeFields  = removeFields 
FUNX.removeFieldsSingle  = removeFieldsSingle 
FUNX.removeFromTable = removeFromTable
FUNX.replaceWildcard = replaceWildcard
FUNX.rescaleFromIpad = rescaleFromIpad
FUNX.resizeFromIpad = resizeFromIpad
FUNX.rmDir = rmDir
FUNX.round = round
FUNX.round2 = round2
FUNX.rtrim = rtrim
FUNX.saveData = saveData
FUNX.saveTable = saveTable
FUNX.saveTableToFile = saveTableToFile
FUNX.scaleFactorForRetina = scaleFactorForRetina
FUNX.scaleObjectToMargins  = scaleObjectToMargins 
FUNX.ScaleObjToSize  = ScaleObjToSize 
FUNX.setFillColorFromString = setFillColorFromString
FUNX.setTextStyles  = setTextStyles 
FUNX.showContentToLocal = showContentToLocal
FUNX.showSpinner = showSpinner
FUNX.showTestBox  = showTestBox 
FUNX.showTestLine  = showTestLine 
FUNX.shrinkAway  = shrinkAway 
FUNX.spinner = spinner
FUNX.spinner = spinner
FUNX.split = split
FUNX.stringToColorTable = stringToColorTable
FUNX.stringToColorTableHDR = stringToColorTableHDR
FUNX.stringToMarginsTable = stringToMarginsTable
FUNX.stripCommandLinesFromText = stripCommandLinesFromText
FUNX.strokeRectObject = strokeRectObject
FUNX.substitutions  = substitutions 
FUNX.table_multi_sort = table_multi_sort
FUNX.table_sort = table_sort
FUNX.tableCopy = tableCopy
FUNX.tableIsEmpty = tableIsEmpty
FUNX.tablelength  = tablelength 
FUNX.tableMerge = tableMerge
FUNX.tableRemoveUnusedCodedElements = tableRemoveUnusedCodedElements
FUNX.tableSubstitutions = tableSubstitutions
FUNX.tellUser = tellUser
FUNX.timePassed = timePassed
FUNX.toggleObject = toggleObject
FUNX.toZero = toZero
FUNX.traceback = traceback
FUNX.translateHTMLEntity = translateHTMLEntity
FUNX.trim = trim
FUNX.undimScreen = undimScreen
FUNX.unescape  = unescape 
FUNX.unloadModule  = unloadModule 
FUNX.url_decode = url_decode
FUNX.url_encode = url_encode
FUNX.verifyNetConnectionOrQuit = verifyNetConnectionOrQuit
FUNX.zSort = zSort


return FUNX