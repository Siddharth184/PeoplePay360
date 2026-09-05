import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import 'attendance_punch_sheet.dart';

/// Compact live punch indicator. Reads the backend-authoritative punch state
/// from [AttendanceService.stateNotifier]. The elapsed timer is derived from the
/// backend `since` instant, not a local counter, so it stays truthful.
class DynamicIslandPill extends StatefulWidget {
  final VoidCallback? onPunchTapped;
  const DynamicIslandPill({super.key, this.onPunchTapped});

  @override
  State<DynamicIslandPill> createState() => _DynamicIslandPillState();
}

class _DynamicIslandPillState extends State<DynamicIslandPill> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh the visible elapsed value once a second while punched in.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Duration _elapsed(PunchState state) {
    if (state.since == null) return Duration.zero;
    final diff = DateTime.now().toUtc().difference(state.since!.toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _openSheet(BuildContext context) {
    if (widget.onPunchTapped != null) {
      widget.onPunchTapped!();
    } else {
      AttendancePunchSheet.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<PunchState>(
      valueListenable: AttendanceService.stateNotifier,
      builder: (context, state, _) {
        Color mainColor;
        String statusTitle;
        String statusSubtitle;
        String actionLabel;
        IconData actionIcon;

        switch (state.status) {
          case PunchStatus.punchedIn:
            mainColor = AppTheme.emeraldSuccess;
            statusTitle = 'PUNCHED IN';
            statusSubtitle = _formatDuration(_elapsed(state));
            actionLabel = 'Punch Out';
            actionIcon = Icons.logout_rounded;
            break;
          case PunchStatus.notPunchedIn:
            mainColor = AppTheme.crimsonDanger;
            statusTitle = 'NOT PUNCHED IN';
            statusSubtitle = 'Shift Idle';
            actionLabel = 'Punch In';
            actionIcon = Icons.touch_app_rounded;
            break;
          case PunchStatus.unknown:
            mainColor = const Color(0xFF80747A);
            statusTitle = 'ATTENDANCE';
            statusSubtitle = 'Tap to load';
            actionLabel = 'Open';
            actionIcon = Icons.fingerprint;
            break;
        }

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: GestureDetector(
            onTap: () => _openSheet(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: mainColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: mainColor.withValues(alpha: 0.2),
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
                      color: mainColor,
                      shape: BoxShape.circle,
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1.3, 1.3),
                        duration: 1.seconds,
                      ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        statusSubtitle,
                        style: const TextStyle(
                          fontSize: 14.5,
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
                      color: mainColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(actionIcon, size: 15, color: mainColor),
                        const SizedBox(width: 4),
                        Text(
                          actionLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
