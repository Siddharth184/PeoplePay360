import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';

/// Backend-controlled punch toggle.
///
/// The sheet holds NO local punch state. On open it loads GET /attendance/status
/// and mirrors the backend. Tapping the button disables it, calls
/// POST /attendance/punch, then refetches status. The elapsed timer is derived
/// from the backend `since` instant, so it can never drift from the server.
class AttendancePunchSheet extends StatefulWidget {
  /// Called after a successful punch so the host screen can refresh its ledger.
  final VoidCallback? onPunchComplete;

  const AttendancePunchSheet({super.key, this.onPunchComplete});

  static Future<void> show(BuildContext context, {VoidCallback? onPunchComplete}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF283044).withValues(alpha: 0.65),
      builder: (context) => AttendancePunchSheet(onPunchComplete: onPunchComplete),
    );
  }

  @override
  State<AttendancePunchSheet> createState() => _AttendancePunchSheetState();
}

class _AttendancePunchSheetState extends State<AttendancePunchSheet> {
  late Timer _clockTimer;

  bool _isLoadingStatus = true;
  bool _isSubmitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // One-second tick refreshes the elapsed display (derived from backend since).
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _refreshStatus();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isLoadingStatus = true;
      _loadError = null;
    });
    final res = await AttendanceService.getPunchStatus();
    if (!mounted) return;
    setState(() {
      _isLoadingStatus = false;
      if (!res.isSuccess) {
        _loadError = res.statusCode == 0
            ? 'Could not sync attendance. Please try again.'
            : (res.errorMessage ?? 'Could not sync attendance. Please try again.');
      }
    });
  }

  Duration _elapsed(PunchState state) {
    if (state.since == null) return Duration.zero;
    final diff = DateTime.now().toUtc().difference(state.since!.toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  String _formatHMS(Duration d) => '${d.inHours}h ${d.inMinutes % 60}m ${d.inSeconds % 60}s';

  String _formatRemainingHMS(Duration d) {
    const target = 8 * 3600;
    final remaining = math.max(0, target - d.inSeconds);
    final h = remaining ~/ 3600;
    final m = (remaining % 3600) ~/ 60;
    final s = remaining % 60;
    return '${h}h ${m}m ${s}s';
  }

  double _progressRatio(Duration d) => (d.inSeconds / (8 * 3600)).clamp(0.0, 1.0);

  void _snack(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? const Color(0xFF006443) : const Color(0xFFBA1A1A),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(success ? Icons.check_circle_outline : Icons.error_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onPunchPressed() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    // Do NOT mutate the final state before the backend confirms.
    final result = await AttendanceService.punch();
    if (!mounted) return;

    // Always re-sync with the backend truth, regardless of outcome.
    await AttendanceService.getPunchStatus();
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      if (result.isSuccess) {
        _loadError = null;
      }
    });

    if (result.isSuccess) {
      _snack(result.message, success: true);
      widget.onPunchComplete?.call();
    } else {
      // Duplicate-tap conflict from the single-open-punch guard: refresh & inform.
      if (result.statusCode == 409) {
        _snack('You are already punched in. Status refreshed.', success: false);
      } else {
        _snack(result.message, success: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final liveClockStr = DateFormat('hh:mm:ss a').format(now);
    final dateStr = DateFormat('EEEE, dd-MMM-yyyy').format(now);

    return ValueListenableBuilder<PunchState>(
      valueListenable: AttendanceService.stateNotifier,
      builder: (context, state, _) {
        final isPunchedIn = state.status == PunchStatus.punchedIn;
        final elapsed = _elapsed(state);
        final progressRatio = _progressRatio(elapsed);
        final progressPercent = (progressRatio * 100).round();

        final mediaQuery = MediaQuery.of(context);
        final maxSheetHeight = mediaQuery.size.height * 0.85;

        return Container(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          margin: const EdgeInsets.only(top: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF283044),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Color(0x7F000000), blurRadius: 32, offset: Offset(0, -6)),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 220,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isPunchedIn
                              ? const Color(0xFF006443)
                              : const Color(0xFFBA1A1A))
                          .withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDAE2FD).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildHeader(dateStr),
                    const SizedBox(height: 16),
                    _buildLiveClock(liveClockStr),
                    const SizedBox(height: 16),

                    if (_isLoadingStatus) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(color: Color(0xFF95F1F8)),
                      ),
                    ] else if (_loadError != null) ...[
                      _buildErrorCard(_loadError!),
                    ] else if (isPunchedIn) ...[
                      _buildPunchedInGauge(state, elapsed, progressRatio, progressPercent),
                      const SizedBox(height: 16),
                      _buildStatsRow(elapsed),
                      const SizedBox(height: 18),
                      _buildActionButton(isPunchedIn: true),
                    ] else ...[
                      _buildNotPunchedInCard(),
                      const SizedBox(height: 18),
                      _buildActionButton(isPunchedIn: false),
                    ],

                    const SizedBox(height: 14),
                    Text(
                      'Attendance is recorded and verified by the PeoplePay360 backend.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: const Color(0xFFDAE2FD).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(String dateStr) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Punch Clock',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                dateStr,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: const Color(0xFFDAE2FD).withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFDAE2FD).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Icon(Icons.close, size: 18, color: Colors.white70)),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveClock(String liveClockStr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDAE2FD).withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time_filled, color: Color(0xFF95F1F8), size: 16),
          const SizedBox(width: 8),
          Text(
            'LIVE CLOCK: $liveClockStr',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF95F1F8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFBA1A1A).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBA1A1A).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Color(0xFFFFB4AB), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF95F1F8)),
                foregroundColor: const Color(0xFF95F1F8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _refreshStatus,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('Retry',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchedInGauge(
      PunchState state, Duration elapsed, double progressRatio, int progressPercent) {
    final sinceLocal = state.since?.toLocal();
    final sinceStr = sinceLocal != null ? DateFormat('hh:mm a').format(sinceLocal) : '--';
    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(220, 220),
                painter: _CircularProgressPainter(
                  progress: progressRatio,
                  trackColor: const Color(0xFFDAE2FD).withValues(alpha: 0.12),
                  progressColor: const Color(0xFF00696E),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF006443).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFF6FFBBE).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: Color(0xFF6FFBBE), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('PUNCHED IN',
                            style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6FFBBE))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${elapsed.inHours.toString().padLeft(2, '0')} : ${(elapsed.inMinutes % 60).toString().padLeft(2, '0')} : ${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Punched in since $sinceStr',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFFDAE2FD).withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF00696E).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('$progressPercent% OF 8H',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF95F1F8))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotPunchedInCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFBA1A1A).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBA1A1A).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Color(0xFFFFB4AB), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOT PUNCHED IN',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFB4AB))),
                Text('You have not punched in today. Tap Punch In to start your shift.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Duration elapsed) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.access_time_filled,
            iconColor: const Color(0xFF6FFBBE),
            iconBg: const Color(0xFF006443),
            label: 'Worked Time',
            value: _formatHMS(elapsed),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            icon: Icons.hourglass_bottom,
            iconColor: const Color(0xFF95F1F8),
            iconBg: const Color(0xFF00696E),
            label: 'Remaining (of 8h)',
            value: _formatRemainingHMS(elapsed),
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Container(
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
              color: iconBg.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Icon(icon, size: 18, color: iconColor)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: const Color(0xFFDAE2FD).withValues(alpha: 0.7))),
                Text(value,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required bool isPunchedIn}) {
    final label = isPunchedIn ? 'Punch Out' : 'Punch In';
    final color = isPunchedIn ? const Color(0xFFBA1A1A) : const Color(0xFF006443);
    final icon = isPunchedIn ? Icons.logout_rounded : Icons.login_rounded;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
        // Disabled immediately while a punch is in flight.
        onPressed: _isSubmitting ? null : _onPunchPressed,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 20),
        label: Text(
          _isSubmitting ? 'Recording…' : label,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _CircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.progressColor != progressColor;
}
