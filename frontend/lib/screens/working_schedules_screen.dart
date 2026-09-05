import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkingSchedulesScreen extends StatefulWidget {
  final void Function(int index)? onNavigateTab;
  const WorkingSchedulesScreen({super.key, this.onNavigateTab});

  @override
  State<WorkingSchedulesScreen> createState() => _WorkingSchedulesScreenState();
}

class _ShiftDay {
  final String id;
  String day;
  String tag;
  String startTime;
  String endTime;
  int breakMinutes;

  _ShiftDay({
    required this.id,
    required this.day,
    this.tag = 'Core',
    this.startTime = '09:00 AM',
    this.endTime = '06:00 PM',
    this.breakMinutes = 60,
  });

  double get calculatedHours {
    final startMin = _parseTimeToMinutes(startTime);
    final endMin = _parseTimeToMinutes(endTime);
    int workMin = endMin - startMin - breakMinutes;
    if (workMin < 0) workMin = 0;
    return workMin / 60.0;
  }

  static int _parseTimeToMinutes(String tStr) {
    try {
      final parts = tStr.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hours = int.parse(timeParts[0]);
      final minutes = int.parse(timeParts[1]);
      if (parts[1].toUpperCase() == 'PM' && hours != 12) hours += 12;
      if (parts[1].toUpperCase() == 'AM' && hours == 12) hours = 0;
      return hours * 60 + minutes;
    } catch (_) {
      return 9 * 60;
    }
  }
}

class _WorkingSchedulesScreenState extends State<WorkingSchedulesScreen> {
  final List<_ShiftDay> _shifts = [
    _ShiftDay(id: 'mon', day: 'Monday'),
    _ShiftDay(id: 'tue', day: 'Tuesday'),
    _ShiftDay(id: 'wed', day: 'Wednesday'),
    _ShiftDay(id: 'thu', day: 'Thursday'),
    _ShiftDay(id: 'fri', day: 'Friday'),
  ];

  final List<String> _startTimes = ['08:00 AM', '08:30 AM', '09:00 AM', '09:30 AM', '10:00 AM'];
  final List<String> _endTimes = ['05:00 PM', '05:30 PM', '06:00 PM', '06:30 PM', '07:00 PM'];

  bool _isSaving = false;
  bool _isSaved = false;

  double get _totalWeeklyHours {
    return _shifts.fold(0.0, (sum, item) => sum + item.calculatedHours);
  }

  void _cycleStartTime(_ShiftDay shift) {
    setState(() {
      int idx = _startTimes.indexOf(shift.startTime);
      if (idx == -1) idx = 2;
      shift.startTime = _startTimes[(idx + 1) % _startTimes.length];
    });
  }

  void _cycleEndTime(_ShiftDay shift) {
    setState(() {
      int idx = _endTimes.indexOf(shift.endTime);
      if (idx == -1) idx = 2;
      shift.endTime = _endTimes[(idx + 1) % _endTimes.length];
    });
  }

  void _copyMonToAll() {
    if (_shifts.isEmpty) return;
    final mon = _shifts.first;
    setState(() {
      for (var s in _shifts) {
        s.startTime = mon.startTime;
        s.endTime = mon.endTime;
        s.breakMinutes = mon.breakMinutes;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF004A31),
        behavior: SnackBarBehavior.floating,
        content: Text('✓ Applied Monday schedule (09:00 AM - 06:00 PM, 1h break) to all working days'),
      ),
    );
  }

  void _addCustomDay() {
    final existingDays = _shifts.map((s) => s.day).toSet();
    String newDay = 'Saturday';
    if (existingDays.contains('Saturday') && !existingDays.contains('Sunday')) {
      newDay = 'Sunday';
    } else if (existingDays.contains('Saturday') && existingDays.contains('Sunday')) {
      newDay = 'Extra Shift ${_shifts.length + 1}';
    }

    setState(() {
      _shifts.add(
        _ShiftDay(
          id: 'day_${DateTime.now().millisecondsSinceEpoch}',
          day: newDay,
          tag: 'Extra',
          startTime: '09:00 AM',
          endTime: '01:00 PM',
          breakMinutes: 0,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF00696E),
        behavior: SnackBarBehavior.floating,
        content: Text('+ Added $newDay shift to schedule'),
      ),
    );
  }

  void _removeDay(int index) {
    final removed = _shifts[index].day;
    setState(() {
      _shifts.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed $removed shift')),
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving || _isSaved) return;

    setState(() {
      _isSaving = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _isSaved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF004A31),
        behavior: SnackBarBehavior.floating,
        content: Text('✓ Saved Working Schedule (${_totalWeeklyHours.toStringAsFixed(1)}h / Week) to Odoo ERP'),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    setState(() {
      _isSaved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalHours = _totalWeeklyHours;
    final isCompliant = totalHours <= 48.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Top Navigation & Header Bar
                _buildHeaderBar(),

                // Scrollable Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 180),
                    children: [
                      // Top Metadata Card
                      _buildTopMetadataCard(),

                      const SizedBox(height: 16),

                      // Section Title & Batch Modifier
                      _buildSectionHeader(),

                      const SizedBox(height: 10),

                      // Day Schedule Cards
                      ..._shifts.asMap().entries.map((entry) {
                        return _buildShiftCard(entry.key, entry.value);
                      }),

                      const SizedBox(height: 12),

                      // Add Custom Day Button
                      _buildAddCustomDayButton(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),

            // Sticky Bottom Summary & Action Ribbon
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomStickyRibbon(totalHours, isCompliant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF).withValues(alpha: 0.85),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
                    color: Color(0xFFE2E7FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.arrow_back, size: 18, color: Color(0xFF131B2E)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Working Schedule',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00696E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'SCHED/2026/01',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4E444A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🕒 Schedule Audit Logs: Version 2026.1 loaded')),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E7FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.history, size: 18, color: Color(0xFF131B2E)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚡ Schedule Actions: Duplicate • Export XML • Archive')),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E7FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.more_vert, size: 18, color: Color(0xFF131B2E)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopMetadataCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
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
                    'STANDARD MODEL',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: const Color(0xFF714B67),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '40 Hours / Week',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Standard Full-Time Policy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: const Color(0xFF4E444A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCF7FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 14, color: Color(0xFF006E73)),
                    const SizedBox(width: 4),
                    Text(
                      'ERP SYNC',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF006E73),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Company & Timezone details grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                // Company
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDAE2FD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.domain, color: Color(0xFF714B67), size: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Company',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                            ),
                            Text(
                              'OXP Pvt Ltd',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(width: 1, height: 28, color: const Color(0xFFD1C3CA)),
                const SizedBox(width: 12),

                // Timezone
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF92EFF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.schedule, color: Color(0xFF006E73), size: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Timezone',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                            ),
                            Text(
                              'Asia/Kolkata (+5:30)',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Live Metric Header Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF006443).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF006443),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_shifts.length} Days/Wk • ${_totalWeeklyHours.toStringAsFixed(1)}h Total Working Hours',
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
                const SizedBox(width: 6),
                const Icon(Icons.check_circle, color: Color(0xFF006443), size: 17),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Shift Schedule',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF131B2E),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E7FF),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${_shifts.length}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: _copyMonToAll,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.content_copy, size: 14, color: Color(0xFF00696E)),
                  const SizedBox(width: 4),
                  Text(
                    'Apply Mon to All',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00696E),
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

  Widget _buildShiftCard(int index, _ShiftDay shift) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Day Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: shift.tag == 'Core' ? const Color(0xFF00696E) : const Color(0xFF714B67),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    shift.day,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      shift.tag,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Hours badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF92EFF5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timelapse, size: 13, color: Color(0xFF006E73)),
                        const SizedBox(width: 4),
                        Text(
                          '${shift.calculatedHours.toStringAsFixed(1)}h',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF006E73),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _removeDay(index),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F3FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.close, size: 15, color: Color(0xFF4E444A)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3-Column Time Grid (Start Time, End Time, Break)
          Row(
            children: [
              // Start Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Time',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _cycleStartTime(shift),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F3FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              shift.startTime,
                              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                            ),
                            const Icon(Icons.schedule, size: 14, color: Color(0xFF80747A)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // End Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'End Time',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _cycleEndTime(shift),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F3FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              shift.endTime,
                              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                            ),
                            const Icon(Icons.schedule, size: 14, color: Color(0xFF80747A)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Break Duration Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Break',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: shift.breakMinutes,
                          isExpanded: true,
                          icon: const Icon(Icons.expand_more, size: 16, color: Color(0xFF80747A)),
                          style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('0m')),
                            DropdownMenuItem(value: 30, child: Text('30m')),
                            DropdownMenuItem(value: 45, child: Text('45m')),
                            DropdownMenuItem(value: 60, child: Text('1h 00m')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                shift.breakMinutes = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddCustomDayButton() {
    return InkWell(
      onTap: _addCustomDay,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3FF).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, color: Color(0xFF00696E), size: 19),
            const SizedBox(width: 8),
            Text(
              '+ Add Weekend / Custom Shift',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00696E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomStickyRibbon(double totalHours, bool isCompliant) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: const [
          BoxShadow(color: Color(0x18000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Total & Compliance Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Weekly Working Time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          totalHours.toStringAsFixed(1),
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF131B2E),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Hours',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4E444A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isCompliant
                      ? const Color(0xFF006443).withValues(alpha: 0.12)
                      : const Color(0xFFBA1A1A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCompliant ? Icons.task_alt : Icons.warning_amber_rounded,
                      size: 14,
                      color: isCompliant ? const Color(0xFF006443) : const Color(0xFFBA1A1A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCompliant ? 'Compliant' : 'Overtime',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCompliant ? const Color(0xFF006443) : const Color(0xFFBA1A1A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Verification Message
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, size: 14, color: Color(0xFF006443)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Standard 8h/day shift verified against Odoo Payroll Policy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF4E444A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Primary Aubergine Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaved
                    ? const Color(0xFF006443)
                    : const Color(0xFF714B67),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 2,
              ),
              onPressed: _handleSave,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_isSaved ? Icons.check_circle : Icons.save, size: 18),
              label: Text(
                _isSaving
                    ? 'Validating with Payroll...'
                    : _isSaved
                        ? 'Saved (${totalHours.toStringAsFixed(1)}h / Week)'
                        : 'Save Working Schedule',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
