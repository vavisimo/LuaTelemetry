-- Lua Telemetry Flight Status for INAV/Taranis
-- Author: https://github.com/teckel12
-- Docs: https://github.com/iNavFlight/LuaTelemetry

local VERSION = "1.3.2"
local FILE_PATH = "/SCRIPTS/TELEMETRY/iNav/"
local FLASH = 3
local SMLCD = LCD_W < 212
local RIGHT_POS = SMLCD and 129 or 195
local GAUGE_WIDTH = SMLCD and 82 or 149
local X_CNTR_1 = SMLCD and 63 or 68
local X_CNTR_2 = SMLCD and 63 or 104
local GPS_FORMAT = SMLCD and "%.5f" or "%.6f"

local modes, units, emptyGPS = loadScript(FILE_PATH .. "modes.luac", "bT")(FLASH)
local gpsDegMin, gpsGeocoding, drawDirection, drawData = loadScript(FILE_PATH .. "functions.luac", "bT")(SMLCD)
local data, getTelemetryId, getTelemetryUnit, PREV, INCR, NEXT, DECR, MENU, reset = loadScript(FILE_PATH .. "data.luac", "bT")(emptyGPS)
local config, configValues = loadScript(FILE_PATH .. "init.luac", "bT")(data, units, emptyGPS, SMLCD, FILE_PATH, getTelemetryId, getTelemetryUnit)

local function playAudio(file, alert)
	if config[4].v == 2 or (config[4].v == 1 and alert ~= nil) then
		playFile(FILE_PATH .. file .. ".wav")
	end
end

local function flightModes()
	local armedPrev = data.armed
	local headFreePrev = data.headFree
	local headingHoldPrev = data.headingHold
	local altHoldPrev = data.altHold
	local homeReset = false
	local modeIdPrev = data.modeId
	if data.telemetry then
		data.armed = false
		data.headFree = false
		data.headingHold = false
		data.altHold = false
		data.modeId = 1 -- No telemetry
		local modeA = data.mode / 10000
		local modeB = data.mode / 1000 % 10
		local modeC = data.mode / 100 % 10
		local modeD = data.mode / 10 % 10
		local modeE = data.mode % 10
		if bit32.band(modeE, 4) == 4 then
			data.armed = true
			if bit32.band(modeD, 2) == 2 then
				data.modeId = 2 -- Horizon
			elseif bit32.band(modeD, 1) == 1 then
				data.modeId = 3 -- Angle
			else
				data.modeId = 4 -- Acro
			end
			data.headFree = bit32.band(modeB, 4) == 4 and true or false
			data.headingHold = bit32.band(modeC, 1) == 1 and true or false
			data.altHold = bit32.band(modeC, 2) == 2 and true or false
			homeReset = data.satellites >= 4000 and true or false
			if bit32.band(modeC, 4) == 4 then
				data.modeId = data.altHold and 8 or 7 -- If also alt hold 3D hold else pos hold
			end
		else
			data.modeId = (bit32.band(modeE, 2) == 2 or modeE == 0) and (data.throttle > -1000 and 13 or 5) or 6 -- Not OK to arm / Throttle warning / Ready to fly
		end
		if bit32.band(modeA, 4) == 4 then
			data.modeId = 12 -- Failsafe
		elseif bit32.band(modeB, 1) == 1 then
			data.modeId = 11 -- RTH
		elseif bit32.band(modeD, 4) == 4 then
			data.modeId = 10 -- Passthru
		elseif bit32.band(modeB, 2) == 2 then
			data.modeId = 9 -- Waypoint
		end
	end
	
	-- Voice alerts
	local vibrate = false
	local beep = false
	if data.armed and not armedPrev then -- Engines armed
		data.timerStart = getTime()
		data.headingRef = data.heading
		data.gpsHome = false
		data.battPercentPlayed = 100
		data.battLow = false
		data.showMax = false
		data.showDir = false
		data.config = 0
		if not data.gpsAltBase and data.gpsFix then
			data.gpsAltBase = data.gpsAlt
		end
		playAudio("engarm", 1)
	elseif not data.armed and armedPrev then -- Engines disarmed
		if data.distanceLast <= data.distRef then
			data.headingRef = -1
			data.showDir = true
			data.gpsAltBase = false
		end
		playAudio("engdrm", 1)
	end
	if data.gpsFix ~= data.gpsFixPrev then -- GPS status change
		playAudio("gps", not data.gpsFix and 1 or nil)
		playAudio(data.gpsFix and "good" or "lost", not data.gpsFix and 1 or nil)
	end
	if modeIdPrev ~= data.modeId then -- New flight mode
		if data.armed and modes[data.modeId].w ~= nil then
			playAudio(modes[data.modeId].w, modes[data.modeId].f > 0 and 1 or nil)
		elseif not data.armed and data.modeId == 6 and modeIdPrev == 5 then
			playAudio(modes[data.modeId].w)
		end
	end
	data.hdop = math.floor(data.satellites / 100) % 10
	if data.armed then
		data.distanceLast = data.distance
		if config[13].v == 1 then
			data.timer = (getTime() - data.timerStart) / 100 -- Armed so update timer
		elseif config[13].v > 1 then
			data.timer = model.getTimer(config[13].v - 2)["value"]
		end
		if data.altHold ~= altHoldPrev and data.modeId ~= 8 then -- Alt hold status change
			playAudio("althld")
			playAudio(data.altHold and "active" or "off")
		end
		if data.headingHold ~= headingHoldPrev then -- Heading hold status change
			playAudio("hedhld")
			playAudio(data.headingHold and "active" or "off")
		end
		if data.headFree ~= headFreePrev then -- Head free status change
			playAudio(data.headFree and "hfact" or "hfoff", 1)
		end
		if homeReset and not data.homeResetPrev then -- Home reset
			playAudio("homrst")
			data.gpsHome = false
			data.headingRef = data.heading
		end
		if data.altitude + 0.5 >= config[6].v and config[12].v > 0 then -- Altitude alert
			if getTime() > data.altNextPlay then
				if config[4].v > 0 then
					playNumber(data.altitude + 0.5, data.altitude_unit)
				end
				data.altNextPlay = getTime() + 1000
			else
				beep = true
			end
		end
		if data.battPercentPlayed > data.fuel and config[11].v == 2 and config[4].v == 2 then -- Fuel notification
			if data.fuel % 5 == 0 and data.fuel > config[17].v and data.fuel <= config[18].v then
				playAudio("batlow")
				playNumber(data.fuel, 13)
				data.battPercentPlayed = data.fuel
			elseif data.fuel % 10 == 0 and data.fuel < 100 and data.fuel > config[17].v + 10 then
				playAudio("battry")
				playNumber(data.fuel, 13)
				data.battPercentPlayed = data.fuel
			end
		end
		if (data.fuel <= config[17].v or data.cell < config[3].v) and config[11].v > 0 then -- Voltage/fuel critial
			if getTime() > data.battNextPlay then
				playAudio("batcrt", 1)
				if data.fuel <= config[17].v and data.battPercentPlayed > data.fuel and config[4].v > 0 then
					playNumber(data.fuel, 13)
					data.battPercentPlayed = data.fuel
				end
				data.battNextPlay = getTime() + 500
			else
				vibrate = true
				beep = true
			end
			data.battLow = true
		elseif data.cell < config[2].v and config[11].v == 2 then -- Voltage notification
			if not data.battLow then
				playAudio("batlow")
				data.battLow = true
			end
		else
			data.battNextPlay = 0
		end
		if (data.headFree and config[9].v == 1) or modes[data.modeId].f ~= 0 then
			if data.modeId ~= 11 or (data.modeId == 11 and config[8].v == 1) then
				beep = true
				vibrate = true
			end
		elseif data.rssi < data.rssiLow and config[10].v == 1 then
			if data.rssi < data.rssiCrit then
				vibrate = true
			end
			beep = true
		end
		if data.hdop < 11 - config[21].v * 2 then
			beep = true
		end
		if vibrate and (config[5].v == 1 or config[5].v == 3) then
			playHaptic(25, 3000)
		end
		if beep and config[5].v >= 2 then
			playTone(2000, 100, 3000, PLAY_NOW)
		end
	else
		data.battLow = false
		data.battPercentPlayed = 100
	end
	data.gpsFixPrev = data.gpsFix
	data.homeResetPrev = homeReset
end

local function background()
	data.rssi = getValue(data.rssi_id)
	if data.telemFlags == -1 then
		reset()
	end
	if data.rssi > 0 or data.telemFlags < 0 then
		data.telemetry = true
		data.mode = getValue(data.mode_id)
		data.rxBatt = getValue(data.rxBatt_id)
		data.satellites = getValue(data.satellites_id)
		data.gpsAlt = getValue(data.gpsAlt_id)
		data.heading = getValue(data.heading_id)
		data.altitude = getValue(data.altitude_id)
		if data.altitude_id == -1 and data.gpsAltBase and data.gpsFix then
			data.altitude = data.gpsAlt - data.gpsAltBase
		end
		data.distance = getValue(data.distance_id)
		data.speed = getValue(data.speed_id)
		if data.showCurr then
			data.current = getValue(data.current_id)
			data.currentMax = getValue(data.currentMax_id)
			data.fuel = getValue(data.fuel_id)
		end
		data.altitudeMax = getValue(data.altitudeMax_id)
		data.distanceMax = getValue(data.distanceMax_id)
		data.speedMax = getValue(data.speedMax_id)
		data.batt = getValue(data.batt_id)
		data.battMin = getValue(data.battMin_id)
		if (data.cells == -1 and data.batt > 2) or (data.showCurr and data.fuel >= 95) then
			data.cells = math.floor(data.batt / 4.3) + 1
		end
		data.cell = data.batt / math.max(data.cells, 1)
		data.cellMin = data.battMin / math.max(data.cells, 1)
		data.rssiMin = getValue(data.rssiMin_id)
		data.accZ = getValue(data.accZ_id)
		data.txBatt = getValue(data.txBatt_id)
		data.rssiLast = data.rssi
		local gpsTemp = getValue(data.gpsLatLon_id)
		data.gpsFix = data.satellites > 3000 and type(gpsTemp) == "table" and gpsTemp.lat ~= nil and gpsTemp.lon ~= nil
		if data.gpsFix then
			data.gpsLatLon = gpsTemp
			config[15].l[0] = gpsTemp
		else
			data.gpsLatLon = emptyGPS
		end
		-- Dist doesn't have a known unit so the transmitter doesn't auto-convert
		if data.distance_unit == 10 then
			data.distance = math.floor(data.distance * 3.28084 + 0.5)
			data.distanceMax = data.distanceMax * 3.28084
		end
		if data.distance > 0 then
			data.distanceLast = data.distance
		end
		data.telemFlags = 0
	else
		data.telemetry = false
		data.telemFlags = FLASH
	end
	data.throttle = getValue(data.throttle_id)

	flightModes()

	if data.armed and data.gpsFix and data.gpsHome == false then
		data.gpsHome = data.gpsLatLon
	end
end

local function run(event)
	lcd.clear()

	-- Display system error
	if data.systemError then
		lcd.drawText((LCD_W - string.len(data.systemError) * 5.2) / 2, 27, data.systemError)
		return 0
	end

	-- Startup message
	if data.startup == 1 then
		startupTime = getTime()
		data.startup = 2
	elseif data.startup == 2 then
		if getTime() - startupTime < 200 then
			if not SMLCD then
				lcd.drawText(53, 9, "INAV Lua Telemetry")
			end
			lcd.drawText(SMLCD and 51 or 91, 17, "v" .. VERSION)
		else
			data.startup = 0
		end
	end
	local startupTime = 0

	-- GPS
	local gpsFlags = SMLSIZE + RIGHT + ((data.telemFlags > 0 or not data.gpsFix) and FLASH or 0)
	local tmp = RIGHT_POS - (gpsFlags == SMLSIZE + RIGHT and 0 or 1)
	lcd.drawText(tmp, 17, math.floor(data.gpsAlt + 0.5) .. units[data.gpsAlt_unit], gpsFlags)
	if config[16].v == 0 then
		lcd.drawText(tmp, 25, string.format(GPS_FORMAT, data.gpsLatLon.lat), gpsFlags)
		lcd.drawText(tmp, 33, string.format(GPS_FORMAT, data.gpsLatLon.lon), gpsFlags)
	else
		lcd.drawText(tmp, 25, config[16].v == 1 and gpsDegMin(data.gpsLatLon.lat, true) or gpsGeocoding(data.gpsLatLon.lat, true), gpsFlags)
		lcd.drawText(tmp, 33, config[16].v == 1 and gpsDegMin(data.gpsLatLon.lon, false) or gpsGeocoding(data.gpsLatLon.lon, false), gpsFlags)
	end
	if config[22].v == 0 then
		if ((data.armed or data.modeId == 6) and data.hdop < 11 - config[21].v * 2) or not data.telemetry then
			lcd.drawText(RIGHT_POS - 30, 9, "    ", SMLSIZE + FLASH)
		end
		for i = 4, 9 do
			lcd.drawLine(RIGHT_POS - (38 - (i * 2)), (data.hdop >= i or not SMLCD) and 17 - i or 14, RIGHT_POS - (38 - (i * 2)), 14, SOLID, (data.hdop >= i or SMLCD) and 0 or GREY_DEFAULT)
		end
	else
		lcd.drawText(RIGHT_POS - 18, 9, data.hdop == 0 and 99 or (9 - data.hdop) / 2 + 0.8, SMLSIZE + RIGHT + ((((data.armed or data.modeId == 6) and data.hdop < 11 - config[21].v * 2) or not data.telemetry) and FLASH or 0))
	end
	lcd.drawLine(RIGHT_POS - 16, 9, RIGHT_POS - 12, 13, SOLID, FORCE)
	lcd.drawLine(RIGHT_POS - 16, 10, RIGHT_POS - 13, 13, SOLID, FORCE)
	lcd.drawLine(RIGHT_POS - 16, 11, RIGHT_POS - 14, 13, SOLID, FORCE)
	lcd.drawLine(RIGHT_POS - 17, 14, RIGHT_POS - 13, 10, SOLID, FORCE)
	lcd.drawPoint(RIGHT_POS - 16, 14)
	lcd.drawPoint(RIGHT_POS - 15, 14)
	lcd.drawText(RIGHT_POS - (data.telemFlags == 0 and 0 or 1), 9, data.satellites % 100, SMLSIZE + RIGHT + data.telemFlags)

	-- Directionals
	if data.showHead and data.startup == 0 and data.config == 0 then
		if event == NEXT or event == PREV then
			data.showDir = not data.showDir
		end
		if data.telemetry then
			local indicatorDisplayed = false
			if data.showDir or data.headingRef < 0 or not SMLCD then
				lcd.drawText(X_CNTR_1 - 2, 9, "N " .. math.floor(data.heading + 0.5) .. "\64", SMLSIZE)
				lcd.drawText(X_CNTR_1 + 10, 21, "E", SMLSIZE)
				lcd.drawText(X_CNTR_1 - 14, 21, "W", SMLSIZE)
				if not SMLCD then
					lcd.drawText(X_CNTR_1 - 2, 32, "S", SMLSIZE)
				end
				drawDirection(data.heading, 140, 7, X_CNTR_1, 23, data.headingHold)
				indicatorDisplayed = true
			end
			if not data.showDir or data.headingRef >= 0 or not SMLCD then
				if not indicatorDisplayed or not SMLCD then
					drawDirection(data.heading - data.headingRef, 145, 8, SMLCD and 63 or 133, 19, data.headingHold)
				end
			end
		end
		if data.gpsHome ~= false and data.distanceLast >= data.distRef then
			if not data.showDir or not SMLCD then
				local o1 = math.rad(data.gpsHome.lat)
				local a1 = math.rad(data.gpsHome.lon)
				local o2 = math.rad(data.gpsLatLon.lat)
				local a2 = math.rad(data.gpsLatLon.lon)
				local y = math.sin(a2 - a1) * math.cos(o2)
				local x = (math.cos(o1) * math.sin(o2)) - (math.sin(o1) * math.cos(o2) * math.cos(a2 - a1))
				local bearing = math.deg(math.atan2(y, x)) - data.headingRef
				local rad1 = math.rad(bearing)
				local x1 = math.floor(math.sin(rad1) * 10 + 0.5) + X_CNTR_2
				local y1 = 19 - math.floor(math.cos(rad1) * 10 + 0.5)
				lcd.drawLine(X_CNTR_2, 19, x1, y1, SMLCD and DOTTED or SOLID, FORCE + (SMLCD and 0 or GREY_DEFAULT))
				lcd.drawFilledRectangle(x1 - 1, y1 - 1, 3, 3, ERASE)
				lcd.drawFilledRectangle(x1 - 1, y1 - 1, 3, 3, SOLID)
			end
		end
	end

	-- Flight mode
	lcd.drawText((SMLCD and 46 or 83) + (modes[data.modeId].f == FLASH and 1 or 0), 33, modes[data.modeId].t, (SMLCD and SMLSIZE or 0) + modes[data.modeId].f)
	if data.headFree then
		lcd.drawText(RIGHT_POS - 41, 9, "HF", FLASH + SMLSIZE)
	end

	-- User input
	if not data.armed and data.config == 0 then
		-- Toggle showing max/min values
		if event == PREV or event == NEXT then
			data.showMax = not data.showMax
		end
		-- Initalize variables on long <Enter>
		if event == EVT_ENTER_LONG then
			reset()
		end
	end

	-- Data & gauges
	drawData("Altd", 9, 1, data.altitude, data.altitudeMax, 10000, units[data.altitude_unit], 0, (data.telemFlags > 0 or data.altitude + 0.5 >= config[6].v) and FLASH or 0, data.showMax)
	if data.altHold then
		lcd.drawRectangle(47, 9, 3, 3, FORCE)
		lcd.drawFilledRectangle(46, 11, 5, 4, FORCE)
		lcd.drawPoint(48, 12)
	end
	local tmp = (data.telemFlags > 0 or data.fuel <= config[17].v or data.cell < config[3].v) and FLASH or 0
	drawData("Dist", data.distPos, 1, data.distanceLast, data.distanceMax, 10000, units[data.distance_unit], 0, data.telemFlags, data.showMax)
	drawData(units[data.speed_unit], data.speedPos, 1, data.speed, data.speedMax, 1000, '', 0, data.telemFlags, data.showMax)
	drawData("Batt", data.battPos1, 2, config[1].v == 0 and data.cell or data.batt, config[1].v == 0 and data.cellMin or data.battMin, 100, "V", config[1].v == 0 and "%.2f" or "%.1f", tmp, 1, data.showMax)
	drawData("RSSI", 57, 2, data.rssiLast, data.rssiMin, 200, "dB", 0, (data.telemFlags > 0 or data.rssi < data.rssiLow) and FLASH or 0, data.showMax)
	if data.showCurr then
		drawData("Curr", 33, 1, data.current, data.currentMax, 100, "A", "%.1f", data.telemFlags, data.showMax)
		drawData("Fuel", 41, 0, data.fuel, 0, 200, "%", 0, tmp, data.showMax)
		lcd.drawGauge(46, 41, GAUGE_WIDTH, 7, math.min(data.fuel, 98), 100)
		if data.fuel == 0 then
			lcd.drawLine(47, 42, 47, 46, SOLID, ERASE)
		end
	end
	local tmp = 100 / (4.2 - config[3].v + 0.1)
	lcd.drawGauge(46, data.battPos2, GAUGE_WIDTH, 56 - data.battPos2, math.min(math.max(data.cell - config[3].v + 0.1, 0) * tmp, 98), 100)
	local tmp = (GAUGE_WIDTH - 2) * (math.min(math.max(data.cellMin - config[3].v + 0.1, 0) * tmp, 99) / 100) + 47
	lcd.drawLine(tmp, data.battPos2 + 1, tmp, 54, SOLID, ERASE)
	lcd.drawGauge(46, 57, GAUGE_WIDTH, 7, math.max(math.min((data.rssiLast - data.rssiCrit) / (100 - data.rssiCrit) * 100, 98), 0), 100)
	local tmp = (GAUGE_WIDTH - 2) * (math.max(math.min((data.rssiMin - data.rssiCrit) / (100 - data.rssiCrit) * 100, 99), 0) / 100) + 47
	lcd.drawLine(tmp, 58, tmp, 62, SOLID, ERASE)
	if not SMLCD then
		local w = config[7].v == 1 and 7 or 15
		local l = config[7].v == 1 and 205 or 197
		lcd.drawRectangle(l, 9, w, 48, SOLID)
		local tmp = math.max(math.min(math.ceil(data.altitude / config[6].v * 46), 46), 0)
		lcd.drawFilledRectangle(l + 1, 56 - tmp, w - 2, tmp, INVERS)
		local tmp = 56 - math.max(math.min(math.ceil(data.altitudeMax / config[6].v * 46), 46), 0)
		lcd.drawLine(l + 1, tmp, l + w - 2, tmp, SOLID, GREY_DEFAULT)
		lcd.drawText(l + 1, 58, config[7].v == 1 and "A" or "Alt", SMLSIZE)
	end

	-- Variometer
	if config[7].v == 1 and data.startup == 0 then
		if SMLCD and data.armed and not data.showDir then
			lcd.drawLine(X_CNTR_2 + 17, 21, X_CNTR_2 + 19, 21, SOLID, FORCE)
			lcd.drawLine(X_CNTR_2 + 18, 21, X_CNTR_2 + 18, 21 - math.max(math.min(data.accZ - 1, 1), -1) * 12, SOLID, FORCE)
		elseif not SMLCD then
			lcd.drawRectangle(197, 9, 7, 48, SOLID)
			lcd.drawText(198, 58, "V", SMLSIZE)
			if data.armed then
				local tmp = 33 - math.floor(math.max(math.min(data.accZ - 1, 1), -1) * 23 - 0.5)
				if tmp > 33 then
					lcd.drawFilledRectangle(198, 33, 5, tmp - 33, INVERS)
				else
					lcd.drawFilledRectangle(198, tmp - 1, 5, 33 - tmp + 2, INVERS)
				end
			end
		end
	end

	-- Title
	lcd.drawFilledRectangle(0, 0, LCD_W, 8, FORCE)
	lcd.drawText(0, 0, data.modelName, INVERS)
	if config[13].v > 0 then
		lcd.drawTimer(SMLCD and 60 or 150, 1, data.timer, SMLSIZE + INVERS)
	end
	if config[19].v > 0 then
		lcd.drawFilledRectangle(86, 1, 19, 6, ERASE)
		lcd.drawLine(105, 2, 105, 5, SOLID, ERASE)
		local tmp = math.max(math.min((data.txBatt - data.txBattMin) / (data.txBattMax - data.txBattMin) * 17, 17), 0) + 86
		for i = 87, tmp, 2 do
			lcd.drawLine(i, 2, i, 5, SOLID, FORCE)
		end
	end
	if config[19].v ~= 1 then
		lcd.drawText(SMLCD and (config[14].v == 1 and 105 or LCD_W) or 128, 1, string.format("%.1f", data.txBatt) .. "V", SMLSIZE + RIGHT + INVERS)
	end
	if data.rxBatt > 0 and data.telemetry and config[14].v == 1 then
		lcd.drawText(LCD_W, 1, string.format("%.1f", data.rxBatt) .. "V", SMLSIZE + RIGHT + INVERS)
	end

	-- Config menu
	if data.config == 0 and event == MENU then
		data.config = 1
		LTconfigSelect = 0
		LTconfigTop = 1
	end
	if data.config > 0 then
		-- Load config menu
		loadScript(FILE_PATH .. "config.luac", "bT")(FILE_PATH, LCD_W, PREV, INCR, NEXT, DECR, gpsDegMin, gpsGeocoding, configValues, config, data, event)
	end
	
	return 0
end

return { run = run, background = background }
