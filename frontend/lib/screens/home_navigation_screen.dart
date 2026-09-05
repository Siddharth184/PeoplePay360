import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/notifications_drawer.dart';
import '../widgets/staff_search_dialog.dart';
import '../services/api_client.dart';
import '../services/mock_data_service.dart';
import '../services/employee_service.dart';
import '../models/models.dart';
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
  final List<int> _tabHistory = [0];
  DateTime? _lastBackPressTime;

  void _onTabSelected(int index) {
    if (index == -1) {
      _handleBack();
      return;
    }
    if (_currentIndex != index) {
      setState(() {
        _tabHistory.add(index);
        _currentIndex = index;
      });
    }
  }

  void _handleBack() {
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
        _currentIndex = _tabHistory.last;
      });
    } else if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
        _tabHistory.clear();
        _tabHistory.add(0);
      });
    } else {
      final now = DateTime.now();
      if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
        _lastBackPressTime = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit PeoplePay 360'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          SystemNavigator.pop();
        }
      }
    }
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
    final bool isEmployee = ApiClient.isEmployee;
    final bool hasPayroll = ApiClient.hasPayrollAccess;
    final bool hasHr = ApiClient.hasHrAccess;
    final bool isAdmin = ApiClient.isAdmin;
    final bool isHrManager = ApiClient.isRoleHrManager;

    // Access Guard Screen for restricted modules
    Widget accessDeniedScreen(String moduleName, String requiredRole) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.odooRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_person_outlined, color: AppTheme.odooRed, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Access Restricted',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
              ),
              const SizedBox(height: 8),
              Text(
                'Your current role (${ApiClient.activeRole}) does not have permission to access the $moduleName module.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF4E444A)),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Required Access: $requiredRole',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF00696E)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.odooAubergine,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => _onTabSelected(0),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Return to My Profile'),
              ),
            ],
          ),
        ),
      );
    }

    final screens = [
      EmployeeProfileScreen(onNavigateTab: _onTabSelected), // 0: Profile
      AttendanceScreen(onNavigateTab: _onTabSelected), // 1: Attendance
      TimeOffScreen(onNavigateTab: _onTabSelected), // 2: Time Off
      hasHr ? ContractsScreen(onNavigateTab: _onTabSelected) : accessDeniedScreen('Contracts', 'HR Manager / Payroll / Admin'), // 3: Contracts
      hasPayroll ? PayrunScreen(onNavigateTab: _onTabSelected) : accessDeniedScreen('Payrun & Payslips', 'HR Payroll User / Payroll Manager / Admin'), // 4: Payrun
      (hasHr || hasPayroll) ? AnalyticsScreen(onNavigateTab: _onTabSelected) : accessDeniedScreen('HR Analytics', 'HR / Payroll / Admin'), // 5: Analytics
      AiCopilotScreen(onNavigateTab: _onTabSelected), // 6: AI Copilot
      hasHr ? EmployeeDirectoryScreen(onNavigateTab: _onTabSelected) : accessDeniedScreen('Employee Master Data', 'HR Manager / Payroll / Admin'), // 7: Employee Master
      hasHr ? WorkingSchedulesScreen(onNavigateTab: _onTabSelected) : accessDeniedScreen('Working Schedules', 'HR Manager / Payroll / Admin'), // 8: Working Schedules
      hasHr ? TimeOffSetupScreen(onNavigateTab: _onTabSelected) : accessDeniedScreen('Time Off Setup', 'HR Manager / Payroll / Admin'), // 9: Time Off Setup
      hasPayroll ? PayrollConfigScreen(onNavigateTab: _onTabSelected) : accessDeniedScreen('Payroll Rules & Structure', 'HR Payroll User (Read-Only) / Payroll Manager'), // 10: Payroll Config
      isAdmin ? UserManagementScreen(onNavigateTab: _onTabSelected) : accessDeniedScreen('User Management & RBAC', 'System Administrator'), // 11: User Management
    ];

    // Build bottom navigation bar items based on role
    List<BottomNavigationBarItem> bottomNavItems;
    List<int> bottomNavIndices;

    if (isEmployee) {
      bottomNavItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'My Profile'),
        BottomNavigationBarItem(icon: Icon(Icons.fingerprint), label: 'Attendance'),
        BottomNavigationBarItem(icon: Icon(Icons.flight_takeoff), label: 'Time Off'),
        BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: 'Copilot'),
      ];
      bottomNavIndices = [0, 1, 2, 6];
    } else if (isHrManager) {
      bottomNavItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Employees'),
        BottomNavigationBarItem(icon: Icon(Icons.fingerprint), label: 'Attendance'),
        BottomNavigationBarItem(icon: Icon(Icons.flight_takeoff), label: 'Time Off'),
        BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: 'Contracts'),
        BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: 'Copilot'),
      ];
      bottomNavIndices = [0, 7, 1, 2, 3, 6];
    } else {
      bottomNavItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        BottomNavigationBarItem(icon: Icon(Icons.fingerprint), label: 'Attendance'),
        BottomNavigationBarItem(icon: Icon(Icons.flight_takeoff), label: 'Time Off'),
        BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: 'Contracts'),
        BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), label: 'Payrun'),
        BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: 'Copilot'),
      ];
      bottomNavIndices = [0, 1, 2, 3, 4, 6];
    }

    int currentBottomNavIndex = bottomNavIndices.indexOf(_currentIndex);
    if (currentBottomNavIndex == -1) currentBottomNavIndex = 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _currentIndex != 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Previous Screen',
                  onPressed: _handleBack,
                )
              : null,
          title: Row(
            children: [
              if (_currentIndex == 0) ...[
                const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 8),
              ],
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
            if (hasHr)
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Staff Directory Search',
                onPressed: () {
                  StaffSearchDialog.show(
                    context,
                    onSelectEmployee: (emp) {
                      MockDataService.switchActiveUser(emp);
                      EmployeeService.currentEmployeeNotifier.value = emp;
                      _onTabSelected(0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Switched Active Profile: ${emp.name} (${emp.jobTitle})')),
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
                    ValueListenableBuilder<EmployeeModel>(
                      valueListenable: EmployeeService.currentEmployeeNotifier,
                      builder: (context, activeEmp, _) {
                        final displayName = ApiClient.currentEmployeeName ?? activeEmp.name;
                        final displayEmail = ApiClient.currentEmail ?? activeEmp.email;
                        final initials = displayName.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join();
                        return UserAccountsDrawerHeader(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.odooAubergine, Color(0xFF57344F)],
                            ),
                          ),
                          accountName: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          accountEmail: Text('$displayEmail • ${widget.userRole}'),
                          currentAccountPicture: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Text(
                              initials.isNotEmpty ? initials : 'U',
                              style: const TextStyle(
                                color: AppTheme.odooAubergine,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_outline, color: AppTheme.odooAubergine),
                      title: Text(isEmployee ? 'My Profile & Info' : 'My Profile & Dashboard'),
                      selected: _currentIndex == 0,
                      onTap: () { Navigator.pop(context); _onTabSelected(0); },
                    ),
                    ListTile(
                      leading: const Icon(Icons.fingerprint, color: AppTheme.odooAubergine),
                      title: Text(isEmployee ? 'My Attendance' : 'Attendance Ledger'),
                      selected: _currentIndex == 1,
                      onTap: () { Navigator.pop(context); _onTabSelected(1); },
                    ),
                    ListTile(
                      leading: const Icon(Icons.flight_takeoff, color: AppTheme.odooAubergine),
                      title: Text(isEmployee ? 'My Time Off' : 'Time Off & Allocations'),
                      selected: _currentIndex == 2,
                      onTap: () { Navigator.pop(context); _onTabSelected(2); },
                    ),
                    if (hasHr)
                      ListTile(
                        leading: const Icon(Icons.description_outlined, color: AppTheme.odooAubergine),
                        title: const Text('Contracts & AST Rules'),
                        selected: _currentIndex == 3,
                        onTap: () { Navigator.pop(context); _onTabSelected(3); },
                      ),
                    if (hasPayroll)
                      ListTile(
                        leading: const Icon(Icons.payments_outlined, color: AppTheme.odooAubergine),
                        title: const Text('2-Step Payrun Wizard'),
                        selected: _currentIndex == 4,
                        onTap: () { Navigator.pop(context); _onTabSelected(4); },
                      ),
                    if (hasHr || hasPayroll)
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

                    // Configuration Section (Only for HR, Payroll, Admin)
                    if (hasHr || hasPayroll || isAdmin) ...[
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                        child: Text('CONFIGURATION & SETUP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      if (hasHr)
                        ListTile(
                          leading: const Icon(Icons.people_alt_outlined, color: AppTheme.odooAubergine),
                          title: const Text('Employee Master Data'),
                          selected: _currentIndex == 7,
                          onTap: () { Navigator.pop(context); _onTabSelected(7); },
                        ),
                      if (hasHr)
                        ListTile(
                          leading: const Icon(Icons.schedule_rounded, color: AppTheme.odooAubergine),
                          title: const Text('Working Schedules'),
                          selected: _currentIndex == 8,
                          onTap: () { Navigator.pop(context); _onTabSelected(8); },
                        ),
                      if (hasHr)
                        ListTile(
                          leading: const Icon(Icons.beach_access_rounded, color: AppTheme.odooAubergine),
                          title: const Text('Time Off Types & Alloc'),
                          selected: _currentIndex == 9,
                          onTap: () { Navigator.pop(context); _onTabSelected(9); },
                        ),
                      if (hasPayroll)
                        ListTile(
                          leading: const Icon(Icons.settings_suggest_outlined, color: AppTheme.odooAubergine),
                          title: Row(
                            children: [
                              const Text('Payroll Rules & Structure'),
                              if (ApiClient.activeRole == 'HR_PAYROLL_USER') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: Text('Read-Only', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                                ),
                              ],
                            ],
                          ),
                          selected: _currentIndex == 10,
                          onTap: () { Navigator.pop(context); _onTabSelected(10); },
                        ),
                      if (isAdmin)
                        ListTile(
                          leading: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.odooAubergine),
                          title: const Text('User Management (RBAC)'),
                          selected: _currentIndex == 11,
                          onTap: () { Navigator.pop(context); _onTabSelected(11); },
                        ),
                    ],

                    if (hasHr) ...[
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.search_rounded),
                        title: const Text('Staff Directory Search'),
                        onTap: () {
                          Navigator.pop(context);
                          StaffSearchDialog.show(
                            context,
                            onSelectEmployee: (emp) {
                              MockDataService.switchActiveUser(emp);
                              EmployeeService.currentEmployeeNotifier.value = emp;
                              _onTabSelected(0);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Switched Active Profile: ${emp.name} (${emp.jobTitle})')),
                              );
                            },
                          );
                        },
                      ),
                    ],
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
          currentIndex: currentBottomNavIndex,
          onTap: (navIndex) {
            final targetTab = bottomNavIndices[navIndex];
            _onTabSelected(targetTab);
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.odooAubergine,
          unselectedItemColor: Colors.grey.shade600,
          items: bottomNavItems,
        ),
      ),
    );
  }
}
