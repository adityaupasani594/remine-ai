import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'gemini_service.dart';

class RecycleResult {
  final int creditsDelta;
  final double cashDeltaInr;
  final double co2DeltaKg;
  final double metalsDeltaG;
  final double energyDeltaKwh;
  final double waterDeltaL;
  final String deviceName;

  const RecycleResult({
    required this.creditsDelta,
    required this.cashDeltaInr,
    required this.co2DeltaKg,
    required this.metalsDeltaG,
    required this.energyDeltaKwh,
    required this.waterDeltaL,
    required this.deviceName,
  });
}

class RecycleService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  RecycleService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No user signed in');
    return uid;
  }

  /// Computes rewards from a device analysis. Keep it deterministic.
  ///
  /// - Green credits: 1 per ₹100 scrap value (min 5, max 250)
  /// - CO2 offset: proportional to value (simple heuristic)
  /// - Metals recovered: heuristic from value (grams)
  /// - Energy saved: heuristic from CO2
  /// - Water saved: heuristic from CO2
  static ({int gc, double cash, double co2, double metalsG, double energyKwh, double waterL}) computeRewards(DeviceAnalysis a) {
    final cash = a.totalValueInr;
    final gcRaw = (cash / 100).round();
    final gc = gcRaw.clamp(5, 250);
    final co2 = (cash / 1500).clamp(0.2, 8.0); // rough estimate

    final metalsG = (cash / 12).clamp(20.0, 1200.0);
    final energyKwh = (co2 * 1.5).clamp(0.2, 20.0);
    final waterL = (co2 * 2.0).clamp(0.5, 30.0);

    return (gc: gc, cash: cash, co2: co2, metalsG: metalsG, energyKwh: energyKwh, waterL: waterL);
  }

  Future<RecycleResult> commitRecycle({required DeviceAnalysis analysis}) async {
    final rewards = computeRewards(analysis);
    final userRef = _db.collection('users').doc(_uid);
    final txRef = userRef.collection('transactions').doc();

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

      t.set(txRef, {
        'type': 'earn',
        'title': 'Device recycled: ${analysis.deviceName}',
        'device_name': analysis.deviceName,
        'amount_inr': rewards.cash,
        'gc_delta': rewards.gc,
        'co2_offset_kg': rewards.co2,
        'metals_recovered_g': rewards.metalsG,
        'energy_saved_kwh': rewards.energyKwh,
        'water_saved_l': rewards.waterL,
        'status': 'completed',
        'created_at': FieldValue.serverTimestamp(),
        'source': 'gemini',
      });

      t.set(
        userRef,
        {
          'green_credits_balance': FieldValue.increment(rewards.gc),
          'cash_balance_inr': FieldValue.increment(rewards.cash),
          'co2_saved_kg': FieldValue.increment(rewards.co2),
          'metals_recovered_g': FieldValue.increment(rewards.metalsG),
          'energy_saved_kwh': FieldValue.increment(rewards.energyKwh),
          'water_saved_l': FieldValue.increment(rewards.waterL),
          'total_items_recycled': FieldValue.increment(1),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    return RecycleResult(
      creditsDelta: rewards.gc,
      cashDeltaInr: rewards.cash,
      co2DeltaKg: rewards.co2,
      metalsDeltaG: rewards.metalsG,
      energyDeltaKwh: rewards.energyKwh,
      waterDeltaL: rewards.waterL,
      deviceName: analysis.deviceName,
    );
  }
}
