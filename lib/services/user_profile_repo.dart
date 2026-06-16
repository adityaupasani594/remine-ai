import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileRepo {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  UserProfileRepo({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No user signed in');
    }
    return uid;
  }

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('users').doc(_uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> stream() => _ref.snapshots();

  Future<DocumentSnapshot<Map<String, dynamic>>> getOnce() => _ref.get();

  Future<void> upsert(Map<String, dynamic> data) async {
    await _ref.set(data, SetOptions(merge: true));
  }
}
