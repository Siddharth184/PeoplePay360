import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/attendance_punch_sheet.dart';

class AttendanceScreen extends StatefulWidget {
  final void Function(int index)? onNavigateTab;
  const AttendanceScreen({super.key, this.onNavigateTab});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  String _selectedFilter = 'Today (Sep 2)';
  late AnimationController _pingController;

  final List<Map<String, dynamic>> _records = [
    {
      'name': 'Aarav Mehta',
      'initials': 'AM',
      'avatarBg': const Color(0xFFFFD7F1),
      'avatarFg': const Color(0xFF2F1029),
      'status': 'Present',
      'statusType': 'present',
      'role': 'Finance',
      'empId': 'EMP-4092',
      'hours': '9.08',
      'subTag': '+0.50h OT',
      'subTagColor': const Color(0xFF006E73),
      'subTagBg': const Color(0xFF92EFF5),
      'startTime': '09:05 AM',
      'endTime': '06:10 PM',
      'locationIcon': Icons.wifi,
      'location': 'Mumbai HQ',
      'auditRef': 'CON/PUNCH/2026/0902-88',
      'ip': '192.168.1.104',
      'geo': '18.9220° N, 72.8347° E',
      'validation': 'Mumbai HQ • Wi-Fi Validated Beacon #04',
      'hasActions': false,
    },
    {
      'name': 'Sara Khan',
      'initials': 'SK',
      'avatarBg': const Color(0xFF92EFF5),
      'avatarFg': const Color(0xFF006E73),
      'status': 'Present',
      'statusType': 'present',
      'role': 'VP Finance & HR',
      'empId': 'EMP-4091',
      'hours': '8.78',
      'subTag': 'Standard',
      'subTagColor': const Color(0xFF4E444A),
      'subTagBg': const Color(0xFFEAEDFF),
      'startTime': '09:15 AM',
      'endTime': '06:02 PM',
      'locationIcon': Icons.fingerprint,
      'location': 'Bio Terminal 1',
      'auditRef': 'CON/PUNCH/2026/0902-74',
      'ip': '192.168.1.18',
      'geo': '18.9219° N, 72.8344° E',
      'validation': 'Mumbai HQ • Biometric Terminal 1',
      'hasActions': false,
    },
    {
      'name': 'John Dsouza',
      'initials': 'JD',
      'avatarBg': const Color(0xFFDAE2FD),
      'avatarFg': const Color(0xFF131B2E),
      'status': 'Present',
      'statusType': 'late',
      'role': 'Payroll Specialist',
      'empId': 'EMP-4098',
      'hours': '8.43',
      'subTag': 'Late +32m',
      'subTagColor': const Color(0xFFBA1A1A),
      'subTagBg': const Color(0xFFFFDAD6),
      'startTime': '09:32 AM',
      'isStartLate': true,
      'endTime': '05:58 PM',
      'locationIcon': Icons.pin_drop_outlined,
      'location': 'Geofence App',
      'auditRef': 'CON/PUNCH/2026/0902-19',
      'ip': '10.0.0.44',
      'geo': '18.9221° N, 72.8349° E',
      'validation': 'Mumbai HQ • Mobile Geofence Radar',
      'hasActions': false,
    },
    {
      'name': 'Neha Patel',
      'initials': 'NP',
      'avatarBg': const Color(0xFFFFDAD6),
      'avatarFg': const Color(0xFF93000A),
      'status': 'Absent',
      'statusType': 'absent',
      'role': 'Accounts Associate',
      'empId': 'EMP-4105',
      'hours': '0.00',
      'subTag': 'Unexcused',
      'subTagColor': const Color(0xFF4E444A),
      'subTagBg': const Color(0xFFEAEDFF),
      'startTime': '--:--',
      'endTime': '--:--',
      'locationIcon': Icons.location_off_outlined,
      'location': 'Not Reported',
      'auditRef': 'CON/PUNCH/2026/0902-00',
      'ip': 'N/A',
      'geo': 'N/A',
      'validation': 'Unexcused Absence • No GPS Beacon',
      'hasActions': true,
    },
    {
      'name': 'Rohan Patel',
      'initials': 'RP',
      'avatarBg': const Color(0xFF6FFBBE),
      'avatarFg': const Color(0xFF002113),
      'status': 'On Duty',
      'statusType': 'onduty',
      'role': 'Sr. Backend Eng',
      'empId': 'EMP-4076',
      'hours': '7.82',
      'subTag': 'Active',
      'subTagColor': const Color(0xFF80747A),
      'subTagBg': const Color(0xFFEAEDFF),
      'startTime': '09:02 AM',
      'isTracking': true,
      'endTime': 'Tracking...',
      'isPendingExit': true,
      'locationIcon': Icons.vpn_lock_outlined,
      'location': 'Bangalore Lab',
      'auditRef': 'CON/PUNCH/2026/0902-04',
      'ip': '172.16.4.12',
      'geo': '12.9716° N, 77.5946° E',
      'validation': 'Bangalore Lab • VPN Session Active',
      'hasActions': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pingController.dispose();
    super.dispose();
  }

  void _openManualPunchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD7F1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_task, color: Color(0xFF714B67), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Manual Attendance Punch',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF4E444A)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Employee *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Aarav Mehta (EMP-4092)', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF4E444A)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Check-In Time *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                        child: Text('09:00 AM', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Check-Out Time *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                        child: Text('06:00 PM', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Audit Reason / Justification *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              decoration: InputDecoration(
                hintText: 'e.g. Biometric sensor hardware calibration discrepancy',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF2F3FF),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                AttendancePunchSheet.show(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF283044),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fingerprint, color: Color(0xFF6FFBBE), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Launch Biometric Dynamic Island',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.open_in_new, color: Color(0xFF95F1F8), size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF714B67),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF004A31),
                          behavior: SnackBarBehavior.floating,
                          content: Text('✓ Manual punch registered and logged with Odoo Audit Ledger'),
                        ),
                      );
                    },
                    child: const Text('Save Record'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openInspector(Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1C3CA),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header & Record Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD7F1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Odoo TimeClocks v18',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2F1029),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF006443).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            record['status'] as String,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF004A31),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record['name'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                    Text(
                      '${record['empId']} • ${record['role']} Dept',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Navigator.pop(ctx),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2F3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.close, size: 18, color: Color(0xFF131B2E)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Audit Metadata Bento Box
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _buildBentoRow('Audit Trail Ref:', record['auditRef'] as String, isValueBold: true),
                  const Divider(height: 18, color: Color(0xFFDAE2FD)),
                  _buildBentoRow(
                    'Interval & Duration:',
                    '${record['startTime']} ➔ ${record['endTime']} (${record['hours']} hrs)',
                    isValueBold: true,
                  ),
                  const Divider(height: 18, color: Color(0xFFDAE2FD)),
                  _buildBentoRow('Client Hardware IP:', record['ip'] as String, valueColor: const Color(0xFF00696E), isValueBold: true),
                  const Divider(height: 18, color: Color(0xFFDAE2FD)),
                  _buildBentoRow('Geofence Coordinates:', record['geo'] as String),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Verification Trust Signal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF92EFF5).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, size: 18, color: Color(0xFF00696E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record['validation'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF004F53),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Inspector Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F3FF),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openManualPunchModal();
                    },
                    icon: const Icon(Icons.history_edu, size: 18, color: Color(0xFF131B2E)),
                    label: Text(
                      'Manual Correction',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF714B67),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF004A31),
                          behavior: SnackBarBehavior.floating,
                          content: Text('✓ Exported audit log for ${record['name']} (CSV & PDF ready)'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: Text(
                      'Export Audit Log',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoRow(String label, String value, {bool isValueBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF4E444A)),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: isValueBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? const Color(0xFF131B2E),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _records.where((record) {
      if (_selectedFilter == 'Missing Out') return record['statusType'] == 'absent';
      if (_selectedFilter == 'Late (18)') return record['statusType'] == 'late';
      if (_selectedFilter == 'Overtime (>8h)') return (record['subTag'] as String).contains('OT');
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top App Bar & Contextual Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  } else if (widget.onNavigateTab != null) {
                                    widget.onNavigateTab!(-1);
                                  }
                                },
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF2F3FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.arrow_back, size: 18, color: Color(0xFF131B2E)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Attendance Records',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                        color: const Color(0xFF131B2E),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Pay Cycle: Sept 2026',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: const Color(0xFF4E444A),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF80747A),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'STITCH_ATT',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF00696E),
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
                        const SizedBox(width: 8),
                        // Actions
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2027),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF2F3FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.calendar_today, size: 18, color: Color(0xFF131B2E)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _openManualPunchModal,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF714B67),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF714B67).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add, size: 16, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Punch',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Quick Summary Metric Glass Ribbon
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3FF).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // Present Today
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Present Today',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4E444A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.outfit(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF131B2E),
                                        ),
                                        children: [
                                          const TextSpan(text: '38'),
                                          TextSpan(
                                            text: '/42',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.normal,
                                              color: const Color(0xFF4E444A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6FFBBE).withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '90.4%',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF004A31),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Container(width: 1, height: 28, color: const Color(0xFFDAE2FD)),

                          // Overtime
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Overtime',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF4E444A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF00696E),
                                          ),
                                          children: [
                                            const TextSpan(text: '14.2'),
                                            TextSpan(
                                              text: 'h',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.normal,
                                                color: const Color(0xFF4E444A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.trending_up, size: 15, color: Color(0xFF00696E)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Container(width: 1, height: 28, color: const Color(0xFFDAE2FD)),

                          // Anomalies
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Anomalies',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF4E444A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        '05',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFBA1A1A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      AnimatedBuilder(
                                        animation: _pingController,
                                        builder: (context, child) => Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFFBA1A1A).withValues(alpha: 0.4 + 0.6 * _pingController.value),
                                          ),
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
                  ],
                ),
              ),

              // Horizontal Scroll Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('Today (Sep 2)', isSelected: _selectedFilter == 'Today (Sep 2)', hasCheck: _selectedFilter == 'Today (Sep 2)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('My Team (12)', isSelected: _selectedFilter == 'My Team (12)'),
                    const SizedBox(width: 8),
                    _buildMissingOutChip('Missing Out', 5, isSelected: _selectedFilter == 'Missing Out'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Late (18)', isSelected: _selectedFilter == 'Late (18)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Overtime (>8h)', isSelected: _selectedFilter == 'Overtime (>8h)'),
                  ],
                ),
              ),

              // Real-time Status Micro-bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live Ledger Feed',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _pingController,
                          builder: (context, child) => Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00696E).withValues(alpha: 0.4 + 0.6 * _pingController.value),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Auto-syncing v18.0',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00696E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // High-Density Card List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: filteredRecords.map((record) => _buildAttendanceCard(record)).toList(),
                ),
              ),

              // Micro Interaction Floating Action Helper
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF00696E)),
                        const SizedBox(width: 6),
                        Text(
                          'Compliant with India Shops & Est. Act',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF4E444A)),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => _openInspector(_records[0]),
                      child: Text(
                        'Inspect Sample',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF714B67),
                          decoration: TextDecoration.underline,
                        ),
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
  }

  Widget _buildFilterChip(String label, {bool isSelected = false, bool hasCheck = false}) {
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF714B67) : const Color(0xFFF2F3FF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF714B67).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasCheck) ...[
              const Icon(Icons.done, size: 15, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF131B2E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingOutChip(String label, int count, {bool isSelected = false}) {
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFBA1A1A).withValues(alpha: 0.15) : const Color(0xFFDAE2FD),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: const Color(0xFFBA1A1A)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: Color(0xFFBA1A1A), shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDAD6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF93000A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    final hasActions = record['hasActions'] == true;
    final isTracking = record['isTracking'] == true;
    final isPendingExit = record['isPendingExit'] == true;
    final isStartLate = record['isStartLate'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () => _openInspector(record),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              // Top Row: Avatar, Name, Status, Hours
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Avatar with badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: record['avatarBg'] as Color,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                record['initials'] as String,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: record['avatarFg'] as Color,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: _buildAvatarBadge(record['statusType'] as String),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                record['name'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF131B2E),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildStatusPill(record['status'] as String, record['statusType'] as String),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                record['role'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF4E444A),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text('•', style: TextStyle(color: Colors.grey[400])),
                              const SizedBox(width: 5),
                              Text(
                                record['empId'] as String,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  color: const Color(0xFF80747A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Right: Worked Hours & Sub-tag
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isTracking ? const Color(0xFF00696E) : const Color(0xFF131B2E),
                          ),
                          children: [
                            TextSpan(text: record['hours'] as String),
                            TextSpan(
                              text: ' hrs',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.normal,
                                color: const Color(0xFF4E444A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (record['subTagBg'] as Color).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record['subTag'] as String,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: record['subTagColor'] as Color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Bottom Row: Time Interval Track
              if (!hasActions)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            record['startTime'] as String,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12.5,
                              fontWeight: isStartLate ? FontWeight.bold : FontWeight.w500,
                              color: isStartLate ? const Color(0xFFBA1A1A) : const Color(0xFF131B2E),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward, size: 14, color: Color(0xFF00696E)),
                          ),
                          if (isTracking) ...[
                            Row(
                              children: [
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00696E)),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tracking...',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00696E),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              record['endTime'] as String,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF131B2E),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          if (isPendingExit) ...[
                            Row(
                              children: [
                                const Icon(Icons.notification_important, size: 14, color: Color(0xFFBA1A1A)),
                                const SizedBox(width: 3),
                                Text(
                                  'Pending Exit',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFBA1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Icon(record['locationIcon'] as IconData, size: 14, color: const Color(0xFF00696E)),
                            const SizedBox(width: 4),
                            Text(
                              record['location'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF4E444A),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF80747A)),
                        ],
                      ),
                    ],
                  ),
                ),

              // Action buttons row for absent card
              if (hasActions)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📝 Opening Leave Application dialog for Neha Patel...')),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F3FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.assignment_add, size: 16, color: Color(0xFF00696E)),
                                const SizedBox(width: 6),
                                Text(
                                  'Log Leave',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF131B2E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('🔔 Nudge notification sent to Neha Patel on PeoplePay Mobile!')),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF92EFF5).withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.notifications_active, size: 16, color: Color(0xFF004F53)),
                                const SizedBox(width: 6),
                                Text(
                                  'Send Nudge',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF004F53),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarBadge(String statusType) {
    if (statusType == 'present') {
      return Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(color: Color(0xFF4EDEA3), shape: BoxShape.circle),
        child: const Center(child: Icon(Icons.check, size: 10, color: Color(0xFF002113))),
      );
    } else if (statusType == 'late') {
      return Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(color: Color(0xFFFFDAD6), shape: BoxShape.circle),
        child: const Center(child: Icon(Icons.schedule, size: 10, color: Color(0xFFBA1A1A))),
      );
    } else if (statusType == 'absent') {
      return Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(color: Color(0xFFBA1A1A), shape: BoxShape.circle),
        child: const Center(child: Icon(Icons.close, size: 10, color: Colors.white)),
      );
    } else {
      // onduty
      return Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(color: Color(0xFF92EFF5), shape: BoxShape.circle),
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Color(0xFF00696E), shape: BoxShape.circle),
          ),
        ),
      );
    }
  }

  Widget _buildStatusPill(String status, String statusType) {
    Color bg;
    Color fg;
    Widget? dot;

    if (statusType == 'absent') {
      bg = const Color(0xFFFFDAD6);
      fg = const Color(0xFFBA1A1A);
    } else if (statusType == 'onduty') {
      bg = const Color(0xFF92EFF5).withValues(alpha: 0.4);
      fg = const Color(0xFF004F53);
      dot = Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.only(right: 4),
        decoration: const BoxDecoration(color: Color(0xFF00696E), shape: BoxShape.circle),
      );
    } else {
      bg = const Color(0xFF006443).withValues(alpha: 0.1);
      fg = const Color(0xFF004A31);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?dot,
          Text(
            status,
            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }
}
