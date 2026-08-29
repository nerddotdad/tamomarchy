# tamOmarchy

A desktop pet for [Omarchy](https://omarchy.org/). An egg hatches on your screens; you name it (default **Mochi**), then it wanders, hops between monitors, and asks to be fed, played with, bathed, or put to sleep. Care for it from a bar sprite.

Plugin id: `io.github.nerddotdad.tamomarchy`

![tamOmarchy](preview.png)

## Install

```bash
omarchy plugin add https://github.com/nerddotdad/tamomarchy.git --enable
```

That clones the plugin, validates the manifest, and enables it. The bar sprite lands on the **right** by default; move it with `omarchy bar move io.github.nerddotdad.tamomarchy`.

Omarchy will warn that plugins run unsandboxed inside `omarchy-shell`. Read this repository before you enable it.

## Remove

```bash
omarchy plugin remove io.github.nerddotdad.tamomarchy
```

That disables the plugin and deletes the checkout. It does not touch other bar widgets or plugins.

Pet progress is stored separately at:

```text
~/.local/state/omarchy/tamagotchi.json
```

Delete that file if you want a clean wipe (new egg, no graves).

## Requirements

Omarchy 4 (Quattro) or newer. No extra packages, no build step, no network access, and nothing outside this plugin directory plus the state file above.

Enabling and removing go through Omarchy’s plugin CLI, which writes only this plugin’s own entries in `~/.config/omarchy/shell.json`. The plugin does not rewrite the rest of your shell config.

## Using it

- The bar sprite opens the care panel (stats, points, shop, playpen, difficulty, Pause Care, No Death, graves).
- Drag the pet. Hold to get Sleep, Eat, Play, Bath, and Kill. Drop on an action to start that mini-game.
- Tap the egg (without dragging far) to name and hatch it.
- Draw a playpen to keep it on one monitor; **Wander freely** clears the pen.
- It walks, and hops, across monitors. Mini-games stay on the screen where you started them.
- Hatched pets earn **1 point per minute** while Pause Care is off. Spend points in the shop. Equip hats and toys with the arrows on the care panel (buying does not auto-equip).
- **Difficulty** (Easy / Medium / Hard) uses the same arrows. It only changes how fast hunger, mood, and walking energy drop. Medium is the original pace (belly ~40 minutes, mood ~70, walk energy ~2 hours). Easy is half that drop; Hard is twice. Sleep refill stays the same.
- **Pause Care** freezes hunger, mood, energy, mess, and points where they are. Mini-games still open but do not change stats. It does not refill anything. (The old Maintenance toggle used this same save flag.)
- **No Death** stops starve and lonely from killing them. When those timers run out they sleep until you feed or play. The Kill mini-game still works.
- Hats, toys, and creature parts are markdown pixel art. See [Style guide](#style-guide).

Optional IPC, using the plugin id as the target:

```bash
omarchy-shell io.github.nerddotdad.tamomarchy toggle
omarchy-shell io.github.nerddotdad.tamomarchy state
```

## Style guide

Shop items and creature parts are 12×11 markdown grids. The plugin loads every `*.md` in the folders below except `template.md`. Copy that starter file, rename it, and draw. A later file with the same `id` wins. Your own copies can live under `~/.config/omarchy/tamomarchy/` so they survive a plugin update. Reopen the shop or restart the shell after you add a file.

### Colors

`.` is empty. Everything else is one letter, one color.

**Theme** letters follow the Omarchy theme (and the bar palette on the bar sprite). Use these for the creature itself so it matches the desktop.

| Letter | Follows |
|---|---|
| `B` | body (accent) |
| `D` | line (darker body) |
| `T` | shaded body |
| `H` | deep outline |
| `E` | eye (foreground) |
| `P` | pupil (background) |
| `M` | mouth (darker line) |

**Paint** letters are fixed. They stay the same in every theme. Use these for hats, toys, and details that should not recolor.

| Letter | Color |
|---|---|
| `R` | red |
| `O` | orange |
| `Y` | gold |
| `G` | green |
| `U` | blue |
| `V` | purple |
| `N` | brown |
| `C` | pink |
| `K` | black |
| `W` | white |
| `A` | gray |

### Shop items

```text
Looks/shop/hats/*.md
Looks/shop/toys/*.md
~/.config/omarchy/tamomarchy/shop/hats/*.md
~/.config/omarchy/tamomarchy/shop/toys/*.md
```

Copy `Looks/shop/hats/template.md` or `Looks/shop/toys/template.md`.

- `#` title is the shop name (or set `name:`)
- `id` is what the save file stores (letters, numbers, `-`, `_`)
- `cost` is points (`0` or missing keeps Buy disabled)
- the folder chooses hat vs toy
- toys may set `pose:` to `idle`, `walk`, `dance`, or `jump`
- each fenced code block is one 12×11 frame
- one fence is static; two to five loop; extra fences are ignored

### Creature parts

```text
Looks/parts/bodies/*.md
Looks/parts/heads/*.md
Looks/parts/hats/*.md
Looks/parts/arms/*.md
Looks/parts/legs/*.md
Looks/parts/tails/*.md
~/.config/omarchy/tamomarchy/parts/<slot>/*.md
```

Copy `Looks/parts/<slot>/template.md`. A new `id` joins the hatch pool. Hatch hats in `Looks/parts/hats/` are the sprout/horns/bow layer; shop hats still draw on top.

- `#` title is the label
- `id` is what the save file stores
- `## idle` is required (one 12×11 fence)
- extra poses are optional; missing ones reuse idle
- pose headings: `idle`, `walk` (one or two fences), `dance` (one or two fences), `watch`, `eat`, `sit`, `sleep`, `sad` (or `walkA` / `walkB`, `danceA` / `danceB`)

Draw only that layer. Typical rows:

- bodies: 4–7, cols 3–8
- heads: 0–4, cols 2–9
- hats: 0–2
- arms: 3–6, cols 0–2 and 9–11
- legs: 8–10
- tails: 5–10, cols 9–11 (drawn behind the body)

## License

MIT, see [LICENSE](LICENSE). Font Awesome Free icons in `icons/` are CC BY 4.0; attribution is in that file.
