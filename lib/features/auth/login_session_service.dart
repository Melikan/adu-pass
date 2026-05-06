import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Son girisin uzerinden [loginCooldown] gecmeden tekrar giris engeli.
class LoginCooldownException implements Exception {
  LoginCooldownException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Son basarili giris ve giris gecmisi Firestore'da tutulur:
/// `user_login_meta/{uid}` + alt koleksiyon `login_history`.
///
/// Security Rules icin ornek: sadece `request.auth.uid == uid`
/// olan kullanicinin bu dokumanlari okuyup yazmasina izin verin.
class LoginSessionService {
  LoginSessionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const loginCooldown = Duration(minutes: 5);

  /// [FirebaseAuth.signInWithEmailAndPassword] basarili olduktan hemen sonra cagrilir.
  /// Cooldown ihlali varsa oturumu kapatir ve [LoginCooldownException] firlatir.
  Future<void> enforceCooldownAndRecordLogin() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final metaRef = _firestore.collection('user_login_meta').doc(uid);

    final snapshot = await metaRef.get();
    final lastTs = snapshot.data()?['lastSuccessfulLoginAt'] as Timestamp?;

    if (lastTs != null) {
      final elapsed = DateTime.now().difference(lastTs.toDate());
      if (elapsed < loginCooldown) {
        final remaining = loginCooldown - elapsed;
        final mins = remaining.inMinutes;
        final secs = remaining.inSeconds % 60;
        await _auth.signOut();
        throw LoginCooldownException(
          'Zaten giris yaptiniz. Tekrar giris icin '
          '${mins > 0 ? '$mins dk ' : ''}${secs > 0 ? '$secs sn ' : ''}bekleyin.',
        );
      }
    }

    final batch = _firestore.batch();
    batch.set(metaRef, {
      'lastSuccessfulLoginAt': FieldValue.serverTimestamp(),
      'email': user.email,
    }, SetOptions(merge: true));

    final historyRef = metaRef.collection('login_history').doc();
    batch.set(historyRef, {'loggedAt': FieldValue.serverTimestamp()});

    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> loginHistoryStream(String uid) {
    return _firestore
        .collection('user_login_meta')
        .doc(uid)
        .collection('login_history')
        .orderBy('loggedAt', descending: true)
        .limit(25)
        .snapshots();
  }
}
