# Data Models

All model classes live in `lib/models/`. They are immutable value objects with `fromJson` factory constructors. No `toJson` is needed — the app only reads from the API.

---

## BannerItem

**File:** `lib/models/banner_item.dart`

Represents a Bannergress mosaic banner.

```dart
class BannerItem {
  final String id;
  final String? uuid;
  final String title;
  final String? description;
  final int width;                        // mosaic column count (1–6)
  final int? numberOfMissions;
  final int? numberOfSubmittedMissions;
  final int? numberOfDisabledMissions;
  final double? startLatitude;
  final double? startLongitude;
  final String? formattedAddress;
  final int? lengthMeters;
  final String? picture;                  // relative or absolute path
  final String? type;                     // "sequential" | "anyOrder"
  final String? warning;
  final String? plannedOfflineDate;
  final String? eventStartDate;
  final String? eventEndDate;
  final String? listType;                 // "none" | "todo" | "done" | "blacklist"
  final List<MissionItem> missions;       // sorted by position key
}
```

### Computed properties

| Getter | Returns | Logic |
|---|---|---|
| `pictureUrl` | `String` | Resolves `picture` to an absolute URL; falls back to `/bnrs/{id}/picture` |
| `bannerUrl` | `String` | `https://bannergress.com/banner/{id}` |
| `author` | `String?` | `missions.first.author?.name` |
| `authorAgent` | `AgentItem?` | `missions.first.author` |

### Mission parsing

The API returns missions as a `Map<String, MissionDto>` keyed by position string. `BannerItem._parseMissions()` sorts the entries numerically and converts them to an ordered `List<MissionItem>`:

```dart
static List<MissionItem> _parseMissions(dynamic raw) {
  if (raw is! Map<String, dynamic>) return [];
  final entries = raw.entries.toList()
    ..sort((a, b) {
      final ia = int.tryParse(a.key) ?? 0;
      final ib = int.tryParse(b.key) ?? 0;
      return ia.compareTo(ib);
    });
  return entries.map((e) => MissionItem.fromJson(e.value)).toList();
}
```

---

## MissionItem

**File:** `lib/models/mission_item.dart`

Represents one mission within a banner.

```dart
class MissionItem {
  final String id;
  final String title;
  final String? picture;
  final String? description;
  final String? type;                     // "sequential" | "anyOrder" | "hidden"
  final String? status;                   // "submitted" | "published" | "disabled"
  final AgentItem? author;
  final int? lengthMeters;
  final int? averageDurationMilliseconds;
  final List<MissionStepItem> steps;
}
```

### Computed properties

| Getter | Returns | Description |
|---|---|---|
| `pictureUrl` | `String` | Resolves `picture`; falls back to `/missions/{id}/picture` |
| `ingressUrl` | `String` | Firebase dynamic link that opens the mission in the Ingress app |

### Ingress deep link format

```
https://link.ingress.com/
  ?link=<encoded https://intel.ingress.com/mission/{id}>
  &apn=com.nianticproject.ingress
  &isi=576505181
  &ibi=com.google.ingress
  &ifl=<encoded App Store URL>
  &ofl=<encoded intel URL>
```

---

## MissionStepItem

**File:** `lib/models/mission_item.dart`

One waypoint step within a mission.

```dart
class MissionStepItem {
  final PoiItem? poi;       // null for hidden steps
  final String objective;   // "hack" | "captureOrUpgrade" | ...
}
```

---

## PoiItem

**File:** `lib/models/mission_item.dart`

A Point of Interest (Ingress portal or field trip waypoint).

```dart
class PoiItem {
  final String id;
  final String title;
  final double? latitude;
  final double? longitude;
  final String? picture;
  final String type;        // "portal" | "fieldTripWaypoint" | "unavailable"
}
```

### Computed properties

| Getter | Returns | Description |
|---|---|---|
| `geoUrl` | `String?` | `geo:{lat},{lng}?q={lat},{lng}({title})` — null when coordinates are missing |

The geo URI is passed to `url_launcher` with `LaunchMode.externalApplication`. Android presents a chooser showing any app that handles `geo:` URIs (Google Maps, OsmAnd, etc.).

---

## AgentItem

**File:** `lib/models/mission_item.dart`

Ingress agent (mission author).

```dart
class AgentItem {
  final String name;       // agent username
  final String faction;    // "ENLIGHTENED" | "ENL" | "RESISTANCE" | "RES"
}
```

Faction color is resolved by `factionColor(faction)` in `lib/utils/format.dart`.

---

## JSON Mapping Examples

### Minimal BannerItem (unauthenticated nearby response)

```json
{
  "id": "my-banner-001",
  "title": "My Banner",
  "numberOfMissions": 6,
  "startLatitude": 50.1234,
  "startLongitude": 8.5678,
  "formattedAddress": "Frankfurt, Germany",
  "lengthMeters": 1500,
  "picture": "/bnrs/my-banner-001/picture",
  "width": 3
}
```

### Authenticated BannerItem (with listType and missions)

```json
{
  "id": "my-banner-001",
  "title": "My Banner",
  "listType": "todo",
  "warning": "Some missions may be disabled",
  "missions": {
    "1": {
      "id": "mission-abc",
      "title": "My Banner - Part 1",
      "type": "sequential",
      "status": "published",
      "author": { "name": "AgentName", "faction": "ENLIGHTENED" },
      "lengthMeters": 500,
      "steps": [
        {
          "objective": "hack",
          "poi": {
            "id": "portal-xyz",
            "title": "Interesting Portal",
            "latitude": 50.1111,
            "longitude": 8.6666,
            "type": "portal"
          }
        },
        {
          "objective": "enterPassphrase",
          "poi": null
        }
      ]
    },
    "2": { ... }
  }
}
```

### Null safety notes

- `id` and `title` default to `''` / `'Untitled'` if the server omits them
- All numeric coordinate fields use `(json['field'] as num?)?.toDouble()` to safely coerce `int` or `double` JSON values
- `missions` defaults to `[]` if the field is absent or not a `Map`
- `steps` defaults to `[]` if absent
