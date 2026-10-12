# Lema — Technical Plan: Addressing Roadblocks & Issues

## 1. OAuth Token Expiration

**Problem:** Platforms invalidate access tokens; scheduled posts fail silently.

**Plan:**
- Add a `TokenLifecycleService` (in `lib/services/`) that tracks token expiry per connected account and refreshes via platform-specific OAuth refresh-token flows before expiry.
- Create a `lib/providers/auth_provider.dart` to hold auth state per platform (connected, expiring-soon, expired) and expose it to the UI.
- When a scheduled post's platform token is expired or expiring within 24h of publish time, surface a **blocking banner** on the calendar and composer: "Instagram token expired. Reconnect to publish scheduled posts."
- Add a `token_expiry` column to the posts model so the scheduler can fail fast with a clear error rather than silently dropping the post.
- Store encrypted tokens via `flutter_secure_storage` (new dependency) instead of SharedPreferences.

## 2. Media Processing Costs

**Problem:** Large video uploads freeze the app; bandwidth/storage costs scale.

**Plan:**
- Extend `MediaUploadService` with an **asynchronous upload queue** using `flutter_uploader` or a background isolate pattern. Show upload progress in the UI without blocking interaction.
- Integrate cloud storage (AWS S3 via presigned URLs or Firebase Storage) — upload directly from the client to S3, then pass the S3 URL to the platform API. This avoids proxying media through your server.
- Add **client-side validation** before upload: check codec (H.264), resolution (1080x1920 for TikTok/Reels), file size, and format. Warn the user with a clear dialog if constraints aren't met.
- Compress videos client-side using `video_compress` if they exceed platform limits before uploading.

## 3. API Rate Limiting

**Problem:** Many users scheduling at the same time causes mass failures.

**Plan:**
- Implement a **server-side jitter queue** (the recommended approach): when a post is scheduled, enqueue it to a Redis/Celery backend that staggers actual API calls with random 0–120s jitter around the target time.
- On the client, add exponential backoff with retry logic in `ApiService` for 429 responses.
- Show a "Queued — publishing at ~12:03 PM" indicator when jitter is applied so users understand the delay.
- For MVP without a backend: use a local `WorkManager` task that fires at the scheduled time and applies client-side jitter, spreading calls if multiple posts target the same minute.

## 4. App Review Bottlenecks

**Problem:** Meta, Google, and TikTok require manual review before granting API access.

**Plan:**
- Create a **demo/test mode** in the app (toggle in Settings) that uses mock API responses so the app is fully functional for review screencasts without needing production API approval.
- Record screen-capture walkthroughs for each platform's review team showing: OAuth connection flow → composer → scheduling → successful publish → analytics view.
- Prepare `PRIVACY_POLICY.md` and `API_DATA_USAGE.md` documents explaining exactly what data is collected and how each platform's API is used.
- Submit for review early with a feature-complete build; use the waiting period to build the queue/jitter infrastructure.

---

## 5. Feature Implementation Roadmap

### 5.1 Must-Have (MVP)

| Feature | Implementation Approach | Key Files |
|---|---|---|
| **Cross-platform text composer** | Extend existing `AIStudioView` with per-platform tabs (Instagram/TikTok/YouTube/Facebook) and per-platform character counters | `lib/views/ai_studio_view.dart`, `lib/models/platform_info.dart` |
| **Media uploader (Images/Video)** | Build on existing `MediaPickerDialog` + `MediaUploadService` with client-side validation | `lib/widgets/media_picker_dialog.dart`, `lib/services/media_upload_service.dart` |
| **Character counters** | Add platform-aware counters to the composer (IG: 2200, TikTok: 2200, YouTube title: 100) | `lib/models/platform_info.dart` |
| **Visual calendar** | Already implemented (`CalendarView` + `table_calendar`); add gap detection highlights and drag-to-reschedule | `lib/views/calendar_view.dart` |
| **Drafts** | Add `isDraft` flag to `PostModel`; show drafts section in queue view | `lib/models/post_model.dart`, `lib/views/queue_view.dart` |
| **Scheduled time-slots** | Already partially implemented via `QueueSlotModel`; enforce slot conflict detection | `lib/models/queue_slot_model.dart` |
| **Edit/Delete queued posts** | Already supported in `PostsProvider`; add swipe-to-delete on queue | `lib/providers/posts_provider.dart` |
| **Basic analytics per post** | Create `AnalyticsService` to fetch likes/views/comments/shares from each platform's insights API; show in card detail | `lib/services/analytics_service.dart` (new), `lib/views/card_detail_view.dart` |
| **Secure OAuth login** | Add `flutter_secure_storage` + `url_launcher` OAuth flow per platform; store tokens securely | `lib/services/oauth_service.dart` (new), `lib/providers/auth_provider.dart` (new) |
| **Account linking** | Add account connection UI in Settings with per-platform connect/disconnect buttons | `lib/views/settings_view.dart` |
| **Immediate error alerts** | Extend `LemaToa`st` widget to support persistent error banners with action buttons ("Reconnect") | `lib/widgets/lema_toast.dart` |

### 5.2 Good-to-Have (Growth)

| Feature | Implementation Approach |
|---|---|
| **Custom link shortener** | Integrate Bitly API or self-hosted shortener via `ApiService` |
| **Saved hashtag groups** | Add `HashtagGroupModel` + CRUD in a dedicated hashtag library view |
| **Built-in image cropping** | Use `image_cropper` plugin in the media picker flow |
| **Queue auto-fill** | Algorithm that analyzes calendar gaps and suggests recycled or AI-generated content to fill empty slots |
| **Drag-and-drop rescheduling** | Extend `LemaGridView`'s existing drag-and-drop to accept drops onto calendar days |
| **Monthly growth charts** | Use `fl_chart` to render aggregated monthly follower/post-growth line charts |
| **Competitor benchmark tracking** | Create `BenchmarkService` that fetches public metrics for competitor accounts |
| **Team collaboration** | Add role-based access (Admin/Editor/Viewer) via a backend or Firebase; draft approval workflow state machine |
| **Unified DM inbox** | Create `InboxService` pulling messages from IG Graph API, YouTube Comments, TikTok inbox |
| **AI monthly summaries** | Extend `AiService` to compile monthly analytics data into a natural-language summary via Gemini |

### 5.3 Innovative / AI (Scaling)

| Feature | Implementation Approach |
|---|---|
| **AI caption generation** | Already partially implemented via `AiService`/Gemini; add per-platform tone/format presets |
| **AI video hook scripts** | Extend Gemini prompts to generate 3-5s hook scripts based on niche/topic input |
| **Auto-transcription** | Integrate Speech-to-Text (`speech_to_text` plugin) or Whisper API for video captions |
| **Predictive scheduling** | Collect engagement time-of-day data per account; train a simple model or use platform-native "Best Time to Post" signals |
| **Intelligent content recycling** | Identify top-performing evergreen posts after 60+ days; AI-rewrites caption and suggests re-scheduling |
| **Comment sentiment analysis** | Pass comments through Gemini or a lightweight on-device classifier; tag positive/negative/neutral |
| **Automated comment moderation** | Auto-hide or flag comments matching negative sentiment or keyword filters |
| **Smart AI replies** | Generate contextual reply suggestions for common DM/comment patterns via Gemini |

---

## 6. UI/UX Design Solutions

### 6.1 Unified Omnichannel Composer
- Single `ComposerView` with a platform tab bar at top
- Shared core text field + per-platform override fields that appear contextually
- Character counter adapts per selected platform
- Media attachment area with platform-specific constraints shown inline

### 6.2 Reactive Visual Calendar
- Already using `table_calendar`; add:
  - Color-coded day indicators (green = posts scheduled, yellow = 1 slot empty, red = token expired)
  - Drag-and-drop from queue to calendar day
  - Week and month toggle with smooth `LemaMotion` spring transitions

### 6.3 Asset Management Library
- New `MediaLibraryView` with grid of stored assets (logos, intro clips, recurring graphics)
- Tag-based filtering (logo, video, image, thumbnail)
- Direct "Use in Post" action from library to composer

### 6.4 Clear Failure States
- Persistent `ErrorBanner` widget (red, top of screen) with action button
- Per-post failure indicator in queue (red icon + tooltip with error reason)
- Connection status indicator in sidebar/tab bar (green dot = all connected, red = issue)

---

## 7. API Integration Details

### 7.1 Meta Graph API (Instagram & Facebook)
- OAuth flow: Facebook Login → request `instagram_basic`, `instagram_content_publish`, `pages_read_engagement` scopes
- Publishing: `POST /{ig-user-id}/media` for images/carousels, `POST /{ig-user-id}/media_publish` for reels
- Token: 60-day long-lived tokens, refresh every 30 days
- Requirement: Instagram Business/Creator account linked to Facebook Page

### 7.2 TikTok Content Posting API
- OAuth flow: TikTok Login Kit → `video.publish`, `video.upload` scopes
- Publishing: Direct post via `POST /v2/video/publish/` or save to draft
- Video specs: MP4/WebM, 1080x1920, max 10 min (600s)
- Rigorous app audit: submit early with demo video walkthrough

### 7.3 YouTube Data API v3
- OAuth flow: Google Sign-In → `youtube.upload` scope
- Publishing: `POST /upload/youtube/v3/videos` (multipart upload)
- Quota: 1600 units per upload; default daily quota 10,000 units
- Must request quota extension via Google Cloud Console early in development

---

## 8. New Dependencies to Add

```yaml
# OAuth & Security
flutter_secure_storage: ^9.0.0
url_launcher: ^6.2.0
app_links: ^6.1.0          # Deep link callbacks from OAuth

# Media Processing
video_compress: ^3.1.0
image_cropper: ^5.0.0
image_picker: ^1.0.0
photo_manager: ^3.0.0       # Access device media library

# Backend / Queue (for server-based jitter)
dio: ^5.4.0                 # Better HTTP client with interceptors
workmanager: ^0.5.0         # Background task scheduling

# Analytics & Charts
fl_chart: ^0.68.0

# AI / Speech
speech_to_text: ^6.6.0

# State Management (if app grows beyond Provider)
# riverpod: ^2.4.0          # Future migration path
```

---

## 9. Architecture Additions

```
lib/
├── services/
│   ├── oauth_service.dart          # NEW: Per-platform OAuth flow
│   ├── token_lifecycle_service.dart # NEW: Token refresh tracking
│   ├── analytics_service.dart      # NEW: Fetch post insights
│   ├── media_processing_service.dart # NEW: Compress/validate media
│   └── backend_queue_service.dart  # NEW: Server queue client
├── providers/
│   ├── auth_provider.dart          # NEW: Auth state per platform
│   └── media_library_provider.dart # NEW: Asset library state
├── views/
│   ├── composer_view.dart          # NEW: Unified omnichannel composer
│   ├── media_library_view.dart     # NEW: Asset management
│   ├── analytics_view.dart         # NEW: Post-level analytics
│   └── inbox_view.dart             # NEW: Unified DM inbox
└── widgets/
    ├── error_banner.dart           # NEW: Persistent error state
    ├── connection_status_dot.dart  # NEW: Platform connection indicator
    └── platform_tab_bar.dart       # NEW: Composer platform tabs
```

---

## 10. Phased Delivery Timeline

| Phase | Duration | Deliverables |
|---|---|---|
| **Phase 1: MVP** | 4-6 weeks | OAuth, composer, calendar, scheduling, basic analytics, error handling |
| **Phase 2: Growth** | 3-4 weeks | Queue auto-fill, drag reschedule, media library, hashtag groups, monthly charts |
| **Phase 3: AI/Scaling** | 4-6 weeks | Predictive scheduling, content recycling, sentiment analysis, smart replies |
| **Phase 4: Polish & Review** | 2-3 weeks | App review submissions, demo mode, screencast recordings, performance optimization |

---

## 11. Risk Mitigation Summary

| Risk | Mitigation |
|---|---|
| Token expiry killing scheduled posts | Proactive refresh + UI warning 24h before expiry |
| Media upload cost blowup | Direct-to-S3 client uploads, compression, validation |
| Rate limit mass failures | Server-side jitter queue with 0-120s randomization |
| App review delays | Build demo mode early; submit reviews in parallel with development |
| YouTube quota exhaustion | Request quota extension in week 1; implement upload queue with quota awareness |
| TikTok audit complexity | Prepare detailed screencast + data usage docs before submission |
