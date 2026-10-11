-- Main HUD: cash bar, status chips, menu, ROLL button, result card, history,
-- and the roll reveal sequence.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local GameConfig = require(Shared.Config.GameConfig)
local Sounds = require(Shared.Config.Sounds)
local RNG = require(Shared.Modules.RNG)
local NumberFormat = require(Shared.Modules.NumberFormat)

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.UI)
local Effects = require(script.Parent.Effects)
local Panels = require(script.Parent.Panels)
local Scale = require(script.Parent.Scale)

local T = UI.Theme

local Hud = {}

local refs: { [string]: any } = {}
local queue: { any } = {}
local revealing = false
local lastRollClick = 0
local cooldownEnds = 0
local cooldownLength = 1

local MENU = {
	{ panel = "Inventory", icon = "🎒", label = "Auras" },
	{ panel = "Upgrades", icon = "⬆️", label = "Upgrades" },
	{ panel = "Rebirth", icon = "♻️", label = "Rebirth" },
	{ panel = "Daily", icon = "🎁", label = "Daily" },
	{ panel = "Quests", icon = "📜", label = "Quests" },
	{ panel = "Zones", icon = "🌍", label = "Zones" },
	{ panel = "Leaderboard", icon = "🏆", label = "Top" },
	{ panel = "Trade", icon = "🤝", label = "Trade" },
	{ panel = "Shop", icon = "🛒", label = "Shop" },
	{ panel = "Codes", icon = "🔑", label = "Codes" },
	{ panel = "Stats", icon = "📊", label = "Stats" },
	{ panel = "Settings", icon = "⚙️", label = "Settings" },
}

------------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------------

local function buildTopBar(screen: ScreenGui)
	local bar = UI.new("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(420, 76),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.08,
		Parent = screen,
	}, {
		UI.corner(16),
		UI.stroke(T.Gold, 2, 0.2),
		UI.gradient(Color3.fromRGB(40, 34, 46), Color3.fromRGB(20, 18, 24)),
	})
	Scale.attach(bar)
	refs.cash = UI.label({
		Text = "$0",
		Font = T.Title,
		TextSize = 38,
		TextColor3 = T.Gold,
		Size = UDim2.new(1, -20, 0, 44),
		Position = UDim2.fromOffset(10, 4),
		TextStrokeTransparency = 0.6,
		Parent = bar,
	})
	refs.lifetime = UI.label({
		Text = "Lifetime $0 · Broke Beginner",
		TextSize = 15,
		TextColor3 = T.Muted,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 48),
		Parent = bar,
	})

	local chips = UI.new("Frame", {
		Name = "Chips",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(700, 30),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Scale.attach(chips)
	refs.chips = chips
end

local function chip(text: string, color: Color3, order: number)
	return UI.new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.1,
		Text = text,
		TextColor3 = color,
		Font = T.Bold,
		TextSize = 15,
		LayoutOrder = order,
		Parent = refs.chips,
	}, { UI.corner(14), UI.padding(0, 12), UI.stroke(color, 1.5, 0.3) })
end

local function buildMenu(screen: ScreenGui)
	local menu = UI.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.42, 0),
		Size = UDim2.fromOffset(156, 6 * 70),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(74, 64),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Scale.attach(menu)
	refs.menuBadges = {}
	for index, item in MENU do
		local button = UI.button({
			Text = "",
			LayoutOrder = index,
			Parent = menu,
		}, function()
			Panels.toggle(item.panel)
		end, "dark")
		UI.label({ Text = item.icon, TextSize = 26, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 4), Parent = button })
		UI.label({ Text = item.label, TextSize = 13, Font = T.Bold, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -22), Parent = button })
		local badge = UI.new("Frame", {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(1, -16, 0, 2),
			BackgroundColor3 = T.Red,
			Visible = false,
			Parent = button,
		}, { UI.corner(7), UI.stroke(T.White, 1.5, 0) })
		refs.menuBadges[item.panel] = badge
	end
end

local function buildRollArea(screen: ScreenGui)
	local area = UI.new("Frame", {
		Name = "RollArea",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(470, 300),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Scale.attach(area)
	refs.rollArea = area

	refs.rollCount = UI.label({
		Text = "Rolls: 0",
		TextSize = 16,
		TextColor3 = T.Muted,
		Size = UDim2.fromOffset(300, 20),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 156),
		Parent = area,
	})

	local roll = UI.button({
		Name = "RollButton",
		Text = "ROLL",
		TextSize = 40,
		Size = UDim2.fromOffset(280, 92),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Parent = area,
	}, function()
		Hud.requestRoll()
	end, "gold")
	refs.rollButton = roll
	UI.stroke(T.White, 3, 0.3).Parent = roll
	local cooldown = UI.new("Frame", {
		Name = "Cooldown",
		Size = UDim2.new(1, -24, 0, 8),
		Position = UDim2.new(0, 12, 1, -14),
		BackgroundColor3 = Color3.fromRGB(60, 40, 10),
		BackgroundTransparency = 0.3,
		Parent = roll,
	}, { UI.corner(4) })
	refs.cooldownFill = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.White,
		Parent = cooldown,
	}, { UI.corner(4) })
	refs.luckOnButton = UI.label({
		Text = "Luck x1.00",
		TextSize = 14,
		Font = T.Bold,
		TextColor3 = Color3.fromRGB(70, 40, 5),
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 6),
		Parent = roll,
	})
	UI.label({ Text = "[R]", TextSize = 12, TextColor3 = Color3.fromRGB(110, 70, 10), Size = UDim2.fromOffset(40, 14), Position = UDim2.new(1, -44, 0, 6), Parent = roll })

	refs.autoButton = UI.button({
		Text = "AUTO\nOFF",
		TextSize = 16,
		Size = UDim2.fromOffset(84, 64),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 150, 1, -34),
		Parent = area,
	}, function()
		local snapshot = State.snapshot
		if not snapshot then
			return
		end
		State.request("SetAutoRoll", not snapshot.autoRoll)
	end, "dark")
	refs.skipButton = UI.button({
		Text = "SKIP\nANIM",
		TextSize = 16,
		Size = UDim2.fromOffset(84, 64),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.5, -150, 1, -34),
		Parent = area,
	}, function()
		local profile = State.profile()
		if profile then
			State.request("SetSetting", "autoRollSkipReveal", not profile.settings.autoRollSkipReveal)
		end
	end, "dark")
end

local function buildResultCard()
	local holder = UI.new("Frame", {
		Name = "ResultHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(460, 146),
		BackgroundTransparency = 1,
		Parent = refs.rollArea,
	})
	local card = UI.new("Frame", {
		Name = "ResultCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.15,
		Parent = holder,
	}, { UI.corner(18) })
	refs.cardStroke = UI.stroke(T.Gold, 3, 0.2)
	refs.cardStroke.Parent = card
	refs.cardScale = UI.new("UIScale", { Parent = card })
	refs.resultName = UI.label({
		Text = "Press ROLL to get rich!",
		Font = T.Title,
		TextScaled = true,
		Size = UDim2.new(1, -30, 0, 58),
		Position = UDim2.fromOffset(15, 12),
		TextColor3 = T.Gold,
		TextStrokeTransparency = 0.5,
		Parent = card,
	})
	refs.nameGradient = UI.new("UIGradient", { Enabled = false, Parent = refs.resultName })
	refs.resultCash = UI.label({
		Text = "",
		Font = T.Title,
		TextSize = 30,
		Size = UDim2.new(1, -30, 0, 36),
		Position = UDim2.fromOffset(15, 72),
		TextColor3 = T.Green,
		Parent = card,
	})
	refs.resultOdds = UI.label({
		Text = "",
		TextSize = 15,
		TextColor3 = T.Muted,
		Size = UDim2.new(1, -30, 0, 20),
		Position = UDim2.fromOffset(15, 112),
		Parent = card,
	})
	refs.newBadge = UI.label({
		Text = "NEW!",
		Font = T.Title,
		TextSize = 18,
		TextColor3 = T.Background,
		BackgroundTransparency = 0,
		BackgroundColor3 = T.Green,
		Size = UDim2.fromOffset(64, 26),
		Position = UDim2.new(1, -74, 0, -10),
		Rotation = 8,
		Visible = false,
		Parent = card,
	})
	UI.corner(8).Parent = refs.newBadge
end

local function buildHistory(screen: ScreenGui)
	local panel = UI.new("Frame", {
		Name = "History",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.42, 0),
		Size = UDim2.fromOffset(210, 300),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.15,
		Parent = screen,
	}, { UI.corner(14), UI.stroke(T.Gold, 1.5, 0.5), UI.padding(8) })
	Scale.attach(panel)
	UI.label({ Text = "RECENT ROLLS", Font = T.Title, TextSize = 16, TextColor3 = T.Gold, Size = UDim2.new(1, 0, 0, 22), Parent = panel })
	local list = UI.new("Frame", {
		Size = UDim2.new(1, 0, 1, -26),
		Position = UDim2.fromOffset(0, 26),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { UI.list(nil, 3) })
	refs.historyList = list
end

------------------------------------------------------------------------------
-- Live updates
------------------------------------------------------------------------------

local function refreshHistory()
	local profile = State.profile()
	if not profile then
		return
	end
	UI.clear(refs.historyList)
	for index = 1, math.min(#profile.history, 10) do
		local entry = profile.history[index]
		local rarity = Rarities.get(entry.id)
		if rarity then
			UI.new("Frame", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = T.Row,
				LayoutOrder = index,
				Parent = refs.historyList,
			}, {
				UI.corner(6),
				UI.label({ Text = rarity.name, TextSize = 13, TextColor3 = rarity.color, Size = UDim2.new(0.58, 0, 1, 0), Position = UDim2.fromOffset(6, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false }),
				UI.label({ Text = "$" .. NumberFormat.short(entry.cash), TextSize = 13, TextColor3 = T.Text, Size = UDim2.new(0.4, -6, 1, 0), Position = UDim2.new(0.6, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right }),
			})
		end
	end
end

local function refreshChips()
	local snapshot = State.snapshot
	if not snapshot then
		return
	end
	UI.clear(refs.chips)
	local stats = snapshot.stats
	local now = State.now()
	chip(string.format("🍀 Luck x%.2f", stats.luck), T.Green, 1)
	local zone = GameConfig.ZoneById[stats.zoneId]
	if zone and zone.id ~= "Downtown" then
		chip("📍 " .. zone.name, zone.color, 2)
	end
	if stats.eventName then
		chip("🎉 " .. stats.eventName, T.Purple, 3)
	end
	if snapshot.serverLuck.expires > now then
		chip(`🌐 Server {snapshot.serverLuck.mult}x · {NumberFormat.duration(snapshot.serverLuck.expires - now)}`, T.Blue, 4)
	end
	local soonest = math.huge
	local boostCount = 0
	for _, boost in snapshot.profile.boosts do
		if boost.expires > now then
			boostCount += 1
			soonest = math.min(soonest, boost.expires)
		end
	end
	if boostCount > 0 then
		chip(string.format("⚡ Boost x%.1f · %s", stats.boostLuck, NumberFormat.duration(soonest - now)), T.Gold, 5)
	end
	if snapshot.temporary then
		chip("⚠ Studio test: not saving", T.Red, 6)
	end
end

local function refreshBadges()
	local snapshot = State.snapshot
	if not snapshot then
		return
	end
	local profile = snapshot.profile
	refs.menuBadges.Daily.Visible = snapshot.canClaimLogin or snapshot.canClaimBoost
	local questReady = false
	for _, entry in profile.quests.daily.list do
		if not entry.claimed and entry.progress >= entry.target then
			questReady = true
		end
	end
	for _, state in profile.quests.repeatable do
		if state.progress >= state.target then
			questReady = true
		end
	end
	refs.menuBadges.Quests.Visible = questReady
end

function Hud.refresh()
	local snapshot = State.snapshot
	if not snapshot then
		return
	end
	local profile = snapshot.profile
	refs.cash.Text = "$" .. NumberFormat.short(profile.cash)
	refs.lifetime.Text = `Lifetime ${NumberFormat.short(profile.lifetime)} · Rebirth {profile.rebirths}`
	refs.rollCount.Text = `Rolls: {NumberFormat.commas(profile.totalRolls)}  ·  x{snapshot.stats.rollsPerClick} per roll`
	refs.luckOnButton.Text = string.format("Luck x%.2f", snapshot.stats.luck)
	if snapshot.autoRoll then
		refs.autoButton.Text = "AUTO\nON"
		UI.setButtonStyle(refs.autoButton, "green")
	else
		refs.autoButton.Text = if snapshot.stats.autoRollUnlocked then "AUTO\nOFF" else `AUTO\n🔒{GameConfig.Roll.autoRollUnlockRolls}`
		UI.setButtonStyle(refs.autoButton, "dark")
	end
	if profile.settings.autoRollSkipReveal then
		refs.skipButton.Text = "SKIP\nON"
		UI.setButtonStyle(refs.skipButton, "blue")
	else
		refs.skipButton.Text = "SKIP\nANIM"
		UI.setButtonStyle(refs.skipButton, "dark")
	end
	refreshHistory()
	refreshChips()
	refreshBadges()
end

------------------------------------------------------------------------------
-- Rolling and the reveal sequence
------------------------------------------------------------------------------

function Hud.requestRoll()
	local snapshot = State.snapshot
	if not snapshot then
		return
	end
	local now = os.clock()
	if now < cooldownEnds or now - lastRollClick < 0.1 then
		return
	end
	lastRollClick = now
	task.spawn(function()
		local result = State.request("Roll")
		if not result.ok and result.message == nil then
			-- Server ignored an early click; nothing to show.
			return
		end
	end)
end

local function startCooldown(seconds: number)
	cooldownLength = seconds
	cooldownEnds = os.clock() + seconds
end

local function setResultText(rarity, cash: number, luck: number)
	refs.resultName.Text = rarity.name
	refs.resultName.TextColor3 = rarity.color
	refs.cardStroke.Color = rarity.color
	refs.resultOdds.Text = NumberFormat.odds(RNG.getProbabilities(luck)[rarity.order]) .. string.format("  (base 1 in %s)", NumberFormat.short(rarity.chance))
	if rarity.effect == "celestial" then
		refs.nameGradient.Enabled = true
		refs.nameGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 140)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 140)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(140, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 150, 255)),
		})
		refs.resultName.TextColor3 = T.White
	else
		refs.nameGradient.Enabled = false
	end
	-- Count the cash up
	local counter = Instance.new("NumberValue")
	counter.Value = 0
	counter.Changed:Connect(function(value)
		refs.resultCash.Text = "+$" .. NumberFormat.short(value)
	end)
	UI.tween(counter, math.min(0.25 + rarity.order * 0.08, 1.2), { Value = cash }).Completed:Connect(function()
		refs.resultCash.Text = "+$" .. NumberFormat.short(cash)
		counter:Destroy()
	end)
end

local function playRevealEffects(rarity)
	local effect = rarity.effect
	Effects.play(Sounds.ByRarity[rarity.id] or Sounds.Reveal, 0.7 + rarity.order * 0.08, 0.4 + rarity.order * 0.04)
	if effect == "sparkle" then
		Effects.burst(rarity.color, 6)
	elseif effect == "burst" then
		Effects.burst(rarity.color, 16)
		Effects.worldBurst(rarity.color, 30)
	elseif effect == "flash" then
		Effects.flash(rarity.color, 0.45, 0.6)
		Effects.burst(rarity.color, 26)
		Effects.worldBurst(rarity.color, 60)
		Effects.shake(1, 0.5)
	elseif effect == "cinematic" or effect == "celestial" then
		Effects.flash(T.White, 0.85, 0.9)
		task.delay(0.15, Effects.flash, rarity.color, 0.6, 1.2)
		Effects.burst(rarity.color, 40)
		Effects.worldBurst(rarity.color, 120)
		Effects.shake(2, 1.1)
		Effects.play(Sounds.Rare, 0.5, 0.8)
	end
	UI.tween(refs.cardScale, 0.12, { Scale = 1.12 }, Enum.EasingStyle.Back).Completed:Connect(function()
		UI.tween(refs.cardScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

local function bigTitle(rarity)
	if not Effects.enabled("effects") then
		return
	end
	local label = UI.label({
		Text = string.upper(rarity.name) .. "!",
		Font = T.Title,
		TextScaled = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.8, 0.16),
		TextColor3 = rarity.color,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = T.Black,
		ZIndex = 55,
		Parent = refs.screen,
	})
	local scale = UI.new("UIScale", { Scale = 0.2, Parent = label })
	UI.tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		UI.tween(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		task.wait(0.4)
		label:Destroy()
	end)
end

local function reveal(result)
	local rarity = Rarities.get(result.best)
	if not rarity then
		return
	end
	local profile = State.profile()
	-- "Skip anim" skips the build-up for anything below Millionaire; a backlog of results is fast-forwarded too.
	local skip = (profile ~= nil and profile.settings.autoRollSkipReveal and rarity.order < 6) or #queue > 2
	refs.newBadge.Visible = false

	if not skip then
		local duration = rarity.revealTime
		local dramatic = rarity.order >= 7
		if dramatic then
			Effects.letterbox(duration + 1.4)
		end
		local maxShown = math.min(Rarities.count, math.max(rarity.order + 2, 5))
		local elapsed = 0
		local interval = 0.045
		refs.resultCash.Text = ""
		refs.resultOdds.Text = ""
		refs.nameGradient.Enabled = false
		while elapsed < duration do
			local fake = Rarities.list[math.random(1, maxShown)]
			refs.resultName.Text = if dramatic and elapsed > duration * 0.6 then "???" else fake.name
			refs.resultName.TextColor3 = fake.color
			refs.cardStroke.Color = fake.color
			Effects.play(Sounds.Tick, 1 + elapsed / duration * 0.6, 0.25)
			task.wait(interval)
			elapsed += interval
			interval = math.min(interval * 1.12, 0.2)
		end
	end

	setResultText(rarity, result.bestCash, result.luck)
	if not skip or rarity.order >= 6 then
		playRevealEffects(rarity)
	end
	if rarity.order >= 7 then
		bigTitle(rarity)
	end
	if result.newDiscoveries and #result.newDiscoveries > 0 then
		refs.newBadge.Visible = true
		if not skip then
			State.notify:fire(`New rarity discovered: {rarity.name}!`, "achievement")
		end
	end
	if #result.results > 1 then
		local parts = {}
		for _, single in result.results do
			local r = Rarities.get(single.id)
			table.insert(parts, if r then r.name else single.id)
		end
		refs.resultOdds.Text = `x{#result.results}: ` .. table.concat(parts, ", ") .. `  ·  total +${NumberFormat.short(result.total)}`
	end
	if not skip and rarity.order >= 7 then
		task.wait(0.8)
	end
end

local function processQueue()
	if revealing then
		return
	end
	revealing = true
	while #queue > 0 do
		local result = table.remove(queue, 1)
		local ok, err = pcall(reveal, result)
		if not ok then
			warn("[Hud] reveal failed: " .. tostring(err))
		end
	end
	revealing = false
end

function Hud.mount(screen: ScreenGui)
	refs.screen = screen
	buildTopBar(screen)
	buildMenu(screen)
	buildRollArea(screen)
	buildResultCard()
	buildHistory(screen)
end

function Hud.init()
	State.changed:connect(Hud.refresh)
	State.rollResult:connect(function(result)
		startCooldown(result.cooldown)
		table.insert(queue, result)
		task.spawn(processQueue)
	end)

	ContextActionService:BindAction("BAM_Roll", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Hud.requestRoll()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)

	-- Cooldown bar + ticking timers
	local timerAccumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		local remaining = math.max(0, cooldownEnds - os.clock())
		refs.cooldownFill.Size = UDim2.fromScale(1 - remaining / math.max(cooldownLength, 0.01), 1)
		timerAccumulator += dt
		if timerAccumulator >= 1 then
			timerAccumulator = 0
			refreshChips()
		end
	end)
end

return Hud
