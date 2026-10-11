-- Equipped wealth auras and the overhead wealth title.
-- Built from Roblox's built-in particle textures, so nothing needs uploading.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Modules.Formulas)

local Registry = require(script.Parent.Parent.Registry)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local AvatarService = {}

local function colorSequence(a: Color3, b: Color3): ColorSequence
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b) })
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 230, 120)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 200)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(130, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 140, 255)),
})

local function makeEmitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Rotation = NumberRange.new(0, 360)
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = parent
	return emitter
end

local function buildAura(root: BasePart, auraId: string)
	local attachment = Instance.new("Attachment")
	attachment.Name = "WealthAura"

	if auraId == "VIP" then
		makeEmitter(attachment, {
			Color = colorSequence(Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 170, 30)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
			Rate = 18,
		})
		makeEmitter(attachment, {
			Texture = FIRE,
			Color = colorSequence(Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 120, 20)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.6, 1),
			Acceleration = Vector3.new(0, 4, 0),
			Rate = 10,
		})
		attachment.Parent = root
		return
	end

	local rarity = Rarities.get(auraId)
	if not rarity then
		return
	end
	local strength = rarity.order / Rarities.count -- 0..1
	local color = if rarity.effect == "celestial" then RAINBOW else colorSequence(rarity.color, rarity.accent)

	makeEmitter(attachment, {
		Color = color,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 + strength * 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Rate = math.floor(6 + strength * 24),
	})
	if rarity.order >= 6 then
		makeEmitter(attachment, {
			Texture = FIRE,
			Color = color,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 + strength), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.55, 1),
			Acceleration = Vector3.new(0, 5, 0),
			Speed = NumberRange.new(0.5, 1.5),
			Rate = math.floor(4 + strength * 10),
		})
	end
	if rarity.order >= 8 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 10
		light.Brightness = 1.5
		light.Shadows = false
		light.Parent = attachment
	end
	if rarity.order >= 10 then
		makeEmitter(attachment, {
			Color = color,
			Size = NumberSequence.new(0.25),
			Speed = NumberRange.new(6, 9),
			Lifetime = NumberRange.new(0.4, 0.6),
			Drag = 4,
			Rate = 20,
		})
	end
	attachment.Parent = root
end

local function buildTag(head: BasePart, player: Player, profile: { [string]: any })
	local existing = head:FindFirstChild("WealthTag")
	if existing then
		existing:Destroy()
	end
	local best = Rarities.list[profile.bestOrder]
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WealthTag"
	billboard.Size = UDim2.fromOffset(220, 64)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false

	local function label(text: string, y: number, height: number, color: Color3, font: Enum.Font)
		local textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.Size = UDim2.new(1, 0, 0, height)
		textLabel.Position = UDim2.fromOffset(0, y)
		textLabel.Font = font
		textLabel.Text = text
		textLabel.TextScaled = true
		textLabel.TextColor3 = color
		textLabel.TextStrokeTransparency = 0.4
		textLabel.Parent = billboard
	end

	local vip = Registry.MonetizationService.hasPass(player, "VIP")
	local titleColor = if best then best.color else Color3.fromRGB(220, 220, 220)
	label((if vip then "[VIP] " else "") .. player.DisplayName, 0, 22, Color3.new(1, 1, 1), Enum.Font.GothamBold)
	label(Formulas.wealthTitle(profile.lifetime), 22, 20, titleColor, Enum.Font.GothamBlack)
	if profile.rebirths > 0 then
		label(`Rebirth {profile.rebirths}`, 43, 16, Color3.fromRGB(255, 215, 90), Enum.Font.Gotham)
	end
	billboard.Parent = head
end

function AvatarService.refresh(player: Player)
	local profile = Registry.DataService.get(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	if root then
		local old = root:FindFirstChild("WealthAura")
		if old then
			old:Destroy()
		end
		local aura = profile.equippedAura
		if aura == "VIP" and not Registry.MonetizationService.hasPass(player, "VIP") then
			aura = ""
		end
		if aura ~= "" then
			buildAura(root, aura)
		end
	end
	if head then
		buildTag(head, player, profile)
	end
end

function AvatarService.init()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Head", 10)
			AvatarService.refresh(player)
		end)
		if player.Character then
			AvatarService.refresh(player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Registry.DataService.onLoaded(function(player)
		AvatarService.refresh(player)
	end)

	-- Keep titles current as lifetime earnings grow (cheap: only rebuild on change).
	local lastTitle: { [Player]: string } = {}
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local profile = Registry.DataService.get(player)
				if profile then
					local key = Formulas.wealthTitle(profile.lifetime) .. profile.rebirths .. profile.bestOrder
					if lastTitle[player] ~= key then
						lastTitle[player] = key
						AvatarService.refresh(player)
					end
				end
			end
			for player in lastTitle do
				if player.Parent == nil then
					lastTitle[player] = nil
				end
			end
		end
	end)
end

return AvatarService
