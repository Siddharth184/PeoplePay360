import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import 'auth_login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusText = 'Initializing Workspace...';

  @override
  void initState() {
    super.initState();
    _startAnimationSequence();
  }

  void _startAnimationSequence() {
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _statusText = 'Loading AST Payroll Rules...');
    });
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _statusText = 'Connecting pgvector RAG Index...');
    });
    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthLoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF714B67), // Odoo Aubergine
              Color(0xFF57344F),
              Color(0xFF2F1029),
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative background glowing circles
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.odooTeal.withValues(alpha: 0.2),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Center Logo & Branding Block
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.hub_rounded,
                    size: 56,
                    color: AppTheme.odooAubergine,
                  ),
                )
                .animate()
                .scale(duration: 800.ms, curve: Curves.elasticOut)
                .fade(duration: 500.ms),

                const SizedBox(height: 24),

                Text(
                  'PeoplePay 360',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                )
                .animate()
                .slideY(begin: 0.3, end: 0, duration: 600.ms, curve: Curves.easeOut)
                .fade(duration: 600.ms),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ENTERPRISE HR & PAYROLL PLATFORM',
                    style: TextStyle(
                      color: Color(0xFF95F1F8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms),

                const SizedBox(height: 48),

                // Loading Spinner & Dynamic Status
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.odooTeal),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  _statusText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // Footer Version Tag
            Positioned(
              bottom: 40,
              child: const Text(
                'v2026.1 • Odoo HRMS Engine • SOC2 Type II Certified',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
