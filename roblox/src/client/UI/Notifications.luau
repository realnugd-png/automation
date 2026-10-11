-- Toast notifications (bottom-right stack) and big server announcements.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Sounds = require(Shared.Config.Sounds)

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.UI)
local Effects = require(script.Parent.Effects)
local Scale = require(script.Parent.Scale)

local T = UI.Theme

local Notifications = {}

local toastHolder: Frame
local bannerHolder: Frame
local lastToast: { [string]: number } = {}

local KIND_COLORS = {
	info = T.Blue,
	success = T.Green,
	error = T.Red,
	warning = Color3.fromRGB(255, 170, 60),
	achievement = T.Gold,
}

function Notifications.mount(screen: ScreenGui)
	toastHolder = UI.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -150),
		Size = UDim2.fromOffset(320, 300),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = screen,
	}, {
		UI.new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	bannerHolder = UI.new("Frame", {
		Name = "Announcements",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 126),
		Size = UDim2.fromOffset(560, 60),
		BackgroundTransparency = 1,
		ZIndex = 45,
		Parent = screen,
	})
	Scale.attach(toastHolder)
	Scale.attach(bannerHolder)
end

function Notifications.toast(text: string, kind: string?)
	if not toastHolder or text == "" then
		return
	end
	-- Drop exact duplicates fired within a second (e.g. "Slow down!").
	local now = os.clock()
	if lastToast[text] and now - lastToast[text] < 1 then
		return
	end
	lastToast[text] = now
	local color = KIND_COLORS[kind or "info"] or T.Blue
	local toast = UI.new("Frame", {
		Size = UDim2.fromOffset(320, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.05,
		LayoutOrder = math.floor(now * 1000) % 1e9,
		ZIndex = 40,
		Parent = toastHolder,
	}, {
		UI.corner(10),
		UI.stroke(color, 2, 0.2),
		UI.padding(10, 12),
		UI.label({
			Text = text,
			TextSize = 16,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 41,
		}),
	})
	local children = toastHolder:GetChildren()
	local frames = {}
	for _, child in children do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	if #frames > 4 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
	if kind == "achievement" then
		Effects.play(Sounds.Notify, 1.2, 0.5)
	end
	task.delay(4, function()
		if toast.Parent then
			UI.tween(toast, 0.3, { BackgroundTransparency = 1 })
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

local function systemChat(text: string, color: Color3)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general and general:IsA("TextChannel") then
		local hex = color:ToHex()
		pcall(function()
			general:DisplaySystemMessage(`<font color="#{hex}"><b>{text}</b></font>`)
		end)
	end
end

function Notifications.announce(payload: { [string]: any })
	if not bannerHolder then
		return
	end
	local color = T.Gold
	local rarity = payload.rarity and Rarities.get(payload.rarity)
	if rarity then
		color = rarity.color
	elseif payload.kind == "serverLuck" then
		color = T.Green
	end
	UI.clear(bannerHolder)
	local banner = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, -20),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.1,
		ZIndex = 45,
		Parent = bannerHolder,
	}, {
		UI.corner(14),
		UI.stroke(color, 2.5, 0),
		UI.label({
			Text = payload.text,
			TextColor3 = color,
			Font = T.Title,
			TextScaled = true,
			Size = UDim2.new(1, -24, 1, -12),
			Position = UDim2.fromOffset(12, 6),
			ZIndex = 46,
		}),
	})
	UI.tween(banner, 0.35, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
	if rarity and rarity.order >= 8 then
		Effects.flash(color, 0.25, 0.6)
	end
	Effects.play(Sounds.Notify, 0.8, 0.6)
	systemChat(payload.text, color)
	task.delay(5, function()
		if banner.Parent then
			UI.tween(banner, 0.3, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, -20) })
			task.wait(0.3)
			banner:Destroy()
		end
	end)
end

function Notifications.init()
	State.notify:connect(Notifications.toast)
	State.announce:connect(Notifications.announce)
end

return Notifications
