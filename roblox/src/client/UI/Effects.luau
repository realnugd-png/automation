-- Screen effects and sounds. Every effect checks the player's settings, is
-- short, and never blocks input.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.UI)

local Effects = {}

local layer: Frame
local soundCache: { [string]: Sound } = {}

local function setting(name: string): boolean
	local profile = State.profile()
	if not profile then
		return true
	end
	return profile.settings[name] ~= false
end

function Effects.mount(screen: ScreenGui)
	layer = UI.new("Frame", {
		Name = "Effects",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = screen,
	})
end

function Effects.play(id: string, speed: number?, volume: number?)
	if not setting("sounds") or id == "" then
		return
	end
	local sound = soundCache[id .. tostring(speed)]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Parent = SoundService
		soundCache[id .. tostring(speed)] = sound
	end
	sound.PlaybackSpeed = speed or 1
	sound.Volume = volume or 0.5
	SoundService:PlayLocalSound(sound)
end

function Effects.flash(color: Color3, strength: number?, duration: number?)
	if not setting("effects") then
		return
	end
	local frame = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - (strength or 0.6),
		ZIndex = 51,
		Parent = layer,
	})
	UI.tween(frame, duration or 0.5, { BackgroundTransparency = 1 }).Completed:Connect(function()
		frame:Destroy()
	end)
end

local shaking = false
function Effects.shake(intensity: number, duration: number)
	if not setting("shake") or not setting("effects") or shaking then
		return
	end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	shaking = true
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		if elapsed >= duration or humanoid.Parent == nil then
			humanoid.CameraOffset = Vector3.zero
			connection:Disconnect()
			shaking = false
			return
		end
		local falloff = 1 - elapsed / duration
		local amount = intensity * falloff * 0.25
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, 0)
	end)
end

-- Coins/sparkles flying out from the centre of the screen.
function Effects.burst(color: Color3, count: number, origin: UDim2?)
	if not setting("effects") then
		return
	end
	local start = origin or UDim2.fromScale(0.5, 0.45)
	for _ = 1, count do
		local symbol = if math.random() < 0.6 then "$" else "✦"
		local piece = UI.label({
			Text = symbol,
			TextColor3 = if math.random() < 0.5 then color else UI.Theme.GoldLight,
			TextSize = math.random(18, 34),
			Font = UI.Theme.Title,
			Size = UDim2.fromOffset(40, 40),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = start,
			Rotation = math.random(-30, 30),
			ZIndex = 52,
			TextStrokeTransparency = 0.5,
			Parent = layer,
		})
		local angle = math.random() * math.pi * 2
		local distance = 0.15 + math.random() * 0.3
		local goal = UDim2.fromScale(
			start.X.Scale + math.cos(angle) * distance * 0.6,
			start.Y.Scale + math.sin(angle) * distance + 0.1
		)
		local time = 0.7 + math.random() * 0.6
		UI.tween(piece, time, { Position = goal, Rotation = math.random(-180, 180), TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad)
		task.delay(time, function()
			piece:Destroy()
		end)
	end
end

-- Letterbox bars for cinematic reveals.
function Effects.letterbox(duration: number)
	if not setting("effects") then
		return
	end
	local bars = {}
	for index, anchor in { 0, 1 } do
		local bar = UI.new("Frame", {
			AnchorPoint = Vector2.new(0, anchor),
			Position = UDim2.fromScale(0, anchor),
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = UI.Theme.Black,
			ZIndex = 49,
			BorderSizePixel = 0,
			Parent = layer,
		})
		bars[index] = bar
		UI.tween(bar, 0.35, { Size = UDim2.new(1, 0, 0.11, 0) })
	end
	task.delay(duration, function()
		for _, bar in bars do
			UI.tween(bar, 0.35, { Size = UDim2.new(1, 0, 0, 0) }).Completed:Connect(function()
				bar:Destroy()
			end)
		end
	end)
end

-- A one-shot particle burst around the local character (visible to this player).
function Effects.worldBurst(color: Color3, amount: number)
	if not setting("effects") then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(12, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(amount)
	task.delay(2, function()
		attachment:Destroy()
	end)
end

function Effects.enabled(name: string): boolean
	return setting(name)
end

return Effects
