# Widget Reference

All widgets live in `lib/widgets/`. They are stateless or minimally stateful, receive data as constructor parameters, and communicate upward via callbacks.

---

## BannerTile

**File:** `lib/widgets/banner_tile.dart`  
**Type:** StatelessWidget  
**Used by:** `BannerListPage` (Nearby list, To-do list)

Renders a single banner as a `ListTile`. Tapping navigates to `BannerDetailPage` and calls `onListTypesUpdated` with the returned map on pop.

### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `banner` | `BannerItem` | ✓ | Banner data to display |
| `bannerService` | `BannerService` | ✓ | Passed through to `BannerDetailPage` |
| `listTypes` | `Map<String, String>` | ✓ | Full list-type map (passed to detail page) |
| `listType` | `String?` | | Pre-computed badge value for this banner; `null` = no badge |
| `distance` | `String?` | | Pre-formatted distance string (e.g. "147 m") |
| `isSignedIn` | `bool` | | Whether to show author and enable list type features |
| `getToken` | `Future<String?> Function()?` | | Token getter passed to detail page |
| `onListTypesUpdated` | `void Function(Map<String, String>)?` | | Called when detail page returns updated map |

### Visual structure

```
[thumbnail] Title                           [passphrase?] [badge?] [>]
            N missions · distance
            📍 address
            👤 author (faction color)
            ⚠️ warning
```

List type badges: bookmark (To-do, blue), ✓ (Done, green), ⊘ (Skip, red).

---

## BannerMap

**File:** `lib/widgets/banner_map.dart`  
**Type:** StatefulWidget  
**Used by:** `BannerDetailPage` (Map tab)

Full-screen flutter_map widget showing all mission routes, a guider bar, and a location toggle.

### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `missions` | `List<MissionItem>` | ✓ | Missions to render |
| `loading` | `bool` | ✓ | Shows spinner when true and missions are empty |
| `bannerStartLat` | `double?` | | Banner start point latitude |
| `bannerStartLng` | `double?` | | Banner start point longitude |
| `bannerTitle` | `String?` | | Banner title (used in start sheet) |
| `bannerAddress` | `String?` | | Banner address (used in start sheet) |
| `currentMissionIndex` | `int?` | | Guider state (0 = not started) |
| `onMissionIndexChanged` | `void Function(int)?` | | Callback when guider index changes |
| `onLaunchMission` | `Future<void> Function()?` | | Callback when "Start/Next" is tapped |
| `onMarkDone` | `Future<void> Function()?` | | Callback when "Mark as done" is tapped |

### Map markers

| Marker | Description |
|---|---|
| Numbered circle (large) | First waypoint of each mission; color from `missionColor(i)` |
| Small dot | Subsequent waypoints within a mission |
| 🏁 red-bordered circle | Banner official start point |
| Blue pulsing dot | User's live location (when enabled) |

### Guider behavior

When `currentMissionIndex > 0`, the map enters guider mode:
- Only the current and previous mission are rendered (others hidden)
- `didUpdateWidget` triggers `_focusOnMissions([ci-1, ci])` to auto-zoom
- The mission legend is hidden
- The flag marker is hidden

### Location updates

When the location button is active, `Geolocator.getCurrentPosition()` is called immediately and then on a 10-second `Timer.periodic`. The camera follows the dot unless `_userInteracting` is true (set by map pan/zoom, cleared after 3 seconds of inactivity).

---

## FilterBar

**File:** `lib/widgets/filter_bar.dart`  
**Type:** StatelessWidget  
**Used by:** `BannerListPage` (Nearby tab, signed in only)

Horizontal scrollable row of `FilterChip` widgets for hiding/showing banner categories.

### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `hiddenFilters` | `Set<String>` | ✓ | Currently hidden category keys |
| `listTypes` | `Map<String, String>` | ✓ | Full banner ID → list type map |
| `banners` | `List<BannerItem>` | ✓ | Current banner list (for counting) |
| `onChanged` | `ValueChanged<Set<String>>` | ✓ | Called with updated hidden set on chip tap |

### Filter keys

| Key | Label | Color |
|---|---|---|
| `todo` | To-do | Blue |
| `done` | Done | Green |
| `blacklist` | Skip | Red |
| `unsorted` | Unsorted | Grey |

Banners with no list type or `listType == 'none'` are counted as `unsorted`.

---

## GuiderBar

**File:** `lib/widgets/guider_bar.dart`  
**Type:** StatefulWidget  
**Used by:** `BannerMap`

Floating navigation bar overlaid on the map at the bottom. Manages its own loading state to prevent double-taps during the async `onLaunch` call.

### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `currentIndex` | `int` | ✓ | Current guider position (0 = not started) |
| `total` | `int` | ✓ | Total number of missions |
| `onDecrement` | `VoidCallback?` | ✓ | Tap handler for `–` button; `null` = disabled |
| `onIncrement` | `VoidCallback?` | ✓ | Tap handler for `+` button; `null` = disabled |
| `onLaunch` | `Future<void> Function()?` | ✓ | Tap handler for main action button |
| `onMarkDone` | `Future<void> Function()?` | | Tap handler when all missions complete |

### Button states

| Condition | Button label | Button color |
|---|---|---|
| `currentIndex == 0` | Start | Green |
| `0 < currentIndex < total` | Next | Primary |
| `currentIndex >= total` | Mark as done | Green |

---

## ListTypeSelector

**File:** `lib/widgets/list_type_selector.dart`  
**Type:** StatelessWidget  
**Used by:** `BannerDetailPage` (Missions tab)

Four-button animated selector for setting a banner's list type.

### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `current` | `String` | ✓ | Active value: `'none'` \| `'todo'` \| `'done'` \| `'blacklist'` |
| `onChanged` | `ValueChanged<String>` | ✓ | Called with new value on tap |

The selected button gets a colored border and background tint. Unselected buttons are grey. The transition is animated over 150 ms.

---

## LocationBar

**File:** `lib/widgets/location_bar.dart`  
**Type:** StatelessWidget  
**Used by:** `BannerListPage`

Thin bar showing the current search center coordinates. Tapping opens the location picker.

### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `position` | `Position?` | ✓ | GPS position (null = locating) |
| `customCenter` | `LatLng?` | ✓ | Manually chosen center (null = using GPS) |
| `onPickLocation` | `VoidCallback` | ✓ | Opens LocationPickerPage |
| `onClearCustom` | `VoidCallback` | ✓ | Clears custom center, reverts to GPS |

When `customCenter != null`, the icon turns orange and a GPS icon appears on the right to clear back to device location.

---

## MissionTile

**File:** `lib/widgets/mission_tile.dart`  
**Type:** StatelessWidget  
**Used by:** `BannerDetailPage` (Missions tab)

`ExpansionTile` for one mission. Contains `_StepTile` children for each waypoint and an "Open in Ingress" icon button.

### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `index` | `int` | ✓ | Zero-based mission position |
| `mission` | `MissionItem` | ✓ | Mission data |
| `color` | `Color` | ✓ | Mission color from `missionColor(index)` |

### _StepTile

Each waypoint step is rendered as a `Row` with:
- Step number in mission color
- Objective icon (colored per objective type)
- POI title (or `(hidden waypoint)` for null POIs)
- Objective type label
- Share location button (if POI has coordinates)

### InfoRow

A reusable row widget used in `BannerDetailPage` for key-value info:
```
[icon]  Label: value
```

---

## BannergressSignInBanner

**File:** `lib/widgets/sign_in_banner.dart`  
**Type:** StatelessWidget  
**Used by:** `BannerListPage` (Nearby tab, signed out)

Card prompting sign-in. Turns red and shows the error message when `authError` is non-null.

### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `authError` | `String?` | ✓ | Error message, or null for normal state |
| `onSignIn` | `VoidCallback` | ✓ | Triggers the sign-in flow |

---

## FullImageDialog

**File:** `lib/widgets/full_image_dialog.dart`  
**Type:** Function (`showFullImage`)

Not a widget class — a top-level function that shows a full-screen `Dialog` with a zoomable `CachedNetworkImage`.

```dart
void showFullImage(BuildContext context, String imageUrl)
```

- `InteractiveViewer` allows pinch-to-zoom (0.5× to 5×)
- Tap anywhere (or the close button) to dismiss
- Background: `Colors.black.withOpacity(0.9)`

---

## Utility Functions (`lib/utils/format.dart`)

| Function | Signature | Description |
|---|---|---|
| `formatMeters` | `String formatMeters(int meters)` | `"147 m"` or `"1.5 km"` |
| `factionColor` | `Color factionColor(String? faction)` | Green for Enlightened, Blue for Resistance, Grey otherwise |
| `missionColor` | `Color missionColor(int i)` | Cycles through 10 distinct colors |
| `launch` | `Future<void> launch(String url)` | Opens URL in external app via `url_launcher` |

### Mission colors

```
0 → Blue   #2196F3
1 → Red    #F44336
2 → Green  #4CAF50
3 → Orange #FF9800
4 → Purple #9C27B0
5 → Cyan   #00BCD4
6 → Pink   #E91E63
7 → Teal   #009688
8 → Yellow #FFEB3B
9 → Indigo #3F51B5
(repeats from 10+)
```
