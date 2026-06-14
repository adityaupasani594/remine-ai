import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AddReviewSheet extends StatefulWidget {
  final String userName;
  const AddReviewSheet({super.key, required this.userName});

  @override
  State<AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<AddReviewSheet> {
  final _reviewCtrl = TextEditingController();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _selectedRecyclerId;
  int _rating = 0;
  bool _isSubmitting = false;

  void _submitReview() async {
    if (_selectedRecyclerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a recycler.')));
      return;
    }
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a rating.')));
      return;
    }
    final text = _reviewCtrl.text.trim();

    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final batch = _db.batch();
      
      // 1. Create the review document
      final reviewDoc = _db.collection('seller_review').doc();
      batch.set(reviewDoc, {
        'recycler_id': _selectedRecyclerId,
        'user_id': user.uid,
        'user_name': widget.userName,
        'rating': _rating,
        'review_text': text,
        'created_at': FieldValue.serverTimestamp(),
      });

      // 2. We need to update the average rating on the recycler document. We can do this in a transaction.
      // Alternatively, we use a simple Firebase increment logic if they keep a total_rating and count.
      // Let's use a transaction to be safe and accurate.
      await _db.runTransaction((transaction) async {
        final recyclerRef = _db.collection('recyclers').doc(_selectedRecyclerId);
        final snapshot = await transaction.get(recyclerRef);
        
        if (!snapshot.exists) throw Exception('Recycler not found');
        
        final data = snapshot.data()!;
        final double currentRating = ((data['rating'] ?? 0.0) as num).toDouble();
        final int currentCount = ((data['review_count'] ?? 0) as num).toInt();

        final newCount = currentCount + 1;
        // Calculate new moving average
        final newRating = ((currentRating * currentCount) + _rating) / newCount;

        transaction.update(recyclerRef, {
          'rating': newRating,
          'review_count': newCount,
        });
        
        // Include the review creation in the transaction for atomicity, replacing the batch above.
        transaction.set(reviewDoc, {
          'recycler_id': _selectedRecyclerId,
          'user_id': user.uid,
          'user_name': widget.userName,
          'rating': _rating,
          'review_text': text,
          'created_at': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review submitted successfully!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF2ECC71),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Review / Complaint',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF2C3E50)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))
            ],
          ),
          const SizedBox(height: 16),
          
          Text('Select Recycler', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF8A9BAE))),
          const SizedBox(height: 8),
          
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('recyclers').where('is_verified', isEqualTo: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final docs = snapshot.data!.docs;
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Tap to select a recycler'),
                    value: _selectedRecyclerId,
                    items: docs.map((d) {
                      final name = (d.data() as Map<String, dynamic>)['business_name'] ?? 'Unknown Recycler';
                      return DropdownMenuItem<String>(
                        value: d.id,
                        child: Text(name.toString()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedRecyclerId = val;
                      });
                    },
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          Text('Rating', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF8A9BAE))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () => setState(() => _rating = index + 1),
                icon: Icon(
                  index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: index < _rating ? const Color(0xFFFFC107) : const Color(0xFF8A9BAE),
                  size: 36,
                ),
              );
            }),
          ),
          
          const SizedBox(height: 24),
          
          Text('Your Review or Complaint', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF8A9BAE))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _reviewCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Share your experience with this recycler...',
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Submit Feedback', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
