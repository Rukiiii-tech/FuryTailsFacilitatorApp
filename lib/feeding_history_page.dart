// lib/feeding_history_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting

// Model for a Feeding Record
class FeedingRecord {
  final String id;
  final String bookingId;
  final String petId;
  final String petName;
  final String ownerName; // Now expected to be in Firestore
  final String foodBrand;
  final List<Map<String, String>> specificTimes; // Store both time and grams
  final Timestamp scheduledAt;
  final String scheduledBy;

  FeedingRecord({
    required this.id,
    required this.bookingId,
    required this.petId,
    required this.petName,
    required this.ownerName,
    required this.foodBrand,
    required this.specificTimes,
    required this.scheduledAt,
    required this.scheduledBy,
  });

  factory FeedingRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<Map<String, String>> parsedSpecificTimes = [];
    if (data['specificTimes'] is List) {
      for (var item in data['specificTimes']) {
        if (item is Map<String, dynamic>) {
          // Parse both 'time' and 'grams'
          parsedSpecificTimes.add({
            'time': item['time']?.toString() ?? 'N/A',
            'grams': item['grams']?.toString() ?? 'N/A', // Added grams
          });
        }
      }
    }

    return FeedingRecord(
      id: doc.id,
      bookingId: data['bookingId'] ?? '',
      petId: data['petId'] ?? 'N/A',
      petName: data['petName'] ?? 'N/A',
      ownerName: data['ownerName'] ?? 'N/A', // Now expecting ownerName in data
      foodBrand: data['foodBrand'] ?? 'N/A',
      specificTimes: parsedSpecificTimes,
      scheduledAt:
          data['scheduledAt'] is Timestamp
              ? data['scheduledAt'] as Timestamp
              : Timestamp.now(),
      scheduledBy: data['scheduledBy'] ?? 'N/A',
    );
  }
}

class FeedingHistoryPage extends StatefulWidget {
  const FeedingHistoryPage({super.key});

  @override
  State<FeedingHistoryPage> createState() => _FeedingHistoryPageState();
}

class _FeedingHistoryPageState extends State<FeedingHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<FeedingRecord>> _getFeedingHistoryStream() {
    return _firestore
        .collection('feedingHistory')
        .orderBy('scheduledAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => FeedingRecord.fromFirestore(doc))
                  .toList(),
        );
  }

  // Helper widget to build information rows with consistent styling
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    double labelSize = 14,
    double valueSize = 16,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2.0,
      ), // Reduced vertical padding for compactness
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]), // Smaller icon
          const SizedBox(width: 8), // Reduced spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: labelSize,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: valueSize,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for Section Titles (used only in the detail bottom sheet now)
  Widget _buildSectionTitle(
    String title, {
    Color color = Colors.deepPurple,
    double fontSize = 18,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10.0,
      ), // Reduced vertical padding
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // Function to show all details in a bottom sheet
  void _showFeedingRecordDetails(BuildContext context, FeedingRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows content to be scrollable
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8, // Start at 80% of screen height
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20.0),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  Text(
                    'Feeding Record Details',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  _buildSectionTitle(
                    'Booking & Pet Info',
                    color: Colors.blueAccent,
                    fontSize: 16,
                  ),
                  _buildInfoRow(
                    Icons.confirmation_num,
                    'Booking ID',
                    record.bookingId,
                    labelSize: 13,
                    valueSize: 14,
                  ),
                  _buildInfoRow(
                    Icons.pets,
                    'Pet Name',
                    record.petName,
                    labelSize: 13,
                    valueSize: 14,
                  ),
                  _buildInfoRow(
                    Icons.fingerprint,
                    'Pet ID',
                    record.petId,
                    labelSize: 13,
                    valueSize: 14,
                  ),
                  _buildInfoRow(
                    Icons.person,
                    'Owner Name',
                    record.ownerName, // This will now be populated
                    labelSize: 13,
                    valueSize: 14,
                  ),

                  const Divider(height: 30, thickness: 1),

                  _buildSectionTitle(
                    'Feeding Specifics',
                    color: Colors.deepOrange,
                    fontSize: 16,
                  ),
                  _buildInfoRow(
                    Icons.restaurant,
                    'Food Brand',
                    record.foodBrand,
                    labelSize: 13,
                    valueSize: 14,
                  ),
                  _buildInfoRow(
                    Icons.format_list_numbered,
                    'Number of Meals',
                    record.specificTimes.length.toString(),
                    labelSize: 13,
                    valueSize: 14,
                  ),

                  const SizedBox(height: 10),
                  Text(
                    'Scheduled Times & Grams:', // Updated label
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (record.specificTimes.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          record.specificTimes.map((timeEntry) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 10.0,
                                bottom: 4.0,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${timeEntry['time']} (${timeEntry['grams']}g)', // Display grams
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(left: 10.0),
                      child: Text(
                        'No specific times recorded.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                  const Divider(height: 30, thickness: 1),

                  _buildSectionTitle(
                    'Record Metadata',
                    color: Colors.green,
                    fontSize: 16,
                  ),
                  _buildInfoRow(
                    Icons.event,
                    'Scheduled At',
                    DateFormat(
                      'MMM dd, yyyy HH:mm a', // Corrected format string
                    ).format(record.scheduledAt.toDate().toLocal()),
                    labelSize: 13,
                    valueSize: 14,
                  ),
                  _buildInfoRow(
                    Icons.person_outline,
                    'Recorded by',
                    record.scheduledBy,
                    labelSize: 13,
                    valueSize: 14,
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Close Details',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteFeedingRecord(String recordId) async {
    // Show a confirmation dialog
    bool confirmDelete =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Delete'),
              content: const Text(
                'Are you sure you want to delete this feeding record?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false; // In case the dialog is dismissed by tapping outside

    if (confirmDelete) {
      try {
        await _firestore.collection('feedingHistory').doc(recordId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feeding record deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete record: ${e.toString()}')),
        );
        print('Error deleting feeding record: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeding History'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              'Recent Feeding Records',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<FeedingRecord>>(
              stream: _getFeedingHistoryStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50.0),
                      child: Text(
                        'No feeding records found yet.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                List<FeedingRecord> records = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    FeedingRecord record = records[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.lightBlue.shade50,
                      child: InkWell(
                        onTap: () => _showFeedingRecordDetails(context, record),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Booking ID: ${record.bookingId}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'By: ${record.scheduledBy}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  // Delete button added here
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed:
                                        () => _deleteFeedingRecord(record.id),
                                    tooltip: 'Delete Record',
                                  ),
                                ],
                              ),
                              const Divider(
                                height: 16,
                                thickness: 0.8,
                                color: Colors.blueGrey,
                              ),

                              _buildInfoRow(
                                Icons.pets,
                                'Pet Name',
                                record.petName,
                                valueColor: Colors.deepPurple,
                                labelSize: 13,
                                valueSize:
                                    16, // UI FIX: Slightly increased for emphasis
                              ),
                              _buildInfoRow(
                                Icons.person,
                                'Owner Name',
                                record.ownerName, // This will now be populated
                                labelSize: 13,
                                valueSize: 15,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  'Tap for more details →',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
