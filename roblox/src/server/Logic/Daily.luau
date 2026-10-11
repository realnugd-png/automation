--!strict
-- Daily login streak, daily luck boost and playtime rewards.
-- All timing uses the server clock (os.time) and UTC day numbers that are
-- saved in the profile, so reconnecting or changing the client clock cannot
-- grant a reward twice.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Modules.Formulas)
local Economy = require(script.Parent.Economy)

type Profile = { [string]: any }

local Daily = {}

function Daily.canClaimLogin(profile: Profile, now: number): boolean
	return profile.daily.lastLoginDay < Formulas.dayNumber(now)
end

-- Reward slot (1-based) for today's claim, or the slot already claimed today.
function Daily.loginIndex(profile: Profile, now: number): number
	local today = Formulas.dayNumber(now)
	local last = profile.daily.lastLoginDay
	local streak = if last == today
		then profile.daily.streak
		elseif last == today - 1 then profile.daily.streak + 1
		else 1
	return ((streak - 1) % #GameConfig.DailyLogin) + 1
end

function Daily.claimLogin(profile: Profile, now: number): (boolean, string)
	local today = Formulas.dayNumber(now)
	local daily = profile.daily
	if daily.lastLoginDay >= today then
		return false, "Already claimed today. Come back tomorrow!"
	end
	if daily.lastLoginDay == today - 1 then
		daily.streak += 1
	else
		daily.streak = 1
	end
	daily.lastLoginDay = today
	local reward = GameConfig.DailyLogin[((daily.streak - 1) % #GameConfig.DailyLogin) + 1]
	return true, `Day {daily.streak} reward: ` .. Economy.grant(profile, reward, "daily", now)
end

function Daily.claimBoost(profile: Profile, now: number): (boolean, string)
	local today = Formulas.dayNumber(now)
	if profile.daily.boostDay >= today then
		return false, "Daily luck boost already used today"
	end
	profile.daily.boostDay = today
	local boost = GameConfig.DailyLuckBoost
	Economy.addBoost(profile, "dailyBoost", boost.mult, boost.minutes, now)
	return true, `{boost.mult}x Luck for {boost.minutes} minutes!`
end

local function rollPlayDay(profile: Profile, now: number)
	local today = Formulas.dayNumber(now)
	if profile.daily.playDay ~= today then
		profile.daily.playDay = today
		profile.daily.playSeconds = 0
		profile.daily.playClaimed = {}
	end
end

function Daily.addPlaytime(profile: Profile, now: number, seconds: number)
	rollPlayDay(profile, now)
	seconds = math.clamp(seconds, 0, 10) -- a single tick can never add more than 10s
	profile.daily.playSeconds += seconds
	profile.stats.playSeconds += seconds
end

function Daily.claimPlaytime(profile: Profile, index: any, now: number): (boolean, string)
	rollPlayDay(profile, now)
	if type(index) ~= "number" or index % 1 ~= 0 then
		return false, "Invalid reward"
	end
	local tier = GameConfig.PlaytimeRewards[index]
	if not tier then
		return false, "Invalid reward"
	end
	local key = tostring(index)
	if profile.daily.playClaimed[key] then
		return false, "Already claimed today"
	end
	if profile.daily.playSeconds < tier.minutes * 60 then
		return false, "Keep playing to unlock this reward"
	end
	profile.daily.playClaimed[key] = true
	return true, "Playtime reward: " .. Economy.grant(profile, tier.reward, "playtime", now)
end

return Daily
