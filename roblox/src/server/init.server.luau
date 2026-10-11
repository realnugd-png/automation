-- Server bootstrap for Become An Millionaire RNG.
-- Creates remotes, registers every service, then initialises them in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes) -- creates the Remotes folder

local Registry = require(script.Registry)
local Services = script.Services

Registry.RequestService = require(Services.RequestService)
Registry.DataService = require(Services.DataService)
Registry.MonetizationService = require(Services.MonetizationService)
Registry.StatsService = require(Services.StatsService)
Registry.RollService = require(Services.RollService)
Registry.RewardService = require(Services.RewardService)
Registry.LeaderboardService = require(Services.LeaderboardService)
Registry.AvatarService = require(Services.AvatarService)
Registry.TradeService = require(Services.TradeService)
Registry.MapService = require(script.Map.MapService)

local announceRemote = Remotes.event("Announce")
Registry.Announce = function(text: string)
	announceRemote:FireAllClients({ kind = "info", text = text })
end

-- Order matters: requests must exist before services register handlers, and
-- the map should exist before players spawn. DataService starts last so every
-- onLoaded/PlayerAdded hook is connected before the first profile loads.
local ORDER = {
	"MapService",
	"RequestService",
	"MonetizationService",
	"StatsService",
	"RollService",
	"RewardService",
	"LeaderboardService",
	"AvatarService",
	"TradeService",
	"DataService",
}

for _, name in ORDER do
	local ok, err = pcall(Registry[name].init)
	if not ok then
		warn(`[Server] {name} failed to start: {err}`)
	end
end

print("[Become An Millionaire RNG] Server ready")
