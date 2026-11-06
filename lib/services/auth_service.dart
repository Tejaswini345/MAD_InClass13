import 'package:firebase_auth/firebase_auth.dart';

/// All Firebase Authentication calls live here. Widgets never call
/// FirebaseAuth directly.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Current signed-in user (null when signed out).
  User? get currentUser => _auth.currentUser;

  /// Stable auth-state stream. Emits the restored session on app start,
  /// then again after every sign-in / sign-out.
  late final Stream<User?> authStateChanges = _auth.authStateChanges();

  /// Registers a new user. Firebase signs the new user in automatically.
  Future<UserCredential> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// Updates the password of the signed-in user.
  /// May throw FirebaseAuthException(code: 'requires-recent-login').
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    await user.updatePassword(newPassword);
  }

  /// Re-authenticates with the current password (used for recent-login recovery).
  Future<void> reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Translates Firebase error codes into safe, helpful messages.
  /// Never shows raw exception text and avoids revealing whether an
  /// email exists when signing in.
  static String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address does not look valid.';
      case 'email-already-in-use':
        return 'An account already exists for that email. Try signing in.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network problem. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this project.';
      case 'requires-recent-login':
        return 'For security, please confirm your current password first.';
      case 'no-current-user':
        return 'You are signed out. Please sign in again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

/// Single shared instance used across the app.
final AuthService authService = AuthService();
