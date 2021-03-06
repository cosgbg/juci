#!/usr/bin/lua 

-- JUCI Lua Backend Server API
-- Copyright (c) 2016 Martin Schröder <mkschreder.uk@gmail.com>. All rights reserved. 
-- This module is distributed under GNU GPLv3 with additional permission for signed images.
-- See LICENSE file for more details. 

local juci = require("orange/core"); 

function ethernet_list_network_adapters(opts)
	function words(str) 
		local f = {}; 
		local count = 0; 
		for w in str:gmatch("%S+") do table.insert(f, w); count = count + 1; end
		return count,f; 
	end
	
	function ipv4parse(ip)
		if not ip then return "",""; end
		local ip,num = ip:match("([%d\\.]+)/(%d+)"); 
		local mask = "0.0.0.0"; 
		if num then 
			local inet_mask = "255"; 
			for i = 16,32,8 do 
				if i <= tonumber(num) then 
					inet_mask = inet_mask..".255";
				else 
					inet_mask = inet_mask..".0"; 
				end
			end
			mask = inet_mask; 
		end
		return ip,mask; 
	end
	
	function ipv6parse(ip)
		if not ip then return "",""; end
		local ip,num = ip:match("([%w:]+)/(%d+)"); 
		-- TODO: return also mask/prefix? whatever..
		return ip; 
	end
	
	local adapters = {}; 
	local obj = {}; 
	local ip_output = juci.shell("ip addr"); 
	for line in ip_output:gmatch("[^\r\n]+") do
		local count,fields = words(line); 
		if fields[1] then 
			if fields[1]:match("%d+:") then
				if(next(obj) ~= nil and obj.device ~= "lo") then table.insert(adapters, obj); end
				obj = {}; 
				obj.device = fields[2]:match("([^:@]+)"); -- match until @ in vlan adapters 
				obj.name = obj.device; 
				obj.flags = fields[3]:match("<([^>]+)>"); 
				-- parse remaining pairs after flags
				for id = 4,count,2 do
					obj[fields[id]] = fields[id+1]; 
				end
			elseif fields[1]:match("link/.*") then 
				obj.link_type = fields[1]:match("link/(.*)"); 
				obj.macaddr = fields[2]; 
				-- parse remaining pairs after link type
				for id = 3,count,2 do
					obj[fields[id]] = fields[id+1]; 
				end
			elseif fields[1] == "inet" then
				if not obj.ipv4 then obj.ipv4 = {} end
				local ipobj = {}; 
				ipobj.addr,ipobj.mask = ipv4parse(fields[2]); 
				-- pase remaining pairs for ipaddr options
				for id = 3,count,2 do
					ipobj[fields[id]] = fields[id+1]; 
				end
				table.insert(obj.ipv4, ipobj); 
			elseif fields[1] == "inet6" then
				if not obj.ipv6 then obj.ipv6 = {} end
				local ipobj = {}; 
				ipobj.addr = ipv6parse(fields[2]); 
				-- parse remaining pairs for ipaddr options
				for id = 3,count,2 do
					ipobj[fields[id]] = fields[id+1]; 
				end
				table.insert(obj.ipv6, ipobj); 
			else 
				-- all other lines are assumed to consist of only pairs
				for id = 1,count,2 do
					obj[fields[id]] = fields[id+1]; 
				end
			end
		end
	end
	-- add last parsed adapter to the list as well
	if(next(obj) ~= nil) then table.insert(adapters, obj); end
	
	for i,v in pairs(adapters) do
		if(v.state and v.state == "UNKNOWN" and v.device and string.find(v.device, "wl")) then
			local state = juci.shell("wlctl -i %s bss", v.device);
			if(state) then v.state = state:gsub("%s",""):upper(); end;
		end
	end
	return { adapters = adapters }; 
end

return {
	["adapters"] = ethernet_list_network_adapters
}; 
