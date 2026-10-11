--!strict
-- Compact number formatting: 1234 -> "1.23K", 5e15 -> "5Qa".

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local NumberFormat = {}

function NumberFormat.short(value: number): string
	if value ~= value then
		return "0"
	end
	local negative = value < 0
	value = math.abs(value)
	if value < 1000 then
		local text = tostring(math.floor(value))
		return if negative then "-" .. text else text
	end
	local tier = math.min(math.floor(math.log10(value) / 3), #SUFFIXES - 1)
	local scaled = value / 10 ^ (tier * 3)
	local text
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		text = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		text = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	if text:find(".", 1, true) then
		text = text:gsub("0+$", "")
		text = text:gsub("%.$", "")
	end
	return (if negative then "-" else "") .. text .. SUFFIXES[tier + 1]
end

function NumberFormat.commas(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""):gsub("^%-,", "-"))
end

function NumberFormat.odds(probability: number): string
	if probability <= 0 then
		return "-"
	end
	local oneIn = 1 / probability
	if oneIn < 10 then
		return string.format("1 in %.1f", oneIn)
	end
	return "1 in " .. NumberFormat.short(math.floor(oneIn + 0.5))
end

function NumberFormat.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %02ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

return NumberFormat
