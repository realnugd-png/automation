-- Tiny helpers for building map geometry in code.

local Builder = {}

export type PartProps = { [string]: any }

local DEFAULTS = {
	Anchored = true,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
	CastShadow = true,
}

function Builder.part(parent: Instance, props: PartProps, className: string?): BasePart
	local part = Instance.new((className or "Part") :: any) :: BasePart
	for key, value in DEFAULTS do
		(part :: any)[key] = value
	end
	for key, value in props do
		if key ~= "Shape" then
			(part :: any)[key] = value
		end
	end
	if props.Shape then
		(part :: any).Shape = props.Shape
	end
	part.Parent = parent
	return part
end

function Builder.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Builder.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- A sign: thin part with a SurfaceGui label on its front (-Z) face.
function Builder.sign(parent: Instance, cframe: CFrame, size: Vector3, text: string, options: { [string]: any }?): BasePart
	local opts = options or {}
	local board = Builder.part(parent, {
		Name = "Sign",
		Size = size,
		CFrame = cframe,
		Color = opts.background or Color3.fromRGB(20, 20, 24),
		Material = opts.material or Enum.Material.SmoothPlastic,
		CastShadow = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = opts.face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.pixelsPerStud or 30
	gui.LightInfluence = 0
	gui.Brightness = opts.brightness or 1.5
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = opts.font or Enum.Font.GothamBlack
	label.TextColor3 = opts.textColor or Color3.fromRGB(255, 215, 90)
	label.TextStrokeTransparency = 0.6
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	return board
end

function Builder.light(parent: BasePart, color: Color3, range: number, brightness: number?)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1
	light.Shadows = false
	light.Parent = parent
	return light
end

function Builder.prompt(parent: BasePart, actionText: string, objectText: string, panel: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("OpenPanel", panel)
	prompt.Parent = parent
	return prompt
end

return Builder
