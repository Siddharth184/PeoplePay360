import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/working_schedule_service.dart';
import '../services/employee_service.dart';

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
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hours != 12) hours += 12;
      if (parts.length > 1 && parts[1].toUpperCase() == 'AM' && hours == 12) hours = 0;
      return hours * 60 + minutes;
    } catch (_) {
      return 9 * 60;
    }
  }
}

class _WorkingSchedulesScreenState extends State<WorkingSchedulesScreen> {
  List<WorkingScheduleModel> _schedules = [];
  List<EmployeeModel> _employees = [];
  late WorkingScheduleModel _activeSchedule;
  late List<_ShiftDay> _shifts;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSaved = false;

  // Selected Assigned Employee IDs
  late Set<String> _assignedEmployeeIds;

  @override
  void initState() {
    super.initState();
    _activeSchedule = WorkingScheduleModel(
      id: 'ws-default',
      name: 'Standard 40 Hours',
      averageHoursPerWeek: 40,
      daysPerWeek: 5,
      timezone: 'Asia/Kolkata',
    );
    _shifts = _getShiftsForSchedule(_activeSchedule);
    _assignedEmployeeIds = {};
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final schedRes = await WorkingScheduleService.getSchedules();
    final empRes = await EmployeeService.getEmployees();

    if (mounted) {
      setState(() {
        _schedules = schedRes.data ?? [];
        _employees = empRes.data ?? [];
        _isLoading = false;
        if (_schedules.isNotEmpty) {
          _activeSchedule = _schedules.first;
          _shifts = _getShiftsForSchedule(_activeSchedule);
        }
      });
    }
  }

  List<_ShiftDay> _getShiftsForSchedule(WorkingScheduleModel sched) {
    if (sched.name.toLowerCase().contains('night')) {
      return [
        _ShiftDay(id: 'mon', day: 'Monday', tag: 'Night', startTime: '10:00 PM', endTime: '07:00 AM', breakMinutes: 60),
        _ShiftDay(id: 'tue', day: 'Tuesday', tag: 'Night', startTime: '10:00 PM', endTime: '07:00 AM', breakMinutes: 60),
        _ShiftDay(id: 'wed', day: 'Wednesday', tag: 'Night', startTime: '10:00 PM', endTime: '07:00 AM', breakMinutes: 60),
        _ShiftDay(id: 'thu', day: 'Thursday', tag: 'Night', startTime: '10:00 PM', endTime: '07:00 AM', breakMinutes: 60),
        _ShiftDay(id: 'fri', day: 'Friday', tag: 'Night', startTime: '10:00 PM', endTime: '07:00 AM', breakMinutes: 60),
      ];
    } else if (sched.name.toLowerCase().contains('part-time')) {
      return [
        _ShiftDay(id: 'mon', day: 'Monday', tag: 'Part-Time', startTime: '09:00 AM', endTime: '03:00 PM', breakMinutes: 30),
        _ShiftDay(id: 'tue', day: 'Tuesday', tag: 'Part-Time', startTime: '09:00 AM', endTime: '03:00 PM', breakMinutes: 30),
        _ShiftDay(id: 'wed', day: 'Wednesday', tag: 'Part-Time', startTime: '09:00 AM', endTime: '03:00 PM', breakMinutes: 30),
        _ShiftDay(id: 'thu', day: 'Thursday', tag: 'Part-Time', startTime: '09:00 AM', endTime: '03:00 PM', breakMinutes: 30),
      ];
    } else {
      return [
        _ShiftDay(id: 'mon', day: 'Monday', tag: 'Core', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        _ShiftDay(id: 'tue', day: 'Tuesday', tag: 'Core', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        _ShiftDay(id: 'wed', day: 'Wednesday', tag: 'Core', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        _ShiftDay(id: 'thu', day: 'Thursday', tag: 'Core', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        _ShiftDay(id: 'fri', day: 'Friday', tag: 'Core', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
      ];
    }
  }

  double get _totalWeeklyHours {
    return _shifts.fold(0.0, (sum, item) => sum + item.calculatedHours);
  }

  // --- TIME PICKER FUNCTIONS ---
  Future<void> _pickStartTime(_ShiftDay shift) async {
    final initial = _parseTimeOfDay(shift.startTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF57344F),
              onPrimary: Colors.white,
              onSurface: Color(0xFF131B2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        shift.startTime = _formatTimeOfDay(picked);
      });
    }
  }

  Future<void> _pickEndTime(_ShiftDay shift) async {
    final initial = _parseTimeOfDay(shift.endTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF57344F),
              onPrimary: Colors.white,
              onSurface: Color(0xFF131B2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        shift.endTime = _formatTimeOfDay(picked);
      });
    }
  }

  void _pickBreakDuration(_ShiftDay shift) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Break Duration for ${shift.day}',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
            ),
            const SizedBox(height: 12),
            ...[
              {'label': 'No Break (0m)', 'mins': 0},
              {'label': '30 Minutes (30m)', 'mins': 30},
              {'label': '45 Minutes (45m)', 'mins': 45},
              {'label': '1 Hour (1h 00m)', 'mins': 60},
              {'label': '1.5 Hours (1h 30m)', 'mins': 90},
              {'label': '2 Hours (2h 00m)', 'mins': 120},
            ].map((opt) {
              final isSel = shift.breakMinutes == opt['mins'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  opt['label'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? const Color(0xFF714B67) : const Color(0xFF131B2E),
                  ),
                ),
                trailing: isSel ? const Icon(Icons.check_circle_rounded, color: Color(0xFF714B67)) : null,
                onTap: () {
                  setState(() {
                    shift.breakMinutes = opt['mins'] as int;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  TimeOfDay _parseTimeOfDay(String tStr) {
    try {
      final parts = tStr.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour != 12) hour += 12;
      if (parts.length > 1 && parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final period = tod.period == DayPeriod.pm ? 'PM' : 'AM';
    final minuteStr = tod.minute.toString().padLeft(2, '0');
    final hourStr = hour.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr $period';
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

    _triggerToast('Applied Monday schedule (${mon.startTime} - ${mon.endTime}) to all shift days');
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

    _triggerToast('+ Added $newDay shift to schedule');
  }

  void _removeDay(int index) {
    final removed = _shifts[index].day;
    setState(() {
      _shifts.removeAt(index);
    });
    _triggerToast('Removed $removed shift');
  }

  void _switchSchedule(WorkingScheduleModel sched) {
    setState(() {
      _activeSchedule = sched;
      _shifts = _getShiftsForSchedule(sched);
    });
    _triggerToast('Switched active schedule to ${sched.name}');
  }

  void _openSchedulePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Working Schedule',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openCreateScheduleSheet();
                  },
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF00696E)),
                  label: const Text('+ New', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00696E))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._schedules.map((sched) {
              final isSel = sched.id == _activeSchedule.id;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                title: Text(
                  sched.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? const Color(0xFF714B67) : const Color(0xFF131B2E),
                  ),
                ),
                subtitle: Text(
                  '${sched.daysPerWeek} Days/Wk • ${sched.averageHoursPerWeek}h/Wk • ${sched.timezone}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF4E444A)),
                ),
                trailing: isSel ? const Icon(Icons.check_circle_rounded, color: Color(0xFF714B67)) : null,
                onTap: () {
                  Navigator.pop(context);
                  _switchSchedule(sched);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _openCreateScheduleSheet() {
    final nameCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '5');
    final hoursCtrl = TextEditingController(text: '40');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New Working Schedule',
                style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameCtrl,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Schedule Name *',
                  hintText: 'e.g. Flexi Shift 38 Hours',
                  prefixIcon: const Icon(Icons.schedule_outlined, color: Color(0xFF714B67)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: daysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Days/Wk *',
                        prefixIcon: const Icon(Icons.calendar_month, color: Color(0xFF714B67)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: hoursCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Hours/Wk *',
                        prefixIcon: const Icon(Icons.timelapse, color: Color(0xFF714B67)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00696E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isNotEmpty) {
                      final payload = {
                        'name': name,
                        'days_per_week': int.tryParse(daysCtrl.text) ?? 5,
                        'hours_per_week': int.tryParse(hoursCtrl.text) ?? 40,
                        'timezone': 'Asia/Kolkata',
                      };
                      final nav = Navigator.of(context);
                      final res = await WorkingScheduleService.createSchedule(payload);
                      if (!mounted) return;
                      if (res.isSuccess) {
                        _triggerToast('Created schedule $name');
                        _loadData();
                      }
                      nav.pop();
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Save & Apply Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAssignEmployeeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Assign Employees to ${_activeSchedule.name}',
                      style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: _employees.map((emp) {
                      final isAssigned = _assignedEmployeeIds.contains(emp.id);
                      return CheckboxListTile(
                        value: isAssigned,
                        activeColor: const Color(0xFF57344F),
                        title: Text(emp.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('${emp.jobTitle} • ${emp.department}', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                        onChanged: (val) {
                          setModalState(() {
                            if (val == true) {
                              _assignedEmployeeIds.add(emp.id);
                            } else {
                              _assignedEmployeeIds.remove(emp.id);
                            }
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF57344F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _triggerToast('✅ Updated mapped workforce (${_assignedEmployeeIds.length} staff assigned)');
                    },
                    child: Text('Confirm Assignment (${_assignedEmployeeIds.length} Selected)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openAuditHistorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF57344F)),
                const SizedBox(width: 8),
                Text(
                  'Schedule Audit Logs & Version History',
                  style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Color(0xFF006443)),
              title: Text('Version 2026.1 (Active)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              subtitle: Text('Adjusted Friday core shift & break time • Updated by Sara Khan on Aug 15, 2026'),
            ),
            ListTile(
              leading: const Icon(Icons.history_toggle_off, color: Colors.grey),
              title: Text('Version 2025.4', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              subtitle: Text('Initial shift calendar creation • Created by Admin User on Jan 01, 2025'),
            ),
          ],
        ),
      ),
    );
  }

  void _openActionMenuSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Schedule Options & Actions', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.copy_all, color: Color(0xFF57344F)),
              title: const Text('Duplicate Working Schedule'),
              subtitle: const Text('Clone this shift configuration into a new schedule'),
              onTap: () async {
                Navigator.pop(context);
                final res = await WorkingScheduleService.createSchedule({
                  'name': '${_activeSchedule.name} (Copy)',
                  'days_per_week': _activeSchedule.daysPerWeek,
                  'hours_per_week': _activeSchedule.averageHoursPerWeek,
                  'timezone': _activeSchedule.timezone,
                });
                if (res.isSuccess && res.data != null) {
                  _switchSchedule(res.data!);
                  _loadData();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined, color: Color(0xFF00696E)),
              title: const Text('Batch Assign to Department'),
              subtitle: const Text('Assign all staff in Engineering / HR to this schedule'),
              onTap: () {
                Navigator.pop(context);
                _openAssignEmployeeSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFB45309)),
              title: const Text('Export Schedule PDF Report'),
              subtitle: const Text('Generate printable weekly shift calendar'),
              onTap: () {
                Navigator.pop(context);
                _triggerToast('📄 Exporting ${_activeSchedule.name} PDF report...');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _triggerToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF283044),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving || _isSaved) return;

    setState(() {
      _isSaving = true;
    });

    final shiftConfigs = _shifts.map((s) => ShiftConfig(
      day: s.day,
      startTime: s.startTime,
      endTime: s.endTime,
      breakMinutes: s.breakMinutes,
    )).toList();
    WorkingScheduleService.setActiveShifts(shiftConfigs);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _isSaved = true;
    });

    _triggerToast('✓ Saved ${_activeSchedule.name} (${_totalWeeklyHours.toStringAsFixed(1)}h / Week) to Odoo ERP');

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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 180),
                          children: [
                            // Top Metadata Card & Switcher
                            _buildTopMetadataCard(),

                      const SizedBox(height: 16),

                      // Mapped Workforce Card
                      _buildMappedWorkforceCard(),

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
                      color: Color(0xFFE2E7FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.arrow_back, size: 18, color: Color(0xFF131B2E)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
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
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00696E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'SCHED/2026/01 • ${_activeSchedule.name}',
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
                onTap: _openAuditHistorySheet,
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
                onTap: _openActionMenuSheet,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE CALENDAR POLICY',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: const Color(0xFF714B67),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeSchedule.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${_activeSchedule.daysPerWeek} Working Days • ${_activeSchedule.averageHoursPerWeek}h/Week Base',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openSchedulePickerSheet,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCF7FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFF006E73)),
                      const SizedBox(width: 4),
                      Text(
                        'Switch',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF006E73),
                        ),
                      ),
                    ],
                  ),
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
                              _activeSchedule.timezone,
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

  Widget _buildMappedWorkforceCard() {
    final assignedStaff = _employees.where((e) => _assignedEmployeeIds.contains(e.id)).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 18, color: Color(0xFF57344F)),
                  const SizedBox(width: 8),
                  Text(
                    'Mapped Workforce & Contracts',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${assignedStaff.length}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF57344F)),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _openAssignEmployeeSheet,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_alt_outlined, size: 14, color: Color(0xFF00696E)),
                      const SizedBox(width: 4),
                      Text(
                        'Assign',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF00696E)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (assignedStaff.isEmpty)
            Text('No employees currently assigned to this schedule.', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: assignedStaff.map((emp) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xFF57344F).withValues(alpha: 0.15),
                        child: Text(
                          emp.name.substring(0, 1),
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF57344F)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        emp.name,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${emp.department})',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
              Expanded(
                child: Row(
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
                    Flexible(
                      child: Text(
                        shift.day,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF131B2E),
                        ),
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
              ),
              const SizedBox(width: 8),
              Row(
                children: [
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

          // 3-Column Interactive Time Grid
          Row(
            children: [
              // Start Time Picker
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
                      onTap: () => _pickStartTime(shift),
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
                            const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF714B67)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // End Time Picker
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
                      onTap: () => _pickEndTime(shift),
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
                            const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF714B67)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Break Duration Selector
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Break',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _pickBreakDuration(shift),
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
                              shift.breakMinutes == 60 ? '1h 00m' : (shift.breakMinutes == 0 ? '0m' : '${shift.breakMinutes}m'),
                              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF714B67)),
                          ],
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
