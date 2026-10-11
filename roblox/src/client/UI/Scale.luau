-- Keeps every HUD group readable on phones, tablets and monitors. Each group
-- gets a UIScale that is updated whenever the viewport changes. Groups are
-- anchored to their screen edge, so scaling never pushes them off screen.

local UI = require(script.Parent.UI)

local Scale = {}

local scales: { UIScale } = {}
Scale.value = 1

local function compute(): number
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(size.X / 1280, size.Y / 760), 0.5, 1.2)
end

local function apply()
	Scale.value = compute()
	for _, uiScale in scales do
		uiScale.Scale = Scale.value
	end
end

function Scale.attach(guiObject: GuiObject): UIScale
	local uiScale = UI.new("UIScale", { Name = "ResponsiveScale", Scale = Scale.value, Parent = guiObject })
	table.insert(scales, uiScale)
	return uiScale
end

function Scale.init()
	local function hookCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
		end
		apply()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)
	hookCamera()
end

return Scale
