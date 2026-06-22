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
  the `ATR:ShouldShow()` gate, AceDB defaults, event registration, and
  `ATR:Refresh()` which gates + drives the display.

  Arena-prep detection (`ATR:ShouldShow()`): show while `IsInInstance() == "arena"`,
  `self.hidden` is false, AND the player is not in combat (`UnitAffectingCombat`).
  `self.hidden` is reset to false (show) on PLAYER_ENTERING_WORLD,
  ARENA_PREP_OPPONENT_SPECIALIZATIONS, and the player casting the round-start
  marker (228212, auto-cast at the start of each round — class-agnostic). It is
  set true (hide) on PVP_MATCH_ACTIVE (gates open). The combat check is a
  belt-and-suspenders hide that holds regardless of event timing. The old Arena
  Preparation aura (32727) gate was unreliable and was removed.
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

Each rule is `{ subject = <dropdown index>, presence = 1|2, should = 1|2, talent = "<name>" }`
stored under `db.profile.rules[categoryKey]` (`class`, `spec`, `compType`, `map`,
`arenaType`, `partnerClass`, `partnerSpec`). `presence` 1 = subject "is present",
2 = "is absent" (negation — e.g. *not* facing Unholy). `should` 1 = "Should have",
2 = "Shouldn't have". The rule fires when the presence condition is met AND the
talent (should/shouldn't) condition is violated. A rule only evaluates if
`ns.CanSpec(talent)` is true (the talent is available to your current spec), so
rules for other classes stay silent. `presence` defaults to 1 when missing, so
pre-existing saved rules keep their old behavior.

Talents are matched by **name** (compared against the spell name of each talent
tree entry and PvP talent), faithful to the original WeakAura — so the talent
field must match the in-game name exactly.

## Usage / dev notes

- `/atr` (or `/arenatalentreminder`) opens the standalone config window. Also under
  Settings → AddOns → Arena Talent Reminder.
- "Test mode" in General previews all rules on screen outside of a match.
- Display only shows while the Arena Preparation buff is up (the window where you
  can still freely change talents), unless test mode is on.
- Ace3 libs live in `Libs/` locally but are **not committed** (gitignored). The
  packager fetches them via `.pkgmeta` externals at release time. To refresh a
  local copy for testing, recopy from another addon (e.g. `Bartender4/libs`) or
  run the packager. Releases are cut by pushing a tag (e.g. `v1.0.1`), which
  triggers `.github/workflows/release.yml` (BigWigsMods/packager) to build the
  zip and publish a GitHub release.
- Fixed vs the original WeakAura: partner-class matching (`UnitClass` return was
  being mis-assigned in the WA, so it never matched).
