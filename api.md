# Bannergress API

Base URL: `https://api.bannergress.com`  
OpenAPI spec: `GET /v3/api-docs` (OpenAPI 3.1.0)

---

## Authentication

Keycloak PKCE flow via `https://login.bannergress.com`.

| Parameter | Value |
|---|---|
| Auth endpoint | `https://login.bannergress.com/auth/realms/bannergress/protocol/openid-connect/auth` |
| Token endpoint | `https://login.bannergress.com/auth/realms/bannergress/protocol/openid-connect/token` |
| `client_id` | `bannergress-website` |
| `redirect_uri` | `https://bannergress.com/` |
| `scope` | `openid profile email` |
| `code_challenge_method` | `S256` |

Token exchange uses `grant_type=authorization_code`; token refresh uses `grant_type=refresh_token`.  
Authenticated requests pass the access token as `Authorization: Bearer <token>`.

---

## Endpoints

### GET /bnrs — List banners

Returns an array of `BannerDto`. Supports proximity search, bounding box, full-text, list-type filtering, and pagination.

**Query parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `placeId` | string | — | Filter by place ID |
| `query` | string | — | Free-text search |
| `missionId` | string | — | Filter to banners containing this mission ID |
| `onlyOfficialMissions` | boolean | `false` | Restrict to Niantic-created missions |
| `author` | string | — | Filter by mission creator agent name |
| `online` | boolean | — | `true` = online only, `false` = offline only |
| `listTypes` | enum[] | — | `none` / `todo` / `done` / `blacklist` (requires auth) |
| `minLatitude` | number | — | Bounding box south edge |
| `maxLatitude` | number | — | Bounding box north edge |
| `minLongitude` | number | — | Bounding box west edge |
| `maxLongitude` | number | — | Bounding box east edge |
| `proximityLatitude` | number | — | Sort-by-proximity reference latitude |
| `proximityLongitude` | number | — | Sort-by-proximity reference longitude |
| `minEventTimestamp` | string (ISO 8601) | — | Events ending after this time |
| `maxEventTimestamp` | string (ISO 8601) | — | Events starting before this time |
| `orderBy` | enum | — | `created` `title` `numberOfMissions` `lengthMeters` `listAdded` `proximityStartPoint` `relevance` |
| `orderDirection` | enum | `ASC` | `ASC` or `DESC` |
| `offset` | integer | `0` | Pagination offset (min 0) |
| `limit` | integer | `20` | Results per page (max 100) |
| `attributes` | string[] | — | Opt-in fields to include (see below) |

**`attributes` values**

`description` `eventEndDate` `eventStartDate` `formattedAddress` `id` `lengthMeters` `listType` `missions` `numberOfDisabledMissions` `numberOfMissions` `numberOfSubmittedMissions` `owner` `picture` `plannedOfflineDate` `startLatitude` `startLongitude` `startPlaceId` `title` `type` `uuid` `warning` `width`

> The server omits missions from list responses by default. Request `missions` explicitly to get mission data (including `author`). `listType` is only populated when authenticated.

**Headers**

| Header | Description |
|---|---|
| `Accept-Language` | Language priority list for translated fields |
| `Authorization` | `Bearer <access_token>` (optional; unlocks `listType` and `listTypes` filter) |

**Response:** `200 OK` — `BannerDto[]`

---

### GET /bnrs/{id} — Get banner by ID

Returns a single `BannerDto` with full mission and step data.

**Path parameter:** `id` — banner identifier (URL-encoded)

**Response:** `200 OK` — `BannerDto` (missions always populated)

---

### POST /bnrs/{id}/settings — Set list type

Adds or updates the authenticated user's list membership for a banner.

**Path parameter:** `id` — banner identifier (URL-encoded)

**Headers:** `Authorization: Bearer <token>`, `Content-Type: application/json`

**Request body**

```json
{ "listType": "todo" }
```

`listType` values: `none` | `todo` | `done` | `blacklist`

**Responses**

| Status | Meaning |
|---|---|
| `200` | Updated |
| `204` | No content (also success) |
| `401` | Token invalid or expired |

---

## Schemas

### BannerDto

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | string | — | Banner identifier |
| `uuid` | string (UUID) | — | UUID format identifier |
| `title` | string | min 1 | Banner name |
| `description` | string | — | Additional details |
| `width` | integer | 1–6 | Mosaic column count |
| `picture` | string | — | Relative or absolute image URL (see Image URLs) |
| `type` | enum | — | `sequential` \| `anyOrder` |
| `listType` | enum | — | `none` \| `todo` \| `done` \| `blacklist` (auth only) |
| `numberOfMissions` | integer | 1–3000 | Total missions |
| `numberOfSubmittedMissions` | integer | 0–3000 | Submitted (pending) missions |
| `numberOfDisabledMissions` | integer | 0–3000 | Disabled missions |
| `missions` | object | — | Map of position string → `MissionDto` (opt-in via `attributes=missions`) |
| `startLatitude` | number | -90 to 90 | Start point latitude |
| `startLongitude` | number | -180 to 180 | Start point longitude |
| `startPlaceId` | string | — | Place ID for start point |
| `formattedAddress` | string | — | Human-readable start location |
| `lengthMeters` | integer | ≥ 0 | Total route length in metres |
| `warning` | string | — | Alert message |
| `plannedOfflineDate` | string (YYYY-MM-DD) | — | Planned offline date |
| `eventStartDate` | string (YYYY-MM-DD) | — | Event start date |
| `eventEndDate` | string (YYYY-MM-DD) | — | Event end date |

The `missions` map is keyed by position (e.g. `"1"`, `"2"`, …). Sort keys numerically to get ordered missions.

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
| `poi` | PoiDto | Waypoint location |
| `objective` | enum | `hack` \| `captureOrUpgrade` \| `createLink` \| `createField` \| `installMod` \| `takePhoto` \| `viewWaypoint` \| `enterPassphrase` |

### PoiDto

| Field | Type | Description |
|---|---|---|
| `id` | string | Point identifier |
| `title` | string | Location name |
| `latitude` | number (-90 to 90) | Latitude |
| `longitude` | number (-180 to 180) | Longitude |
| `picture` | string | Image URL |
| `type` | enum | `portal` \| `fieldTripWaypoint` \| `unavailable` |

### NamedAgentDto

| Field | Type | Description |
|---|---|---|
| `name` | string | Agent username |
| `faction` | enum | `enlightened` \| `resistance` |

---

## Image URLs

`picture` values may be relative or absolute. Resolve them as:

```
if starts with http:// or https://  →  use as-is
else                                 →  https://api.bannergress.com/<picture stripped of leading />
```

Fallback when `picture` is absent:

| Resource | Fallback URL |
|---|---|
| Banner | `https://api.bannergress.com/bnrs/{id}/picture` |
| Mission | `https://api.bannergress.com/missions/{id}/picture` |

## Banner web link

`https://bannergress.com/banner/{id}`
