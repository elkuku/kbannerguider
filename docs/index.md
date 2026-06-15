# kBannerGuider — Documentation

kBannerGuider is an Android app for the [Ingress](https://ingress.com/) augmented reality game. It integrates with [Bannergress](https://bannergress.com/) to let you browse banners near your location, manage your to-do list, and navigate step-by-step through each mission.

## Contents

| Document | Description |
|---|---|
| [User Guide](user-guide.md) | How to use the app — screens, features, workflows |
| [Architecture](architecture.md) | Code structure, data flows, design decisions |
| [API Reference](api-reference.md) | Bannergress HTTP API used by the app |
| [Authentication](authentication.md) | Keycloak PKCE sign-in flow, token lifecycle |
| [Development](development.md) | Build, test, deploy |
| [Widget Reference](widget-reference.md) | Every widget and its parameters |
| [Data Models](data-models.md) | Dart model classes and JSON mapping |

## What it does

- **Nearby banners** — fetches banners sorted by proximity to your GPS position (or a custom search center)
- **To-do list** — shows your Bannergress bookmarked banners, sorted by distance
- **List type management** — mark banners as To-do / Done / Skip directly from the app; changes sync to Bannergress instantly
- **Mission detail** — shows all missions in a banner with waypoint steps, objectives, and lengths
- **Map view** — renders all mission routes on an OpenStreetMap map with colored numbered markers
- **Guider** — step-by-step mission navigator that opens each mission in the Ingress app and auto-advances the map
- **Bannergress sign-in** — optional Keycloak PKCE authentication via in-app WebView; tokens persisted securely across sessions
- **Theme** — dark / light mode toggle, preference persisted across restarts
