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

Pre-Phase-0. Nothing has been built yet. See §11 of `CLAUDE.md` for the open blockers — most importantly `rotationEpoch` and the backend architecture decision.

## Build order

Phases are defined in §9 of `CLAUDE.md`. Run them in order; each is a self-contained prompt for Claude Code. Do not skip ahead — later phases assume the data layer from earlier ones.
