# Arena Talent Reminder

A standalone WoW retail addon (interface 120007) ported from a WeakAura. During
arena prep it checks the enemy team, your partners, the map and the bracket
against a user-defined rule set and reminds you to swap talents — e.g. *"Found
Death Knight - Unholy but missing Way of the Crane."*

`WeakAura.json` is the original import, kept for reference only. It is not loaded.

## Layout

- `ArenaTalentReminder.toc` — load order. Embeds Ace3 from `Libs/` then loads the
  four addon files in order.
- `Core.lua` — AceAddon object (`ns.ATR`), the lookup tables (`classMap`,
  `specMap`, `mapMap`/`mapNames`, `casters`, `melee`, comp/bracket names), the
  talent helpers `ns.CanSpec` / `ns.IsSpecced` (ported from `CanSpec`/`IsSpecced`),
  the `ns.IsInArenaPrep` gate (Arena Preparation buff, spell 32727), AceDB
  defaults, event registration, and `ATR:Refresh()` which gates + drives the
  display.
- `Engine.lua` — `ns.categories` (the 7 rule categories) and `ATR:Evaluate()`,
  the port of the WeakAura custom trigger. Each category has `values()` (dropdown),
  `label(rule)` (subject name for the message) and `match(rule)` (is the subject
  present in the current arena). `Evaluate(isTest)` returns a deduped list of
  reminder strings; `isTest` forces every rule's subject to count as present.
- `Display.lua` — the on-screen frame (icon + multiline text), drag-to-move when
  unlocked, settings applied from `db.profile.display`.
- `Options.lua` — the AceConfig table that replaces the WeakAura author options.
  One tab per category with an Add/Delete dynamic rule list, rebuilt by
  `ATR:RefreshOptions()` (wipe args + `AceConfigRegistry:NotifyChange`).

## Rule model

Each rule is `{ subject = <dropdown index>, should = 1|2, talent = "<name>" }`
stored under `db.profile.rules[categoryKey]` (`class`, `spec`, `compType`, `map`,
`arenaType`, `partnerClass`, `partnerSpec`). `should` 1 = "Should have", 2 =
"Shouldn't have". A rule only fires if `ns.CanSpec(talent)` is true (the talent is
available to your current spec), so rules for other classes stay silent.

Talents are matched by **name** (compared against the spell name of each talent
tree entry and PvP talent), faithful to the original WeakAura — so the talent
field must match the in-game name exactly.

## Usage / dev notes

- `/atr` (or `/arenatalentreminder`) opens the standalone config window. Also under
  Settings → AddOns → Arena Talent Reminder.
- "Test mode" in General previews all rules on screen outside of a match.
- Display only shows while the Arena Preparation buff is up (the window where you
  can still freely change talents), unless test mode is on.
- Ace3 libs were copied from `Bartender4/libs`. To update, recopy those folders.
- Fixed vs the original WeakAura: partner-class matching (`UnitClass` return was
  being mis-assigned in the WA, so it never matched).
