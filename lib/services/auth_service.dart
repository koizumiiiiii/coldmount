import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class AuthService {
  // Admin role is assigned via Firestore users/{uid}.role == 'admin'.
  // No email is hardcoded here to avoid leaking personal accounts on GitHub.

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // streams login state changes for the whole app shell
  Stream<User?> get userStream => _auth.authStateChanges();

  // exposes current signed in user id or null
  String? get currentUid => _auth.currentUser?.uid;

  // fetches user profile document from firestore by uid
  Future<Map<String, dynamic>?> fetchProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // updates stored profile photo url for given user
  Future<void> updatePhotoUrl(String uid, String url) {
    return _db.collection('users').doc(uid).update({'photo_url': url});
  }

  // signs in with email and returns the user role string
  Future<String> signIn(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail, password: password);
      return await resolveRole(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthError(_messageFor(e));
    }
  }

  // resolves user role from firestore; admin must be set manually in console
  Future<String> resolveRole(User user) async {
    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return (doc.data()?['role'] as String?) ?? 'tenant';
    }
    // blocks entry when no registered profile document is found
    await _auth.signOut();
    throw const AuthError(
      'This account is not registered in Coldmount. Ask your admin for an account.');
  }

  // creates tenant account without signing out current admin
  Future<void> createTenant({
    required String email,
    required String tempPassword,
    required String name,
    required String unit,
    required String phone,
    required String occupation,
    String role = 'tenant',
  }) async {
    FirebaseApp secondary;
    try {
      secondary = Firebase.app('secondary');
    } catch (_) {
      secondary = await Firebase.initializeApp(
        name: 'secondary',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    try {
      final cred = await FirebaseAuth.instanceFor(app: secondary)
        .createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(), password: tempPassword);
      await _db.collection('users').doc(cred.user!.uid).set({
        'email': email.trim().toLowerCase(),
        'role': role,
        'name': name,
        'unit': unit,
        'phone': phone,
        'occupation': occupation,
        'createdAt': Timestamp.now(),
      });
    } on FirebaseAuthException catch (e) {
      // tells apart real duplicates from orphaned logins of deleted accounts
      if (e.code == 'email-already-in-use') {
        final clean = email.trim().toLowerCase();
        final existing = await _db
          .collection('users')
          .where('email', isEqualTo: clean)
          .limit(1)
          .get();
        if (existing.docs.isNotEmpty) {
          throw const AuthError('This email is already registered.');
        }
        throw const AuthError(
          'This email was deleted before but its login still exists. '
          'Delete it in Firebase Console > Authentication, or tap send reset link below and create again after reset.');
      }
      throw AuthError(_messageFor(e));
    } finally {
      await FirebaseAuth.instanceFor(app: secondary).signOut();
    }
  }

  // sends password reset link for reclaiming an orphaned login
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      throw AuthError(_messageFor(e));
    }
  }

  // signs out the currently authenticated firebase user
  Future<void> signOut() => _auth.signOut();

  // changes temporary password to tenant chosen private password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthError('You are not signed in. Log in again first.');
    }
    if (newPassword.length < 6) {
      throw const AuthError('New password must be at least 6 characters.');
    }
    try {
      final cred = EmailAuthProvider.credential(
        email: email, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthError('Current password is incorrect.');
      }
      throw AuthError(_messageFor(e));
    }
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'This email or password does not exist. Ask your admin for an account.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection. Connect and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'Sign-in failed (${e.code}). Try again.';
    }
  }
}

class AuthError implements Exception {
  final String message;
  const AuthError(this.message);
  @override
  String toString() => message;
}
