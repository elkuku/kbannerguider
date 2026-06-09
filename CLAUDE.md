# kBannerGuider — Claude Code guide

## What this app does

Flutter Android app for the Ingress game. It shows Bannergress banners nearby, lets you mark them as **To-do / Done / Skip**, and guides you step-by-step through each mission. List types are synced via the Bannergress API. No local persistence beyond theme preference.

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
  main.dart                       # App entry point; wires AuthService
  models/
    banner_item.dart              # BannerItem (title, location, missions[]); author getter
    mission_item.dart             # MissionItem, MissionStepItem, PoiItem, AgentItem
  services/
    auth_service.dart             # Bannergress Keycloak PKCE auth via WebView
    banner_service.dart           # HTTP calls to api.bannergress.com
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
- **Bannergress is the sole source of truth** — nothing is persisted locally
- On sign-in and session restore, `_syncListStates` fetches all three list types (todo/done/blacklist) in parallel and populates the in-memory `_listTypes` map
- `BannerListPage` owns the authoritative `_listTypes` map and passes it down; `BannerDetailPage` returns the updated map via `Navigator.pop(context, _listTypes)`
- `_setListType` in `BannerDetailPage` calls `POST /bnrs/{id}/settings` to persist changes and is idempotent (no-op if value unchanged)
- When not signed in: list type selector, filter bar, and badges are hidden entirely; To-do tab shows only a sign-in prompt
- On sign-out: `_listTypes`, `_todoBanners`, and `_hiddenFilters` are all cleared

### Bannergress auth (optional)
- `AuthService` implements Keycloak PKCE flow via an in-app WebView dialog
- Tokens stored in `flutter_secure_storage`; refresh token used to silently renew
- When signed in, the To-do tab fetches from `GET /bnrs?listTypes=todo` with Bearer token
- Sign-in is optional — browsing works without it; list type features require it

### Guider (step-by-step mission navigator)
- Current mission index is in-memory state only (`_currentMissionIndex` in `BannerDetailPage`)
- Resets to mission 1 each time the detail page is opened
- The map tab shows a numbered marker for the current mission

## Bannergress API

Base URL: `https://api.bannergress.com`

| Endpoint | Use |
|---|---|
| `GET /bnrs?orderBy=proximityStartPoint&proximityLatitude=…&proximityLongitude=…&limit=25&attributes=…` | Nearby banners list |
| `GET /bnrs/{id}` | Banner detail with full missions + steps |
| `GET /bnrs?listTypes=todo&attributes=…` | Authenticated user's list by type (todo/done/blacklist) |
| `POST /bnrs/{id}/settings` | Set list type `{"listType": "todo"}` (requires Bearer token) |

When authenticated, nearby and list-type fetches pass an explicit `attributes` parameter requesting `missions` and `warning` on top of the server's default fields — this is required because the server omits missions from list responses by default, and author names live inside mission data. `BannerItem.author` is a getter derived from `missions.first.author?.name`.

Mission and banner pictures use a relative path stored in `picture`; `pictureUrl` getter resolves them to absolute URLs.

## Bannergress sign-in

- `AuthService` uses the Keycloak endpoint at `login.bannergress.com` with PKCE
- client_id: `bannergress-website`, redirect: `https://bannergress.com/`
- Sign-in is optional — browsing works without it; list types and To-do tab require it

## Important conventions

- `PopScope(canPop: false)` wraps every top-level screen so the system back-gesture still returns `_listTypes` via `Navigator.pop`
- `unawaited()` is used intentionally for fire-and-forget operations (e.g. `_syncListStates`)

## Files worth knowing

| File | Notes |
|---|---|
| `api.md` | Bannergress API response shape reference |
| `plan.md` | Historic design notes / feature backlog |
