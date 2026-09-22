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
  (`Player.scratch_damage`, default 2.0). Damage is applied in proportion to
  **mouse distance travelled**, so holding the button still does nothing — you
  must scrub. A radial brush (`brush_radius_cells`, default 21) applies damage
  with linear falloff.
- **Reveal at ~85% total health removed.** When about 85% of a panel's total
  foil health is gone (`reveal_threshold`, default 0.85), the panel
  auto-clears the remaining foil and shows the prize.
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
  unique name, design, tile count, level cap, XP curve and a weighted list of
  icons. New types should be added as data, not code.
- **Roll on first pickup.** The first time a ticket is picked up, each tile is
  rolled independently from that type's weighted icon table. The result is then
  fixed. (Pickup pockets the ticket in the backpack; see the day/night section.)
- **Reward is evaluated only after the whole ticket is scratched** (all tiles
  revealed). **All pairs score**: for every icon that appears 2+ times, that
  icon's prize is paid **once**. (With more tiles, e.g. 2 blood + 2 coins, you get
  both prizes.) Paying multiple times for triples is a special rule a future
  ticket type may have — not the default.
- **Leveling is automatic and per type.** Each type has its own XP and level
  (not shared). **Every level-up grants 1 normal skill point**, except level-ups
  to a multiple of 5 (**5, 10, ...**) grant **1 epic skill point instead**.
  Level caps are per type.
- **Coins are the currency** (not "gold"). No XP UI yet (the skill tree has its
  own panel).

### Suffering (first ticket type)

3 tiles. Level cap 10. Icons (id, weight, prize):

| Icon        | Weight | Prize          |
|-------------|--------|----------------|
| Empty       | 70     | nothing        |
| Blood       | 30     | 1 ticket XP    |
| Broken bone | 0      | 5 ticket XP    |
| Coin        | 0      | 1 coin         |
| Purse       | 0      | 5 coins        |
| Gold bar    | 0      | 100 coins      |

Weights of 0 mean the icon cannot roll yet (it exists for when progression/skill
trees raise its weight). Placeholder XP curve for the 9 level-ups up to cap 10:
`[1, 5, 10, 15, 20, 25, 30, 35, 40]` (tunable).

### Skill tree (Suffering)

Per-type skill tree, opened with **`T`** (closes with `T`/`ESC`); it frees the
mouse and locks player input while open, and cannot be opened while a ticket is
being held. Skills cost points and are chained: **Lucky Coin is the root**, and
the other two require Lucky Coin rank ≥ 1.

| Skill      | Effect                                   | Ranks | Cost   |
|------------|------------------------------------------|-------|--------|
| Lucky Coin | Coin icon weight +10 per rank            | 5     | normal |
| Wear Away  | Empty icon weight −15 per rank (min 0)   | 5     | normal |
| Blood Money| Double all prizes (coins **and** XP)     | 1     | epic   |

- Weight skills change the table **for future rolls only** — a ticket already
  generated keeps its icons.
- The prize multiplier is applied **at payout time**, so it affects a ticket
  even if it was rolled before the skill was bought.
- No respec/refund yet. Skill points and tree state are in-memory (reset on
  refresh), same as XP, until a save system exists.

## Day/night loop, hideout, scavenging & guests

The loop is **day = hide & scratch, night = scavenge the carnival and avoid the
guests.** The carnival is the existing map; the hideout is a safe room in the
same map (no scene switching).

- **Hybrid cycle.** *Day* is untimed; it lasts until the player sleeps at the
  hideout bed, which starts *Night*. *Night* runs a fixed real-time timer
  (`night_duration`, default **120 s**).
- **The hideout is safe.** Guests cannot enter it or detect the player inside. It
  holds the **bed** (sleep → start Night), the **stash** (deposit carried
  tickets) and the **gadget bench** (spend coins).
- **Day is safe, and you are shut in.** No guests, and the ground is empty (all
  nightly tickets have despawned). The player **starts in the hideout**, and the
  hideout door is **sealed during Day** — the only way out is to sleep and start
  Night. The door opens when Night starts and closes again at dawn.
- **Entering the hideout during Night ends the night immediately** and breaks
  dawn safely; you keep everything you carried. The 120 s timer is only a
  deadline for being *outside*.
- **Dawn:** every ticket still lying on the ground despawns and every guest
  despawns. At the start of each Night, `tickets_per_night` (default **10**)
  fresh tickets are placed at valid, reachable floor points.
- **Scratching can happen anywhere, anytime**, day or night.

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
around the carnival. They spawn at Night and despawn at dawn. First two types:

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
  player draws a guest to investigate; a positive lock starts a chase.
- **Capture:** a chasing guest within `capture_range` (default 1.2 m) catches the
  player → death (above).

### Gadgets

- Bought at the hideout gadget bench with **coins**; owned gadgets and charges
  are in-memory until a save system exists.
- **First pass: the Stun Device only.** Usable at Night, stuns guests within a
  short radius for a brief time, with limited charges per night. Exact
  radius/duration/charges are set at implementation.
- **Lethal gadgets and decoys are deferred.**

### First-pass tunables

`night_duration 120 s`, `tickets_per_night 10`, `backpack_capacity 5`,
`noise_sprint_radius 12 m`, `noise_walk_radius 4 m`, `capture_range 1.2 m`,
stun radius/duration/charges TBD. All are meant to be tuned.

**Status:** agreed design, not built yet.

### Deferred (do not build yet)

- Skill trees for types other than Suffering; respec/refund.
- Lethal gadgets, decoy gadgets and the full gadget-shop UI.
- Crouch / noise-stealth moves beyond sprint-vs-walk noise.
- Save system — XP, coins, skill points, stash, gadgets and the cycle are
  in-memory (reset on refresh).
- XP UI (the skill-tree panel exists, but no XP display).

## Controls (current)

- Click canvas to capture mouse, `WASD` move, `Shift` sprint, `Space` jump,
  mouse to look, `ESC` release mouse.
- Look at a floor ticket + `E` = pocket it. `Q` = take one from the backpack to
  hold-and-scratch. Held: hold left mouse and scrub; `E`/`ESC` = stow it.
- Hideout: `E` at the bed = sleep (start Night); `E` at the stash = deposit
  carried tickets; `E` at the gadget bench = buy gadgets.
- `G` = use the Stun Device (Night).
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
