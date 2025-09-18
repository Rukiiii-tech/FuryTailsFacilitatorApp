import 'package:facilitator1/bookings_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:facilitator1/login_screen.dart';
import 'package:facilitator1/home_page.dart'; // Ensure this import is correct
import 'package:facilitator1/feeding_history_page.dart';
import 'package:facilitator1/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  // NEW: Add initialTabIndex to the constructor
  final int initialTabIndex;

  const HomeScreen({
    super.key,
    this.initialTabIndex = 0,
  }); // Default to 0 if not provided

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Index of the selected tab

  late final List<Widget> _widgetOptions; // Initialized in initState

  int _boardingCount = 0;
  int _groomingCount = 0;
  bool _isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    // Initialize _selectedIndex with the value from the constructor
    _selectedIndex = widget.initialTabIndex;

    // Initialize _widgetOptions here
    _widgetOptions = <Widget>[
      const HomePage(),
      const BookingPage(),
      const FeedingHistoryPage(),
      const ProfilePage(),
    ];

    _fetchServiceCounts();
  }

  Future<void> _fetchServiceCounts() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final boardingSnapshot =
          await firestore
              .collection('bookings')
              .where('serviceType', isEqualTo: 'Boarding')
              .where('status', isEqualTo: 'Approved')
              .get();
      final groomingSnapshot =
          await firestore
              .collection('bookings')
              .where('serviceType', isEqualTo: 'Grooming')
              .where('status', isEqualTo: 'Approved')
              .get();
      if (mounted) {
        setState(() {
          _boardingCount = boardingSnapshot.size;
          _groomingCount = groomingSnapshot.size;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCounts = false;
        });
      }
      print('Error fetching service counts: $e');
    }
  }

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_selectedIndex == 0)
            Column(
              children: [
                const SizedBox(height: 36),
                Center(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 180,
                    height: 180,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _selectedIndex = 1),
                        child: Card(
                          color: Colors.deepPurple.shade50,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 24,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.king_bed,
                                  color: Colors.deepPurple,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Boarding',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _isLoadingCounts
                                    ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Text(
                                      '$_boardingCount',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: () => setState(() => _selectedIndex = 1),
                        child: Card(
                          color: Colors.orange.shade50,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 24,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cut, color: Colors.orange, size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  'Grooming',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _isLoadingCounts
                                    ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Text(
                                      '$_groomingCount',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          Expanded(child: _widgetOptions[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
          child: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Pets'),
              BottomNavigationBarItem(
                icon: Icon(Icons.fastfood), // Icon for feeding
                label: 'Feeding',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor:
                Theme.of(
                  context,
                ).colorScheme.secondary, // Selected item uses secondary color
            unselectedItemColor: Theme.of(context).colorScheme.onPrimary
                .withOpacity(0.6), // Unselected items are slightly faded
            onTap: onItemTapped, // Use the public onItemTapped
            type: BottomNavigationBarType.fixed,
            backgroundColor:
                Theme.of(context).colorScheme.primary, // Background color
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
