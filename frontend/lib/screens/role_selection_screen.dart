import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_logo.dart';
import 'auth_login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const List<Map<String, dynamic>> demoRoles = [
    {
      'role': 'Admin',
      'label': 'SysAdmin (Root)',
      'icon': Icons.admin_panel_settings_outlined,
      'badge': 'admin@oxp.com',
      'desc': 'Full System Access & Audit Logs',
      'email': 'admin@oxp.com',
      'systemRole': 'ADMIN',
      'accentColor': Color(0xFF714B67),
      'avatarBg': Color(0xFFFFD7F1),
      'avatarText': Color(0xFF57344F),
    },
    {
      'role': 'HR Manager',
      'label': 'HR Manager',
      'icon': Icons.groups_outlined,
      'badge': 'Sara Khan • HR Lead',
      'desc': 'Employee Directory & Approvals',
      'email': 'sara.khan@oxp.com',
      'systemRole': 'HR_MANAGER',
      'accentColor': Color(0xFF00696E),
      'avatarBg': Color(0xFF92EFF5),
      'avatarText': Color(0xFF004F53),
    },
    {
      'role': 'HR Payroll Mgr',
      'label': 'HR Payroll Manager',
      'icon': Icons.account_balance_wallet_outlined,
      'badge': 'Vikram Nair • Finance Lead',
      'desc': 'Salary Rules, Batches & Payroll Config',
      'email': 'vikram.nair@oxp.com',
      'systemRole': 'HR_PAYROLL_MANAGER',
      'accentColor': Color(0xFF006443),
      'avatarBg': Color(0xFFB9F3D2),
      'avatarText': Color(0xFF004A31),
    },
    {
      'role': 'Payroll User',
      'label': 'Payroll User',
      'icon': Icons.receipt_long_outlined,
      'badge': 'Aarav Mehta • Payroll Specialist',
      'desc': 'Payslip Viewing & Payment Execution',
      'email': 'aarav.mehta@oxp.com',
      'systemRole': 'HR_PAYROLL_USER',
      'accentColor': Color(0xFF2E5BFF),
      'avatarBg': Color(0xFFDAE2FD),
      'avatarText': Color(0xFF131B2E),
    },
    {
      'role': 'Employee',
      'label': 'Employee Self-Service',
      'icon': Icons.badge_outlined,
      'badge': 'Rohan Desai • Engineering',
      'desc': 'Attendance Punch, Leaves & Own Payslips',
      'email': 'rohan.desai@oxp.com',
      'systemRole': 'EMPLOYEE',
      'accentColor': Color(0xFFD97706),
      'avatarBg': Color(0xFFFEF3C7),
      'avatarText': Color(0xFF92400E),
    },
  ];

  void _onRoleSelected(BuildContext context, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AuthLoginScreen(initialRoleIndex: index),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Aubergine Header Bar with App Logo
            _buildTopHeaderBar(context),

            // Main Body: Role Cards List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  Text(
                    'Select Role to Proceed',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap any demo workspace role below to proceed to the Sign In screen.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5 Role Cards
                  ...demoRoles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final role = entry.value;
                    return _buildRoleCard(context, index, role);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeaderBar(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF714B67),
            Color(0xFF4A2E43),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33714B67),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Navigation Row with App Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const AppLogoIcon(size: 28),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PeoplePay360',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                'ENTERPRISE HR & PAYROLL • ODOO 18',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.jetBrainsMono(
                                  color: const Color(0xFFF0BFE0),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4EDEA3),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PROD',
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Title & Subtitle
              Text(
                'Welcome Back',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Choose a demo role to sign in to your workspace.',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF0BFE0),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, int index, Map<String, dynamic> role) {
    final IconData iconData = role['icon'] as IconData;
    final String label = role['label'] as String;
    final String badge = role['badge'] as String;
    final String desc = role['desc'] as String;
    final Color avatarBg = role['avatarBg'] as Color;
    final Color avatarText = role['avatarText'] as Color;
    final Color accentColor = role['accentColor'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _onRoleSelected(context, index),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Role Icon Container
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(iconData, color: avatarText, size: 24),
                  ),
                ),
                const SizedBox(width: 14),

                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF131B2E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role['role'] as String,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00696E),
                        ),
                      ),
                      Text(
                        desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right Arrow
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF714B67)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
