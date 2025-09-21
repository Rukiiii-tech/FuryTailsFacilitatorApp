import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Network Helper for ESP8266 communication (reused from set_feeding_schedule_page.dart)
class NetworkHelper {
  static const String _esp8266IpAddress = '192.168.100.42'; // UPDATE THIS IP!
  static const Duration _timeout = Duration(seconds: 10);

  // Test ESP8266 connectivity
  static Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_esp8266IpAddress/ping'))
          .timeout(_timeout);

      return response.statusCode == 200 && response.body.trim() == 'pong';
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  // Get ESP8266 status
  static Future<Map<String, dynamic>?> getStatus() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_esp8266IpAddress/status'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Status check failed: $e');
    }
    return null;
  }

  // Enhanced trigger feeding with retry mechanism
  static Future<bool> triggerFeeding() async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('Feeding attempt $attempt/3...');

        final response = await http
            .post(
              Uri.parse('http://$_esp8266IpAddress/trigger_feeding'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(_timeout);

        if (response.statusCode == 200) {
          print('✅ Feeding triggered successfully!');
          return true;
        } else {
          print('❌ HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        print('❌ Attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: 2));
        }
      }
    }
    return false;
  }

  static String get ipAddress => _esp8266IpAddress;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _activeBoardingPets = [];
  bool _isLoading = true;
  bool _isDeviceConnected = false;
  bool _isFeedingInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadActiveBoardingPets();
  }

  Future<void> _loadActiveBoardingPets() async {
    try {
      final QuerySnapshot boardingSnapshot =
          await _firestore
              .collection('bookings')
              .where('serviceType', isEqualTo: 'Boarding')
              .where(
                'status',
                whereIn: ['Approved', 'Feeding Scheduled', 'In Progress'],
              )
              .get();

      List<Map<String, dynamic>> activePets = [];
      for (var doc in boardingSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final petInfo = data['petInformation'] as Map<String, dynamic>?;
        final feedingSchedule =
            data['feedingSchedule'] as Map<String, dynamic>?;

        if (petInfo != null) {
          activePets.add({
            'bookingId': doc.id,
            'petName': petInfo['petName'] ?? 'Unknown Pet',
            'petType': petInfo['petType'] ?? 'Unknown',
            'petBreed': petInfo['petBreed'] ?? 'Unknown',
            'feedingSchedule': feedingSchedule,
            'lastFed': data['lastFed'],
            'nextFeeding': _getNextFeedingTime(feedingSchedule),
          });
        }
      }

      setState(() {
        _activeBoardingPets = activePets;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading active boarding pets: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _getNextFeedingTime(Map<String, dynamic>? feedingSchedule) {
    if (feedingSchedule == null) return null;

    final specificTimes = feedingSchedule['specificTimes'] as List<dynamic>?;
    if (specificTimes == null || specificTimes.isEmpty) return null;

    // Simple logic to find next feeding time
    // In a real app, you'd want more sophisticated time calculation
    return specificTimes.first['time'] ?? null;
  }

  Future<void> _triggerManualFeeding(String petName, String bookingId) async {
    setState(() {
      _isFeedingInProgress = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text('Feeding $petName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Triggering manual feeding...'),
              ],
            ),
          ),
    );

    bool success = await NetworkHelper.triggerFeeding();

    Navigator.pop(context); // Close loading dialog

    if (success) {
      // Log the feeding in Firestore
      await _logFeeding(bookingId, petName);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Manual feeding triggered for $petName!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to trigger feeding for $petName'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isFeedingInProgress = false;
    });
  }

  Future<void> _logFeeding(String bookingId, String petName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await _firestore.collection('feedingHistory').add({
        'bookingId': bookingId,
        'petName': petName,
        'feedingType': 'Manual',
        'fedBy': user?.uid ?? 'Unknown',
        'fedAt': FieldValue.serverTimestamp(),
        'notes': 'Manual feeding triggered from home page',
      });

      // Update the booking with last fed timestamp
      await _firestore.collection('bookings').doc(bookingId).update({
        'lastFed': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging feeding: $e');
    }
  }

  Widget _buildQuickFeedingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text(
                  'Quick Manual Feeding',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_activeBoardingPets.isEmpty)
              Text(
                'No active boarding pets found',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              Column(
                children:
                    _activeBoardingPets.map((pet) {
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.shade100,
                            child: Icon(Icons.pets, color: Colors.orange),
                          ),
                          title: Text(
                            pet['petName'],
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${pet['petType']} • ${pet['petBreed']}',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: ElevatedButton.icon(
                            onPressed:
                                _isFeedingInProgress
                                    ? null
                                    : () => _triggerManualFeeding(
                                      pet['petName'],
                                      pet['bookingId'],
                                    ),
                            icon: Icon(Icons.restaurant, size: 16),
                            label: Text('Feed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedingScheduleCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.deepPurple, size: 24),
                SizedBox(width: 8),
                Text(
                  'Today\'s Feeding Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_activeBoardingPets.isEmpty)
              Text(
                'No feeding schedules to display',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              Column(
                children:
                    _activeBoardingPets
                        .where((pet) => pet['feedingSchedule'] != null)
                        .map((pet) {
                          final schedule = pet['feedingSchedule'];
                          final specificTimes =
                              schedule['specificTimes'] as List<dynamic>?;

                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pet['petName'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Food: ${schedule['foodBrand'] ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (specificTimes != null) ...[
                                    SizedBox(height: 8),
                                    ...specificTimes.map(
                                      (time) => Padding(
                                        padding: EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '${time['time']} - ${time['grams']}g',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadActiveBoardingPets();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),

              // Welcome Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade100,
                        Colors.deepPurple.shade100,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to Furry Tails!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Manage your pet care operations efficiently',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Quick Manual Feeding
              _buildQuickFeedingCard(),

              SizedBox(height: 20),

              // Feeding Schedule
              _buildFeedingScheduleCard(),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
