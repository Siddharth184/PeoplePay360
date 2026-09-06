import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../widgets/attendance_punch_sheet.dart';
import '../services/attendance_service.dart';
import '../services/mock_data_service.dart';
import '../services/api_client.dart';
import '../models/models.dart';

class AttendanceScreen extends StatefulWidget {
  final void Function(int index)? onNavigateTab;
  const AttendanceScreen({super.key, this.onNavigateTab});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  String? _loadError;
  late String _selectedMonth;
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  bool _isHrTeamView = false;

  List<AttendanceModel> _allAttendances = [];
  final TextEditingController _searchCtrl = TextEditingController();

  late final List<String> _monthOptions = _buildRecentMonths();

  final List<String> _statusFilters = [
    'All',
    'Present',
    'Late',
    'Absent',
    'On Leave',
    'Overtime',
    'Missing Punch',
  ];

  static List<String> _buildRecentMonths() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return DateFormat('MMMM yyyy').format(d);
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    _loadAttendanceData();
    AttendanceService.getPunchStatus();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final String? employeeFilter =
        _isHrTeamView ? null : ApiClient.currentEmployeeId;

    final res = await AttendanceService.getAttendances(
      employeeId: employeeFilter,
      dateFrom: _monthStart(_selectedMonth),
      dateTo: _monthEnd(_selectedMonth),
    );
    if (!mounted) return;

    final offline = res.statusCode == 0 || !ApiClient.isBackendOnline;

    setState(() {
      _isLoading = false;
      if (res.isSuccess && res.data != null) {
        _allAttendances = res.data!;
        _loadError = null;
      } else if (offline) {
        _allAttendances = MockDataService.attendances;
      } else {
        _allAttendances = [];
        _loadError = res.errorMessage ?? 'Could not load attendance records.';
      }
    });
  }

  String _monthStart(String monthStr) {
    final d = _parseMonth(monthStr);
    return DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, 1));
  }

  String _monthEnd(String monthStr) {
    final d = _parseMonth(monthStr);
    final lastDay = DateTime(d.year, d.month + 1, 0);
    return DateFormat('yyyy-MM-dd').format(lastDay);
  }

  DateTime _parseMonth(String monthStr) {
    try {
      return DateFormat('MMMM yyyy').parse(monthStr);
    } catch (_) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, 1);
    }
  }

  String _getMonthPrefix(String monthStr) {
    final d = _parseMonth(monthStr);
    return DateFormat('yyyy-MM').format(d);
  }

  List<AttendanceModel> get _filteredList {
    final prefix = _getMonthPrefix(_selectedMonth);
    return _allAttendances.where((att) {
      // Month filter
      final matchesMonth = att.dateStr.isEmpty || att.dateStr.startsWith(prefix);
      if (!matchesMonth) return false;

      // Status filter
      final statusUpper = att.status.toUpperCase();
      final isMissing = att.checkIn != null &&
          att.checkOutTime == null &&
          statusUpper != 'ON_LEAVE' &&
          statusUpper != 'ABSENT';

      if (_selectedStatusFilter == 'Present' && statusUpper != 'PRESENT') return false;
      if (_selectedStatusFilter == 'Late' && statusUpper != 'LATE') return false;
      if (_selectedStatusFilter == 'Absent' && statusUpper != 'ABSENT') return false;
      if (_selectedStatusFilter == 'On Leave' && statusUpper != 'ON_LEAVE') return false;
      if (_selectedStatusFilter == 'Overtime' && (att.overtimeHours <= 0 && statusUpper != 'OVERTIME')) return false;
      if (_selectedStatusFilter == 'Missing Punch' && !isMissing) return false;

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchDate = att.dateStr.toLowerCase().contains(q);
        final matchEmp = (att.employeeName ?? '').toLowerCase().contains(q);
        if (!matchDate && !matchEmp) return false;
      }

      return true;
    }).toList();
  }

  AttendanceModel? get _todayAttendance {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final att in _allAttendances) {
      if (att.dateStr == todayStr) return att;
    }
    return _allAttendances.isNotEmpty ? _allAttendances.first : null;
  }

  int get _presentDaysCount {
    final prefix = _getMonthPrefix(_selectedMonth);
    return _allAttendances
        .where((a) =>
            (a.dateStr.isEmpty || a.dateStr.startsWith(prefix)) &&
            a.status.toUpperCase() == 'PRESENT')
        .length;
  }

  int get _lateDaysCount {
    final prefix = _getMonthPrefix(_selectedMonth);
    return _allAttendances
        .where((a) =>
            (a.dateStr.isEmpty || a.dateStr.startsWith(prefix)) &&
            a.status.toUpperCase() == 'LATE')
        .length;
  }

  int get _absentDaysCount {
    final prefix = _getMonthPrefix(_selectedMonth);
    return _allAttendances
        .where((a) =>
            (a.dateStr.isEmpty || a.dateStr.startsWith(prefix)) &&
            a.status.toUpperCase() == 'ABSENT')
        .length;
  }

  int get _leaveDaysCount {
    final prefix = _getMonthPrefix(_selectedMonth);
    return _allAttendances
        .where((a) =>
            (a.dateStr.isEmpty || a.dateStr.startsWith(prefix)) &&
            a.status.toUpperCase() == 'ON_LEAVE')
        .length;
  }

  int get _overtimeDaysCount {
    final prefix = _getMonthPrefix(_selectedMonth);
    return _allAttendances
        .where((a) =>
            (a.dateStr.isEmpty || a.dateStr.startsWith(prefix)) &&
            (a.overtimeHours > 0 || a.status.toUpperCase() == 'OVERTIME'))
        .length;
  }

  double get _totalOvertimeHoursSum {
    final prefix = _getMonthPrefix(_selectedMonth);
    double total = 0.0;
    for (final a in _allAttendances) {
      if (a.dateStr.isEmpty || a.dateStr.startsWith(prefix)) {
        total += a.overtimeHours;
      }
    }
    return total;
  }

  double get _totalWorkedHoursSum {
    final prefix = _getMonthPrefix(_selectedMonth);
    double total = 0.0;
    for (final a in _allAttendances) {
      if (a.dateStr.isEmpty || a.dateStr.startsWith(prefix)) {
        total += a.workedHours;
      }
    }
    return total;
  }

  List<AttendanceModel> get _missingPunches {
    final prefix = _getMonthPrefix(_selectedMonth);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _allAttendances.where((a) {
      if (a.checkIn == null || a.dateStr.isEmpty) return false;
      if (!a.dateStr.startsWith(prefix)) return false;
      if (a.dateStr == todayStr) return false;
      final statusUpper = a.status.toUpperCase();
      return a.checkOutTime == null &&
          statusUpper != 'ON_LEAVE' &&
          statusUpper != 'ABSENT';
    }).toList();
  }

  void _openRegularizationModal(AttendanceModel? att) {
    if (ApiClient.hasAttendanceLedgerAccess) {
      _openManualCorrectionSheet(att);
    } else {
      _showAskHrDialog(att);
    }
  }

  void _showAskHrDialog(AttendanceModel? att) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Missing Punch',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          att?.checkOutTime == null && att != null
              ? 'This day has no check-out recorded. Attendance corrections are made by HR. Please ask your HR team to regularize ${att.dateStr}.'
              : 'Attendance corrections are made by HR. Please contact your HR team to regularize this record.',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got it',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF714B67))),
          ),
        ],
      ),
    );
  }

  /// HR-only manual correction sheet with clean, high-contrast semantic chips.
  void _openManualCorrectionSheet(AttendanceModel? att) {
    final baseDate = att?.checkIn?.toLocal() ?? DateTime.now();
    DateTime selectedDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    TimeOfDay checkInTod =
        TimeOfDay.fromDateTime(att?.checkIn?.toLocal() ?? DateTime(0, 1, 1, 9));
    TimeOfDay? checkOutTod = att?.checkOut != null
        ? TimeOfDay.fromDateTime(att!.checkOut!.toLocal())
        : null;
    final reasonCtrl = TextEditingController(text: att?.auditNotes ?? '');
    String status = att?.status ?? 'PRESENT';
    bool submitting = false;

    final targetEmployeeId = att?.employeeId ?? ApiClient.currentEmployeeId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> submit() async {
            if (targetEmployeeId == null || targetEmployeeId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('This record has no employee to correct.')),
              );
              return;
            }
            DateTime combine(TimeOfDay t) => DateTime(
                selectedDate.year, selectedDate.month, selectedDate.day, t.hour, t.minute);

            final checkInDt = combine(checkInTod);
            final checkOutDt = checkOutTod != null ? combine(checkOutTod!) : null;
            if (checkOutDt != null && checkOutDt.isBefore(checkInDt)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Check-out cannot be before check-in.')),
              );
              return;
            }

            setSheet(() => submitting = true);
            final res = await AttendanceService.upsertManualAttendance(
              employeeId: targetEmployeeId,
              checkIn: checkInDt.toUtc().toIso8601String(),
              checkOut: checkOutDt?.toUtc().toIso8601String(),
              status: status,
              auditNotes: reasonCtrl.text.trim().isEmpty
                  ? 'Manual correction'
                  : reasonCtrl.text.trim(),
              attendanceId: att?.id,
            );
            if (!mounted) return;
            setSheet(() => submitting = false);

            if (res.isSuccess) {
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    'Attendance saved for ${DateFormat('dd MMM yyyy').format(selectedDate)}.',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  ),
                ),
              );
              _loadAttendanceData();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    res.statusCode == 0
                        ? 'Could not sync attendance. Please try again.'
                        : (res.errorMessage ?? 'Could not save attendance.'),
                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  ),
                ),
              );
            }
          }

          Widget pickerTile({
            required String label,
            required String value,
            required IconData icon,
            required VoidCallback onTap,
            VoidCallback? onClear,
          }) {
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF714B67).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 18, color: const Color(0xFF714B67)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onClear != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: onClear,
                        tooltip: 'Clear',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            );
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        att == null ? 'Manual Attendance (HR)' : 'Correct Attendance (HR)',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    att?.employeeName != null
                        ? 'Editing record for ${att!.employeeName}'
                        : 'Recorded directly to backend ledger with audit trail.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 18),

                  pickerTile(
                    label: 'DATE',
                    value: DateFormat('dd MMMM yyyy').format(selectedDate),
                    icon: Icons.calendar_today_rounded,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setSheet(() => selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: pickerTile(
                          label: 'CHECK-IN',
                          value: checkInTod.format(ctx),
                          icon: Icons.login_rounded,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: checkInTod,
                            );
                            if (picked != null) setSheet(() => checkInTod = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: pickerTile(
                          label: 'CHECK-OUT',
                          value: checkOutTod?.format(ctx) ?? 'Not set',
                          icon: Icons.logout_rounded,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: checkOutTod ?? const TimeOfDay(hour: 18, minute: 0),
                            );
                            if (picked != null) setSheet(() => checkOutTod = picked);
                          },
                          onClear: checkOutTod != null ? () => setSheet(() => checkOutTod = null) : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'STATUS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // High contrast semantic status chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCorrectionStatusChip(
                        label: 'PRESENT',
                        isSelected: status == 'PRESENT',
                        activeBg: const Color(0xFF10B981),
                        onTap: () => setSheet(() => status = 'PRESENT'),
                      ),
                      _buildCorrectionStatusChip(
                        label: 'LATE',
                        isSelected: status == 'LATE',
                        activeBg: const Color(0xFFF59E0B),
                        onTap: () => setSheet(() => status = 'LATE'),
                      ),
                      _buildCorrectionStatusChip(
                        label: 'OVERTIME',
                        isSelected: status == 'OVERTIME',
                        activeBg: const Color(0xFF8B5CF6),
                        onTap: () => setSheet(() => status = 'OVERTIME'),
                      ),
                      _buildCorrectionStatusChip(
                        label: 'ABSENT',
                        isSelected: status == 'ABSENT',
                        activeBg: const Color(0xFFEF4444),
                        onTap: () => setSheet(() => status = 'ABSENT'),
                      ),
                      _buildCorrectionStatusChip(
                        label: 'HALF_DAY',
                        isSelected: status == 'HALF_DAY',
                        activeBg: const Color(0xFF714B67),
                        onTap: () => setSheet(() => status = 'HALF_DAY'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AUDIT NOTE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Why is this record being edited by hand?',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: const Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF714B67), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF714B67),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: submitting ? null : submit,
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        submitting ? 'Saving...' : 'Save Attendance',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCorrectionStatusChip({
    required String label,
    required bool isSelected,
    required Color activeBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeBg : const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canAccessHrLedger = ApiClient.hasAttendanceLedgerAccess;
    final missingPunches = _missingPunches;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mobile-first responsive header bar
                    _buildHeaderBar(canAccessHrLedger),

                    const SizedBox(height: 16),

                    // Error info banner if any
                    if (_loadError != null) ...[
                      _buildInfoBanner(
                        icon: Icons.error_outline_rounded,
                        color: const Color(0xFFEF4444),
                        bg: const Color(0xFFFEE2E2),
                        message: _loadError!,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Action Needed Alert (Only if verified missing punch exists)
                    if (missingPunches.isNotEmpty) ...[
                      _buildAlertBanner(missingPunches.first),
                      const SizedBox(height: 16),
                    ],

                    // Today's Attendance Status Overview Card
                    _buildTodayAttendanceCard(),

                    const SizedBox(height: 16),

                    // Monthly Summary Metrics Grid
                    _buildMonthlySummaryGrid(),

                    const SizedBox(height: 18),

                    // Filter Toolbar (Month + Search + Status Chips)
                    _buildFilterToolbar(),

                    const SizedBox(height: 14),

                    // Attendance Records (Day Cards on Mobile, Table on Desktop)
                    _buildAttendanceContent(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required Color color,
    required Color bg,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Responsive Header Bar: Never squishes title into 1 character per line!
  Widget _buildHeaderBar(bool canAccessHrLedger) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;

        final titleSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isHrTeamView ? 'Team Attendance Ledger' : 'My Attendance Ledger',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _isHrTeamView
                  ? 'All department & team attendance logs'
                  : 'Personal attendance logs & monthly summary',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        );

        final controlsSection = Row(
          mainAxisSize: isDesktop ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (canAccessHrLedger) ...[
              Container(
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_isHrTeamView) {
                          setState(() => _isHrTeamView = false);
                          _loadAttendanceData();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: !_isHrTeamView ? const Color(0xFF714B67) : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'My Logs',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: !_isHrTeamView ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (!_isHrTeamView) {
                          setState(() => _isHrTeamView = true);
                          _loadAttendanceData();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isHrTeamView ? const Color(0xFF714B67) : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'Team Ledger',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _isHrTeamView ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],

            if (!isDesktop) const Spacer(),

            ValueListenableBuilder<PunchState>(
              valueListenable: AttendanceService.stateNotifier,
              builder: (context, punchState, _) {
                final isPunchedIn = punchState.isPunchedIn;
                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPunchedIn
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF017E84),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    AttendancePunchSheet.show(
                      context,
                      onPunchComplete: _loadAttendanceData,
                    );
                  },
                  icon: Icon(
                    isPunchedIn ? Icons.stop_circle_outlined : Icons.touch_app_outlined,
                    size: 16,
                  ),
                  label: Text(
                    isPunchedIn ? 'Punch Out' : 'Punch Clock',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        );

        if (isDesktop) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleSection),
              const SizedBox(width: 16),
              controlsSection,
            ],
          );
        }

        // Mobile layout: Stacks title and controls cleanly
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleSection,
            const SizedBox(height: 12),
            controlsSection,
          ],
        );
      },
    );
  }

  Widget _buildAlertBanner(AttendanceModel missingAtt) {
    String dateLabel = missingAtt.dateStr;
    final dt = DateTime.tryParse(missingAtt.dateStr);
    if (dt != null) {
      dateLabel = DateFormat('dd MMM yyyy').format(dt);
    }

    final checkInDisplay = missingAtt.checkInTime.isNotEmpty && missingAtt.checkInTime != '--'
        ? ' (Checked in at ${missingAtt.checkInTime})'
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missing Check-Out Action Required',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No check-out recorded for $dateLabel$checkInDisplay.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: const Color(0xFF78350F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _openRegularizationModal(missingAtt),
            child: Text(
              'Regularize',
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayAttendanceCard() {
    final today = _todayAttendance;
    final isCheckedIn = today != null && today.checkOutTime == null;
    final isDoneToday = today != null && today.checkOutTime != null;

    final String statusLabel = isCheckedIn
        ? 'IN OFFICE'
        : (isDoneToday ? today.status : 'NOT PUNCHED');
    final Color statusColor = isCheckedIn
        ? const Color(0xFF017E84)
        : (isDoneToday ? const Color(0xFF10B981) : const Color(0xFF714B67));
    final Color statusBg = isCheckedIn
        ? const Color(0xFFE6F4F4)
        : (isDoneToday ? const Color(0xFFECFDF5) : const Color(0xFFF5F3F7));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF714B67).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.today_rounded, size: 16, color: Color(0xFF714B67)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Today's Shift",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.login_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: 'Check-In',
                  value: today?.checkInTime ?? '--:--',
                ),
              ),
              Container(width: 1, height: 34, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.logout_rounded,
                  iconColor: const Color(0xFFEF4444),
                  label: 'Check-Out',
                  value: today?.checkOutTime ?? (isCheckedIn ? 'Active' : '--:--'),
                ),
              ),
              Container(width: 1, height: 34, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.timer_outlined,
                  iconColor: const Color(0xFF017E84),
                  label: 'Worked',
                  value: today != null ? '${today.workedHours.toStringAsFixed(1)} hrs' : '0.0 hrs',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              AttendancePunchSheet.show(
                context,
                onPunchComplete: _loadAttendanceData,
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCheckedIn ? Icons.access_time_filled : Icons.touch_app_rounded,
                    size: 14,
                    color: const Color(0xFF714B67),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isCheckedIn
                          ? 'Shift active. Tap to view timer or punch out →'
                          : 'Tap here to punch in or register shift →',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF714B67),
                      ),
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

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummaryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile 3x2 grid layout
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Present Days',
                      '${_presentDaysCount}d',
                      Icons.check_circle_outline,
                      const Color(0xFF10B981),
                      const Color(0xFFECFDF5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard(
                      'Late Days',
                      '${_lateDaysCount}d',
                      Icons.access_time_rounded,
                      const Color(0xFFF59E0B),
                      const Color(0xFFFEF3C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Absent Days',
                      '${_absentDaysCount}d',
                      Icons.cancel_outlined,
                      const Color(0xFFEF4444),
                      const Color(0xFFFEE2E2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard(
                      'On Leave',
                      '${_leaveDaysCount}d',
                      Icons.beach_access_outlined,
                      const Color(0xFF3B82F6),
                      const Color(0xFFEFF6FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Overtime',
                      '${_overtimeDaysCount}d (${_totalOvertimeHoursSum.toStringAsFixed(1)}h)',
                      Icons.more_time_rounded,
                      const Color(0xFF8B5CF6),
                      const Color(0xFFF5F3FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Worked',
                      '${_totalWorkedHoursSum.toStringAsFixed(1)} hrs',
                      Icons.schedule_rounded,
                      const Color(0xFF017E84),
                      const Color(0xFFE6F4F4),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        // Desktop 6-card row
        return Row(
          children: [
            Expanded(child: _buildSummaryCard('Present Days', '${_presentDaysCount}d', Icons.check_circle_outline, const Color(0xFF10B981), const Color(0xFFECFDF5))),
            const SizedBox(width: 10),
            Expanded(child: _buildSummaryCard('Late Days', '${_lateDaysCount}d', Icons.access_time_rounded, const Color(0xFFF59E0B), const Color(0xFFFEF3C7))),
            const SizedBox(width: 10),
            Expanded(child: _buildSummaryCard('Absent Days', '${_absentDaysCount}d', Icons.cancel_outlined, const Color(0xFFEF4444), const Color(0xFFFEE2E2))),
            const SizedBox(width: 10),
            Expanded(child: _buildSummaryCard('On Leave', '${_leaveDaysCount}d', Icons.beach_access_outlined, const Color(0xFF3B82F6), const Color(0xFFEFF6FF))),
            const SizedBox(width: 10),
            Expanded(child: _buildSummaryCard('Overtime', '${_overtimeDaysCount}d (${_totalOvertimeHoursSum.toStringAsFixed(1)}h)', Icons.more_time_rounded, const Color(0xFF8B5CF6), const Color(0xFFF5F3FF))),
            const SizedBox(width: 10),
            Expanded(child: _buildSummaryCard('Total Hours', '${_totalWorkedHoursSum.toStringAsFixed(1)}h', Icons.schedule_rounded, const Color(0xFF017E84), const Color(0xFFE6F4F4))),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color bg, {
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: isFullWidth
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                      child: Icon(icon, size: 16, color: color),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                      child: Icon(icon, size: 14, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterToolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Month Dropdown Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  icon: const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF714B67)),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  onChanged: (val) {
                    if (val != null && val != _selectedMonth) {
                      setState(() => _selectedMonth = val);
                      _loadAttendanceData();
                    }
                  },
                  items: _monthOptions.map((m) {
                    return DropdownMenuItem<String>(
                      value: m,
                      child: Text(m),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Search Bar
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel, size: 16, color: Color(0xFF64748B)),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    hintText: 'Search date or remarks...',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _statusFilters.map((filter) {
              final isSelected = _selectedStatusFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  selectedColor: const Color(0xFF714B67),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF714B67) : const Color(0xFFCBD5E1),
                  ),
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedStatusFilter = filter);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceContent() {
    final list = _filteredList;

    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 44, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              'No attendance records found',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No matching attendance logs for the selected month or filter.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          // Mobile: Clean, touch-friendly day cards
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (c, i) => const SizedBox(height: 10),
            itemBuilder: (ctx, index) {
              return _buildMobileAttendanceCard(list[index]);
            },
          );
        }

        // Desktop: Generous Data Table
        return _buildDesktopTable(list);
      },
    );
  }

  Widget _buildMobileAttendanceCard(AttendanceModel att) {
    DateTime? dt = DateTime.tryParse(att.dateStr);
    String dayNumber = '';
    String monthDay = att.dateStr;
    if (dt != null) {
      dayNumber = DateFormat('dd').format(dt);
      monthDay = DateFormat('MMM, EEE').format(dt);
    }

    final isMissing = att.checkIn != null &&
        att.checkOutTime == null &&
        att.status.toUpperCase() != 'ON_LEAVE' &&
        att.status.toUpperCase() != 'ABSENT';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Date Block + Status Badge + Action
          Row(
            children: [
              // Date badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      dayNumber.isNotEmpty ? dayNumber : '--',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      monthDay,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Status badge & Employee Name (if HR view)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isHrTeamView && att.employeeName != null) ...[
                      Text(
                        att.employeeName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    _buildStatusBadge(att.status, isMissingPunch: isMissing),
                  ],
                ),
              ),

              // Action buttons (HR edit or Regularize)
              if (ApiClient.hasAttendanceLedgerAccess)
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF714B67)),
                  tooltip: 'Correct Record',
                  onPressed: () => _openManualCorrectionSheet(att),
                )
              else if (isMissing)
                TextButton(
                  onPressed: () => _openRegularizationModal(att),
                  child: Text(
                    'Regularize',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Bottom Row: Times and Worked Duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimeSubMetric(
                label: 'IN',
                value: att.checkInTime.isNotEmpty ? att.checkInTime : '--:--',
                color: const Color(0xFF10B981),
              ),
              _buildTimeSubMetric(
                label: 'OUT',
                value: att.checkOutTime ?? (att.status.toUpperCase() == 'PRESENT' && att.workedHours > 0 ? '--:--' : 'Tracking...'),
                color: att.checkOutTime == null ? const Color(0xFFD97706) : const Color(0xFF64748B),
              ),
              _buildTimeSubMetric(
                label: 'WORKED',
                value: '${att.workedHours.toStringAsFixed(1)}h',
                color: const Color(0xFF017E84),
              ),
              if (att.overtimeHours > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${att.overtimeHours.toStringAsFixed(1)}h OT',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSubMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(List<AttendanceModel> list) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('DATE & DAY', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
                if (_isHrTeamView)
                  Expanded(flex: 3, child: Text('EMPLOYEE', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('CHECK IN', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('CHECK OUT', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('WORKED', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('STATUS', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('ACTION', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
            itemBuilder: (ctx, index) {
              final att = list[index];
              return _buildTableRow(att);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(AttendanceModel att) {
    DateTime? dt = DateTime.tryParse(att.dateStr);
    String dateFormatted = att.dateStr;
    String dayFormatted = '';
    if (dt != null) {
      dateFormatted = DateFormat('dd MMM yyyy').format(dt);
      dayFormatted = DateFormat('EEE').format(dt);
    }

    final isMissing = att.checkIn != null &&
        att.checkOutTime == null &&
        att.status.toUpperCase() != 'ON_LEAVE' &&
        att.status.toUpperCase() != 'ABSENT';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormatted,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                Text(
                  dayFormatted,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          if (_isHrTeamView)
            Expanded(
              flex: 3,
              child: Text(
                att.employeeName ?? '--',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              ),
            ),

          Expanded(
            flex: 2,
            child: Text(
              att.checkInTime.isNotEmpty ? att.checkInTime : '--:--',
              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              att.checkOutTime ?? (att.status.toUpperCase() == 'PRESENT' && att.workedHours > 0 ? '--:--' : 'Tracking...'),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: att.checkOutTime == null ? const Color(0xFFD97706) : const Color(0xFF0F172A),
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              '${att.workedHours.toStringAsFixed(1)} hrs',
              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF017E84)),
            ),
          ),

          Expanded(
            flex: 2,
            child: _buildStatusBadge(att.status, isMissingPunch: isMissing),
          ),

          Expanded(
            flex: 2,
            child: Row(
              children: [
                if (ApiClient.hasAttendanceLedgerAccess)
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF714B67)),
                    tooltip: 'Edit',
                    onPressed: () => _openManualCorrectionSheet(att),
                  )
                else if (isMissing)
                  IconButton(
                    icon: const Icon(Icons.build_circle_outlined, size: 18, color: Color(0xFFD97706)),
                    tooltip: 'Ask HR to Regularize',
                    onPressed: () => _openRegularizationModal(att),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String rawStatus, {bool isMissingPunch = false}) {
    if (isMissingPunch) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'MISSING PUNCH',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD97706),
          ),
        ),
      );
    }

    final status = rawStatus.toUpperCase();
    String label = 'PRESENT';
    Color color = const Color(0xFF10B981);
    Color bg = const Color(0xFFECFDF5);

    if (status == 'LATE') {
      label = 'LATE';
      color = const Color(0xFFF59E0B);
      bg = const Color(0xFFFEF3C7);
    } else if (status == 'OVERTIME') {
      label = 'OVERTIME';
      color = const Color(0xFF8B5CF6);
      bg = const Color(0xFFF5F3FF);
    } else if (status == 'ABSENT') {
      label = 'ABSENT';
      color = const Color(0xFFEF4444);
      bg = const Color(0xFFFEE2E2);
    } else if (status == 'ON_LEAVE') {
      label = 'ON LEAVE';
      color = const Color(0xFF3B82F6);
      bg = const Color(0xFFEFF6FF);
    } else if (status == 'HALF_DAY') {
      label = 'HALF DAY';
      color = const Color(0xFF714B67);
      bg = const Color(0xFFF5F3F7);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
