import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:facilitator1/set_feeding_schedule_page.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _approvedBookingsDocs = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchCheckInBookings(); // Changed method name for clarity
  }

  Future<void> _fetchCheckInBookings() async {
    try {
      final QuerySnapshot checkInBookingsSnapshot =
          await _firestore
              .collection('bookings')
              .where(
                'status',
                isEqualTo: 'Check In',
              ) // Filter for 'Check In' status
              .get();

      if (mounted) {
        setState(() {
          _approvedBookingsDocs = checkInBookingsSnapshot.docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load checked-in bookings: ${e.toString()}';
          _isLoading = false;
        });
        print('Error fetching checked-in bookings: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Checked-In Bookings',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Colors.white,
            fontFamily: 'Roboto',
          ),
        ),
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
              : _approvedBookingsDocs.isEmpty
              ? const Center(
                child: Text(
                  'No checked-in bookings found.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _approvedBookingsDocs.length,
                itemBuilder: (context, index) {
                  final doc = _approvedBookingsDocs[index];
                  final booking = doc.data() as Map<String, dynamic>;
                  final bookingId = doc.id;

                  final petInfo =
                      booking['petInformation'] as Map<String, dynamic>?;
                  final serviceType = booking['serviceType'] ?? 'N/A';
                  final bookingDate =
                      booking['date'] ??
                      (booking['boardingDetails']?['checkInDate'] ??
                          booking['groomingDetails']?['groomingCheckInDate'] ??
                          'N/A');
                  final bookingTime = booking['time'] ?? 'N/A';

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  SetFeedingSchedulePage(bookingId: bookingId),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: Offset(0, 8),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(22.0),
                      ),
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22.0),
                          side: BorderSide(
                            color: Colors.grey.withOpacity(0.18),
                            width: 1.2,
                          ),
                        ),
                        color: const Color(0xFFEDEDED),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22.0,
                            vertical: 22.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Booking ID: $bookingId',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[800],
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.green[600],
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.green.withOpacity(
                                              0.18,
                                            ),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 7,
                                      ),
                                      child: Text(
                                        booking['status'] ?? 'N/A',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Divider(
                                height: 18,
                                thickness: 1.1,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pet: ${petInfo?['petName'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF22223B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Service: $serviceType',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF4A4E69),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Date: $bookingDate, Time: $bookingTime',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF4A4E69),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
