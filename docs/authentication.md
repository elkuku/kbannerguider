# Authentication

Sign-in is **optional**. Browsing nearby banners works without an account. The following features require a valid Bannergress session:

- Viewing and changing a banner's list type (To-do / Done / Skip)
- The To-do tab
- Filter bar and list-type badges on the Nearby tab
- Author names in banner cards

---

## Protocol: Keycloak PKCE

Bannergress uses a Keycloak server at `login.bannergress.com`. The app implements the standard OAuth 2.0 Authorization Code flow with PKCE (RFC 7636), which avoids transmitting a client secret from a mobile app.

| Parameter | Value |
|---|---|
| Authorization endpoint | `https://login.bannergress.com/auth/realms/bannergress/protocol/openid-connect/auth` |
| Token endpoint | `https://login.bannergress.com/auth/realms/bannergress/protocol/openid-connect/token` |
| `client_id` | `bannergress-website` |
| `redirect_uri` | `https://bannergress.com/` |
| `scope` | `openid profile email` |
| `code_challenge_method` | `S256` |

---

## Login Flow

```
AuthService.login(context)
  │
  ├─ 1. Generate PKCE pair
  │       code_verifier  = random 32 bytes, base64url-encoded
  │       code_challenge = SHA-256(code_verifier), base64url-encoded
  │
  ├─ 2. Build authorization URL
  │       GET /auth?client_id=...&response_type=code&scope=...
  │             &state=<random>&code_challenge=...&code_challenge_method=S256
  │
  ├─ 3. Show _LoginWebViewDialog (full-screen in-app WebView)
  │       NavigationDelegate intercepts redirects to https://bannergress.com/
  │       Extracts 'code' query parameter, closes dialog, returns code
  │
  ├─ 4. Token exchange
  │       POST /token
  │         grant_type=authorization_code
  │         code=<received code>
  │         code_verifier=<plain verifier>
  │         client_id=bannergress-website
  │         redirect_uri=https://bannergress.com/
  │
  └─ 5. Persist tokens
          flutter_secure_storage keys:
            bg_access_token  = JWT access token
            bg_refresh_token = refresh token
```

---

## Session Restore

On every app launch, `BannerListPage._checkAuth()` runs in `initState`:

1. `auth.isLoggedIn()` — returns `true` if `bg_refresh_token` exists in secure storage
2. `_getToken()` — calls `AuthService.getAccessToken()`, which reads `bg_access_token`
3. If token is valid → set `_isSignedIn = true`, fire `_syncListStates` (fire-and-forget)
4. If token is missing or refresh fails → set `_isSignedIn = false`

There is no proactive token refresh on startup. The stored access token is used as-is until an API call returns `401`.

---

## Token Expiry and Refresh

`AuthService.getAccessToken()` inspects the JWT `exp` claim before returning:

```dart
bool _isTokenExpiredOrSoon(String token) {
  // decodes JWT payload, checks exp claim
  // returns true if token expires within 60 seconds
}
```

If the token is expiring soon, `refreshIfNeeded()` is called:

```
POST /token
  grant_type=refresh_token
  refresh_token=<stored>
  client_id=bannergress-website
```

- **Success** → saves new access + refresh tokens, returns new access token
- **Failure** → calls `logout()` (deletes all tokens), returns `null`

Concurrent refresh calls race to the same `_pendingRefresh` Future — only one HTTP request is made.

Reactive refresh also happens on `SessionExpiredException` (HTTP 401): `_fetchTodosFromApi()` catches `SessionExpiredException`, calls `auth.refreshIfNeeded()`, and retries once.

---

## Sign-out

```
AuthService.logout()
  └─ FlutterSecureStorage.deleteAll()
       clears both bg_access_token and bg_refresh_token

BannerListPage._signOut()
  ├─ auth.logout()
  └─ setState:
       _isSignedIn = false
       _todoBanners = []
       _listTypes   = {}
       _hiddenFilters = {}
  └─ _fetchBanners()   (re-fetches without auth header)
```

---

## Token Storage

Both tokens are stored using `flutter_secure_storage`, which uses the Android Keystore on Android. They survive app restarts and device reboots, but are cleared on app uninstall.

| Key | Contents |
|---|---|
| `bg_access_token` | Keycloak JWT access token (short-lived, ~5 min) |
| `bg_refresh_token` | Keycloak refresh token (long-lived, days to weeks) |

---

## Token Flow Diagram

```
App Launch
    │
    ▼
isLoggedIn()  ──no──►  show sign-in UI
    │
   yes
    │
    ▼
getAccessToken()
    ├─ not expired  ──────────────────────────────────►  use token
    └─ expiring soon
            │
            ▼
        refreshIfNeeded()
            ├─ success  ──────────────────────────────►  use new token
            └─ failure  ──►  logout()  ──►  show sign-in UI

                    (during API call)
                    HTTP 401
                        │
                        ▼
                    refreshIfNeeded()
                        ├─ success  ──►  retry request
                        └─ failure  ──►  logout()  ──►  show sign-in UI
```

---

## WebView Details

The login dialog uses `webview_flutter` with:

- **JavaScript enabled** — required for the Keycloak login page
- **Custom User-Agent** — `Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36 … Mobile Safari/537.36` — ensures Keycloak renders the mobile-optimized login form
- **Navigation interception** — `NavigationDelegate.onNavigationRequest` watches for URLs starting with `https://bannergress.com/` and extracts the `code` parameter without actually loading the Bannergress website
