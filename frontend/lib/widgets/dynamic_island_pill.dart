import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import 'attendance_punch_sheet.dart';

class DynamicIslandPill extends StatelessWidget {
  final VoidCallback? onPunchTapped;
  const DynamicIslandPill({super.key, this.onPunchTapped});

  String _formatDuration(int totalSecs) {
    int hours = totalSecs ~/ 3600;
    int minutes = (totalSecs % 3600) ~/ 60;
    int seconds = totalSecs % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _openSheet(BuildContext context) {
    if (onPunchTapped != null) {
      onPunchTapped!();
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
            statusTitle = 'PUNCHED IN (HR APPROVED)';
            statusSubtitle = _formatDuration(state.elapsedSeconds);
            actionLabel = 'Manage Shift';
            actionIcon = Icons.fingerprint;
            break;
          case PunchStatus.pendingPunchIn:
            mainColor = const Color(0xFFF59E0B);
            statusTitle = 'PUNCH IN PENDING HR';
            statusSubtitle = 'Req at ${state.pendingRequest?.requestedTimeString ?? '--'}';
            actionLabel = 'View Request';
            actionIcon = Icons.hourglass_top_rounded;
            break;
          case PunchStatus.pendingPunchOut:
            mainColor = const Color(0xFFF59E0B);
            statusTitle = 'PUNCH OUT PENDING HR';
            statusSubtitle = 'Req at ${state.pendingRequest?.requestedTimeString ?? '--'}';
            actionLabel = 'View Request';
            actionIcon = Icons.hourglass_bottom_rounded;
            break;
          case PunchStatus.pendingBreak:
            mainColor = const Color(0xFFF59E0B);
            statusTitle = 'BREAK REQ PENDING HR';
            statusSubtitle = 'Awaiting Approval';
            actionLabel = 'View Request';
            actionIcon = Icons.hourglass_empty_rounded;
            break;
          case PunchStatus.onBreak:
            mainColor = const Color(0xFF00696E);
            statusTitle = 'ON BREAK (APPROVED)';
            statusSubtitle = 'Shift Paused';
            actionLabel = 'End Break';
            actionIcon = Icons.coffee_rounded;
            break;
          case PunchStatus.notPunchedIn:
          case PunchStatus.punchedOut:
            mainColor = AppTheme.crimsonDanger;
            statusTitle = 'NOT PUNCHED IN';
            statusSubtitle = 'Shift Idle';
            actionLabel = 'Submit Punch In';
            actionIcon = Icons.touch_app_rounded;
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
                border: Border.all(
                  color: mainColor,
                  width: 1.5,
                ),
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
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3), duration: 1.seconds),
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
                        Icon(
                          actionIcon,
                          size: 15,
                          color: mainColor,
                        ),
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
