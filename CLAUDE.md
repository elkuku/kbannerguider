# kBannerGuider — Claude Code guide

## What this app does

Flutter Android app for the Ingress game. It shows Bannergress banners nearby, lets you mark them as **To-do / Done / Skip**, and guides you step-by-step through each mission. User progress (list types, guider index) is synced to Google Drive so it survives reinstalls.

## Build & deploy

After every code change:

```bash
flutter build apk && flutter install
```

Target device: Pixel 6a (`23191JEGR03752`).

For analysis/type-checking only:

```bash
flutter analyze
flutter test
```

## Architecture

```
lib/
  main.dart                   # App entry point; wires AuthService + DriveService
  config.dart                 # googleOAuthClientId (OAuth Web Client ID)
  models/
    banner_item.dart          # BannerItem (title, location, missions[])
    mission_item.dart         # MissionItem, MissionStepItem, PoiItem, AgentItem
  services/
    auth_service.dart         # Wraps google_sign_in; exposes authenticationEvents stream
    banner_service.dart       # HTTP calls to api.bannergress.com
    cache_service.dart        # SharedPreferences cache (24 h TTL) for listTypes + todoBanners
    drive_service.dart        # Read/write JSON file on Google Drive (drive.file scope)
    location_service.dart     # Geolocator wrapper
  screens/
    banner_list_page.dart     # Home: Nearby tab + To-do tab; filter bar; location bar
    banner_detail_page.dart   # Detail: Missions tab + Map tab; list-type picker; guider
    location_picker_page.dart # flutter_map picker for custom search center
  utils/
    format.dart               # formatMeters(int) → "X m" / "X.X km"
  widgets/
    full_image_dialog.dart    # Full-screen image overlay (Hero animation source)
```

## Key data flows

### List types (To-do / Done / Skip / None)
- Stored in Drive as `{ "listTypes": { "<bannerId>": "todo"|"done"|"blacklist"|"none" } }`
- Also cached locally in SharedPreferences (24 h TTL) so the list appears instantly on app open
- `BannerListPage` owns the authoritative `_listTypes` map and passes it down; `BannerDetailPage` returns the updated map via `Navigator.pop(context, _listTypes)`
- `_setListType` in `BannerDetailPage` is idempotent (no-op if value unchanged) and shows an undo SnackBar

### Drive persistence
- `DriveService` maintains an in-memory cache of the JSON payload (`_cachedData`) and a cached `DriveApi` instance (`_cachedApi`)
- On sign-out, `invalidate()` clears both caches and the file ID
- All `save*` methods do an optimistic in-memory update before uploading

### Guider (step-by-step mission navigator)
- Current mission index + mission ID are saved to Drive under `guiderProgress[bannerId]`
- The map tab in `BannerDetailPage` shows a numbered marker for the current mission

## Bannergress API

Base URL: `https://api.bannergress.com`

| Endpoint | Use |
|---|---|
| `GET /bnrs?orderBy=proximityStartPoint&proximityLatitude=…&proximityLongitude=…&limit=100` | Nearby banners list |
| `GET /bnrs/{id}` | Banner detail with missions |

Mission pictures and banner pictures use a relative path stored in `picture`; `pictureUrl` getter resolves them to absolute URLs.

## Google sign-in / Drive

- Scope: `drive.file` (only files created by this app)
- OAuth Web Client ID configured in `lib/config.dart`
- `AuthService.initialize()` attempts silent sign-in on startup via `attemptLightweightAuthentication()`
- `DriveService._getApi()` re-uses the cached `DriveApi`; `invalidate()` must be called on sign-out

## Important conventions

- `PopScope(canPop: false)` wraps every top-level screen so the system back-gesture still returns `_listTypes` via `Navigator.pop`
- The Drive debug card (`_DriveDebugCard`) is guarded by `kDebugMode` — it only appears in debug builds
- To-do banners are fetched in parallel with `Future.wait`
- `unawaited()` is used intentionally for fire-and-forget cache saves

## Files worth knowing

| File | Notes |
|---|---|
| `lib/config.dart` | OAuth client ID — do not commit real credentials to a public repo |
| `SETUP.md` | One-time Google Cloud / OAuth setup steps |
| `api.md` | Bannergress API response shape reference |
| `plan.md` | Historic design notes / feature backlog |
