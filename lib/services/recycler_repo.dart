import 'package:cloud_firestore/cloud_firestore.dart';

class RecyclerRepo {
  final FirebaseFirestore _db;

  RecyclerRepo({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Query<Map<String, dynamic>> queryNearby({String? city, int limit = 50}) {
    // Simple query: optionally filter by city; otherwise just list.
    // NOTE: A real "nearby" query would use GeoFlutterFire or similar.
    var q = _db.collection('recyclers').where('is_verified', isEqualTo: true);
    if (city != null && city.trim().isNotEmpty) {
      q = q.where('city', isEqualTo: city.trim());
    }
    return q.limit(limit);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> stream({String? city, int limit = 50}) {
    return queryNearby(city: city, limit: limit).snapshots();
  }
}
