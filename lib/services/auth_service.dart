import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' show DriveApi;
// drive.file scope: create and modify files created by this app (visible in Drive)

import '../config.dart';

class AuthService {
  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;

  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      GoogleSignIn.instance.authenticationEvents;

  Future<void> initialize() async {
    GoogleSignIn.instance.authenticationEvents.listen((event) {
      switch (event) {
        case GoogleSignInAuthenticationEventSignIn(:final user):
          _currentUser = user;
        case GoogleSignInAuthenticationEventSignOut():
          _currentUser = null;
      }
    });
    await GoogleSignIn.instance.initialize(
      serverClientId: googleOAuthClientId,
    );
    // Attempt silent sign-in on startup
    await GoogleSignIn.instance.attemptLightweightAuthentication();
  }

  Future<GoogleSignInAccount> signIn() => GoogleSignIn.instance.authenticate(
        scopeHint: [DriveApi.driveFileScope],
      );

  Future<void> signOut() => GoogleSignIn.instance.signOut();
}
