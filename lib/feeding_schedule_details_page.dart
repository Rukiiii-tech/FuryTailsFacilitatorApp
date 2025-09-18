import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FeedingScheduleDetailsPage extends StatefulWidget {
  final String bookingId;

  const FeedingScheduleDetailsPage({super.key, required this.bookingId});

  @override
  State<FeedingScheduleDetailsPage> createState() =>
      _FeedingScheduleDetailsPageState();
}

class _FeedingScheduleDetailsPageState
    extends State<FeedingScheduleDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _feedingSchedule;
  String? _petName;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchFeedingSchedule();
  }

  Future<void> _fetchFeedingSchedule() async {
    try {
      final DocumentSnapshot bookingSnapshot =
          await _firestore.collection('bookings').doc(widget.bookingId).get();

      if (mounted) {
        if (bookingSnapshot.exists) {
          final data = bookingSnapshot.data() as Map<String, dynamic>;
          setState(() {
            _petName =
                data['petInformation']?['petName']?.toString() ??
                'Unknown Pet'; // Added .toString()
            // Ensure feedingSchedule is treated as a Map<String, dynamic>
            _feedingSchedule =
                data['feedingSchedule'] is Map
                    ? Map<String, dynamic>.from(data['feedingSchedule'])
                    : null;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Booking not found for ID: ${widget.bookingId}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load feeding schedule: ${e.toString()}';
          _isLoading = false;
        });
        print('Error fetching feeding schedule: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic>? specificTimesList;
    if (_feedingSchedule != null &&
        _feedingSchedule!['specificTimes'] is List) {
      specificTimesList = _feedingSchedule!['specificTimes'] as List;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Feeding Schedule for ${_petName ?? 'Pet'}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: Colors.deepPurple,
                              size: 28,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Scheduled Meals',
                              style: Theme.of(
                                context,
                              ).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade800,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20, thickness: 1),
                        if (specificTimesList == null ||
                            specificTimesList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Text(
                                'No specific feeding times set for this pet.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                Icons.restaurant_menu,
                                'Food Brand',
                                _feedingSchedule!['foodBrand']?.toString() ??
                                    'N/A', // Ensure it's string
                              ),
                              _buildInfoRow(
                                Icons.format_list_numbered,
                                'Number of Meals',
                                specificTimesList.length.toString(),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Meal Times & Portions:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...specificTimesList.map((item) {
                                // Safely cast item to Map<String, dynamic>
                                final timeEntry =
                                    item is Map
                                        ? Map<String, dynamic>.from(item)
                                        : <String, dynamic>{};
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    left: 10.0,
                                    bottom: 8.0,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 20,
                                        color: Colors.blueGrey,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${timeEntry['time']?.toString() ?? 'N/A'} - ${timeEntry['grams']?.toString() ?? 'N/A'}g', // Safely access and convert to string
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
