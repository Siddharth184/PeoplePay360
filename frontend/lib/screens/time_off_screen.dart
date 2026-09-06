import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/time_off_service.dart';
import '../services/api_client.dart';

class TimeOffScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const TimeOffScreen({super.key, this.onNavigateTab});

  @override
  State<TimeOffScreen> createState() => _TimeOffScreenState();
}

class _TimeOffScreenState extends State<TimeOffScreen> with SingleTickerProviderStateMixin {
  String _selectedTab = 'To Approve';
  int _toReviewCount = 0;
  int _approvedCount = 0;
  late AnimationController _pulseController;

  // Custom Toast State
  bool _showToast = false;
  String _toastTitle = 'Request Processed';
  String _toastDesc = 'Syncing balance to server...';

  // Request Cards Data & Live Balances
  List<Map<String, dynamic>> _requests = [];
  List<LeaveBalanceModel> _balances = [];
  List<TimeOffTypeModel> _leaveTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchBalancesAndTypes();
    await _fetchRequests();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchBalancesAndTypes() async {
    final typesRes = await TimeOffService.getTimeOffTypes();
    final balancesRes = await TimeOffService.getLeaveBalances();

    if (mounted) {
      setState(() {
        if (typesRes.isSuccess && typesRes.data != null) {
          _leaveTypes = typesRes.data!;
        }
        if (balancesRes.isSuccess && balancesRes.data != null) {
          _balances = balancesRes.data!;
        }
      });
    }
  }

  Future<void> _fetchRequests() async {
    final res = await TimeOffService.getLeaveRequests();
    if (!mounted) return;

    if (res.isSuccess && res.data != null) {
      final parsed = res.data!.map((req) {
        final isAppr = req.status == 'APPROVED';
        final isRefused = req.status == 'REFUSED';
        final isCancelled = req.status == 'CANCELLED';

        String statusLabel = 'Waiting for approval';
        if (isAppr) statusLabel = 'Approved';
        if (isRefused) statusLabel = 'Refused';
        if (isCancelled) statusLabel = 'Cancelled';

        LeaveBalanceModel? matchedBal;
        if (_balances.isNotEmpty) {
          try {
            matchedBal = _balances.firstWhere(
              (b) => b.timeoffTypeId == req.timeoffTypeId ||
                     b.timeoffTypeName.toLowerCase() == req.typeName.toLowerCase(),
            );
          } catch (_) {}
        }

        final allocatedDays = matchedBal?.allocatedDays ?? 0.0;
        final takenDays = matchedBal?.takenDays ?? 0.0;
        final remainingDays = matchedBal?.remainingDays ?? 0.0;

        return {
          'id': req.id,
          'name': req.employeeName ?? 'Employee',
          'role': req.typeName,
          'avatar': '',
          'type': req.typeName,
          'timeoffTypeId': req.timeoffTypeId,
          'ref': req.id.length > 8 ? 'REQ-${req.id.substring(0, 8).toUpperCase()}' : 'REQ-${req.id}',
          'dateRange': '${req.startDate} → ${req.endDate}',
          'startDate': req.startDate,
          'endDate': req.endDate,
          'days': req.daysCount,
          'durationLabel': '${req.daysCount.toStringAsFixed(req.daysCount.truncateToDouble() == req.daysCount ? 0 : 1)} Working Days',
          'rawStatus': req.status,
          'status': statusLabel,
          'isApproved': isAppr,
          'isPending': req.status == 'TO_APPROVE',
          'note': req.reason.isNotEmpty ? req.reason : 'Time off request',
          'time': req.createdAt != null && req.createdAt!.length >= 10 ? req.createdAt!.substring(0, 10) : 'Recent',
          'leaveQuota': matchedBal != null ? '${matchedBal.timeoffTypeName} Quota' : '${req.typeName} Quota',
          'allocatedDays': allocatedDays,
          'takenDays': takenDays,
          'remainingDays': remainingDays,
        };
      }).toList();

      setState(() {
        _requests = parsed;
        _toReviewCount = parsed.where((r) => r['rawStatus'] == 'TO_APPROVE').length;
        _approvedCount = parsed.where((r) => r['rawStatus'] == 'APPROVED').length;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerToast(String title, String desc) {
    setState(() {
      _toastTitle = title;
      _toastDesc = desc;
      _showToast = true;
    });
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _showToast = false);
    });
  }

  void _approveRequest(String id, String name, double days) async {
    final res = await TimeOffService.approveLeaveRequest(id);
    if (res.isSuccess) {
      _triggerToast('Request Approved ✓', '$name granted ${days.toStringAsFixed(0)} days. Allocation debited.');
    } else {
      _triggerToast('Approval Failed', res.errorMessage ?? 'Could not approve leave request');
    }
    await _fetchBalancesAndTypes();
    await _fetchRequests();
  }

  void _rejectRequest(String id, String name) async {
    final res = await TimeOffService.refuseLeaveRequest(id, 'Refused by HR');
    if (res.isSuccess) {
      _triggerToast('Request Refused', '$name request was refused.');
    } else {
      _triggerToast('Refusal Failed', res.errorMessage ?? 'Could not refuse request');
    }
    await _fetchBalancesAndTypes();
    await _fetchRequests();
  }

  void _cancelRequest(String id) async {
    final res = await TimeOffService.cancelLeaveRequest(id);
    if (res.isSuccess) {
      _triggerToast('Request Cancelled', 'Leave request cancelled & balance restored.');
    } else {
      _triggerToast('Cancellation Failed', res.errorMessage ?? 'Could not cancel request');
    }
    await _fetchBalancesAndTypes();
    await _fetchRequests();
  }

  void _approveAllPending() async {
    int count = 0;
    final pending = _requests.where((r) => r['rawStatus'] == 'TO_APPROVE').toList();
    for (var r in pending) {
      final res = await TimeOffService.approveLeaveRequest(r['id'] as String);
      if (res.isSuccess) count++;
    }
    _triggerToast('Bulk Approved ⚡', '$count pending requests approved.');
    await _fetchRequests();
    await _fetchBalancesAndTypes();
  }

  void _openNewLeaveSheet() async {
    if (_leaveTypes.isEmpty || _balances.isEmpty) {
      await _fetchBalancesAndTypes();
    }
    TimeOffTypeModel? selectedType = _leaveTypes.isNotEmpty ? _leaveTypes.first : null;
    final reasonCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    String dayPart = 'FULL_DAY'; // 'FULL_DAY', 'FIRST_HALF', 'SECOND_HALF'

    double requestedDays = 1.0;
    bool isFetchingPreview = false;
    bool hasFetchedInitialPreview = false;
    bool isSubmitting = false;
    String? previewError;
    String? submitErrorText;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (selectedType == null && _leaveTypes.isNotEmpty) {
            selectedType = _leaveTypes.first;
          }

          Future<void> fetchPreview() async {
            final startStr =
                "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
            final endStr =
                "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";

            setModalState(() {
              isFetchingPreview = true;
              previewError = null;
              submitErrorText = null;
            });

            final res = await TimeOffService.getDurationPreview(
              startDate: startStr,
              endDate: endStr,
              dayPart: dayPart,
            );

            if (ctx.mounted) {
              setModalState(() {
                isFetchingPreview = false;
                if (res.isSuccess && res.data != null) {
                  final numDays = (res.data!['working_days'] is num)
                      ? (res.data!['working_days'] as num).toDouble()
                      : 1.0;
                  requestedDays = numDays;
                } else {
                  previewError = res.errorMessage ?? "Selected date range contains no working days.";
                }
              });
            }
          }

          // Initial preview load once
          if (!hasFetchedInitialPreview) {
            hasFetchedInitialPreview = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              fetchPreview();
            });
          }

          // Find balance for selected type
          LeaveBalanceModel? activeBalance;
          if (selectedType != null && _balances.isNotEmpty) {
            try {
              activeBalance = _balances.firstWhere(
                (b) => b.timeoffTypeId == selectedType!.id ||
                       b.timeoffTypeName.toLowerCase() == selectedType!.name.toLowerCase(),
              );
            } catch (_) {}
          }

          double defaultAlloc = 0.0;
          if (selectedType != null && selectedType!.isPaid) {
            if (selectedType!.name.contains('Sick')) {
              defaultAlloc = 10.0;
            } else if (selectedType!.name.contains('Maternity')) {
              defaultAlloc = 90.0;
            } else if (selectedType!.name.contains('Comp')) {
              defaultAlloc = 5.0;
            } else {
              defaultAlloc = 20.0;
            }
          }

          final allocated = activeBalance?.allocatedDays ?? defaultAlloc;
          final taken = activeBalance?.takenDays ?? 0.0;
          final remaining = activeBalance != null ? activeBalance.remainingDays : (allocated - taken);
          final remainingAfterApproval = remaining - requestedDays;

          final bool requiresAllocation = selectedType?.requiresAllocation ?? (selectedType?.isPaid ?? true);
          final bool isExceeding = requiresAllocation && (requestedDays > remaining);

          String fmtDate(DateTime d) =>
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              top: 20,
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
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF92EFF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.beach_access, color: Color(0xFF006E73), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Request Time Off',
                            style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF4E444A)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Leave Type Dropdown
                  Text('Time Off Type *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TimeOffTypeModel>(
                        value: selectedType,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                        items: _leaveTypes.map((t) {
                          return DropdownMenuItem<TimeOffTypeModel>(
                            value: t,
                            child: Text(
                              '${t.name} (${t.isPaid ? 'Paid' : 'Unpaid'})',
                              style: const TextStyle(color: Color(0xFF131B2E), fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedType = val);
                            fetchPreview();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date Selection Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start Date *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 730)),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    startDate = picked;
                                    if (endDate.isBefore(startDate)) endDate = startDate;
                                  });
                                  fetchPreview();
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(fmtDate(startDate), style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                    const Icon(Icons.calendar_month, size: 16, color: Color(0xFF00696E)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('End Date *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime.now().add(const Duration(days: 730)),
                                );
                                if (picked != null) {
                                  setModalState(() => endDate = picked);
                                  fetchPreview();
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(fmtDate(endDate), style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                    const Icon(Icons.calendar_month, size: 16, color: Color(0xFF00696E)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Half-day Mode Option (Single day only)
                  if (startDate.year == endDate.year && startDate.month == endDate.month && startDate.day == endDate.day) ...[
                    Text('Duration Mode', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildDayPartChoice('Full Day', 'FULL_DAY', dayPart, (val) {
                          setModalState(() => dayPart = val);
                          fetchPreview();
                        }),
                        const SizedBox(width: 8),
                        _buildDayPartChoice('First Half', 'FIRST_HALF', dayPart, (val) {
                          setModalState(() => dayPart = val);
                          fetchPreview();
                        }),
                        const SizedBox(width: 8),
                        _buildDayPartChoice('Second Half', 'SECOND_HALF', dayPart, (val) {
                          setModalState(() => dayPart = val);
                          fetchPreview();
                        }),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Dynamic Balance Preview Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isExceeding ? const Color(0xFFFFDAD6) : const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isExceeding ? const Color(0xFFBA1A1A) : const Color(0xFF92EFF5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'LEAVE BALANCE DYNAMICS',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isExceeding ? const Color(0xFFBA1A1A) : const Color(0xFF00696E),
                              ),
                            ),
                            if (isFetchingPreview)
                              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                              Text(
                                '${requestedDays.toStringAsFixed(requestedDays.truncateToDouble() == requestedDays ? 0 : 1)} Working Days',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF131B2E),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Allocated: ${allocated.toStringAsFixed(1)}d', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade700)),
                            Text('Used / Taken: ${taken.toStringAsFixed(1)}d', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Current Remaining:', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text('${remaining.toStringAsFixed(1)} days', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF006E73))),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Balance After Approval:', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(
                              '${remainingAfterApproval.toStringAsFixed(1)} days',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isExceeding ? const Color(0xFFBA1A1A) : const Color(0xFF57344F),
                              ),
                            ),
                          ],
                        ),
                        if (selectedType != null && !selectedType!.isPaid) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 14, color: Color(0xFFD97706)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Unpaid Leave — May result in Loss of Pay (LOP) deduction during payroll.',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFD97706)),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (isExceeding) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.error_outline, size: 14, color: Color(0xFFBA1A1A)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Requested duration exceeds available allocation!',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFBA1A1A)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (previewError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(10)),
                      child: Text(previewError!, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFBA1A1A))),
                    ),
                  ],

                  if (submitErrorText != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(10)),
                      child: Text(submitErrorText!, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFBA1A1A))),
                    ),
                  ],

                  const SizedBox(height: 14),
                  Text('Reason / Description *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF131B2E),
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Family function & personal travel',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600),
                      filled: true,
                      fillColor: const Color(0xFFF2F3FF),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            backgroundColor: (isExceeding || isFetchingPreview || selectedType == null || previewError != null)
                                ? Colors.grey
                                : const Color(0xFF00696E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: (isExceeding || isFetchingPreview || isSubmitting || selectedType == null || previewError != null)
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  final startStr =
                                      "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
                                  final endStr =
                                      "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";

                                  final res = await TimeOffService.createLeaveRequestSelf(
                                    timeOffTypeId: selectedType!.id,
                                    startDate: startStr,
                                    endDate: endStr,
                                    reason: reasonCtrl.text.isEmpty ? 'Personal leave' : reasonCtrl.text,
                                    dayPart: dayPart,
                                  );

                                  if (res.isSuccess) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    _triggerToast('Application Submitted ✓', 'Time off request created and sent for approval.');
                                     await _fetchBalancesAndTypes();
                                     await _fetchRequests();
                                  } else {
                                    setModalState(() {
                                      isSubmitting = false;
                                      submitErrorText = res.errorMessage ?? 'Failed to submit time off request';
                                    });
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text('Submit Request'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayPartChoice(String label, String value, String currentVal, Function(String) onSelect) {
    final bool isSel = currentVal == value;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF714B67) : const Color(0xFFF2F3FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                color: isSel ? Colors.white : const Color(0xFF131B2E),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHrView = ApiClient.hasTimeOffApprovalAccess;
    final bool isEmployeeView = ApiClient.isEmployee;
    final currentEmpName = ApiClient.currentEmployeeName ?? '';

    // RBAC: Employee sees only own requests; HR+ sees all
    final roleFilteredRequests = isEmployeeView
        ? _requests.where((r) => (r['name'] as String?)?.toLowerCase() == currentEmpName.toLowerCase()).toList()
        : _requests;

    final pendingList = roleFilteredRequests.where((r) => r['isPending'] == true || r['rawStatus'] == 'TO_APPROVE').toList();
    final approvedList = roleFilteredRequests.where((r) => r['isApproved'] == true || r['rawStatus'] == 'APPROVED').toList();

    List<Map<String, dynamic>> displayedRequests;
    if (_selectedTab == 'To Approve' || _selectedTab == 'My Pending') {
      displayedRequests = pendingList;
    } else if (_selectedTab == 'Approved' || _selectedTab == 'My Approved') {
      displayedRequests = approvedList;
    } else {
      displayedRequests = roleFilteredRequests;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header & KPI Section
                  _buildHeaderSection(),

                  // Sticky Filter Bar
                  _buildFilterBar(pendingList.length),

                  // Fast Bulk Action Banner (HR+ only)
                  if (isHrView && pendingList.isNotEmpty) _buildBulkBanner(pendingList.length),

                  // Request Cards Stream
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _isLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : (displayedRequests.isEmpty && (_selectedTab == 'To Approve' || _selectedTab == 'My Pending')
                            ? _buildEmptyState()
                            : Column(
                                children: displayedRequests.map((r) => _buildRequestCard(r, showApprovalActions: isHrView)).toList(),
                              )),
                  ),
                ],
              ),
            ),
          ),

          // Delight Top Toast Alert
          if (_showToast)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: _buildToastNotification(),
            ),

          // Floating Action Button (Only for regular employees requesting leave; removed for HR login)
          if (!isHrView)
            Positioned(
              bottom: 24,
              right: 16,
              child: _buildFab(),
            ),
        ],
      ),
    );
  }

  Widget _buildToastNotification() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFF006443),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _toastTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                      Text(
                        _toastDesc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
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
          Text(
            'Just now',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF00696E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Live KPI Overview Ribbon
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // To Review
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) => Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF714B67).withValues(alpha: 0.4 + 0.6 * _pulseController.value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'To Review',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4E444A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_toReviewCount',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF714B67),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(width: 1, height: 26, color: const Color(0xFFDAE2FD)),

                // Approved
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Approved',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4E444A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_approvedCount',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF006443),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Container(width: 1, height: 26, color: const Color(0xFFDAE2FD)),

                // Total Balances Summary
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Balances',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4E444A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_balances.fold<double>(0, (sum, b) => sum + b.remainingDays).toStringAsFixed(0)}d',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 19,
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
          ),

          _buildBalancesOverview(),
        ],
      ),
    );
  }

  Widget _buildBalancesOverview() {
    if (_balances.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave Balances Overview',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _balances.map((b) {
                final isPaid = b.timeoffTypeName.toLowerCase().contains('paid') ||
                    b.timeoffTypeName.toLowerCase().contains('pto') ||
                    b.timeoffTypeName.toLowerCase().contains('sick');
                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPaid ? const Color(0xFF006443) : const Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            b.timeoffTypeName,
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPaid ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPaid ? 'Paid' : 'Unpaid',
                              style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: isPaid ? const Color(0xFF006443) : const Color(0xFFD97706)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Allocated', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF80747A))),
                              Text('${b.allocatedDays.toStringAsFixed(0)}d', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E))),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Used / Taken', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF80747A))),
                              Text('${b.takenDays.toStringAsFixed(0)}d', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF714B67))),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Remaining', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF80747A))),
                              Text('${b.remainingDays.toStringAsFixed(0)}d', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: isPaid ? const Color(0xFF006443) : const Color(0xFFD97706))),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(int pendingCount) {
    final bool isEmployeeView = ApiClient.isEmployee;
    final tabs = isEmployeeView
        ? [
            {'name': 'My Pending', 'badge': pendingCount > 0 ? '$pendingCount' : null},
            {'name': 'My Approved', 'badge': null},
            {'name': 'All Mine', 'badge': null},
          ]
        : [
            {'name': 'To Approve', 'badge': pendingCount > 0 ? '$pendingCount' : null},
            {'name': 'Approved', 'badge': null},
            {'name': 'All Requests', 'badge': null},
          ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: tabs.map((tab) {
          final isSel = _selectedTab == tab['name'];
          final badge = tab['badge'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedTab = tab['name'] as String),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFF714B67) : const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: const Color(0xFF714B67).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Text(
                      tab['name'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                        color: isSel ? Colors.white : const Color(0xFF4E444A),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBA1A1A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBulkBanner(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEDFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: Color(0xFF00696E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count pending request(s) awaiting your review.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _approveAllPending,
            child: Text(
              'Approve All',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00696E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r, {bool showApprovalActions = true}) {
    final id = r['id'] as String;
    final name = r['name'] as String;
    final isApproved = r['isApproved'] as bool;
    final hasCalendar = r['calendar'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar, Name, Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF2F3FF),
                      ),
                      child: Center(
                        child: Text(
                          name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF714B67)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF131B2E),
                            ),
                          ),
                          Text(
                            r['role'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: const Color(0xFF4E444A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isApproved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6FFBBE).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 14, color: Color(0xFF004A31)),
                      const SizedBox(width: 4),
                      Text(
                        'Approved',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF004A31),
                        ),
                      ),
                    ],
                  ),
                )
              else if (r['rawStatus'] == 'REFUSED')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDAD6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.close, size: 14, color: Color(0xFFBA1A1A)),
                      const SizedBox(width: 4),
                      Text(
                        'Refused',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFBA1A1A),
                        ),
                      ),
                    ],
                  ),
                )
              else if (r['rawStatus'] == 'CANCELLED')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'Cancelled',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDAE2FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(color: Color(0xFF714B67), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'To Approve',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF714B67),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Leave Type & Reference
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF92EFF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  r['type'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF006E73),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                r['ref'] as String,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: const Color(0xFF80747A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Date Range & Duration
          Text(
            r['dateRange'] as String,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF131B2E),
            ),
          ),
          if (r['durationLabel'] != null && !isApproved) ...[
            const SizedBox(height: 2),
            Text(
              r['durationLabel'] as String,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00696E),
              ),
            ),
          ],

          // Calendar Strip (if available)
          if (hasCalendar) ...[
            const SizedBox(height: 10),
            Row(
              children: (r['calendar'] as List).map((c) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          c['day'] as String,
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF80747A), fontWeight: FontWeight.bold),
                        ),
                        Text(
                          c['num'] as String,
                          style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                        ),
                        Text(
                          c['tag'] as String,
                          style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w600, color: c['color'] as Color),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Balance Impact Widget (if available)
          if (r['leaveQuota'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.pie_chart_outline, size: 16, color: Color(0xFF00696E)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                r['leaveQuota'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${r['remainingDays']} days left',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4E444A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar
                  Builder(
                    builder: (context) {
                      final allocatedVal = (r['allocatedDays'] as num?)?.toDouble() ?? 0.0;
                      final takenVal = (r['takenDays'] as num?)?.toDouble() ?? 0.0;
                      final reqDays = (r['days'] as num?)?.toDouble() ?? 0.0;
                      final remainingVal = (r['remainingDays'] as num?)?.toDouble() ?? 0.0;

                      final double takenRatio = allocatedVal > 0 ? (takenVal / allocatedVal).clamp(0.0, 1.0) : 0.0;
                      final double reqRatio = allocatedVal > 0 ? (reqDays / allocatedVal).clamp(0.0, 1.0) : 0.0;
                      final double remainRatio = allocatedVal > 0 ? (1.0 - takenRatio - reqRatio).clamp(0.0, 1.0) : 1.0;

                      final int takenFlex = (takenRatio * 100).toInt().clamp(1, 100);
                      final int reqFlex = (reqRatio * 100).toInt().clamp(1, 100);
                      final int remainFlex = (remainRatio * 100).toInt().clamp(1, 100);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 6,
                              child: Row(
                                children: [
                                  if (takenFlex > 0) Expanded(flex: takenFlex, child: Container(color: const Color(0xFF714B67))),
                                  if (reqFlex > 0) Expanded(flex: reqFlex, child: Container(color: const Color(0xFF00696E))),
                                  if (remainFlex > 0) Expanded(flex: remainFlex, child: Container(color: const Color(0xFF006443))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Consumes ${reqDays.toStringAsFixed(reqDays.truncateToDouble() == reqDays ? 0 : 1)} day(s) from allocation (${allocatedVal.toStringAsFixed(0)}d total, ${takenVal.toStringAsFixed(0)}d taken). ${remainingVal.toStringAsFixed(1)} days remaining.',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          // Note / Reason
          if (r['note'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEDFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('🌴', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${r['note']}"',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Approved footer metadata
          if (isApproved && r['approvalNote'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      r['approvalNote'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r['approver'] ?? '',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF006443)),
                  ),
                ],
              ),
            ),
          ],

          // Manager Subtitle
          if (r['manager'] != null && !isApproved) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFF714B67),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            r['managerInitials'] ?? 'M',
                            style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Direct Manager: ${r['manager']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  r['time'] as String,
                  style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF80747A)),
                ),
              ],
            ),
          ],

          // Action Buttons: Refuse & Approve (HR+ only)
          if (r['rawStatus'] == 'TO_APPROVE' && showApprovalActions) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFDAD6),
                      foregroundColor: const Color(0xFFBA1A1A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: () => _rejectRequest(id, name),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(
                      'Refuse',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004A31),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: () => _approveRequest(id, name, (r['days'] as num).toDouble()),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: Text(
                      'Approve',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Action Button: Cancel (Employee self-service for pending request)
          if (r['rawStatus'] == 'TO_APPROVE' && !showApprovalActions) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBA1A1A),
                  side: const BorderSide(color: Color(0xFFBA1A1A)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                ),
                onPressed: () => _cancelRequest(id),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: Text(
                  'Cancel Request',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFF92EFF5),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.celebration, color: Color(0xFF006E73), size: 30),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Inbox Zero! All Clear 🎉',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
          ),
          const SizedBox(height: 6),
          Text(
            'No pending time-off requests to display right now.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF4E444A)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDAE2FD),
              foregroundColor: const Color(0xFF714B67),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            onPressed: () => setState(() => _selectedTab = ApiClient.isEmployee ? 'All Mine' : 'All Requests'),
            child: Text(ApiClient.isEmployee ? 'View All My Requests' : 'Review All Requests', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00696E),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 6,
      ),
      onPressed: _openNewLeaveSheet,
      icon: const Icon(Icons.add, size: 20),
      label: Text(
        'Request Leave',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
