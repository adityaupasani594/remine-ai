import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'gemini_service.dart';
import 'recycle_service.dart';

/// Data returned after a pickup request is created.
class PickupRequestResult {
  final String pickupDocId;
  final String handoffOtp;
  final String recyclerName;
  final double recyclerRating;
  final String recyclerDistance;
  final String deviceName;
  final String deviceDetails;
  final double totalValueInr;
  final int greenCredits;
  final String transactionId;
  final String recyclerId;

  const PickupRequestResult({
    required this.pickupDocId,
    required this.handoffOtp,
    required this.recyclerName,
    required this.recyclerRating,
    required this.recyclerDistance,
    required this.deviceName,
    required this.deviceDetails,
    required this.totalValueInr,
    required this.greenCredits,
    required this.transactionId,
    required this.recyclerId,
  });
}

class PickupService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  PickupService({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No user signed in');
    return uid;
  }

  /// Generates a random 6-character alphanumeric OTP.
  static String _generateOtp() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous 0/O, 1/I
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Creates a pickup request in Firestore and returns the document ID + OTP.
  Future<PickupRequestResult> createPickupRequest({
    required DeviceAnalysis analysis,
    required String recyclerName,
    required double recyclerRating,
    required String recyclerDistance,
    String? recyclerId,
  }) async {
    final rewards = RecycleService.computeRewards(analysis);
    final otp = _generateOtp();

    final pickupRef = _db.collection('pickup_requests').doc();
    final txRef = _db.collection('transactions').doc();

    final resolvedRecyclerId = (recyclerId ?? '').trim().isNotEmpty
        ? recyclerId!.trim()
        : 'unknown';

    await _db.runTransaction((t) async {
      t.set(pickupRef, {
        'user_id': _uid,
        'recycler_id': resolvedRecyclerId,
        'recycler_name': recyclerName,
        'recycler_rating': recyclerRating,
        'recycler_distance': recyclerDistance,
        'device_name': analysis.deviceName,
        'device_details': analysis.deviceDetails,
        'total_value_inr': analysis.totalValueInr,
        'green_credits': rewards.gc,
        'co2_kg': rewards.co2,
        'metals_g': rewards.metalsG,
        'energy_kwh': rewards.energyKwh,
        'water_l': rewards.waterL,
        'handoff_otp': otp,
        'status': 'pending',
        'transaction_id': txRef.id,
        'created_at': FieldValue.serverTimestamp(),
      });

      t.set(txRef, {
        'type': 'pickup',
        'status': 'pending',
        'user_id': _uid,
        'recycler_id': resolvedRecyclerId,
        'recycler_name': recyclerName,
        'pickup_request_id': pickupRef.id,
        'handoff_otp': otp,
        'device_name': analysis.deviceName,
        'device_details': analysis.deviceDetails,
        'amount_inr': analysis.totalValueInr,
        'gc_delta': rewards.gc,
        'co2_offset_kg': rewards.co2,
        'metals_recovered_g': rewards.metalsG,
        'energy_saved_kwh': rewards.energyKwh,
        'water_saved_l': rewards.waterL,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Also add to user's own subcollection for immediate wallet/history UI.
      final userTxRef = _db
          .collection('users')
          .doc(_uid)
          .collection('transactions')
          .doc(txRef.id);
      t.set(userTxRef, {
        'type': 'pickup',
        'status': 'pending',
        'title': 'Pickup scheduled: ${analysis.deviceName}',
        'pickup_request_id': pickupRef.id,
        'handoff_otp': otp,
        'recycler_id': resolvedRecyclerId,
        'recycler_name': recyclerName,
        'device_name': analysis.deviceName,
        'amount_inr': analysis.totalValueInr,
        'gc_delta': rewards.gc,
        'created_at': FieldValue.serverTimestamp(),
        'source': 'pickup',
      });
    });

    return PickupRequestResult(
      pickupDocId: pickupRef.id,
      handoffOtp: otp,
      recyclerName: recyclerName,
      recyclerRating: recyclerRating,
      recyclerDistance: recyclerDistance,
      deviceName: analysis.deviceName,
      deviceDetails: analysis.deviceDetails,
      totalValueInr: analysis.totalValueInr,
      greenCredits: rewards.gc,
      transactionId: txRef.id,
      recyclerId: resolvedRecyclerId,
    );
  }

  /// Returns a real-time stream for a pickup request document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPickup(
    String pickupDocId,
  ) {
    return _db.collection('pickup_requests').doc(pickupDocId).snapshots();
  }

  /// Called when the pickup status changes to `completed`.
  /// Writes credits to the user profile and creates a transaction record.
  Future<RecycleResult> completePickup({required String pickupDocId}) async {
    final pickupSnap = await _db
        .collection('pickup_requests')
        .doc(pickupDocId)
        .get();
    if (!pickupSnap.exists) {
      throw StateError('Pickup document not found');
    }

    final data = pickupSnap.data()!;
    final gc = (data['green_credits'] as num?)?.toInt() ?? 0;
    final cash = (data['total_value_inr'] as num?)?.toDouble() ?? 0.0;
    final co2 = (data['co2_kg'] as num?)?.toDouble() ?? 0.0;
    final metalsG = (data['metals_g'] as num?)?.toDouble() ?? 0.0;
    final energyKwh = (data['energy_kwh'] as num?)?.toDouble() ?? 0.0;
    final waterL = (data['water_l'] as num?)?.toDouble() ?? 0.0;
    final deviceName = (data['device_name'] as String?) ?? 'Device';
    final txId = (data['transaction_id'] as String?) ?? '';

    final userRef = _db.collection('users').doc(_uid);
    final txRef = txId.isNotEmpty
        ? _db.collection('users').doc(_uid).collection('transactions').doc(txId)
        : userRef.collection('transactions').doc();

    await _db.runTransaction((t) async {
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

      // Note: User credits and wallet balances are now updated in RecyclerVerificationService.
      // This function only ensures the transaction and pickup document states are resolved if called manually.

      // update user tx (subcollection)
      t.set(txRef, {
        'status': 'completed',
        'completed_at': FieldValue.serverTimestamp(),
        'source': 'smart_handshake',
      }, SetOptions(merge: true));

      // update global transaction if exists
      if (txId.isNotEmpty) {
        final globalTxRef = _db.collection('transactions').doc(txId);
        t.set(globalTxRef, {
          'status': 'completed',
          'completed_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });

    return RecycleResult(
      creditsDelta: gc,
      cashDeltaInr: cash,
      co2DeltaKg: co2,
      metalsDeltaG: metalsG,
      energyDeltaKwh: energyKwh,
      waterDeltaL: waterL,
      deviceName: deviceName,
    );
  }
}
