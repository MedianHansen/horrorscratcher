# plan0.2.md — vertical-slice polish

Implementation plan for turning the working vertical slice into something that
**feels** good. Companion to `plan0.1.md` (the mechanics build-out). This is a
plan, not a contract; `AGENTS.md` stays the source of truth for behaviour, and
each phase updates `AGENTS.md` if it changes agreed behaviour.

## Goal

The loop (day hide/scratch, night scavenge/avoid guests) is mechanically
complete. plan0.2 makes it *readable, responsive and tense*: the player should
always understand what is happening, every action should have feedback, and the
night should feel dangerous. Work is split into independent phases so they can
land one at a time.

## Polish principles

- **Feedback for every verb.** Pick up, pocket, hold, scratch, reveal, payout,
  stow, discard, buy, sleep, get spotted, get caught — each needs an immediate
  sight/sound response.
- **Read the danger at a glance.** Awareness, proximity and time pressure should
  be visible without reading text.
- **No new mechanics in this plan** unless a phase explicitly says so. This is
  shine on top of the existing loop.
- **Web-first.** Everything must stay cheap enough for the browser WASM build
  (no heavy post-processing per frame, no per-frame allocations in `_process`).

## Target tunables (new, first pass)

| Name                        | Default | Notes                          |
|-----------------------------|---------|--------------------------------|
| `head_bob_amplitude`        | 0.04 m  | walk; scales up when sprinting |
| `head_bob_frequency`        | 9 Hz    |                                |
| `sprint_fov_kick`           | +8°     | lerped, not snapped            |
| `shake_capture`             | 0.35 s  | strongest shake                |
| `vignette_base`             | 0.15    | daytime / safe                 |
| `vignette_night`            | 0.45    | night baseline                 |
| `vignette_chase`            | 0.9     | while a guest is chasing       |
| `sfx_master_db`             | -6 dB   |                                |

All tunable and expected to move.

## Architecture notes

- **`Sfx` autoload** (new): a thin pool of `AudioStreamPlayer`s with
  `play(id, position?)` for 2D/3D one-shots, plus bus volume control. Keeps
  callers free of node plumbing. Registered in `project.godot [autoload]` next to
  `Game`; reach it by group lookup if `--check-only` complains (same rule as
  `Game`).
- **`Game` signals are the hook points.** Audio/juice should subscribe to the
  existing signals (`night_started`, `day_started`, `backpack_changed`,
  `gadgets_changed`, `player_died`) and the ticket signals (`panel_revealed`,
  `ticket_completed`, `stowed`, `finished`, `discarded`) rather than being called
  from every script. Add new signals only when there is no existing hook
  (e.g. `guest_alert_changed`).
- **Theme resource.** Build one `Theme` (`.tres`) for the whole UI instead of the
  current default-styled nodes, so panels/labels/buttons are consistent. Keep
  code-built panels (`skill_tree_ui.gd`, `upgrade_ui.gd`) using the same theme.
- **Camera effects live on `Player`.** Head-bob, sprint FOV and shake belong to
  the `Camera3D` in `main.tscn` (lines 43-46) and `player.gd`, driven from
  `_physics_process`; expose `add_shake(amount)` for other systems to call.
- **No post-processing requirement.** A vignette can be a full-screen
  `ColorRect` with a radial-gradient shader on the `UI` CanvasLayer, or a
  `TextureRect` overlay; prefer the cheapest that looks right in GL
  Compatibility.

## Build order

### Phase 1 — UI overhaul
The user called this out explicitly; do it first because later phases (toasts,
alert states) build on it.

**Decisions locked:** visual direction = **grimy carnival horror** (near-black /
charcoal base, desaturated purple, amber/rust accents, blood red for danger);
**two OFL fonts** (a display face for titles + a clean sans for body/HUD);
**icons stay as text glyphs for this pass** (see the icon task below).

- [x] Add a shared `Theme` (`scripts/ui_theme.gd`, code-built; applied to the
      root Window from `Game._ready`): fonts, colors, panel/button/progress
      styleboxes, plus `TitleLabel`/`HeadingLabel`/`MutedLabel`/`ChipLabel`/
      `GoldLabel`/`AlertLabel`/`DangerButton`/`CardPanel` variations.
- [x] Redesign the HUD (`scripts/hud.gd`, now built in code; old HUD nodes
      removed from `main.tscn`):
  - [x] top-left status panel with phase + countdown (red under 20 s);
  - [x] stamina bar with label and value, colour-graded;
  - [x] carried tickets and gadget charges as a bottom-right chip panel;
  - [x] a drawn crosshair that is always visible;
  - [x] alert (`?` / `SPOTTED!`) restyled with the display font.
- [~] Interaction prompt: restyled via the theme, but the keycap + verb pill
      (`[E] Pocket`) formatting is still TODO.
- [x] Rework `skill_tree_ui.gd` visuals: themed title/points, an XP-to-next bar,
      themed tooltip, rounded skill nodes with a learnable glow.
- [x] Rework `upgrade_ui.gd`: upgrade cards (`CardPanel`), themed title/coins,
      and a destructive-styled "Reset save" button.
- [x] Add a payout/result toast system (stacked toasts: `+N coins`, `+N XP`,
      `LEVEL UP`, `SPOTTED!`) fed by `Game.ticket_completed`.
- [x] Held-ticket info panel: while scratching, shows the type's XP bar and
      level plus every rollable icon's percentage chance (effective weight after
      skills) and reward. Driven by `Game.ticket_held` / `ticket_released`.
- [x] On finish the panel stays up and the XP bar animates to the new value
      (fill-then-reset on level-up) with gold particles at the fill front.
- [ ] **Icons = text glyphs for now.** Skills keep `Skill.glyph`; upgrades and
      HUD chips use glyphs too. A real icon-art pass is deferred (see Deferred):
      replace skill glyphs, upgrade icons and the **ticket-field icons**
      (`TicketIcon`) with sprites/atlases once art exists.
- [ ] Verify UI at 1280x720 and a smaller window; check `canvas_items` stretch
      still reads well. *(Pending in-browser visual pass.)*

### Phase 1b — UI polish pass
Follow-up to Phase 1, from the "still a bit amateurish" feedback. Icons deferred.

- [x] **Typography**: real hierarchy via Inter's variable weight axis
      (`FontVariation`): 400/500/600 weights, a type scale
      (12/13/14/15/18/28/34), letter-spacing on `SectionLabel`, and tabular
      figures (`tnum`) so numbers don't jitter.
- [x] **Spacing**: a 4 px scale (`SP_XS`…`SP_XL`) applied to panel padding,
      margins and separations.
- [x] **Material/depth**: softer larger panel shadows, consistent radii,
      `CardPanel`, themed `HSeparator`, amber accent rules under panel titles.
- [x] **Colour refactor**: ticket paper/foil, skill-node states and tree-link
      colours moved into `UiTheme` (no hardcoded UI colours left in scripts).
- [x] **HUD composition**: stamina moved into a panel with a section label,
      `CARRY` chip panel, drawn crosshair that recolours/expands with danger,
      and an atmosphere pass.
- [x] **Atmosphere**: full-screen vignette shader whose intensity rises at night,
      with suspicion/chase, and while scratching; a light focus-dim on hold.
- [x] **Motion**: panel open fade+scale (skill tree, workshop, scratch panel),
      animated XP-bar fill, alert pulse, skill-node hover pop, toast accent bar.
- [ ] **Deferred**: iconography (keycap prompts, coin/ticket/stun/stamina icons,
      skill/upgrade/ticket-field icons) — see Deferred.

### Phase 2 — Game feel / juice
- [x] Player camera: head-bob while moving (faster/stronger when sprinting, none
      when still), a subtle landing dip on ground contact, and a lerped sprint
      FOV kick. Tunables exported on `Player`.
- [x] Screen shake: `Player.add_shake(amount)` with trauma-squared decay via
      `FastNoiseLite` (offset + roll); strong on death/capture, light on being
      spotted and on ticket completion.
- [x] Settings menu (`O`, `scripts/settings_ui.gd`): head-bob and screen-shake
      toggles, persisted in the save (`Game.settings` / `settings_changed`) and
      applied live by `Player`.
- [x] Scratch feel (`scripts/scratch_ticket.gd`): foil-spark particles at the
      brush (HUD `spawn_sparks`), and a `TRANS_BACK` prize pop. Reveal now
      clears the remaining foil with a **diagonal white shine** (top-left →
      bottom-right) plus a **clockwise yellow outline trace** around the panel
      (`reveal_wipe_seconds` / `reveal_outline_seconds`).
- [x] Ticket-in-world feel: looked-at ground tickets lift and scale slightly
      (kept lying flat when idle, per AGENTS); pickup flies to the camera and
      shrinks before freeing.
- [~] Payout moment: coins count up in the HUD, the toast fires, and the ticket
      gives a completion shake. (The brief slow/zoom-in is not done.)
- [x] Stun feel: stunned guests pulse (squash/stretch) on top of the existing
      colour change. (The ground ring at the stun origin is not done.)
- [x] Proximity/tension overlay: the vignette intensifies at night, with
      suspicion/chase, and while scratching (built in Phase 1b).

### Phase 3 — Audio pass
Needs an asset decision before it can finish (see Open questions). Build the
plumbing first so it is not blocked.

- [ ] `Sfx` autoload + `AudioServer` buses (`Master`, `SFX`, `UI`, `Ambience`,
      `Music`); `Game` exposes master/SFX volume, and the workshop panel gets
      volume sliders (persisted in the save).
- [ ] Ambient bed: a low carnival-at-night loop + wind; day is quiet/safe.
- [ ] Player: footsteps whose cadence and loudness match walk vs sprint (this
      doubles as a **noise cue** so the player *hears* how loud they are), jump
      and land.
- [ ] Ticket: foil-scratch loop while the mouse is down and moving (volume tied
      to mouse speed), reveal sting, payout jingle, level-up fanfare, stow.
- [ ] Guests: alert stinger on `?` and on `SPOTTED!`, a proximity heartbeat that
      quickens with awareness, a capture sting.
- [ ] UI: hover/click/learn/buy/error ticks; distinct error sound for
      unaffordable.
- [ ] Bus ducking: duck `Ambience` under capture/payout stings.

### Phase 4 — Guest AI & tension
- [ ] Awareness feedback upgrade: guests emit a subtle "noticed" cue (sound +
      head turn) the instant they first become suspicious; add
      `guest_alert_changed(level)` so the HUD/overlay reacts without polling.
- [ ] Chase tension: while a guest is chasing, the Phase 2 vignette ramps and a
      heartbeat/breathing layer plays; escalate with proximity.
- [ ] Smarter search: on losing sight, guests search around the **last known
      position** (a few nearby points) before returning to patrol, instead of
      just a 3 s timer.
- [ ] Patrol polish: authored route loops per spawn marker (or a light
      waypoint graph) so guests move with intent instead of random wander;
      keep the existing raycast-sampled fallback for the open carnival.
- [ ] Stun feedback: stunned guests show a clear state (sparks/pose) and
      recover with a short "dazed" pause before re-acquiring.
- [ ] Tune `hear_radius`/`sight_range` against the new walk/run rings and the
      vignette so "sneaking past" is a real, readable decision.
- [ ] Keep the `H` debug overlays in sync with any sense changes.

### Phase 5 — Clarity & onboarding
- [ ] First-run flow: a short objective banner per phase ("Sleep to start the
      night", "Find tickets on the ground", "Get back before dawn"), shown once
      and dismissible.
- [ ] Contextual hints the first time each verb is available (pocket, hold,
      scratch, stash, buy), stored as "seen" flags in the save.
- [ ] A controls/help overlay (e.g. `F1` or `Tab`) listing the current bindings,
      including the `H` debug toggle.
- [ ] Make consequences legible: on death, state exactly what was lost
      (carried tickets) and what was kept; on level-up, show the skill point
      gained (normal vs epic).
- [ ] Add a small "type XP / next level" readout to the HUD or the skill panel
      header so progression is visible outside the tree.
- [ ] Clearer wording pass over all prompts/tooltips; keep AGENTS controls list
      authoritative.

### Phase 6 — Bugs, robustness & performance
- [ ] Save/load hardening: version the save, tolerate missing/renamed fields
      (already partly done), and add a headless round-trip smoke test.
- [ ] Edge cases: holding a ticket when dawn ends the night; backpack full vs
      deposit; trashcan discarded then workshop reset; guest caught mid-stun;
      tickets spawning inside geometry.
- [ ] Web performance: confirm only the held ticket uses
      `UPDATE_ALWAYS`; profile guest count vs frame time; avoid per-frame
      allocations in `_process`/`_physics_process`; check the `H` overlays and
      Phase 2 particles are cheap.
- [ ] Input robustness: handle losing/regaining pointer lock, alt-tab, and the
      mouse-free UI states cleanly; ensure `ESC` never leaves the player stuck.
- [ ] Consistency: one prompt/ownership path, no lingering prompts after stow or
      death.
- [ ] Final in-browser sanity run of the whole loop at both day and night.

## Verification (per phase)

1. Parse-check every touched/new script:
   `~/bin/godot --headless --path . --check-only --script <file>`.
2. Where practical, add a temporary headless smoke test for logic (save
   round-trip, awareness transitions, spawn counts), then delete it.
3. `npm run export`, confirm the build is served, hard-refresh
   (`Ctrl+Shift+R`).
4. In-browser pass for the phase's feature; watch the web console for errors and
   frame-time regressions.
5. Update `AGENTS.md` (and `README.md` if controls/gameplay changed) whenever a
   phase alters agreed behaviour, in the same commit.

## Deferred (not in plan0.2)

- **Icon art pass.** Replace text glyphs with real icons for **skills**
  (`Skill.glyph`), **upgrades** (workshop cards) and **ticket fields**
  (`TicketIcon`) once assets exist. Phase 1 only restyles the glyph rendering.

## Open questions / TBD

- **Audio assets:** where do sounds come from? Options: a CC0/free SFX pack
  committed under `assets/audio/`, or Godot-procedural synthesis
  (`AudioStreamGenerator`) for placeholder blips. Needs a decision before
  Phase 3 can finish; plumbing can land first.
- **Visual identity:** are we keeping the current primitive shapes, or is an
  art/model pass (the Unreal carnival pack in `assets/data` is not usable in
  Godot as-is) in scope for the slice? UI theme colors should follow the answer.
- **Vignette/post:** confirm a shader overlay is acceptable, or restrict to
  `CanvasModulate`/`ColorRect` tinting for GL Compatibility safety.
- **Patrol routes:** authored waypoints vs the current random wander; depends on
  how much the carnival layout is expected to change.
- **Difficulty knobs:** should polish phases also rebalance (spawn counts,
  stamina, costs), or keep plan0.1 values until a dedicated balance pass?
