import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Recycler-side verification:
/// - Recycler scans QR / code shown to user (handoff_otp)
/// - We verify it matches the transaction and recycler
/// - Then we atomically:
///   - mark global transaction completed
///   - mark pickup_request completed
///   - credit the user (green credits + metrics)
///   - write a completed user transaction entry (same doc id)
class RecyclerVerificationService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  RecyclerVerificationService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  String get _recyclerUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No recycler signed in');
    return uid;
  }

  Future<void> verifyAndComplete({
    required String transactionId,
    required String scannedOtp,
  }) async {
    final txRef = _db.collection('transactions').doc(transactionId);

    await _db.runTransaction((t) async {
      final txSnap = await t.get(txRef);
      if (!txSnap.exists) {
        throw StateError('Transaction not found');
      }

      final tx = txSnap.data() as Map<String, dynamic>;
      final status = (tx['status'] ?? 'pending').toString();
      if (status == 'completed') {
        return; // idempotent
      }

      final recyclerId = (tx['recycler_id'] ?? '').toString();
      if (recyclerId.isEmpty) {
        throw StateError('Transaction missing recycler_id');
      }

      // Only allow the assigned recycler to complete.
      if (recyclerId != _recyclerUid && recyclerId != (tx['recycler_uid'] ?? '').toString()) {
        // We support both styles: recycler doc id may be uid.
        // If your recycler docs use uid as docId, recyclerId == uid.
        throw StateError('This transaction is not assigned to your recycler account.');
      }

      final expectedOtp = (tx['handoff_otp'] ?? '').toString().trim().toUpperCase();
      final gotOtp = scannedOtp.trim().toUpperCase();
      if (expectedOtp.isEmpty) {
        throw StateError('Transaction has no handoff code');
      }
      if (expectedOtp != gotOtp) {
        throw StateError('Invalid QR / handoff code.');
      }

      final userId = (tx['user_id'] ?? '').toString();
      if (userId.isEmpty) throw StateError('Transaction missing user_id');

      final pickupRequestId = (tx['pickup_request_id'] ?? '').toString();
      final gc = (tx['gc_delta'] as num?)?.toInt() ?? 0;
      final cash = (tx['amount_inr'] as num?)?.toDouble() ?? 0.0;
      final co2 = (tx['co2_offset_kg'] as num?)?.toDouble() ?? 0.0;
      final metalsG = (tx['metals_recovered_g'] as num?)?.toDouble() ?? 0.0;
      final energyKwh = (tx['energy_saved_kwh'] as num?)?.toDouble() ?? 0.0;
      final waterL = (tx['water_saved_l'] as num?)?.toDouble() ?? 0.0;
      final deviceName = (tx['device_name'] ?? 'Device').toString();

      final recyclerRef = _db.collection('recyclers').doc(recyclerId);
      final recyclerSnap = await t.get(recyclerRef);
      if (!recyclerSnap.exists) {
        throw StateError('Recycler not found');
      }

      final walletBalance = (recyclerSnap.data()?['wallet_balance_inr'] as num?)?.toDouble() ?? 0.0;
      if (walletBalance < cash) {
        throw StateError('Insufficient wallet balance to payout ₹$cash. Please top up your wallet first.');
      }

      final userRef = _db.collection('users').doc(userId);
      final userTxRef = userRef.collection('transactions').doc(transactionId);

      // Ensure user doc exists.
      final userSnap = await t.get(userRef);
      if (!userSnap.exists) {
        t.set(userRef, {
          'green_credits_balance': 0,
          'cash_balance_inr': 0.0,
          'co2_saved_kg': 0.0,
          'metals_recovered_g': 0.0,
          'energy_saved_kwh': 0.0,
          'water_saved_l': 0.0,
          'total_items_recycled': 0,
          'created_at': FieldValue.serverTimestamp(),
          'is_verified': false,
          'role': 'household',
        }, SetOptions(merge: true));
      }

      // Mark global transaction completed.
      t.set(txRef, {
        'status': 'completed',
        'completed_at': FieldValue.serverTimestamp(),
        'verified_by_recycler_id': recyclerId,
      }, SetOptions(merge: true));

      // Mark pickup_request completed.
      if (pickupRequestId.isNotEmpty) {
        final pickupRef = _db.collection('pickup_requests').doc(pickupRequestId);
        t.set(pickupRef, {
          'status': 'completed',
          'completed_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Update user's wallet + impact metrics.
      t.set(userRef, {
        'green_credits_balance': FieldValue.increment(gc),
        'cash_balance_inr': FieldValue.increment(cash),
        'co2_saved_kg': FieldValue.increment(co2),
        'metals_recovered_g': FieldValue.increment(metalsG),
        'energy_saved_kwh': FieldValue.increment(energyKwh),
        'water_saved_l': FieldValue.increment(waterL),
        'total_items_recycled': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Deduct cash from recycler's wallet
      t.set(recyclerRef, {
        'wallet_balance_inr': FieldValue.increment(-cash),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Ensure user's transaction doc is completed (same id as global tx).
      t.set(userTxRef, {
        'type': 'earn',
        'title': 'Device recycled: $deviceName',
        'device_name': deviceName,
        'amount_inr': cash,
        'gc_delta': gc,
        'co2_offset_kg': co2,
        'metals_recovered_g': metalsG,
        'energy_saved_kwh': energyKwh,
        'water_saved_l': waterL,
        'status': 'completed',
        'pickup_request_id': pickupRequestId,
        'created_at': tx['created_at'] ?? FieldValue.serverTimestamp(),
        'completed_at': FieldValue.serverTimestamp(),
        'source': 'recycler_qr',
        'recycler_id': recyclerId,
        'recycler_name': tx['recycler_name'] ?? '',
      }, SetOptions(merge: true));
    });
  }
}
