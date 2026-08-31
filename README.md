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
