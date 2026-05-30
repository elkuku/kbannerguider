# Google Sign-In & Drive Setup

## 1. Create a Google Cloud project

1. Go to https://console.cloud.google.com
2. Create a new project (or select an existing one)
3. Enable the **Google Drive API**:
   - APIs & Services → Library → search "Google Drive API" → Enable

## 2. Create OAuth 2.0 credentials

You need two OAuth clients: one Web client (used as `serverClientId`) and one Android client.

### Web client (required — used as `serverClientId`)

1. APIs & Services → Credentials → Create Credentials → OAuth client ID
2. Application type: **Web application**
3. Copy the generated **Client ID** — this goes into `lib/config.dart`

### Android client

1. Create Credentials → OAuth client ID
2. Application type: **Android**
3. Package name: `com.elkuku.kbannerguider`
4. SHA-1 certificate fingerprint — get it by running:
   ```
   keytool -list -v -keystore ~/.android/debug.keystore \
     -alias androiddebugkey -storepass android -keypass android
   ```
5. Save — no file download needed

## 3. Configure the app

Open `lib/config.dart` and replace the placeholder with your Web client ID:

```dart
const googleOAuthClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
```

## 4. Build

No `google-services.json` or Firebase setup required. The app authenticates
via the `serverClientId` directly.

```
flutter build apk
```

## What gets stored on Drive

The app stores a single JSON file (`kbannerguider_data.json`) in the **root of
the user's Google Drive** (visible). It uses the `drive.file` scope so it can
only access files it created itself. It contains the banner list-type map:

```json
{
  "listTypes": {
    "<banner-id>": "todo | done | blacklist"
  }
}
```
