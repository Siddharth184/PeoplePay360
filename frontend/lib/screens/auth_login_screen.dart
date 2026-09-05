import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import 'home_navigation_screen.dart';

class AuthLoginScreen extends StatefulWidget {
  const AuthLoginScreen({super.key});

  @override
  State<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends State<AuthLoginScreen> {
  String _selectedRole = 'EMPLOYEE';
  final _emailController = TextEditingController(text: 'aarav.sharma@peoplepay360.io');
  final _passwordController = TextEditingController(text: '••••••••••••');

  void _login() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeNavigationScreen(userRole: _selectedRole),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.odooAubergine,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.odooAubergine.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.hub_rounded, size: 44, color: Colors.white),
                ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Text(
                      'PeoplePay 360',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Odoo 18 Enterprise HR & Payroll Platform',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              Text(
                'Select Active Role',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRoleChip('EMPLOYEE', 'Employee', Icons.person_outline),
                  _buildRoleChip('HR_MANAGER', 'HR Manager', Icons.badge_outlined),
                  _buildRoleChip('HR_PAYROLL_MANAGER', 'Payroll Mgr', Icons.payments_outlined),
                  _buildRoleChip('ADMIN', 'System Admin', Icons.admin_panel_settings_outlined),
                ],
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.odooAubergine,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Secure Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _login,
                  icon: const Icon(Icons.fingerprint, size: 22, color: AppTheme.odooTeal),
                  label: const Text(
                    'Biometric Sign In (Face ID)',
                    style: TextStyle(color: AppTheme.odooTeal, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String value, String label, IconData icon) {
    final isSelected = _selectedRole == value;
    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.odooAubergine),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.odooAubergine,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimaryLight,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedRole = value);
      },
    );
  }
}
