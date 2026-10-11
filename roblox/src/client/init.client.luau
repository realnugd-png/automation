-- Client bootstrap for Become An Millionaire RNG.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)

local State = require(script.State)
local UI = require(script.UI.UI)
local Scale = require(script.UI.Scale)
local Effects = require(script.UI.Effects)
local Notifications = require(script.UI.Notifications)
local Panels = require(script.UI.Panels)
local Hud = require(script.UI.Hud)
local World = require(script.World)
local TradePanel = require(script.Panels.Trade)

local player = Players.LocalPlayer

local screen = UI.new("ScreenGui", {
	Name = "MillionaireRNG",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Loading screen until the first snapshot arrives.
local loading = UI.new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = UI.Theme.Background,
	ZIndex = 100,
	Parent = screen,
}, {
	UI.label({
		Text = "BECOME AN MILLIONAIRE RNG",
		Font = UI.Theme.Title,
		TextScaled = true,
		TextColor3 = UI.Theme.Gold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.7, 0.12),
		ZIndex = 101,
	}),
	UI.label({
		Text = "Loading your fortune…",
		TextSize = 20,
		TextColor3 = UI.Theme.Muted,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.6, 0.05),
		ZIndex = 101,
	}),
})

UI.onClickSound = function()
	Effects.play(Sounds.Click, 1.2, 0.3)
end

Scale.init()
State.init()
Effects.mount(screen)
Notifications.mount(screen)
Notifications.init()
Panels.mount(screen)
Panels.init()
Hud.mount(screen)
Hud.init()
World.init()

Panels.register("Inventory", require(script.Panels.Inventory))
Panels.register("Upgrades", require(script.Panels.Upgrades))
Panels.register("Rebirth", require(script.Panels.Rebirth))
Panels.register("Daily", require(script.Panels.Daily))
Panels.register("Quests", require(script.Panels.Quests))
Panels.register("Zones", require(script.Panels.Zones))
Panels.register("Leaderboard", require(script.Panels.Leaderboard))
Panels.register("Trade", TradePanel)
Panels.register("Shop", require(script.Panels.Shop))
Panels.register("Codes", require(script.Panels.Codes))
Panels.register("Stats", require(script.Panels.Stats))
Panels.register("Settings", require(script.Panels.Settings))
TradePanel.init(screen)

-- Keep the default player list (shows Cash/Best/Rebirths) and chat; hide nothing else.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
end)

local first = true
local function hideLoading()
	if first then
		first = false
		UI.tween(loading, 0.5, { BackgroundTransparency = 1 })
		for _, child in loading:GetChildren() do
			if child:IsA("TextLabel") then
				UI.tween(child, 0.5, { TextTransparency = 1 })
			end
		end
		task.delay(0.6, function()
			loading:Destroy()
		end)
	end
end
State.changed:connect(hideLoading)
if State.snapshot then
	hideLoading()
end
