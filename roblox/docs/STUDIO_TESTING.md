# Testing in Roblox Studio

The automated suites (`./run-tests.sh`) execute the real server, client and map code against a Roblox instance model with an in-memory DataStore. These are the things that only a real Roblox session can confirm, with exact steps for each.

## Setup
- In *Game Settings → Security*, enable **Studio Access to API Services**. Otherwise data uses a temporary, unsaved profile, shown by a red chip on screen.
- Open the Output window (*View → Output*) and check for red errors after pressing Play.

## 1. Core loop (single player)
| Step | Expected |
|---|---|
| Press Play | Loading screen, then the HUD: cash bar, menu, ROLL button, recent rolls |
| Click **ROLL** or press **R** | Names cycle, then the result appears with cash counting up and the history updates |
| Click ROLL repeatedly | The cooldown bar fills and early clicks are ignored |
| Open each menu button | Every panel opens, and X or the same button closes it |
| Buy a Lucky Charm upgrade | Cash drops and the luck chip increases |
| Open Settings and turn off Visual effects | Rare reveals no longer flash or shake |

To see rare effects quickly, temporarily add a test code to `src/server/Config/Codes.luau`:
`TESTLUCK = { reward = { luckBoost = { mult = 100000, minutes = 5 } } },`
Redeem it in the Codes menu and the rare tiers become common. Remove the code before publishing.

## 2. Saving
1. Roll a few times, note your cash, and stop the test.
2. Press Play again. Cash, rolls, upgrades and settings should all be restored.
3. Claim the daily reward, stop, and press Play again. The Daily button should say "NEXT IN …", so it can't be claimed twice.

## 3. Multiplayer, trading and announcements
Go to *Test → Clients and Servers → 2 Players → Start*.
- Each player's wealth title and rebirth tag show above their character.
- The "Richest in Server" board in the leaderboard plaza (south) lists both players.
- **Trade:** Player 1 opens Menu → Trade → Send Request, and Player 2 clicks Accept. Both add auras with + / −. Changing an offer clears both "ready" states, and both pressing Accept swaps the items. To get auras for testing, roll until you hit Comfortable or better.
- **Announcements:** when one player rolls Multi-Millionaire or better, the other sees a banner and a chat message.

## 4. Mobile and tablet layout
In the Device Emulator (*Test → Device*), try iPhone 14 landscape and iPad:
- The menu, roll button, history and top bar must not overlap or sit under the thumbstick or jump button.
- Panels fit on screen and scroll.

## 5. Map
Walk or fly around the whole map:
- North is the Golden Bank. Walk in through the door to reach the vault with Daily Rewards and Codes.
- East is the Neon Strip, with the slot-machine upgrade terminals (press E).
- West is the mansion, with the Rebirth shrine in the front garden.
- South is the leaderboard plaza, followed by the Portal Hall.
- Touching a locked portal shows a warning. Unlock Luxury Hills from the Zones menu, touch its portal again, and you're teleported there with the luck chip showing the zone. The gold portal on the island brings you back.

## 6. Purchases (after adding real IDs)
Studio uses test purchases, so no Robux are spent.
- Buy each pass. After the prompt it shows OWNED and its perk applies. VIP adds the VIP aura in the Index and a `[VIP]` chat tag.
- Buy each product. The boost or cash is granted once, and buying again grants again (it's consumable).

## 7. Global leaderboard
The global board needs a **published** place with API access. It updates every 2 minutes.
