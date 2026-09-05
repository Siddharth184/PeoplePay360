import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/mock_data_service.dart';
import '../services/dashboard_service.dart';
import '../services/api_client.dart';
import '../models/models.dart';
import '../widgets/analytics_pdf_dialog.dart';

class AnalyticsScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const AnalyticsScreen({super.key, this.onNavigateTab});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _DeptCostData {
  final String deptName;
  final String deptCode;
  final int staffCount;
  final double totalWage;
  final double avgSalary;
  final double percentShare;
  final Color barColor;

  _DeptCostData({
    required this.deptName,
    required this.deptCode,
    required this.staffCount,
    required this.totalWage,
    required this.avgSalary,
    required this.percentShare,
    required this.barColor,
  });
}

class _TrendPointData {
  final String monthLabel;
  final double totalNetPaid;
  final String displayVal;
  final bool isPeak;

  _TrendPointData({
    required this.monthLabel,
    required this.totalNetPaid,
    required this.displayVal,
    required this.isPeak,
  });
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _refreshAnimController;

  // Active Filters
  String _selectedPeriod = 'Sep 2026';
  String _selectedDept = 'All';
  String _selectedType = 'All Staff';
  String _selectedEntity = 'OXP Pvt Ltd';

  // Dynamic Calculated Metrics
  bool _isLoading = false;
  double _totalGrossSalary = 2100000.0;
  double _totalNetSalary = 1840000.0;
  int _totalPayslipsCount = 148;
  int _pendingPayslipsCount = 6;
  int _paidPayslipsCount = 142;
  double _avgCompensation = 12432.0;
  int _approvedLeavesDays = 34;
  double _attendanceHealthPercent = 94.2;

  // Operational Attendance Mini Box Counts
  int _presentCount = 94;
  int _lateCount = 18;
  int _absentCount = 9;
  int _overtimeCount = 22;
  int _missingPunchesCount = 5;

  // Anomalies / Audit Counts
  int _missingBankDetailsCount = 2;
  int _duplicateEntriesCount = 1;
  int _unvalidatedDraftsCount = 4;

  // Dynamic Lists
  List<_DeptCostData> _departmentSpendList = [];
  List<_DeptCostData> _departmentMatrixList = [];
  List<_TrendPointData> _trendDataList = [];

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadBackendAnalytics();
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
    super.dispose();
  }

  String _formatCurrencyCompact(double amount) {
    if (amount >= 100000) {
      final lakhs = amount / 100000;
      return '${lakhs.toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      final k = amount / 1000;
      return '${k.toStringAsFixed(1)}k';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  /// Converts a period label like 'Sep 2026' into a 'YYYY-MM' prefix
  /// ('2026-09') used to match against attendance `dateStr` values.
  /// Returns null if the label cannot be parsed, meaning "no period filter".
  String? _monthPrefix(String periodLabel) {
    const monthMap = {
      'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
      'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
      'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
    };
    final parts = periodLabel.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final mon = monthMap[parts[0].toLowerCase()];
    final year = parts[1];
    if (mon == null || year.length != 4) return null;
    return '$year-$mon';
  }

  void _computeMetrics() {
    final allEmps = MockDataService.allEmployees;
    final allContracts = MockDataService.contracts;
    final allAttendance = MockDataService.attendances;
    final allLeaves = MockDataService.timeOffRequests;

    // Filter employees by department & type
    final filteredEmps = allEmps.where((emp) {
      if (_selectedDept != 'All' && !emp.department.toLowerCase().contains(_selectedDept.toLowerCase())) {
        return false;
      }
      if (_selectedType != 'All Staff' && emp.employeeType != null && !emp.employeeType!.toLowerCase().contains(_selectedType.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    final scopeEmps = filteredEmps.isEmpty ? allEmps : filteredEmps;

    // Group employees & contracts by department
    final Map<String, List<EmployeeModel>> deptMap = {};
    for (final emp in scopeEmps) {
      final dName = emp.department.isNotEmpty ? emp.department : 'General Staff';
      deptMap.putIfAbsent(dName, () => []).add(emp);
    }

    double overallWageBill = 0.0;
    final List<_DeptCostData> deptCosts = [];
    final colors = [
      const Color(0xFF714B67),
      const Color(0xFF57344F),
      const Color(0xFF00696E),
      const Color(0xFF78D5DB),
      const Color(0xFF004A31),
      const Color(0xFF93000A),
    ];

    int colorIdx = 0;
    deptMap.forEach((dept, emps) {
      double deptWage = 0.0;
      for (final emp in emps) {
        final c = allContracts.firstWhere(
          (con) => con.employeeName.toLowerCase().contains(emp.name.toLowerCase().split(' ').first),
          orElse: () => ContractModel(
            id: 'fallback',
            refCode: '',
            employeeName: emp.name,
            department: dept,
            startDate: '2024-01-01',
            wageMonthly: 85000.0,
            status: 'RUNNING',
          ),
        );
        deptWage += c.wageMonthly;
      }
      overallWageBill += deptWage;

      final parts = dept.split(RegExp(r'\s+'));
      final code = parts.map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

      deptCosts.add(_DeptCostData(
        deptName: dept,
        deptCode: code.isNotEmpty ? code : 'DP',
        staffCount: emps.length,
        totalWage: deptWage,
        avgSalary: emps.isNotEmpty ? deptWage / emps.length : 0.0,
        percentShare: 0.0,
        barColor: colors[colorIdx % colors.length],
      ));
      colorIdx++;
    });

    final finalDeptCosts = deptCosts.map((d) {
      final share = overallWageBill > 0 ? (d.totalWage / overallWageBill) : 0.0;
      return _DeptCostData(
        deptName: d.deptName,
        deptCode: d.deptCode,
        staffCount: d.staffCount,
        totalWage: d.totalWage,
        avgSalary: d.avgSalary,
        percentShare: share,
        barColor: d.barColor,
      );
    }).toList();

    finalDeptCosts.sort((a, b) => b.totalWage.compareTo(a.totalWage));

    // Attendance stats — filtered by the active Department / Type / Period pills
    // so the counts update in real time when any filter changes.

    // Set of employee names in the currently selected dept/type cohort. When the
    // dept/type filters are 'All' this contains every employee, so nothing is
    // excluded. Matching is done on the first name to tolerate small naming
    // differences between the employee list and the attendance logs.
    final Set<String> scopeEmpKeys = {};
    for (final emp in scopeEmps) {
      final first = emp.name.toLowerCase().trim().split(RegExp(r'\s+')).first;
      if (first.isNotEmpty) scopeEmpKeys.add(first);
    }
    final bool deptOrTypeFiltered = _selectedDept != 'All' || _selectedType != 'All Staff';

    // Month prefix like '2026-09' derived from the selected period ('Sep 2026').
    final String? periodPrefix = _monthPrefix(_selectedPeriod);

    bool matchesScope(AttendanceModel log) {
      // Period (month) filter
      if (periodPrefix != null && !log.dateStr.startsWith(periodPrefix)) {
        return false;
      }
      // Department / employee-type filter (via the employee cohort)
      if (deptOrTypeFiltered) {
        final name = (log.employeeName ?? '').toLowerCase().trim();
        if (name.isEmpty) return false;
        final first = name.split(RegExp(r'\s+')).first;
        if (!scopeEmpKeys.contains(first)) return false;
      }
      return true;
    }

    final scopedAttendance = allAttendance.where(matchesScope).toList();

    int pres = 0;
    int late = 0;
    int abs = 0;
    int ot = 0;
    int missed = 0;

    for (final log in scopedAttendance) {
      final st = log.status.toUpperCase();
      if (st.contains('PRESENT')) pres++;
      if (st.contains('LATE')) late++;
      if (st.contains('ABSENT')) abs++;
      if (log.workedHours > 9.0 || st.contains('OVERTIME')) ot++;
      if (st.contains('MISSED') || log.checkOutTime == null || log.checkOutTime == '—') missed++;
    }

    // Whether the current filter selection actually produced any attendance rows.
    // Used below to decide between showing real filtered zeros vs. seed defaults.
    final bool hasScopedAttendance = scopedAttendance.isNotEmpty;

    final totalAtt = pres + late + abs;
    final attHealth = totalAtt > 0 ? ((pres + late) / totalAtt * 100.0) : 94.2;

    // Anomalies
    final noBank = allEmps.where((e) => e.bankAccountNumber == null || e.bankAccountNumber!.isEmpty).length;
    final drafts = allContracts.where((c) => c.status == 'DRAFT').length;

    // Rolling 6 months trend
    final months = ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'];
    final factors = [0.80, 0.83, 0.78, 0.82, 0.93, 1.0];
    final List<_TrendPointData> trendPoints = [];

    double maxNetVal = 0.0;
    for (int i = 0; i < months.length; i++) {
      final mVal = overallWageBill * 0.88 * factors[i];
      if (mVal > maxNetVal) maxNetVal = mVal;
    }

    for (int i = 0; i < months.length; i++) {
      final mVal = overallWageBill * 0.88 * factors[i];
      trendPoints.add(_TrendPointData(
        monthLabel: months[i],
        totalNetPaid: mVal,
        displayVal: '₹${_formatCurrencyCompact(mVal)}',
        isPeak: mVal == maxNetVal,
      ));
    }

    setState(() {
      _totalGrossSalary = overallWageBill;
      _totalNetSalary = overallWageBill * 0.88;
      _totalPayslipsCount = scopeEmps.length * 12;
      _pendingPayslipsCount = drafts > 0 ? drafts + 2 : 6;
      _paidPayslipsCount = _totalPayslipsCount - _pendingPayslipsCount;
      _avgCompensation = scopeEmps.isNotEmpty ? (overallWageBill / scopeEmps.length) : 12432.0;
      _approvedLeavesDays = (allLeaves.where((l) => l.status == 'APPROVED').length * 4) + 10;
      _attendanceHealthPercent = attHealth;

      // When the scoped query returned real rows we show the exact counts —
      // including legitimate zeros — so the filters reflect reality. Only when
      // there is genuinely no data at all do we fall back to seed placeholders.
      if (hasScopedAttendance) {
        _presentCount = pres;
        _lateCount = late;
        _absentCount = abs;
        _overtimeCount = ot;
        _missingPunchesCount = missed;
      } else {
        _presentCount = 0;
        _lateCount = 0;
        _absentCount = 0;
        _overtimeCount = 0;
        _missingPunchesCount = 0;
      }

      _missingBankDetailsCount = noBank > 0 ? noBank : 2;
      _unvalidatedDraftsCount = drafts > 0 ? drafts : 4;
      _duplicateEntriesCount = 1;

      _departmentSpendList = finalDeptCosts;
      _departmentMatrixList = finalDeptCosts;
      _trendDataList = trendPoints;
    });
  }

  Future<void> _loadBackendAnalytics() async {
    setState(() => _isLoading = true);

    if (!ApiClient.isBackendOnline) {
      _computeMetrics();
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final metricsRes = await DashboardService.getMetrics();
      if (metricsRes.isSuccess && metricsRes.data != null) {
        final data = metricsRes.data!;
        final kpis = data['kpi'] as Map<String, dynamic>? ?? {};

        final gross = (kpis['total_gross_salary'] is num) ? (kpis['total_gross_salary'] as num).toDouble() : 0.0;
        final net = (kpis['total_net_salary'] is num) ? (kpis['total_net_salary'] as num).toDouble() : 0.0;
        final totalSlips = (kpis['total_payslips_count'] is num) ? (kpis['total_payslips_count'] as num).toInt() : 0;
        final pendingSlips = (kpis['pending_payslips_count'] is num) ? (kpis['pending_payslips_count'] as num).toInt() : 0;
        final paidSlips = (kpis['paid_payslips_count'] is num) ? (kpis['paid_payslips_count'] as num).toInt() : 0;
        final avgComp = (kpis['avg_compensation'] is num) ? (kpis['avg_compensation'] as num).toDouble() : 0.0;
        final leaveDays = (kpis['approved_leaves_days'] is num) ? (kpis['approved_leaves_days'] as num).toInt() : 0;
        final attHealth = (kpis['attendance_health_percent'] is num) ? (kpis['attendance_health_percent'] as num).toDouble() : 0.0;

        final att = data['attendance_overview'] as Map<String, dynamic>? ?? {};
        final pres = (att['present_count'] is num) ? (att['present_count'] as num).toInt() : 0;
        final lateVal = (att['late_count'] is num) ? (att['late_count'] as num).toInt() : 0;
        final absVal = (att['absent_count'] is num) ? (att['absent_count'] as num).toInt() : 0;
        final otVal = (att['overtime_count'] is num) ? (att['overtime_count'] as num).toInt() : 0;
        final missedVal = (att['missing_punches_count'] is num) ? (att['missing_punches_count'] as num).toInt() : 0;

        final colors = [
          const Color(0xFF714B67),
          const Color(0xFF57344F),
          const Color(0xFF00696E),
          const Color(0xFF78D5DB),
          const Color(0xFF004A31),
          const Color(0xFF93000A),
        ];

        final rawCosts = data['department_costs'] as List? ?? [];
        int colorIdx = 0;
        final List<_DeptCostData> parsedCosts = [];
        for (final item in rawCosts) {
          if (item is Map<String, dynamic>) {
            final name = item['department_name']?.toString() ?? 'Department';
            final code = item['department_code']?.toString() ?? 'DP';
            final staff = item['staff_count'] is num ? (item['staff_count'] as num).toInt() : 0;
            final wage = item['total_wage'] is num ? (item['total_wage'] as num).toDouble() : 0.0;
            final avg = item['avg_salary'] is num ? (item['avg_salary'] as num).toDouble() : 0.0;
            final share = item['percent_share'] is num ? (item['percent_share'] as num).toDouble() : 0.0;

            parsedCosts.add(_DeptCostData(
              deptName: name,
              deptCode: code,
              staffCount: staff,
              totalWage: wage,
              avgSalary: avg,
              percentShare: share,
              barColor: colors[colorIdx % colors.length],
            ));
            colorIdx++;
          }
        }

        final rawTrend = data['payroll_trend'] as List? ?? [];
        final List<_TrendPointData> parsedTrend = [];
        double maxNet = 0.0;
        for (final item in rawTrend) {
          if (item is Map<String, dynamic>) {
            final n = item['total_net_paid'] is num ? (item['total_net_paid'] as num).toDouble() : 0.0;
            if (n > maxNet) maxNet = n;
          }
        }

        for (final item in rawTrend) {
          if (item is Map<String, dynamic>) {
            final label = item['month_label']?.toString() ?? '';
            final n = item['total_net_paid'] is num ? (item['total_net_paid'] as num).toDouble() : 0.0;
            parsedTrend.add(_TrendPointData(
              monthLabel: label,
              totalNetPaid: n,
              displayVal: '₹${_formatCurrencyCompact(n)}',
              isPeak: maxNet > 0 && n == maxNet,
            ));
          }
        }

        if (mounted) {
          setState(() {
            _totalGrossSalary = gross;
            _totalNetSalary = net;
            _totalPayslipsCount = totalSlips;
            _pendingPayslipsCount = pendingSlips;
            _paidPayslipsCount = paidSlips;
            _avgCompensation = avgComp;
            _approvedLeavesDays = leaveDays;
            _attendanceHealthPercent = attHealth;

            _presentCount = pres;
            _lateCount = lateVal;
            _absentCount = absVal;
            _overtimeCount = otVal;
            _missingPunchesCount = missedVal;

            if (parsedCosts.isNotEmpty) {
              _departmentSpendList = parsedCosts;
              _departmentMatrixList = parsedCosts;
            }
            if (parsedTrend.isNotEmpty) {
              _trendDataList = parsedTrend;
            }
          });
        }
      } else {
        _computeMetrics();
      }
    } catch (_) {
      _computeMetrics();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }


  void _triggerRefresh() {
    _refreshAnimController.forward(from: 0.0);
    _loadBackendAnalytics();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Live Analytics synced with OXP Core Ledger ($_selectedPeriod)',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00696E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showExportPdfSuccess() {
    showDialog(
      context: context,
      builder: (context) => AnalyticsPdfDialog(
        period: _selectedPeriod,
        department: _selectedDept,
        employeeType: _selectedType,
        corporateEntity: _selectedEntity,
        totalGrossSalary: _totalGrossSalary,
        netSalaryPaid: _totalNetSalary,
        avgCompensation: _avgCompensation,
        attendanceHealth: _attendanceHealthPercent,
        departmentCosts: _departmentSpendList,
      ),
    );
  }

  void _showPickerSheet(String title, List<String> options, String currentVal, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          top: 16,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF131B2E),
                ),
              ),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final isSel = opt == currentVal;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  title: Text(
                    opt,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel ? const Color(0xFF714B67) : const Color(0xFF131B2E),
                    ),
                  ),
                  trailing: isSel ? const Icon(Icons.check_circle_rounded, color: Color(0xFF714B67)) : null,
                  onTap: () {
                    Navigator.pop(context);
                    onSelect(opt);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Top Navigation & Live Sync Status
                  _buildTopHeader(),
                  const SizedBox(height: 14),

                  // Horizontal Scrollable Filter Bar
                  _buildFilterBar(),
                  const SizedBox(height: 16),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(color: Color(0xFF714B67), backgroundColor: Color(0xFFE2E7FF)),
                    ),

                  // Period Highlights Carousel Header & Ribbon
                  _buildCarouselHeader(),
                  const SizedBox(height: 8),
                  _buildHighlightsCarousel(),
                  const SizedBox(height: 16),

                  // Operational Health & Anomalies Quick Glance (Dual Cards)
                  _buildOperationalDualCards(),
                  const SizedBox(height: 16),

                  // Interactive Chart A: Salary Cost by Department
                  _buildDepartmentSpendCard(),
                  const SizedBox(height: 16),

                  // Interactive Chart B: Monthly Net Salary Trend (Last 6 Months)
                  _buildSalaryTrendCard(),
                  const SizedBox(height: 16),

                  // Department Master Table / Breakdown
                  _buildDepartmentMatrixCard(),
                  const SizedBox(height: 16),

                  // Executive Audit Summary Banner
                  _buildAuditSignOffBanner(),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Sticky Bottom Floating Ribbon
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildStickyBottomRibbon(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.onNavigateTab == null && Navigator.canPop(context)) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final route = ModalRoute.of(context);
                if (route != null && !route.isFirst) {
                  Navigator.pop(context);
                } else if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(-1);
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
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
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00696E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'EXECUTIVE HR COST ANALYTICS',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00696E),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Executive Analytics',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF131B2E),
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'PeoplePay360 • Cross-Model Command Center',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF4E444A),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 1,
                shadowColor: Colors.black12,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _triggerRefresh,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: RotationTransition(
                      turns: _refreshAnimController,
                      child: const Icon(
                        Icons.sync_rounded,
                        color: Color(0xFF57344F),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: const Color(0xFF714B67),
                shape: const CircleBorder(),
                elevation: 1,
                shadowColor: Colors.black12,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _showExportPdfSuccess,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Active Primary Period Pill
          InkWell(
            onTap: () {
              _showPickerSheet(
                'Select Analytics Period',
                ['Sep 2026', 'Aug 2026', 'Jul 2026', 'Jun 2026', 'May 2026', 'Apr 2026'],
                _selectedPeriod,
                (val) {
                  setState(() => _selectedPeriod = val);
                  _loadBackendAnalytics();
                },
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF714B67),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF714B67).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    _selectedPeriod,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Dept Chip
          _buildFilterChip('Dept:', _selectedDept, () {
            _showPickerSheet(
              'Filter by Department',
              ['All', 'Human Resources', 'Finance & Tech Ops', 'Engineering', 'Design', 'Sales', 'Customer Support', 'Executive Management'],
              _selectedDept,
              (val) {
                setState(() => _selectedDept = val);
                _loadBackendAnalytics();
              },
            );
          }),
          const SizedBox(width: 8),

          // Type Chip
          _buildFilterChip('Type:', _selectedType, () {
            _showPickerSheet(
              'Filter by Employee Type',
              ['All Staff', 'Full-time', 'Part-time', 'Contractor', 'Intern'],
              _selectedType,
              (val) {
                setState(() => _selectedType = val);
                _loadBackendAnalytics();
              },
            );
          }),
          const SizedBox(width: 8),

          // Entity Chip
          _buildFilterChip('Entity:', _selectedEntity, () {
            _showPickerSheet(
              'Filter by Corporate Entity',
              ['OXP Pvt Ltd', 'OXP Global', 'OXP Enterprise Services'],
              _selectedEntity,
              (val) {
                setState(() => _selectedEntity = val);
                _loadBackendAnalytics();
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEAEDFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF4E444A),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF131B2E),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF4E444A)),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Period Highlights',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF131B2E),
            ),
          ),
          Row(
            children: [
              Text(
                'SWIPE TO EXPLORE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF00696E),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.swipe_rounded, size: 14, color: Color(0xFF00696E)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsCarousel() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Card 1: Net Salary Paid
          _buildKpiCard(
            icon: Icons.payments_rounded,
            iconBg: const Color(0xFFE2E7FF),
            iconColor: const Color(0xFF57344F),
            badgeText: '+8.5%',
            badgeBg: const Color(0xFF4EDEA3).withValues(alpha: 0.2),
            badgeTextColor: const Color(0xFF004A31),
            badgeIcon: Icons.trending_up_rounded,
            title: 'Net Salary Paid',
            valuePrefix: '₹',
            value: _formatCurrencyCompact(_totalNetSalary),
            subtitle: '100% disbursed cycle',
            subtitleColor: const Color(0xFF00696E),
          ),
          const SizedBox(width: 12),

          // Card 2: Payslips Volume
          _buildPayslipsVolumeCard(),
          const SizedBox(width: 12),

          // Card 3: Avg Compensation
          _buildKpiCard(
            icon: Icons.balance_rounded,
            iconBg: const Color(0xFFE2E7FF),
            iconColor: const Color(0xFF57344F),
            badgeText: 'FTE Avg',
            badgeBg: const Color(0xFFE2E7FF),
            badgeTextColor: const Color(0xFF4E444A),
            title: 'Avg Compensation',
            valuePrefix: '₹',
            value: _avgCompensation.toStringAsFixed(0),
            subtitle: 'Active FTE baseline matrix',
            subtitleColor: const Color(0xFF4E444A),
          ),
          const SizedBox(width: 12),

          // Card 4: Approved Leaves
          _buildKpiCard(
            icon: Icons.beach_access_rounded,
            iconBg: const Color(0xFFE2E7FF),
            iconColor: const Color(0xFF00696E),
            badgeText: '${_selectedPeriod.split(' ').first} Quota',
            badgeBg: const Color(0xFFE2E7FF),
            badgeTextColor: const Color(0xFF131B2E),
            title: 'Approved Leaves',
            value: '$_approvedLeavesDays',
            valueSuffix: 'Total Days',
            subtitle: 'Verified allocation ledger',
            subtitleColor: const Color(0xFF00696E),
          ),
          const SizedBox(width: 12),

          // Card 5: Attendance Health
          _buildKpiCard(
            icon: Icons.verified_user_rounded,
            iconBg: const Color(0xFFE2E7FF),
            iconColor: const Color(0xFF004A31),
            badgeText: _attendanceHealthPercent >= 90 ? 'Optimal' : 'Standard',
            badgeBg: const Color(0xFF4EDEA3).withValues(alpha: 0.2),
            badgeTextColor: const Color(0xFF004A31),
            title: 'Attendance Health',
            value: '${_attendanceHealthPercent.toStringAsFixed(1)}%',
            subtitle: 'Active biometric log ratio',
            subtitleColor: const Color(0xFF4E444A),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String badgeText,
    required Color badgeBg,
    required Color badgeTextColor,
    IconData? badgeIcon,
    required String title,
    String? valuePrefix,
    required String value,
    String? valueSuffix,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Container(
      width: 230,
      height: 156,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badgeIcon != null) ...[
                      Icon(badgeIcon, size: 13, color: badgeTextColor),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      badgeText,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF4E444A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (valuePrefix != null)
                    Text(
                      valuePrefix,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                  if (valuePrefix != null) const SizedBox(width: 3),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  if (valueSuffix != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      valueSuffix,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF4E444A),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayslipsVolumeCard() {
    final factor = _totalPayslipsCount > 0 ? (_paidPayslipsCount / _totalPayslipsCount) : 0.95;
    return Container(
      width: 230,
      height: 156,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E7FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_rounded, color: Color(0xFF00696E), size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF92EFF5).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_pendingPayslipsCount Pending',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF006E73),
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payslips Volume',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF4E444A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$_totalPayslipsCount',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'slips generated',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF4E444A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  color: const Color(0xFFE2E7FF),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: factor.clamp(0.1, 1.0),
                    child: Container(
                      color: const Color(0xFF00696E),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_paidPayslipsCount paid • $_pendingPayslipsCount draft review',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4E444A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalDualCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;
          final leftCard = Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attendance',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4EDEA3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildAttendanceMiniBox('Present', '$_presentCount', const Color(0xFF131B2E))),
                    const SizedBox(width: 6),
                    Expanded(child: _buildAttendanceMiniBox('Late', '$_lateCount', const Color(0xFF131B2E))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _buildAttendanceMiniBox('Absent', '$_absentCount', const Color(0xFFBA1A1A))),
                    const SizedBox(width: 6),
                    Expanded(child: _buildAttendanceMiniBox('Overtime', '$_overtimeCount', const Color(0xFF00696E))),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E7FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFBA1A1A)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '$_missingPunchesCount missing punches require approval',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF131B2E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          final rightCard = Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pre-Flight Audit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDAD6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ALERT',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF93000A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildAnomalyBullet(const Color(0xFFBA1A1A), '$_missingBankDetailsCount missing bank details'),
                const SizedBox(height: 6),
                _buildAnomalyBullet(const Color(0xFF79526F), '$_duplicateEntriesCount duplicate entry'),
                const SizedBox(height: 6),
                _buildAnomalyBullet(const Color(0xFF00696E), '$_unvalidatedDraftsCount unvalidated drafts'),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🔍 Inspecting payrun anomaly batch...')),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E7FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Inspect Batch',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF57344F),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF57344F)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

          if (isNarrow) {
            return Column(
              children: [
                leftCard,
                const SizedBox(height: 12),
                rightCard,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: leftCard),
              const SizedBox(width: 12),
              Expanded(child: rightCard),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAttendanceMiniBox(String label, String count, Color countColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: const Color(0xFF4E444A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: countColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyBullet(Color dotColor, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF131B2E),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentSpendCard() {
    double totalWageSum = 0.0;
    for (final d in _departmentSpendList) {
      totalWageSum += d.totalWage;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Salary Cost by Department',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Allocated operational payroll',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Spend',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                    Text(
                      '₹ ${_formatCurrencyCompact(totalWageSum)}',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF57344F),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Dynamic Bar Items
            ..._departmentSpendList.map((d) {
              final pctStr = '${(d.percentShare * 100).toStringAsFixed(0)}%';
              final amtStr = '₹ ${_formatCurrencyCompact(d.totalWage)}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSpendBarItem(d.deptName, amtStr, pctStr, d.percentShare.clamp(0.05, 1.0), d.barColor),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendBarItem(String dept, String amount, String percent, double factor, Color barColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: barColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dept,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  amount,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF131B2E),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  percent,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: const Color(0xFF4E444A),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 7,
            color: const Color(0xFFE2E7FF),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: factor,
              child: Container(color: barColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryTrendCard() {
    double maxTrend = 0.0;
    for (final t in _trendDataList) {
      if (t.totalNetPaid > maxTrend) maxTrend = t.totalNetPaid;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Salary Trend Analysis',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Past 6 rolling payroll cycles',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E7FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₹${_formatCurrencyCompact(maxTrend)} Max',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Spline Graphic with Peak Cycle badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _SplineTrendPainter(),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF714B67),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Peak Cycle',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            // X-Axis Labels & Data values
            Row(
              children: _trendDataList.map((t) {
                return Expanded(child: _buildTrendMonthItem(t.monthLabel, t.displayVal, isPeak: t.isPeak));
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendMonthItem(String month, String value, {required bool isPeak}) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            month,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
              color: isPeak ? const Color(0xFF57344F) : const Color(0xFF131B2E),
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
              color: isPeak ? const Color(0xFF57344F) : const Color(0xFF4E444A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentMatrixCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Department Matrix',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cost & Headcount summary',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening Full Department Ledger...')),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'See Full Ledger',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF00696E),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF00696E)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Dynamic Rows
            ..._departmentMatrixList.map((d) {
              final staffStr = '${d.staffCount} Staff';
              final avgStr = 'Avg: ₹ ${_formatCurrencyCompact(d.avgSalary)} / employee';
              final grossStr = '₹ ${_formatCurrencyCompact(d.totalWage)}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildMatrixRow(d.deptCode, d.deptName, staffStr, avgStr, grossStr),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrixRow(String initials, String deptName, String staffCount, String avgPerEmp, String gross) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E7FF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF57344F),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              deptName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF131B2E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF92EFF5).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              staffCount,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF006E73),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        avgPerEmp,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: const Color(0xFF4E444A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                gross,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF131B2E),
                ),
              ),
              Text(
                'Monthly Gross',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  color: const Color(0xFF4E444A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditSignOffBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E7FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Color(0xFF00696E),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audit Sign-off Ready',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'All statutory deductions calculated and checked',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF4E444A),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'READY',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF00696E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF714B67),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: _showExportPdfSuccess,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Download Report (PDF)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 48,
            width: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFEAEDFF),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFF57344F), size: 20),
              tooltip: 'Schedule Automated Report',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📅 Automated monthly payroll digest scheduled!')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SplineTrendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(size.width * 0.05, size.height * 0.75), // Apr
      Offset(size.width * 0.23, size.height * 0.68), // May
      Offset(size.width * 0.41, size.height * 0.76), // Jun
      Offset(size.width * 0.59, size.height * 0.58), // Jul
      Offset(size.width * 0.77, size.height * 0.38), // Aug
      Offset(size.width * 0.95, size.height * 0.12), // Sep Peak
    ];

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    // Fill Gradient Path
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF714B67).withValues(alpha: 0.35),
        const Color(0xFF714B67).withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke Paint
    final strokePaint = Paint()
      ..color = const Color(0xFF714B67)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Draw Dots
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      if (i == points.length - 1) {
        // Sep Peak active node
        final outerPaint = Paint()..color = const Color(0xFF714B67);
        final ringPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(pt, 7, outerPaint);
        canvas.drawCircle(pt, 7, ringPaint);
      } else {
        final whitePaint = Paint()..color = Colors.white;
        final borderPaint = Paint()
          ..color = const Color(0xFF714B67)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(pt, 4.5, whitePaint);
        canvas.drawCircle(pt, 4.5, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
