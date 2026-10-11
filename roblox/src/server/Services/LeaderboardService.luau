-- In-server leaderstats, the live "richest in server" list, and a global
-- all-time leaderboard (lifetime earnings) backed by an OrderedDataStore.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Modules.Formulas)
local NumberFormat = require(Shared.Modules.NumberFormat)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Modules.Remotes)

local Registry = require(script.Parent.Parent.Registry)

local LeaderboardService = {}

local leaderboardRemote = Remotes.event("Leaderboard")
local orderedStore: OrderedDataStore? = nil
local globalEntries: { { userId: number, name: string, value: number } } = {}
local nameCache: { [number]: string } = {}
local pendingUpdate: { [Player]: boolean } = {}

local function getOrderedStore(): OrderedDataStore?
	if orderedStore then
		return orderedStore
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(GameConfig.LeaderboardStoreName)
	end)
	if ok then
		orderedStore = result
		return result
	end
	return nil
end

local function ensureLeaderstats(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = "0"
	cash.Parent = folder
	local best = Instance.new("StringValue")
	best.Name = "Best"
	best.Value = "-"
	best.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder
	folder.Parent = player
end

function LeaderboardService.updatePlayer(player: Player, profile: { [string]: any })
	ensureLeaderstats(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	;(stats:FindFirstChild("Cash") :: StringValue).Value = NumberFormat.short(profile.cash)
	local best = Rarities.list[profile.bestOrder]
	;(stats:FindFirstChild("Best") :: StringValue).Value = if best then best.name else "-"
	;(stats:FindFirstChild("Rebirths") :: IntValue).Value = profile.rebirths
	player:SetAttribute("Cash", profile.cash)
	player:SetAttribute("Lifetime", profile.lifetime)
	player:SetAttribute("Rebirths", profile.rebirths)
	player:SetAttribute("BestOrder", profile.bestOrder)
	player:SetAttribute("Title", Formulas.wealthTitle(profile.lifetime))
	pendingUpdate[player] = true
end

local function serverEntries()
	local entries = {}
	for _, player in Players:GetPlayers() do
		local profile = Registry.DataService.get(player)
		if profile then
			table.insert(entries, {
				userId = player.UserId,
				name = player.DisplayName,
				value = profile.cash,
				lifetime = profile.lifetime,
				rebirths = profile.rebirths,
			})
		end
	end
	table.sort(entries, function(a, b)
		return a.value > b.value
	end)
	return entries
end

local function broadcast()
	local payload = { server = serverEntries(), global = globalEntries }
	leaderboardRemote:FireAllClients(payload)
	Registry.MapService.updateLeaderboardBoards(payload)
end

local function resolveName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok then name else ("Player " .. userId)
	nameCache[userId] = result
	return result
end

local function pushGlobalScores()
	local store = getOrderedStore()
	if not store then
		return
	end
	for _, player in Players:GetPlayers() do
		local profile = Registry.DataService.get(player)
		if profile and not Registry.DataService.isTemporary(player) and profile.lifetime > 0 then
			pcall(function()
				store:SetAsync(tostring(player.UserId), Formulas.encodeLeaderboardValue(profile.lifetime))
			end)
		end
	end
end

local function fetchGlobal()
	local store = getOrderedStore()
	if not store then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, GameConfig.Leaderboard.globalSize)
	end)
	if not ok then
		return
	end
	local entries = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, {
				userId = userId,
				name = resolveName(userId),
				value = Formulas.decodeLeaderboardValue(item.value),
			})
		end
	end
	globalEntries = entries
end

function LeaderboardService.init()
	Registry.DataService.onLoaded(function(player, profile)
		LeaderboardService.updatePlayer(player, profile)
		broadcast()
	end)
	Players.PlayerRemoving:Connect(function(player)
		pendingUpdate[player] = nil
		task.defer(broadcast)
	end)

	Registry.RequestService.register("GetLeaderboard", function()
		return { ok = true, data = { server = serverEntries(), global = globalEntries } }
	end, 2)

	-- Live server leaderboard: refresh a few times per minute when values change.
	task.spawn(function()
		while true do
			task.wait(3)
			if next(pendingUpdate) then
				table.clear(pendingUpdate)
				broadcast()
			end
		end
	end)

	-- Global leaderboard: write scores, then read the top list.
	task.spawn(function()
		task.wait(10)
		while true do
			pushGlobalScores()
			fetchGlobal()
			broadcast()
			task.wait(GameConfig.Leaderboard.globalRefreshSeconds)
		end
	end)
end

return LeaderboardService
