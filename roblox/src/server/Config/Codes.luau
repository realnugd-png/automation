--!strict
-- Redeemable codes. Server-only (clients cannot read ServerScriptService), so
-- codes can't be discovered by exploiters. Codes are case-insensitive; write
-- them here in UPPERCASE. `expiresAt` is an optional UTC unix timestamp.

local Codes: { [string]: { reward: { cash: number?, scaledCash: number?, luckBoost: { mult: number, minutes: number }? }, expiresAt: number? } } = {
	RELEASE = { reward = { cash = 5_000 } },
	LUCKY = { reward = { luckBoost = { mult = 2, minutes = 15 } } },
	MILLIONAIRE = { reward = { scaledCash = 25, luckBoost = { mult = 1.5, minutes = 10 } } },
}

return Codes
