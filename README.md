# Family Appily — App

Native SwiftUI family-management app for iPhone, iPad, Apple Watch, and Mac. Brings together the household's calendars, task list, weekly chore charts, and ticket-based reward system.

## Start here

**`CLAUDE.md`** at the repo root is the build specification. Claude Code loads it automatically at the start of every session — it contains the accessibility constraints, platform requirements, design language, and the phased build plan.

**`family-hub-assets/`** contains the design system and seed data extracted from the family's physical wall charts:

| Path | What it is |
|---|---|
| `data/family.json` | Per-child weekly chore schedules and the chore catalog |
| `data/rotation.json` | Shared family chore rotation — a computed 3-week cycle |
| `data/tickets.json` | Ticket economy: earn catalog, spend tiers, reward chart |
| `design/tokens.json` | Colors, typography, frame styles, layout rules |
| `design/avatars/` | Per-child mascot SVGs (pizza, panda, penguin) |
| `design/motifs/` | Decorative SVGs, star token, vault |
| `preview.html` | Open in a browser to see it all rendered |

## Current state

Phase 0 (foundation) and Phase 1 (profile picker, weekly chart, card frames, completion mark) are built, per `PHASE0_PROMPT.md`. `rotationEpoch` still needs to be set once by an adult in-app (there's a setup prompt for it) — see §11 of `CLAUDE.md` for the remaining open items.

Also built out of sequence: **Job Search**, a new tab with its own scoped backend (see `ARCHITECTURE_DECISION.md` in the API repo) — applications board, RSS-sourced job feed, and identity/profile view, behind the same inline adult gate as other adult actions.

Open the project with `FamilyAppily.xcodeproj`, or regenerate it from `project.yml` via `xcodegen generate` (`brew install xcodegen`) if you change the project structure.

## Build order

Phases are defined in §9 of `CLAUDE.md`. Run them in order; each is a self-contained prompt for Claude Code. Do not skip ahead — later phases assume the data layer from earlier ones. Remaining: Phase 2/3 (calendar), Phase 5 (reward system UI), Phase 6's widgets, Phase 7 (Mac), Phase 8 (Watch), Phase 9 (cross-platform audit).

## Family Appily on the Mac

`/Applications/Family Appily.app` is the full app — Home, Family Rotation, and
the whole Job Search pipeline in a sidebar. Built from the `FamilyAppilyMac`
target:

```bash
xcodebuild -project FamilyAppily.xcodeproj -scheme FamilyAppilyMac \
  -destination 'platform=macOS' build
```

### Household data does not sync to the Mac yet

The Mac build has **no iCloud entitlement**, so SwiftData falls back to a local
store (`~/Library/Containers/com.mspaldingworks.FamilyAppily/…/default.store`).
The chore chart and rotation work, seeded from `family-hub-assets`, but they are
this Mac's own copy — changes here do not reach the iPhone and vice versa.

Adding the entitlement requires a Mac App Development provisioning profile,
which requires this Mac to be registered in the developer account:

- Provisioning UDID: `00008103-001600C20AF3001E`
- Register at developer.apple.com → Devices → macOS, then restore the iCloud
  keys in `Platforms/macOS/FamilyAppilyMac.entitlements` and `project.yml`.

Job Search is unaffected — it talks to the API over the network and shares the
same data as the phone already.
