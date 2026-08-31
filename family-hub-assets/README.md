# Family Hub — Asset Package

Vector recreation of the three physical WEEKLY CHORES charts. Drop this folder into the repo root alongside `CLAUDE.md`.

```
family-hub-assets/
├── data/family.json        ← chore catalog + per-child weekly schedule
├── design/tokens.json      ← colors, type, frame styles, layout rules
├── design/avatars/*.svg    ← Finley pizza + pasta, Arthur panda, Maryn penguin
├── design/motifs/*.svg     ← corner decorations, per child
└── preview.html            ← open in a browser to see it all rendered
```

## How to use it

`family.json` is the **seed data**, not the runtime schema. In Phase 4, import it once into SwiftData and let the app own it from there — adults need to edit chores without touching JSON.

The SVGs go into the asset catalog as **vector-preserved PDFs or SF Symbols-style template assets**. Do not rasterize to PNG at fixed sizes; these need to scale for the Watch complication, the widget, and a full-screen iPad chart from the same source.

`tokens.json` becomes a generated Swift file (a `ChildTheme` enum with a case per child). Views should never reference a hex value directly.

## What was in the photos

| Child | Motif | Card frame | Corners | Title |
|---|---|---|---|---|
| Finley | Pizza slice / pasta bowl, alternating | Open book, one chore per page | Navy cap (top), green hoodie (bottom) | Green |
| Arthur | Panda | Bamboo fence rail | Conical hat (top), bamboo stalks (bottom) | Green |
| Maryn | Penguin | Held sign | Red flower (top), ice cube (bottom) | Red |

All three use the same seven-card grid: **four across the top, three across the bottom, week starting Sunday.**

## Notes on the recreation

The original charts use licensed clip-art from a printable template. The SVGs here are **original illustrations** drawn to match the motif, palette, and spirit of each chart — not traces of the source art. They'll read as the same characters to your kids while leaving you clear to ship the app.

The hand-drawn checkmarks visible in the photos were **not** imported as data. Those are one week's completions, not part of the template. But keep the *look* — a slightly irregular black check, not a tidy SF Symbol checkmark. It's the most recognizable element of the whole system and the thing a kid is actually reaching for.

## Still needed

See `openQuestions` at the bottom of `family.json`. The big one: **no photos of the reward system were included.** Phase 5 can't be specified without them.
