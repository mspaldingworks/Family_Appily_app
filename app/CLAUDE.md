# CLAUDE.md — Family Hub

> **Placement:** Keep this file at the repository root. Claude Code loads `CLAUDE.md` automatically at the start of every session, so these constraints apply to every prompt without being re-pasted.
>
> **Status:** Parts 1 and 2 complete. Design language (§7) and the full ticket economy (§7.7) are derived from the physical materials and live in `family-hub-assets/`. Remaining blockers are listed in §11.

---

## 1. What we're building

A single app that replaces three things our household currently juggles:

1. **Scattered calendars** — several separate calendars that no one sees in one place.
2. **A physical chore chart + reward system** — a whimsical, hand-built system that already works. The app digitizes it; it does not redesign it.
3. **A shared task list** — quick add/remove of tasks and events by any adult, from any device.

**The north star:** any family member should be able to walk up to any device in the house, see what's theirs, act on it, and see the result — without help, without instructions, and without a login screen. The physical chart works because it's glanceable and requires zero explanation. The app has to clear that same bar.

### Non-goals (say no to these)
- Accounts, sign-ups, cloud user management, or anything requiring an email address for a child.
- Gamification we didn't design. The existing reward system is the spec. No streaks, badges, or leaderboards unless they exist on the physical chart.
- Social features, sharing outside the household, or third-party analytics.
- A "productivity app" aesthetic. This should look like our kitchen wall, not like Asana.

---

## 2. Confirmed decisions

| # | Decision | Answer | Consequence |
|---|---|---|---|
| D1 | Framework | **Native SwiftUI** | EventKit gives direct, permissioned access to the household's real calendars and Reminders. |
| D2 | Target platforms | **iPhone, iPad, Apple Watch, Mac** | One SwiftUI multiplatform app with a shared core; four distinct interaction models. See §3.8. |
| D3 | Widgets | Home Screen + Lock Screen widgets, plus a Watch complication | Cheap to add once the data layer exists, and the highest-value glanceable surface. |
| D4 | Data storage | **Local-first (SwiftData) + CloudKit private database** | No server, no accounts, syncs across family devices via existing Apple IDs, children's data never leaves Apple's ecosystem. |
| D5 | Minimum OS | iOS 17 / iPadOS 17 / watchOS 10 / macOS 14 | Unlocks modern SwiftUI + SwiftData across all four. **Verify against the oldest device in the house before Phase 0.** |
| D6 | Reading level | **All three children read fluently** | Text labels are safe. Image-first design remains, but for speed of recognition rather than necessity — see §3.4. |

### A note on scope

Four platforms is real work, and shipping nothing is worse than shipping iPhone-and-iPad-first. The phase plan in §9 builds the shared core once, ships iPhone + iPad as v1, then adds Mac and Watch as separate targets against that same core. If you'd rather have all four at once, that's a legitimate choice — it just moves the first usable build several phases later.

---

## 3. Hard constraints: accessibility & family usability

**These are not suggestions. Every screen must satisfy all of them before a phase is considered done.**

### 3.1 Touch and motor
- Minimum tap target **44×44pt** anywhere in the app. **60×60pt minimum** for any control a child uses (marking chores done, selecting a profile).
- **Never** make drag-and-drop the only way to do something. Every drag interaction needs a tap-based equivalent.
- Primary actions live in the **bottom third** of the screen, thumb-reachable. Nothing critical in the top corners.
- No double-tap, long-press, or swipe as the *sole* path to a core action. These are discoverability and motor-skill traps.
- Generous spacing between adjacent tappable items (≥8pt) so mis-taps don't trigger the wrong thing.

### 3.2 Vision and text
- **Dynamic Type is mandatory.** No hardcoded font sizes, no `.frame(height:)` on text containers. Every screen must be tested at the **largest accessibility size (AX5)** and must remain usable — text truncation or clipped buttons is a bug, not a tradeoff.
- Contrast: **4.5:1 minimum** for text, **3:1** for UI components and meaningful graphics.
- **Color is never the only signal.** A completed chore is indicated by color *and* an icon *and* a state change in the illustration. Two of our design elements are color-coded on the physical chart — those need redundant encoding here.
- Full **Dark Mode** support. No hardcoded hex values scattered in views; use a semantic color asset catalog.
- Respect and test: `Reduce Motion`, `Reduce Transparency`, `Bold Text`, `Increase Contrast`, `Differentiate Without Color`.

### 3.3 VoiceOver and screen readers
- Every interactive element gets a **meaningful** accessibility label. `"Mark 'feed the dog' complete for Kid A"` — never `"Button"` or `"checkmark.circle"`.
- Decorative illustrations get `.accessibilityHidden(true)`. Meaningful images get descriptive labels.
- Group related elements with `.accessibilityElement(children: .combine)` so a chore row reads as one coherent item instead of four fragments.
- Custom controls expose correct traits and values (e.g., a reward progress meter reports `"3 of 5 stars"`).
- Announce state changes with `.accessibilityAnnouncement` — completing a chore should be audibly confirmed.

### 3.4 Glanceability

All three children read fluently, so text labels are safe to rely on. Image-first design still applies — not out of necessity, but because recognition beats reading for speed, and because the existing physical system is visual and we're preserving it.

- Child-facing items pair **image + text**. The image carries identification at a glance; the text confirms it. Neither one alone.
- Profile selection is **photo-based** with the name beneath it.
- Quantities use both symbol and number (⭐️⭐️⭐️ *and* "3 of 5") — symbols scan faster, numerals are unambiguous at a count of twelve.
- A child should be able to answer "what do I still have to do today?" from across the room, without walking up to the device. This is the actual test for the chart view.

### 3.5 Cognitive load and error tolerance
- **No login wall.** The shared iPad opens directly to a profile picker. Adult-only actions are gated behind a simple PIN or Face ID *at the point of the action*, not at app launch.
- Children can **never** delete data. Marking a chore complete is reversible by tapping again; anything destructive is adult-gated.
- Every adult destructive action gets **undo**, not a confirmation dialog. Confirmation dialogs get dismissed reflexively; undo actually protects data.
- Maximum **one primary action per screen**. If a screen has three equally-weighted buttons, it needs to be split.
- No timed interactions, auto-dismissing toasts under 5 seconds, or anything that punishes slowness.

### 3.6 Reliability
- **Offline-first.** The app must fully function with no network. Calendar and chore data render from local storage; sync happens in the background.
- **Never block a screen on a spinner.** Show last-known data with a subtle staleness indicator.
- App launches to usable content in **under 2 seconds** on the oldest device in the house.
- State survives backgrounding, force-quit, and restart. A half-completed chore interaction is never lost.

### 3.7 Feedback and delight
- Completing a chore triggers **haptic + visual + optional sound**. All three independently mutable in settings.
- Reward progress must be **visible at rest** — a child should see how close they are without tapping anything.
- Animations are short (<400ms), purposeful, and fully disabled under `Reduce Motion` (replaced with a cross-fade, not removed entirely — the state change still needs to be perceptible).

### 3.8 Cross-platform interaction requirements

The four platforms are not one UI scaled up and down. Each has non-negotiable native behaviors.

**iPhone** — one-handed operation, bottom-anchored primary actions, the adult's quick-capture surface.

**iPad** — the shared household surface and likely the primary chore-chart device. Must support Split View, Slide Over, Stage Manager, all orientations, and external keyboard. Assume it sits in a stand in a common room and gets walked up to, not held.

**Mac** —
- Full **keyboard navigation**. Tab order must be logical; every action reachable without a mouse.
- **Keyboard shortcuts** for adult quick-add (⌘N for event, ⌘⇧N for task) and a real menu bar, not a stub.
- **Pointer interactions**: hover states, right-click context menus, resizable windows down to a sensible minimum.
- Touch targets can shrink to macOS norms, but **only** on Mac — do not let this leak back into the shared components.

**Apple Watch** —
- Scope is deliberately narrow: glance at today's events, glance at chore progress, mark a chore complete. Nothing else.
- **Digital Crown** support for any scrolling list.
- Targets sized for the smallest supported case. If it doesn't work on a 40mm, it doesn't ship.
- Assume the wrist is raised for two seconds. Any interaction needing more attention than that belongs on the phone.
- Complication showing remaining chores for the wearer's profile.

**Shared rule:** platform-specific code lives behind `#if os(...)` in view layers only. The data layer, models, and business logic are written once and compiled everywhere. If a platform difference is bleeding into the model layer, the abstraction is wrong.

---

## 4. Household roles and permissions

| Role | Can do | Cannot do |
|---|---|---|
| **Adult** | Everything: add/edit/delete events and tasks, adjust chore definitions, award or revoke rewards, redeem rewards, manage profiles | — |
| **Child** | View own chart and the family calendar, mark own chores complete/incomplete, view own reward progress, request reward redemption | Edit or delete anything, modify chore definitions, alter another child's data, change reward values |

- Role is determined by the selected profile, not by a session or password.
- Adult-gated actions prompt for Face ID / PIN **inline**, at the moment of the action.
- Profile switching is one tap and always available — no "log out" concept.

---

## 5. Data and privacy rules

- All family data lives in the **CloudKit private database** tied to the family's own iCloud, plus a local SwiftData store. No custom backend.
- **Zero third-party SDKs** for analytics, crash reporting, or advertising. Nothing about our children leaves Apple's ecosystem.
- Photographs of the physical chart and of the children are stored **locally and in the private CloudKit container only**, never uploaded elsewhere, never sent to any API.
- Calendar access is **read/write to explicitly selected calendars only**, requested with a clear, plain-language purpose string.
- Permission prompts are preceded by an in-app explanation screen so a denial isn't accidental and permanent.

---

## 6. Calendar and task integration

- Use **EventKit** for both `EKEventStore` (calendars) and `EKReminder` (tasks). Do not build a parallel task system if Reminders can carry it — the family already gets Siri, Watch, and Mac support for free that way.
- The app **aggregates** multiple calendars into one view with per-calendar color coding and per-calendar visibility toggles.
- Writes go back to the correct source calendar. Never silently create a new "app calendar" and strand events there.
- Handle the ugly cases explicitly: recurring events, all-day events, timezone shifts, declined invitations, and calendars that lose write permission.
- Quick-add for events and tasks must be reachable in **≤2 taps from launch** for an adult.

---

## 7. Design language

Derived from photographs of the three physical charts. **The assets in `family-hub-assets/` are the specification. Do not invent an alternative visual system.**

### 7.1 Per-child identity

Every child owns a complete visual world, not just a mascot. Identity must be consistent everywhere that child appears — chore chart, calendar event dots, task list, widget, Watch complication, profile picker.

| Child | Motif | Card frame | Corner decorations | Identity color |
|---|---|---|---|---|
| **Finley** | Pizza slice / pasta bowl, alternating by day | Open book — one chore per facing page | Navy cap (top), green hoodie (bottom) | Blue `#1B4F9C` |
| **Arthur** | Panda | Bamboo fence rail | Conical hat (top), bamboo stalks (bottom) | Green `#5CB85C` fill / `#3E7D36` text |
| **Maryn** | Penguin | Held sign | Red flower (top), ice cube (bottom) | Orange `#E04E2C` fill / `#BF3A1E` text |

**Identity colors come from the FAMILY CHORE CHART legend, not the mascot artwork.** The legend is an explicit family convention already in use on the wall. Mascot palettes are decorative fill only — several fail AA and none may carry text. See `identityColorResolution` in `tokens.json`.

Finley's open-book frame holds exactly two chores. That constraint is inherited from the physical chart — either respect it or change the frame, but don't let a third chore overflow the metaphor.

### 7.2 The chart layout

Seven day cards, **four in the top row, three in the bottom, week beginning Sunday.** This is what the family already reads at a glance and it is preserved on iPad and Mac. Collapse to a vertical list only on iPhone and Watch, where the grid genuinely doesn't fit.

### 7.3 The completion mark

Completion is a **hand-drawn-feeling black check** struck across the chore text — not a tidy checkmark in a circle, not a strikethrough, not a color swap. This single mark is the most recognizable element of the entire system and the thing a child is physically reaching for.

Requirements:
- Draw it as a stroked SVG path with slight irregularity, animated on with a short draw-in (disabled under Reduce Motion — cross-fade instead).
- Because it's a *mark over text*, contrast against the chore label matters. Verify legibility of the completed state.
- Per §3.2, the check cannot be the only signal. Pair it with the card's background state changing and the accessibility value updating to `"completed"`.

### 7.4 Color rules

`design/tokens.json` flags several palette entries as `decorativeOnly` — pizza gold, ice blue, bamboo light, hat orange. These **fail text contrast on white** and may only be used as illustration fill. Text and stateful UI use `ink` and the child's `primary`, both of which clear AA.

Views reference tokens, never raw hex. Generate a `ChildTheme` enum from `tokens.json` in Phase 0.

### 7.5 Typography

The physical charts use a rounded marker face for titles and a plain sans for chore text. Reproduce with **system fonts only** — `.system(.largeTitle, design: .rounded)` uppercase for chart titles, `.system(.caption, design: .rounded)` bold uppercase for day labels, `.system(.body)` for chore text. A custom display font that doesn't support the full Dynamic Type range is a §3.2 violation and will not ship.

### 7.7 The ticket economy

Three artifacts interlock. Build them as one system, not three screens.

1. **Personal weekly chore chart** (§7.2) — fixed daily chores per child.
2. **Family rotation chart** — six shared chores on a 3-week cycle. `data/rotation.json`.
3. **Reward chart + tickets** — 30 slots in 5 rows of 6, star at each row's end, Vault. `data/tickets.json`.

**The rotation is computed, not stored.** The printed chart shows seven week columns, but it is a 3-week cycle displayed 2⅓ times — WK7 equals WK1. One formula reproduces all 42 printed cells: `cycle[(offset + weekIndex) mod 3]` over `[finley, maryn, arthur]`. Store six offsets and a start date, not a grid, and the rotation never expires.

**This resolves the "Weekly Chore" placeholder.** Each child's chart has that slot on Sunday and Saturday; the rotation fills it. Resolve it automatically and render the real chore label. Do not ask an adult to type it in weekly — removing that chore *from the adults* is most of the point of digitizing this.

**Ticket spend tiers are family-scope and identical across all three children.** Per-child pricing is the fastest way to make this feel unfair. 5 / 10 / 15 / 20.

**Health-adjacent earn items are private.** Arthur's earn list includes therapy activities. Any item flagged `private: true` renders only in that child's own profile and for adults — never in shared family views, exports, or a widget on a shared device. This is a §5 privacy requirement, not a preference.

### 7.6 Asset handling

SVGs go into the asset catalog as **vector-preserved** assets. Do not rasterize to fixed-size PNGs — the same source has to serve a Watch complication, a Home Screen widget, and a full-screen iPad chart.

---

## 8. Engineering conventions

- SwiftUI + SwiftData, **multiplatform target** with per-platform app targets sharing a `FamilyCore` package.
- MVVM-lite: views stay dumb, logic lives in observable models. Models are platform-agnostic — no `UIKit` or `AppKit` imports below the view layer.
- Structure: `FamilyCore/` (models, persistence, EventKit adapters, business logic) + `Features/Calendar`, `Features/Chores`, `Features/Rewards`, `Features/Profiles` + `Platforms/iOS`, `Platforms/macOS`, `Platforms/watchOS`.
- No force unwraps in shipping code paths.
- Every view has a `#Preview` at default size, at AX5, and in dark mode. Shared views additionally preview on each platform they render on. This makes accessibility and layout regressions visible during development instead of at the end.
- Accessibility labels are written **at the same time** as the view, never bolted on later.
- Commit after each phase with a working build. Do not stack unverified phases.

---

## 9. Phased build plan

Each phase below is a self-contained prompt for Claude Code. Run them in order. **Do not skip ahead** — later phases assume the data layer from earlier ones.

**Phase 0 — Scaffold.** Create the Xcode project as a multiplatform app with a shared `FamilyCore` package. Add iOS and iPadOS targets now; leave macOS and watchOS targets stubbed but unbuilt. Set up the module structure per §8, an asset catalog with semantic colors, and an `AccessibilityChecklist.md` in the repo that every commit must satisfy. Wire up SwiftData + CloudKit private container. No UI yet beyond a launch screen.

**Phase 1 — Profiles.** Build the profile picker as the app's entry point. Photo-based, no login, one-tap switching, adult/child role flag, Face ID/PIN gate helper for adult actions. This is the foundation everything else keys off.

**Phase 2 — Calendar aggregation (read-only).** EventKit permission flow with pre-prompt explanation, calendar selection screen, unified day/week/month views with per-calendar color coding and visibility toggles. Read-only first — prove the aggregation before allowing writes.

**Phase 3 — Calendar and task writes.** Quick-add for events and tasks, editing, deletion with undo, correct source-calendar routing, EKReminder integration for the shared task list.

**Phase 4 — Chore system.** Import `family-hub-assets/data/family.json` as seed data into SwiftData, then build chore definitions (adult-managed), per-child assignment, recurrence, the completion interaction per §7.3, and the weekly chart view per §7.2. The `Weekly Chore` placeholder needs an adult-editable label per week. This is where the design language in §7 becomes load-bearing.

**Phase 5 — Reward system.** Import `tickets.json` and `rotation.json`. Build the 30-slot reward chart per §7.7, the earn catalog with private-item filtering, the spend tiers with adult-gated redemption, and the Vault. Resolve rotation assignments into each child's Weekly Chore slots. Ticket balance must be visible at rest per §3.7 — a child should see how close they are to 5 without tapping anything.

**Phase 6 — iPhone/iPad v1 ship.** Home Screen and Lock Screen widgets showing today's events and chore progress. Full accessibility audit pass against §10. Performance pass against the 2-second launch target. **This is the first build that goes on the family's devices** — get it in real use before expanding.

**Phase 7 — Mac target.** Activate the macOS target against the existing `FamilyCore`. Menu bar, keyboard shortcuts, pointer and hover states, context menus, window sizing. No new features — this is the same app, natively Mac.

**Phase 8 — Apple Watch target.** Activate the watchOS target. Three screens only: today's events, my chores, mark complete. Digital Crown scrolling. Complication for remaining chores. Resist scope creep here aggressively.

**Phase 9 — Cross-platform audit.** Verify sync consistency across all four platforms, re-run the §10 checklist on each, and confirm no platform-specific code has leaked into `FamilyCore`.

---

## 10. Definition of done

A phase is not complete until all of the following pass:

- [ ] Every screen usable at **AX5** Dynamic Type with no clipping or truncation
- [ ] Full **VoiceOver** walkthrough completes every task without sighted assistance
- [ ] All tap targets meet the 44pt / 60pt minimums
- [ ] Works correctly in **airplane mode**
- [ ] Works in **dark mode**
- [ ] Works with **Reduce Motion** enabled
- [ ] No information conveyed by color alone
- [ ] Child profile cannot reach any destructive action
- [ ] On Mac: every action reachable by keyboard alone, logical tab order
- [ ] On Watch: usable on the smallest supported case, Digital Crown scrolls
- [ ] On iPad: correct in Split View, Slide Over, and both orientations
- [ ] **The kid test:** the youngest child completes the phase's core task unassisted, with no verbal instruction from an adult

That last item is the real acceptance criterion. The rest are how we get there.

---

## 11. Still needed

- [ ] Confirm the oldest device in the house meets the D5 minimums
- [ ] **`rotationEpoch`** — the Sunday that WK1 began. Hard blocker for Phase 5; the app cannot compute the current rotation week without it.
- [ ] **Backend decision.** A separate API repo exists (`Famiy_Appily_api`), which contradicts D4's no-server, CloudKit-only architecture. Given the health-adjacent items on the earn lists, this needs a deliberate answer before Phase 0, not a default.
- [ ] Whether Finley and Maryn have their own individual-goal earn items — Arthur's therapy items were deliberately not copied across
- [ ] Answers to `openQuestions` in `family.json`, `derivationNotes.needsConfirmation` in `tickets.json`, and the Vault question in `tickets.json`
- [ ] List of the calendars to aggregate and who owns each
- [ ] The current reward tiers and what they cost in earned units
