import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn;
  static Future<void>? _initFuture;

  GoogleAuthService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  Future<void> initialize() => _ensureInitialized();

  Future<void> _ensureInitialized() {
    _initFuture ??= _googleSignIn.initialize();
    return _initFuture!;
  }

  Future<GoogleSignInAccount?> signIn() async {
    await _ensureInitialized();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError(
        "이 플랫폼은 authenticate 기반 로그인을 지원하지 않아요.",
      );
    }

    return _googleSignIn.authenticate();
  }

  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      _googleSignIn.authenticationEvents;

  Future<String?> getIdToken(GoogleSignInAccount account) async {
    try {
      await _ensureInitialized();
      final auth = account.authentication;
      return auth.idToken;
    } catch (_) {
      return null;
    }
  }
}
