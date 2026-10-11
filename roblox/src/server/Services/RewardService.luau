-- Daily login, daily boost, playtime, codes, quests, achievements (+ badges),
-- roll milestones and offline earnings.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Modules.Formulas)
local NumberFormat = require(Shared.Modules.NumberFormat)
local Upgrades = require(Shared.Config.Upgrades)

local Registry = require(script.Parent.Parent.Registry)
local Economy = require(script.Parent.Parent.Logic.Economy)
local Daily = require(script.Parent.Parent.Logic.Daily)
local Quests = require(script.Parent.Parent.Logic.Quests)
local Codes = require(script.Parent.Parent.Config.Codes)

local RewardService = {}

local function awardBadge(player: Player, badgeId: number)
	if badgeId == 0 then
		return
	end
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
		if ok and not has then
			pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
		end
	end)
end

-- Called after anything that can complete achievements/milestones.
function RewardService.checkProgress(player: Player, profile: { [string]: any }, now: number)
	for _, earned in Quests.checkAchievements(profile, now) do
		Registry.DataService.notify(player, `Achievement: {earned.achievement.name}! {earned.text}`, "achievement")
		awardBadge(player, earned.achievement.badgeId)
	end
	for _, message in Quests.checkMilestones(profile, now) do
		Registry.DataService.notify(player, message, "success")
	end
end

-- Wraps a pure (profile, ...) -> (ok, message) action as a request handler.
local function action(fn: (profile: { [string]: any }, ...any) -> (boolean, string))
	return function(player: Player, ...)
		local profile = Registry.DataService.get(player)
		if not profile then
			return { ok = false, message = "Still loading" }
		end
		local ok, message = fn(profile, ...)
		if ok then
			RewardService.checkProgress(player, profile, os.time())
			Registry.DataService.changed(player)
			Registry.LeaderboardService.updatePlayer(player, profile)
		end
		return { ok = ok, message = message }
	end
end

local function grantOffline(player: Player, profile: { [string]: any })
	local now = os.time()
	if profile.lastOnline > 0 then
		local seconds = now - profile.lastOnline
		local cash = Formulas.offlineCash(profile.upgrades.Offline or 0, profile.bestOrder, seconds)
		if cash > 0 then
			Economy.addCash(profile, cash)
			Registry.DataService.notify(
				player,
				`Welcome back! Passive income earned ${NumberFormat.short(cash)} while you were away ({NumberFormat.duration(seconds)}).`,
				"success"
			)
		end
	end
	profile.lastOnline = now
end

function RewardService.init()
	local Request = Registry.RequestService

	Request.register("ClaimDaily", action(function(profile)
		return Daily.claimLogin(profile, os.time())
	end), 1)

	Request.register("ClaimDailyBoost", action(function(profile)
		return Daily.claimBoost(profile, os.time())
	end), 1)

	Request.register("ClaimPlaytime", action(function(profile, index)
		return Daily.claimPlaytime(profile, index, os.time())
	end), 0.5)

	Request.register("ClaimQuest", action(function(profile, index)
		return Quests.claimDaily(profile, index, os.time())
	end), 0.5)

	Request.register("ClaimRepeatable", action(function(profile, id)
		return Quests.claimRepeatable(profile, id, os.time())
	end), 0.5)

	Request.register("RedeemCode", action(function(profile, code)
		return Economy.redeemCode(profile, code, Codes, os.time())
	end), 2)

	Request.register("BuyUpgrade", function(player, upgradeId)
		local profile = Registry.DataService.get(player)
		if not profile then
			return { ok = false, message = "Still loading" }
		end
		local ok, message = Economy.buyUpgrade(profile, upgradeId)
		if ok then
			Quests.progress(profile, "upgrades", 1)
			RewardService.checkProgress(player, profile, os.time())
			Registry.DataService.changed(player)
			Registry.LeaderboardService.updatePlayer(player, profile)
		end
		return { ok = ok, message = message }
	end, 0.1)

	Request.register("BuyUpgradeMax", function(player, upgradeId)
		local profile = Registry.DataService.get(player)
		if not profile or type(upgradeId) ~= "string" or not Upgrades.byId[upgradeId] then
			return { ok = false, message = "Invalid" }
		end
		local bought = 0
		while bought < 100 and Economy.buyUpgrade(profile, upgradeId) do
			bought += 1
		end
		if bought == 0 then
			return { ok = false, message = "Not enough cash" }
		end
		Quests.progress(profile, "upgrades", bought)
		RewardService.checkProgress(player, profile, os.time())
		Registry.DataService.changed(player)
		Registry.LeaderboardService.updatePlayer(player, profile)
		return { ok = true, message = `Bought {bought} level(s)` }
	end, 0.5)

	Request.register("Rebirth", function(player)
		local profile = Registry.DataService.get(player)
		if not profile then
			return { ok = false, message = "Still loading" }
		end
		local ok, message = Economy.rebirth(profile)
		if ok then
			RewardService.checkProgress(player, profile, os.time())
			Registry.DataService.changed(player)
			Registry.LeaderboardService.updatePlayer(player, profile)
			Registry.AvatarService.refresh(player)
			Registry.Announce(`{player.DisplayName} reached Rebirth {profile.rebirths}!`)
			task.spawn(Registry.DataService.save, player, false)
		end
		return { ok = ok, message = message }
	end, 1)

	Request.register("UnlockZone", action(function(profile, zoneId)
		return Economy.unlockZone(profile, zoneId)
	end), 0.5)

	Request.register("SetSetting", action(function(profile, key, value)
		return Economy.setSetting(profile, key, value)
	end), 0.1)

	Request.register("EquipAura", function(player, auraId)
		local profile = Registry.DataService.get(player)
		if not profile then
			return { ok = false, message = "Still loading" }
		end
		local ok, message = Economy.equipAura(profile, auraId, Registry.MonetizationService.hasPass(player, "VIP"))
		if ok then
			Registry.AvatarService.refresh(player)
			Registry.DataService.changed(player)
		end
		return { ok = ok, message = message }
	end, 0.3)

	Registry.DataService.onLoaded(function(player, profile)
		local now = os.time()
		grantOffline(player, profile)
		Quests.ensureDaily(profile, now)
		Quests.ensureRepeatable(profile)
		Economy.pruneBoosts(profile, now)
		RewardService.checkProgress(player, profile, now)
		if Daily.canClaimLogin(profile, now) then
			Registry.DataService.notify(player, "Your daily reward is ready! Open the Daily menu.", "info")
		end
		Registry.DataService.changed(player)
	end)

	-- Playtime tracking, daily quest rollover and boost expiry.
	task.spawn(function()
		local lastTick = os.clock()
		local minuteCounter: { [Player]: number } = {}
		while true do
			task.wait(5)
			local elapsed = os.clock() - lastTick
			lastTick = os.clock()
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local profile = Registry.DataService.get(player)
				if profile then
					Daily.addPlaytime(profile, now, elapsed)
					minuteCounter[player] = (minuteCounter[player] or 0) + elapsed
					local changed = false
					if minuteCounter[player] >= 60 then
						minuteCounter[player] -= 60
						Quests.progress(profile, "playMinutes", 1)
						changed = true
					end
					if Quests.ensureDaily(profile, now) then
						Registry.DataService.notify(player, "New daily quests are available!", "info")
						changed = true
					end
					local hadBoosts = next(profile.boosts) ~= nil
					Economy.pruneBoosts(profile, now)
					if hadBoosts and next(profile.boosts) == nil then
						changed = true
					end
					if changed then
						Registry.DataService.changed(player)
					end
				end
			end
			for player in minuteCounter do
				if player.Parent == nil then
					minuteCounter[player] = nil
				end
			end
		end
	end)
end

return RewardService
