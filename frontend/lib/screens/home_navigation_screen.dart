import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'employee_profile_screen.dart';
import 'attendance_screen.dart';
import 'time_off_screen.dart';
import 'contracts_screen.dart';
import 'payrun_screen.dart';
import 'analytics_screen.dart';
import 'ai_copilot_screen.dart';

class HomeNavigationScreen extends StatefulWidget {
  final String userRole;
  const HomeNavigationScreen({super.key, required this.userRole});

  @override
  State<HomeNavigationScreen> createState() => _HomeNavigationScreenState();
}

class _HomeNavigationScreenState extends State<HomeNavigationScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      EmployeeProfileScreen(onNavigateTab: _onTabSelected),
      const AttendanceScreen(),
      const TimeOffScreen(),
      const ContractsScreen(),
      const PayrunScreen(),
      const AnalyticsScreen(),
      const AiCopilotScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text('PeoplePay 360 (${widget.userRole})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🔔 2 New HR Escalation Notifications')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined, color: AppTheme.odooTeal),
            onPressed: () => _onTabSelected(6), // Copilot
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.odooAubergine),
              accountName: const Text('Aarav Sharma', style: TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: const Text('aarav.sharma@peoplepay360.io'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Text('AS', style: TextStyle(color: AppTheme.odooAubergine, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('My Profile & Dashboard'),
              onTap: () { Navigator.pop(context); _onTabSelected(0); },
            ),
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('Attendance Ledger'),
              onTap: () { Navigator.pop(context); _onTabSelected(1); },
            ),
            ListTile(
              leading: const Icon(Icons.flight_takeoff),
              title: const Text('Time Off & Leaves'),
              onTap: () { Navigator.pop(context); _onTabSelected(2); },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Contracts & AST Rules'),
              onTap: () { Navigator.pop(context); _onTabSelected(3); },
            ),
            ListTile(
              leading: const Icon(Icons.payments),
              title: const Text('2-Step Payrun Wizard'),
              onTap: () { Navigator.pop(context); _onTabSelected(4); },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('HR Analytics'),
              onTap: () { Navigator.pop(context); _onTabSelected(5); },
            ),
            ListTile(
              leading: const Icon(Icons.smart_toy, color: AppTheme.odooTeal),
              title: const Text('AI HR Copilot (RAG)'),
              onTap: () { Navigator.pop(context); _onTabSelected(6); },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex > 5 ? 5 : _currentIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.odooAubergine,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.fingerprint), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.flight_takeoff), label: 'Time Off'),
          BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: 'Contracts'),
          BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), label: 'Payrun'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: 'Copilot'),
        ],
      ),
    );
  }
}
