# Arena Talent Reminder

[![Latest release](https://img.shields.io/github/v/release/cody-young/ArenaTalentReminder)](https://github.com/cody-young/ArenaTalentReminder/releases/latest)
[![CurseForge](https://img.shields.io/curseforge/dt/1583954?label=CurseForge&logo=curseforge)](https://www.curseforge.com/wow/addons/arenatalentreminder)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

A World of Warcraft addon that reminds you to swap talents during arena prep,
based on **your own rules**. Define things like *"against an Unholy Death Knight,
as a Monk, I should have Way of the Crane"* — and the moment you're in the arena
starting room, it tells you if your current talents don't match.

Ported from a personal WeakAura into a standalone, configurable addon.

## Features

- **Rule-based reminders** evaluated against the live arena:
  - Against an enemy **class** or **spec**
  - Against a 3v3 **comp type** (caster cleave / melee cleave / caster-melee)
  - On a specific **map**
  - In a specific **bracket** (Solo Shuffle / 2v2 / 3v3)
  - With a partner of a given **class** or **spec**
- **Should / shouldn't have** a talent — and **presence negation**: trigger on the
  subject being *present* OR *absent* (e.g. *drop* a talent when you're **not**
  facing Unholy).
- Only reminds you for talents your **current spec can actually take** (so rules
  for other classes/specs stay silent).
- Shows during the prep window and **hides automatically** when the gates open or
  you enter combat. Re-shows each Solo Shuffle round.
- Movable, scalable on-screen display.
- Full in-game config UI (Ace3), plus slash commands.

## Installation

- **CurseForge:** [Arena Talent Reminder](https://www.curseforge.com/wow/addons/arenatalentreminder)
  (recommended — auto-updates).
- **Manual:** download `ArenaTalentReminder-vX.Y.Z.zip` from the
  [latest release](https://github.com/cody-young/ArenaTalentReminder/releases/latest)
  and extract it into `World of Warcraft\_retail_\Interface\AddOns\`.

> Don't install by cloning the repo — the Ace3 libraries are not committed to git
> (they're fetched at release time). Use a packaged release zip instead.

## Usage

- `/atr` — open the configuration window.
- `/atr test` — toggle test mode (preview all your rules on screen, anywhere).
- `/atr status` — print current state (bracket, rule counts, why it's showing/hidden).
- `/atr debug` — toggle debug output to the chat frame.

### Setting up a rule

Open `/atr`, pick a category tab (e.g. **Against Spec**), click **Add Rule**, then
read the row left-to-right as a sentence:

> `Death Knight - Unholy` · **is present** · *Should have* · `Way of the Crane`

The **talent name** must match the in-game spell name exactly (PvP talents work
too). Switch **is present** to **is absent** to negate, and **Should have** to
**Shouldn't have** to flip the talent condition.

## When does it show?

The reminder appears while you're in an arena and out of combat, during the prep
window. It hides when the gates open (`PVP_MATCH_ACTIVE`) or you enter combat, and
re-appears at the start of each Solo Shuffle round. Use **test mode** to preview
your rules outside of a match.

## Building / Contributing

Releases are built by the [BigWigs packager](https://github.com/BigWigsMods/packager)
via GitHub Actions. The Ace3 libraries live in `Libs/` locally for testing but are
**not committed** — they're declared as externals in [`.pkgmeta`](.pkgmeta) and
checked out fresh at build time.

To cut a release, push a tag:

```sh
git tag -a v1.0.1 -m "v1.0.1"
git push origin v1.0.1
```

The workflow packages the addon (bundling the libraries) and publishes a GitHub
release automatically.

## License

Released under the [GNU GPL v3](LICENSE).
