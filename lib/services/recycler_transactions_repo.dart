import 'package:cloud_firestore/cloud_firestore.dart';

class RecyclerTransactionsRepo {
  final FirebaseFirestore _db;

  RecyclerTransactionsRepo({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Query<Map<String, dynamic>> queryForRecycler(String recyclerId, {int limit = 100}) {
    return _db
        .collection('transactions')
        .where('recycler_id', isEqualTo: recyclerId)
        .limit(limit);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamForRecycler(String recyclerId, {int limit = 100}) {
    return queryForRecycler(recyclerId, limit: limit).snapshots();
  }
}
