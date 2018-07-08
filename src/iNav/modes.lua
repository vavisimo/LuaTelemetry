local FLASH = ...

-- Modes: t=text / f=flags for text / w=wave file
local modes = {
	{ t = "NO TELEM",  f = FLASH },
	{ t = "HORIZON",   f = 0, w = "hrznmd" },
	{ t = "  ANGLE",   f = 0, w = "anglmd" },
	{ t = "   ACRO",   f = 0, w = "acromd" },
	{ t = " NOT OK ",  f = FLASH },
	{ t = "  READY",   f = 0, w = "ready" },
	{ t = "POS HOLD",  f = 0, w = "poshld" },
	{ t = "3D HOLD",   f = 0, w = "3dhold" },
	{ t = "WAYPOINT",  f = 0, w = "waypt" },
	{ t = " MANUAL",   f = 0, w = "manmd" },
	{ t = "   RTH   ", f = FLASH, w = "rtl" },
	{ t = "FAILSAFE",  f = FLASH, w = "fson" },
	{ t = "THR WARN",  f = FLASH }
}
local units = { [0] = "", "V", "A", "mA", "kts", "m/s", "f/s", "km/h", "MPH", "m", "'" }

local emptyGPS = { lat = 0, lon = 0 }

return modes, units, emptyGPS