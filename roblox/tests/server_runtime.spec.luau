-- Boots the real server (all services + map) against an in-memory
-- DataStore, fake Marketplace and fake players, then plays through joins,
-- rolls, exploits, rewards, saving, rejoining, purchases, trades and
-- shutdown.

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local H = require("./harness")
local Runtime = require("./runtime")

print("Server integration tests")
Runtime.install()

------------------------------------------------------------------------------
-- Fakes
------------------------------------------------------------------------------

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- In-memory DataStore with UpdateAsync semantics and failure injection.
local storeData: { [string]: any } = {}
local storeFailures = 0
local storeFailMessage = "502: DataStore request failed"
local writes = 0
local fakeStore = {
	UpdateAsync = function(_, key, transform)
		if storeFailures > 0 then
			storeFailures -= 1
			error(storeFailMessage)
		end
		local result = transform(deepCopy(storeData[key]))
		if result ~= nil then
			storeData[key] = deepCopy(result)
			writes += 1
		end
		return result
	end,
}
local ordered = {}
local fakeOrdered = {
	SetAsync = function(_, key, value)
		ordered[key] = value
	end,
	GetSortedAsync = function(_, _, size)
		local list = {}
		for key, value in ordered do
			table.insert(list, { key = key, value = value })
		end
		table.sort(list, function(a, b)
			return a.value > b.value
		end)
		return { GetCurrentPage = function()
			return { table.unpack(list, 1, math.min(size, #list)) }
		end }
	end,
}

local prompts = {}
local marketplace = {
	PromptGamePassPurchaseFinished = Runtime.newSignal(),
	UserOwnsGamePassAsync = function()
		return false
	end,
	PromptGamePassPurchase = function(_, player, id)
		table.insert(prompts, { "pass", id })
	end,
	PromptProductPurchase = function(_, player, id)
		table.insert(prompts, { "product", id })
	end,
}

local isStudio = false
local bindToClose = {}
local heartbeat = Runtime.newSignal()

-- Fake server remotes: record everything sent to clients.
local sent: { { remote: string, player: any, payload: any } } = {}
local remoteFunctions = {}
local function serverRemote(name)
	return {
		FireClient = function(_, player, payload)
			table.insert(sent, { remote = name, player = player, payload = payload })
		end,
		FireAllClients = function(_, payload)
			table.insert(sent, { remote = name, player = "all", payload = payload })
		end,
	}
end
local remoteEvents = {}
local FakeRemotes = {
	event = function(name)
		remoteEvents[name] = remoteEvents[name] or serverRemote(name)
		return remoteEvents[name]
	end,
	func = function(name)
		remoteFunctions[name] = remoteFunctions[name] or {}
		return remoteFunctions[name]
	end,
}

local rt = Runtime.create({
	isServer = true,
	stubs = {
		DataStoreService = {
			GetDataStore = function()
				return fakeStore
			end,
			GetOrderedDataStore = function()
				return fakeOrdered
			end,
		},
		MarketplaceService = marketplace,
		BadgeService = {
			UserHasBadgeAsync = function()
				return false
			end,
			AwardBadge = function() end,
		},
		RunService = {
			IsServer = function()
				return true
			end,
			IsStudio = function()
				return isStudio
			end,
			Heartbeat = heartbeat,
		},
	},
})
rt.game.BindToClose = function(_, fn)
	table.insert(bindToClose, fn)
end
H.preload("src/shared/Modules/Remotes", FakeRemotes)

-- Real Player instances parented to the real Players service.
local Players = rt.dm:GetService("Players")
-- Lune creates a new userdata per lookup; Roblox keeps identity stable, so
-- hand back the exact objects that joined.
local joined: { [number]: any } = {}
roblox.implementMethod("Players", "GetPlayers", function()
	local list = {}
	for _, player in joined do
		if player.Parent ~= nil then
			table.insert(list, player)
		end
	end
	return list
end)
roblox.implementMethod("Players", "GetPlayerByUserId", function(_, id)
	local player = joined[id]
	return if player and player.Parent ~= nil then player else nil
end)
roblox.implementMethod("Players", "GetPlayerFromCharacter", function()
	return nil
end)
roblox.implementMethod("Players", "GetNameFromUserIdAsync", function(_, id)
	return "User" .. id
end)
local kicks: { [number]: string } = {}
roblox.implementMethod("Player", "Kick", function(self, message)
	kicks[self.UserId] = message
	self.Parent = nil
end)
for _, event in { "CharacterAdded" } do
	roblox.implementProperty("Player", event, function()
		return Runtime.newSignal()
	end)
end

local function join(userId: number, name: string)
	local player = roblox.Instance.new("Player")
	player.UserId = userId
	player.Name = name
	player.DisplayName = name
	player.Parent = Players
	joined[userId] = player
	Runtime.signalOf(Players, "PlayerAdded"):Fire(player)
	return player
end

local function leave(player)
	player.Parent = nil
	Runtime.signalOf(Players, "PlayerRemoving"):Fire(player)
end

local function request(player, action, ...)
	return remoteFunctions.Request.OnServerInvoke(player, action, ...)
end

local function sentTo(player, remote)
	local list = {}
	for _, entry in sent do
		if entry.remote == remote and (entry.player == player or entry.player == "all") then
			table.insert(list, entry.payload)
		end
	end
	return list
end

------------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------------

H.test("server boots (all services + map)", function()
	H.require("src/server")
end)

local Registry = H.require("src/server/Registry")
local DataService = Registry.DataService
DataService.config.lockedRetryDelay = 0.05
DataService.config.errorRetryDelay = 0.01
DataService.config.saveRetryDelay = 0.01
local Monetization = H.require("src/shared/Config/Monetization")

local alice

H.test("player joins and gets a fresh profile + snapshot", function()
	alice = join(1001, "Alice")
	task.wait(0.2)
	local profile = DataService.get(alice)
	H.expect(profile ~= nil, "profile not loaded")
	H.expect(profile.cash == 0 and profile.version == 1)
	H.expect(#sentTo(alice, "State") >= 1, "no state snapshot sent")
	H.expect(storeData.u_1001 ~= nil and storeData.u_1001.lock ~= nil, "session lock not written")
	H.expect(alice:FindFirstChild("leaderstats") ~= nil, "leaderstats missing")
	local quests = profile.quests.daily.list
	H.expect(#quests == 3, "daily quests not issued")
end)

H.test("rolling works and the server enforces the cooldown", function()
	local profile = DataService.get(alice)
	local first = request(alice, "Roll")
	H.expect(first.ok, "first roll failed: " .. tostring(first.message))
	H.expect(profile.totalRolls == 1 and profile.cash > 0, "roll didn't grant")
	H.expect(#sentTo(alice, "RollResult") == 1)
	task.wait(0.15)
	local spam = request(alice, "Roll")
	H.expect(not spam.ok and profile.totalRolls == 1, "cooldown bypassed")
	task.wait(1.6)
	H.expect(request(alice, "Roll").ok and profile.totalRolls == 2, "roll after cooldown failed")
end)

H.test("client cannot pass its own luck, cash or results", function()
	local profile = DataService.get(alice)
	task.wait(1.6)
	local cashBefore = profile.cash
	-- Extra arguments are ignored by the Roll handler.
	request(alice, "Roll", { luck = 1e9, cash = 1e18, rarity = "CelestialFortune" })
	H.expect(profile.cash - cashBefore < 1e6, "client influenced the reward")
end)

H.test("malformed and unknown requests are rejected safely", function()
	local profile = DataService.get(alice)
	H.expect(not request(alice, 12345).ok)
	H.expect(not request(alice, "GiveMeMoney").ok)
	H.expect(not request(alice, "BuyUpgrade", { "Luck" }).ok)
	H.expect(not request(alice, "SetSetting", "cash", true).ok)
	H.expect(not request(alice, "UnlockZone", "CelestialHeights").ok)
	H.expect(not request(alice, "EquipAura", "CelestialFortune").ok)
	H.expect(not request(alice, "ClaimPlaytime", 1).ok, "playtime claimed without playing")
	H.expect(profile.cash < 1e6)
end)

H.test("remote spam is rate limited", function()
	task.wait(1.1)
	local limited = 0
	for _ = 1, 40 do
		local result = request(alice, "SetSetting", "sounds", true)
		if result.message == "Slow down!" then
			limited += 1
		end
	end
	H.expect(limited > 10, "no rate limiting (" .. limited .. ")")
end)

H.test("upgrades and zones spend cash correctly", function()
	task.wait(1.1)
	local profile = DataService.get(alice)
	profile.cash = 1e6
	H.expect(request(alice, "BuyUpgrade", "Luck").ok)
	H.expect(profile.upgrades.Luck == 1 and profile.cash == 1e6 - 150)
	task.wait(0.6)
	H.expect(request(alice, "UnlockZone", "LuxuryHills").ok and profile.zones.LuxuryHills)
	task.wait(0.6)
	H.expect(request(alice, "BuyUpgradeMax", "Cash").ok and profile.upgrades.Cash > 1)
end)

H.test("rebirth applies and keeps the collection", function()
	task.wait(1.1)
	local profile = DataService.get(alice)
	profile.cash = 1e6
	profile.inventory.Rich = 2
	H.expect(request(alice, "Rebirth").ok)
	H.expect(profile.rebirths == 1 and profile.cash == 0 and profile.upgrades.Luck == 0 and profile.inventory.Rich == 2)
	local stats = Registry.StatsService.compute(alice)
	H.expect(math.abs(stats.cashMultiplier - 1.5) < 1e-9, "rebirth bonus not applied")
end)

H.test("daily reward survives a rejoin and can't be claimed twice", function()
	task.wait(1.1)
	H.expect(request(alice, "ClaimDaily").ok)
	task.wait(1.1)
	H.expect(not request(alice, "ClaimDaily").ok, "claimed twice in a session")
	local cash = DataService.get(alice).cash
	leave(alice)
	task.wait(0.2)
	H.expect(storeData.u_1001.lock == nil, "lock not released on leave")
	H.expect(storeData.u_1001.data.cash == cash, "cash not saved")
	alice = join(1001, "Alice")
	task.wait(0.2)
	H.expect(DataService.get(alice).cash == cash, "cash not loaded")
	H.expect(not request(alice, "ClaimDaily").ok, "daily claimable again after rejoin")
end)

H.test("session lock held by another server blocks the join without writing", function()
	storeData.u_2002 = { data = { version = 1, cash = 777 }, lock = { job = "other-server", time = os.time() } }
	local before = deepCopy(storeData.u_2002)
	local bob = join(2002, "Bob")
	task.wait(1)
	H.expect(kicks[2002] ~= nil, "player with locked data was not kicked")
	H.expect(DataService.get(bob) == nil)
	H.expect(storeData.u_2002.data.cash == before.data.cash and storeData.u_2002.lock.job == "other-server", "locked data was modified")
end)

H.test("a stale lock is taken over", function()
	storeData.u_3003 = { data = { version = 1, cash = 555 }, lock = { job = "dead-server", time = os.time() - 3600 } }
	local carol = join(3003, "Carol")
	task.wait(0.2)
	H.expect(DataService.get(carol) ~= nil and DataService.get(carol).cash == 555)
end)

H.test("DataStore outage kicks instead of overwriting (live servers)", function()
	storeData.u_4004 = { data = { version = 1, cash = 999999 } }
	storeFailures = 100
	local dave = join(4004, "Dave")
	task.wait(1.5)
	storeFailures = 0
	H.expect(kicks[4004] ~= nil, "not kicked during outage")
	H.expect(storeData.u_4004.data.cash == 999999, "data overwritten during outage")
	H.expect(DataService.get(dave) == nil)
end)

H.test("Studio without API access uses a temporary, never-saved profile", function()
	isStudio = true
	storeFailures = 100
	storeFailMessage = "403: Studio access to API services is not enabled"
	local erin = join(5005, "Erin")
	task.wait(0.3)
	H.expect(DataService.get(erin) ~= nil and DataService.isTemporary(erin))
	local writesBefore = writes
	DataService.save(erin, true)
	H.expect(writes == writesBefore, "temporary profile was saved")
	storeFailures = 0
	isStudio = false
	leave(erin)
end)

H.test("developer product receipts are granted exactly once", function()
	local product = Monetization.ProductByKey.Luck15
	product.id = 999
	Monetization.ProductById[999] = product
	local profile = DataService.get(alice)
	local receipt = { PlayerId = 1001, ProductId = 999, PurchaseId = "purchase-1" }
	local process = marketplace.ProcessReceipt
	H.expect(process ~= nil, "ProcessReceipt not set")
	H.expect(process(receipt) == roblox.Enum.ProductPurchaseDecision.PurchaseGranted)
	local expires = profile.boosts.product.expires
	H.expect(process(receipt) == roblox.Enum.ProductPurchaseDecision.PurchaseGranted, "retry should still acknowledge")
	H.expect(profile.boosts.product.expires == expires, "receipt granted twice")
	H.expect(table.find(storeData.u_1001.data.receipts, "purchase-1") ~= nil, "receipt not saved before granting")
	H.expect(process({ PlayerId = 424242, ProductId = 999, PurchaseId = "x" }) == roblox.Enum.ProductPurchaseDecision.NotProcessedYet)
	H.expect(process({ PlayerId = 1001, ProductId = 1, PurchaseId = "y" }) == roblox.Enum.ProductPurchaseDecision.NotProcessedYet)
end)

H.test("unconfigured passes/products are refused, configured ones prompt Roblox", function()
	task.wait(1.1)
	H.expect(not request(alice, "BuyPass", "VIP").ok, "VIP has no id and must not be purchasable")
	H.expect(#prompts == 0)
	task.wait(1.1)
	H.expect(request(alice, "BuyProduct", "Luck15").ok and #prompts == 1 and prompts[1][2] == 999)
end)

H.test("secure trade swaps auras once and rejects stale accepts", function()
	local carol = Players:GetPlayerByUserId(3003)
	local a, c = DataService.get(alice), DataService.get(carol)
	a.inventory = { Rich = 2 }
	c.inventory = { Millionaire = 1 }
	task.wait(1.1)
	H.expect(request(alice, "TradeRequest", 3003).ok)
	H.expect(request(carol, "TradeRespond", 1001, true).ok)
	H.expect(not request(alice, "TradeSetOffer", { Rich = 5 }).ok, "offered more than owned")
	task.wait(0.25)
	H.expect(request(alice, "TradeSetOffer", { Rich = 2 }).ok)
	H.expect(request(carol, "TradeSetOffer", { Millionaire = 1 }).ok)
	local updates = sentTo(alice, "Trade")
	local version = updates[#updates].version
	H.expect(not request(alice, "TradeAccept", version - 1).ok, "stale version accepted")
	task.wait(0.35)
	H.expect(request(alice, "TradeAccept", version).ok)
	H.expect(request(carol, "TradeAccept", version).ok)
	H.expect(a.inventory.Rich == nil and a.inventory.Millionaire == 1, "alice inventory wrong")
	H.expect(c.inventory.Rich == 2 and c.inventory.Millionaire == nil, "carol inventory wrong")
	task.wait(0.35)
	H.expect(not request(alice, "TradeAccept", version).ok, "trade executed twice")
end)

H.test("auto-roll is locked early, then rolls on the server loop", function()
	local profile = DataService.get(alice)
	profile.totalRolls = 10
	task.wait(0.35)
	H.expect(not request(alice, "SetAutoRoll", true).ok, "auto-roll before unlock")
	profile.totalRolls = 800
	task.wait(0.35)
	H.expect(request(alice, "SetAutoRoll", true).ok)
	local before = profile.totalRolls
	for _ = 1, 50 do
		heartbeat:Fire(0.1)
		task.wait(0.1)
	end
	H.expect(profile.totalRolls > before + 1, "auto-roll did not roll")
	task.wait(0.35)
	request(alice, "SetAutoRoll", false)
end)

H.test("rare rolls announce to everyone", function()
	local announces = 0
	for _, entry in sent do
		if entry.remote == "Announce" and entry.player == "all" then
			announces += 1
		end
	end
	H.expect(announces >= 1, "rebirth/roll announcements missing")
end)

H.test("BindToClose saves everyone and releases locks", function()
	H.expect(#bindToClose == 1, "BindToClose not registered")
	DataService.get(alice).cash = 4242
	bindToClose[1]()
	H.expect(storeData.u_1001.data.cash == 4242 and storeData.u_1001.lock == nil)
	H.expect(storeData.u_3003.lock == nil)
end)

local ok = H.summary()
process.exit(if ok then 0 else 1)
