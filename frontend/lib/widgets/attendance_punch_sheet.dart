import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';

class AttendancePunchSheet extends StatefulWidget {
  final VoidCallback? onCheckOutComplete;
  final VoidCallback? onBreakToggled;

  const AttendancePunchSheet({
    super.key,
    this.onCheckOutComplete,
    this.onBreakToggled,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onCheckOutComplete, VoidCallback? onBreakToggled}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF283044).withValues(alpha: 0.65),
      builder: (context) => AttendancePunchSheet(
        onCheckOutComplete: onCheckOutComplete,
        onBreakToggled: onBreakToggled,
      ),
    );
  }

  @override
  State<AttendancePunchSheet> createState() => _AttendancePunchSheetState();
}

class _AttendancePunchSheetState extends State<AttendancePunchSheet> with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _elapsedSeconds = 6 * 3600 + 56 * 60 + 16; // 06:56:16 base
  bool _isCheckedIn = true;
  bool _isOnBreak = false;
  late DateTime _currentTime;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fetchPunchStatus();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_isCheckedIn && !_isOnBreak) {
          _elapsedSeconds++;
        }
        _currentTime = DateTime.now();
      });
    });
  }

  Future<void> _fetchPunchStatus() async {
    final res = await AttendanceService.getPunchStatus();
    if (mounted && res.isSuccess && res.data != null) {
      final isChecked = res.data!['checked_in'] as bool? ?? true;
      final elapsedHours = (res.data!['elapsed_hours'] as num?)?.toDouble() ?? 0.0;
      setState(() {
        _isCheckedIn = isChecked;
        if (elapsedHours > 0) {
          _elapsedSeconds = (elapsedHours * 3600).round();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _formatWorkedHMS() {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${h}h ${m}m ${s}s';
  }

  String _formatRemainingHMS() {
    const targetSeconds = 8 * 3600;
    final remaining = math.max(0, targetSeconds - _elapsedSeconds);
    final h = remaining ~/ 3600;
    final m = (remaining % 3600) ~/ 60;
    final s = remaining % 60;
    return '${h}h ${m}m ${s}s';
  }

  double get _progressRatio {
    const targetSeconds = 8 * 3600;
    return (_elapsedSeconds / targetSeconds).clamp(0.0, 1.0);
  }

  int get _progressPercent => (_progressRatio * 100).round();

  void _handleCheckOut() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF283044),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.fingerprint, color: Color(0xFFBA1A1A), size: 28),
            const SizedBox(width: 10),
            Text(
              'Biometric Verification',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Place your registered finger on the sensor or authenticate with FaceID to record your departure timestamp.',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFFDAE2FD), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Color(0xFF4EDEA3), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cryptographic Punch: BOM-HQ (WiFi: OXP-Corp-5G)',
                      style: GoogleFonts.jetBrainsMono(color: const Color(0xFF6FFBBE), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() {
                _isCheckedIn = !_isCheckedIn;
              });
              await AttendanceService.punch(note: 'Biometric verified terminal punch');
              if (mounted) {
                Navigator.pop(context);
                widget.onCheckOutComplete?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF006443),
                    behavior: SnackBarBehavior.floating,
                    content: Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Punch recorded successfully at ${DateFormat('hh:mm a').format(DateTime.now())}. Shift: ${_formatWorkedHMS()}',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
            child: Text('Confirm Biometric', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _toggleBreak() {
    setState(() {
      _isOnBreak = !_isOnBreak;
    });
    widget.onBreakToggled?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _isOnBreak ? const Color(0xFF00696E) : const Color(0xFF006443),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(
          _isOnBreak ? '☕ Shift timer paused. On Break.' : '▶ Shift timer resumed. Back from Break.',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    final liveClockStr = DateFormat('hh:mm:ss a').format(_currentTime);
    final dateStr = DateFormat('EEE, MMM dd, yyyy').format(_currentTime);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF283044),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x7F000000),
            blurRadius: 32,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient Backlight Gradient at Top
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 280,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF004A31).withValues(alpha: 0.5),
                      const Color(0xFF00696E).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Drag Handle notch
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF80747A).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sheet Header: Avatar, Name, Office Chip
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Aarav Mehta Avatar with online status
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF714B67),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    'https://lh3.googleusercontent.com/aida-public/AB6AXuBbDu9y-yvqjkjsKc9UyC2Yn-_w_zM5rKHE9AwIPy3Tb9RoNZzro1k_Lhy7R0gEyc3UTbBLcg8ckjUiBDjCma9JUs3bDypi0_kd_y9Hi-kFMW8ZBjEuujDqVX6aUQNPjZYQwn2WHibvZm8B3l9Mc6Ug8dLwJrSSy5v78xDz_d-ncZ2_TvzZ4WRdo7XAteZa92MglCS1PMeJjworqpOzxiCytRUb7kEHYMPXAJyMZLjFmCIPlAG7mH6Z',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Text('AM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6FFBBE),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF283044), width: 2),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF004A31),
                                          shape: BoxShape.circle,
                                        ),
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
                                  'Good morning,',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: const Color(0xFFDAE2FD).withValues(alpha: 0.8),
                                  ),
                                ),
                                Text(
                                  'Aarav Mehta!',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Office location chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDAE2FD).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Color(0xFF95F1F8)),
                              const SizedBox(width: 4),
                              Text(
                                'BOM-HQ',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF95F1F8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Current Date & Monospace Live World Clock Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_available, size: 16, color: Color(0xFF6FFBBE)),
                            const SizedBox(width: 6),
                            Text(
                              dateStr,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                color: const Color(0xFFDAE2FD).withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDAE2FD).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) => Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF4EDEA3).withValues(alpha: 0.4 + 0.6 * _pulseController.value),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                liveClockStr,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Central Radial Dynamic Island Shift Progress Gauge
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Custom Radial Progress Painter
                        CustomPaint(
                          size: const Size(240, 240),
                          painter: _RadialGaugePainter(
                            progress: _progressRatio,
                            trackColor: const Color(0xFF1E2638),
                            startColor: const Color(0xFF4EDEA3),
                            endColor: const Color(0xFF00696E),
                          ),
                        ),

                        // Center content inside radial gauge
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Status Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _isOnBreak
                                    ? const Color(0xFF00696E).withValues(alpha: 0.4)
                                    : const Color(0xFF006443).withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isOnBreak ? const Color(0xFF95F1F8) : const Color(0xFF6FFBBE),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _isOnBreak ? 'ON BREAK' : (_isCheckedIn ? 'CHECKED IN' : 'CHECKED OUT'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: _isOnBreak ? const Color(0xFF95F1F8) : const Color(0xFF6FFBBE),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Monospace Large Elapsed Clock
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _twoDigits(h),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) => Opacity(
                                    opacity: 0.4 + 0.6 * _pulseController.value,
                                    child: Text(
                                      ' : ',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w300,
                                        color: const Color(0xFF6FFBBE),
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  _twoDigits(m),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) => Opacity(
                                    opacity: 0.4 + 0.6 * _pulseController.value,
                                    child: Text(
                                      ' : ',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w300,
                                        color: const Color(0xFF6FFBBE),
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  _twoDigits(s),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF95F1F8),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),
                            Text(
                              'Elapsed since check-in at 09:05 AM',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                color: const Color(0xFFDAE2FD).withValues(alpha: 0.75),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // % Indicator Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDAE2FD).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_progressPercent% COMPLETED',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: const Color(0xFF6FFBBE),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Mini Stats Row Underneath Gauge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Worked Time
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDAE2FD).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF004A31).withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.timelapse, size: 18, color: Color(0xFF6FFBBE)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Worked Time',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        color: const Color(0xFFDAE2FD).withValues(alpha: 0.7),
                                      ),
                                    ),
                                    Text(
                                      _formatWorkedHMS(),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Remaining
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDAE2FD).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00696E).withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.hourglass_bottom, size: 18, color: Color(0xFF95F1F8)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Remaining',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        color: const Color(0xFFDAE2FD).withValues(alpha: 0.7),
                                      ),
                                    ),
                                    Text(
                                      _formatRemainingHMS(),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Shift Targets & Overtime Projection Strip
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDAE2FD).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flag_outlined, size: 18, color: Color(0xFF95F1F8)),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Target: 8h 00m',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Est. Departure: 06:05 PM',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      color: const Color(0xFFDAE2FD).withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF006443).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.trending_up, size: 14, color: Color(0xFF6FFBBE)),
                                const SizedBox(width: 4),
                                Text(
                                  '+0.50h OT Projected',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF6FFBBE),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Primary Action Buttons & Biometric Punch Trigger
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Prominent Red Checkout Button
                        InkWell(
                          onTap: _handleCheckOut,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFBA1A1A),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFBA1A1A).withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF283044).withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.fingerprint, color: Colors.white, size: 24),
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'CHECK OUT NOW',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'HOLD OR TAP WITH BIOMETRICS',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.logout, color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Secondary Break / Pause Action
                        InkWell(
                          onTap: _toggleBreak,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDAE2FD).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isOnBreak ? Icons.play_circle_outline : Icons.pause_circle_outline,
                                    size: 19,
                                    color: const Color(0xFF95F1F8),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isOnBreak ? 'Resume Shift Timer' : 'Shift Break / Pause Timer',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Trust, Security Audit & Geofence Verification Footer
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified, size: 14, color: Color(0xFF6FFBBE)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Geofence Verified: Mumbai HQ (Wi-Fi: OXP-Corp-5G)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6FFBBE),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline, size: 12, color: const Color(0xFFDAE2FD).withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Biometric cryptographic timestamp logged via PeoplePay360 ERP',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  color: const Color(0xFFDAE2FD).withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
}

class _RadialGaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color startColor;
  final Color endColor;

  _RadialGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 14;

    // Background track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc with soft glow
    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress;
      const startAngle = -math.pi / 2;

      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [startColor, endColor],
      );

      // Glow shadow paint
      final glowPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);

      // Main crisp arc paint
      final arcPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
