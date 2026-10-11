local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NumberFormat = require(Shared.Modules.NumberFormat)

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local T = UI.Theme

local tab = "server"
local requested = false

return {
	title = "LEADERBOARDS",
	onOpen = function()
		if not requested then
			requested = true
			task.spawn(function()
				local result = State.request("GetLeaderboard")
				if result.ok and result.data then
					State.leaderboard = result.data
					State.leaderboardChanged:fire(result.data)
				end
			end)
		end
	end,
	refresh = function(content: ScrollingFrame)
		UI.clear(content)
		local bar = UI.new("Frame", {
			Size = UDim2.new(1, -6, 0, 42),
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Parent = content,
		}, {
			UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		})
		for _, option in { { "server", "Richest in Server" }, { "global", "All-Time (Global)" } } do
			UI.button({ Text = option[2], TextSize = 15, Size = UDim2.fromOffset(210, 38), Parent = bar }, function()
				tab = option[1]
				require(script.Parent.Parent.UI.Panels).refresh()
			end, if tab == option[1] then "gold" else "dark")
		end

		local entries = State.leaderboard[tab] or {}
		UI.label({
			Text = if tab == "server" then "Current cash of everyone in this server" else "Lifetime earnings across all servers (updates every 2 minutes)",
			TextSize = 13,
			TextColor3 = T.Muted,
			LayoutOrder = 1,
			Parent = content,
		})
		if #entries == 0 then
			UI.label({ Text = "Loading…", TextSize = 16, TextColor3 = T.Muted, LayoutOrder = 2, Parent = content })
		end
		local me = Players.LocalPlayer.UserId
		for rank, entry in entries do
			local row = UI.row(content, 40, 1 + rank)
			if entry.userId == me then
				row.BackgroundColor3 = Color3.fromRGB(70, 56, 20)
			end
			local medal = if rank == 1 then "🥇" elseif rank == 2 then "🥈" elseif rank == 3 then "🥉" else `#{rank}`
			UI.label({ Text = medal, TextSize = 18, Size = UDim2.fromOffset(50, 40), Position = UDim2.fromOffset(6, 0), Parent = row })
			UI.label({ Text = entry.name, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.6, -60, 1, 0), Position = UDim2.fromOffset(60, 0), Parent = row })
			UI.label({ Text = "$" .. NumberFormat.short(entry.value), Font = T.Title, TextSize = 17, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.4, -14, 1, 0), Position = UDim2.new(0.6, 0, 0, 0), Parent = row })
		end
	end,
}
