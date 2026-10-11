# Become An Millionaire RNG

A complete Roblox RNG simulator. Players start broke and roll for wealth tiers, from **Broke** (1 in 2) up to **Celestial Fortune** (about 1 in 22 million at base luck). They collect wealth auras, buy upgrades, rebirth for permanent bonuses, unlock luxury zones and climb the leaderboards.

All game logic runs on the server. The client only asks to roll and displays results.

---

## 1. Fastest way to play it

1. Open **`BecomeAnMillionaireRNG.rbxlx`** in Roblox Studio (double-click it, or use *File → Open from File*).
2. Press **Play**. The server builds the whole map, and the UI appears once your data loads.
3. To make saving work in Studio, open *Game Settings → Security* and turn on **Enable Studio Access to API Services**. Without it the game still runs, but it uses a temporary profile and shows a red "not saving" chip.

To publish, use *File → Publish to Roblox*. Section 6 has the full checklist.

## 2. Live-sync workflow with Rojo (port 34872)

```bash
cd roblox
rojo serve            # servePort 34872 is set in default.project.json
```

In Studio, open *Plugins → Rojo*, enter `localhost : 34872` and click **Connect**. Edits to files in `src/` then sync into Studio live. To rebuild the place file:

```bash
rojo build default.project.json -o BecomeAnMillionaireRNG.rbxlx
```

## 3. Project structure

```
roblox/
├─ default.project.json           Rojo project (serve port 34872)
├─ BecomeAnMillionaireRNG.rbxlx   Ready-to-open place file
├─ src/
│  ├─ shared/      → ReplicatedStorage.Shared
│  │  ├─ Config/   Rarities, Upgrades, GameConfig (zones, rewards, events),
│  │  │            Quests (+achievements), Monetization, Sounds
│  │  └─ Modules/  RNG, Formulas, NumberFormat, Remotes
│  ├─ server/      → ServerScriptService.Server (Script)
│  │  ├─ init.server.luau   bootstrap
│  │  ├─ Logic/    pure, unit-tested rules: Profile (schema/migrations), Roll,
│  │  │            Economy, Daily, Quests, Trade
│  │  ├─ Services/ DataService, RequestService, RollService, RewardService,
│  │  │            StatsService, MonetizationService, LeaderboardService,
│  │  │            AvatarService, TradeService
│  │  ├─ Map/      MapService (builds the world), Builder helpers
│  │  └─ Config/Codes.luau  (server-only: clients can't read codes)
│  └─ client/      → StarterPlayerScripts.Client (LocalScript)
│     ├─ State.luau, World.luau
│     ├─ UI/       UI kit, Hud (roll + reveal), Effects, Notifications,
│     │            Panels (manager), Scale (responsive)
│     └─ Panels/   Inventory, Upgrades, Rebirth, Daily, Quests, Zones,
│                  Leaderboard, Trade, Shop, Codes, Stats, Settings
├─ blender/build_models.py        Generates the 3D props (FBX)
├─ assets/models/                 Generated FBX files, Props.blend, preview.png
├─ tests/                         Lune test suites + Roblox runtime shim
└─ run-tests.sh                   Runs every automated check
```

## 4. How the game works

| System | Details |
|---|---|
| **RNG** | 11 rarities in `Config/Rarities.luau`. Each rarity has a weight of `1/chance`, and luck multiplies every non-common weight. The weights are normalised, so 2× luck makes every rare tier twice as likely relative to Broke. Rolls happen on the server using `Random.new()`. |
| **Roll flow** | The client sends `Request("Roll")`. The server checks the cooldown and computes stats (upgrades, rebirths, zone by **character position**, passes, boosts, events and server luck). It then rolls, grants cash and auras, updates quests and achievements, and announces rare results to the server. |
| **Reveal** | The animation length and effects scale with rarity: sparkle → coin burst → flash + shake → cinematic letterbox with big title → rainbow "celestial". Results from Multi-Millionaire up trigger a server-wide banner and a chat message. Every effect can be switched off in Settings. |
| **Upgrades** | The upgrades are Luck, Cash, Speed (cooldown), Multi-Roll (+1 roll per click, best result shown) and Passive Income (offline cash, capped at 8h). Each level costs `baseCost × growth^level`. |
| **Rebirth** | Costs $1M × 20ⁿ. It resets cash and upgrades, but Passive Income is kept. Each rebirth permanently adds **+50% cash** and **+10% luck**. Auras, zones and lifetime earnings are kept. |
| **Zones** | Luxury Hills, Neon Strip, Fortune Vault and Celestial Heights. Each adds luck and a cash multiplier, and later zones need rebirths. Bonuses apply only while you physically stand in the zone (checked on the server). Players get there through the portals or the Zones menu. |
| **Engagement** | 7-day login streak, free daily luck boost, playtime rewards counted per UTC day, 3 daily quests, repeatable quests with growing targets, 16 achievements (badge-ready), roll milestones, collection rewards, scheduled and weekend events, and codes. |
| **Data** | Session-locked `UpdateAsync` with retries, saves on autosave/leave/shutdown, and a versioned schema with migrations. A failed load **kicks** the player instead of overwriting their data. |
| **Leaderboards** | In-server leaderstats, a live "richest in server" board, and an all-time global board (OrderedDataStore, log-encoded so values above 2⁶³ fit). |
| **Trading** | Aura-only (cash can't be traded). Offers are validated server-side, accepting is tied to the offer version, and the swap is atomic and re-validated before both profiles save. |
| **Monetization** | 4 game passes and 4 developer products. `ProcessReceipt` deduplicates by PurchaseId and saves before granting. Items without a real ID show "Coming soon" and can't be bought. |

### Anti-exploit rules
- Clients never send luck, cash, rarity, results, prices or inventory. They only send an action name plus an id or setting, which the server validates.
- Every request has a per-action minimum interval and a global budget of 25 requests per second per player.
- Roll cooldown, zone bonuses (based on position and ownership), daily timestamps, quest progress and purchase grants are all decided on the server.

## 5. Customising

- **Add a rarity:** append it to `src/shared/Config/Rarities.luau` with a higher `chance` and `order` set to its position. The odds, index, auras, quests and UI all update automatically.
- **Balance:** edit `GameConfig.luau` (cooldown, rebirth, zones, rewards, events, titles) and `Upgrades.luau`.
- **Codes:** edit `src/server/Config/Codes.luau`. You can add an optional `expiresAt` (a unix timestamp).
- **Events:** add an entry to `GameConfig.Events` with `startsAt`/`endsAt` (UTC) and a luck multiplier. The weekend 1.5× event is automatic.
- **Badges:** create badges on the Creator Dashboard and paste their IDs into `badgeId` in `Config/Quests.luau`.
- **Sounds:** the defaults use built-in Roblox client sounds. For better audio, paste Creator Store sound IDs into `Config/Sounds.luau` (`ByRarity` gives each tier its own sound).
- **Add or change data fields:** add the field to `Profile.template()` and existing players receive the default automatically. For a breaking change, bump `GameConfig.DataVersion` and add a step to `MIGRATIONS` in `Logic/Profile.luau`.

## 6. Publishing checklist

1. In Studio, use *File → Publish to Roblox* (create a new experience).
2. In *Game Settings → Security*, enable **Studio Access to API Services**, then publish again.
3. **Monetization (optional):** on the Creator Dashboard, create the 4 passes (VIP, 2x Luck, Fast Roll, Instant Auto-Roll) and the 4 developer products (2x Luck 15m, 3x Luck 60m, Cash Briefcase, Server 2x Luck). Paste their IDs into `src/shared/Config/Monetization.luau`, rebuild or sync, and publish.
4. **Badges (optional):** create them and paste the IDs into `Config/Quests.luau`.
5. Set `GameConfig.Events[1].startsAt` to your launch date (or delete the event).
6. Add a thumbnail and icon, set the genre to Simulator, and make the experience public.

## 7. Blender models

See [`docs/BLENDER.md`](docs/BLENDER.md). In short, `blender --background --python blender/build_models.py` regenerates the FBX props. Import them with *Avatar/3D Importer* into `ServerStorage.Models`, and the map uses them automatically in place of the built-in part versions.

## 8. Testing

Run `./run-tests.sh` to execute every automated check. It needs [Lune](https://github.com/lune-org/lune), Rojo, and optionally luau-lsp with the Roblox definitions:

| Suite | What it covers |
|---|---|
| `shared.spec` (22) | Probabilities sum to 1, luck scaling, a 400k-roll Monte Carlo check against the analytic odds, cash ranges, stat stacking, events, costs, formatting |
| `server.spec` (24) | Profile migrations, roll, upgrades, rebirth, zones, codes, boosts, daily/playtime anti-exploit, quests, achievements, trade dupe protection |
| `map.spec` (11) | Runs the **real** map builder in a Roblox instance model (every property validated), checks the areas, prompts, spawns and part/light budget, and Blender prop replacement |
| `ui.spec` (21) | Boots the **real** client at phone resolution, opens every panel, presses every button, and plays every rarity's reveal, announcements and the trade flow |
| `server_runtime.spec` (19) | Boots the **real** server against an in-memory DataStore and covers joining, rolling, the cooldown, exploit attempts, rate limits, rebirth, daily-after-rejoin, session locks, outages, receipts, purchases, trades, auto-roll and BindToClose |

Things that can only be verified inside Roblox are listed in [`docs/STUDIO_TESTING.md`](docs/STUDIO_TESTING.md).
