import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalyticsScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const AnalyticsScreen({super.key, this.onNavigateTab});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _refreshAnimController;
  String _selectedPeriod = 'Sep 2026';
  String _selectedDept = 'All';
  String _selectedType = 'All Staff';
  String _selectedEntity = 'OXP Pvt Ltd';

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
    super.dispose();
  }

  void _triggerRefresh() {
    _refreshAnimController.forward(from: 0.0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Live Analytics synced with OXP Core Ledger',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Exporting Executive Analytics Board (PDF)...',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF57344F),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4EDEA3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE SYNCED',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
          // Active Primary Pill
          InkWell(
            onTap: () {
              setState(() {
                _selectedPeriod = _selectedPeriod == 'Sep 2026' ? 'Aug 2026' : 'Sep 2026';
              });
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
            setState(() {
              _selectedDept = _selectedDept == 'All' ? 'Engineering' : 'All';
            });
          }),
          const SizedBox(width: 8),

          // Type Chip
          _buildFilterChip('Type:', _selectedType, () {
            setState(() {
              _selectedType = _selectedType == 'All Staff' ? 'Full Time' : 'All Staff';
            });
          }),
          const SizedBox(width: 8),

          // Entity Chip
          _buildFilterChip('Entity:', _selectedEntity, () {
            setState(() {
              _selectedEntity = _selectedEntity == 'OXP Pvt Ltd' ? 'OXP Global' : 'OXP Pvt Ltd';
            });
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
            value: '18.4L',
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
            value: '12,432',
            subtitle: 'Active FTE baseline matrix',
            subtitleColor: const Color(0xFF4E444A),
          ),
          const SizedBox(width: 12),

          // Card 4: Approved Leaves
          _buildKpiCard(
            icon: Icons.beach_access_rounded,
            iconBg: const Color(0xFFE2E7FF),
            iconColor: const Color(0xFF00696E),
            badgeText: 'Sep Quota',
            badgeBg: const Color(0xFFE2E7FF),
            badgeTextColor: const Color(0xFF131B2E),
            title: 'Approved Leaves',
            value: '34',
            valueSuffix: 'Total Days',
            subtitle: '-12% vs August cycle',
            subtitleColor: const Color(0xFF00696E),
          ),
          const SizedBox(width: 12),

          // Card 5: Attendance Health
          _buildKpiCard(
            icon: Icons.verified_user_rounded,
            iconBg: const Color(0xFFE2E7FF),
            iconColor: const Color(0xFF004A31),
            badgeText: 'Optimal',
            badgeBg: const Color(0xFF4EDEA3).withValues(alpha: 0.2),
            badgeTextColor: const Color(0xFF004A31),
            title: 'Attendance Health',
            value: '94.2%',
            subtitle: '141 active punch records',
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
                  '6 Pending',
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
                    '148',
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
                    widthFactor: 0.96,
                    child: Container(
                      color: const Color(0xFF00696E),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '142 paid • 6 draft review',
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
                    Expanded(child: _buildAttendanceMiniBox('Present', '94', const Color(0xFF131B2E))),
                    const SizedBox(width: 6),
                    Expanded(child: _buildAttendanceMiniBox('Late', '18', const Color(0xFF131B2E))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _buildAttendanceMiniBox('Absent', '09', const Color(0xFFBA1A1A))),
                    const SizedBox(width: 6),
                    Expanded(child: _buildAttendanceMiniBox('Overtime', '22', const Color(0xFF00696E))),
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
                          '5 missing punches require approval',
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
                _buildAnomalyBullet(const Color(0xFFBA1A1A), '2 missing bank details'),
                const SizedBox(height: 6),
                _buildAnomalyBullet(const Color(0xFF79526F), '1 duplicate entry'),
                const SizedBox(height: 6),
                _buildAnomalyBullet(const Color(0xFF00696E), '4 unvalidated drafts'),
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
                      '₹ 660,000',
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

            // Bar Items
            _buildSpendBarItem('Information Tech (IT)', '₹ 170k', '100%', 1.0, const Color(0xFF714B67)),
            const SizedBox(height: 12),
            _buildSpendBarItem('Sales & Revenue', '₹ 150k', '88%', 0.88, const Color(0xFF57344F)),
            const SizedBox(height: 12),
            _buildSpendBarItem('Finance & Ops', '₹ 130k', '76%', 0.76, const Color(0xFF00696E)),
            const SizedBox(height: 12),
            _buildSpendBarItem('Customer Support', '₹ 110k', '64%', 0.64, const Color(0xFF78D5DB)),
            const SizedBox(height: 12),
            _buildSpendBarItem('HR & People', '₹ 90k', '52%', 0.52, const Color(0xFF004A31)),
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
                    '₹18.4L Max',
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
              children: [
                Expanded(child: _buildTrendMonthItem('Apr', '₹14.8L', isPeak: false)),
                Expanded(child: _buildTrendMonthItem('May', '₹15.2L', isPeak: false)),
                Expanded(child: _buildTrendMonthItem('Jun', '₹14.3L', isPeak: false)),
                Expanded(child: _buildTrendMonthItem('Jul', '₹15.0L', isPeak: false)),
                Expanded(child: _buildTrendMonthItem('Aug', '₹17.1L', isPeak: false)),
                Expanded(child: _buildTrendMonthItem('Sep', '₹18.4L', isPeak: true)),
              ],
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

            // Rows
            _buildMatrixRow('IT', 'Engineering & IT', '18 Staff', 'Avg: ₹ 23.3k / employee', '₹ 4.2L'),
            const SizedBox(height: 10),
            _buildMatrixRow('SL', 'Sales & Growth', '22 Staff', 'Avg: ₹ 25.9k / employee', '₹ 5.7L'),
            const SizedBox(height: 10),
            _buildMatrixRow('HR', 'People & Talent', '8 Staff', 'Avg: ₹ 23.7k / employee', '₹ 1.9L'),
            const SizedBox(height: 10),
            _buildMatrixRow('CS', 'Customer Success', '14 Staff', 'Avg: ₹ 22.1k / employee', '₹ 3.1L'),
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
