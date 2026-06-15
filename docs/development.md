# Development Guide

## Prerequisites

- Flutter SDK (see `pubspec.yaml` → `environment.sdk` for the required version)
- Android SDK with a connected device or emulator
- Target device for deployment: Pixel 6a, serial `23191JEGR03752`

## Build and Install

The `build.sh` script is the standard build command. Run it after every code change:

```bash
./build.sh
```

It:
1. Stamps the build with the current datetime as `YYYYMMDD-HHmm`
2. Injects the version string via `--dart-define=APP_VERSION=<version>`
3. Builds a release APK (`flutter build apk`)
4. Copies it to `build/app/outputs/flutter-apk/kbannerguider-<version>.apk`
5. Installs on the target device (`flutter install -d 23191JEGR03752`)

The version string is read at runtime via:

```dart
// lib/version.dart
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
```

It appears in the app bar subtitle. Debug runs (e.g. `flutter run`) show `dev`.

## Analysis and Tests

```bash
flutter analyze          # static analysis (no errors expected)
flutter test             # run all tests
flutter test --coverage  # run tests with lcov coverage output
```

Coverage report is generated at `coverage/lcov.info`. The CI pipeline publishes an HTML report to GitHub Pages.

## Running on the Emulator

Two emulators are available:

| ID | Name |
|---|---|
| `Medium_Phone_API_35` | Medium Phone API 35 |
| `Pixel_6a_API_35` | Pixel 6a API 35 |

```bash
flutter emulators --launch Pixel_6a_API_35
flutter run -d emulator-5554
```

## Project Structure Notes

### Version injection

```bash
flutter build apk --dart-define=APP_VERSION="20260615-1200"
```

The `APP_VERSION` Dart define is the only build-time configuration.

### Android signing

Signing configuration is in `android/key.properties` (not committed). The keystore is `android/app/kbannerguider.jks`.

### Gradle warnings

The build may warn about plugins that use the Kotlin Gradle Plugin directly (`shared_preferences_android`, `url_launcher_android`). These are upstream issues in the plugin packages and do not affect the build.

## CI / CD

`.github/workflows/build-and-deploy.yml`:

```yaml
on: [push]

jobs:
  build:
    steps:
      - flutter analyze
      - flutter test --coverage
      - flutter build apk --release
      - deploy coverage to GitHub Pages
```

Node.js 24 compatible action versions are used (`actions/checkout@v4`, `subosito/flutter-action@v2`, etc.).

## Adding a Dependency

```bash
flutter pub add <package>
flutter pub get
```

Then run `./build.sh` to verify the build still passes.

## Testing Strategy

### Unit tests

Services (`BannerService`, `AuthService`) accept injected HTTP clients and token storage via constructor parameters:

```dart
BannerService(http.Client? client)
AuthService(TokenStorage? storage, http.Client? httpClient)
```

Tests inject `MockClient` (from `package:http/testing.dart`) and a simple `Map`-backed `TokenStorage` implementation.

### Widget tests

`BannerListPage` and `BannerDetailPage` are tested using `flutter_test`. A `MockBannerService` and `MockAuthService` (implemented by returning pre-loaded fixture data) are injected. Fixtures live in `test/fixtures/`:

| File | Used by |
|---|---|
| `banner_list.json` | Nearby banner list tests |
| `banner_detail.json` | Detail page tests |
| `banner_nearby_auth.json` | Authenticated nearby tests |
| `banner_todo.json` | To-do list tests |

### Running a single test file

```bash
flutter test test/banner_service_test.dart
flutter test test/banner_detail_page_test.dart -v
```
