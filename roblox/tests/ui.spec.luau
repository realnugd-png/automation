-- Boots the real client (HUD + every panel) in Lune's Roblox instance model
-- with a realistic snapshot, then opens every panel, presses every enabled
-- button, plays every rarity's reveal, and fires announcements and trade
-- events. Any invalid property, missing reference or runtime error fails.

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local H = require("./harness")
local Runtime = require("./runtime")

print("Client UI tests")
Runtime.install()

local warnings = {}

-- Fake players
local playerGui = roblox.Instance.new("PlayerGui")
local localPlayer = {
	Name = "Tester",
	DisplayName = "Tester",
	UserId = 1,
	Character = nil,
	WaitForChild = function()
		return playerGui
	end,
	GetAttribute = function() return nil end,
}
local otherPlayer = { Name = "Friend", DisplayName = "Friend", UserId = 222 }
local playersStub = {
	LocalPlayer = localPlayer,
	GetPlayers = function()
		return { localPlayer, otherPlayer }
	end,
	GetPlayerByUserId = function(_, id)
		return if id == 222 then otherPlayer else nil
	end,
	PlayerAdded = Runtime.newSignal(),
	PlayerRemoving = Runtime.newSignal(),
}

local remotes, events, calls = Runtime.fakeRemotes(function(action)
	if action == "GetLeaderboard" then
		return { ok = true, data = { server = { { name = "Tester", value = 5e9, userId = 0 } }, global = {} } }
	end
	return { ok = true }
end)

Runtime.create({
	isServer = false,
	remotes = remotes,
	stubs = {
		Players = playersStub,
		TextChatService = { FindFirstChild = function() return nil end },
	},
})
-- Lune can't override engine-computed properties like Camera.ViewportSize,
-- so the client sees a plain-table workspace with a phone-sized camera.
local fakeCamera = {
	ViewportSize = roblox.Vector2.new(844, 390),
	GetPropertyChangedSignal = function()
		return Runtime.newSignal()
	end,
}
H.globals.workspace = {
	CurrentCamera = fakeCamera,
	GetPropertyChangedSignal = function()
		return Runtime.newSignal()
	end,
	GetServerTimeNow = function()
		return os.time()
	end,
}
H.globals.warn = function(...)
	table.insert(warnings, table.concat({ ... }, " "))
end

-- Build a realistic snapshot with the real server logic.
local Profile = H.require("src/server/Logic/Profile")
local Quests = H.require("src/server/Logic/Quests")
local Formulas = H.require("src/shared/Modules/Formulas")
local Rarities = H.require("src/shared/Config/Rarities")

local now = os.time()
local profile = Profile.template()
profile.cash = 5e9
profile.lifetime = 9e9
profile.totalRolls = 1234
profile.bestOrder = 8
profile.rebirths = 2
profile.inventory = { Rich = 3, Millionaire = 1, Billionaire = 1 }
profile.discovered = { Broke = true, Poor = true, WorkingClass = true, Comfortable = true, Rich = true, Millionaire = true, Billionaire = true }
profile.rarityCounts = { Broke = 600, Poor = 300, Rich = 3 }
profile.equippedAura = "Rich"
profile.history = { { id = "Rich", cash = 12000 }, { id = "Broke", cash = 3 } }
profile.boosts = { daily = { mult = 2, expires = now + 600 } }
profile.zones.LuxuryHills = true
Quests.ensureDaily(profile, now)
Quests.ensureRepeatable(profile)
profile.quests.daily.list[1].progress = profile.quests.daily.list[1].target
profile.daily.playDay = Formulas.dayNumber(now)
profile.daily.playSeconds = 20 * 60
local stats = Formulas.computeStats(profile, { passes = { VIP = true }, zoneId = "LuxuryHills", now = now, serverLuck = 1 })

local function snapshot()
	return {
		profile = Profile.snapshot(profile),
		stats = stats,
		passes = { VIP = true },
		serverLuck = { mult = 2, expires = now + 300 },
		serverTime = now,
		loginIndex = 1,
		canClaimLogin = true,
		canClaimBoost = true,
		autoRoll = false,
		temporary = true,
	}
end

H.test("client bootstrap runs", function()
	H.require("src/client")
end)

local screen = playerGui:FindFirstChild("MillionaireRNG")

H.test("screen gui created", function()
	H.expect(screen ~= nil, "ScreenGui missing")
end)

H.test("first snapshot renders the HUD", function()
	events.State.OnClientEvent:Fire(snapshot())
	task.wait(0.3)
	local found = false
	for _, label in Runtime.descendants(screen, "TextLabel") do
		if label.Text == "$5B" then
			found = true
		end
	end
	H.expect(found, "cash label not updated to $5B")
end)

local Panels = H.require("src/client/UI/Panels")
local PANELS = { "Inventory", "Upgrades", "Rebirth", "Daily", "Quests", "Zones", "Leaderboard", "Trade", "Shop", "Codes", "Stats", "Settings" }

local function panelFrame(name: string)
	for _, frame in Runtime.descendants(screen, "ScrollingFrame") do
		if frame.Name == name then
			return frame
		end
	end
	return nil
end

local function press(button)
	if button:GetAttribute("Disabled") then
		return false
	end
	local signal = Runtime.signalOf(button, "Activated")
	if signal then
		signal:Fire()
		return true
	end
	return false
end

for _, name in PANELS do
	H.test("panel " .. name .. " opens, renders and every button works", function()
		Panels.open(name)
		task.wait(0.05)
		local frame = panelFrame(name)
		H.expect(frame ~= nil, "panel content missing")
		local items = #frame:GetChildren()
		H.expect(items > 2, "panel looks empty (" .. items .. ")")
		local before = #calls
		local pressed = 0
		for _, button in Runtime.descendants(frame, "TextButton") do
			if press(button) then
				pressed += 1
			end
		end
		task.wait(0.3) -- let deferred refreshes run
		if name == "Rebirth" then
			-- Rebirth needs a second tap to confirm; the first only arms it.
			for _, button in Runtime.descendants(frame, "TextButton") do
				press(button)
			end
			task.wait(0.1)
			H.expect(calls[#calls].action == "Rebirth", "confirmed rebirth should send a request")
		end
		if name == "Leaderboard" then
			-- Tabs switch locally (no server call).
			for _, button in Runtime.descendants(frame, "TextButton") do
				if button.Text == "All-Time (Global)" then
					press(button)
				end
			end
			task.wait(0.3)
			local switched = false
			for _, label in Runtime.descendants(frame, "TextLabel") do
				if label.Text:find("Lifetime earnings across all servers") then
					switched = true
				end
			end
			H.expect(switched, "global tab did not render")
		elseif name ~= "Codes" then -- codes needs typed text first
			H.expect(pressed == 0 or #calls > before, "buttons pressed but no request was sent")
		end
	end)
end

H.test("menu buttons toggle panels", function()
	Panels.close()
	local menu = screen:FindFirstChild("Menu")
	local count = 0
	for _, button in Runtime.descendants(menu, "TextButton") do
		H.expect(press(button), "menu button not wired")
		count += 1
		task.wait(0.02)
	end
	H.expect(count == #PANELS, "expected a menu button per panel")
	Panels.close()
end)

H.test("codes panel redeems typed code", function()
	Panels.open("Codes")
	local frame = panelFrame("Codes")
	local box = Runtime.descendants(frame, "TextBox")[1]
	box.Text = "RELEASE"
	local before = #calls
	for _, button in Runtime.descendants(frame, "TextButton") do
		press(button)
	end
	H.expect(#calls == before + 1 and calls[#calls].action == "RedeemCode" and calls[#calls].args[1] == "RELEASE")
	Panels.close()
end)

H.test("roll button sends a Roll request", function()
	local rollButton
	for _, button in Runtime.descendants(screen, "TextButton") do
		if button.Name == "RollButton" then
			rollButton = button
		end
	end
	H.expect(rollButton ~= nil, "roll button missing")
	local before = #calls
	press(rollButton)
	task.wait(0.05)
	H.expect(#calls == before + 1 and calls[#calls].action == "Roll", "no Roll request")
end)

H.test("every rarity reveal plays without errors", function()
	for _, rarity in Rarities.list do
		events.RollResult.OnClientEvent:Fire({
			results = { { id = rarity.id, cash = rarity.minCash }, { id = "Broke", cash = 2 } },
			best = rarity.id,
			bestCash = rarity.minCash,
			total = rarity.minCash + 2,
			newDiscoveries = { rarity.id },
			cooldown = 1,
			luck = 2,
			auto = false,
		})
		task.wait(rarity.revealTime + 1.5)
	end
	H.expect(#warnings == 0, "warnings: " .. table.concat(warnings, " | "))
end)

H.test("announcements, notifications and trade flow render", function()
	events.Announce.OnClientEvent:Fire({ kind = "roll", rarity = "Trillionaire", text = "Friend rolled Trillionaire!" })
	events.Announce.OnClientEvent:Fire({ kind = "serverLuck", text = "Server luck!" })
	events.Notify.OnClientEvent:Fire({ text = "Hello", kind = "achievement" })
	events.Trade.OnClientEvent:Fire({ type = "invite", fromName = "Friend", fromUserId = 222 })
	events.Trade.OnClientEvent:Fire({ type = "update", partnerName = "Friend", partnerUserId = 222, myOffer = { Rich = 1 }, theirOffer = { Millionaire = 1 }, myAccepted = false, theirAccepted = true, version = 3 })
	task.wait(0.3)
	H.expect(Panels.current == "Trade", "trade panel should open on session start")
	local before = #calls
	for _, button in Runtime.descendants(panelFrame("Trade"), "TextButton") do
		press(button)
	end
	local sawAccept = false
	for i = before + 1, #calls do
		if calls[i].action == "TradeAccept" and calls[i].args[1] == 3 then
			sawAccept = true
		end
	end
	H.expect(sawAccept, "accept should send the version the player saw")
	events.Trade.OnClientEvent:Fire({ type = "closed", reason = "Trade complete!" })
	task.wait(0.3)
end)

H.test("auto roll and settings states refresh", function()
	local snap = snapshot()
	snap.autoRoll = true
	snap.profile.settings.autoRollSkipReveal = true
	events.State.OnClientEvent:Fire(snap)
	task.wait(0.3)
	local autoText
	for _, button in Runtime.descendants(screen, "TextButton") do
		if button.Text == "AUTO\nON" then
			autoText = button.Text
		end
	end
	H.expect(autoText ~= nil, "auto button did not show ON")
	H.expect(#warnings == 0, "warnings: " .. table.concat(warnings, " | "))
end)

local ok = H.summary()
process.exit(if ok then 0 else 1)
