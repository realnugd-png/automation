-- UI toolkit: theme + small constructors used by every screen.

local TweenService = game:GetService("TweenService")

local UI = {}

UI.Theme = {
	Background = Color3.fromRGB(16, 14, 20),
	Panel = Color3.fromRGB(26, 23, 31),
	PanelLight = Color3.fromRGB(38, 34, 45),
	Row = Color3.fromRGB(33, 30, 39),
	Gold = Color3.fromRGB(255, 200, 70),
	GoldLight = Color3.fromRGB(255, 232, 150),
	GoldDark = Color3.fromRGB(196, 132, 24),
	Text = Color3.fromRGB(248, 244, 236),
	Muted = Color3.fromRGB(168, 160, 150),
	Green = Color3.fromRGB(80, 210, 120),
	Red = Color3.fromRGB(235, 80, 80),
	Blue = Color3.fromRGB(90, 170, 255),
	Purple = Color3.fromRGB(160, 100, 255),
	Black = Color3.fromRGB(0, 0, 0),
	White = Color3.fromRGB(255, 255, 255),
	Title = Enum.Font.GothamBlack,
	Bold = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
}
local T = UI.Theme

function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className :: any)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.corner(radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UI.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color or T.Gold,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return UI.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function UI.padding(all: number, horizontal: number?): UIPadding
	local h = horizontal or all
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, h),
		PaddingRight = UDim.new(0, h),
	})
end

function UI.list(direction: Enum.FillDirection?, padding: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return UI.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
	})
end

function UI.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = T.Bold,
		TextColor3 = T.Text,
		TextSize = 18,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for key, value in props do
		defaults[key] = value
	end
	return UI.new("TextLabel", defaults)
end

function UI.tween(instance: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

export type ButtonStyle = "gold" | "dark" | "green" | "red" | "blue" | "purple"

local STYLES: { [string]: { Color3 } } = {
	gold = { Color3.fromRGB(255, 220, 110), Color3.fromRGB(220, 150, 30), Color3.fromRGB(40, 26, 6) },
	dark = { Color3.fromRGB(56, 50, 64), Color3.fromRGB(38, 34, 45), T.Text },
	green = { Color3.fromRGB(110, 230, 140), Color3.fromRGB(40, 160, 80), Color3.fromRGB(8, 30, 14) },
	red = { Color3.fromRGB(250, 120, 120), Color3.fromRGB(190, 50, 50), T.White },
	blue = { Color3.fromRGB(120, 190, 255), Color3.fromRGB(50, 110, 220), T.White },
	purple = { Color3.fromRGB(190, 140, 255), Color3.fromRGB(110, 60, 220), T.White },
}

UI.onClickSound = nil :: (() -> ())?

-- Rounded gradient button with hover/press animation.
function UI.button(props: { [string]: any }, onClick: (() -> ())?, style: ButtonStyle?): TextButton
	local palette = STYLES[style or "gold"]
	local defaults = {
		AutoButtonColor = false,
		BackgroundColor3 = T.White,
		Font = T.Title,
		TextColor3 = palette[3],
		TextSize = 18,
		Size = UDim2.fromOffset(140, 42),
		Text = "Button",
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = UI.new("TextButton", defaults, {
		UI.corner(10),
		UI.new("UIGradient", { Name = "Fill", Color = ColorSequence.new(palette[1], palette[2]), Rotation = 90 }),
		UI.stroke(T.White, 1, 0.85),
	})
	local scale = UI.new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		UI.tween(scale, 0.12, { Scale = 1.04 })
	end)
	button.MouseLeave:Connect(function()
		UI.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UI.tween(scale, 0.06, { Scale = 0.96 })
	end)
	button.MouseButton1Up:Connect(function()
		UI.tween(scale, 0.1, { Scale = 1.04 })
	end)
	if onClick then
		button.Activated:Connect(function()
			if button:GetAttribute("Disabled") then
				return
			end
			if UI.onClickSound then
				UI.onClickSound()
			end
			onClick()
		end)
	end
	return button
end

function UI.setButtonStyle(button: TextButton, style: ButtonStyle)
	local palette = STYLES[style]
	local fill = button:FindFirstChild("Fill") :: UIGradient?
	if fill then
		fill.Color = ColorSequence.new(palette[1], palette[2])
	end
	button.TextColor3 = palette[3]
end

-- Visually disables a button (it still exists so layouts stay stable).
function UI.setEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute("Disabled", not enabled)
	button.AutoButtonColor = false
	button.TextTransparency = if enabled then 0 else 0.45
	local fill = button:FindFirstChild("Fill") :: UIGradient?
	if fill then
		fill.Transparency = NumberSequence.new(if enabled then 0 else 0.5)
	end
end

function UI.progressBar(parent: Instance, color: Color3, height: number?): (Frame, (number) -> ())
	local bar = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, height or 10),
		BackgroundColor3 = Color3.fromRGB(14, 12, 18),
		Parent = parent,
	}, { UI.corner(6) })
	local fill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		Parent = bar,
	}, { UI.corner(6) })
	return bar, function(alpha: number)
		fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
	end
end

function UI.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

-- Card row used in most panel lists.
function UI.row(parent: Instance, height: number, order: number?): Frame
	return UI.new("Frame", {
		Size = UDim2.new(1, -6, 0, height),
		BackgroundColor3 = T.Row,
		LayoutOrder = order or 0,
		Parent = parent,
	}, { UI.corner(10), UI.stroke(T.Gold, 1, 0.8) })
end

return UI
