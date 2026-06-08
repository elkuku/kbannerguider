# kBannerGuider — Claude Code guide

## What this app does

Flutter Android app for the Ingress game. It shows Bannergress banners nearby, lets you mark them as **To-do / Done / Skip**, and guides you step-by-step through each mission. User progress (list types, guider index) is synced to Google Drive so it survives reinstalls.

## Build & deploy

After every code change:

```bash
./build.sh
```

This stamps the build with the current datetime (`YYYYMMDD-HHmm`), embeds it in the title bar via `--dart-define=APP_VERSION=...`, copies the APK to `build/app/outputs/flutter-apk/kbannerguider-<version>.apk`, then installs it.

Target device: Pixel 6a (`23191JEGR03752`).

For analysis/type-checking only:

```bash
flutter analyze
flutter test
```

## Architecture

```
lib/
  main.dart                       # App entry point; wires AuthService + LocalStorageService
  models/
    banner_item.dart              # BannerItem (title, location, missions[])
    mission_item.dart             # MissionItem, MissionStepItem, PoiItem, AgentItem
  services/
    auth_service.dart             # Bannergress Keycloak PKCE auth via WebView
    banner_service.dart           # HTTP calls to api.bannergress.com (incl. fetchTodos)
    cache_service.dart            # SharedPreferences cache (24 h TTL) for todoBanners
    local_storage_service.dart    # Persistent storage for listTypes + guiderProgress
    location_service.dart         # Geolocator wrapper
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
- Stored locally in SharedPreferences via `LocalStorageService` (permanent, no TTL)
- `BannerListPage` owns the authoritative `_listTypes` map and passes it down; `BannerDetailPage` returns the updated map via `Navigator.pop(context, _listTypes)`
- `_setListType` in `BannerDetailPage` is idempotent (no-op if value unchanged)

### Bannergress auth (optional)
- `AuthService` implements Keycloak PKCE flow via an in-app WebView dialog
- Tokens stored in `flutter_secure_storage`; refresh token used to silently renew
- When signed in, the To-do tab fetches from `GET /bnrs?listTypes=todo` with Bearer token
- When not signed in, the To-do tab shows banners with locally-set `todo` type

### Local persistence
- `LocalStorageService` stores list types and guider progress in SharedPreferences
- `CacheService` provides a 24 h SharedPreferences cache for todo banner details

### Guider (step-by-step mission navigator)
- Current mission index + mission ID are saved locally under `local_guider_progress`
- The map tab in `BannerDetailPage` shows a numbered marker for the current mission

## Bannergress API

Base URL: `https://api.bannergress.com`

| Endpoint | Use |
|---|---|
| `GET /bnrs?orderBy=proximityStartPoint&proximityLatitude=…&proximityLongitude=…&limit=100` | Nearby banners list |
| `GET /bnrs/{id}` | Banner detail with missions |
| `GET /bnrs?listTypes=todo` | Authenticated user's todo list (requires Bearer token) |

Mission pictures and banner pictures use a relative path stored in `picture`; `pictureUrl` getter resolves them to absolute URLs.

## Bannergress sign-in

- `AuthService` uses the Keycloak endpoint at `login.bannergress.com` with PKCE
- client_id: `bannergress-website`, redirect: `https://bannergress.com/`
- Sign-in is optional — the app works fully without it (list types saved locally only)

## Important conventions

- `PopScope(canPop: false)` wraps every top-level screen so the system back-gesture still returns `_listTypes` via `Navigator.pop`
- To-do banners are fetched in parallel with `Future.wait` (local mode) or a single API call (auth mode)
- `unawaited()` is used intentionally for fire-and-forget cache saves

## Files worth knowing

| File | Notes |
|---|---|
| `api.md` | Bannergress API response shape reference |
| `plan.md` | Historic design notes / feature backlog |
