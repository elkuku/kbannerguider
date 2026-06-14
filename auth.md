# Bannergress Authentication

## Overview

Sign-in is **optional**. Browsing nearby banners works without it. The following features require a valid session:

- Viewing and changing a banner's list type (To-do / Done / Skip)
- The To-do tab
- Filter bar and list-type badges on the Nearby tab
- Author names in banner cards

---

## Protocol: Keycloak PKCE (Authorization Code + PKCE)

Bannergress uses a Keycloak server at `login.bannergress.com`. The app implements the standard PKCE flow (RFC 7636), which avoids sending a client secret from a mobile app.

**Endpoints:**

| Purpose | URL |
|---|---|
| Authorization | `https://login.bannergress.com/auth/realms/bannergress/protocol/openid-connect/auth` |
| Token exchange / refresh | `https://login.bannergress.com/auth/realms/bannergress/protocol/openid-connect/token` |

**Parameters:**

| Key | Value |
|---|---|
| `client_id` | `bannergress-website` |
| `redirect_uri` | `https://bannergress.com/` |
| `scope` | `openid profile email` |
| `code_challenge_method` | `S256` |

---

## Login flow (step by step)

1. **Generate PKCE pair** — a random 32-byte `code_verifier` and its SHA-256/base64url hash as `code_challenge`.
2. **Open WebView dialog** — `_LoginWebViewDialog` loads the authorization URL in a full-screen in-app WebView with a custom Android UA string so Keycloak renders the mobile login page correctly.
3. **Intercept redirect** — the `NavigationDelegate` watches every navigation request. When the URL starts with `https://bannergress.com/`, it extracts the `code` query parameter and closes the dialog, returning the code to the caller. The navigation itself is blocked (`NavigationDecision.prevent`) so the WebView never actually loads the Bannergress website.
4. **Token exchange** — `AuthService.login()` POSTs to the token endpoint with `grant_type=authorization_code`, the `code`, and the plain `code_verifier`. The server validates the verifier against the earlier challenge and returns `access_token` + `refresh_token`.
5. **Persist tokens** — both tokens are written to `flutter_secure_storage` under the keys `bg_access_token` and `bg_refresh_token`. They survive app restarts.

---

## Session restore on startup

`BannerListPage._checkAuth()` runs in `initState`:

1. Calls `AuthService.isLoggedIn()` — checks whether `bg_access_token` is non-null in secure storage.
2. If true, sets `_isSignedIn = true` in UI state, then fires `_syncListStates` (fire-and-forget via `unawaited`).

There is **no automatic token refresh on startup** — the stored access token is used as-is. Refresh only happens on a 401 response.

---

## Token refresh

`AuthService.refreshIfNeeded()` is called reactively when an API call returns `401 Unauthorized` (`SessionExpiredException`). It:

1. Reads `bg_refresh_token` from secure storage.
2. POSTs to the token endpoint with `grant_type=refresh_token`.
3. On success: saves the new access + refresh tokens and returns the new access token.
4. On failure (network error or server error): calls `logout()` (deletes all stored tokens) and returns `null`, which causes the UI to set `_isSignedIn = false`.

---

## Sign-out

`AuthService.logout()` calls `FlutterSecureStorage.deleteAll()`, clearing both tokens. `BannerListPage._signOut()` then clears `_listTypes`, `_todoBanners`, and `_hiddenFilters` from in-memory state and re-fetches the nearby list without authentication.

---

## How the token reaches API calls

`BannerListPage._getToken()` is a thin wrapper around `AuthService.getAccessToken()` that reads directly from secure storage each time. It is passed as a callback (`getToken`) into `BannerDetailPage`, and called inline before authenticated requests in `BannerListPage` (nearby fetch, list-type sync, To-do tab fetch).

The token is sent as an HTTP `Authorization: Bearer <token>` header. When the token is absent (user not signed in), the header is omitted and the request is made anonymously.

---

## List-type sync after sign-in

`_syncListStates(token)` fires after every successful sign-in or session restore. It calls `BannerService.fetchByListType` in parallel for all three list types (`todo`, `done`, `blacklist`) and merges the results into the in-memory `_listTypes` map (`Map<bannerId, listType>`). This map is the sole local source of truth for list-type state and is never persisted — Bannergress is authoritative.

---

## Token storage keys

| Key | Value |
|---|---|
| `bg_access_token` | Keycloak JWT access token |
| `bg_refresh_token` | Keycloak refresh token |

Both are stored via `flutter_secure_storage`, which uses Android Keystore on Android.
