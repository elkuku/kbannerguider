# Bannergress API Reference

Base URL: `https://api.bannergress.com`  
OpenAPI spec: `GET /v3/api-docs` (OpenAPI 3.1.0)

Authenticated requests pass the Keycloak access token as:
```
Authorization: Bearer <access_token>
```

---

## Endpoints used by kBannerGuider

### GET /bnrs — List banners

Used for:
- **Nearby banners** (unauthenticated or authenticated)
- **To-do / Done / Skip lists** (authenticated, `listTypes` parameter)

#### Nearby banners request

```
GET /bnrs
  ?orderBy=proximityStartPoint
  &orderDirection=ASC
  &online=true
  &proximityLatitude={lat}
  &proximityLongitude={lng}
  &offset={offset}
  &limit=25
  &attributes=id&attributes=title&attributes=numberOfMissions
  &attributes=numberOfSubmittedMissions&attributes=numberOfDisabledMissions
  &attributes=lengthMeters&attributes=startLatitude&attributes=startLongitude
  &attributes=picture&attributes=width&attributes=startPlaceId
  &attributes=formattedAddress&attributes=listType&attributes=missions
  &attributes=warning
```

The `attributes` parameters are only added when the user is authenticated; they request mission author data (`missions`) and warning text on top of the server defaults.

#### List-type banners request

```
GET /bnrs
  ?listTypes={todo|done|blacklist}
  &orderBy=listAdded
  &orderDirection=DESC
  &offset=0
  &limit=100
  &attributes=...  (same set as above)
```

#### Response

`200 OK` — JSON array of `BannerDto` objects:

```json
[
  {
    "id": "free42-tour-frankfurt-part-one",
    "uuid": "...",
    "title": "free42",
    "description": "Free42 Tour durch Frankfurt- Part One",
    "width": 3,
    "numberOfMissions": 6,
    "numberOfSubmittedMissions": 0,
    "numberOfDisabledMissions": 0,
    "startLatitude": 50.11234,
    "startLongitude": 8.67890,
    "formattedAddress": "Frankfurt, Germany",
    "lengthMeters": 1500,
    "picture": "/bnrs/free42.../picture",
    "type": "sequential",
    "listType": "done",
    "warning": null,
    "missions": {
      "1": { /* MissionDto */ },
      "2": { /* MissionDto */ }
    }
  }
]
```

---

### GET /bnrs/{id} — Get banner by ID

Returns a single banner with all mission and step data populated.

```
GET /bnrs/{id}
Authorization: Bearer <token>   (optional)
```

**Response:** `200 OK` — single `BannerDto` with `missions` always populated.

Called by `BannerService.fetchById()` when the detail page opens to load full step-level data.

---

### POST /bnrs/{id}/settings — Set list type

Saves the authenticated user's list membership for a banner.

```
POST /bnrs/{id}/settings
Authorization: Bearer <token>
Content-Type: application/json

{"listType": "todo"}
```

`listType` values: `none` | `todo` | `done` | `blacklist`

**Responses:**

| Status | Meaning |
|---|---|
| `200` | Updated |
| `204` | No content (also success) |
| `401` | Token invalid or expired → `SessionExpiredException` |

---

## Schemas

### BannerDto

| Field | Type | Notes |
|---|---|---|
| `id` | string | Banner identifier (used in URLs) |
| `uuid` | string (UUID) | Alternate identifier |
| `title` | string | Display name |
| `description` | string? | Optional description |
| `width` | integer (1–6) | Mosaic column count |
| `picture` | string? | Relative or absolute image path — see [Image URLs](#image-urls) |
| `type` | `"sequential"` \| `"anyOrder"` | Whether missions must be completed in order |
| `listType` | `"none"` \| `"todo"` \| `"done"` \| `"blacklist"` | Auth-only field |
| `numberOfMissions` | integer | Total missions |
| `numberOfSubmittedMissions` | integer | Pending missions |
| `numberOfDisabledMissions` | integer | Disabled missions |
| `missions` | `Map<String, MissionDto>` | Keyed by position string ("1", "2", …) |
| `startLatitude` | number | Start point latitude |
| `startLongitude` | number | Start point longitude |
| `formattedAddress` | string? | Human-readable start location |
| `lengthMeters` | integer | Total route length |
| `warning` | string? | Alert message from Bannergress |
| `plannedOfflineDate` | string (YYYY-MM-DD)? | Scheduled offline date |
| `eventStartDate` | string (YYYY-MM-DD)? | Event start |
| `eventEndDate` | string (YYYY-MM-DD)? | Event end |

The `missions` map is sorted numerically by key to produce the ordered mission list.

### MissionDto

| Field | Type | Notes |
|---|---|---|
| `id` | string | Mission identifier |
| `title` | string | Mission name |
| `picture` | string? | Image path |
| `description` | string? | Mission details |
| `type` | `"sequential"` \| `"anyOrder"` \| `"hidden"` | Step order requirement |
| `status` | `"submitted"` \| `"published"` \| `"disabled"` | Moderation status |
| `author` | `NamedAgentDto?` | Mission creator |
| `averageDurationMilliseconds` | integer? | Average completion time |
| `lengthMeters` | integer? | Mission route length |
| `steps` | `MissionStepDto[]` | Ordered waypoints |

### MissionStepDto

| Field | Type | Notes |
|---|---|---|
| `poi` | `PoiDto?` | Waypoint — null for hidden steps |
| `objective` | string | See objective types below |

**Objective types:**

| Value | Display | Icon |
|---|---|---|
| `hack` | Hack | 📡 |
| `captureOrUpgrade` | Capture/Upgrade | 🏳 |
| `createLink` | Create Link | 🔗 |
| `createField` | Create Field | △ |
| `installMod` | Install Mod | 🔧 |
| `takePhoto` | Take Photo | 📷 |
| `viewWaypoint` | View Waypoint | 👁 |
| `enterPassphrase` | Enter Passphrase | 🔑 |

### PoiDto

| Field | Type | Notes |
|---|---|---|
| `id` | string | Point identifier |
| `title` | string | Location name |
| `latitude` | number? | Latitude |
| `longitude` | number? | Longitude |
| `picture` | string? | Image URL |
| `type` | `"portal"` \| `"fieldTripWaypoint"` \| `"unavailable"` | POI type |

### NamedAgentDto

| Field | Type | Notes |
|---|---|---|
| `name` | string | Ingress agent username |
| `faction` | `"ENLIGHTENED"` \| `"ENL"` \| `"RESISTANCE"` \| `"RES"` | Faction |

---

## Image URLs

`picture` fields may be relative paths or absolute URLs. The app resolves them as:

```
if picture starts with "http://" or "https://"  →  use as-is
else                                              →  "https://api.bannergress.com/" + picture.trimLeadingSlashes()
```

Fallback when `picture` is absent or empty:

| Resource | Fallback |
|---|---|
| Banner | `https://api.bannergress.com/bnrs/{id}/picture` |
| Mission | `https://api.bannergress.com/missions/{id}/picture` |

This logic is implemented in `BannerItem.pictureUrl` and `MissionItem.pictureUrl`.

---

## Deep Links

### Banner web link
```
https://bannergress.com/banner/{id}
```
Used by "View on Bannergress" in the detail page.

### Mission Ingress deep link
```
https://link.ingress.com/
  ?link=<encoded intel URL>
  &apn=com.nianticproject.ingress
  &isi=576505181
  &ibi=com.google.ingress
  &ifl=<encoded App Store URL>
  &ofl=<encoded intel URL>
```
Opens the mission in the Ingress app. If Ingress is not installed, falls back to the Intel map in the browser.

### Waypoint geo URI
```
geo:{lat},{lng}?q={lat},{lng}({encoded_title})
```
Passed to `url_launcher` with `LaunchMode.externalApplication`; Android presents a chooser (Google Maps, OsmAnd, etc.).

---

## Pagination

The nearby endpoint uses offset-based pagination:

| Parameter | Value |
|---|---|
| `limit` | 25 (page size, constant `BannerService.pageSize`) |
| `offset` | 0, 25, 50, … |

The app knows there are more results when `response.length >= pageSize`. When the scroll controller is within 300 px of the end, it loads the next page and appends to the list.

List-type fetches use `limit=100` with no pagination (assumed to fit in a single response).
