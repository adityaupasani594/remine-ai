import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/gemini_service.dart';
import '../services/pickup_service.dart';
import '../services/recycler_repo.dart';
import '../widgets/view_reviews_sheet.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const Color _kEmerald = Color(0xFF2ECC71);
const Color _kDark = Color(0xFF2C3E50);
const Color _kSoft = Color(0xFF8A9BAE);
const Color _kOffWhite = Color(0xFFF5F5F7);

// ─── Screen ───────────────────────────────────────────────────────────────────
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  int _selectedPin = 0;
  bool _bookingBusy = false;
  DeviceAnalysis? _analysis;
  final _recyclerRepo = RecyclerRepo();
  String? _selectedRecyclerId;
  Map<String, dynamic>? _selectedRecycler;

  // Simple seed locations near Mumbai for now.
  final List<LatLng> _pinLatLng = const [
    LatLng(19.0760, 72.8777),
    LatLng(19.0830, 72.8900),
    LatLng(19.0650, 72.8650),
    LatLng(19.0900, 72.8600),
  ];

  GoogleMapController? _mapCtrl;

  Set<Marker> _buildMarkersFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return {
      for (final d in docs)
        if ((d.data()['location'] is GeoPoint))
          Marker(
            markerId: MarkerId('recycler_${d.id}'),
            position: LatLng(
              (d.data()['location'] as GeoPoint).latitude,
              (d.data()['location'] as GeoPoint).longitude,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              d.id == _selectedRecyclerId
                  ? BitmapDescriptor.hueGreen
                  : BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: (d.data()['business_name'] ?? 'Recycler').toString(),
              snippet:
                  '${(d.data()['rating'] ?? 0).toString()} ★ · ${(d.data()['distance_km'] ?? '').toString()} km',
            ),
            onTap: () {
              setState(() {
                _selectedRecyclerId = d.id;
                _selectedRecycler = {'document_id': d.id, ...d.data()};
              });
            },
          ),
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_analysis == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is DeviceAnalysis) {
        _analysis = args;
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _onBookPickup() async {
    if (_analysis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No device data. Please scan a device first.'),
        ),
      );
      return;
    }

    if (_selectedRecyclerId == null || _selectedRecycler == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recycler on the map.')),
      );
      return;
    }

    setState(() => _bookingBusy = true);
    try {
      final r = _selectedRecycler!;
      await PickupService().createPickupRequest(
        analysis: _analysis!,
        recyclerId: _selectedRecyclerId,
        recyclerName: (r['business_name'] ?? r['recycler_name'] ?? 'Recycler')
            .toString(),
        recyclerRating: ((r['rating'] ?? 0.0) as num).toDouble(),
        recyclerDistance:
            '${((r['distance_km'] ?? 0.0) as num).toDouble().toStringAsFixed(1)} km',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pickup scheduled successfully!',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF2ECC71),
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
    } finally {
      if (mounted) setState(() => _bookingBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _recyclerRepo.stream(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];

          // Default camera target.
          LatLng initialTarget = const LatLng(19.0760, 72.8777);
          if (_selectedRecycler != null &&
              (_selectedRecycler!['location'] is GeoPoint)) {
            final gp = _selectedRecycler!['location'] as GeoPoint;
            initialTarget = LatLng(gp.latitude, gp.longitude);
          } else {
            for (final d in docs) {
              final loc = d.data()['location'];
              if (loc is GeoPoint) {
                initialTarget = LatLng(loc.latitude, loc.longitude);
                break;
              }
            }
          }

          // Auto-select the first recycler if none selected.
          if (_selectedRecyclerId == null && docs.isNotEmpty) {
            final first = docs.first;
            _selectedRecyclerId = first.id;
            _selectedRecycler = {'document_id': first.id, ...first.data()};
          }

          final selected = _selectedRecycler;

          return Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: 12.8,
                  ),
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  markers: _buildMarkersFromDocs(docs),
                  onMapCreated: (c) => _mapCtrl = c,
                ),
              ),

              SafeArea(
                child: Column(
                  children: [const SizedBox(height: 12), _buildSearchBar()],
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomRecyclerCard(selected),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search_rounded, color: _kEmerald, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search nearby recyclers...',
                style: GoogleFonts.inter(fontSize: 14, color: _kSoft),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kEmerald,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomRecyclerCard(Map<String, dynamic>? recycler) {
    final name = (recycler?['business_name'] ?? 'Select a recycler').toString();
    final rating = ((recycler?['rating'] ?? 0.0) as num).toDouble();
    final distanceKm = ((recycler?['distance_km'] ?? 0.0) as num).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _kOffWhite,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ─────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _kEmerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.recycling_rounded,
                        color: _kEmerald,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _kDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Color(0xFFFFC107),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _kDark,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: _kSoft,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${distanceKm.toStringAsFixed(1)} km',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: _kSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _bookingBusy || recycler == null
                        ? null
                        : _onBookPickup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kEmerald,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kEmerald.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _bookingBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Schedule Pickup',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 10),

                // View Reviews Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: recycler == null
                        ? null
                        : () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => ViewReviewsSheet(
                                recyclerId: recycler['document_id'].toString(),
                                recyclerName: name,
                              ),
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kEmerald,
                      side: const BorderSide(color: _kEmerald, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'View Reviews & Ratings',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
