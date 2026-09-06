import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../widgets/app_logo.dart';
import 'home_navigation_screen.dart';
import 'role_selection_screen.dart';

class AuthLoginScreen extends StatefulWidget {
  final int initialRoleIndex;
  const AuthLoginScreen({super.key, this.initialRoleIndex = 0});

  @override
  State<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends State<AuthLoginScreen> {
  // Backend Seeded Role Models
  final List<Map<String, dynamic>> _demoRoles = [
    {
      'role': 'Admin',
      'label': 'Admin',
      'icon': Icons.admin_panel_settings_outlined,
      'badge': 'admin@oxp.com • Full Access',
      'desc': 'Full System Access',
      'email': 'admin@oxp.com',
      'pass': 'PeoplePay@360',
      'systemRole': 'ADMIN',
    },
    {
      'role': 'HR Manager',
      'label': 'HR Manager',
      'icon': Icons.groups_outlined,
      'badge': 'Sara Khan • HR Lead',
      'desc': 'Sara Khan • HR Lead',
      'email': 'sara.khan@oxp.com',
      'pass': 'PeoplePay@360',
      'systemRole': 'HR_MANAGER',
    },
    {
      'role': 'HR Payroll Mgr',
      'label': 'HR Payroll Mgr',
      'icon': Icons.account_balance_wallet_outlined,
      'badge': 'Vikram Nair • Finance Lead',
      'desc': 'Vikram Nair • Finance Lead',
      'email': 'vikram.nair@oxp.com',
      'pass': 'PeoplePay@360',
      'systemRole': 'HR_PAYROLL_MANAGER',
    },
    {
      'role': 'Payroll User',
      'label': 'Payroll User',
      'icon': Icons.receipt_long_outlined,
      'badge': 'Aarav Mehta • Payroll',
      'desc': 'Aarav Mehta • Payroll',
      'email': 'aarav.mehta@oxp.com',
      'pass': 'PeoplePay@360',
      'systemRole': 'HR_PAYROLL_USER',
    },
    {
      'role': 'Employee',
      'label': 'Employee',
      'icon': Icons.badge_outlined,
      'badge': 'Rohan Desai • Engineering',
      'desc': 'Rohan Desai • Eng',
      'email': 'rohan.desai@oxp.com',
      'pass': 'PeoplePay@360',
      'systemRole': 'EMPLOYEE',
    },
  ];

  int _selectedRoleIndex = 0;
  bool _obscurePassword = true;
  bool _keepMeSignedIn = true;
  bool _isAuthenticating = false;
  bool _isAuthenticated = false;

  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  String _currentRoleBadge = 'Role: SysAdmin';
  String? _notificationText;

  @override
  void initState() {
    super.initState();
    _selectedRoleIndex = widget.initialRoleIndex.clamp(0, _demoRoles.length - 1);
    final selectedRole = _demoRoles[_selectedRoleIndex];
    _emailController = TextEditingController(text: selectedRole['email']);
    _passwordController = TextEditingController(
      text: AuthService.getKnownPassword(selectedRole['email']!),
    );
    _currentRoleBadge = 'Role: ${selectedRole['role']}';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectRole(int index) {
    setState(() {
      _selectedRoleIndex = index;
      final item = _demoRoles[index];
      _emailController.text = item['email']!;
      _passwordController.text = AuthService.getKnownPassword(item['email']!);
      _currentRoleBadge = 'Role: ${item['role']}';
      _notificationText = 'Loaded demo credentials: ${item['badge']}';
    });

    // Auto-dismiss notification toast
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _notificationText = null;
        });
      }
    });
  }

  Future<void> _handleSignIn() async {
    if (_isAuthenticating || _isAuthenticated) return;

    setState(() {
      _isAuthenticating = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final response = await AuthService.login(email: email, password: password);

    if (!mounted) return;

    if (response.isSuccess) {
      setState(() {
        _isAuthenticating = false;
        _isAuthenticated = true;
      });

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final targetRole = ApiClient.currentUserRole ?? _demoRoles[_selectedRoleIndex]['systemRole'] ?? 'ADMIN';
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeNavigationScreen(userRole: targetRole),
        ),
      );
    } else {
      setState(() {
        _isAuthenticating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            response.errorMessage ?? 'Authentication failed. Check your credentials.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }



  void _openForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    int step = 1; // 1 = verify previous password, 2 = set new password
    bool isBusy = false;
    String? localError;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    void showResultSnack(BuildContext c, String message, {required bool ok}) {
      ScaffoldMessenger.of(c).showSnackBar(
        SnackBar(
          backgroundColor: ok ? const Color(0xFF004A31) : const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.error_outline,
                  color: ok ? const Color(0xFF6FFBBE) : Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            InputDecoration fieldDecoration(IconData icon, String hint, {Widget? suffix}) {
              return InputDecoration(
                prefixIcon: Icon(icon, color: const Color(0xFF00696E), size: 20),
                suffixIcon: suffix,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                hintText: hint,
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: Colors.grey),
              );
            }

            Widget fieldBox(Widget child) {
              return Container(
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(12),
                  border: localError != null
                      ? Border.all(color: const Color(0xFFBA1A1A).withValues(alpha: 0.5))
                      : Border.all(color: const Color(0xFFDAE2FD)),
                ),
                child: child,
              );
            }

            final textStyle = GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF131B2E),
              fontWeight: FontWeight.w500,
            );

            Future<void> onVerify() async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                setSheetState(() => localError = 'Please enter a valid work email address.');
                return;
              }
              if (currentPassCtrl.text.isEmpty) {
                setSheetState(() => localError = 'Please enter your previous (current) password.');
                return;
              }
              setSheetState(() {
                isBusy = true;
                localError = null;
              });
              final res = await AuthService.verifyCurrentPassword(
                email: email,
                password: currentPassCtrl.text,
              );
              if (!ctx.mounted) return;
              setSheetState(() {
                isBusy = false;
                if (res.isSuccess) {
                  step = 2;
                  localError = null;
                } else {
                  localError = res.errorMessage ?? 'Previous password does not match our records.';
                }
              });
            }

            Future<void> onSave() async {
              final newPass = newPassCtrl.text;
              if (newPass.length < 6) {
                setSheetState(() => localError = 'New password must be at least 6 characters.');
                return;
              }
              if (newPass != confirmPassCtrl.text) {
                setSheetState(() => localError = 'The new passwords do not match.');
                return;
              }
              if (newPass == currentPassCtrl.text) {
                setSheetState(() => localError = 'New password must differ from your previous password.');
                return;
              }
              setSheetState(() {
                isBusy = true;
                localError = null;
              });
              final res = await AuthService.resetPassword(
                email: emailCtrl.text.trim(),
                currentPassword: currentPassCtrl.text,
                newPassword: newPass,
              );
              if (!ctx.mounted) return;
              if (res.isSuccess) {
                Navigator.pop(ctx);
                if (mounted) {
                  setState(() {
                    _emailController.text = emailCtrl.text.trim();
                    _passwordController.text = newPass;
                  });
                }
                showResultSnack(
                  context,
                  '✓ Password reset successfully! You can now sign in with your new password.',
                  ok: true,
                );
              } else {
                setSheetState(() {
                  isBusy = false;
                  localError = res.errorMessage ?? 'Unable to update password. Please try again.';
                  if (res.statusCode == 400 || res.statusCode == 401) step = 1;
                });
              }
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: step == 1 ? const Color(0xFFFFD7F1) : const Color(0xFF92EFF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              step == 1 ? Icons.lock_reset : Icons.verified_user_outlined,
                              color: step == 1 ? const Color(0xFF714B67) : const Color(0xFF00696E),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step == 1 ? 'Verify Previous Password' : 'Set New Password',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF131B2E),
                                ),
                              ),
                              Text(
                                step == 1 ? 'Step 1 of 2 • Identity Verification' : 'Step 2 of 2 • Update Password',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  color: const Color(0xFF00696E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF4E444A)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (step == 1) ...[
                    Text(
                      'Enter your work email and previous password. If they match, you will be allowed to set a new password.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: const Color(0xFF4E444A),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    fieldBox(TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: textStyle,
                      decoration: fieldDecoration(Icons.mail_outline, 'Work email address (e.g. admin@oxp.com)'),
                    )),
                    fieldBox(TextField(
                      controller: currentPassCtrl,
                      obscureText: obscureCurrent,
                      style: textStyle,
                      onSubmitted: (_) => onVerify(),
                      decoration: fieldDecoration(
                        Icons.lock_outline,
                        'Enter previous password',
                        suffix: IconButton(
                          icon: Icon(
                            obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF80747A),
                            size: 19,
                          ),
                          onPressed: () => setSheetState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    )),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6FFBBE).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00696E).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF004A31), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Previous password matched! Enter your new password below.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF004A31),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    fieldBox(TextField(
                      controller: newPassCtrl,
                      obscureText: obscureNew,
                      style: textStyle,
                      decoration: fieldDecoration(
                        Icons.lock_reset_outlined,
                        'New password (min 6 characters)',
                        suffix: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF80747A),
                            size: 19,
                          ),
                          onPressed: () => setSheetState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    )),
                    fieldBox(TextField(
                      controller: confirmPassCtrl,
                      obscureText: obscureConfirm,
                      style: textStyle,
                      onSubmitted: (_) => onSave(),
                      decoration: fieldDecoration(
                        Icons.lock_outline,
                        'Confirm new password',
                        suffix: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF80747A),
                            size: 19,
                          ),
                          onPressed: () => setSheetState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    )),
                  ],

                  if (localError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDAD6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFBA1A1A), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              localError!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFBA1A1A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF714B67),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      onPressed: isBusy ? null : (step == 1 ? onVerify : onSave),
                      child: isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              step == 1 ? 'Verify Previous Password →' : 'Save New Password & Continue',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  if (step == 2) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: isBusy
                            ? null
                            : () => setSheetState(() {
                                  step = 1;
                                  localError = null;
                                }),
                        child: Text(
                          '← Back to Previous Password',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF714B67),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // TOP AUBERGINE GRADIENT HEADER
            _buildAubergineHeader(),

            // CENTER ELEVATED FLOATING GLASS CARD
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSignInCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAubergineHeader() {
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
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 38),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back to Role Selection Button
              GestureDetector(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Change Role',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Top Bar with Brand & Cluster status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // App Icon with Cyan badge
                        Stack(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Center(
                                child: AppLogoIcon(size: 26),
                              ),
                            ),
                            Positioned(
                              right: -1,
                              bottom: -1,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF92EFF5),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF714B67),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                                  fontSize: 19,
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
                  // PROD-US1 Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
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
              const SizedBox(height: 24),
              // Headlines
              Text(
                'Welcome Back',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Sign in to continue to your workspace.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A714B67),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Work Email row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Work Email',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6FFBBE).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 13, color: Color(0xFF004A31)),
                    const SizedBox(width: 4),
                    Text(
                      'Verified Domain',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF004A31),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Email input
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _emailController,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.mail_outline, color: Color(0xFF00696E), size: 19),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Password row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Flexible(
                child: Text(
                  _currentRoleBadge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00696E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Password input
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
                letterSpacing: _obscurePassword ? 2.0 : 0.0,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00696E), size: 19),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: const Color(0xFF80747A),
                    size: 19,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Keep me signed in & Forgot Password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _keepMeSignedIn = !_keepMeSignedIn;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _keepMeSignedIn,
                        activeColor: const Color(0xFF714B67),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) {
                          setState(() {
                            _keepMeSignedIn = val ?? true;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Keep me signed in',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF4E444A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _openForgotPasswordDialog,
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF714B67),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Sign In to Workspace Primary Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAuthenticated
                    ? const Color(0xFF006443)
                    : const Color(0xFF714B67),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 4,
                shadowColor: const Color(0x40714B67),
              ),
              onPressed: _handleSignIn,
              child: _isAuthenticating
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Authenticating...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : _isAuthenticated
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Authenticated!',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Sign In to Workspace',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
            ),
          ),


        ],
      ),
    );
  }

  Widget _buildQuickDemoRolesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A714B67),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD7F1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.bolt, color: Color(0xFF714B67), size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Demo Roles',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                    Text(
                      'Tap a role card to pre-fill credentials',
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
            ],
          ),
          const SizedBox(height: 14),

          // 2x2 Grid of 4 Roles (Admin, HR Manager, Payroll User, Employee)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _demoRoles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.85,
            ),
            itemBuilder: (context, index) {
              final item = _demoRoles[index];
              final isSelected = _selectedRoleIndex == index;

              return InkWell(
                onTap: () => _selectRole(index),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFD7F1) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF714B67)
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: const Color(0xFF714B67).withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  size: 16,
                                  color: isSelected ? const Color(0xFF714B67) : const Color(0xFF00696E),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    item['label'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? const Color(0xFF2F1029)
                                          : const Color(0xFF131B2E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Color(0xFF714B67),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 11,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['desc'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF57344F)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Notification Banner
          if (_notificationText != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF92EFF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.swap_horiz, size: 16, color: Color(0xFF006E73)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _notificationText!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF006E73),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'READY',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF006E73),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
