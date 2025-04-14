import 'package:flutter/material.dart';
import 'budget.dart'; // Budget page
import 'account.dart'; // Account Management page
import 'report.dart'; // Report page
import 'setting.dart'; // Setting page
import 'dashboard_screen.dart'; // Dashboard page

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xpenses',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // List of pages to display
  final List<Widget> _pages = [
    DashboardScreen(),
    ReportScreen(),
    AccountScreen(),
    BudgetScreen(),
    SettingsScreen(),
  ];

  // Handle the bottom navigation bar item click
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        //title: Text(_getPageTitle(_selectedIndex)),  // Dynamic title based on selected page
      ),
      body: _pages[_selectedIndex],  // Display the selected screen
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueGrey,
        unselectedItemColor: Colors.grey,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Account',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Budget',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  /*
  // Method to return page title based on selected index
  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Report';
      case 2:
        return 'Account';
      case 3:
        return 'Budget';
      case 4:
        return 'Settings';
      default:
        return 'Xpenses';
    }
  }
   */
}
