import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

const _keycloakBase =
    'https://login.bannergress.com/auth/realms/bannergress/protocol/openid-connect';
const _clientId = 'bannergress-website';
const _redirectUri = 'https://bannergress.com/';

const _keyAccessToken = 'bg_access_token';
const _keyRefreshToken = 'bg_refresh_token';

class AuthService {
  final _storage = const FlutterSecureStorage();

  // Deduplicates concurrent refresh attempts that race at startup.
  Future<String?>? _pendingRefresh;

  /// Returns a valid access token, refreshing silently if the stored one is
  /// expired or close to expiry. Returns null when not logged in or refresh fails.
  Future<String?> getAccessToken() async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null || token.isEmpty) return null;
    if (!_isTokenExpiredOrSoon(token)) return token;

    _pendingRefresh ??= refreshIfNeeded()
        .whenComplete(() => _pendingRefresh = null);
    return _pendingRefresh;
  }

  Future<bool> isLoggedIn() async {
    final refresh = await _storage.read(key: _keyRefreshToken);
    return refresh != null && refresh.isNotEmpty;
  }

  /// Decodes the JWT exp claim and returns true when the token expires within
  /// 60 seconds (giving the refresh call time to complete before APIs reject it).
  bool _isTokenExpiredOrSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      var payload = parts[1];
      final padding = (4 - payload.length % 4) % 4;
      payload += '=' * padding;
      final decoded =
          jsonDecode(utf8.decode(base64Url.decode(payload))) as Map;
      final exp = decoded['exp'] as int?;
      if (exp == null) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry.subtract(const Duration(seconds: 60)));
    } catch (_) {
      return true;
    }
  }

  Future<void> login(BuildContext context) async {
    final codeVerifier = _randomBase64(32);
    final codeChallenge = _sha256Base64(codeVerifier);
    final state = _randomBase64(16);

    final authUrl = Uri.parse('$_keycloakBase/auth').replace(queryParameters: {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope': 'openid profile email',
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });

    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LoginWebViewDialog(
        url: authUrl.toString(),
        redirectUri: _redirectUri,
      ),
    );

    if (code == null) throw Exception('Login cancelled');

    final response = await http.post(
      Uri.parse('$_keycloakBase/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'code': code,
        'code_verifier': codeVerifier,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Token exchange failed (${response.statusCode}): ${response.body}');
    }

    await _saveTokens(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<String?> refreshIfNeeded() async {
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    if (refreshToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$_keycloakBase/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode != 200) {
        await logout();
        return null;
      }

      final tokens = jsonDecode(response.body) as Map<String, dynamic>;
      await _saveTokens(tokens);
      return tokens['access_token'] as String?;
    } catch (_) {
      await logout();
      return null;
    }
  }

  Future<void> logout() => _storage.deleteAll();

  String _randomBase64(int byteCount) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteCount, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _sha256Base64(String input) {
    final digest = sha256.convert(utf8.encode(input));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<void> _saveTokens(Map<String, dynamic> tokens) async {
    if (tokens['access_token'] != null) {
      await _storage.write(
          key: _keyAccessToken, value: tokens['access_token'] as String);
    }
    if (tokens['refresh_token'] != null) {
      await _storage.write(
          key: _keyRefreshToken, value: tokens['refresh_token'] as String);
    }
  }
}

class _LoginWebViewDialog extends StatefulWidget {
  final String url;
  final String redirectUri;

  const _LoginWebViewDialog({required this.url, required this.redirectUri});

  @override
  State<_LoginWebViewDialog> createState() => _LoginWebViewDialogState();
}

class _LoginWebViewDialogState extends State<_LoginWebViewDialog> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36')
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: (request) {
          if (request.url.startsWith(widget.redirectUri)) {
            final uri = Uri.parse(request.url);
            final code = uri.queryParameters['code'];
            if (code != null && mounted) {
              Navigator.of(context).pop(code);
            }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sign in to Bannergress'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(null),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
