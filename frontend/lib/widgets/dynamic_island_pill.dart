import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class DynamicIslandPill extends StatefulWidget {
  final VoidCallback? onPunchTapped;
  const DynamicIslandPill({super.key, this.onPunchTapped});

  @override
  State<DynamicIslandPill> createState() => _DynamicIslandPillState();
}

class _DynamicIslandPillState extends State<DynamicIslandPill> {
  bool _isCheckedIn = true;
  late Timer _timer;
  int _elapsedSeconds = 5 * 3600 + 30 * 60 + 15; // 05:30:15

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isCheckedIn) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSecs) {
    int hours = totalSecs ~/ 3600;
    int minutes = (totalSecs % 3600) ~/ 60;
    int seconds = totalSecs % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _togglePunch() {
    setState(() {
      _isCheckedIn = !_isCheckedIn;
    });
    if (widget.onPunchTapped != null) {
      widget.onPunchTapped!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _togglePunch,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: _isCheckedIn ? AppTheme.emeraldSuccess : AppTheme.crimsonDanger,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isCheckedIn ? AppTheme.emeraldSuccess : AppTheme.crimsonDanger).withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _isCheckedIn ? AppTheme.emeraldSuccess : AppTheme.crimsonDanger,
                shape: BoxShape.circle,
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3), duration: 1.seconds),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isCheckedIn ? 'CHECKED IN (PRESENT)' : 'CHECKED OUT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isCheckedIn ? AppTheme.emeraldSuccess : AppTheme.crimsonDanger,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _formatDuration(_elapsedSeconds),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (_isCheckedIn ? AppTheme.emeraldSuccess : AppTheme.crimsonDanger).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCheckedIn ? Icons.fingerprint : Icons.touch_app,
                    size: 16,
                    color: _isCheckedIn ? AppTheme.emeraldSuccess : AppTheme.crimsonDanger,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isCheckedIn ? 'Punch Out' : 'Punch In',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isCheckedIn ? AppTheme.emeraldSuccess : AppTheme.crimsonDanger,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
