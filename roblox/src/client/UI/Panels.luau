-- Modal panel manager. Each panel module returns
--   { title: string, build: (content: ScrollingFrame) -> (), refresh: (content) -> () }
-- Only one panel is open at a time; the open panel refreshes when state changes.

local UI = require(script.Parent.UI)
local Scale = require(script.Parent.Scale)
local State = require(script.Parent.Parent.State)

local T = UI.Theme

export type PanelDef = {
	title: string,
	build: ((content: ScrollingFrame) -> ())?,
	refresh: (content: ScrollingFrame) -> (),
	onOpen: (() -> ())?,
	live: boolean?, -- refresh every second while open (timers)
}

local Panels = {}

local definitions: { [string]: PanelDef } = {}
local container: Frame
local titleLabel: TextLabel
local content: { [string]: ScrollingFrame } = {}
local built: { [string]: boolean } = {}
Panels.current = nil :: string?
local refreshQueued = false
local openedListeners: { (string?) -> () } = {}

function Panels.register(name: string, definition: any)
	definitions[name] = definition
end

function Panels.onChanged(fn: (string?) -> ())
	table.insert(openedListeners, fn)
end

function Panels.mount(screen: ScreenGui)
	local holder = UI.new("Frame", {
		Name = "PanelHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(680, 470),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = screen,
	})
	Scale.attach(holder)
	container = UI.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.Panel,
		Visible = false,
		ZIndex = 20,
		Parent = holder,
	}, {
		UI.corner(18),
		UI.stroke(T.Gold, 2, 0.15),
		UI.gradient(Color3.fromRGB(34, 30, 40), Color3.fromRGB(20, 18, 24)),
	})
	UI.new("UIScale", { Name = "OpenScale", Parent = container })

	local header = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = T.GoldDark,
		ZIndex = 21,
		Parent = container,
	}, {
		UI.corner(18),
		UI.gradient(Color3.fromRGB(255, 214, 100), Color3.fromRGB(196, 128, 20)),
	})
	-- square off the header's bottom corners
	UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		BackgroundColor3 = T.White,
		BorderSizePixel = 0,
		ZIndex = 21,
		Parent = header,
	}, { UI.gradient(Color3.fromRGB(226, 170, 60), Color3.fromRGB(196, 128, 20)) })
	titleLabel = UI.label({
		Text = "",
		Font = T.Title,
		TextSize = 26,
		TextColor3 = Color3.fromRGB(40, 24, 4),
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
		Parent = header,
	})
	UI.button({
		Text = "X",
		Size = UDim2.fromOffset(40, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		ZIndex = 23,
		Parent = header,
	}, function()
		Panels.close()
	end, "red")
end

local function getContent(name: string): ScrollingFrame
	local frame = content[name]
	if frame then
		return frame
	end
	frame = UI.new("ScrollingFrame", {
		Name = name,
		Size = UDim2.new(1, -24, 1, -70),
		Position = UDim2.fromOffset(12, 62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		ZIndex = 21,
		Parent = container,
	}, { UI.list(nil, 8), UI.padding(4, 2) })
	content[name] = frame
	return frame
end

local function refreshCurrent()
	local name = Panels.current
	if not name then
		return
	end
	local definition = definitions[name]
	local frame = getContent(name)
	if not built[name] then
		built[name] = true
		if definition.build then
			definition.build(frame)
		end
	end
	definition.refresh(frame)
end

function Panels.refresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.delay(0.15, function()
		refreshQueued = false
		refreshCurrent()
	end)
end

function Panels.open(name: string)
	local definition = definitions[name]
	if not definition then
		return
	end
	for other, frame in content do
		frame.Visible = other == name
	end
	Panels.current = name
	titleLabel.Text = definition.title
	local frame = getContent(name)
	frame.Visible = true
	frame.CanvasPosition = Vector2.zero
	refreshCurrent()
	if definition.onOpen then
		definition.onOpen()
	end
	if not container.Visible then
		local scale = container:FindFirstChild("OpenScale") :: UIScale
		scale.Scale = 0.85
		container.Visible = true
		UI.tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	for _, fn in openedListeners do
		task.spawn(fn, name)
	end
end

function Panels.close()
	if not container.Visible then
		return
	end
	Panels.current = nil
	container.Visible = false
	for _, fn in openedListeners do
		task.spawn(fn, nil)
	end
end

function Panels.toggle(name: string)
	if Panels.current == name then
		Panels.close()
	else
		Panels.open(name)
	end
end

function Panels.init()
	State.changed:connect(Panels.refresh)
	State.leaderboardChanged:connect(Panels.refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			local name = Panels.current
			if name and definitions[name].live then
				Panels.refresh()
			end
		end
	end)
end

return Panels
