# Lema — Visual Design Plan (v2: Backdrop)

> Co-design working doc. Visual target: **[expo-backdrop](https://github.com/rit3zh/expo-backdrop)** —
> Instagram-inspired event feed: off-white canvas, near-black type, story rings with
> gradient outlines, event cards (bold title / grey subtitle / meta pill row / tilted
> media strip / stats row), circular glass header buttons, floating dark create pill.
> Workflow: **one slice = one commit**. No slice merges without a screenshot check.

## 0. Where things live

| Concern | Path |
|---|---|
| Working copy (git remote `origin/main`) | `/Users/baraka/Desktop/Lema` |
| Home surface (the Backdrop canvas) | `lib/views/lema_grid_view.dart` |
| Backdrop design tokens | `lib/theme/backdrop_theme.dart` |
| Story rings (platform row) | `lib/widgets/backdrop/story_rings.dart` |
| Tilted media strip + dashed add tile | `lib/widgets/backdrop/tilted_media_strip.dart` |
| Find / queue-health sheets | `lib/widgets/backdrop/backdrop_sheets.dart` |
| Wiring | `lib/main.dart`, `lib/widgets/sidebar_navigation.dart` |
| Data ops | `lib/providers/posts_provider.dart` (`reorderPosts`, `updatePost`) |
| Legacy tokens (Apple language, other screens) | `lib/theme/apple_theme.dart` |
| Media | `lib/widgets/media_player_widget.dart` (`UniversalMediaPlayer`) |

Run / verify loop (from `/Users/baraka/Desktop/Lema`):

```bash
flutter analyze
flutter test
flutter run -d macos --debug      # desktop shell
flutter run -d web-server --web-port=8799 --web-hostname=127.0.0.1  # browser preview
# → open http://127.0.0.1:8799; the web socket server needs no Chrome driver.
```

Commit convention: `feat(lema): <slice>`, `fix(lema): <…>`, `docs(lema): <…>`.

## 1. Design tokens — Backdrop v2 (binding for the Home surface)

- Canvas: light `#F5F5F8` (kept — it already matches the reference), dark `#0E0E10`.
- Cards: white (light) / `#16161B` (dark); radius **24**; hairline border `black 8%` /
  `white 10%`; shadow `black 6–10%, blur 20–24, y 8–10`.
- Ink: primary `#0A0A0C` (light) / white (dark); secondary `#6E6E76` / `white60`;
  tertiary `#A0A0A8` / `white38`.
- **Story-ring gradient** (signature): `#FEDA75 → #FA7E1E → #D62976 → #962FBF → #4F5BD5`
  (Instagram). Selected ring = solid `#D62976`. Unwatched/dim ring = grey 25%.
- Accent magenta `#D62976` replaces system blue as the Home interactive accent
  (dock selection, add badges). Platform brand colors keep their meaning on chips/dots.
- Type: eyebrow 11/800/+1.6 (the pinned `LEMA` mark); card title 22–24/800/−0.6;
  prompt 18/800/−0.4; subtitle 13/500 secondary; meta 12/600; ring labels 11/500.
- Circular glass buttons (header): 38pt circle, white/70 (light) or `white 12%` (dark),
  1px hairline, 18pt icon.
- Floating create pill: dark translucent (`black 55%` + blur 20), white label 14/700,
  full radius, centered, ≥16pt above the tab-bar clearance.
- Lime `#D3E157` stays reserved (showcase shutter only) — no longer the primary accent.

## 2. Backdrop design language → existing model (integration map)

The reference is an events app; Lema's `PostModel` **is** the event. Mapping is
presentation-only — no model, provider, or service changes:

| Backdrop element | Lema source of truth |
|---|---|
| Header avatar + prompt | Fixed brand avatar + "What's your next post?" prompt; pinned `LEMA` eyebrow + `Tap, drag, ship.` subcopy stay |
| 🔍 search circle | Find sheet: text filter over existing `PostsProvider.posts` (title/caption), tap → existing `CardDetailView` |
| 🔔 bell circle | Queue-health sheet: overdue (`isOverdue`) + failed posts, empty → "All caught up" |
| "Your story" + tile | "New post" ring (+ badge) → existing Compose destination |
| Story rings | One ring per `platformsMap` entry (brand icon + color); tap toggles a platform filter on hero pool, grid and timeline |
| Event card title/subtitle | Day group: day label + `${n} posts · start time` |
| Meta pill row | Platform chips (brand colors) for that day's posts |
| Tilted photo strip | Day's posts rendered as tilted `UniversalMediaPlayer` thumbnails (tap → `CardDetailView`) |
| Dashed `+` tile | Opens Compose (add media/post to the queue) |
| 💬 34 · 👥 6 · Share Invite row | Existing per-post stats live in tiles/queue; the day card's stats line is `posts · start` (no invented engagement numbers) |
| Floating "+ Create New Event" pill | Floating "+ New post" pill on Home → Compose |

Deliberately **not** copied: engagement counts the data doesn't have, story
viewing/progress rings (rings are filters, not stories), full-screen story player.

## 3. Home surface spec (section by section)

1. **Header row** — `LEMA` eyebrow; 42pt gradient-ring avatar + prompt
   "What's your next post?" + two circular glass buttons (search / bell);
   `Tap, drag, ship.` subcopy line beneath. No overflow at 402pt (prompt wraps,
   buttons keep 38pt fixed).
2. **Story rings row** — horizontal scroll, no scrollbar; "New post" ring first,
   then the 6 platforms; 62pt ring + 11pt label; selected platform gets the solid
   magenta ring + bold label; tapping again clears the filter.
3. **Stats strip** — UNCHANGED (tests pin center alignment + shuffle on the axis).
4. **Hero card** — UNCHANGED structurally (morph source; tests pin
   `home_hero_card` and the `YOUR NEXT POST · <PLATFORM>` pill + menu).
5. **Filter pills + density toggle + drag grid** — UNCHANGED (pinned strings and
   drag behavior).
6. **Timeline day accordions → event cards** — header becomes backdrop-style
   (bold day title, `n posts · start` subtitle, platform chips row, chevron);
   expanded body **leads with the tilted media strip** (≤4 thumbnails, rotations
   −4°…+4°, white borders, shadow) + trailing dashed `+` tile, then the existing
   Morning/Afternoon/Evening slot rows (Edit → quick-edit kept).
7. **Floating create pill** — dark translucent "+ New post" pill, bottom-center
   of Home content, sits in the existing 140pt bottom clearance. **Only on the
   dock layouts only (<768pt).** The sidebar layouts reserve no clearance band, so
   the pill rendered on top of the filter-pill row and covered live tap
   targets; those layouts already expose Composer in the sidebar.
8. **Dock** — selection tint follows the accent: magenta bubble/label in light,
   keeps reflections, haptics, dock geometry (all pinned by tests).

## 4. Binding test constraints (read before touching Home)

`flutter test` encodes the following; the Backdrop restyle must preserve every one:

- Pinned Home strings: `LEMA`, `Tap, drag, ship.`, `FEED GRID · DRAG TO REORDER`,
  `Today's timeline`, `QUEUED`/`DRAFT` pills, density labels `3`/`4`,
  `Queued posts` + `Draft ideas` (center-aligned), error card
  `Couldn't load your queue` + `Reset to starter posts`.
- Keys: `home_stats_shuffle` (exactly centered horizontally), `home_hero_card`,
  `mobile_body_clearance`.
- Hero pill `YOUR NEXT POST · <PLATFORM>` + its morph menu.
- `FloatingTabBar`: 5 tabs, exactly 10 icons (5 + 5 reflections), 5 ShaderMask
  reflections, 28pt top-radius dock, edge-to-edge width.
- Media matrix (desktop boot): **exactly one** autoplay non-thumbnail player
  (the hero); every new strip/thumbnail player must pass `thumbnail: true,
  autoPlay: false`.
- Overflow matrix at 402 / 430 / 768pt (size_matrix_test) — header row, rings,
  day cards and create pill must all fit.
- New UI must not introduce texts that collide with existing exact-text
  assertions (e.g. a bare `Instagram` find) — ring labels use platform names,
  which no test looks up as bare exact text today.

## 5. Density rules (still binding, trimmed)

1. Every grid tile keeps platform dots, status pill, video badges (unchanged).
2. Aspect policy unchanged: 3-col 3:4, 4-col 1:1, uniform, `BoxFit.cover`.
3. Status text never relies on color alone.
4. Transient feedback via `lema_toast`; undo reorder kept.
5. Error states render the frosted error card — never a red screen.
6. Text scale clamped to 1.2× across the Lema subtree.

## 6. Slice log

- [x] v1 — baseline grid planner → Slices 1–22 (see git history; travel-ref
      language, hero morph, dock, showcase, calendar flip, queue states, etc.)
- [x] **Slice 23 — Backdrop restyle (Home)**
      - New: `lib/theme/backdrop_theme.dart`, `lib/widgets/backdrop/*`.
      - Home header → backdrop row (avatar + prompt + search/bell circles).
      - Story rings row (PlatformInfo-driven, filters grid/hero/timeline).
      - Day accordions → event cards with tilted media strip + dashed add tile.
      - Floating "+ New post" pill (dock layouts only); dock accent → magenta.
      - Accept: `flutter analyze` clean, full `flutter test` green (all §4 pins),
        browser preview screenshot check light + dark.

## 6a. Migration roadmap (v2 → whole app)

Direction agreed with the user: **unify on Backdrop, one surface per slice**, each
slice screenshot-verified with `flutter analyze` + the full suite green before the
next starts. The `AppleTheme` class stays (tests use it as a host theme); surfaces
stop *reading its tokens* one at a time.

Inventory at the start of the migration: **24 files read `AppleTheme`**, 5 read
`BackdropTheme` (Home only). Order is by leverage — the frame before the rooms:

| # | Slice | Files |
|---|---|---|
| 24 | **Theme plumbing + shell** (this slice) | `backdrop_theme.dart` (`lightTheme`/`darkTheme` + shell tokens), `main.dart`, `window_title_bar.dart`, `sidebar_navigation.dart`, `dynamic_capsule.dart` |
| 25 | Queue + its dispatch sheets | `queue_view.dart` |
| 26 | Composer | `composer_view.dart`, `media_picker_dialog.dart`, `schedule_time_picker.dart` |
| 27 | Calendar | `calendar_view.dart` |
| 28 | AI Studio + Hooks | `ai_studio_view.dart`, `hooks_pipeline_view.dart` |
| 29 | Settings + Tasks + Analytics | `settings_view.dart`, `tasks_view.dart`, `analytics_view.dart` |
| 30 | Simulator + Simulation | `simulator_view.dart`, `simulation_view.dart` |
| 31 | Shared widgets | `apple_glass_card.dart` (→ `glass_card.dart`), `error_banner.dart`, `lema_toast.dart`, `morph_pill_menu.dart`, `media_player_widget.dart`, `card_detail_view.dart`, `connection_status_dot.dart` |

Slice 31 lands last because every earlier slice embeds those widgets; migrating
them late means each screen is restyled twice at most, never three times.

`colorScheme` is read **nowhere** in `lib/` (verified: zero matches), so swapping
the global `ThemeData` is safe — screens read static tokens, not the scheme.

## 7. Out of scope (parked)

- Backend daemon publishing; AI Studio copy; macOS window chrome; store assets.
- `UniversalMediaPlayer` internals (black box; overlay only).
- Story *viewing* (progress rings, full-screen player) — rings are filters.
- Engagement counts that the data model does not have.

## 8. Definition of done (every slice)

1. `flutter analyze` clean.
2. Full `flutter test` green — §4 pins are regression contract.
3. No `RenderFlex overflow` at 402/430/768pt (size matrix).
4. Screenshot check on the Home surface, light **and** dark.
5. Density rules (§5) respected.
