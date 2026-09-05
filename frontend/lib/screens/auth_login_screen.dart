import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import 'home_navigation_screen.dart';

class AuthLoginScreen extends StatefulWidget {
  const AuthLoginScreen({super.key});

  @override
  State<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends State<AuthLoginScreen> {
  // Backend Seeded Role Models
  final List<Map<String, String>> _demoRoles = [
    {
      'role': 'Admin',
      'label': '★ Admin',
      'badge': 'admin@oxp.com • Full Access',
      'email': 'admin@oxp.com',
      'pass': 'PeoplePay@360',
      'systemRole': 'ADMIN',
    },
    {
      'role': 'HR Manager',
      'label': 'HR Manager',
      'badge': 'Sara Khan • HR Lead',
      'email': 'sara.khan@oxp.com',
      'pass': 'PeoplePay@360',
      'systemRole': 'HR_MANAGER',
    },
    {
      'role': 'Payroll Mgr',
      'label': 'Payroll Mgr',
      'badge': 'Vikram Nair • Finance Lead',
      'email': 'vikram.nair@oxp.com',
      'pass': 'PeoplePay@360',
      'systemRole': 'HR_PAYROLL_MANAGER',
    },
    {
      'role': 'Payroll User',
      'label': 'Payroll User',
      'badge': 'Aarav Mehta • Comp & Payroll',
      'email': 'aarav.mehta@oxp.com',
      'pass': 'PeoplePay@360',
      'systemRole': 'HR_PAYROLL_USER',
    },
    {
      'role': 'Employee',
      'label': 'Employee',
      'badge': 'Rohan Desai • Engineering',
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
  bool _isScanningFaceId = false;

  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  String _currentRoleBadge = 'Role: SysAdmin';
  String? _notificationText;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: _demoRoles[0]['email']);
    _passwordController = TextEditingController(text: _demoRoles[0]['pass']);
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
      _passwordController.text = item['pass']!;
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

  Future<void> _handleFaceId() async {
    if (_isScanningFaceId) return;

    setState(() {
      _isScanningFaceId = true;
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF004A31),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF6FFBBE)),
            const SizedBox(width: 8),
            Text(
              'Face ID Confirmed • Logging in...',
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final targetRole = _demoRoles[_selectedRoleIndex]['systemRole'] ?? 'ADMIN';
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeNavigationScreen(userRole: targetRole),
      ),
    );
  }

  void _openForgotPasswordDialog() {
    final resetEmailCtrl = TextEditingController(text: _emailController.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  Text(
                    'Reset Password',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF4E444A)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your verified company work email. We will send an encrypted Odoo password reset link to verify your identity.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF4E444A),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: resetEmailCtrl,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF131B2E),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF00696E), size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: 'name@enterprise.odoo.com',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF004A31),
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          '✉️ Reset instructions dispatched to ${resetEmailCtrl.text}',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Send Reset Link',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
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

            // QUICK ROLE DEMO SWITCHER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildQuickDemoRolesSection(),
            ),

            // LEGAL FOOTER
            _buildFooter(),
            const SizedBox(height: 28),
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
              // Top Bar with Brand & Cluster status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // App Icon with Cyan badge
                      Stack(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.badge_outlined,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -1,
                            bottom: -1,
                            child: Container(
                              width: 13,
                              height: 13,
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
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PeoplePay360',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'ENTERPRISE HR & PAYROLL • ODOO 18',
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFFF0BFE0),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // PROD-US1 Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4EDEA3),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'PROD-US1',
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white,
                            fontSize: 11,
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
              Text(
                _currentRoleBadge,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF00696E),
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
                    Text(
                      'Keep me signed in',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF4E444A),
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

          const SizedBox(height: 12),

          // Face ID Secondary Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFEAEDFF),
                foregroundColor: const Color(0xFF00696E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _handleFaceId,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.face, size: 20, color: Color(0xFF00696E)),
                  const SizedBox(width: 8),
                  Text(
                    'Or sign in with Face ID',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00696E),
                    ),
                  ),
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
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFF92EFF5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.bolt, color: Color(0xFF006E73), size: 15),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '⚡ Quick Demo Roles (1-Tap Fast Evaluation)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Instantly populate credentials for judging & sandbox access.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF4E444A),
            ),
          ),
          const SizedBox(height: 12),

          // 2x2 Grid of Roles
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _demoRoles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            itemBuilder: (context, index) {
              final item = _demoRoles[index];
              final isSelected = _selectedRoleIndex == index;

              return InkWell(
                onTap: () => _selectRole(index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFD7F1) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF714B67).withValues(alpha: 0.3)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
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
                          Text(
                            item['label']!,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? const Color(0xFF2F1029)
                                  : (item['role'] == 'Admin'
                                      ? const Color(0xFF714B67)
                                      : const Color(0xFF00696E)),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.done,
                              size: 14,
                              color: Color(0xFF2F1029),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['badge']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF2F1029)
                              : const Color(0xFF4E444A),
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF92EFF5),
                borderRadius: BorderRadius.circular(8),
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

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEAEDFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 12, color: Color(0xFF4E444A)),
              const SizedBox(width: 5),
              Text(
                'Secured by Odoo Enterprise RBAC • Version 2026.1',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: const Color(0xFF4E444A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF00696E),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Acme Global Industries (US-East Cluster)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
