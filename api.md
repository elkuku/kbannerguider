# Bannergress API

Base URL: `https://api.bannergress.com`  
Spec: OpenAPI 3.1.0 — `GET /v3/api-docs`

---

## GET /bnrs — List banners

### Query parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `placeId` | string | — | Filter by place ID |
| `query` | string | — | Free-text search |
| `missionId` | string | — | Filter to banners containing this mission |
| `onlyOfficialMissions` | boolean | — | Restrict to Niantic-created missions |
| `author` | string | — | Filter by mission creator agent name |
| `online` | boolean | — | Online / offline status |
| `minLatitude` | number | — | Bounding box south edge |
| `maxLatitude` | number | — | Bounding box north edge |
| `minLongitude` | number | — | Bounding box west edge |
| `maxLongitude` | number | — | Bounding box east edge |
| `proximityLatitude` | number | — | Sort-by-proximity reference latitude |
| `proximityLongitude` | number | — | Sort-by-proximity reference longitude |
| `minEventTimestamp` | string (ISO 8601) | — | Event start lower bound |
| `maxEventTimestamp` | string (ISO 8601) | — | Event start upper bound |
| `orderBy` | enum | — | `created` `title` `numberOfMissions` `lengthMeters` `listAdded` `proximityStartPoint` `relevance` |
| `orderDirection` | enum | — | `ASC` `DESC` |
| `offset` | integer | 0 | Pagination offset |
| `limit` | integer | 20 | Results per page (max 100) |
| `attributes` | string[] | — | Optional extra fields to include in response |

### Response — array of `BannerDto`

---

## Schemas

### BannerDto

| Field | Type | Constraints | Description |
|---|---|---|---|
| `id` | string | — | Banner identifier |
| `uuid` | string (UUID) | — | UUID format identifier |
| `title` | string | min 1 | Banner name |
| `description` | string | — | Additional details |
| `width` | integer | 1–6 | Number of columns in mosaic |
| `picture` | string | — | Image reference (use `/bnrs/{id}/picture` for full URL) |
| `type` | enum | — | `sequential` \| `anyOrder` |
| `listType` | enum | — | `none` \| `todo` \| `done` \| `blacklist` |
| `numberOfMissions` | integer | 1–3000 | Total missions |
| `numberOfSubmittedMissions` | integer | 0–3000 | Submitted (pending) missions |
| `numberOfDisabledMissions` | integer | 0–3000 | Disabled missions |
| `missions` | object | — | Map of position → `MissionDto` |
| `startLatitude` | number | -90 to 90 | Start point latitude |
| `startLongitude` | number | -180 to 180 | Start point longitude |
| `startPlaceId` | string | — | Place identifier for start point |
| `formattedAddress` | string | — | Human-readable start location |
| `lengthMeters` | integer | ≥ 0 | Total route length in metres |
| `warning` | string | — | Alert / warning message |
| `plannedOfflineDate` | string (YYYY-MM-DD) | — | Planned offline date |
| `eventStartDate` | string (YYYY-MM-DD) | — | Event start date |
| `eventEndDate` | string (YYYY-MM-DD) | — | Event end date |

### MissionDto

| Field | Type | Description |
|---|---|---|
| `id` | string | Mission identifier |
| `title` | string | Mission name |
| `picture` | string | Image URL |
| `description` | string | Mission details |
| `type` | enum | `sequential` \| `anyOrder` \| `hidden` |
| `status` | enum | `submitted` \| `published` \| `disabled` |
| `latestUpdateStatus` | string (ISO 8601) | Last status change timestamp |
| `author` | NamedAgentDto | Creator |
| `averageDurationMilliseconds` | integer | Average completion time (ms) |
| `lengthMeters` | integer | Mission route length (m) |
| `steps` | MissionStepDto[] | Ordered waypoints |

### MissionStepDto

| Field | Type | Description |
|---|---|---|
| `poi` | PoiDto | Waypoint details |
| `objective` | enum | `hack` \| `captureOrUpgrade` \| `createLink` \| `createField` \| `installMod` \| `takePhoto` \| `viewWaypoint` \| `enterPassphrase` |

### PoiDto

| Field | Type | Description |
|---|---|---|
| `id` | string | Point identifier |
| `title` | string | Location name |
| `latitude` | number | Latitude (-90 to 90) |
| `longitude` | number | Longitude (-180 to 180) |
| `picture` | string | Image URL |
| `type` | enum | `portal` \| `fieldTripWaypoint` \| `unavailable` |

### NamedAgentDto

| Field | Type | Description |
|---|---|---|
| `name` | string | Agent username |
| `faction` | enum | `enlightened` \| `resistance` |

---

## Image URLs

| Resource | URL pattern |
|---|---|
| Banner picture | `https://api.bannergress.com/bnrs/{id}/picture` |
| Mission picture | `https://api.bannergress.com/missions/{id}/picture` |

## Banner web link

`https://bannergress.com/banner/{id}`
