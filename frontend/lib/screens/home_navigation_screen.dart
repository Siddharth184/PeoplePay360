import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/notifications_drawer.dart';
import '../widgets/staff_search_dialog.dart';
import 'employee_profile_screen.dart';
import 'attendance_screen.dart';
import 'time_off_screen.dart';
import 'contracts_screen.dart';
import 'payrun_screen.dart';
import 'analytics_screen.dart';
import 'ai_copilot_screen.dart';
import 'auth_login_screen.dart';
import 'user_management_screen.dart';
import 'employee_directory_screen.dart';
import 'working_schedules_screen.dart';
import 'time_off_setup_screen.dart';
import 'payroll_config_screen.dart';

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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.odooRed),
            SizedBox(width: 10),
            Text('Logout Session'),
          ],
        ),
        content: const Text(
          'Are you sure you want to end your active PeoplePay 360 session? All unsaved AST payroll rule drafts will be synced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.odooRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthLoginScreen()),
                (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🔒 Logged out of OXP Workspace')),
              );
            },
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
      EmployeeDirectoryScreen(onNavigateTab: _onTabSelected),
      const WorkingSchedulesScreen(),
      const TimeOffSetupScreen(),
      const PayrollConfigScreen(),
      const UserManagementScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'PeoplePay 360 (${widget.userRole})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Staff Directory Search',
            onPressed: () {
              StaffSearchDialog.show(
                context,
                onSelectEmployee: (emp) {
                  _onTabSelected(0);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Selected Employee: ${emp.name} (${emp.jobTitle})')),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppTheme.odooTeal,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '2',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            tooltip: 'HR Notifications Inbox',
            onPressed: () {
              NotificationsDrawer.show(context, onNavigateTab: _onTabSelected);
            },
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined, color: AppTheme.odooTeal),
            tooltip: 'AI Copilot RAG Assistant',
            onPressed: () => _onTabSelected(6),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  UserAccountsDrawerHeader(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.odooAubergine, Color(0xFF57344F)],
                      ),
                    ),
                    accountName: const Text('Aarav Mehta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    accountEmail: Text('aarav@oxp.com • ${widget.userRole}'),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        'AM',
                        style: TextStyle(
                          color: AppTheme.odooAubergine,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: AppTheme.odooAubergine),
                    title: const Text('My Profile & Dashboard'),
                    selected: _currentIndex == 0,
                    onTap: () { Navigator.pop(context); _onTabSelected(0); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.fingerprint, color: AppTheme.odooAubergine),
                    title: const Text('Attendance Ledger'),
                    selected: _currentIndex == 1,
                    onTap: () { Navigator.pop(context); _onTabSelected(1); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.flight_takeoff, color: AppTheme.odooAubergine),
                    title: const Text('Time Off & Allocations'),
                    selected: _currentIndex == 2,
                    onTap: () { Navigator.pop(context); _onTabSelected(2); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: AppTheme.odooAubergine),
                    title: const Text('Contracts & AST Rules'),
                    selected: _currentIndex == 3,
                    onTap: () { Navigator.pop(context); _onTabSelected(3); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.payments_outlined, color: AppTheme.odooAubergine),
                    title: const Text('2-Step Payrun Wizard'),
                    selected: _currentIndex == 4,
                    onTap: () { Navigator.pop(context); _onTabSelected(4); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bar_chart_rounded, color: AppTheme.odooAubergine),
                    title: const Text('HR Cost Analytics'),
                    selected: _currentIndex == 5,
                    onTap: () { Navigator.pop(context); _onTabSelected(5); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.smart_toy, color: AppTheme.odooTeal),
                    title: const Text('AI HR Copilot (RAG)'),
                    selected: _currentIndex == 6,
                    onTap: () { Navigator.pop(context); _onTabSelected(6); },
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text('CONFIGURATION & SETUP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_alt_outlined, color: AppTheme.odooAubergine),
                    title: const Text('Employee Master Data'),
                    selected: _currentIndex == 7,
                    onTap: () { Navigator.pop(context); _onTabSelected(7); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded, color: AppTheme.odooAubergine),
                    title: const Text('Working Schedules'),
                    selected: _currentIndex == 8,
                    onTap: () { Navigator.pop(context); _onTabSelected(8); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.beach_access_rounded, color: AppTheme.odooAubergine),
                    title: const Text('Time Off Types & Alloc'),
                    selected: _currentIndex == 9,
                    onTap: () { Navigator.pop(context); _onTabSelected(9); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_suggest_outlined, color: AppTheme.odooAubergine),
                    title: const Text('Payroll Rules & Structure'),
                    selected: _currentIndex == 10,
                    onTap: () { Navigator.pop(context); _onTabSelected(10); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.odooAubergine),
                    title: const Text('User Management (RBAC)'),
                    selected: _currentIndex == 11,
                    onTap: () { Navigator.pop(context); _onTabSelected(11); },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.search_rounded),
                    title: const Text('Staff Directory Search'),
                    onTap: () {
                      Navigator.pop(context);
                      StaffSearchDialog.show(
                        context,
                        onSelectEmployee: (emp) {
                          _onTabSelected(0);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Selected Employee: ${emp.name}')),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            // Bottom Drawer Actions (Logout)
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.odooRed),
              title: const Text(
                'Logout Session',
                style: TextStyle(color: AppTheme.odooRed, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog();
              },
            ),
            const SizedBox(height: 12),
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
        unselectedItemColor: Colors.grey.shade600,
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
