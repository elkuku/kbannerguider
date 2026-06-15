> [!CAUTION]
> <img src="ai-generated.svg" height="48" align="absmiddle"> &nbsp; **AI Generated Code!**

# kBannerGuider

An Android app for [Ingress](https://ingress.com/) players. It connects to [Bannergress](https://bannergress.com/) to show mosaic banners near your location, lets you manage your To-do / Done / Skip lists, and guides you step-by-step through each mission with an integrated map.

## Features

- Browse banners sorted by proximity to your GPS position or a custom search center
- Sign in to Bannergress to sync your To-do list and manage list types
- Filter the nearby list by list type (To-do / Done / Skip / Unsorted)
- View mission details, waypoint steps, and route lengths
- Interactive map with colored mission routes and numbered markers
- Step-by-step guider that opens each mission in the Ingress app
- Dark / light theme toggle

## Documentation

Full documentation is in the [`docs/`](docs/) folder:

| Document | Description |
|---|---|
| [User Guide](docs/user-guide.md) | Screens, features, and workflows with screenshots |
| [Architecture](docs/architecture.md) | Code structure, data flows, design decisions |
| [API Reference](docs/api-reference.md) | Bannergress HTTP API |
| [Authentication](docs/authentication.md) | Keycloak PKCE sign-in flow |
| [Development](docs/development.md) | Build, test, deploy |
| [Widget Reference](docs/widget-reference.md) | Every widget and its parameters |
| [Data Models](docs/data-models.md) | Dart model classes and JSON mapping |

## Download

Download and stats: **[elkuku.github.io/kbannerguider](https://elkuku.github.io/kbannerguider/)**

## Build

```bash
./build.sh
```

Builds a release APK stamped with the current datetime and installs it on the connected device. See the [Development Guide](docs/development.md) for details.
