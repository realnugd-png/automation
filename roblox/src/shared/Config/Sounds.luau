--!strict
-- Sound ids. The defaults use sounds bundled with every Roblox client
-- (rbxasset://), so they work without uploading anything. For a more
-- polished feel, replace them with "rbxassetid://<id>" sounds from the
-- Creator Store (Toolbox -> Audio). Per-rarity reveal sounds are pitched
-- differently so each tier is audibly distinct.

return {
	Click = "rbxasset://sounds/clickfast.wav",
	Tick = "rbxasset://sounds/clickfast.wav",
	Reveal = "rbxasset://sounds/electronicpingshort.wav",
	Rare = "rbxasset://sounds/electronicpingshort.wav",
	Notify = "rbxasset://sounds/electronicpingshort.wav",
	-- Optional per-rarity overrides: [rarityId] = "rbxassetid://..."
	ByRarity = {} :: { [string]: string },
}
