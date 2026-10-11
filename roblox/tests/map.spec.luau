-- Executes the real MapService against Lune's Roblox instance model, which
-- validates every property name/type, then checks the world's structure.
local H = require("./harness")
local Runtime = require("./runtime")

print("Map build tests")

Runtime.install()
local rt = Runtime.create({ isServer = true })
local Registry = H.require("src/server/Registry")
local registered = {}
Registry.RequestService = { register = function(name, fn) registered[name] = fn end }
local notifications = {}
local profiles = {}
Registry.DataService = {
	get = function(player) return profiles[player] end,
	notify = function(player, text) table.insert(notifications, text) end,
}

-- Simulate a Blender-imported "Lamp" in ServerStorage.Models.
local roblox = require("@lune/roblox")
roblox.implementMethod("Model", "GetBoundingBox", function()
	return roblox.CFrame.new(), roblox.Vector3.new(2, 12, 2)
end)
roblox.implementMethod("Model", "PivotTo", function() end)
roblox.implementMethod("Model", "GetScale", function()
	return 1
end)
roblox.implementMethod("Model", "ScaleTo", function() end)
local models = roblox.Instance.new("Folder")
models.Name = "Models"
models.Parent = rt.dm:GetService("ServerStorage")
local importedLamp = roblox.Instance.new("Model")
importedLamp.Name = "Lamp"
importedLamp.Parent = models
local mesh = roblox.Instance.new("Part") -- stands in for a MeshPart
mesh.Name = "Gold_Pole"
mesh.Anchored = false
mesh.Parent = importedLamp

local MapService = H.require("src/server/Map/MapService")
local GameConfig = H.require("src/shared/Config/GameConfig")

H.test("map builds without runtime errors", function()
	MapService.init()
end)

local map = rt.workspace:FindFirstChild("Map")

H.test("map exists with every area", function()
	H.expect(map ~= nil, "Map model missing")
	for _, name in { "SpawnPlaza", "GoldenBank", "NeonStrip", "LuxuryMansion", "LeaderboardPlaza", "PortalHall", "Roads" } do
		H.expect(map:FindFirstChild(name) ~= nil, name .. " missing")
	end
	local bank = map:FindFirstChild("GoldenBank")
	H.expect(bank:FindFirstChild("VaultRoom") ~= nil, "vault room missing")
end)

H.test("one island and one portal per unlockable zone", function()
	for _, zone in GameConfig.Zones do
		if zone.radius > 0 then
			H.expect(map:FindFirstChild("Zone_" .. zone.id) ~= nil, "island " .. zone.id)
			H.expect(map.PortalHall:FindFirstChild("Portal_" .. zone.id) ~= nil, "portal " .. zone.id)
		end
	end
end)

H.test("spawns sit on the plaza", function()
	local spawns = Runtime.descendants(map, "SpawnLocation")
	H.expect(#spawns == 4, "expected 4 spawns, got " .. #spawns)
	for _, spawn in spawns do
		H.expect(spawn.CFrame.Position.Magnitude < 46, "spawn off plaza")
		H.expect(spawn.Anchored)
	end
end)

H.test("every station prompt opens a real panel", function()
	local valid = { Inventory = true, Upgrades = true, Rebirth = true, Daily = true, Quests = true, Zones = true, Leaderboard = true, Trade = true, Shop = true, Codes = true, Stats = true, Settings = true }
	local prompts = Runtime.descendants(map, "ProximityPrompt")
	local seen = {}
	for _, prompt in prompts do
		local panel = prompt:GetAttribute("OpenPanel")
		H.expect(valid[panel], "prompt opens unknown panel " .. tostring(panel))
		seen[panel] = true
	end
	for _, needed in { "Upgrades", "Rebirth", "Daily", "Codes", "Quests", "Shop", "Inventory", "Trade", "Leaderboard", "Zones" } do
		H.expect(seen[needed], "no station for " .. needed)
	end
end)

H.test("all parts are anchored and the map stays lightweight", function()
	local parts = Runtime.descendants(map, "BasePart")
	for _, part in parts do
		H.expect(part.Anchored, part:GetFullName() .. " not anchored")
	end
	print(string.format("        %d parts, %d lights, %d particle emitters", #parts, #Runtime.descendants(map, "PointLight"), #Runtime.descendants(map, "ParticleEmitter")))
	H.expect(#parts < 1500, "too many parts for mobile: " .. #parts)
	H.expect(#Runtime.descendants(map, "PointLight") < 80, "too many lights")
end)

H.test("zone islands are inside their anti-cheat radius", function()
	for _, zone in GameConfig.Zones do
		if zone.radius > 0 then
			local island = map:FindFirstChild("Zone_" .. zone.id)
			local top = island:FindFirstChild("Top")
			local offset = top.CFrame.Position - zone.center
			H.expect(math.abs(offset.X) < 1 and math.abs(offset.Z) < 1, "island centered")
			H.expect(top.Size.Y / 2 <= zone.radius, "walkable area exceeds zone radius")
		end
	end
end)

H.test("imported Blender props replace fallbacks and get recoloured", function()
	local found = 0
	for _, part in Runtime.descendants(map, "BasePart") do
		if part.Name == "Gold_Pole" then
			found += 1
			H.expect(part.Anchored, "imported part not anchored")
			H.expect(part.Material == roblox.Enum.Material.Foil, "palette material not applied")
		end
	end
	H.expect(found > 10, "imported lamps not used (" .. found .. ")")
	for _, model in Runtime.descendants(map, "Model") do
		if model.Name == "Lamp" then
			H.expect(model:FindFirstChild("Pole") == nil, "fallback lamp built despite import")
		end
	end
end)

H.test("leaderboard boards render entries", function()
	MapService.updateLeaderboardBoards({
		server = { { name = "Alice", value = 1234567, userId = 1 }, { name = "Bob", value = 99, userId = 2 } },
		global = {},
	})
	local server = map.LeaderboardPlaza.ServerBoard
	local labels = Runtime.descendants(server, "TextLabel")
	local found = false
	for _, label in labels do
		if label.Text:find("Alice") and label.Text:find("1.23M") then
			found = true
		end
	end
	H.expect(found, "Alice row missing")
	local global = Runtime.descendants(map.LeaderboardPlaza.GlobalBoard, "TextLabel")
	local loading = false
	for _, label in global do
		if label.Text == "Loading..." then
			loading = true
		end
	end
	H.expect(loading, "empty board should say Loading")
end)

H.test("travel request validates zone ownership", function()
	local travel = registered.TravelZone
	H.expect(travel ~= nil, "TravelZone not registered")
	local player = {}
	profiles[player] = { zones = { Downtown = true } }
	H.expect(travel(player, "LuxuryHills").ok == false, "locked zone")
	H.expect(travel(player, 42).ok == false, "bad input")
	H.expect(travel(player, "Nope").ok == false, "unknown")
end)

H.test("locked portal refuses to teleport", function()
	local surface = map.PortalHall.Portal_LuxuryHills.Surface
	local touched = Runtime.signalOf(surface, "Touched")
	H.expect(touched ~= nil and #touched.listeners == 1, "portal has no touch handler")
end)

return H.summary()
