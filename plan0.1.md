# plan0.1.md — day/night survival loop

Implementation plan for the design agreed in `AGENTS.md`
("Day/night loop, hideout, scavenging & guests"). This is a plan, not a
contract; `AGENTS.md` stays the source of truth for behaviour.

## Goal

Day = hide and scratch. Night = scavenge the carnival for tickets and avoid the
guests. Players can **win time** by collecting tickets at night and **pay** for
risk by carrying them until they are back home.

## Target tunables (first pass)

| Name                  | Default |
|-----------------------|---------|
| `night_duration`      | 120 s   |
| `tickets_per_night`   | 10      |
| `backpack_capacity`   | 5       |
| `noise_sprint_radius` | 12 m    |
| `noise_walk_radius`   | 4 m     |
| `capture_range`       | 1.2 m   |
| stun radius/duration/charges | TBD at implementation |

## Architecture notes

- **`Game` autoload** (new, registered in `project.godot` `[autoload]`) is the
  owner of cycle state, backpack, stash, gadget state and tunables. It exposes
  signals (`phase_changed`, `backpack_changed`, `player_died`) so the HUD,
  lighting, spawner and guests can react without hard references.
  - `Progression` stays a static `class_name`; `Game` is the *instance* layer
    that needs signals and per-run containers.
  - `--check-only` must still resolve `Game`; if the headless checker complains,
    fall back to a group lookup (`get_tree().get_first_node_in_group("game")`).
- **Ticket state must survive being pocketed and stowed.** Today
  `scratch_ticket.gd` rolls icons and keeps per-cell foil `health` inside the
  scene. Extract that into a small `TicketData` (RefCounted): `type`, per-panel
  `icon` ids, per-panel `health` arrays, `damage`, `revealed`. The 3D scene
  becomes a *view* that reads/writes a `TicketData`.
  - Pocket: create `TicketData`, roll once, store in `Game.backpack`, free the
    scene.
  - Hold (`Q`): instantiate the scene and attach the stored `TicketData`.
  - Stow (`E`/`ESC`): write state back to the `TicketData`, free the scene.
  - Finish: award, then remove the `TicketData` from backpack.
  - Simpler fallback if time-boxed: keep each pocketed ticket node alive but
    hidden/detached. Less clean for the stash and save system; avoid if possible.
- **Spawn points / guest paths need no NavMesh yet.** First pass uses explicit
  `Marker3D` spawn points and patrol waypoint loops. Reachability of ticket
  spawns is checked with a downward raycast + minimum-distance rules from the
  hardcoded candidate set, not pathfinding.
- **Hideout** is a room added to `scenes/main.tscn`: floor/walls on the existing
  `y = 0` plane, a roof quad, a door opening. An `Area3D` covering the interior
  detects the player entering during Night.
- **Rendering rules stay:** only the held ticket uses SubViewport
  `UPDATE_ALWAYS`; grounded tickets render `UPDATE_ONCE`. Ticket pickup colliders
  remain `Area3D` (never solid).

## Build order

### Phase 0 — groundwork
- [x] Add input actions to `project.godot`: `use_gadget` (`G`),
      `take_ticket` (`Q`). Reuse `interact` (`E`) for all world interactions.
- [x] Add `Game` autoload + `scripts/game.gd` with phase enum
      (`DAY`/`NIGHT`), tunables, and empty backpack/stash/gadget state.
      *Done as autoload; scripts reach it via the `"game"` group because
      `--check-only` does not resolve autoload identifiers.*
- [x] Add HUD labels to `main.tscn` UI: carried/capacity, phase, night timer,
      gadget charges, death message (`scripts/hud.gd`).

### Phase 1 — day/night, hideout, timer, dawn
- [x] Build the hideout room in `scenes/main.tscn` (walls + roof + door gap).
      Watch the `Transform3D` rows gotcha for flat/roof quads, and keep the
      floor collision offset `y = -0.5` aligned with the floor mesh.
- [x] `scripts/hideout_zone.gd`: interior `Area3D` → on player enter during
      Night call `Game.end_night(safe = true)`. *(Area uses `collision_layer = 0`
      so it never blocks interactable raycasts; `collision_mask = 1` still
      detects the player body — verified headless.)*
- [x] `scripts/bed.gd`: `E` interactable → `Game.start_night()` (only during
      Day). *(Built on a reusable `scripts/interactable.gd` base class.)*
- [x] Cycle logic in `Game`: start Night (reset `night_duration`), tick down
      only while the player is outside, expire → dawn caught/teleport, enter
      hideout → dawn safe.
- [x] Debug lighting: dim the `DirectionalLight3D` (and optionally tint
      `WorldEnvironment`) during Night, restore at Day
      (`scripts/day_night_light.gd`).
- [x] Dawn: despawn all ground tickets and all guests. *(Guests come in
      Phase 4; the group sweep is already in place. Ground tickets self-despawn
      via `day_started`. Tickets do not respawn until Phase 3.)*
- [x] HUD: show phase and remaining night seconds (done in Phase 0).
- [x] Rule change (post-Phase 2): the player **starts in the hideout** and the
      door is **sealed during Day**, opening at Night — `scripts/hideout_door.gd`,
      player spawn moved inside, `Game.player_in_hideout` defaults `true`.

### Phase 2 — backpack, pocket/hold/stow, stash
- [x] `scripts/ticket_data.gd` (`TicketData`, `class_name`) as described above.
- [x] Refactor `scripts/scratch_ticket.gd`:
  - ground ticket: `E` = pocket into `Game.backpack` (capacity-checked), then
    `queue_free()`; keep the "look at it" prompt.
  - hold mode: `Q` (or explicit `hold(data)`) brings a ticket into hand; keep
    the existing mouse-free / input-lock / scrub behaviour.
  - replace `_put_down()` dropping to floor with **stow into backpack**.
  - `_finish_ticket()` must remove the `TicketData` from the backpack.
  *Done. The scene has a `GROUND`/`HELD` mode; `Game` owns hold/stow via the
  `stowed`/`finished` signals. Added a prompt-ownership rule in `player.gd`
  (`show_prompt(text, owner)`) so ground tickets cannot wipe the held prompt.*
- [x] `Game` backpack API: `add_ticket`, `remove_ticket`, `take_for_scratch`,
      `stow`, `deposit_all`; emit `backpack_changed`.
  *Implemented as `pocket`, `deposit_all`, `take_for_scratch`, plus the
  `stowed`/`finished` handlers (`cancel_held` on death).*
- [x] `scripts/stash.gd`: `E` interactable in the hideout → `Game.deposit_all()`.
- [x] HUD: carried / capacity readout.
- [x] Guard: cannot open the skill tree while holding a ticket (already true) —
      keep that check working after the refactor.

### Phase 3 — nightly ticket spawner
- [x] Remove the six hardcoded `Ticket1..6` nodes from `scenes/main.tscn`.
- [x] `scripts/ticket_spawner.gd`: on Night start, place `tickets_per_night`
      tickets at valid candidate points (inside walls, not inside obstacles, not
      in the hideout, minimum spacing, reachable by a straight floor raycast).
  *Implemented with rejection sampling: a downward ray from `y = 6` must land on
  the floor (`y <= 0.5`), which automatically rejects obstacle tops and the
  hideout roof; plus 3 m minimum spacing and a random yaw. No hardcoded obstacle
  list.*
- [x] On dawn, free every un-pocketed ground ticket.
- [x] Keep ticket type assignment data-driven; allow weighted type selection
      later, but Suffering is the only type for now.
  *Spawner has an exported `ticket_type`; weighted selection is still future work.*

### Phase 4 — guests, senses, capture, death
- [x] `scripts/guest_type.gd` (`GuestType`, `class_name extends Resource`) with
      `type_name`, `speed`, `sight_range`, `sight_angle_deg`, `can_see`,
      `hear_radius`, `capture_range`, path colour.
  *Added `color` and `chase_speed`.*
- [x] `.tres` instances in `guest_types/`: **Drifter** (sight + noise) and
      **Listener** (blind, noise-only, faster).
- [x] `scripts/guest.gd` (`CharacterBody3D`): patrol waypoint loop, awareness
      FSM `UNAWARE → SUSPICIOUS → CHASING → CAUGHT`.
      - sight: range + angle + clear-line-of-sight raycast;
      - hearing: distance to player ≤ noise radius;
      - capture: while chasing, distance ≤ `capture_range` → `Game.on_caught()`.
  *Uses random wander targets (floor-raycast sampled) instead of authored
  waypoints. LOS ray aims at the player's `Camera3D`; capture uses **horizontal**
  distance (the guest origin is at its feet).*
- [x] Player noise: expose `current_noise_radius()` from `player.gd` based on
      moving + sprint state (`noise_sprint_radius` / `noise_walk_radius` / 0).
- [x] Spawn points as `Marker3D` nodes; spawn at Night start, despawn at dawn.
  *`scripts/guest_spawner.gd` with 2 Drifters + 1 Listener and six markers.*
- [x] `Game.on_caught()`: teleport player to hideout, clear backpack (undeposited
      tickets only), end Night, show a death message. Keep coins / XP / stash /
      gadgets.
- [x] Hideout is safe: guests never path into it and cannot detect inside.
  *`guest._sense` bails while `Game.player_in_hideout`.*

### Scene-format gotcha (learned in Phase 4)
- In `.tscn`, node groups must be in the **node header**
  (`[node name="X" type="Y" parent="Z" groups=["g"]]`), not a separate
  `groups = [...]` property line — the latter is silently ignored. This was also
  silently breaking the hideout respawn marker.
- Toggling a `CollisionShape3D.disabled` from a signal handler can hit
  "can't change state while flushing queries"; use `set_deferred("disabled", …)`.

### Phase 5 — stun gadget & bench
- [x] `scripts/gadget.gd` (`Gadget`, `class_name extends Resource`): id, title,
      coin cost, charges per night, stun radius, stun duration. First entry:
      Stun Device (`gadgets/stun_device.tres`).
- [x] `scripts/gadget_bench.gd`: `E` interactable in the hideout; buy the gadget
      for coins, show owned state.
  *Built on `Interactable` with an overridable `_prompt_text()` showing cost /
  affordability / owned state.*
- [x] `player.gd`: `G` uses the gadget if charges remain; `Game` tracks charges
      and resets them each Night.
- [x] `guest.gd`: stunned state (stop moving, no detection) for the duration.
- [x] HUD: gadget charges.

### Round 2 changes (post-Phase 5)
- [x] Clearer detection feedback: guest body turns amber (suspicious) / red
      (chasing); HUD shows `?` / `SPOTTED!`.
- [x] Capture now triggers on contact regardless of awareness state (previously
      only while `CHASING`, so a searching guest could bump into the player with
      no effect).
- [x] Base `Player.scratch_damage` 2.0 → 0.6.
- [x] Uniform scratch-field background (`PANEL_COLOR`); foil darkened
      (`FOIL_COLOR`) for strong contrast.
- [x] Coin upgrades + workshop panel: Scratch Damage (+25%/level, 10 levels) and
      Movement Speed (+10%/level, 5 levels).
- [x] Trashcan: bought at the workshop for 1 coin (one-level unlock); discards
      the held ticket (`E` within ~2.5 m). Absent until bought.

### Round 3 — carnival scene
- [x] Rebuilt the map as a 120×120 walled carnival (`scenes/carnival.tscn`,
      static/hand-editable) instanced by `scenes/main.tscn`.
- [x] Attractions: entrance gate + ticket booth, big top tent, Ferris wheel
      (rotating), carousel (rotating), funhouse, five game stalls, three food
      carts, lampposts + string lights, and a backlot (dumpsters/crates/barrels).
- [x] Hideout rebuilt as a standalone 10×10 metal room in the backlot, with all
      interactables (bed, stash, gadget bench, workshop, trashcan, spawn, light).
- [x] `scripts/ferris_wheel.gd` / `scripts/carousel.gd` spin the rides.
- [x] Reworked spawns for the larger map: ticket bounds `MAP_HALF 28 → 56`, guest
      wander bounds `26 → 56`, 8 guest markers, 4 Drifters + 2 Listeners.
- [x] `main.tscn` reduced to an orchestrator (environment, sun, carnival instance,
      player, UI, spawners).

### Round 4 — Suffering skill tree tweak
- [x] New root skill **Unlock Coin**: Coin weight +20, Empty weight −20
      (one-time). `Skill` gained `target_icon_2` / `amount_2` so one skill can
      modify two icons.
- [x] Lucky Coin, Wear Away and Blood Money now all require Unlock Coin.

### Round 5 — WoW-style talent tree HUD
- [x] `skill_tree_ui.gd` rebuilt as a talent tree: nodes laid out by dependency
      depth with connector lines, a side tooltip, and click-to-learn.
- [x] `skill_node.gd` draws each node (icon colour + glyph, rank badge, state
      border: green learnable / gold maxed / dark locked); `skill_tree_lines.gd`
      draws the links.
- [x] `Skill` gained `icon_color` and `glyph`; Suffering's four skills set them.

### Round 6 — stamina & three more upgrades
- [x] Stamina: max 100, sprint drains it over ~30 s; empty forces a walk. Only
      sleeping restores it (5, or 10 with Restful Bed). HUD stamina bar.
- [x] Workshop upgrades: Bag Space (+2 slots/level, 5, 60×(lvl+1)), Brush Size
      (+20% radius/level, 5, 35×(lvl+1)), Restful Bed (sleep 5→10, 1 level, 80).
- [x] Backpack capacity, scratch brush radius and sleep restore now read from the
      upgrade state.

### Round 7 — balancing
- [x] Trashcan cost 50 → 1 coin.
- [x] Suffering XP curve → `[1, 3, 7, 14, 26, 45, 75, 120, 180]` (soft ramp,
      total 471): cheap early, strongly back-loaded for later levels.
- [x] New skill **Unlock Bone** (Bone weight +20, Empty −20; requires Unlock
      Coin) so the higher-XP Bone icon becomes rollable and later levels are
      affordable.

### Round 8 — save / load
- [x] JSON autosave at `user://horrorscratcher_save.json`: coins, stamina,
      per-type progression, backpack/stash tickets (with foil state), gadgets,
      upgrades. World state is not saved (loads at Day in the hideout).
- [x] `Game.save_game` / `load_game` / `reset_save`; `TicketData.to_dict` /
      `from_dict`; `Progression.all_profiles` / `set_profiles` / `reset_all`.
- [x] Autosave on startup and after pickups, deposits, stows, payouts, discards,
      gadget use, purchases, sleep and dawn; also on window close.
- [x] "Reset save" button in the workshop panel.

## Verification (per phase)

1. Parse-check every touched/new script:
   `~/bin/godot --headless --path . --check-only --script <file>`.
2. Where practical, add a temporary headless smoke test (e.g. drive `Game`
   through start-night → capture → respawn, or spawn tickets and assert count),
   then delete it.
3. `npm run export`, confirm the build is served, hard-refresh
   (`Ctrl+Shift+R`).
4. Sanity pass in-browser: phase switches, timer, pocket/stow, stash, one guest
   detection, one capture, stun.
5. Update `AGENTS.md` (and `README.md` controls/gameplay) if anything deviates.

## Open questions / TBD

- Guest patrol routes and spawn count per night.
- Upgrade coin costs/curves (currently `base × (level + 1)`).
- Whether ticket types can be weighted per night later (multiple types).
- Save system (deferred); everything is in-memory for now.
