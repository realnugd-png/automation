-- Builds the luxury map at server start (unless Workspace already contains a
-- hand-made "Map" model with Workspace:GetAttribute("KeepCustomMap") = true).
--
-- Blender props: any Model placed in ServerStorage.Models with one of the
-- names in PROP_NAMES replaces the code-built fallback for that prop. It is
-- scaled to fit the same footprint automatically, so import scale doesn't
-- matter. See docs/BLENDER.md.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local NumberFormat = require(Shared.Modules.NumberFormat)

local Registry = require(script.Parent.Parent.Registry)
local B = require(script.Parent.Builder)

local MapService = {}

-- Palette
local GOLD = Color3.fromRGB(255, 196, 64)
local DEEP_GOLD = Color3.fromRGB(200, 140, 30)
local MARBLE = Color3.fromRGB(236, 232, 224)
local DARK = Color3.fromRGB(28, 26, 32)
local ASPHALT = Color3.fromRGB(46, 46, 52)
local SIDEWALK = Color3.fromRGB(190, 184, 172)
local GRASS = Color3.fromRGB(86, 150, 76)
local LEAF = Color3.fromRGB(70, 140, 60)
local WATER = Color3.fromRGB(80, 170, 230)
local NEON_PINK = Color3.fromRGB(255, 70, 190)
local NEON_CYAN = Color3.fromRGB(60, 230, 255)
local PURPLE = Color3.fromRGB(150, 80, 255)

local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y

local map: Model
local boards: { [string]: Frame } = {}
local customModels = ServerStorage:FindFirstChild("Models")

------------------------------------------------------------------------------
-- Blender prop replacement
------------------------------------------------------------------------------

-- Blender meshes are named "<Palette>_<Part>"; this restores colour and
-- material even if the 3D Importer dropped them.
local PROP_PALETTE: { [string]: { Color3 | Enum.Material | number } } = {
	Gold = { GOLD, Enum.Material.Foil },
	Marble = { MARBLE, Enum.Material.Marble },
	Dark = { DARK, Enum.Material.Metal },
	Water = { WATER, Enum.Material.Glass, 0.3 },
	Leaf = { LEAF, Enum.Material.Grass },
	Palm = { Color3.fromRGB(60, 150, 70), Enum.Material.Grass },
	Wood = { Color3.fromRGB(110, 75, 45), Enum.Material.Wood },
	Bark = { Color3.fromRGB(150, 110, 70), Enum.Material.Wood },
	Steel = { Color3.fromRGB(150, 155, 165), Enum.Material.DiamondPlate },
	Red = { Color3.fromRGB(150, 20, 40), Enum.Material.SmoothPlastic },
	White = { Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic },
	Pip = { Color3.fromRGB(200, 20, 40), Enum.Material.SmoothPlastic },
	Glow = { Color3.fromRGB(255, 236, 180), Enum.Material.Neon },
	Neon = { NEON_CYAN, Enum.Material.Neon },
}

local function applyPalette(part: BasePart)
	local prefix = string.match(part.Name, "^(%a+)_")
	local entry = prefix and PROP_PALETTE[prefix]
	if entry then
		part.Color = entry[1] :: Color3
		part.Material = entry[2] :: Enum.Material
		if entry[3] then
			part.Transparency = entry[3] :: number
			part.CanCollide = false
		end
		if prefix == "Glow" then
			B.light(part, entry[1] :: Color3, 26, 1.2)
		end
	end
end

local function placeProp(parent: Instance, name: string, cframe: CFrame, footprint: number, fallback: () -> Instance?): Instance?
	local template = customModels and customModels:FindFirstChild(name)
	if template and template:IsA("Model") then
		local clone = template:Clone()
		local size = clone:GetExtentsSize()
		local largest = math.max(size.X, size.Z, 0.01)
		pcall(function()
			clone:ScaleTo(clone:GetScale() * footprint / largest)
		end)
		local _, extents = clone:GetBoundingBox()
		clone:PivotTo(cframe * CFrame.new(0, extents.Y / 2, 0))
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				applyPalette(descendant)
			end
		end
		clone.Parent = parent
		return clone
	end
	return fallback()
end

------------------------------------------------------------------------------
-- Reusable props (code fallbacks)
------------------------------------------------------------------------------

local function tree(parent: Instance, position: Vector3, scale: number?)
	local s = scale or 1
	placeProp(parent, "Tree", CFrame.new(position), 9 * s, function()
		local model = B.model(parent, "Tree")
		B.part(model, {
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(9 * s, 1.6 * s, 1.6 * s),
			CFrame = CFrame.new(position + Vector3.new(0, 4.5 * s, 0)) * VERTICAL,
			Color = Color3.fromRGB(110, 75, 45),
			Material = Enum.Material.Wood,
		})
		B.part(model, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(9, 9, 9) * s,
			CFrame = CFrame.new(position + Vector3.new(0, 10 * s, 0)),
			Color = LEAF,
			Material = Enum.Material.Grass,
		})
		return model
	end)
end

local function palm(parent: Instance, position: Vector3)
	placeProp(parent, "PalmTree", CFrame.new(position), 10, function()
		local model = B.model(parent, "PalmTree")
		B.part(model, {
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(16, 1.4, 1.4),
			CFrame = CFrame.new(position + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.rad(85)),
			Color = Color3.fromRGB(150, 110, 70),
			Material = Enum.Material.Wood,
		})
		for i = 0, 4 do
			local angle = math.rad(i * 72)
			B.part(model, {
				Name = "Frond",
				Size = Vector3.new(1.4, 0.3, 7),
				CFrame = CFrame.new(position + Vector3.new(0, 16, 0))
					* CFrame.Angles(0, angle, 0)
					* CFrame.Angles(math.rad(-20), 0, 0)
					* CFrame.new(0, 0, -3),
				Color = Color3.fromRGB(60, 150, 70),
				Material = Enum.Material.Grass,
				CastShadow = false,
			})
		end
		return model
	end)
end

local lampCount = 0
local function lamp(parent: Instance, position: Vector3)
	lampCount += 1
	local lit = lampCount % 2 == 0 -- every other lamp casts light (mobile performance)
	placeProp(parent, "Lamp", CFrame.new(position), 2.5, function()
		local model = B.model(parent, "Lamp")
		B.part(model, {
			Name = "Pole",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(12, 0.6, 0.6),
			CFrame = CFrame.new(position + Vector3.new(0, 6, 0)) * VERTICAL,
			Color = DARK,
			Material = Enum.Material.Metal,
		})
		local head = B.part(model, {
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2, 2, 2),
			CFrame = CFrame.new(position + Vector3.new(0, 12.5, 0)),
			Color = Color3.fromRGB(255, 236, 180),
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
		if lit then
			B.light(head, Color3.fromRGB(255, 220, 160), 30, 1.2)
		end
		return model
	end)
end

local function goldBars(parent: Instance, cframe: CFrame)
	placeProp(parent, "GoldBars", cframe, 6, function()
		local model = B.model(parent, "GoldBars")
		local index = 0
		for layer = 0, 2 do
			for row = 0, 2 - layer do
				index += 1
				B.part(model, {
					Name = "Bar" .. index,
					Size = Vector3.new(1.6, 0.8, 3.2),
					CFrame = cframe * CFrame.new((row - (2 - layer) / 2) * 1.8, 0.4 + layer * 0.8, 0),
					Color = GOLD,
					Material = Enum.Material.Foil,
				})
			end
		end
		return model
	end)
end

local function station(parent: Instance, name: string, cframe: CFrame, color: Color3, title: string, panel: string, actionText: string)
	local model = B.model(parent, name)
	B.part(model, {
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 10, 10),
		CFrame = cframe * CFrame.new(0, 0.5, 0) * VERTICAL,
		Color = DARK,
		Material = Enum.Material.Marble,
	})
	local pedestal = B.part(model, {
		Name = "Pedestal",
		Size = Vector3.new(4, 4, 4),
		CFrame = cframe * CFrame.new(0, 3, 0),
		Color = GOLD,
		Material = Enum.Material.Foil,
	})
	local orb = B.part(model, {
		Name = "Orb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		CFrame = cframe * CFrame.new(0, 6.6, 0),
		Color = color,
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	B.light(orb, color, 16, 2)
	B.sign(model, cframe * CFrame.new(0, 10, 0), Vector3.new(10, 2.6, 0.4), title, { textColor = color, background = DARK })
	B.prompt(pedestal, actionText, title, panel)
	return model
end

------------------------------------------------------------------------------
-- Areas
------------------------------------------------------------------------------

local function buildGround(parent: Instance)
	B.part(parent, {
		Name = "Ground",
		Size = Vector3.new(760, 4, 760),
		CFrame = CFrame.new(0, -2, 60),
		Color = GRASS,
		Material = Enum.Material.Grass,
	})
	-- Invisible boundary walls keep players on the island.
	for _, data in {
		{ Vector3.new(0, 40, -320), Vector3.new(760, 100, 4) },
		{ Vector3.new(0, 40, 440), Vector3.new(760, 100, 4) },
		{ Vector3.new(-380, 40, 60), Vector3.new(4, 100, 760) },
		{ Vector3.new(380, 40, 60), Vector3.new(4, 100, 760) },
	} do
		B.part(parent, { Name = "Boundary", Size = data[2], CFrame = CFrame.new(data[1]), Transparency = 1, CastShadow = false })
	end
end

local function buildRoads(parent: Instance)
	local roads = B.model(parent, "Roads")
	-- North, south, east, west avenues from the plaza edge.
	local specs = {
		{ CFrame.new(0, 0.05, -130), Vector3.new(26, 0.2, 170) },
		{ CFrame.new(0, 0.05, 140), Vector3.new(26, 0.2, 190) },
		{ CFrame.new(130, 0.05, 0), Vector3.new(170, 0.2, 26) },
		{ CFrame.new(-130, 0.05, 0), Vector3.new(170, 0.2, 26) },
	}
	for _, spec in specs do
		local cf, size = spec[1], spec[2]
		B.part(roads, { Name = "Road", Size = size, CFrame = cf, Color = ASPHALT, Material = Enum.Material.Asphalt })
		-- Sidewalks
		local alongZ = size.Z > size.X
		local offset = if alongZ then Vector3.new(17, 0.15, 0) else Vector3.new(0, 0.15, 17)
		local walkSize = if alongZ then Vector3.new(8, 0.5, size.Z) else Vector3.new(size.X, 0.5, 8)
		B.part(roads, { Name = "Sidewalk", Size = walkSize, CFrame = cf + offset, Color = SIDEWALK, Material = Enum.Material.Concrete })
		B.part(roads, { Name = "Sidewalk", Size = walkSize, CFrame = cf - offset, Color = SIDEWALK, Material = Enum.Material.Concrete })
		-- Gold centre line
		local lineSize = if alongZ then Vector3.new(0.6, 0.22, size.Z - 6) else Vector3.new(size.X - 6, 0.22, 0.6)
		B.part(roads, { Name = "Line", Size = lineSize, CFrame = cf + Vector3.new(0, 0.02, 0), Color = GOLD, Material = Enum.Material.Neon, CastShadow = false })
		-- Lamps and trees along the sidewalks
		local length = if alongZ then size.Z else size.X
		local steps = math.floor(length / 34)
		for i = 0, steps do
			local t = -length / 2 + 12 + i * 34
			if t < length / 2 - 6 then
				local along = if alongZ then Vector3.new(0, 0, t) else Vector3.new(t, 0, 0)
				local base = cf.Position + along
				local side = if alongZ then Vector3.new(19.5, 0.4, 0) else Vector3.new(0, 0.4, 19.5)
				lamp(roads, base + side)
				lamp(roads, base - side)
				local treeSide = if alongZ then Vector3.new(27, 0, 0) else Vector3.new(0, 0, 27)
				tree(roads, base + treeSide + (if alongZ then Vector3.new(0, 0, 17) else Vector3.new(17, 0, 0)), 0.9)
				tree(roads, base - treeSide + (if alongZ then Vector3.new(0, 0, 17) else Vector3.new(17, 0, 0)), 0.9)
			end
		end
	end
end

local function buildPlaza(parent: Instance)
	local plaza = B.model(parent, "SpawnPlaza")
	B.part(plaza, {
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 92, 92),
		CFrame = CFrame.new(0, 0.2, 0) * VERTICAL,
		Color = MARBLE,
		Material = Enum.Material.Marble,
	})
	B.part(plaza, {
		Name = "GoldRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.62, 94, 94),
		CFrame = CFrame.new(0, 0.19, 0) * VERTICAL,
		Color = GOLD,
		Material = Enum.Material.Foil,
	})

	-- Fountain
	placeProp(plaza, "Fountain", CFrame.new(0, 0.5, 0), 26, function()
		local fountain = B.model(plaza, "Fountain")
		B.part(fountain, { Name = "Basin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 26, 26), CFrame = CFrame.new(0, 1.6, 0) * VERTICAL, Color = MARBLE, Material = Enum.Material.Marble })
		B.part(fountain, { Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 23, 23), CFrame = CFrame.new(0, 2.7, 0) * VERTICAL, Color = WATER, Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, CastShadow = false })
		B.part(fountain, { Name = "Tier", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 6, 6), CFrame = CFrame.new(0, 5, 0) * VERTICAL, Color = MARBLE, Material = Enum.Material.Marble })
		B.part(fountain, { Name = "Bowl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 12, 12), CFrame = CFrame.new(0, 7.8, 0) * VERTICAL, Color = GOLD, Material = Enum.Material.Foil })
		local coin = B.part(fountain, { Name = "GoldCoin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 8, 8), CFrame = CFrame.new(0, 13, 0) * CFrame.Angles(0, math.rad(90), 0), Color = GOLD, Material = Enum.Material.Foil })
		for _, side in { CFrame.new(0, 13, -0.66), CFrame.new(0, 13, 0.66) * CFrame.Angles(0, math.pi, 0) } do
			B.sign(fountain, side, Vector3.new(5, 5, 0.05), "$", { background = GOLD, textColor = DEEP_GOLD, pixelsPerStud = 40 }).Transparency = 1
		end
		B.light(coin, GOLD, 24, 2)
		local spray = Instance.new("ParticleEmitter")
		spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		spray.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
		spray.Size = NumberSequence.new(0.5, 0)
		spray.Lifetime = NumberRange.new(1, 1.5)
		spray.Rate = 18
		spray.Speed = NumberRange.new(6, 9)
		spray.SpreadAngle = Vector2.new(20, 20)
		spray.Acceleration = Vector3.new(0, -12, 0)
		spray.EmissionDirection = Enum.NormalId.Top
		spray.Parent = fountain:FindFirstChild("Bowl")
		return fountain
	end)

	-- Spawns around the fountain
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 0.4, 8)
		spawn.CFrame = CFrame.new(math.cos(angle) * 30, 0.6, math.sin(angle) * 30)
		spawn.Color = GOLD
		spawn.Material = Enum.Material.Foil
		spawn.Duration = 0
		spawn.Neutral = true
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = plaza
	end

	-- Benches and planters
	for i = 0, 7 do
		local angle = math.rad(i * 45 + 22.5)
		local pos = Vector3.new(math.cos(angle) * 40, 0.5, math.sin(angle) * 40)
		local facing = CFrame.lookAt(pos, Vector3.new(0, 0.5, 0))
		B.part(plaza, { Name = "Planter", Size = Vector3.new(7, 2, 3), CFrame = facing * CFrame.new(0, 1, 0), Color = DARK, Material = Enum.Material.Marble })
		B.part(plaza, { Name = "Hedge", Size = Vector3.new(6.4, 1.6, 2.4), CFrame = facing * CFrame.new(0, 2.6, 0), Color = LEAF, Material = Enum.Material.Grass })
	end

	-- Welcome arch over the south avenue
	local arch = B.model(plaza, "WelcomeArch")
	for _, x in { -16, 16 } do
		B.part(arch, { Name = "Pillar", Size = Vector3.new(4, 26, 4), CFrame = CFrame.new(x, 13, 52), Color = MARBLE, Material = Enum.Material.Marble })
		B.part(arch, { Name = "Cap", Size = Vector3.new(5, 1.5, 5), CFrame = CFrame.new(x, 26.5, 52), Color = GOLD, Material = Enum.Material.Foil })
	end
	B.part(arch, { Name = "Beam", Size = Vector3.new(38, 4, 4), CFrame = CFrame.new(0, 29, 52), Color = GOLD, Material = Enum.Material.Foil })
	B.sign(arch, CFrame.new(0, 29, 49.9), Vector3.new(34, 3.4, 0.2), GameConfig.GameName, { background = DARK })
	B.sign(arch, CFrame.new(0, 29, 54.1) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(34, 3.4, 0.2), GameConfig.GameName, { background = DARK })

	-- Plaza stations
	local function facingCenter(x: number, z: number): CFrame
		return CFrame.lookAt(Vector3.new(x, 0.5, z), Vector3.new(0, 0.5, 0))
	end
	station(plaza, "QuestBoard", facingCenter(-26, -26), Color3.fromRGB(120, 220, 255), "QUESTS", "Quests", "View Quests")
	station(plaza, "ShopKiosk", facingCenter(26, -26), Color3.fromRGB(120, 255, 160), "SHOP", "Shop", "Open Shop")
	station(plaza, "IndexPedestal", facingCenter(-26, 26), Color3.fromRGB(255, 160, 255), "AURA INDEX", "Inventory", "Open Index")
	station(plaza, "TradeBooth", facingCenter(26, 26), Color3.fromRGB(255, 200, 120), "TRADING", "Trade", "Trade")
end

local function buildBank(parent: Instance)
	-- Golden bank at the north end with a walk-in vault room.
	local bank = B.model(parent, "GoldenBank")
	local origin = CFrame.new(0, 0, -250)
	local width, depth, height = 96, 70, 34

	-- Steps
	for i = 0, 3 do
		B.part(bank, { Name = "Step", Size = Vector3.new(width + 10 - i * 2, 1, 14 - i * 3), CFrame = origin * CFrame.new(0, 0.5 + i, depth / 2 + 7 - i * 1.5), Color = MARBLE, Material = Enum.Material.Marble })
	end
	B.part(bank, { Name = "Floor", Size = Vector3.new(width, 4, depth), CFrame = origin * CFrame.new(0, 2, 0), Color = Color3.fromRGB(245, 240, 230), Material = Enum.Material.Marble })

	local wallColor = Color3.fromRGB(232, 200, 120)
	local function wall(name: string, size: Vector3, offset: CFrame)
		B.part(bank, { Name = name, Size = size, CFrame = origin * offset, Color = wallColor, Material = Enum.Material.Sandstone })
	end
	local floorTop = 4
	wall("BackWall", Vector3.new(width, height, 2), CFrame.new(0, floorTop + height / 2, -depth / 2 + 1))
	wall("LeftWall", Vector3.new(2, height, depth), CFrame.new(-width / 2 + 1, floorTop + height / 2, 0))
	wall("RightWall", Vector3.new(2, height, depth), CFrame.new(width / 2 - 1, floorTop + height / 2, 0))
	-- Front wall with a 20 x 18 doorway
	local doorW, doorH = 20, 18
	local sideW = (width - doorW) / 2
	wall("FrontLeft", Vector3.new(sideW, height, 2), CFrame.new(-(doorW / 2 + sideW / 2), floorTop + height / 2, depth / 2 - 1))
	wall("FrontRight", Vector3.new(sideW, height, 2), CFrame.new(doorW / 2 + sideW / 2, floorTop + height / 2, depth / 2 - 1))
	wall("FrontTop", Vector3.new(doorW, height - doorH, 2), CFrame.new(0, floorTop + doorH + (height - doorH) / 2, depth / 2 - 1))
	B.part(bank, { Name = "Roof", Size = Vector3.new(width + 6, 3, depth + 6), CFrame = origin * CFrame.new(0, floorTop + height + 1.5, 0), Color = GOLD, Material = Enum.Material.Foil })

	-- Columns and pediment
	for i = 0, 7 do
		local x = -width / 2 + 6 + i * ((width - 12) / 7)
		if math.abs(x) > doorW / 2 + 2 then
			B.part(bank, { Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 4, 4), CFrame = origin * CFrame.new(x, floorTop + height / 2, depth / 2 + 4) * VERTICAL, Color = MARBLE, Material = Enum.Material.Marble })
		end
	end
	B.part(bank, { Name = "Portico", Size = Vector3.new(width + 6, 3, 10), CFrame = origin * CFrame.new(0, floorTop + height + 1.5, depth / 2 + 4), Color = GOLD, Material = Enum.Material.Foil })
	local pedW = (width + 6) / 2
	B.part(bank, { Name = "PedimentL", Size = Vector3.new(2, 12, pedW), CFrame = origin * CFrame.new(-pedW / 2, floorTop + height + 9, depth / 2 + 6) * CFrame.Angles(0, math.rad(90), 0), Color = GOLD, Material = Enum.Material.Foil }, "WedgePart")
	B.part(bank, { Name = "PedimentR", Size = Vector3.new(2, 12, pedW), CFrame = origin * CFrame.new(pedW / 2, floorTop + height + 9, depth / 2 + 6) * CFrame.Angles(0, math.rad(-90), 0), Color = GOLD, Material = Enum.Material.Foil }, "WedgePart")
	B.sign(bank, origin * CFrame.new(0, floorTop + doorH + 7, depth / 2 + 0.2) * CFrame.Angles(0, math.pi, 0), Vector3.new(40, 6, 0.3), "GOLDEN BANK", { background = DARK })

	-- Interior: lobby lights + vault room
	for _, x in { -30, 0, 30 } do
		local chandelier = B.part(bank, { Name = "Chandelier", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), CFrame = origin * CFrame.new(x, floorTop + height - 6, 8), Color = Color3.fromRGB(255, 230, 170), Material = Enum.Material.Neon, CastShadow = false })
		B.light(chandelier, Color3.fromRGB(255, 220, 160), 40, 1.5)
	end
	-- Lobby carpet
	B.part(bank, { Name = "Carpet", Size = Vector3.new(14, 0.2, depth - 20), CFrame = origin * CFrame.new(0, floorTop + 0.1, 8), Color = Color3.fromRGB(150, 20, 40), Material = Enum.Material.Fabric })

	local vault = B.model(bank, "VaultRoom")
	local vaultOrigin = origin * CFrame.new(0, floorTop, -depth / 2 + 14)
	B.part(vault, { Name = "VaultFloor", Size = Vector3.new(60, 0.3, 24), CFrame = vaultOrigin * CFrame.new(0, 0.15, 0), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.DiamondPlate })
	-- Giant open vault door leaning against the left side
	placeProp(vault, "VaultDoor", vaultOrigin * CFrame.new(-22, 0, 4) * CFrame.Angles(0, math.rad(60), 0), 22, function()
		local door = B.model(vault, "VaultDoor")
		B.part(door, { Name = "Door", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 22, 22), CFrame = vaultOrigin * CFrame.new(-22, 11, 4) * CFrame.Angles(0, math.rad(60 + 90), 0), Color = Color3.fromRGB(150, 155, 165), Material = Enum.Material.DiamondPlate })
		B.part(door, { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 8, 8), CFrame = vaultOrigin * CFrame.new(-22, 11, 4) * CFrame.Angles(0, math.rad(60 + 90), 0), Color = GOLD, Material = Enum.Material.Foil })
		return door
	end)
	for i, x in { -8, 2, 12, 22 } do
		goldBars(vault, vaultOrigin * CFrame.new(x, 0.3, -6 + (i % 2) * 3))
	end
	station(vault, "DailyRewards", vaultOrigin * CFrame.new(-2, 0.3, 6) * CFrame.Angles(0, math.pi, 0), GOLD, "DAILY REWARDS", "Daily", "Claim Daily")
	station(vault, "CodesTerminal", vaultOrigin * CFrame.new(16, 0.3, 6) * CFrame.Angles(0, math.pi, 0), NEON_CYAN, "CODES", "Codes", "Redeem Codes")
end

local function buildCasinoStrip(parent: Instance)
	-- Casino-inspired neon district (visual only, no gambling) with the upgrade machines.
	local strip = B.model(parent, "NeonStrip")
	local origin = CFrame.new(250, 0, 0)
	B.part(strip, { Name = "Plaza", Size = Vector3.new(110, 0.4, 120), CFrame = origin * CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(30, 22, 40), Material = Enum.Material.Slate })
	-- Main building
	B.part(strip, { Name = "Building", Size = Vector3.new(30, 46, 90), CFrame = origin * CFrame.new(42, 23, 0), Color = Color3.fromRGB(40, 30, 55), Material = Enum.Material.SmoothPlastic })
	B.part(strip, { Name = "Trim", Size = Vector3.new(30.4, 1.2, 90.4), CFrame = origin * CFrame.new(42, 46, 0), Color = NEON_PINK, Material = Enum.Material.Neon, CastShadow = false })
	B.sign(strip, origin * CFrame.new(26.8, 34, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(60, 12, 0.4), "LUCKY STRIP", { textColor = NEON_PINK, background = Color3.fromRGB(20, 10, 30), brightness = 3 })
	for i = -2, 2 do
		B.part(strip, { Name = "NeonBar", Size = Vector3.new(0.6, 18, 1), CFrame = origin * CFrame.new(26.9, 12, i * 16), Color = if i % 2 == 0 then NEON_CYAN else NEON_PINK, Material = Enum.Material.Neon, CastShadow = false })
	end

	-- Giant dice (decorative)
	local function die(cframe: CFrame, pips: { Vector2 })
		placeProp(strip, "Dice", cframe, 10, function()
			local model = B.model(strip, "Dice")
			B.part(model, { Name = "Cube", Size = Vector3.new(10, 10, 10), CFrame = cframe * CFrame.new(0, 5, 0), Color = Color3.fromRGB(245, 245, 245), Material = Enum.Material.SmoothPlastic })
			for _, pip in pips do
				B.part(model, { Name = "Pip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.8, 1.8), CFrame = cframe * CFrame.new(pip.X * 2.6, 5 + pip.Y * 2.6, -5.05) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(200, 20, 40), Material = Enum.Material.SmoothPlastic, CastShadow = false })
			end
			return model
		end)
	end
	die(origin * CFrame.new(-40, 0.4, -46) * CFrame.Angles(0, math.rad(20), 0), { Vector2.new(-1, 1), Vector2.new(0, 0), Vector2.new(1, -1) })
	die(origin * CFrame.new(-26, 0.4, -50) * CFrame.Angles(0, math.rad(-15), 0), { Vector2.new(-1, 1), Vector2.new(1, 1), Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(0, 0) })

	-- Slot-machine styled upgrade terminals
	local colors = { GOLD, NEON_CYAN, NEON_PINK }
	for i = -1, 1 do
		local cf = origin * CFrame.new(14, 0.4, i * 20) * CFrame.Angles(0, math.rad(90), 0)
		local machine = placeProp(strip, "SlotMachine", cf, 8, function()
			local model = B.model(strip, "SlotMachine")
			B.part(model, { Name = "Body", Size = Vector3.new(8, 12, 6), CFrame = cf * CFrame.new(0, 6, 0), Color = Color3.fromRGB(150, 20, 40), Material = Enum.Material.SmoothPlastic })
			B.part(model, { Name = "Screen", Size = Vector3.new(6, 4, 0.4), CFrame = cf * CFrame.new(0, 8, -3.1), Color = colors[i + 2], Material = Enum.Material.Neon, CastShadow = false })
			B.part(model, { Name = "Top", Size = Vector3.new(8.4, 1.4, 6.4), CFrame = cf * CFrame.new(0, 12.6, 0), Color = GOLD, Material = Enum.Material.Foil })
			B.part(model, { Name = "Lever", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 0.5, 0.5), CFrame = cf * CFrame.new(4.4, 8, 0) * VERTICAL, Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal })
			B.part(model, { Name = "Knob", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = cf * CFrame.new(4.4, 10.6, 0), Color = Color3.fromRGB(230, 30, 50), Material = Enum.Material.SmoothPlastic })
			return model
		end)
		local promptHost = B.part(strip, { Name = "UpgradeTrigger", Size = Vector3.new(8, 8, 8), CFrame = cf * CFrame.new(0, 4, -5), Transparency = 1, CanCollide = false, CastShadow = false })
		B.prompt(promptHost, "Upgrade", "Upgrade Machine", "Upgrades")
		local _ = machine
	end
	B.sign(strip, origin * CFrame.new(-2, 18, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(30, 5, 0.4), "UPGRADES", { textColor = GOLD, background = DARK })

	-- Neon arch entrance from the east avenue
	for _, z in { -14, 14 } do
		B.part(strip, { Name = "ArchPost", Size = Vector3.new(2, 22, 2), CFrame = origin * CFrame.new(-54, 11, z), Color = NEON_CYAN, Material = Enum.Material.Neon, CastShadow = false })
	end
	B.part(strip, { Name = "ArchTop", Size = Vector3.new(2, 2, 30), CFrame = origin * CFrame.new(-54, 22, 0), Color = NEON_PINK, Material = Enum.Material.Neon, CastShadow = false })
	local glow = B.part(strip, { Name = "Glow", Size = Vector3.new(1, 1, 1), CFrame = origin * CFrame.new(0, 14, 0), Transparency = 1, CanCollide = false, CastShadow = false })
	B.light(glow, NEON_PINK, 60, 1.2)
end

local function buildMansion(parent: Instance)
	local estate = B.model(parent, "LuxuryMansion")
	local origin = CFrame.new(-250, 0, 0)
	B.part(estate, { Name = "Lawn", Size = Vector3.new(120, 0.4, 130), CFrame = origin * CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(100, 175, 90), Material = Enum.Material.Grass })
	B.part(estate, { Name = "Driveway", Size = Vector3.new(60, 0.5, 14), CFrame = origin * CFrame.new(30, 0.25, 0), Color = SIDEWALK, Material = Enum.Material.Pavement })

	local white = Color3.fromRGB(245, 245, 240)
	local house = B.model(estate, "Mansion")
	local base = origin * CFrame.new(-28, 0, 0)
	B.part(house, { Name = "Foundation", Size = Vector3.new(44, 2, 80), CFrame = base * CFrame.new(0, 1, 0), Color = MARBLE, Material = Enum.Material.Marble })
	B.part(house, { Name = "Floor1", Size = Vector3.new(40, 16, 76), CFrame = base * CFrame.new(0, 10, 0), Color = white, Material = Enum.Material.SmoothPlastic })
	B.part(house, { Name = "Floor2", Size = Vector3.new(36, 14, 60), CFrame = base * CFrame.new(-2, 25, 0), Color = white, Material = Enum.Material.SmoothPlastic })
	B.part(house, { Name = "GoldBand", Size = Vector3.new(40.4, 1, 76.4), CFrame = base * CFrame.new(0, 18, 0), Color = GOLD, Material = Enum.Material.Foil })
	B.part(house, { Name = "Roof", Size = Vector3.new(40, 2, 64), CFrame = base * CFrame.new(-2, 33, 0), Color = DARK, Material = Enum.Material.Slate })
	for row = 0, 1 do
		for i = -3, 3 do
			B.part(house, { Name = "Window", Size = Vector3.new(0.4, 6, 5), CFrame = base * CFrame.new(20.1 - row * 4, 10 + row * 15, i * 9), Color = Color3.fromRGB(150, 210, 255), Material = Enum.Material.Glass, Transparency = 0.2, CastShadow = false })
		end
	end
	B.part(house, { Name = "Door", Size = Vector3.new(0.6, 10, 8), CFrame = base * CFrame.new(20.2, 7, 0), Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.Wood })
	for _, z in { -8, 8 } do
		B.part(house, { Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 2, 2), CFrame = base * CFrame.new(25, 10, z) * VERTICAL, Color = MARBLE, Material = Enum.Material.Marble })
	end
	B.part(house, { Name = "Balcony", Size = Vector3.new(8, 1, 22), CFrame = base * CFrame.new(25, 18.5, 0), Color = MARBLE, Material = Enum.Material.Marble })

	-- Pool with palms
	B.part(estate, { Name = "PoolEdge", Size = Vector3.new(26, 1, 40), CFrame = origin * CFrame.new(18, 0.5, -38), Color = MARBLE, Material = Enum.Material.Marble })
	B.part(estate, { Name = "PoolWater", Size = Vector3.new(22, 1.05, 36), CFrame = origin * CFrame.new(18, 0.55, -38), Color = WATER, Material = Enum.Material.Glass, Transparency = 0.25, CastShadow = false })
	for _, offset in { Vector3.new(36, 0.4, -54), Vector3.new(36, 0.4, -22), Vector3.new(0, 0.4, -58), Vector3.new(-50, 0.4, 50), Vector3.new(40, 0.4, 50) } do
		palm(estate, origin.Position + offset)
	end
	-- Hedges
	for _, z in { -48, -24, 24, 48 } do
		B.part(estate, { Name = "Hedge", Size = Vector3.new(4, 3, 14), CFrame = origin * CFrame.new(56, 1.5, z), Color = LEAF, Material = Enum.Material.Grass })
	end

	-- Rebirth shrine in the front garden
	local shrine = station(estate, "RebirthStation", origin * CFrame.new(30, 0.4, 38) * CFrame.Angles(0, math.rad(-90), 0), PURPLE, "REBIRTH", "Rebirth", "Rebirth")
	local ring = B.part(shrine, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 16, 16), CFrame = origin * CFrame.new(30, 0.7, 38) * VERTICAL, Color = PURPLE, Material = Enum.Material.Neon, CastShadow = false })
	local _ = ring
end

local function buildLeaderboardPlaza(parent: Instance)
	local plaza = B.model(parent, "LeaderboardPlaza")
	local origin = CFrame.new(0, 0, 260)
	B.part(plaza, { Name = "Floor", Size = Vector3.new(120, 0.4, 70), CFrame = origin * CFrame.new(0, 0.2, 0), Color = MARBLE, Material = Enum.Material.Marble })

	local function board(name: string, cframe: CFrame, title: string)
		local frameModel = B.model(plaza, name)
		B.part(frameModel, { Name = "Frame", Size = Vector3.new(30, 36, 1.6), CFrame = cframe * CFrame.new(0, 20, 0.6), Color = GOLD, Material = Enum.Material.Foil })
		for _, x in { -13, 13 } do
			B.part(frameModel, { Name = "Leg", Size = Vector3.new(2, 4, 2), CFrame = cframe * CFrame.new(x, 2, 0.6), Color = DARK, Material = Enum.Material.Metal })
		end
		local screen = B.part(frameModel, { Name = "Screen", Size = Vector3.new(28, 34, 0.4), CFrame = cframe * CFrame.new(0, 20, 0), Color = DARK, Material = Enum.Material.SmoothPlastic, CastShadow = false })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.LightInfluence = 0
		gui.Parent = screen
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, 0, 0.1, 0)
		header.BackgroundColor3 = DEEP_GOLD
		header.TextColor3 = Color3.new(1, 1, 1)
		header.Font = Enum.Font.GothamBlack
		header.TextScaled = true
		header.Text = title
		header.Parent = gui
		local list = Instance.new("Frame")
		list.Name = "List"
		list.Size = UDim2.new(1, -20, 0.88, 0)
		list.Position = UDim2.new(0, 10, 0.11, 0)
		list.BackgroundTransparency = 1
		list.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0.006, 0)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		boards[name] = list
	end
	board("ServerBoard", origin * CFrame.new(-24, 0.4, 14), "RICHEST IN SERVER")
	board("GlobalBoard", origin * CFrame.new(24, 0.4, 14), "ALL-TIME RICHEST")

	-- Podium
	local heights = { 6, 4, 2.5 }
	local xs = { 0, -9, 9 }
	local podiumColors = { GOLD, Color3.fromRGB(200, 200, 210), Color3.fromRGB(205, 127, 50) }
	for i = 1, 3 do
		B.part(plaza, { Name = "Podium" .. i, Size = Vector3.new(8, heights[i], 8), CFrame = origin * CFrame.new(xs[i], heights[i] / 2 + 0.4, -6), Color = podiumColors[i], Material = Enum.Material.Foil })
	end
	station(plaza, "LeaderboardKiosk", origin * CFrame.new(0, 0.4, 14), GOLD, "LEADERBOARDS", "Leaderboard", "View")
end

local teleportDebounce: { [Player]: number } = {}

local function teleport(player: Player, position: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and character then
		character:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	end
end

local function canTeleport(player: Player): boolean
	local now = os.clock()
	if teleportDebounce[player] and now - teleportDebounce[player] < 2 then
		return false
	end
	teleportDebounce[player] = now
	return true
end

local PORTAL_HALL = CFrame.new(0, 0, 330)

local function buildPortal(parent: Instance, cframe: CFrame, zone: GameConfig.Zone)
	local portal = B.model(parent, "Portal_" .. zone.id)
	local function frame()
		local model = B.model(portal, "Frame")
		for _, x in { -7, 7 } do
			B.part(model, { Name = "Post", Size = Vector3.new(2.4, 20, 2.4), CFrame = cframe * CFrame.new(x, 10, 0), Color = GOLD, Material = Enum.Material.Foil })
		end
		B.part(model, { Name = "Top", Size = Vector3.new(17, 2.4, 2.4), CFrame = cframe * CFrame.new(0, 21, 0), Color = GOLD, Material = Enum.Material.Foil })
		return model
	end
	placeProp(portal, "PortalArch", cframe, 17, frame)
	local surface = B.part(portal, { Name = "Surface", Size = Vector3.new(11.6, 18, 0.6), CFrame = cframe * CFrame.new(0, 10, 0), Color = zone.color, Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, CastShadow = false })
	B.light(surface, zone.color, 18, 2)
	local reqText = if zone.requiredRebirths > 0 then ` · {zone.requiredRebirths} Rebirth` else ""
	B.sign(portal, cframe * CFrame.new(0, 25, 0) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(18, 5, 0.3), `{zone.name}\n${NumberFormat.short(zone.cost)}{reqText}`, { textColor = zone.color, background = DARK })
	B.prompt(surface, "Unlock / Info", zone.name, "Zones")
	surface.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or not canTeleport(player) then
			return
		end
		local profile = Registry.DataService.get(player)
		if profile and profile.zones[zone.id] then
			teleport(player, zone.center + Vector3.new(0, 1, 50))
		else
			Registry.DataService.notify(player, `{zone.name} is locked. Open the Zones menu to unlock it.`, "warning")
		end
	end)
end

local function buildZoneIsland(parent: Instance, zone: GameConfig.Zone)
	local island = B.model(parent, "Zone_" .. zone.id)
	local center = CFrame.new(zone.center)
	B.part(island, { Name = "Island", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, zone.radius * 2, zone.radius * 2), CFrame = center * CFrame.new(0, -3, 0) * VERTICAL, Color = Color3.fromRGB(70, 65, 80), Material = Enum.Material.Slate })
	B.part(island, { Name = "Top", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, zone.radius * 2 - 6, zone.radius * 2 - 6), CFrame = center * CFrame.new(0, 0.2, 0) * VERTICAL, Color = MARBLE, Material = Enum.Material.Marble })
	B.part(island, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, zone.radius * 2 - 2, zone.radius * 2 - 2), CFrame = center * CFrame.new(0, 0.1, 0) * VERTICAL, Color = zone.color, Material = Enum.Material.Neon, CastShadow = false })
	-- Invisible fence
	for i = 0, 11 do
		local angle = math.rad(i * 30)
		local pos = zone.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (zone.radius - 1)
		B.part(island, { Name = "Fence", Size = Vector3.new(2, 40, zone.radius * 0.6), CFrame = CFrame.lookAt(pos + Vector3.new(0, 20, 0), zone.center + Vector3.new(0, 20, 0)) * CFrame.Angles(0, math.rad(90), 0), Transparency = 1, CastShadow = false })
	end
	-- Ring of pillars
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local pos = zone.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (zone.radius - 14)
		B.part(island, { Name = "Pillar", Size = Vector3.new(4, 18, 4), CFrame = CFrame.new(pos + Vector3.new(0, 9, 0)), Color = MARBLE, Material = Enum.Material.Marble })
		local cap = B.part(island, { Name = "Flame", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 3.4, 3.4), CFrame = CFrame.new(pos + Vector3.new(0, 19.8, 0)), Color = zone.color, Material = Enum.Material.Neon, CastShadow = false })
		if i % 2 == 0 then
			B.light(cap, zone.color, 26, 1.4)
		end
	end
	-- Monument
	B.part(island, { Name = "MonumentBase", Size = Vector3.new(14, 4, 14), CFrame = center * CFrame.new(0, 2, 0), Color = DARK, Material = Enum.Material.Marble })
	local gem = B.part(island, { Name = "Gem", Size = Vector3.new(7, 7, 7), CFrame = center * CFrame.new(0, 10, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0), Color = zone.color, Material = Enum.Material.Neon, CastShadow = false })
	B.light(gem, zone.color, 40, 2)
	B.sign(island, center * CFrame.new(0, 20, 0), Vector3.new(26, 5, 0.3), `{zone.name}\n{zone.description}`, { textColor = zone.color, background = DARK, face = Enum.NormalId.Back })
	for i = 0, 5 do
		local angle = math.rad(i * 60 + 30)
		tree(island, zone.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (zone.radius - 30), 1.1)
	end
	if zone.center.Y > 20 then
		-- Floating clouds for elevated zones
		for i = 0, 9 do
			local angle = math.rad(i * 36)
			B.part(island, { Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.new(26, 26, 26), CFrame = CFrame.new(zone.center + Vector3.new(math.cos(angle) * (zone.radius + 10), -14, math.sin(angle) * (zone.radius + 10))), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, Transparency = 0.2, CanCollide = false, CastShadow = false })
		end
	end

	-- Return portal
	local back = B.part(island, { Name = "ReturnPortal", Size = Vector3.new(10, 16, 0.6), CFrame = center * CFrame.new(0, 8.4, zone.radius - 18), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, CastShadow = false })
	B.sign(island, center * CFrame.new(0, 19, zone.radius - 18), Vector3.new(14, 3, 0.3), "RETURN TO CITY", { background = DARK })
	back.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and canTeleport(player) then
			teleport(player, PORTAL_HALL.Position + Vector3.new(0, 1, -24))
		end
	end)
end

local function buildPortalHall(parent: Instance)
	local hall = B.model(parent, "PortalHall")
	B.part(hall, { Name = "Floor", Size = Vector3.new(150, 0.4, 40), CFrame = PORTAL_HALL * CFrame.new(0, 0.2, 0), Color = DARK, Material = Enum.Material.Marble })
	B.sign(hall, PORTAL_HALL * CFrame.new(0, 34, 10), Vector3.new(50, 6, 0.4), "WEALTH ZONES", { background = DARK })
	local zonesToPlace = {}
	for _, zone in GameConfig.Zones do
		if zone.radius > 0 then
			table.insert(zonesToPlace, zone)
		end
	end
	local spacing = 30
	for index, zone in zonesToPlace do
		local x = (index - (#zonesToPlace + 1) / 2) * spacing
		buildPortal(hall, PORTAL_HALL * CFrame.new(x, 0.4, 8) * CFrame.Angles(0, math.rad(180), 0), zone)
		buildZoneIsland(parent, zone)
	end
end

local function setupLighting()
	Lighting.ClockTime = 17.4
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(70, 60, 60)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 125, 115)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(255, 215, 180)
	atmosphere.Decay = Color3.fromRGB(150, 110, 120)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.12
	color.Contrast = 0.06
	color.TintColor = Color3.fromRGB(255, 246, 236)
	color.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
end

------------------------------------------------------------------------------
-- Leaderboard boards
------------------------------------------------------------------------------

local function fillBoard(list: Frame, entries: { any })
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for rank = 1, math.min(#entries, 10) do
		local entry = entries[rank]
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0.094, 0)
		row.BackgroundColor3 = if rank % 2 == 0 then Color3.fromRGB(40, 36, 44) else Color3.fromRGB(32, 29, 36)
		row.BorderSizePixel = 0
		row.TextColor3 = if rank == 1 then GOLD elseif rank == 2 then Color3.fromRGB(220, 220, 230) elseif rank == 3 then Color3.fromRGB(215, 140, 70) else Color3.new(1, 1, 1)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = `  #{rank}  {entry.name}  —  ${NumberFormat.short(entry.value)}`
		row.LayoutOrder = rank
		row.Parent = list
	end
	if #entries == 0 then
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0.1, 0)
		row.BackgroundTransparency = 1
		row.TextColor3 = Color3.fromRGB(180, 180, 180)
		row.Font = Enum.Font.Gotham
		row.TextScaled = true
		row.Text = "Loading..."
		row.Parent = list
	end
end

function MapService.updateLeaderboardBoards(payload: { server: { any }, global: { any } })
	if boards.ServerBoard then
		fillBoard(boards.ServerBoard, payload.server)
	end
	if boards.GlobalBoard then
		fillBoard(boards.GlobalBoard, payload.global)
	end
end

-- Instant travel for unlocked zones (used by the Zones menu).
local function travel(player: Player, zoneId: any)
	if type(zoneId) ~= "string" then
		return { ok = false, message = "Invalid zone" }
	end
	local zone = GameConfig.ZoneById[zoneId]
	local profile = Registry.DataService.get(player)
	if not zone or not profile then
		return { ok = false, message = "Invalid zone" }
	end
	if not profile.zones[zoneId] then
		return { ok = false, message = "Unlock this zone first" }
	end
	if not canTeleport(player) then
		return { ok = false, message = "Slow down!" }
	end
	if zone.radius == 0 then
		teleport(player, Vector3.new(0, 1, 30))
	else
		teleport(player, zone.center + Vector3.new(0, 1, 50))
	end
	return { ok = true, message = "Welcome to " .. zone.name }
end

function MapService.init()
	setupLighting()
	Registry.RequestService.register("TravelZone", travel, 1)
	local existing = workspace:FindFirstChild("Map")
	if existing and workspace:GetAttribute("KeepCustomMap") then
		map = existing :: Model
		return
	end
	if existing then
		existing:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	map = Instance.new("Model")
	map.Name = "Map"
	buildGround(map)
	buildRoads(map)
	buildPlaza(map)
	buildBank(map)
	buildCasinoStrip(map)
	buildMansion(map)
	buildLeaderboardPlaza(map)
	buildPortalHall(map)
	map.Parent = workspace

	Players.PlayerRemoving:Connect(function(player)
		teleportDebounce[player] = nil
	end)
end

return MapService
