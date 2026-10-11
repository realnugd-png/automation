-- Manual and auto rolling. The server owns the cooldown, the luck value and
-- the random generator; the client only asks "roll please".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Modules.Remotes)
local NumberFormat = require(Shared.Modules.NumberFormat)

local Registry = require(script.Parent.Parent.Registry)
local Roll = require(script.Parent.Parent.Logic.Roll)
local Quests = require(script.Parent.Parent.Logic.Quests)

local RollService = {}

local random = Random.new()
local function nextNumber(): number
	return random:NextNumber()
end

local lastRoll: { [Player]: number } = {}
local autoRolling: { [Player]: true } = {}
local resultRemote = Remotes.event("RollResult")
local announceRemote = Remotes.event("Announce")

function RollService.isAutoRolling(player: Player): boolean
	return autoRolling[player] == true
end

local function doRoll(player: Player, auto: boolean): (boolean, string?)
	local profile = Registry.DataService.get(player)
	local stats = Registry.StatsService.compute(player)
	if not profile or not stats then
		return false, "Still loading"
	end
	local now = os.clock()
	local last = lastRoll[player]
	if last and now - last < stats.cooldown - GameConfig.Roll.latencyTolerance then
		return false, nil -- silently ignore early clicks
	end
	lastRoll[player] = now

	local outcome = Roll.perform(profile, stats, nextNumber)
	local timestamp = os.time()

	-- Quest progress
	Quests.progress(profile, "rolls", outcome.rollsDone)
	Quests.progress(profile, "earn", outcome.total)
	for _, single in outcome.results do
		local rarity = Rarities.byId[single.id]
		Quests.progress(profile, "rarityAtLeast", 1, rarity.order)
	end

	resultRemote:FireClient(player, {
		results = outcome.results,
		best = outcome.best,
		bestCash = outcome.bestCash,
		total = outcome.total,
		newDiscoveries = outcome.newDiscoveries,
		cooldown = stats.cooldown,
		luck = stats.luck,
		auto = auto,
	})

	local best = Rarities.byId[outcome.best]
	if best.announce then
		announceRemote:FireAllClients({
			kind = "roll",
			userId = player.UserId,
			name = player.DisplayName,
			rarity = best.id,
			cash = outcome.bestCash,
			text = `{player.DisplayName} rolled {best.name} for ${NumberFormat.short(outcome.bestCash)}!`,
		})
	end

	Registry.RewardService.checkProgress(player, profile, timestamp)
	Registry.LeaderboardService.updatePlayer(player, profile)
	-- Auto-equip a newly discovered aura if it beats the equipped one.
	if best.hasAura and table.find(outcome.newDiscoveries, best.id) then
		local equipped = Rarities.byId[profile.equippedAura]
		if profile.equippedAura == "" or (equipped and equipped.order < best.order) then
			profile.equippedAura = best.id
			Registry.AvatarService.refresh(player)
		end
	end
	Registry.DataService.changed(player)
	return true, nil
end

function RollService.init()
	Registry.RequestService.register("Roll", function(player)
		local ok, message = doRoll(player, false)
		return { ok = ok, message = message }
	end, 0.1)

	Registry.RequestService.register("SetAutoRoll", function(player, enabled)
		if type(enabled) ~= "boolean" then
			return { ok = false, message = "Invalid" }
		end
		if enabled then
			local stats = Registry.StatsService.compute(player)
			if not stats or not stats.autoRollUnlocked then
				return { ok = false, message = `Auto-roll unlocks at {GameConfig.Roll.autoRollUnlockRolls} rolls (or with the Auto-Roll pass)` }
			end
		end
		if enabled then
			autoRolling[player] = true
		else
			autoRolling[player] = nil
		end
		Registry.DataService.changed(player)
		return { ok = true }
	end, 0.3)

	Players.PlayerRemoving:Connect(function(player)
		autoRolling[player] = nil
		lastRoll[player] = nil
	end)

	-- Auto-roll loop: rolls for each opted-in player as soon as their cooldown allows.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.05 then
			return
		end
		accumulator = 0
		for player in autoRolling do
			local stats = Registry.StatsService.compute(player)
			local last = lastRoll[player]
			if stats and (not last or os.clock() - last >= stats.cooldown) then
				task.spawn(doRoll, player, true)
			end
		end
	end)
end

return RollService
