import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionsRepo {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  TransactionsRepo({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No user signed in');
    return uid;
  }

  Query<Map<String, dynamic>> baseQuery() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('transactions')
        .orderBy('created_at', descending: true);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamLatest({int limit = 50}) {
    return baseQuery().limit(limit).snapshots();
  }
}
