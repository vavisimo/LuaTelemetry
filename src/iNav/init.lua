local data, units, emptyGPS, SMLCD, FILE_PATH, getTelemetryId, getTelemetryUnit = ...

-- Config options: o=display Order / t=Text / c=Characters / v=default Value / l=Lookup text / d=Decimal / m=Min / x=maX / i=Increment / a=Append text / b=Blocked by
local config = {
	{ o = 1,  t = "Battery View",   c = 1, v = 1, i = 1, l = {[0] = "Cell", "Total"} },
	{ o = 3,  t = "Cell Low",       c = 2, v = 3.5, d = true, m = 2.7, x = 3.9, i = 0.1, a = "V", b = 2 },
	{ o = 4,  t = "Cell Critical",  c = 2, v = 3.4, d = true, m = 2.6, x = 3.8, i = 0.1, a = "V", b = 2 },
	{ o = 13, t = "Voice Alerts",   c = 1, v = 2, x = 2, i = 1, l = {[0] = "Off", "Critical", "All"} },
	{ o = 14, t = "Feedback",       c = 1, v = 3, x = 3, i = 1, l = {[0] = "Off", "Haptic", "Beeper", "All"} },
	{ o = 8,  t = "Max Altitude",   c = 4, v = data.altitude_unit == 10 and 400 or 120, x = 9999, i = data.altitude_unit == 10 and 10 or 1, a = units[data.altitude_unit], b = 7 },
	{ o = 12, t = "Variometer",     c = 1, v = 1, i = 1, l = {[0] = "Off", "On"} },
	{ o = 15, t = "RTH Feedback",   c = 1, v = 1, i = 1, l = {[0] = "Off", "On"}, b = 14 },
	{ o = 16, t = "HeadFree Fback", c = 1, v = 1, i = 1, l = {[0] = "Off", "On"}, b = 14 },
	{ o = 17, t = "RSSI Feedback",  c = 1, v = 1, i = 1, l = {[0] = "Off", "On"}, b = 14 },
	{ o = 2,  t = "Battery Alerts", c = 1, v = 2, x = 2, i = 1, l = {[0] = "Off", "Critical", "All"} },
	{ o = 7,  t = "Altitude Alert", c = 1, v = 1, i = 1, l = {[0] = "Off", "On"} },
	{ o = 9,  t = "Timer",          c = 1, v = 1, x = 4, i = 1, l = {[0] = "Off", "Auto", "Timer1", "Timer2", "Timer3"} },
	{ o = 11, t = "Rx Voltage",     c = 1, v = 1, i = 1, l = {[0] = "Off", "On"} },
	{ o = 22, t = "GPS",            c = 1, v = 0, x = 0, i = 0, l = {[0] = emptyGPS} },
	{ o = 21, t = "GPS Coords",     c = 1, v = 0, x = 2, i = 1, l = {[0] = "Decimal", "Deg/Min", "Geocode"} },
	{ o = 6,  t = "Fuel Critical",  c = 2, v = 20, m = 5, x = 30, i = 5, a = "%", b = 2 },
	{ o = 5,  t = "Fuel Low",       c = 2, v = 30, m = 10, x = 50, i = 5, a = "%", b = 2 },
	{ o = 10, t = "Tx Voltage",     c = 1, v = SMLCD and 1 or 2, x = SMLCD and 1 or 2, i = 1, l = {[0] = "Number", "Graph", "Both"} },
	{ o = 18, t = "Speed Sensor",   c = 1, v = 0, i = 1, l = {[0] = "GPS", "Pitot"} },
	{ o = 20, t = "GPS Warning     >", c = 2, v = 2.5, d = true, m = 1.0, x = 5.0, i = 0.5, a = " HDOP" },
	{ o = 19, t = "GPS HDOP View",  c = 1, v = 0, i = 1, l = {[0] = "Graph", "Decimal"} },
}
local configValues = 22
for i = 1, configValues do
	for ii = 1, configValues do
		if i == config[ii].o then
			config[i].z = ii
			config[ii].o = nil
		end
	end
end

-- Load config data
local fh = io.open(FILE_PATH .. "config.dat", "r")
if fh ~= nil then
	for line = 1, configValues do
		local tmp = io.read(fh, config[line].c)
		if tmp ~= "" then
			config[line].v = config[line].d == nil and tonumber(tmp) or tmp / 10
		end
	end
	io.close(fh)
end
config[7].v = data.accZ_id > -1 and config[7].v or 0
config[15].v = 0
config[19].x = config[14].v == 0 and 2 or SMLCD and 1 or 2
config[19].v = math.min(config[19].x, config[19].v)
config[20].v = data.pitot and config[20].v or 0
local tmp = config[20].v == 0 and "GSpd" or "ASpd"
data.speed_id = getTelemetryId(tmp)
data.speedMax_id = getTelemetryId(tmp .. "+")
data.speed_unit = getTelemetryUnit(tmp)

return config, configValues