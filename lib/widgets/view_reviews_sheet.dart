import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ViewReviewsSheet extends StatelessWidget {
  final String recyclerId;
  final String recyclerName;

  const ViewReviewsSheet({
    super.key,
    required this.recyclerId,
    required this.recyclerName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reviews',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2C3E50),
                      ),
                    ),
                    Text(
                      recyclerName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF8A9BAE),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('seller_review')
                  .where('recycler_id', isEqualTo: recyclerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading reviews: ${snapshot.error}'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data?.docs.toList() ?? [];

                // Sort client-side to avoid needing a composite index in Firestore
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['created_at'] as Timestamp?;
                  final bTime = bData['created_at'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  // If aTime is null, it means it's still being written to the server (FieldValue.serverTimestamp())
                  // usually we want those at the very top (newest).
                  if (aTime == null) return -1;
                  if (bTime == null) return 1;
                  return bTime.compareTo(aTime); // descending
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No reviews yet for this recycler.',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF8A9BAE),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 32, color: Color(0xFFE5EBE8)),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final userName = data['user_name'] ?? 'Anonymous';
                    final rating = ((data['rating'] ?? 0) as num).toInt();
                    final text = data['review_text'] ?? '';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(
                                0xFF2ECC71,
                              ).withValues(alpha: 0.15),
                              child: Text(
                                userName
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF2ECC71),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                userName,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: const Color(0xFF2C3E50),
                                ),
                              ),
                            ),
                            Row(
                              children: List.generate(5, (starIdx) {
                                return Icon(
                                  starIdx < rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: const Color(0xFFFFC107),
                                  size: 16,
                                );
                              }),
                            ),
                          ],
                        ),
                        if (text.toString().trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            text,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF2C3E50),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
