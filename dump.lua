module(..., package.seeall)

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

