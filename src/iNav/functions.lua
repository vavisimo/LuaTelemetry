local SMLCD = ...

local function gpsDegMin(coord, lat)
	local gpsD = math.floor(math.abs(coord))
	return gpsD .. string.format("\64%05.2f", (math.abs(coord) - gpsD) * 60) .. (lat and (coord >= 0 and "N" or "S") or (coord >= 0 and "E" or "W"))
end

local function gpsGeocoding(coord, lat)
	local gpsD = math.floor(math.abs(coord))
	return (lat and (coord >= 0 and "N" or "S") or (coord >= 0 and "E" or "W")) .. gpsD .. string.format("\64%05.2f", (math.abs(coord) - gpsD) * 60)
end

local function drawDirection(heading, width, radius, x, y, hh)
	local rad1 = math.rad(heading)
	local rad2 = math.rad(heading + width)
	local rad3 = math.rad(heading - width)
	local x1 = math.floor(math.sin(rad1) * radius + 0.5) + x
	local y1 = y - math.floor(math.cos(rad1) * radius + 0.5)
	local x2 = math.floor(math.sin(rad2) * radius + 0.5) + x
	local y2 = y - math.floor(math.cos(rad2) * radius + 0.5)
	local x3 = math.floor(math.sin(rad3) * radius + 0.5) + x
	local y3 = y - math.floor(math.cos(rad3) * radius + 0.5)
	lcd.drawLine(x1, y1, x2, y2, SOLID, FORCE)
	lcd.drawLine(x1, y1, x3, y3, SOLID, FORCE)
	if hh then
		lcd.drawFilledRectangle((x2 + x3) / 2 - 1.5, (y2 + y3) / 2 - 1.5, 4, 4, SOLID)
	else
		lcd.drawLine(x2, y2, x3, y3, SMLCD and DOTTED or SOLID, FORCE + (SMLCD and 0 or GREY_DEFAULT))
	end
end

local function drawData(txt, y, dir, vc, vm, max, ext, frac, flags, showMax)
	if showMax and dir > 0 then
		vc = vm
		lcd.drawText(0, y, string.sub(txt, 1, 3), SMLSIZE)
		lcd.drawText(15, y, dir == 1 and "\192" or "\193", SMLSIZE)
	else
		lcd.drawText(0, y, txt, SMLSIZE)
	end
	local tmpext = (frac ~= 0 or vc < max) and ext or ""
	if frac ~= 0 and vc + 0.5 < max then
		lcd.drawText(21, y, string.format(frac, vc) .. tmpext, SMLSIZE + flags)
	else
		lcd.drawText(21, y, math.floor(vc + 0.5) .. tmpext, SMLSIZE + flags)
	end
end

return gpsDegMin, gpsGeocoding, drawDirection, drawData