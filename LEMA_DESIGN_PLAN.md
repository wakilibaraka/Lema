# Lema Grid — Visual Design Plan

> Co-design working doc. Device under test: **iPhone 18 Pro simulator, Flutter debug**.
> Visual target: travel-app reference screens (extreme radii, frosted glass, off-white canvas, black type).
> Workflow: **one slice = one commit + push**. No slice merges without an iPhone 18 Pro screenshot check.

## 0. Where things live

| Concern | Path |
|---|---|
| Source of truth (edits go here) | `…/Desktop/Web Design/Lema` (Google Drive, git remote `origin/main`) |
| Local build mirror (runs on simulator; Drive FS can't codesign) | `/Users/baraka/Desktop/Lema` |
| New view | `lib/views/lema_grid_view.dart` |
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

Commit convention: `feat(lema): <slice>`, `fix(lema): <…>`, `docs(lema): <…>`.
Push after **every** slice: `git push origin main`.

## Progress

- [x] Baseline: Lema drag-and-drop grid planner v1 (`9ec2a23`)
- [x] Plan doc + gap addendum + Slices 11–15 spec (`b89471d`, `21d2e43`)
- [x] Slice 1 — mobile top bar (`957bc83`)
- [x] Slice 2 — hero typography + scrim (`c5dc5c8`)
- [x] Slice 3 — floating glass tab bar (`705602a`)
- [x] Rename Lema everywhere + Queue/Tasks/Calendar overflow drive-bys (`da71d52`)
- [x] Slice 4 — grid density + drag feel + toast/undo
- [x] Slice 5 — draft seeds + empty states
- [x] Mobile unblock: Calendar stacked layout + Queue badge wrap (`e85db53`)
- [x] Slice 6 — timeline default-open + slot grouping
- [x] Slice 7 — quick-edit time stepper + platform toggle
- [x] Slice 8 — dark-mode pass
- [ ] Slice 9 — tests + hygiene
- [ ] Slice 10 — polish pass
- [ ] Slices 11–15 — signature interactions

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
9. **[Dark mode]** Lema verified light-only. Fix: full dark pass on 18 Pro with dark appearance.
10. **[Hygiene]** No widget tests; `flutter analyze` must stay clean every slice.

## 2b. Gap closure addendum (refinement pass)

Visual language from the new refs (photo-gallery + art-auction apps) is now binding:

- **Face/name pills** (gallery `Ralph`/`Selene` tags) → creator chip on hero meta pill + avatar dots on grid tiles.
- **`Live` status pills** (auction cards) → status pills on tiles: `SCHEDULED` (blue) / `DRAFT` (amber) / `LIVE` = published (green).
- **Category pills + avatar row** (auction) → already covered by filter pills; add platform avatar dots (16px, max 3, platform brand color ring).
- **Countdown card** (`Auction ending in 22:52:34`) → `Posts in 45m` countdown chip in hero sheet (Slice 6).
- **Stacked album cards** (gallery) → draft-stack visual for the Drafts filter empty/pending state (Slice 5).
- **Viewer filmstrip + circular action bar** (photo viewer) → reuse SimulatorView's post filmstrip pattern for hero shuffle; sheet keeps 3-action row (Edit / Duplicate / Delete) in v2 (Slice 7).

### Density rules (binding for all slices)

1. **Platform indicators**: every `_gridTile` shows up to 3 platform dots (16px, brand-color ring, overflow `+n`); every `_slotRow` leads with its platform icon chip. Cross-platform strategy must read at a glance — no tap required.
2. **Aspect ratio policy**: uniform tiles, `BoxFit.cover` center-crop. Grid 3-col = 3:4, 4-col = 1:1. No masonry (keeps drag math + at-a-glance scanning). Hero = cover-fill, no letterbox.
3. **Status badging**: frosted pill top-left of tile: `DRAFT` amber / `QUEUED` blue / `LIVE` green. Status text never relies on color alone.
4. **Media scrims**: video tiles always show glass play badge (top-left under status pill) + `VIDEO`/`REEL` duration pill bottom-right when duration unknown. Image tiles show nothing.
5. **Transient feedback**: `lib/widgets/lema_toast.dart` (new) — frosted toast, three variants (`Saved`/`Moved`/`Error`), 2.5s, single instance. Every `updatePost`/`reorderPosts`/`publishNow` from Lema surfaces one. No silent writes, no blocking spinners for <500ms ops.
6. **Undo reorder**: provider keeps pre-move snapshot; toast carries an **Undo** action for 5s. Accidental drops are one tap from recovery.
7. **Error states**: JSON parse/sync failure → frosted on-brand error card in place of the grid (off-white canvas, retry button). Raw Flutter red screens are a ship-blocker.
8. **Dynamic Type**: Lema subtree wraps `MediaQuery` with `textScaler` clamped to max 1.2x. Clamped titles (Slice 2) and dense slot rows (Slice 6) must survive max accessibility sizes without overflow.

## 3. Slices (commit + push after EACH)

### Slice 1 — Top app bar (mobile)
- Scope: `lib/main.dart` mobile `appBar` only.
- Route-aware short titles (`Lema`, not `Lema Visual Grid`); capsule compresses (dot + handle, sync text hidden < 420pt); hamburger + title + capsule never collide.
- Accept: 18 Pro screenshot, no truncation, no overlap; desktop/tablet untouched.
- Commit: `fix(lema): mobile top bar truncation + capsule crowding`

### Slice 2 — Hero typography + scrim
- Scope: `_buildHeroPreview` only.
- Title 2-line clamp bottom-anchored; hook 2 lines; scrim stops retuned; meta pill pinned above glass sheet; cover-fill, no letterbox bands.
- Accept: screenshots on 2 hero posts (video + image); no mid-word clip over faces.
- Commit: `feat(lema): hero typography + scrim safe zones`

### Slice 3 — Floating tab bar + content padding
- Scope: `lib/main.dart` mobile `bottomNavigationBar` only.
- Floating frosted pill bar (margins 16/12/16/28, radius 26); grid `SliverPadding` bottom ≥ 120; content visibly scrolls under bar.
- Accept: pills + first grid row fully visible above bar; all 5 tabs switch.
- Commit: `feat(lema): floating glass tab bar`

### Slice 4 — Grid density + drag feel
- Scope: `_buildDragGrid` / `_gridTile` + toolbar toggle + NEW `lib/widgets/lema_toast.dart`.
- 3/4-col toggle persisted in-memory (3:4 tiles at 3-col, 1:1 at 4-col per aspect policy); haptic on lift; blue placeholder gap at drop index; `reorderPosts` unchanged.
- Tile upgrades (density rules §1–4): platform dots (16px, max 3, `+n`), status pill (DRAFT amber / QUEUED blue / LIVE green), video glass play badge + media pill.
- Toast infra + reorder Undo: provider snapshot + `undoLastReorder()`; `Moved` toast with Undo (5s).
- Accept: reorder persists across restart (storage); Undo restores order; screenshot of drag state; no overflow at 402pt.
- Commit: `feat(lema): grid density + drag affordance + undo`

### Slice 5 — Draft seeds + empty states
- Scope: `lib/models/post_model.dart` seeds (+ provider filter already exists).
- 3 draft seeds (image + video mix, multi-platform to exercise dots); stats pill shows drafts; Drafts filter + all-empty state screenshotted.
- Draft-stack visual (gallery stacked-album language) for pending drafts; status pills verified on every tile.
- Accept: `N queued · 3 drafts`; each filter combination renders intentionally.
- Commit: `feat(lema): draft seeds + empty states`

### Slice 6 — Timeline accordion
- Scope: `_buildDayAccordion` / `_slotRow`.
- Today expanded by default; `Morning/Afternoon/Evening` group dividers; slot time editing entry point kept as Edit → sheet.
- Accept: cold start shows Today open; collapse/expand animated, no overflow at 402pt.
- Commit: `feat(lema): timeline default-open + slot grouping`

### Slice 7 — Quick-edit sheet v2
- Scope: `_QuickEditSheet` only.
- Time stepper (±15 min, updates `scheduledTime`); platform multi-toggle chips; Save persists + hot UI update + `Saved` toast (viewer 3-action language: primary Save, secondary Duplicate/Delete ok).
- Accept: edit caption + time + platform, verify in grid + timeline same session; toast visible in screenshot.
- Commit: `feat(lema): quick-edit time stepper + platform toggle`

### Slice 8 — Dark-mode pass
- Scope: Lema widgets only (no global theme change).
- Full 18 Pro dark-appearance screenshot set: header, hero, grid, timeline, sheet.
- Accept: contrast ≥ travel-ref feel; no white flashes; glass borders visible on black.
- Commit: `feat(lema): dark-mode pass`

### Slice 9 — Tests + hygiene
- Scope: `test/lema_grid_test.dart` (new).
- Widget tests: filter logic, hashtag count, `reorderPosts` index mapping, day grouping, undo restore, toast dispatch; `flutter analyze` + `flutter test` green.
- Accept: CI-equivalent green locally; screenshot final light+dark.
- Commit: `test(lema): grid logic + provider reorder tests`

### Slice 10 — Polish pass (airtight sign-off)
- Scope: `_gridTile` badges audit + error states + text-scale bound. No new features.
- Badge audit: 16px platform dots legible at 4-col; video pills present on every video tile; status pill contrast on light + dark.
- Error states: corrupt `lema_posts` JSON → frosted on-brand error card with Retry (kill red screen); sync failure → `Error` toast variant.
- Text-scale bound: `MediaQuery.textScaler.clamp(maxScaleFactor: 1.2)` around Lema subtree; verify at max accessibility size, no overflow in hero/title/slot rows.
- Countdown chip: `Posts in 45m` (auction-countdown language) in hero sheet when a post is due within 2h.
- Accept: fault-injection screenshots (corrupt JSON, max text size); light + dark badge set.
- Commit: `feat(lema): polish pass — badges, errors, text-scale`

## 6. Signature interactions (Slices 11–15)

Shared motion spec for all five: spring curves (`Curves.easeOutBack` / `spring` via `AnimationController`), 60fps on 18 Pro (no jank in DevTools timeline), `HapticFeedback` on trigger + settle, `prefers-reduced-motion` respected (crossfade fallback). Each slice ships its own widget file under `lib/widgets/` + a gallery entry point for isolated verification.

### Slice 11 — Circle menu dropdown morph
- Scope: NEW `lib/widgets/morph_pill_menu.dart`, wired to Lema filter pills.
- Tapping a topic pill expands/morphs it into a centered floating modal card (shared-element scale + fade, spring response); action items stagger in (fade + scale, 40ms cascade); dismiss reverses into the originating pill position.
- Implementation: `OverlayPortal` + `RectTween` between pill and card rects; `AnimationController` forward/reverse; staggered `Interval`s.
- Accept: video capture of open + dismiss; reverse lands pixel-aligned on the pill; no overflow at 402pt.
- Commit: `feat(lema): circle menu dropdown morph`

### Slice 12 — Poster reflection on bottom tabs
- Scope: `FloatingTabBar` only.
- Glossy reflection under each tab icon (mirrored icon, gradient mask fade, 40% height) in the Netflix-poster language; selected tab reflection tints blue with the bubble.
- Implementation: `Transform.flip` + `ShaderMask` linear-gradient fade; static (no animation cost); dark-mode dimmed to 25%.
- Accept: light + dark screenshots; reflection never overlaps labels; zero layout shift.
- Commit: `feat(lema): poster reflection on bottom tabs`

### Slice 13 — Intro swipe camera-click showcase
- Scope: NEW `lib/widgets/showcase_carousel.dart`, shown on first launch (persist flag in `StorageService`) + replay from Settings.
- Auto-cycling horizontal cards of editing capabilities; floating shutter button plays a tap animation; on trigger, photo transforms via rapid blur + fade reveal into the AI-styled output, then slides to the next style.
- Implementation: `PageView` auto-advance timer, shutter `GestureDetector` → `ImageFiltered` blur ramp + crossfade; seeded sample assets only (no backend).
- Accept: screen recording of full cycle (3 cards); skip button persists dismissal; cold start unaffected.
- Commit: `feat(lema): intro swipe camera-click showcase`

### Slice 14 — Virtual card morph slide-up
- Scope: hero preview card → NEW `lib/views/card_detail_view.dart`.
- Tapping the hero card triggers a shared-element morph + slide-up into the management view: card expands to top hero position, page elements fade/slide in; horizontal swipe pages between black virtual and light-gray physical card with spring snap.
- Implementation: `Hero` widget on the card + `PageView` (viewportFraction 0.92, spring `PageScrollPhysics`); detail rows stagger in.
- Accept: recording of morph both ways (back = reverse morph); swipe snaps; no hero-tag collisions with grid tiles (unique tags per post id).
- Commit: `feat(lema): virtual card morph slide-up`

### Slice 15 — Daily page-flip calendar
- Scope: `CalendarView` day header only.
- Advancing days triggers a 3D page-curl/flip on the central date digits; lunar/moon/fortune indicators fade + slide; accent color shifts dynamically across month boundary (July red → August blue), tear-away-pad language.
- Implementation: `AnimatedSwitcher` with custom 3D `Matrix4.rotationY` transition; accent derived from focused month; lunar data stubbed locally (no backend).
- Accept: recording crossing a month boundary; flip never clips digits at 402pt; reduced-motion = crossfade.
- Commit: `feat(lema): daily page-flip calendar`

## 4. Out of scope (parked)

- Backend daemon publishing changes; AI Studio copy; macOS window chrome; Android release signing; App Store assets.
- Any change to `UniversalMediaPlayer` internals (treat as black box; overlay around it only).

## 5. Definition of done (every slice)

1. `flutter analyze` clean on touched files.
2. iPhone 18 Pro debug screenshot attached to the commit message body (save under `/tmp`, reference by name).
3. No `RenderFlex overflow` in run log (`grep -i overflow` on the run log).
4. Density rules (§2b) respected: platform dots, status pill, media badge, toast on writes (from Slice 4 onward).
5. `git push origin main` succeeds; local mirror re-synced.
