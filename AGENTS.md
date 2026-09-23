# AGENTS.md — rules and source of truth

This file records the rules and decisions we have agreed on for
**horrorscratcher**. Treat it as the source of truth.

**Meta-rule (important):** if a request contradicts anything below, or asks for
something not described here, **do not silently change agreed behaviour**. First
confirm with the user that they really want the change. If they confirm, make
the change **and update this file** (and any related docs) in the same commit so
it stays accurate. Never let this file drift from reality.

---

## Scratch-off ticket (design rules)

These were agreed with the user and are the intended behaviour.

- **Found on the ground, held in hand.** Tickets are physical objects lying flat
  on the floor around the room, not on a pedestal. The player must find one.
- **Pocket, then hold to scratch.** Look at a floor ticket and press `E` to
  pocket it in the backpack (you keep moving). Press `Q` to take a ticket out of
  the backpack and hold it in front of the camera; while held, the mouse is freed
  and player movement/look is locked. Press `E` or `ESC` to stow the held ticket
  back in the backpack — it is never dropped back on the floor.
- **Three spaces per ticket.** Each ticket has 3 scratch panels; they are part
  of one ticket.
- **Foil health is the only gate.** There is no scratch stamina, durability, or
  other cost. Difficulty is purely how much foil health must be worn away.
- **Per-cell health, damage per distance moved.** Every foil cell has health
  (`scratch_hardness`, default 60). The player has a damage stat
  (`Player.scratch_damage`, default 0.6). Damage is applied in proportion to
  **mouse distance travelled**, so holding the button still does nothing — you
  must scrub. A radial brush (`brush_radius_cells`, default 21) applies damage
  with linear falloff.
- **Reveal at ~85% total health removed.** When about 85% of a panel's total
  foil health is gone (`reveal_threshold`, default 0.85), the panel
  auto-clears the remaining foil and shows the prize.
- **Foil fades with easing, not linearly.** Foil alpha is
  `1 − (1 − health_ratio) ^ foil_fade_power` (`foil_fade_power`, default 2.0), so
  the foil stays nearly opaque for most of the scratch and only becomes
  see-through near the end — the prize is not given away early.
- **Prizes come from the ticket type** (see below). The rolled result is rendered
  **under the foil from the very start**, so scratching progressively reveals it
  — it must not appear only at the moment of full reveal. Rewards are added to
  the player's coin total / the type's XP.
- **Tickets must not block movement.** The pickup collider is an `Area3D`, never
  a solid body.
- **Only the held ticket renders live** (SubViewport `UPDATE_ALWAYS`); grounded
  tickets render once for performance.

## Ticket types, resources & progression

Two resources: **Ticket XP** (tracked per ticket type) and **Coins** (global).

- **Ticket types are data-driven** (`TicketType` resource). Each type defines a
  unique name, design, tile count, level cap, XP curve, its own nightly spawn
  number (`spawn_per_night`), the first night it may appear (`min_night`), an
  optional special rule (`special`) and a weighted list of icons. New types
  should be added as data, not code.
- **Roll on first pickup.** The first time a ticket is picked up, each tile is
  rolled independently from that type's weighted icon table. The result is then
  fixed. (Pickup pockets the ticket in the backpack; see the day/night section.)
- **Reward is evaluated only after the whole ticket is scratched** (all tiles
  revealed). **All pairs score**: for every icon that appears 2+ times, that
  icon's prize is paid **once**. (With more tiles, e.g. 2 blood + 2 coins, you get
  both prizes.) Paying multiple times for triples is a special rule a future
  ticket type may have — not the default.
- **Every finished ticket also grants a flat 1 ticket XP** (`BASE_XP` in
  `scratch_ticket.gd`) on top of any prizes, so scratching always makes progress
  even when nothing pairs. The prize multiplier and the distance multiplier apply
  to it too, but the **level multiplier does not** (see below).
- **Leveling is automatic and per type.** Each type has its own XP and level
  (not shared). **Every level-up grants 1 normal skill point**, except level-ups
  to a multiple of 5 (**5, 10, ...**) grant **1 epic skill point instead**.
  Level caps are per type.
- **Levels multiply rewards.** The type's current level scales all of its future
  payouts — coins **and** icon XP prizes — by that level (`level_mult` = ×1 at
  level 1, ×2 at level 2, ×3 at level 3, ...). The per-level bonus is **100%** for
  now (`TicketType.level_reward_bonus`, default 1.0; tunable). It is applied
  **at payout time**, so it affects a ticket even if
  it was rolled before the level-up. The flat `BASE_XP` is exempt. The result
  text shows `xN level` when the multiplier is above ×1.
- **Coins are the currency** (not "gold"). The skill-tree panel shows the
  type's current XP and the XP needed for the next level (or "(max level)").

### Suffering (first ticket type)

3 tiles. Level cap 10. Icons (id, weight, prize):

| Icon        | Weight | Prize          |
|-------------|--------|----------------|
| Empty       | 70     | nothing        |
| Blood       | 0      | 2 ticket XP    |
| Broken bone | 0      | 5 ticket XP    |
| Coin        | 30     | 1 coin         |
| Purse       | 0      | 5 coins        |
| Gold bar    | 0      | 100 coins      |

Weights of 0 mean the icon cannot roll yet (it exists for when progression/skill
trees raise its weight). Coin starts unlocked; Blood is locked until its unlock is
bought. XP curve for the 9 level-ups up to cap 10:
`[5, 15, 35, 70, 130, 225, 375, 600, 900]` (total 2355, ~1.6× per level — cheap
early, demanding late; tunable). Spawns **10/night** from night 1.

### Fortune (second ticket type)

A rarer, occult-themed slip. 4 tiles. Level cap 8. **No skill tree yet**
(deferred), so all its icons are always rollable — the only locked ones are the
future prize icons. Icons (id, weight, prize):

| Icon    | Weight | Prize   |
|---------|--------|---------|
| Empty   | 50     | nothing |
| Token   | 50     | 5 coins |
| Eye     | 0      | 4 XP    |
| Skull   | 0      | 10 XP   |
| Chalice | 0      | 12 coins|
| Jackpot | 0      | 80 coins|

Only Empty and Token roll today; the rest wait for a future Fortune skill tree.
A pair of Tokens pays once (the normal pair rule). XP curve for the 7 level-ups up
to cap 8: `[5, 15, 35, 70, 130, 225, 375]`.

Nightly spawn: each type is placed independently from its `spawn_per_night`
(expected tickets per night) — the integer part is guaranteed and the fraction is
a per-night chance (e.g. `1.6` = 1 always + 60% for a second). Fortune is
**0.15/night** with `min_night = 3`, so it cannot appear on the first two nights;
Suffering is **10/night** with `min_night = 1` (`ticket_spawner.gd`,
`scenes/main.tscn`).

### The Long Run (third ticket type)

A running/endurance slip. 3 tiles. Level cap 10, Suffering's XP curve. Icons
(id, weight, prize):

| Icon      | Weight | Prize    |
|-----------|--------|----------|
| Empty     | 60     | nothing  |
| Footprint | 25     | 2 coins  |
| Sneaker   | 10     | 4 XP     |
| Medal     | 4      | 10 coins |
| Trophy    | 1      | 50 coins |

**Special rule — distance reward** (`TicketType.Special.DISTANCE_REWARD`): the
whole payout (coins and XP) is multiplied by how far the player is from the
hideout when the last panel is revealed — `1×` at the hideout, rising linearly to
`4×` at `120 m` or more (`TicketType.distance_multiplier`). Movement is locked
while a ticket is held, so the player picks the spot before scratching; the held
prompt shows the current multiplier. Spawns **0/night** for now (disabled until
it is switched on).

### Skill tree (Suffering)

Per-type skill tree, opened with **`T`** (closes with `T`/`ESC`); it frees the
mouse and locks player input while open, and cannot be opened while a ticket is
being held. Skills cost points and are chained: **Unlock Blood is the root**, and
the other five require Unlock Blood rank ≥ 1.

The panel is a **WoW-style talent tree** (`skill_tree_ui.gd` + `skill_node.gd`):
each skill is an icon node (`Skill.icon_color` / `Skill.glyph`) laid out by
dependency depth with connector lines between a skill and its prerequisite.
Hovering a node fills a tooltip (name, description, rank, cost, requirement) and
clicking it spends a point. Node borders show state — green = learnable, gold =
maxed, dark = locked — and connector lines light up once the prerequisite is
ranked.

| Skill       | Effect                                                 | Ranks | Cost   |
|-------------|--------------------------------------------------------|-------|--------|
| Unlock Blood| Blood weight +20 and Empty weight −20 (one-time)       | 1     | normal |
| Unlock Bone | Bone weight +20 and Empty weight −20 (one-time)        | 1     | normal |
| Lucky Coin  | Coin icon weight +10 per rank                          | 5     | normal |
| Wear Away   | Empty icon weight −15 per rank (min 0)                 | 5     | normal |
| Blood Value | Blood pairs pay +1 XP per rank                         | 5     | normal |
| Blood Money | Double all prizes (coins **and** XP)                   | 1     | epic   |

A single skill may carry a second icon modifier (`target_icon_2` / `amount_2`),
which is how Unlock Blood and Unlock Bone each raise their icon and lower Empty.
Blood and Bone cannot roll until their unlock is bought (Bone is the main XP
source, so this is what makes later levels affordable).

- Weight skills change the table **for future rolls only** — a ticket already
  generated keeps its icons.
- The prize multiplier is applied **at payout time**, so it affects a ticket
  even if it was rolled before the skill was bought.
- **Blood Value** (`Skill.Kind.ICON_XP_BONUS`) adds a flat XP bonus to its
  target icon's payout, also at evaluation time; Blood Money doubles it too.
- No respec/refund yet. Skill points and tree state are in-memory (reset on
  refresh), same as XP, until a save system exists.

## Day/night loop, hideout, scavenging & guests

The loop is **day = hide & scratch, night = scavenge the carnival and avoid the
guests.** The carnival is one 120×120 walled grounds (`scenes/carnival.tscn`,
instanced by `scenes/main.tscn`); the hideout is a metal room in its backlot (no
scene switching).

### Carnival layout

`scenes/carnival.tscn` is a **static, hand-editable** scene (no runtime
generation). It contains the ground, a fenced perimeter, and:

- **Entrance gate** (south) with pillars, marquee and a ticket booth.
- **Big top tent** (west), **Ferris wheel** (east, slowly rotating) and
  **Carousel** (centre, rotating) — the two rides spin via `ferris_wheel.gd` /
  `carousel.gd`.
- **Funhouse** (east), a row of five **game stalls** (north) and three **food
  carts**.
- **Lampposts** with amber lights along the midway, plus string lights.
- **Backlot** (north-west): dumpsters, crates, barrels — and the **hideout**.
- **Guest spawn markers** (8, group `guest_spawn`) and the hideout respawn marker
  (group `hideout_spawn`).

The hideout is a standalone 10×10 metal room with a door (east side) that is
sealed during Day and opens at Night, an interior trigger `Zone`, and the bed,
stash, gadget bench, workshop, trashcan, spawn marker and a warm light.

- **Hybrid cycle.** *Day* is untimed; it lasts until the player sleeps at the
  hideout bed, which starts *Night*. *Night* runs a fixed real-time timer
  (`night_duration`, default **120 s**).
- **The hideout is safe.** Guests cannot enter it or detect the player inside. It
  holds the **bed** (sleep → start Night), the **stash** (deposit carried
  tickets), the **gadget bench** (buy gadgets), the **workshop** (buy upgrades)
  and — once bought — a **trashcan** (discard the held ticket).
- **Day is safe, and you are shut in.** No guests, and the ground is empty (all
  nightly tickets have despawned). The player **starts in the hideout**, and the
  hideout door is **sealed during Day** — the only way out is to sleep and start
  Night. The door opens when Night starts and closes again at dawn.
- **Entering the hideout during Night ends the night immediately** and breaks
  dawn safely; you keep everything you carried. The 120 s timer is only a
  deadline for being *outside*.
- **Dawn:** every ticket still lying on the ground despawns and every guest
  despawns. At the start of each Night, every eligible type spawns its
  `spawn_per_night` count (integer part guaranteed, fraction rolled) at valid,
  reachable floor points; types below their `min_night` are skipped.
- **Scratching can happen anywhere, anytime**, day or night.

### Stamina

- Max **100**. Sprinting drains it over ~30 s (`sprint_stamina_seconds`), so once
  empty you drop to a walk until you rest.
- **Only sleeping restores stamina**: each sleep at the bed restores **5** (or
  **10** with the Restful Bed upgrade). It does not regenerate on its own.
- The HUD shows a stamina bar (`stamina` / `stamina_max` on the player).

### Hunger

**Status: not implemented (deferred).** The player has a **hunger bar** that
empties over time and slows movement as it drops:

- At **50% or above**, the player moves at full speed.
- Speed falls off linearly as hunger drops below 50%, reaching **50% speed at
  0%** hunger.

The exact drain rate, restoration (food?) and HUD placement are still to be
decided. Not built yet — see Deferred.

### Backpack, stash & loss

- `backpack_capacity` default **5**; the HUD shows carried / capacity.
- Carried tickets are **at risk**. Tickets deposited in the hideout stash are
  safe and unlimited.
- **Pocket, hold, stow.** `E` on a floor ticket pockets it instantly (no movement
  lock). `Q` takes a ticket from the backpack into the hand to scratch it; while
  held, movement/look lock and the mouse frees. `E`/`ESC` stows a half-scratched
  ticket back in the backpack (never on the floor). A fully revealed ticket is
  consumed and paid out as before.

### Death & consequences

Caught by a guest, **or** still outside when the night timer expires → death:

- Respawn in the hideout.
- **Lose every carried (undeposited) ticket.**
- Coins, ticket XP/levels, skill points, purchased gadgets and the stash are
  **safe**.
- The Night ends; there is no second chance that night.

### Guests (data-driven)

Guest types are data-driven resources (`GuestType`) with spawn points placed
around the carnival (8 markers; **4 Drifters + 2 Listeners** each Night). They
spawn at Night and despawn at dawn. First two types:

| Guest    | Movement | Senses                             |
|----------|----------|------------------------------------|
| Drifter  | patrol   | sight cone + hearing (the default) |
| Listener | patrol   | blind — noise only, but faster     |

- **Senses:** sight has a range, an angle and requires clear line of sight;
  hearing has a radius. **Noise** comes from movement: sprinting is loud
  (`noise_sprint_radius`, default 12 m), walking is quiet (`noise_walk_radius`,
  default 4 m), standing still is silent. There is no crouch yet. The Listener
  ignores sight and reacts only to noise.
- **Awareness:** *Unaware → Suspicious → Chasing → Caught*. Seeing or hearing the
  player draws a guest to investigate; a positive lock starts a chase. Detection
  is shown clearly: a guest turns **amber** when suspicious and **red** when
  chasing, and the HUD shows `?` / `SPOTTED!`.
- **Capture:** a chasing guest within `capture_range` (default 1.2 m) catches the
  player → death (above).

### Gadgets

- Bought at the hideout gadget bench with **coins**; owned gadgets and charges
  are in-memory until a save system exists.
- **First pass: the Stun Device only.** Bought once for **25 coins**; usable at
  Night with **3 charges per night** (refilled at the start of each Night). Press
  `G` to stun guests within **5 m** for **4 s**.
- **Lethal gadgets and decoys are deferred.**

### Upgrades (coins)

Bought at the hideout **workshop** with coins; levels are in-memory until a save
system exists.

| Upgrade        | Effect                        | Levels | Cost (coins)     |
|----------------|-------------------------------|--------|------------------|
| Scratch Damage | +25% scratch damage per level | 10     | 10 × (level + 1) |
| Movement Speed | +10% movement speed per level | 5      | 30 × (level + 1) |
| Trashcan       | Unlocks a hideout bin to discard held tickets | 1 | 1 |
| Bag Space      | +2 backpack slots per level   | 5      | 20 × (level + 1) |
| Brush Size     | +20% scratch brush radius per level | 5 | 15 × (level + 1) |
| Restful Bed    | Sleep restores 10 stamina instead of 5 | 1 | 7 |
| Fortune Charm  | +0.15 Fortune tickets spawned per night | 1 | 20 |
| Fortune Beacon | +0.5 Fortune tickets spawned per night  | 1 | 40 |
| Fortune Magnet | +2 Fortune tickets spawned per night    | 1 | 200 |

- Bonuses are multiplicative (`1.25^level`, `1.10^level`): level 2 damage is
  ×1.5625, level 3 ×1.953125, and so on.
- Scratch damage applies at scrub time; movement speed applies to walk and sprint
  alike.
- The three Fortune upgrades add to that type's nightly spawn count
  (`TicketType.spawn_per_night`) as a flat `spawn_bonus` (fractional parts roll as
  a per-night chance); they stack and are independent of each other.
- The workshop opens a panel (`E` at the bench) listing each upgrade with its
  level, cost and a Buy button; it frees the mouse and locks input like the skill
  tree, and closes with `ESC`.

### Trashcan

- Bought at the **workshop for 1 coin** (a one-level unlock); until bought it
  is absent from the hideout (no mesh, no collision, no interaction).
- Once bought, it is a bin in the hideout. While **holding** a ticket, standing
  within ~2.5 m of the trashcan and pressing `E` **discards** it (removed from
  the backpack, no reward) instead of stowing it; `ESC` always stows. Because
  holding locks movement, stand at the trashcan first, then take a ticket out.

### First-pass tunables

`night_duration 120 s`, `backpack_capacity 5`,
`noise_sprint_radius 12 m`, `noise_walk_radius 4 m`, `capture_range 1.2 m`,
stamina 100 over ~30 s of sprint (sleep restores 5, or 10 with Restful Bed),
stun cost 25 coins / radius 5 m / duration 4 s / 3 charges per night. Ticket
spawn numbers live on each type (Suffering 10/night, Fortune 0.15/night from
night 3). All are meant to be tuned.

**Status:** built (first pass); the values above are the current ones.

### Deferred (do not build yet)

- Skill trees for types other than Suffering; respec/refund.
- Lethal gadgets, decoy gadgets and the full gadget-shop UI.
- Crouch / noise-stealth moves beyond sprint-vs-walk noise.
- XP UI beyond the skill-tree panel's XP line (e.g. a HUD XP bar).
- Hunger bar (movement slowdown as it empties; see Hunger above).

## Save / load

- Single autosave slot at `user://horrorscratcher_save.json` (JSON). Web builds
  persist `user://` in IndexedDB, so progress survives reloads.
- **Saved:** coins, stamina, per-type XP/level/skill points/ranks, the backpack
  and stash (each ticket's type, rolled icons, foil health, damage and revealed
  state), owned gadgets + charges, workshop upgrade levels, and the
  nights-started counter (used for spawn gating).
- **Not saved:** the live world — phase, night timer, ground tickets and guests.
  Loading resumes at Day in the hideout with a fresh cycle.
- **Autosave** runs once at startup and after every meaningful change (pickup,
  deposit, stow, payout, discard, gadget use, purchase, sleep/start-night, dawn).
- **Reset:** the workshop panel has a "Reset save" button that wipes the file and
  all in-memory progress.

## Controls (current)

- Click canvas to capture mouse, `WASD` move, `Shift` sprint, `Space` jump,
  mouse to look, `ESC` release mouse.
- Look at a floor ticket + `E` = pocket it. `Q` = take one from the backpack to
  hold-and-scratch. Held: hold left mouse and scrub; `E`/`ESC` = stow it.
- Hideout: `E` at the bed = sleep (start Night); `E` at the stash = deposit
  carried tickets; `E` at the gadget bench = buy gadgets; `E` at the workshop =
  buy upgrades.
- `G` = use the Stun Device (Night).
- While holding a ticket: `E` near the trashcan = discard it (otherwise `E`/`ESC`
  stows it).
- `T` = open/close the Suffering skill tree (only when not holding a ticket).

---

## Workflow / engineering conventions

- **Engine:** Godot 4.4.1, GL Compatibility renderer. Server has no GPU; the
  game is exported to WASM and run in the browser.
- **Run:** `npm start` (headless export, ensure TLS cert, then serve) →
  **https://37.187.131.157.sslip.io:5997/**. A trusted Let's Encrypt cert is
  used (sslip.io maps that hostname to the server IP). Godot web needs a secure
  context, so HTTPS (or localhost) is required. Use the hostname, not the bare IP.
- **After changing game code:** re-run `npm run export` (the server serves from
  `export/web/` on disk). Hard-refresh the browser (`Ctrl+Shift+R`).
- **Validate before claiming done:** parse-check scripts with
  `~/bin/godot --headless --path . --check-only --script <file>`, exercise logic
  with a headless smoke test where practical, then `npm run export` and confirm
  the file is served. Remove temporary test scripts afterwards.
- **Never commit:** `certs/`, `export/`, `.godot/`. In particular never commit
  the TLS private key. These are in `.gitignore`.
- **Commit/push only when the user explicitly asks.** Match the existing commit
  message style.
- **Scene gotchas learned the hard way:**
  - In `.tscn`, `Transform3D(...)` lists the basis **rows**, not columns. A flat
    (floor-facing-up) quad is `Transform3D(1, 0, 0, 0, 0, 1, 0, -1, 0, x, y, z)`.
  - The floor collision shape is offset by `y = -0.5` so its top surface matches
    the visible floor mesh at `y = 0`. Keep both aligned.
- **Code style:** match the existing GDScript; no comments unless asked.
