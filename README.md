# horrorscratcher — Godot project (dev-server, no GPU)

Godot 4 first-person game. The server has no GPU, but Godot web exports are
WASM+JS that run in the **browser**, so the server only serves static files.

## Run it (self-contained — no Laravel needed)

```bash
cd /home/debian/Programming/horrorscratcher
npm start
```

`npm start` does three things:
1. Headless Godot export (no GPU/editor) → `export/web/`
2. Ensures a TLS cert exists in `certs/` (`scripts/gen-cert.sh` generates a
   self-signed one only as a fallback) — Godot's web runtime requires a
   *secure context* (HTTPS or `localhost`).
3. Serves `export/web/` over **HTTPS** on
   **https://37.187.131.157.sslip.io:5997/** with the COOP/COEP headers Godot 4
   needs (`Cross-Origin-Opener-Policy: same-origin`,
   `Cross-Origin-Embedder-Policy: require-corp`).

The live cert is a **trusted Let's Encrypt** cert for `37.187.131.157.sslip.io`
(sslip.io maps that hostname back to the server IP), so there is **no browser
warning**. Note the hostname: opening `https://37.187.131.157:5997/` by IP now
shows a name-mismatch warning because the cert is issued for the sslip.io name.

If Let's Encrypt is unavailable, the fallback self-signed cert can be used; the
browser then warns once and you click **Advanced → Proceed**. Or SSH-forward the
port and use `localhost` (also a secure context):
```bash
ssh -L 5997:localhost:5997 debian@37.187.131.157
# then open http://localhost:5997/ on your machine
```

Other scripts:

```bash
npm run export   # just re-export (after editing GDScript/scenes)
npm run serve    # just serve the existing export/web (skip export)
SKIP_EXPORT=1 npm start   # serve without re-exporting
PORT=6000 npm start       # different port
```

Open from any other machine: **https://37.187.131.157.sslip.io:5997/**

Controls: click canvas to capture mouse, `WASD` move, `Shift` sprint,
`Space` jump, `Mouse` look, `ESC` release mouse.

Scratch-off tickets lie on the floor. Look down at one and press `E` to pocket it
in your backpack. Press `Q` to take one out and hold it; **hold left mouse and
scrub** to wear off the foil, then `E`/`ESC` stows it again. Most are 3-space
**Suffering** slips; about 1 in 20 is a 4-space **Fortune** slip. Deposit carried
tickets at the hideout stash so a bad night can't cost you them.

Scratching always earns a little **ticket XP** (every finished ticket, even with
no match); leveling up grants skill points. Press `T` to open the Suffering
**talent tree** (a WoW-style node tree): learn **Unlock Blood** and **Unlock
Bone** to make those icons rollable, then **Lucky Coin** (more coins, unlocked
from the start), **Wear Away** (less Empty), **Blood Value** (more XP from
Blood) and **Blood Money** (double prizes).

## Day / night

The map is a 120×120 carnival grounds: an entrance gate, a big top tent, a
slowly rotating Ferris wheel and carousel, a funhouse, five game stalls, food
carts, lampposts and string lights, and a backstage backlot. Your **hideout** is
a metal room in that backlot with a bed, a **stash** (press `E` to deposit
carried tickets), a **gadget bench**, a **workshop** and — once bought — a
**trashcan**. **You
start inside, and the hideout door is sealed during the Day** — the only way out
is to sleep. Press `E` at the bed to start **Night**: the door opens, a
120-second timer runs and the lighting dims. Dawn despawns the floor tickets.
**Entering the hideout during Night ends it safely**; if the timer runs out while
you are still outside, you are caught, lose anything you carried, and respawn in
the hideout. Each Night spawns 10 fresh tickets around the carnival and dawn
clears any left on the ground. Guests stalk the carnival at night: **Drifters**
see you and hear you, **Listeners** are blind but hear you from further away. A
guest turns amber when suspicious and red when chasing, with `?` / `SPOTTED!` on
the HUD. Sprinting is loud, walking is quiet, standing still is silent — get
caught and you lose your carried tickets.

Sprinting drains **stamina** (100, about 30 seconds of running); when it's empty
you drop to a walk, and **only sleeping restores it** (5, or 10 with the Restful
Bed). Spend coins at the **gadget bench** for the **Stun Device** (25 coins; `G`
at Night, 3 charges) and at the **workshop** for upgrades: Scratch Damage,
Movement Speed, Bag Space, Brush Size, Restful Bed and a **Trashcan** (1
coin). Once you own the trashcan, stand at it, take a ticket out (`Q`), then
press `E` to discard it. (Lethal gadgets and decoys are still being built — see
`plan0.1.md`.)

## Saving

Progress **autosaves** to your browser's local storage (`user://` →
IndexedDB): coins, stamina, ticket XP/levels/skills, your backpack and stash,
gadgets and upgrades. The live night (tickets on the ground, guests) is not
saved — you resume at Day in the hideout. To wipe everything, open the workshop
panel and press **Reset save**.

## Requirements (already installed on this server)

- Godot headless: `~/bin/godot` (4.4.1)
- Export templates: `~/.local/share/godot/export_templates/4.4.1.stable/`
  (install script: `/home/debian/Programming/mtgfyn/scripts/install-godot-headless.sh`)
- certbot with the `certbot.timer` systemd timer enabled for automatic renewal.

## TLS certificate (Let's Encrypt)

The trusted cert is for `37.187.131.157.sslip.io` and is managed by certbot with
the Apache webroot as the HTTP-01 challenge path:

```bash
# initial issuance (already done)
sudo certbot certonly --webroot -w /home/debian/Programming/mtgfyn/public \
  -d 37.187.131.157.sslip.io --deploy-hook \
  /home/debian/Programming/horrorscratcher/scripts/deploy-cert.sh

# check / force renewal
sudo certbot renew --dry-run
sudo certbot renew
```

`scripts/deploy-cert.sh` copies `fullchain.pem`/`privkey.pem` into `certs/` so the
unprivileged `serve.mjs` can read them; it runs automatically on every renewal
(registered as the renewal's `renew_hook`).

## Project layout

```
project.godot            # main scene: scenes/main.tscn, GL Compatibility renderer
scenes/main.tscn         # floor, walls, pillars, Player + Camera3D, UI
scripts/player.gd        # FPS controller (CharacterBody3D)
scripts/export.sh        # headless export helper
scripts/gen-cert.sh      # self-signed TLS cert fallback (only if no Let's Encrypt)
scripts/deploy-cert.sh   # certbot deploy hook: copies Let's Encrypt cert to certs/
scripts/serve.mjs        # static server (HTTPS when certs/ present) + COOP/COEP
scripts/start.sh         # export, ensure cert, then serve
certs/                   # cert.pem/key.pem (Let's Encrypt, or self-signed fallback)
export/web/              # generated web build (index.html/js/wasm/pck)
```

## Notes

- Re-run `npm run export` (or restart `npm start`) after changing game code.
- `crossOriginIsolated` in the browser console should be `true` (headers active).
- This project also has an alternative host inside the mtgfyn Laravel app at
  `/horrorscratcher`, but the standalone `npm start` above is the direct way.
