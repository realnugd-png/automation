-- Computes a player's effective stats on the server. The zone bonus is based
-- on where the character actually is (and whether the zone is unlocked), so a
-- client can't claim to be in a better zone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Modules.Formulas)

local Registry = require(script.Parent.Parent.Registry)

local StatsService = {}

function StatsService.zoneFor(player: Player, profile: { [string]: any }): string
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return "Downtown"
	end
	local position = root.Position
	for _, zone in GameConfig.Zones do
		if zone.radius > 0 and profile.zones[zone.id] then
			local offset = position - zone.center
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= zone.radius and math.abs(offset.Y) < 80 then
				return zone.id
			end
		end
	end
	return "Downtown"
end

function StatsService.compute(player: Player): Formulas.Stats?
	local profile = Registry.DataService.get(player)
	if not profile then
		return nil
	end
	return Formulas.computeStats(profile, {
		passes = Registry.MonetizationService.getPasses(player),
		zoneId = StatsService.zoneFor(player, profile),
		now = os.time(),
		serverLuck = Registry.MonetizationService.getServerLuck().mult,
	})
end

function StatsService.init()
	-- Keep each client's zone/luck display current as players move between zones.
	local lastZone: { [Player]: string } = {}
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in game:GetService("Players"):GetPlayers() do
				local profile = Registry.DataService.get(player)
				if profile then
					local zone = StatsService.zoneFor(player, profile)
					if lastZone[player] ~= zone then
						lastZone[player] = zone
						player:SetAttribute("Zone", zone)
						Registry.DataService.changed(player)
					end
				end
			end
			for player in lastZone do
				if player.Parent == nil then
					lastZone[player] = nil
				end
			end
		end
	end)
end

return StatsService
