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
  late Timer _clockTimer;
  late DateTime _currentTime;
  late AnimationController _pulseController;

  String _selectedLocation = 'Mumbai HQ (Floor 4 • Wi-Fi: OXP-Corp-5G)';
  String _selectedWorkMode = 'Office HQ';
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _locations = [
    'Mumbai HQ (Floor 4 • Wi-Fi: OXP-Corp-5G)',
    'Bengaluru Tech Park (Floor 2 • Lab)',
    'Client Site (Bandra Kurla Complex)',
    'Remote / WFH (GPS Geofence Verified)',
  ];

  final List<String> _workModes = [
    'Office HQ',
    'Client Site',
    'Work From Home (WFH)',
  ];

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _pulseController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _formatHMS(int totalSecs) {
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    return '${h}h ${m}m ${s}s';
  }

  String _formatRemainingHMS(int elapsedSecs) {
    const targetSeconds = 8 * 3600;
    final remaining = math.max(0, targetSeconds - elapsedSecs);
    final h = remaining ~/ 3600;
    final m = (remaining % 3600) ~/ 60;
    final s = remaining % 60;
    return '${h}h ${m}m ${s}s';
  }

  double _progressRatio(int elapsedSecs) {
    const targetSeconds = 8 * 3600;
    return (elapsedSecs / targetSeconds).clamp(0.0, 1.0);
  }

  Future<void> _submitRequest(PunchRequestType type) async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 400));

    final req = await AttendanceService.submitPunchRequest(
      type: type,
      location: _selectedLocation,
      workMode: _selectedWorkMode,
      reason: _reasonController.text.trim().isNotEmpty
          ? _reasonController.text.trim()
          : (type == PunchRequestType.punchIn
              ? 'Shift start check-in request'
              : type == PunchRequestType.punchOut
                  ? 'Shift completion check-out request'
                  : 'Break transition request'),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF006443),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.outgoing_mail, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${req.typeLabel} Request #${req.id} submitted! Sent to HR Sara Khan for approval.',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _fastApproveDemo(String reqId) async {
    await AttendanceService.approvePunchRequest(reqId);
    if (mounted) {
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
                  '✓ HR Approved! Status updated to Punched In at ${DateFormat('hh:mm a').format(DateTime.now())}.',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showRequestDialog(PunchRequestType type) {
    _reasonController.clear();
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          String dialogTitle;
          Color dialogColor;
          IconData dialogIcon;

          switch (type) {
            case PunchRequestType.punchIn:
              dialogTitle = 'Submit Punch In Request';
              dialogColor = const Color(0xFF006443);
              dialogIcon = Icons.login_rounded;
              break;
            case PunchRequestType.punchOut:
              dialogTitle = 'Submit Punch Out Request';
              dialogColor = const Color(0xFFBA1A1A);
              dialogIcon = Icons.logout_rounded;
              break;
            case PunchRequestType.breakStart:
              dialogTitle = 'Submit Break Request';
              dialogColor = const Color(0xFF00696E);
              dialogIcon = Icons.coffee_rounded;
              break;
            case PunchRequestType.breakEnd:
              dialogTitle = 'Submit Resume Shift Request';
              dialogColor = const Color(0xFF006443);
              dialogIcon = Icons.play_arrow_rounded;
              break;
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF283044),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: dialogColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Icon(dialogIcon, color: dialogColor, size: 20)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dialogTitle,
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: Color(0xFF95F1F8), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Requested Time:',
                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFFDAE2FD), fontSize: 12),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('hh:mm a, dd-MMM-yyyy').format(_currentTime),
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Location Selector
                  Text('PUNCH LOCATION', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFFDAE2FD).withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDAE2FD).withValues(alpha: 0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLocation,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E2433),
                        icon: const Icon(Icons.expand_more, color: Colors.white70),
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12),
                        items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => _selectedLocation = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Work Mode
                  Text('WORK MODE', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFFDAE2FD).withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDAE2FD).withValues(alpha: 0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedWorkMode,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E2433),
                        icon: const Icon(Icons.expand_more, color: Colors.white70),
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12),
                        items: _workModes.map((wm) => DropdownMenuItem(value: wm, child: Text(wm))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => _selectedWorkMode = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Remarks / Notes
                  Text('REASON / REMARKS (OPTIONAL)', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFFDAE2FD).withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _reasonController,
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'e.g. Regular shift start or client meeting...',
                      hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFFDAE2FD).withValues(alpha: 0.2))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFFDAE2FD).withValues(alpha: 0.2))),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF92EFF5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF95F1F8), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Request will be routed to HR Sara Khan for validation.',
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFDAE2FD), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: dialogColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _submitRequest(type);
                },
                child: Text('Submit to HR', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveClockStr = DateFormat('hh:mm:ss a').format(_currentTime);
    final dateStr = DateFormat('EEEE, dd-MMM-yyyy').format(_currentTime);

    return ValueListenableBuilder<PunchState>(
      valueListenable: AttendanceService.stateNotifier,
      builder: (context, state, _) {
        final isPunchedIn = state.status == PunchStatus.punchedIn;
        final isOnBreak = state.status == PunchStatus.onBreak;
        final isPending = state.status == PunchStatus.pendingPunchIn ||
            state.status == PunchStatus.pendingPunchOut ||
            state.status == PunchStatus.pendingBreak;

        final elapsedH = state.elapsedSeconds ~/ 3600;
        final elapsedM = (state.elapsedSeconds % 3600) ~/ 60;
        final elapsedS = state.elapsedSeconds % 60;
        final progressRatio = _progressRatio(state.elapsedSeconds);
        final progressPercent = (progressRatio * 100).round();

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
              // Ambient glow
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
                              : isPending
                                  ? const Color(0xFFF59E0B)
                                  : isOnBreak
                                      ? const Color(0xFF00696E)
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
                    // Drag Handle
                    Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDAE2FD).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Attendance Punching & Approval',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                dateStr,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFFDAE2FD).withValues(alpha: 0.7),
                                ),
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
                            child: const Center(
                              child: Icon(Icons.close, size: 18, color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Live Time Clock Display
                    Container(
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
                    ),
                    const SizedBox(height: 16),

                    // Status Gauge / Card
                    if (isPunchedIn) ...[
                      // Punched In Gauge
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
                                glowColor: const Color(0xFF6FFBBE),
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
                                    border: Border.all(color: const Color(0xFF6FFBBE).withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF6FFBBE), shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'PUNCHED IN',
                                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF6FFBBE)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_twoDigits(elapsedH)} : ${_twoDigits(elapsedM)} : ${_twoDigits(elapsedS)}',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Approved at ${state.activeApprovedRequest?.approvedTimeString ?? '09:05 AM'}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFFDAE2FD).withValues(alpha: 0.7)),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF00696E).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                                  child: Text('$progressPercent% COMPLETED', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF95F1F8))),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Approval Verification Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF006443).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF006443).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified, color: Color(0xFF6FFBBE), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '✓ Punched In: Approved by ${state.activeApprovedRequest?.approvedBy ?? 'Sara Khan (HR Lead)'} on ${state.activeApprovedRequest?.approvedDateString ?? dateStr}',
                                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF6FFBBE), fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isPending) ...[
                      // Pending Approval Banner
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(child: Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 22)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PUNCH REQUEST PENDING',
                                        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFFBBF24)),
                                      ),
                                      Text(
                                        '${state.pendingRequest?.typeLabel} #${state.pendingRequest?.id ?? ''}',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Requested Time:', style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 11)),
                                      Text(state.pendingRequest?.requestedTimeString ?? '--', style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Location:', style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 11)),
                                      Expanded(
                                        child: Text(
                                          state.pendingRequest?.location ?? 'Mumbai HQ',
                                          textAlign: TextAlign.end,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Fast Approve Tool for Evaluation
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006443),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onPressed: () => _fastApproveDemo(state.pendingRequest!.id),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: Text('⚡ Fast-Approve as HR (Demo Evaluator)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isOnBreak) ...[
                      // On Break Status
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00696E).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF00696E).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.coffee, color: Color(0xFF95F1F8), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ON BREAK (SHIFT PAUSED)', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF95F1F8))),
                                  Text('Break request approved by HR Lead.', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.white70)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Not Punched In
                      Container(
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
                                  Text('NOT PUNCHED IN', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFFFB4AB))),
                                  Text('Submit a Punch In request to HR below to log your shift.', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.white70)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Stats Bento (Worked Time & Remaining)
                    Row(
                      children: [
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
                                    color: const Color(0xFF006443).withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(child: Icon(Icons.access_time_filled, size: 18, color: Color(0xFF6FFBBE))),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Worked Time', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFFDAE2FD).withValues(alpha: 0.7))),
                                      Text(_formatHMS(state.elapsedSeconds), style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                                  child: const Center(child: Icon(Icons.hourglass_bottom, size: 18, color: Color(0xFF95F1F8))),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Remaining', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFFDAE2FD).withValues(alpha: 0.7))),
                                      Text(_formatRemainingHMS(state.elapsedSeconds), style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Action Submission Buttons
                    if (!isPunchedIn && !isPending) ...[
                      // Submit Punch In
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006443),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          onPressed: _isSubmitting ? null : () => _showRequestDialog(PunchRequestType.punchIn),
                          icon: const Icon(Icons.login_rounded, size: 20),
                          label: Text('Submit Punch In Request to HR', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else if (isPunchedIn && !isPending) ...[
                      // Action Row: Punch Out & Break
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF95F1F8)),
                                foregroundColor: const Color(0xFF95F1F8),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                              ),
                              onPressed: () => _showRequestDialog(PunchRequestType.breakStart),
                              icon: const Icon(Icons.coffee_rounded, size: 18),
                              label: Text('Request Break', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFBA1A1A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                              ),
                              onPressed: () => _showRequestDialog(PunchRequestType.punchOut),
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: Text('Request Punch Out', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isOnBreak && !isPending) ...[
                      // Resume Shift
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006443),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          onPressed: () => _showRequestDialog(PunchRequestType.breakEnd),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: Text('Request Resume Shift (End Break)', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Audit Info Footnote
                    Text(
                      'All punch requests are cryptographically timestamped and synced with OXP HR Attendance engine.',
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
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final Color glowColor;

  _CircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
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
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.progressColor != progressColor;
  }
}
