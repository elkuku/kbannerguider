# Architecture

## Directory Layout

```
lib/
  main.dart                         # App entry point; theme management; AuthService wiring
  version.dart                      # APP_VERSION compile-time constant
  models/
    banner_item.dart                # BannerItem — banner data + pictureUrl / author getters
    mission_item.dart               # MissionItem, MissionStepItem, PoiItem, AgentItem
  services/
    auth_service.dart               # Bannergress Keycloak PKCE auth via WebView dialog
    banner_service.dart             # HTTP calls to api.bannergress.com
    location_service.dart           # Geolocator wrapper (permission handling)
  screens/
    banner_list_page.dart           # Home: Nearby tab + To-do tab + filter + location bar
    banner_detail_page.dart         # Detail: Missions tab + Map tab + list-type picker + guider
    location_picker_page.dart       # flutter_map picker for custom search center
  utils/
    format.dart                     # formatMeters, factionColor, missionColor, launch()
  widgets/
    banner_map.dart                 # FlutterMap widget + guider bar overlay + legend
    banner_tile.dart                # List tile for a single BannerItem
    filter_bar.dart                 # Horizontal chip filter strip (To-do/Done/Skip/Unsorted)
    full_image_dialog.dart          # Full-screen zoomable image overlay
    guider_bar.dart                 # Mission navigator bar (–, counter, +, Start/Next/Done)
    list_type_selector.dart         # Four-button selector (None/To-do/Done/Skip)
    location_bar.dart               # GPS / custom-center coordinate display strip
    mission_tile.dart               # ExpansionTile for a mission + _StepTile + InfoRow
    sign_in_banner.dart             # Card prompting sign-in or showing auth error
```

## Key Principles

### No local persistence (except theme)
Bannergress is the single source of truth for all list types (To-do / Done / Skip). The in-memory `_listTypes` map in `BannerListPage` is rebuilt from the API on every sign-in and session restore. No SQLite, no Hive, no shared-preferences storage for banner data.

The only thing persisted between sessions is the `dark_mode` boolean in `SharedPreferences`.

### List type map ownership
`BannerListPage` owns the canonical `Map<String, String> _listTypes` (banner ID → list type string). It is passed down to `BannerDetailPage`, which returns an updated copy through `Navigator.pop(context, _listTypes)`. `PopScope(canPop: false)` on every top-level screen guarantees the map is always returned regardless of how the user navigates back (gesture, back button, hardware key).

### Auth as optional dependency
`AuthService` is created once in `main.dart` and injected into `BannerListPage`. If `authService` is null (e.g. in tests), all auth-dependent UI is hidden. `BannerListPage._getToken()` is a thin callback that delegates to `AuthService.getAccessToken()` and is passed as a `Future<String?> Function()` into child widgets, keeping them decoupled from `AuthService`.

### Fire-and-forget for non-critical background work
`unawaited(_syncListStates(token))` is used intentionally on sign-in and session restore. This pre-fetches the full list-type map in the background without blocking the UI.

---

## Data Flows

### 1. App startup

```
main()
  └─ KBannerGuiderApp
       └─ BannerListPage.initState()
            ├─ _fetchBanners()        # gets GPS → fetches nearby 25 banners
            └─ _checkAuth()
                 ├─ auth.isLoggedIn() # checks stored refresh token
                 └─ (if logged in) unawaited(_syncListStates(token))
                                      # parallel fetch of todo/done/blacklist lists
```

### 2. Nearby banner fetch

```
_fetchBanners()
  ├─ LocationService.getCurrentPosition()   # request GPS (prompt if needed)
  ├─ BannerService.fetchNearby(lat, lng, token?)
  │     └─ GET /bnrs?orderBy=proximityStartPoint&...&limit=25
  └─ (if token) _mergeListTypes(banners)    # merge server-returned listType into _listTypes
```

Infinite scroll: `_nearbyScrollController` listener triggers `_fetchMoreBanners()` with `offset = _banners.length` when within 300 px of the end.

### 3. List type update

```
User taps list type button in BannerDetailPage
  └─ _setListType(type)
       ├─ optimistic UI update (_listTypes updated immediately)
       └─ BannerService.setListType(id, type, token)
              └─ POST /bnrs/{id}/settings  {"listType": "todo"}
```

On return from `BannerDetailPage`, `BannerListPage` receives the updated map via `Navigator.pop` and calls `setState`, triggering a re-render of any visible badges.

### 4. Session restore / token refresh

```
AuthService.getAccessToken()
  ├─ read 'bg_access_token' from flutter_secure_storage
  ├─ if null → return null
  ├─ _isTokenExpiredOrSoon(token)?
  │     decodes JWT exp claim; true if expires within 60 s
  └─ if expiring → refreshIfNeeded()
          └─ POST /bnrs/token  {grant_type: refresh_token}
               ├─ success → save new tokens → return new access token
               └─ failure → logout() → return null
```

Concurrent refresh calls are deduplicated: `_pendingRefresh` stores the in-flight `Future<String?>` and is cleared in `whenComplete`.

### 5. Guider state machine

Guider state is purely in-memory in `BannerDetailPage._currentMissionIndex`.

```
Initial state: _currentMissionIndex = 0 (not started)

GuiderBar "Start" pressed:
  └─ _launchCurrentMission()
       ├─ launches mission[0].ingressUrl via url_launcher (external app)
       └─ _currentMissionIndex = 1

GuiderBar "Next" pressed (or mission launched):
  └─ _setGuiderIndex(index + 1)
       └─ BannerMap.didUpdateWidget() → _focusOnMissions([current-1, current])

GuiderBar "Mark as done" pressed (index == missions.length):
  └─ _setListType('done')
       └─ Navigator.pop(context, _listTypes)  # returns to list
```

---

## Theme System

`KBannerGuiderApp` manages theme in `_KBannerGuiderAppState`:

- Default: dark mode
- Persisted: `SharedPreferences` key `dark_mode` (bool)
- `_buildTheme(Brightness)` constructs Material 3 `ThemeData` with a custom grey-based `ColorScheme` (no strong accent colors — intentional Ingress-agnostic design)
- `onToggleTheme` callback passed into `BannerListPage` → forwarded to the app bar icon button

App bar background: `#212121` (dark) / `#424242` (light).  
Surface: `#1C1C1C` (dark) / `#F5F5F5` (light).

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `geolocator` | ^13.0.4 | GPS position + permission handling |
| `http` | ^1.4.0 | HTTP client for Bannergress API |
| `url_launcher` | ^6.3.2 | Open missions in Ingress / browser |
| `shared_preferences` | ^2.5.5 | Dark-mode preference persistence |
| `cached_network_image` | ^3.4.1 | Image caching for banner/mission thumbnails |
| `flutter_map` | ^8.3.0 | OpenStreetMap tile rendering |
| `latlong2` | ^0.9.1 | LatLng type used by flutter_map |
| `flutter_secure_storage` | ^9.2.4 | Secure token storage (Android Keystore) |
| `webview_flutter` | ^4.10.0 | In-app WebView for Keycloak login |
| `crypto` | ^3.0.0 | SHA-256 for PKCE code_challenge |

---

## Testing

Tests live in `test/`. Key files:

| File | Coverage |
|---|---|
| `banner_service_test.dart` | HTTP fetch logic, JSON parsing, error handling |
| `banner_service_auth_test.dart` | Authenticated fetch, 401 handling, token injection |
| `auth_service_test.dart` | Token expiry detection, refresh deduplication, logout |
| `banner_detail_page_test.dart` | Widget tests for BannerDetailPage (31 tests) |
| `banner_list_page_test.dart` | Widget tests for BannerListPage (27 tests) |
| `models_test.dart` | BannerItem / MissionItem JSON parsing |
| `format_test.dart` | formatMeters, factionColor, missionColor |
| `widgets_test.dart` | Individual widget smoke tests |

Services accept injectable `http.Client` and `TokenStorage` for easy unit testing without platform channels.

Current coverage: ~63 % (230 tests). Coverage report published to GitHub Pages via CI.

---

## CI / CD

`.github/workflows/build-and-deploy.yml` runs on every push:

1. `flutter analyze` — static analysis
2. `flutter test --coverage` — run tests and collect lcov
3. Build release APK
4. Deploy coverage report to GitHub Pages
