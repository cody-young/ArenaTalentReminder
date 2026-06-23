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
  set true (hide) on PVP_MATCH_ACTIVE (gates open) and on PLAYER_REGEN_DISABLED
  (entering combat) — the latter latches hidden so leaving combat won't re-show
  the reminder until a fresh arena-prep signal (the round-start marker or
  ARENA_PREP_OPPONENT_SPECIALIZATIONS) resets it. The combat check in
  `ShouldShow()` is an additional belt-and-suspenders hide that holds regardless
  of event timing. The old Arena Preparation aura (32727) gate was unreliable and
  was removed.
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

Each rule is `{ subject = <dropdown index>, presence = 1|2, should = 1|2,
talent = "<name>", mirror = bool }` stored under `db.profile.rules[categoryKey]`
(`class`, `spec`, `compType`, `map`, `arenaType`, `partnerClass`, `partnerSpec`).
`presence` 1 = subject "is present", 2 = "is absent" (negation — e.g. *not* facing
Unholy). `should` 1 = "Should have", 2 = "Shouldn't have". The rule fires when the
presence condition is met AND the talent (should/shouldn't) condition is violated.

`mirror` (the "Also apply the inverse" toggle) additionally evaluates a second
variant with **both** `presence` and `should` flipped. So "against Unholy → should
have X" also reminds "not against Unholy → shouldn't have X". At most one variant
can fire at a time (the presence conditions are mutually exclusive). See
`ATR:Evaluate`'s `variants` logic in [Engine.lua](Engine.lua).

**Want-set suppression.** `ATR:Evaluate` is two-pass over pre-built rule
`contexts`. Pass 1 computes `wantedBy[talent]` — every talent a currently-active
"should have" variant wants, and by which matchups. Pass 2 builds messages, but a
"drop" (a `should == 2` variant where you currently `has` the talent) is
**suppressed** if anything wants that talent — so a talent good vs Unholy *and*
Beast Mastery isn't flagged for removal when you face only one of them. "Want it"
always beats "drop it" (the conflict-resolution policy). A suppressed drop instead
emits an informational **note** naming the overruled rule (`X: "no <subject>" says
drop — kept (wanted vs ...)`, gated on `display.showNotes`, default on, deduped by
talent+suppressed-subject). `Evaluate` returns `{ reminders = {...}, notes = {...} }`.
[Display.lua](Display.lua) renders reminders in the large gold `f.text` and notes
in a smaller gray `f.notes` FontString, each note line prefixed with an inline info
icon; `ATR:LayoutDisplay` stacks the two blocks and sizes the border to hug them.
Test mode skips suppression to preview each rule's raw output.

A rule only evaluates if `ns.CanSpec(talent)` is true (the talent is available to
your current spec), so rules for other classes stay silent. `presence`/`mirror`
default to 1/false when missing, so pre-existing saved rules keep their behavior.

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
