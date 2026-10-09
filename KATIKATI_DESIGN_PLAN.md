# Katikati Grid — Visual Design Plan

> Co-design working doc. Device under test: **iPhone 18 Pro simulator, Flutter debug**.
> Visual target: travel-app reference screens (extreme radii, frosted glass, off-white canvas, black type).
> Workflow: **one slice = one commit + push**. No slice merges without an iPhone 18 Pro screenshot check.

## 0. Where things live

| Concern | Path |
|---|---|
| Source of truth (edits go here) | `…/Desktop/Web Design/Lema` (Google Drive, git remote `origin/main`) |
| Local build mirror (runs on simulator; Drive FS can't codesign) | `/Users/baraka/Desktop/Lema` |
| New view | `lib/views/katikati_grid_view.dart` |
| Wiring | `lib/main.dart`, `lib/widgets/sidebar_navigation.dart` |
| Data ops | `lib/providers/posts_provider.dart` (`reorderPosts`, `updatePost`) |
| Design tokens | `lib/theme/apple_theme.dart`, `lib/widgets/apple_glass_card.dart` |
| Media | `lib/widgets/media_player_widget.dart` (`UniversalMediaPlayer`) |

Sync Drive → local after every edit:

```bash
rsync -a --exclude=build --exclude=.dart_tool \
  "/Users/baraka/Library/CloudStorage/GoogleDrive-emmanuelbaraka254@gmail.com/Other computers/My Mac (1)/Desktop/Web Design/Lema/lib/" \
  /Users/baraka/Desktop/Lema/lib/
```

Run / verify loop (from `/Users/baraka/Desktop/Lema`):

```bash
flutter run -d 130A52D4-A743-4AB1-8A05-2727E3620EF2 --debug   # iPhone 18 Pro
# press r = hot reload, R = hot restart
xcrun simctl io 130A52D4-A743-4AB1-8A05-2727E3620EF2 screenshot /tmp/live.png && open /tmp/live.png
```

> Correct 18 Pro UDID: `130A52D4-A743-4AB1-8A05-2727E3620EF2` (verify with `xcrun simctl list devices`).

Commit convention: `feat(katikati): <slice>`, `fix(katikati): <…>`, `docs(katikati): <…>`.
Push after **every** slice: `git push origin main`.

## 1. Design tokens (frozen for all slices)

- Canvas light `#F5F5F8`, card white, ink black `#000` / charcoal `#3A3A3C`, muted `black54`.
- Radii: stat pill 28, hero card 32, grid tile 22, filter pill 20, accordion 26, sheet 28 top.
- Shadows: `black 8–14% alpha, blur 14–30, y 6–16`. Dark mode: `black 25–35%`.
- Glass: `BackdropFilter blur 14–28`, white alpha 38–70 overlays, 1px `white60` borders.
- Accent lime `#D3E157` reserved for the primary forward action only.
- Type: eyebrow 10–11pt / 800 / +1.0–1.6 spacing; headline 30–32pt / 900 / −1.0; body 12–14pt.

## 2. Screenshot audit (iPhone 18 Pro, baseline v1)

Observations from the live screenshot, ranked:

1. **[Top bar]** Title truncates to `Katik…` and the `@emmsdigitalmedia | OFFLINE SYNC` capsule crowds it (`lib/main.dart` mobile `appBar`). Fix: shorter title per route, capsule shrinks to dot+handle, no overlap at 402pt width.
2. **[Hero]** Title clips mid-word `(The A…` over faces; hook line `why t…` truncates hard. Fix: 2-line title clamp with bottom-anchored gradient, hook 2 lines max, meta pill never overlaps faces (move to bottom sheet zone).
3. **[Hero]** Video letterboxes with black bands; burned-in captions collide with overlay text. Fix: `BoxFit.cover` fill + dark scrim stops tuned (0.0/0.3/0.6/1.0), title block bottom-anchored above glass sheet.
4. **[Content/tab overlap]** Filter-pills row sits half under the bottom tab bar on first paint. Fix: floating glass tab bar + `SliverPadding` bottom ≥ 120, tab bar translucent so grid scrolls beneath.
5. **[Data]** `0 Draft ideas` — empty state untested visually. Fix: seed 3 drafts so stats, filters, grid-empty and draft styling all render.
6. **[Grid]** No density choice; drag has no haptic/placeholder. Fix: 3/4-col toggle, `HapticFeedback`, drop-target placeholder gap.
7. **[Timeline]** All days collapsed on load; slot rows dense. Fix: Today expanded by default, clearer `Morning/Afternoon/Evening` grouping.
8. **[Sheet]** Quick-edit lacks time editing. Fix: time stepper (±15m) + platform multi-toggle in sheet.
9. **[Dark mode]** Katikati verified light-only. Fix: full dark pass on 18 Pro with dark appearance.
10. **[Hygiene]** No widget tests; `flutter analyze` must stay clean every slice.

## 3. Slices (commit + push after EACH)

### Slice 1 — Top app bar (mobile)
- Scope: `lib/main.dart` mobile `appBar` only.
- Route-aware short titles (`Katikati`, not `Katikati Visual Grid`); capsule compresses (dot + handle, sync text hidden < 420pt); hamburger + title + capsule never collide.
- Accept: 18 Pro screenshot, no truncation, no overlap; desktop/tablet untouched.
- Commit: `fix(katikati): mobile top bar truncation + capsule crowding`

### Slice 2 — Hero typography + scrim
- Scope: `_buildHeroPreview` only.
- Title 2-line clamp bottom-anchored; hook 2 lines; scrim stops retuned; meta pill pinned above glass sheet; cover-fill, no letterbox bands.
- Accept: screenshots on 2 hero posts (video + image); no mid-word clip over faces.
- Commit: `feat(katikati): hero typography + scrim safe zones`

### Slice 3 — Floating tab bar + content padding
- Scope: `lib/main.dart` mobile `bottomNavigationBar` only.
- Floating frosted pill bar (margins 16/12/16/28, radius 26); grid `SliverPadding` bottom ≥ 120; content visibly scrolls under bar.
- Accept: pills + first grid row fully visible above bar; all 5 tabs switch.
- Commit: `feat(katikati): floating glass tab bar`

### Slice 4 — Grid density + drag feel
- Scope: `_buildDragGrid` / `_gridTile` + toolbar toggle.
- 3/4-col toggle persisted in-memory; haptic on lift; blue placeholder gap at drop index; `reorderPosts` unchanged.
- Accept: reorder persists across restart (storage); GIF/screenshot of drag state.
- Commit: `feat(katikati): grid density toggle + drag affordance`

### Slice 5 — Draft seeds + empty states
- Scope: `lib/models/post_model.dart` seeds (+ provider filter already exists).
- 3 draft seeds (image + video mix); stats pill shows drafts; Drafts filter + all-empty state screenshotted.
- Accept: `N queued · 3 drafts`; each filter combination renders intentionally.
- Commit: `feat(katikati): draft seeds + empty states`

### Slice 6 — Timeline accordion
- Scope: `_buildDayAccordion` / `_slotRow`.
- Today expanded by default; `Morning/Afternoon/Evening` group dividers; slot time editing entry point kept as Edit → sheet.
- Accept: cold start shows Today open; collapse/expand animated, no overflow at 402pt.
- Commit: `feat(katikati): timeline default-open + slot grouping`

### Slice 7 — Quick-edit sheet v2
- Scope: `_QuickEditSheet` only.
- Time stepper (±15 min, updates `scheduledTime`); platform multi-toggle chips; Save persists + hot UI update.
- Accept: edit caption + time + platform, verify in grid + timeline same session.
- Commit: `feat(katikati): quick-edit time stepper + platform toggle`

### Slice 8 — Dark-mode pass
- Scope: Katikati widgets only (no global theme change).
- Full 18 Pro dark-appearance screenshot set: header, hero, grid, timeline, sheet.
- Accept: contrast ≥ travel-ref feel; no white flashes; glass borders visible on black.
- Commit: `feat(katikati): dark-mode pass`

### Slice 9 — Tests + hygiene
- Scope: `test/katikati_grid_test.dart` (new).
- Widget tests: filter logic, hashtag count, `reorderPosts` index mapping, day grouping; `flutter analyze` + `flutter test` green.
- Accept: CI-equivalent green locally; screenshot final light+dark.
- Commit: `test(katikati): grid logic + provider reorder tests`

## 4. Out of scope (parked)

- Backend daemon publishing changes; AI Studio copy; macOS window chrome; Android release signing; App Store assets.
- Any change to `UniversalMediaPlayer` internals (treat as black box; overlay around it only).

## 5. Definition of done (every slice)

1. `flutter analyze` clean on touched files.
2. iPhone 18 Pro debug screenshot attached to the commit message body (save under `/tmp`, reference by name).
3. No `RenderFlex overflow` in run log (`grep -i overflow /tmp/katikati_18pro.log`).
4. `git push origin main` succeeds; local mirror re-synced.
