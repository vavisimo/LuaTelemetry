local emptyGPS = ...

local function getTelemetryId(name)
	local field = getFieldInfo(name)
	return field and field.id or -1
end

local function getTelemetryUnit(name)
	local field = getFieldInfo(name)
	return (field and field.unit <= 10) and field.unit or 0
end

local rssi, low, crit = getRSSI()
local ver, radio, maj, minor, rev = getVersion()
local tx = string.sub(radio, 0, 2)
local tmp = tx == "x9" and EVT_PLUS_BREAK or (tx == "xl" and EVT_UP_BREAK)
local PREV = tx == "x7" and EVT_ROT_LEFT or tmp
local INCR = tx == "x7" and EVT_ROT_RIGHT or tmp
local tmp = tx == "x9" and EVT_MINUS_BREAK or (tx == "xl" and EVT_DOWN_BREAK)
local NEXT = tx == "x7" and EVT_ROT_RIGHT or tmp
local DECR = tx == "x7" and EVT_ROT_LEFT or tmp
local MENU = tx == "xl" and EVT_SHIFT_BREAK or EVT_MENU_BREAK
local general = getGeneralSettings()
local distanceSensor = getTelemetryId("Dist") > -1 and "Dist" or (getTelemetryId("0420") > -1 and "0420" or "0007")
local data = {
	rssiLow = low,
	rssiCrit = crit,
	txBattMin = general.battMin,
	txBattMax = general.battMax,
	modelName = model.getInfo().name,
	mode_id = getTelemetryId("Tmp1"),
	rxBatt_id = getTelemetryId("RxBt"),
	satellites_id = getTelemetryId("Tmp2"),
	gpsAlt_id = getTelemetryId("GAlt"),
	gpsLatLon_id = getTelemetryId("GPS"),
	heading_id = getTelemetryId("Hdg"),
	altitude_id = getTelemetryId("Alt"),
	distance_id = getTelemetryId(distanceSensor),
	current_id = getTelemetryId("Curr"),
	altitudeMax_id = getTelemetryId("Alt+"),
	distanceMax_id = getTelemetryId(distanceSensor .. "+"),
	currentMax_id = getTelemetryId("Curr+"),
	batt_id = getTelemetryId("VFAS"),
	battMin_id = getTelemetryId("VFAS-"),
	fuel_id = getTelemetryId("Fuel"),
	rssi_id = getTelemetryId("RSSI"),
	rssiMin_id = getTelemetryId("RSSI-"),
	accZ_id = getTelemetryId("AccZ"),
	txBatt_id = getTelemetryId("tx-voltage"),
	gpsAlt_unit = getTelemetryUnit("GAlt"),
	altitude_unit = getTelemetryUnit("Alt"),
	distance_unit = getTelemetryUnit(distanceSensor),
	throttle_id = getTelemetryId("thr"),
	homeResetPrev = false,
	gpsFixPrev = false,
	altNextPlay = 0,
	battNextPlay = 0,
	battPercentPlayed = 100,
	armed = false,
	headFree = false,
	headingHold = false,
	altHold = false,
	telemFlags = -1,
	cells = -1,
	fuel = 100,
	config = 0,
	modeId = 1,
	startup = 1
}

data.showCurr = data.current_id > -1 and true or false
data.showHead = data.heading_id > -1 and true or false
data.pitot = getTelemetryId("ASpd") > -1 and true or false
data.distPos = data.showCurr and 17 or 21
data.speedPos = data.showCurr and 25 or 33
data.battPos1 = data.showCurr and 49 or 45
data.battPos2 = data.showCurr and 49 or 41
data.distRef = data.distance_unit == 10 and 20 or 6
data.altitude_unit = data.altitude_id == -1 and data.gpsAlt_unit or data.altitude_unit
data.distance_unit = data.distance_unit == 0 and 9 or data.distance_unit
data.systemError = maj + minor / 10 < 2.2 and "OpenTX v2.2+ Required" or false

local function reset()
	data.timerStart = 0
	data.timer = 0
	data.distanceLast = 0
	data.gpsHome = false
	data.gpsLatLon = emptyGPS
	data.gpsFix = false
	data.headingRef = -1
	data.battLow = false
	data.showMax = false
	data.showDir = true
	if not data.showCurr then
		data.cells = -1
	end
	data.fuel = 100
	data.config = 0
	data.gpsAltBase = false
end

return data, getTelemetryId, getTelemetryUnit, PREV, INCR, NEXT, DECR, MENU, reset