import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting

class SingleBookingDetailsPage extends StatefulWidget {
  final String bookingId; // Expects a booking ID to fetch details

  const SingleBookingDetailsPage({super.key, required this.bookingId});

  @override
  State<SingleBookingDetailsPage> createState() =>
      _SingleBookingDetailsPageState();
}

class _SingleBookingDetailsPageState extends State<SingleBookingDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _bookingDetails;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();
  }

  Future<void> _fetchBookingDetails() async {
    try {
      final DocumentSnapshot bookingSnapshot =
          await _firestore.collection('bookings').doc(widget.bookingId).get();

      if (mounted) {
        if (bookingSnapshot.exists) {
          setState(() {
            _bookingDetails = bookingSnapshot.data() as Map<String, dynamic>;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage =
                'Booking details not found for ID: ${widget.bookingId}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load booking details: ${e.toString()}';
          _isLoading = false;
        });
        print('Error fetching booking details: $e');
      }
    }
  }

  // Helper widget to build information rows with consistent styling
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
                  overflow: TextOverflow.ellipsis, // Added to prevent overflow
                  maxLines: 2, // Allow up to 2 lines before ellipsis
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for Section Titles, consistent with booking_form_screen
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple.shade700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Booking Details'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Booking Details'),
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

    // Assuming _bookingDetails is not null at this point due to checks above
    final booking = _bookingDetails!;
    final petInfo = booking['petInformation'] as Map<String, dynamic>?;
    final ownerInfo = booking['ownerInformation'] as Map<String, dynamic>?;
    final boardingDetails = booking['boardingDetails'] as Map<String, dynamic>?;
    final groomingDetails = booking['groomingDetails'] as Map<String, dynamic>?;

    // Format timestamps for display
    final timestamp = booking['timestamp'] as Timestamp?;
    // Corrected the date format string by removing "Jamboree"
    final formattedTimestamp =
        timestamp != null
            ? DateFormat(
              'MMM dd, yyyy HH:mm a',
            ).format(timestamp.toDate().toLocal())
            : 'N/A';
    final updateTime = booking['updateAt'] as Timestamp?;
    final formattedUpdateTime =
        updateTime != null
            ? DateFormat(
              'MMM dd, yyyy HH:mm a',
            ).format(updateTime.toDate().toLocal())
            : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Booking Overview
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
                    Text(
                      'Booking Overview',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const Divider(height: 20, thickness: 1),
                    _buildInfoRow(
                      Icons.confirmation_num,
                      'Booking ID',
                      widget.bookingId,
                    ),
                    _buildInfoRow(
                      Icons.pets,
                      'Pet Name',
                      petInfo?['petName'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      Icons.medical_services,
                      'Service Type',
                      booking['serviceType'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      Icons.access_time,
                      'Booked Time',
                      booking['time'] ?? 'N/A',
                    ),

                    if (booking['serviceType'] == 'Boarding') ...[
                      _buildInfoRow(
                        Icons.date_range,
                        'Check-in Date',
                        boardingDetails?['checkInDate'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        Icons.date_range,
                        'Check-out Date',
                        boardingDetails?['checkOutDate'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        Icons.king_bed,
                        'Room Type',
                        boardingDetails?['selectedRoomType'] ?? 'N/A',
                      ),
                    ] else if (booking['serviceType'] == 'Grooming') ...[
                      _buildInfoRow(
                        Icons.date_range,
                        'Grooming Date',
                        groomingDetails?['groomingCheckInDate'] ?? 'N/A',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Section: Client Information
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
                    Text(
                      'Client Information',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const Divider(height: 20, thickness: 1),
                    _buildInfoRow(
                      Icons.person,
                      'Name',
                      '${ownerInfo?['firstName'] ?? 'N/A'} ${ownerInfo?['lastName'] ?? ''}',
                    ),
                    _buildInfoRow(
                      Icons.phone,
                      'Contact Number',
                      ownerInfo?['contactNo'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      Icons.email,
                      'Email Address',
                      ownerInfo?['email'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      Icons.location_on,
                      'Address',
                      ownerInfo?['address'] ?? 'N/A',
                    ),
                  ],
                ),
              ),
            ),

            // Section: Pet Details (conditionally displayed if petInfo exists)
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
                      Text(
                        'Pet Details',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const Divider(height: 20, thickness: 1),
                      _buildInfoRow(
                        Icons.fingerprint,
                        'Pet ID',
                        petInfo['petId'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        Icons.category,
                        'Breed',
                        petInfo['petBreed'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        Icons.transgender,
                        'Gender',
                        petInfo['petGender'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        Icons.pets,
                        'Type',
                        petInfo['petType'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        Icons.monitor_weight,
                        'Weight',
                        '${petInfo['petWeight'] ?? 'N/A'} kg',
                      ),
                      _buildInfoRow(
                        Icons.cake,
                        'Date of Birth (Pet)',
                        petInfo['dateOfBirth'] ?? 'N/A',
                      ),
                      // You can add an Image.network here if petInfo['petProfileImgUrl'] is a valid URL
                      // if (petInfo['petProfileImgUrl'] != null && petInfo['petProfileImgUrl'].isNotEmpty)
                      //   Image.network(petInfo['petProfileImgUrl']),
                    ],
                  ),
                ),
              ),

            // Section: Customer's Declared Feeding Details (if available for Boarding)
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
                      Text(
                        'Customer\'s Declared Feeding Details',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const Divider(height: 20, thickness: 1),
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
                      if (booking['feedingDetails']['afternoonFeeding'] == true)
                        _buildInfoRow(
                          Icons.flare,
                          'Afternoon Feeding Time',
                          booking['feedingDetails']['afternoonTime'] ?? 'N/A',
                        ),
                      if (booking['feedingDetails']['eveningFeeding'] == true)
                        _buildInfoRow(
                          Icons.nights_stay,
                          'Evening Feeding Time',
                          booking['feedingDetails']['eveningTime'] ?? 'N/A',
                        ),
                    ],
                  ),
                ),
              ),

            // Section: Payment Details (if available for Boarding)
            if (booking['paymentDetails'] != null &&
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
                      Text(
                        'Payment Details',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const Divider(height: 20, thickness: 1),
                      _buildInfoRow(
                        Icons.credit_card,
                        'Method',
                        booking['paymentDetails']['method'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        Icons.numbers,
                        'Account No.',
                        booking['paymentDetails']['accountNumber'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        Icons.account_circle,
                        'Account Name',
                        booking['paymentDetails']['accountName'] ?? 'N/A',
                      ),
                      if (booking['paymentDetails']['receiptImageUrl'] !=
                              null &&
                          booking['paymentDetails']['receiptImageUrl']
                              .isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            Text(
                              'Payment Receipt:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Center(
                              child: Image.network(
                                booking['paymentDetails']['receiptImageUrl'],
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

            // Section: Vaccination Record (if available for Boarding)
            if (booking['vaccinationRecord'] != null &&
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
                      Text(
                        'Vaccination Record',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const Divider(height: 20, thickness: 1),
                      if (booking['vaccinationRecord']['imageUrl'] != null &&
                          booking['vaccinationRecord']['imageUrl'].isNotEmpty)
                        Center(
                          child: Image.network(
                            booking['vaccinationRecord']['imageUrl'],
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        const Text('No vaccination record image uploaded.'),
                    ],
                  ),
                ),
              ),

            // Section: Admin Notes (if available)
            if (booking['adminNotes'] != null &&
                booking['adminNotes'].isNotEmpty)
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
                      Text(
                        'Admin Notes',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const Divider(height: 20, thickness: 1),
                      Text(
                        booking['adminNotes'],
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Section: Booking Timestamps
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
                    Text(
                      'Booking Timestamps',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const Divider(height: 20, thickness: 1),
                    _buildInfoRow(Icons.event, 'Booked At', formattedTimestamp),
                    _buildInfoRow(
                      Icons.history,
                      'Last Updated',
                      formattedUpdateTime,
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
