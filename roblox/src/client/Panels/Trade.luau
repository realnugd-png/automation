-- Aura trading UI. The server validates every offer and executes the swap;
-- this panel only displays the session and sends requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local T = UI.Theme

local session: { [string]: any }? = nil
local popup: Frame? = nil
local screenRef: ScreenGui? = nil

local function panels()
	return require(script.Parent.Parent.UI.Panels)
end

local function offerText(offer: { [string]: number }?): string
	if not offer or next(offer) == nil then
		return "(nothing)"
	end
	local parts = {}
	for _, rarity in Rarities.list do
		local count = offer[rarity.id]
		if count and count > 0 then
			table.insert(parts, `<font color="#{rarity.color:ToHex()}">{rarity.name}</font> x{count}`)
		end
	end
	return table.concat(parts, "\n")
end

local function changeOffer(rarityId: string, delta: number)
	if not session then
		return
	end
	local profile = State.profile()
	if not profile then
		return
	end
	local offer = table.clone(session.myOffer or {})
	local owned = profile.inventory[rarityId] or 0
	offer[rarityId] = math.clamp((offer[rarityId] or 0) + delta, 0, owned)
	if offer[rarityId] == 0 then
		offer[rarityId] = nil
	end
	State.request("TradeSetOffer", offer)
end

local function showInvite(payload)
	if not screenRef then
		return
	end
	if popup then
		popup:Destroy()
	end
	local frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 200),
		Size = UDim2.fromOffset(380, 130),
		BackgroundColor3 = T.Panel,
		ZIndex = 30,
		Parent = screenRef,
	}, {
		UI.corner(14),
		UI.stroke(T.Gold, 2, 0.1),
		UI.label({ Text = `{payload.fromName} wants to trade auras with you`, TextSize = 17, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 8), ZIndex = 31 }),
	})
	local scale = require(script.Parent.Parent.UI.Scale)
	scale.attach(frame)
	popup = frame
	local function respond(accept: boolean)
		frame:Destroy()
		popup = nil
		local result = State.request("TradeRespond", payload.fromUserId, accept)
		if accept and result.ok then
			panels().open("Trade")
		end
	end
	UI.button({ Text = "ACCEPT", Size = UDim2.fromOffset(160, 44), Position = UDim2.fromOffset(20, 70), ZIndex = 31, Parent = frame }, function()
		respond(true)
	end, "green")
	UI.button({ Text = "DECLINE", Size = UDim2.fromOffset(160, 44), Position = UDim2.fromOffset(200, 70), ZIndex = 31, Parent = frame }, function()
		respond(false)
	end, "red")
	task.delay(30, function()
		if popup == frame then
			frame:Destroy()
			popup = nil
		end
	end)
end

local function refreshIdle(content: ScrollingFrame)
	UI.label({ Text = "Trade collectible auras with players in this server. Cash cannot be traded.", TextSize = 14, TextColor3 = T.Muted, Size = UDim2.new(1, -10, 0, 36), LayoutOrder = 0, Parent = content })
	local others = 0
	for index, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer then
			others += 1
			local row = UI.row(content, 50, index)
			UI.label({ Text = player.DisplayName, Font = T.Bold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -170, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = row })
			UI.button({ Text = "SEND REQUEST", TextSize = 14, Size = UDim2.fromOffset(150, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = row }, function()
				State.request("TradeRequest", player.UserId)
			end, "gold")
		end
	end
	if others == 0 then
		UI.label({ Text = "No other players in this server yet.", TextSize = 16, TextColor3 = T.Muted, LayoutOrder = 1, Parent = content })
	end
end

local function refreshSession(content: ScrollingFrame, current: { [string]: any })
	local profile = State.profile()
	if not profile then
		return
	end
	UI.label({ Text = `Trading with {current.partnerName}`, Font = T.Title, TextSize = 20, TextColor3 = T.Gold, LayoutOrder = 0, Parent = content })

	local offers = UI.new("Frame", { Size = UDim2.new(1, -6, 0, 130), BackgroundTransparency = 1, LayoutOrder = 1, Parent = content })
	for column, data in { { "Your offer", current.myOffer, current.myAccepted }, { current.partnerName .. "'s offer", current.theirOffer, current.theirAccepted } } do
		UI.new("Frame", {
			Size = UDim2.new(0.5, -6, 1, 0),
			Position = UDim2.new((column - 1) * 0.5, (column - 1) * 6, 0, 0),
			BackgroundColor3 = T.Row,
			Parent = offers,
		}, {
			UI.corner(10),
			UI.stroke(if data[3] then T.Green else T.Gold, 2, if data[3] then 0 else 0.6),
			UI.label({ Text = data[1] .. (if data[3] then "  ✔ READY" else ""), Font = T.Bold, TextSize = 15, TextColor3 = if data[3] then T.Green else T.Text, Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 4) }),
			UI.label({ Text = offerText(data[2]), RichText = true, TextSize = 14, Size = UDim2.new(1, -10, 1, -30), Position = UDim2.fromOffset(5, 28), TextYAlignment = Enum.TextYAlignment.Top }),
		})
	end

	local actions = UI.new("Frame", { Size = UDim2.new(1, -6, 0, 48), BackgroundTransparency = 1, LayoutOrder = 2, Parent = content }, {
		UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	local accept = UI.button({ Text = if current.myAccepted then "WAITING…" else "ACCEPT TRADE", Size = UDim2.fromOffset(200, 44), Parent = actions }, function()
		State.request("TradeAccept", current.version)
	end, "green")
	UI.setEnabled(accept, not current.myAccepted)
	UI.button({ Text = "CANCEL", Size = UDim2.fromOffset(140, 44), Parent = actions }, function()
		State.request("TradeCancel")
	end, "red")

	UI.label({ Text = "Your auras (tap + / − to change your offer)", TextSize = 14, TextColor3 = T.Muted, LayoutOrder = 3, Parent = content })
	local any = false
	for index, rarity in Rarities.list do
		local owned = profile.inventory[rarity.id] or 0
		if rarity.hasAura and owned > 0 then
			any = true
			local offered = (current.myOffer and current.myOffer[rarity.id]) or 0
			local row = UI.row(content, 44, 10 + index)
			UI.label({ Text = `{rarity.name}  ({offered}/{owned} offered)`, TextSize = 15, TextColor3 = rarity.color, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -140, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = row })
			local minus = UI.button({ Text = "−", TextSize = 22, Size = UDim2.fromOffset(52, 34), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0), Parent = row }, function()
				changeOffer(rarity.id, -1)
			end, "dark")
			UI.setEnabled(minus, offered > 0)
			local plus = UI.button({ Text = "+", TextSize = 22, Size = UDim2.fromOffset(52, 34), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = row }, function()
				changeOffer(rarity.id, 1)
			end, "gold")
			UI.setEnabled(plus, offered < owned)
		end
	end
	if not any then
		UI.label({ Text = "You don't own any auras yet — roll Comfortable or rarer to collect them.", TextSize = 14, TextColor3 = T.Muted, LayoutOrder = 11, Parent = content })
	end
end

local Trade = {
	title = "TRADING",
	refresh = function(content: ScrollingFrame)
		UI.clear(content)
		if session then
			refreshSession(content, session)
		else
			refreshIdle(content)
		end
	end,
}

function Trade.init(screen: ScreenGui)
	screenRef = screen
	State.tradeEvent:connect(function(payload)
		if payload.type == "invite" then
			showInvite(payload)
		elseif payload.type == "update" then
			session = payload
			if panels().current ~= "Trade" then
				panels().open("Trade")
			else
				panels().refresh()
			end
		elseif payload.type == "closed" then
			session = nil
			State.notify:fire(payload.reason, "info")
			panels().refresh()
		end
	end)
	Players.PlayerAdded:Connect(function()
		panels().refresh()
	end)
	Players.PlayerRemoving:Connect(function()
		panels().refresh()
	end)
end

return Trade
