// lib/set_feeding_schedule_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

// Enhanced Network Helper for ESP8266 communication
class NetworkHelper {
  // IMPORTANT: UPDATE THIS IP ADDRESS TO YOUR ESP8266'S ACTUAL IP
  static const String _esp8266IpAddress = '192.168.100.42';
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
          print('❌ HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        print('❌ Attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    return false;
  }

  // Enhanced servo test with retry mechanism
  static Future<bool> testServo() async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('Servo test attempt $attempt/3...');

        final response = await http
            .post(
              Uri.parse('http://$_esp8266IpAddress/test_servo'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'command': 'TEST_SERVO'}),
            )
            .timeout(_timeout);

        if (response.statusCode == 200) {
          print('✅ Servo test completed successfully!');
          return true;
        } else {
          print('❌ HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        print('❌ Attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    return false;
  }

  // Send schedule to ESP8266 with retry mechanism
  // The scheduleData should now directly contain 'petName' and 'feedingTimes'
  static Future<bool> sendSchedule(Map<String, dynamic> scheduleData) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('Schedule send attempt $attempt/3...');
        print(
          'Sending data to ESP: ${json.encode(scheduleData)}',
        ); // Debug print

        final response = await http
            .post(
              Uri.parse('http://$_esp8266IpAddress/set_schedule'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(scheduleData),
            )
            .timeout(
              const Duration(seconds: 15),
            ); // Increased timeout for schedule

        if (response.statusCode == 200) {
          print('✅ Schedule sent successfully!');
          return true;
        } else {
          print('❌ HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        print('❌ Attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    return false;
  }

  static String get ipAddress => _esp8266IpAddress;
}

class SetFeedingSchedulePage extends StatefulWidget {
  final String bookingId;

  const SetFeedingSchedulePage({Key? key, required this.bookingId})
    : super(key: key);

  @override
  State<SetFeedingSchedulePage> createState() => _SetFeedingSchedulePageState();
}

class _SetFeedingSchedulePageState extends State<SetFeedingSchedulePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _bookingDetails;
  bool _isLoading = true;
  String _errorMessage = '';

  // Controllers for facilitator-set feeding schedule inputs
  final List<Map<String, TextEditingController>> _feedingTimeControllers = [];

  // Variable to store the current facilitator's UID
  String? _currentFacilitatorUid;

  // Card style variables for reuse
  final cardColor = const Color(0xFFF3EEFF);
  final cardRadius = BorderRadius.circular(22);
  final cardShadow = [
    BoxShadow(
      color: Colors.deepPurple.withOpacity(0.10),
      blurRadius: 18,
      spreadRadius: 2,
      offset: const Offset(0, 8),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentFacilitatorUid();
    _fetchBookingDetails();
  }

  @override
  void dispose() {
    for (var controllers in _feedingTimeControllers) {
      controllers['time']?.dispose();
      controllers['grams']?.dispose();
    }
    super.dispose();
  }

  void _getCurrentFacilitatorUid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentFacilitatorUid = user.uid;
      });
    } else {
      print("Warning: No facilitator is logged in. Cannot get UID.");
    }
  }

  Future<void> _fetchBookingDetails() async {
    try {
      final DocumentSnapshot bookingSnapshot =
          await _firestore.collection('bookings').doc(widget.bookingId).get();

      if (bookingSnapshot.exists) {
        setState(() {
          _bookingDetails = bookingSnapshot.data() as Map<String, dynamic>;
          _isLoading = false;
        });

        final existingFacilitatorSchedule =
            _bookingDetails!['feedingSchedule'] as Map<String, dynamic>?;
        if (existingFacilitatorSchedule != null) {
          if (existingFacilitatorSchedule['specificTimes'] is List) {
            final List<dynamic> loadedTimes =
                existingFacilitatorSchedule['specificTimes'];
            setState(() {
              _feedingTimeControllers.clear();
              for (var item in loadedTimes) {
                if (item is Map<String, dynamic>) {
                  _feedingTimeControllers.add({
                    'time': TextEditingController(text: item['time'] ?? ''),
                    'grams': TextEditingController(
                      text: (item['grams'] ?? '').toString(),
                    ),
                  });
                }
              }
            });
          }
        } else {
          final customerFeedingDetails =
              _bookingDetails!['feedingDetails'] as Map<String, dynamic>?;
          if (customerFeedingDetails != null) {
            setState(() {
              _feedingTimeControllers.clear();
              if (customerFeedingDetails['morningFeeding'] == true &&
                  customerFeedingDetails['morningTime'] != null &&
                  customerFeedingDetails['morningTime'].isNotEmpty) {
                _feedingTimeControllers.add({
                  'time': TextEditingController(
                    text: customerFeedingDetails['morningTime'],
                  ),
                  'grams': TextEditingController(
                    text:
                        customerFeedingDetails['morningFoodGrams']
                            ?.toString() ??
                        '',
                  ),
                });
              }
              if (customerFeedingDetails['afternoonFeeding'] == true &&
                  customerFeedingDetails['afternoonTime'] != null &&
                  customerFeedingDetails['afternoonTime'].isNotEmpty) {
                _feedingTimeControllers.add({
                  'time': TextEditingController(
                    text: customerFeedingDetails['afternoonTime'],
                  ),
                  'grams': TextEditingController(
                    text:
                        customerFeedingDetails['afternoonFoodGrams']
                            ?.toString() ??
                        '',
                  ),
                });
              }
              if (customerFeedingDetails['eveningFeeding'] == true &&
                  customerFeedingDetails['eveningTime'] != null &&
                  customerFeedingDetails['eveningTime'].isNotEmpty) {
                _feedingTimeControllers.add({
                  'time': TextEditingController(
                    text: customerFeedingDetails['eveningTime'],
                  ),
                  'grams': TextEditingController(
                    text:
                        customerFeedingDetails['eveningFoodGrams']
                            ?.toString() ??
                        '',
                  ),
                });
              }
            });
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Booking details not found.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load booking details: $e';
        _isLoading = false;
      });
      print('Error fetching booking details: $e');
    }
  }

  void _addFeedingTimeField() {
    setState(() {
      _feedingTimeControllers.add({
        'time': TextEditingController(),
        'grams': TextEditingController(),
      });
    });
  }

  void _removeFeedingTimeField(int index) {
    setState(() {
      _feedingTimeControllers[index]['time']?.dispose();
      _feedingTimeControllers[index]['grams']?.dispose();
      _feedingTimeControllers.removeAt(index);
    });
  }

  // Test ESP8266 connection
  void _testESP8266Connection() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Testing ESP8266 Connection'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking device connectivity...'),
              ],
            ),
          ),
    );

    // Test basic connectivity
    bool isConnected = await NetworkHelper.testConnection();

    if (!mounted)
      return; // Check if widget is still mounted before popping dialog
    Navigator.pop(context); // Close loading dialog

    if (isConnected) {
      // Get detailed status
      Map<String, dynamic>? status = await NetworkHelper.getStatus();

      if (!mounted) return; // Check if widget is still mounted
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('✅ ESP8266 Connected'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Device is online and responding!'),
                  if (status != null) ...[
                    const SizedBox(height: 10),
                    Text('IP: ${status['ip']}'),
                    Text('Signal: ${status['rssi'] ?? 0} dBm'),
                    Text(
                      'Uptime: ${Duration(milliseconds: (status['uptime'] ?? 0)).inMinutes} min',
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    } else {
      _showConnectionErrorDialog();
    }
  }

  // Manual feeding with improved error handling
  void _triggerFeeding() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Triggering Manual Feed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Sending command to feeder...'),
              ],
            ),
          ),
    );

    bool success = await NetworkHelper.triggerFeeding();

    if (!mounted)
      return; // Check if widget is still mounted before popping dialog
    Navigator.pop(context); // Close loading dialog

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Manual feeding triggered successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _showConnectionErrorDialog();
    }
  }

  // Connection error dialog with troubleshooting
  void _showConnectionErrorDialog() {
    if (!mounted)
      return; // Ensure the widget is still mounted before showing dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('❌ Connection Failed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cannot connect to ESP8266 device.'),
                const SizedBox(height: 10),
                const Text(
                  'Troubleshooting steps:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text('1. Check ESP8266 power and WiFi connection'),
                Text('2. Verify IP address: ${NetworkHelper.ipAddress}'),
                const Text('3. Ensure both devices are on same network'),
                const Text('4. Check ESP8266 serial monitor for errors'),
              ],
            ),
          ),
    );
  }

  Future<void> _saveFeedingSchedule() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Saving Schedule'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Saving to database and sending to feeder...'),
              ],
            ),
          ),
    );

    try {
      if (_bookingDetails == null) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot save schedule: Booking details not loaded.'),
          ),
        );
        return;
      }

      if (_feedingTimeControllers.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one feeding time.'),
          ),
        );
        return;
      }

      List<Map<String, dynamic>> specificFeedingTimes =
          []; // Changed to dynamic for grams
      for (var controllers in _feedingTimeControllers) {
        final time = controllers['time']!.text.trim();
        final grams = controllers['grams']!.text.trim();

        if (time.isEmpty || grams.isEmpty) {
          if (!mounted) return;
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please fill all feeding time and grams fields.'),
            ),
          );
          return;
        }

        final double parsedGrams = double.tryParse(grams) ?? 0;

        if (parsedGrams == null) {
          if (!mounted) return;
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid number for grams.'),
            ),
          );
          return;
        }

        specificFeedingTimes.add({
          'time': time,
          'grams': parsedGrams,
        }); // Store grams as double
      }

      final petInfo =
          _bookingDetails!['petInformation'] as Map<String, dynamic>?;

      final String scheduledBy =
          _currentFacilitatorUid ?? 'Unknown Facilitator';

      // Save to Firestore first
      await _firestore.collection('bookings').doc(widget.bookingId).update({
        'feedingSchedule': {
          'specificTimes': specificFeedingTimes,
          'scheduledBy': scheduledBy,
          'scheduledAt': FieldValue.serverTimestamp(),
        },
        'status': 'Feeding Scheduled',
        'updateAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('feedingHistory').add({
        'bookingId': widget.bookingId,
        'petId': petInfo?['petId'] ?? 'N/A',
        'petName': petInfo?['petName'] ?? 'N/A',
        'specificTimes': specificFeedingTimes,
        'scheduledAt': FieldValue.serverTimestamp(),
        'scheduledBy': scheduledBy,
      });

      // Prepare ESP8266 data - ONLY include petName and feedingTimes as expected by ESP8266
      final String espPetName = petInfo?['petName'] ?? 'Unknown Pet';

      final espData = {
        'petName': espPetName,
        'feedingTimes': specificFeedingTimes,
      };

      // Send to ESP8266 with enhanced error handling
      bool espSuccess = await NetworkHelper.sendSchedule(espData);

      if (!mounted)
        return; // Check if widget is still mounted before popping dialog
      Navigator.pop(context); // Close loading dialog

      if (espSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Schedule saved to database and sent to ESP8266!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Schedule saved to database but failed to send to ESP8266. Check device connection.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // No Navigator.pop(context) here as the SnackBar might still be visible
      // and the user might want to stay on the page after saving.
      // If you want to navigate back, uncomment the line below:
      // Navigator.pop(context);
    } catch (e) {
      print('Overall Save Error: $e');
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog in case of error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save feeding schedule. Please try again.'),
        ),
      );
    }
  }

  // Helper widget to build information rows with consistent styling
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor ?? Colors.grey[600]),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    String? suffixText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        suffixText: suffixText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
      validator: validator,
    );
  }

  // Helper for Section Titles
  Widget _buildSectionTitle(String title, {Color color = Colors.deepPurple}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // Helper for read-only pet details
  Widget _buildReadOnlyDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  // Build control buttons for ESP8266 interaction
  Widget _buildControlButtons() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Device Controls', color: Colors.blue),
            Text(
              'ESP8266 IP: ${NetworkHelper.ipAddress}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testESP8266Connection,
                    icon: const Icon(Icons.wifi),
                    label: const Text('Test Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced Manual Feeding Section
  Widget _buildManualFeedingSection() {
    final petInfo = _bookingDetails!['petInformation'] as Map<String, dynamic>?;
    final petName = petInfo?['petName'] ?? 'Unknown Pet';

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade50, Colors.orange.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.restaurant,
                    color: Colors.orange.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manual Feeding Control',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        Text(
                          'Direct device control for $petName',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Device Status Indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color:
                          Colors
                              .green, // This would be dynamic based on connection status
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Device Status: Connected',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _testESP8266Connection,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Manual Feeding Controls
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _triggerFeeding,
                      icon: const Icon(Icons.restaurant, size: 24),
                      label: const Text(
                        'TRIGGER FEEDING',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Feeding Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feeding Information:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This will dispense food according to the current schedule settings',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Set Feeding Schedule'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Set Feeding Schedule'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final booking = _bookingDetails!;
    final petInfo = booking['petInformation'] as Map<String, dynamic>?;
    final boardingDetails = booking['boardingDetails'] as Map<String, dynamic>?;
    final groomingDetails = booking['groomingDetails'] as Map<String, dynamic>?;

    final timestamp = booking['timestamp'] as Timestamp?;
    final formattedTimestamp =
        timestamp != null
            ? DateFormat(
              'MMM dd, yyyy HH:mm a',
            ).format(timestamp.toDate().toLocal())
            : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Feeding Schedule'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device Control Section
            if (booking['serviceType'] != 'Grooming') _buildControlButtons(),

            // Manual Feeding Section (for boarding services only)
            if (booking['serviceType'] != 'Grooming')
              _buildManualFeedingSection(),

            // Booking Overview
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: cardRadius,
                boxShadow: cardShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking Overview',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Divider(height: 24, thickness: 1.2),
                    _buildInfoRow(
                      Icons.confirmation_num_rounded,
                      'Booking ID',
                      widget.bookingId,
                      iconColor: Colors.deepPurple,
                    ),
                    _buildInfoRow(
                      Icons.pets,
                      'Pet Name',
                      petInfo?['petName'] ?? 'N/A',
                      iconColor: Colors.deepPurple,
                    ),
                    _buildInfoRow(
                      Icons.medical_services,
                      'Service Type',
                      booking['serviceType'] ?? 'N/A',
                      iconColor: Colors.deepPurple,
                    ),
                    _buildInfoRow(
                      Icons.access_time,
                      'Booked Time',
                      booking['time'] ?? 'N/A',
                      iconColor: Colors.deepPurple,
                    ),
                    if (booking['serviceType'] == 'Boarding') ...[
                      _buildInfoRow(
                        Icons.date_range,
                        'Check-in Date',
                        boardingDetails?['checkInDate'] ?? 'N/A',
                        iconColor: Colors.deepPurple,
                      ),
                      _buildInfoRow(
                        Icons.date_range,
                        'Check-out Date',
                        boardingDetails?['checkOutDate'] ?? 'N/A',
                        iconColor: Colors.deepPurple,
                      ),
                      _buildInfoRow(
                        Icons.king_bed,
                        'Room Type',
                        boardingDetails?['selectedRoomType'] ?? 'N/A',
                        iconColor: Colors.deepPurple,
                      ),
                    ] else if (booking['serviceType'] == 'Grooming') ...[
                      _buildInfoRow(
                        Icons.date_range,
                        'Grooming Date',
                        groomingDetails?['groomingCheckInDate'] ?? 'N/A',
                        iconColor: Colors.deepPurple,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Pet Details
            if (petInfo != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Pet Details'),
                      _buildReadOnlyDetail(
                        'Pet Type',
                        petInfo['petType'] ?? 'N/A',
                      ),
                      _buildReadOnlyDetail(
                        'Breed',
                        petInfo['petBreed'] ?? 'N/A',
                      ),
                      _buildReadOnlyDetail(
                        'Gender',
                        petInfo['petGender'] ?? 'N/A',
                      ),
                      _buildReadOnlyDetail(
                        'Weight (kg)',
                        petInfo['petWeight']?.toString() ?? 'N/A',
                      ),
                      _buildReadOnlyDetail(
                        'Birthdate',
                        petInfo['dateOfBirth'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        Icons.fingerprint,
                        'Pet ID',
                        petInfo['petId'] ?? 'N/A',
                      ),
                    ],
                  ),
                ),
              ),

            // Customer's Feeding Details
            if (booking['feedingDetails'] != null &&
                booking['serviceType'] == 'Boarding')
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(
                        'Customer\'s Declared Feeding Details',
                      ),
                      _buildInfoRow(
                        Icons.restaurant,
                        'Food Brand',
                        booking['feedingDetails']['foodBrand'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        Icons.format_list_numbered,
                        'Number of Meals',
                        booking['feedingDetails']['numberOfMeals'] ?? 'N/A',
                      ),
                      if (booking['feedingDetails']['morningFeeding'] == true)
                        _buildInfoRow(
                          Icons.wb_sunny,
                          'Morning Feeding Time',
                          booking['feedingDetails']['morningTime'] ?? 'N/A',
                        ),
                      if (booking['feedingDetails']['morningFeeding'] == true)
                        _buildInfoRow(
                          Icons.scale,
                          'Morning Food Grams',
                          booking['feedingDetails']['morningFoodGrams']
                                  ?.toString() ??
                              'N/A',
                        ),
                      if (booking['feedingDetails']['afternoonFeeding'] == true)
                        _buildInfoRow(
                          Icons.flare,
                          'Afternoon Feeding Time',
                          booking['feedingDetails']['afternoonTime'] ?? 'N/A',
                        ),
                      if (booking['feedingDetails']['afternoonFeeding'] == true)
                        _buildInfoRow(
                          Icons.scale,
                          'Afternoon Food Grams',
                          booking['feedingDetails']['afternoonFoodGrams']
                                  ?.toString() ??
                              'N/A',
                        ),
                      if (booking['feedingDetails']['eveningFeeding'] == true)
                        _buildInfoRow(
                          Icons.nights_stay,
                          'Evening Feeding Time',
                          booking['feedingDetails']['eveningTime'] ?? 'N/A',
                        ),
                      if (booking['feedingDetails']['eveningFeeding'] == true)
                        _buildInfoRow(
                          Icons.scale,
                          'Evening Food Grams',
                          booking['feedingDetails']['eveningFoodGrams']
                                  ?.toString() ??
                              'N/A',
                        ),
                    ],
                  ),
                ),
              ),

            // Facilitator Schedule Setting
            if (booking['serviceType'] != 'Grooming')
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(
                        'Facilitator: Set Pet Feeding Schedule',
                        color: Colors.deepOrange,
                      ),
                      Text(
                        'Specific Feeding Times:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children:
                            _feedingTimeControllers.asMap().entries.map((
                              entry,
                            ) {
                              int idx = entry.key;
                              var controllers = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          _buildTextField(
                                            controller: controllers['time']!,
                                            labelText: 'Time (e.g., 8:00 AM)',
                                            icon: Icons.alarm,
                                            readOnly: true,
                                            onTap:
                                                () => _selectTime(
                                                  context,
                                                  controllers['time']!,
                                                ),
                                            validator:
                                                (value) =>
                                                    value!.isEmpty
                                                        ? 'Time required'
                                                        : null,
                                          ),
                                          const SizedBox(height: 10),
                                          _buildTextField(
                                            controller: controllers['grams']!,
                                            labelText: 'Grams',
                                            icon: Icons.scale,
                                            keyboardType: TextInputType.number,
                                            suffixText: 'grams',
                                            validator: (value) {
                                              if (value!.isEmpty) {
                                                return 'Grams required';
                                              }
                                              if (double.tryParse(value) ==
                                                  null) {
                                                return 'Enter valid number';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle,
                                        color: Colors.red,
                                      ),
                                      onPressed:
                                          () => _removeFeedingTimeField(idx),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addFeedingTimeField,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.green,
                          ),
                          label: const Text('Add Feeding Time'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveFeedingSchedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 8,
                            shadowColor: Colors.deepPurple.withOpacity(0.25),
                          ),
                          icon: const Icon(Icons.save, size: 24),
                          label: const Text(
                            'Save Feeding Schedule',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
