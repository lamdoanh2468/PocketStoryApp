import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<String> getCurrentUserIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập để lấy Firebase ID token.');
    }

    final idToken = await user.getIdToken(forceRefresh);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Không lấy được Firebase ID token của người dùng hiện tại.');
    }

    return idToken;
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    await _upsertUserProfile(credential.user, displayName: displayName);
    return credential;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _upsertUserProfile(credential.user);
    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw StateError('Người dùng đã hủy đăng nhập Google.');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    await _upsertUserProfile(userCredential.user);
    return userCredential;
  }

  Future<void> signOut() async {
    await Future.wait([
      GoogleSignIn().signOut(),
      _auth.signOut(),
    ]);
  }

  Future<void> _upsertUserProfile(User? user, {String? displayName}) async {
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    final now = FieldValue.serverTimestamp();

    if (!snap.exists) {
      await ref.set({
        'displayName': displayName ?? user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'createdAt': now,
        'updatedAt': now,
      });
      return;
    }

    await ref.update({
      'displayName': displayName ?? user.displayName ?? snap.data()?['displayName'] ?? '',
      'email': user.email ?? snap.data()?['email'] ?? '',
      'photoUrl': user.photoURL ?? snap.data()?['photoUrl'],
      'updatedAt': now,
    });
  }
}
