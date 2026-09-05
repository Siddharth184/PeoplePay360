import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/notifications_drawer.dart';
import '../services/notification_service.dart';
import '../widgets/staff_search_dialog.dart';
import '../services/api_client.dart';
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

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'My Profile';
      case 1:
        return 'Attendance Ledger';
      case 2:
        return 'Time Off & Allocations';
      case 3:
        return 'Contracts & AST Rules';
      case 4:
        return '2-Step Payrun Wizard';
      case 5:
        return 'HR Cost Analytics';
      case 6:
        return 'AI HR Copilot';
      case 7:
        return 'Workforce Directory';
      case 8:
        return 'Working Schedules';
      case 9:
        return 'Time Off Setup & Rules';
      case 10:
        return 'Payroll Rules & Structure';
      case 11:
        return 'User Management & RBAC';
      default:
        return 'PeoplePay 360';
    }
  }

  @override
  void initState() {
    super.initState();
    if (ApiClient.isRoleHrManager) {
      _currentIndex = 7;
      _tabHistory[0] = 7;
    }
  }

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

    // Build enriched navigation bar items based on role
    List<_NavItem> enrichedNavItems;
    if (isEmployee) {
      enrichedNavItems = const [
        _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'My Profile', targetIndex: 0),
        _NavItem(icon: Icons.fingerprint, activeIcon: Icons.fingerprint, label: 'Attendance', targetIndex: 1),
        _NavItem(icon: Icons.flight_takeoff, activeIcon: Icons.flight_takeoff, label: 'Time Off', targetIndex: 2),
        _NavItem(icon: Icons.smart_toy_outlined, activeIcon: Icons.smart_toy, label: 'Copilot', targetIndex: 6),
      ];
    } else if (isHrManager) {
      enrichedNavItems = const [
        _NavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Employees', targetIndex: 7),
        _NavItem(icon: Icons.fingerprint, activeIcon: Icons.fingerprint, label: 'Attendance', targetIndex: 1),
        _NavItem(icon: Icons.flight_takeoff, activeIcon: Icons.flight_takeoff, label: 'Time Off', targetIndex: 2),
        _NavItem(icon: Icons.smart_toy_outlined, activeIcon: Icons.smart_toy, label: 'Copilot', targetIndex: 6),
      ];
    } else {
      enrichedNavItems = const [
        _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', targetIndex: 0),
        _NavItem(icon: Icons.fingerprint, activeIcon: Icons.fingerprint, label: 'Attendance', targetIndex: 1),
        _NavItem(icon: Icons.flight_takeoff, activeIcon: Icons.flight_takeoff, label: 'Time Off', targetIndex: 2),
        _NavItem(icon: Icons.description_outlined, activeIcon: Icons.description, label: 'Contracts', targetIndex: 3),
        _NavItem(icon: Icons.payments_outlined, activeIcon: Icons.payments, label: 'Payrun', targetIndex: 4),
        _NavItem(icon: Icons.smart_toy_outlined, activeIcon: Icons.smart_toy, label: 'Copilot', targetIndex: 6),
      ];
    }

    final bottomNavIndices = enrichedNavItems.map((e) => e.targetIndex).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  tooltip: 'Back',
                  onPressed: _handleBack,
                )
              : null,
          title: Text(
            _getTabTitle(_currentIndex),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: NotificationService.notificationsNotifier,
              builder: (context, notifications, _) {
                final unreadCount = notifications.where((n) => n['isUnread'] == true).length;
                return IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined),
                      if (unreadCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: const BoxDecoration(
                              color: AppTheme.odooTeal,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'HR Notifications Inbox',
                  onPressed: () {
                    NotificationsDrawer.show(context, onNavigateTab: _onTabSelected);
                  },
                );
              },
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
          surfaceTintColor: Colors.transparent,
          child: Column(
            children: [
              _buildDrawerHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    ...(() {
                      bool isPinned(int idx) => bottomNavIndices.contains(idx);

                      final modules = <Widget>[];

                      if (!isPinned(0)) {
                        modules.add(
                          _buildDrawerTile(
                            context: context,
                            icon: Icons.person_outline_rounded,
                            title: isEmployee ? 'My Profile & Info' : 'My Profile & Dashboard',
                            accentColor: const Color(0xFF38BDF8),
                            isSelected: _currentIndex == 0,
                            onTap: () {
                              Navigator.pop(context);
                              _onTabSelected(0);
                            },
                          ),
                        );
                      }
                      if (!isPinned(1)) {
                        modules.add(
                          _buildDrawerTile(
                            context: context,
                            icon: Icons.fingerprint_rounded,
                            title: isEmployee ? 'My Attendance' : 'Attendance Ledger',
                            accentColor: const Color(0xFF34D399),
                            isSelected: _currentIndex == 1,
                            onTap: () {
                              Navigator.pop(context);
                              _onTabSelected(1);
                            },
                          ),
                        );
                      }
                      if (!isPinned(2)) {
                        modules.add(
                          _buildDrawerTile(
                            context: context,
                            icon: Icons.flight_takeoff_rounded,
                            title: isEmployee ? 'My Time Off' : 'Time Off & Allocations',
                            accentColor: const Color(0xFFFBBF24),
                            isSelected: _currentIndex == 2,
                            onTap: () {
                              Navigator.pop(context);
                              _onTabSelected(2);
                            },
                          ),
                        );
                      }
                      if (!isPinned(3) && hasHr) {
                        modules.add(
                          _buildDrawerTile(
                            context: context,
                            icon: Icons.description_outlined,
                            title: 'Contracts & AST Rules',
                            accentColor: const Color(0xFF818CF8),
                            isSelected: _currentIndex == 3,
                            onTap: () {
                              Navigator.pop(context);
                              _onTabSelected(3);
                            },
                          ),
                        );
                      }
                      if (!isPinned(4) && hasPayroll) {
                        modules.add(
                          _buildDrawerTile(
                            context: context,
                            icon: Icons.payments_outlined,
                            title: '2-Step Payrun Wizard',
                            accentColor: const Color(0xFFA78BFA),
                            isSelected: _currentIndex == 4,
                            onTap: () {
                              Navigator.pop(context);
                              _onTabSelected(4);
                            },
                          ),
                        );
                      }
                      if (!isPinned(5) && (hasHr || hasPayroll)) {
                        modules.add(
                          _buildDrawerTile(
                            context: context,
                            icon: Icons.bar_chart_rounded,
                            title: 'HR Cost Analytics',
                            accentColor: const Color(0xFF2DD4BF),
                            isSelected: _currentIndex == 5,
                            onTap: () {
                              Navigator.pop(context);
                              _onTabSelected(5);
                            },
                          ),
                        );
                      }
                      if (!isPinned(6)) {
                        modules.add(
                          _buildDrawerTile(
                            context: context,
                            icon: Icons.smart_toy_rounded,
                            title: 'AI HR Copilot (RAG)',
                            accentColor: const Color(0xFFF472B6),
                            badgeText: 'AI',
                            badgeColor: const Color(0xFFEC4899),
                            isSelected: _currentIndex == 6,
                            onTap: () {
                              Navigator.pop(context);
                              _onTabSelected(6);
                            },
                          ),
                        );
                      }

                      final configs = <Widget>[];

                      if (!isPinned(7) && hasHr) {
                        configs.add(
                          _buildDrawerTile(
                            context: context,
                            icon: Icons.people_alt_outlined,
                            title: 'Employee Master Data',
                            accentColor: const Color(0xFF60A5FA),
                            isSelected: _currentIndex == 7,
                            onTap: () {
                              Navigator.pop(context);
                              _onTabSelected(7);
                            },
                          ),
                        );
                      }
                      if (!isPinned(8) && hasHr) {
                        configs.add(
                          _buildDrawerTile(
                            context: context,
                            icon: Icons.schedule_rounded,
                            title: 'Working Schedules',
                            accentColor: const Color(0xFFC084FC),
                            isSelected: _currentIndex == 8,
                            onTap: () {
                              Navigator.pop(context);
                              _onTabSelected(8);
                            },
                          ),
                        );
                      }
                      if (!isPinned(9) && hasHr) {
                        configs.add(
                          _buildDrawerTile(
                            context: context,
                            icon: Icons.beach_access_rounded,
                            title: 'Time Off Types & Alloc',
                            accentColor: const Color(0xFFFB923C),
                            isSelected: _currentIndex == 9,
                            onTap: () {
                              Navigator.pop(context);
                              _onTabSelected(9);
                            },
                          ),
                        );
                      }
                      if (!isPinned(10) && hasPayroll) {
                        configs.add(
                          _buildDrawerTile(
                            context: context,
                            icon: Icons.settings_suggest_outlined,
                            title: 'Payroll Rules & Structure',
                            accentColor: const Color(0xFFFB7185),
                            badgeText: ApiClient.activeRole == 'HR_PAYROLL_USER' ? 'Read-Only' : null,
                            badgeColor: ApiClient.activeRole == 'HR_PAYROLL_USER' ? Colors.amber.shade700 : null,
                            isSelected: _currentIndex == 10,
                            onTap: () {
                              Navigator.pop(context);
                              _onTabSelected(10);
                            },
                          ),
                        );
                      }
                      if (!isPinned(11) && isAdmin) {
                        configs.add(
                          _buildDrawerTile(
                            context: context,
                            icon: Icons.admin_panel_settings_outlined,
                            title: 'User Management (RBAC)',
                            accentColor: const Color(0xFFF87171),
                            isSelected: _currentIndex == 11,
                            onTap: () {
                              Navigator.pop(context);
                              _onTabSelected(11);
                            },
                          ),
                        );
                      }

                      final resultList = <Widget>[];

                      if (modules.isNotEmpty) {
                        resultList.add(_buildDrawerCategoryHeader('CORE MODULES', const Color(0xFF38BDF8)));
                        resultList.addAll(modules);
                      }

                      if (configs.isNotEmpty) {
                        resultList.add(_buildDrawerCategoryHeader('CONFIGURATION & SETUP', const Color(0xFFC084FC)));
                        resultList.addAll(configs);
                      }

                      return resultList;
                    })(),

                    if (hasHr) ...[
                      _buildDrawerCategoryHeader('DIRECTORY & SEARCH', const Color(0xFF34D399)),
                      _buildDrawerTile(
                        context: context,
                        icon: Icons.search_rounded,
                        title: 'Staff Directory Search',
                        accentColor: const Color(0xFF38BDF8),
                        isSelected: false,
                        onTap: () {
                          Navigator.pop(context);
                          StaffSearchDialog.show(
                            context,
                            onSelectEmployee: (emp) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EmployeeProfileScreen(initialEmployee: emp),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
                ),
              ),
              const SizedBox(height: 6),
              _buildDrawerTile(
                context: context,
                icon: Icons.logout_rounded,
                title: 'Logout Session',
                accentColor: const Color(0xFFEF4444),
                isSelected: false,
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
        bottomNavigationBar: _buildEnrichedNavBar(
          items: enrichedNavItems,
          currentIndex: _currentIndex,
          onSelect: _onTabSelected,
        ),
      ),
    );
  }

  Widget _buildEnrichedNavBar({
    required List<_NavItem> items,
    required int currentIndex,
    required Function(int) onSelect,
  }) {
    // Determine active index in items list. If currentIndex is not in items, activeIdx is -1 (no item highlighted!)
    final activeIdx = items.indexWhere((item) => item.targetIndex == currentIndex);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131722),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(color: Color(0xFF252C3D), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isSelected = (i == activeIdx);

              return Expanded(
                child: InkWell(
                  onTap: () => onSelect(item.targetIndex),
                  borderRadius: BorderRadius.circular(16),
                  splashColor: const Color(0xFF714B67).withValues(alpha: 0.2),
                  highlightColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: isSelected
                        ? BoxDecoration(
                            color: const Color(0xFF714B67).withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF714B67).withValues(alpha: 0.5),
                              width: 1,
                            ),
                          )
                        : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected ? const Color(0xFF4EDEA3) : const Color(0xFF94A3B8),
                          size: isSelected ? 22 : 20,
                        ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: isSelected ? 11 : 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return ValueListenableBuilder<EmployeeModel>(
      valueListenable: EmployeeService.currentEmployeeNotifier,
      builder: (context, activeEmp, _) {
        final displayName = ApiClient.currentEmployeeName ?? activeEmp.name;
        final displayEmail = ApiClient.currentEmail ?? activeEmp.email;
        final initials = displayName
            .split(' ')
            .where((e) => e.isNotEmpty)
            .map((e) => e[0])
            .take(2)
            .join();
        final role = widget.userRole.toUpperCase();

        return Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            bottom: 22,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2C1929), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA27B99), Color(0xFF38BDF8)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF714B67).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF1E293B),
                      child: Text(
                        initials.isNotEmpty ? initials : 'U',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF714B67).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFA27B99).withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            role,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFF1F5F9),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      displayEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerCategoryHeader(String title, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFF334155).withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailing,
    String? badgeText,
    Color? badgeColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final selectedBg = isDark
        ? accentColor.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.12);
    final activeBorderColor = accentColor.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeBorderColor : Colors.transparent,
            width: 1,
          ),
          boxShadow: isSelected && isDark
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isSelected ? accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.25)
                          : accentColor.withValues(alpha: isDark ? 0.14 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? (isDark ? Colors.white : accentColor)
                          : accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? (isDark ? Colors.white : accentColor)
                            : baseTextColor,
                      ),
                    ),
                  ),
                  if (badgeText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor ?? accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: badgeColor != null ? Colors.white : accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (trailing != null) trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int targetIndex;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.targetIndex,
  });
}
