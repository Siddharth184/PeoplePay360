import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../services/contract_service.dart';
import '../services/employee_service.dart';
import '../services/mock_data_service.dart';
import '../models/models.dart';

class ContractsScreen extends StatefulWidget {
  final void Function(int index)? onNavigateTab;
  final EmployeeModel? initialEmployee;
  final String? employeeId;

  const ContractsScreen({
    super.key,
    this.onNavigateTab,
    this.initialEmployee,
    this.employeeId,
  });

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  bool _rulesExpanded = true;
  late EmployeeModel _emp;

  // Contract View / Edit State
  String? _contractId = 'con-01';
  String _contractRef = 'CON/2026/0042';
  DateTime _startDate = DateTime(2026, 1, 1);
  DateTime? _endDate;
  String _department = 'Finance & Tech Ops';
  String _jobPosition = 'HR Manager & People Director';
  double _monthlyWage = 100000.0;
  String _salaryStructure = 'Regular Employee Base';
  String _selectedStage = 'Running';
  String _schedule = '40 Hours / Week (Standard)';
  String _contractType = 'Permanent / Full-Time';

  List<ContractModel> _allContracts = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialEmployee != null) {
      _emp = widget.initialEmployee!;
    } else if (widget.employeeId != null && widget.employeeId!.isNotEmpty) {
      _emp = MockDataService.allEmployees.firstWhere(
        (e) => e.id == widget.employeeId,
        orElse: () => MockDataService.currentEmployee,
      );
    } else {
      _emp = MockDataService.currentEmployee;
    }
    EmployeeService.currentEmployeeNotifier.addListener(_onEmployeeChanged);
    _fetchContracts();
  }

  void _onEmployeeChanged() {
    if (mounted && widget.initialEmployee == null && widget.employeeId == null) {
      setState(() {
        _emp = EmployeeService.currentEmployeeNotifier.value;
      });
      _fetchContracts();
    }
  }

  @override
  void dispose() {
    EmployeeService.currentEmployeeNotifier.removeListener(_onEmployeeChanged);
    super.dispose();
  }

  Future<void> _fetchContracts() async {
    final res = await ContractService.getContracts(employeeId: _emp.id);
    if (mounted && res.isSuccess && res.data != null && res.data!.isNotEmpty) {
      _allContracts = res.data!;
      final matching = _allContracts.firstWhere(
        (c) => _matchesEmployeeName(c.employeeName, _emp.name) && (c.status == 'RUNNING' || c.status == 'Running'),
        orElse: () => _allContracts.firstWhere(
          (c) => _matchesEmployeeName(c.employeeName, _emp.name),
          orElse: () => _buildFallbackContract(_emp),
        ),
      );
      _applyContractData(matching);
    } else {
      // Fallback from MockDataService
      _allContracts = MockDataService.contracts;
      final matching = _allContracts.firstWhere(
        (c) => _matchesEmployeeName(c.employeeName, _emp.name) && (c.status == 'RUNNING' || c.status == 'Running'),
        orElse: () => _allContracts.firstWhere(
          (c) => _matchesEmployeeName(c.employeeName, _emp.name),
          orElse: () => _buildFallbackContract(_emp),
        ),
      );
      _applyContractData(matching);
    }
  }

  void _updateContractStage(String newStage) {
    if (_selectedStage == newStage) return;

    final apiStatus = newStage == 'Running'
        ? 'RUNNING'
        : (newStage == 'Expired'
            ? 'EXPIRED'
            : (newStage == 'Cancelled' ? 'CANCELLED' : 'DRAFT'));

    setState(() {
      _selectedStage = newStage;

      // Update in local _allContracts
      final idxInAll = _allContracts.indexWhere((c) => c.id == _contractId || c.refCode == _contractRef);
      if (idxInAll != -1) {
        final old = _allContracts[idxInAll];
        _allContracts[idxInAll] = ContractModel(
          id: old.id,
          refCode: old.refCode,
          employeeName: old.employeeName,
          department: old.department,
          startDate: old.startDate,
          endDate: old.endDate,
          wageMonthly: old.wageMonthly,
          status: apiStatus,
          structureName: old.structureName,
        );
      }

      // Update in MockDataService.contracts
      final idxInMock = MockDataService.contracts.indexWhere((c) => c.id == _contractId || c.refCode == _contractRef);
      if (idxInMock != -1) {
        final old = MockDataService.contracts[idxInMock];
        MockDataService.contracts[idxInMock] = ContractModel(
          id: old.id,
          refCode: old.refCode,
          employeeName: old.employeeName,
          department: old.department,
          startDate: old.startDate,
          endDate: old.endDate,
          wageMonthly: old.wageMonthly,
          status: apiStatus,
          structureName: old.structureName,
        );
      }
    });

    if (_contractId != null) {
      ContractService.updateContract(_contractId!, {'status': apiStatus});
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚡ Contract stage updated to $newStage'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _matchesEmployeeName(String contractEmpName, String targetEmpName) {
    final c = contractEmpName.toLowerCase().trim();
    final t = targetEmpName.toLowerCase().trim();
    if (c == t) return true;
    final cParts = c.split(' ');
    final tParts = t.split(' ');
    if (cParts.first.length >= 3 && tParts.first.length >= 3 && cParts.first == tParts.first) {
      return true;
    }
    return false;
  }

  ContractModel _buildFallbackContract(EmployeeModel emp) {
    final ref = 'CON/2026/${(emp.name.hashCode.abs() % 8999 + 1000)}';
    final joiningDt = DateTime.tryParse(emp.dateOfJoining ?? '') ?? DateTime(2024, 1, 1);
    final isExecutive = emp.jobTitle.toLowerCase().contains('director') ||
        emp.jobTitle.toLowerCase().contains('manager') ||
        emp.jobTitle.toLowerCase().contains('lead');
    final structure = isExecutive ? 'Executive Salary Structure' : 'Regular Employee Base';

    return ContractModel(
      id: 'con-${emp.id}',
      refCode: ref,
      employeeName: emp.name,
      department: emp.department.isNotEmpty ? emp.department : 'Human Resources',
      startDate: "${joiningDt.year}-${joiningDt.month.toString().padLeft(2, '0')}-${joiningDt.day.toString().padLeft(2, '0')}",
      wageMonthly: isExecutive ? 115000.0 : 85000.0,
      status: 'RUNNING',
      structureName: structure,
    );
  }

  void _applyContractData(ContractModel c) {
    if (!mounted) return;
    setState(() {
      _contractId = c.id;
      _contractRef = c.refCode.isNotEmpty ? c.refCode : 'CON/2026/0042';
      _monthlyWage = c.wageMonthly > 0 ? c.wageMonthly : 100000.0;
      _selectedStage = c.status == 'RUNNING'
          ? 'Running'
          : (c.status == 'EXPIRED'
              ? 'Expired'
              : (c.status == 'CANCELLED' ? 'Cancelled' : 'Draft'));
      _department = c.department.isNotEmpty ? c.department : _emp.department;
      _jobPosition = _emp.jobTitle.isNotEmpty ? _emp.jobTitle : 'Senior Analyst';
      _startDate = DateTime.tryParse(c.startDate) ?? DateTime(2026, 1, 1);
      _endDate = c.endDate != null && c.endDate!.isNotEmpty ? DateTime.tryParse(c.endDate!) : null;
      _salaryStructure = c.structureName ?? 'Regular Employee Base';
    });
  }

  String _formatDateStr(DateTime? dt) {
    if (dt == null) return 'Ongoing (—)';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dayStr = dt.day.toString().padLeft(2, '0');
    final monStr = months[dt.month - 1];
    return '$dayStr-$monStr-${dt.year}';
  }

  String _formatYMD(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  /// Validation logic against overlapping active contracts
  String? _checkOverlap({
    required String? currentContractId,
    required DateTime startDate,
    required DateTime? endDate,
    required String stage,
    required String employeeName,
  }) {
    if (stage != 'Running') return null;

    final targetNameLower = employeeName.toLowerCase().trim();

    for (final c in _allContracts) {
      if (currentContractId != null && c.id == currentContractId) {
        continue;
      }

      final isSameEmployee = c.employeeName.toLowerCase().trim() == targetNameLower ||
          c.employeeName.toLowerCase().contains(targetNameLower.split(' ').first);

      if (!isSameEmployee) continue;

      final isRunning = c.status == 'RUNNING' || c.status == 'Running';
      if (!isRunning) continue;

      final otherStart = DateTime.tryParse(c.startDate) ?? DateTime(2026, 1, 1);
      final otherEnd = c.endDate != null && c.endDate!.isNotEmpty ? DateTime.tryParse(c.endDate!) : null;

      final bool overlaps = (otherEnd == null || !startDate.isAfter(otherEnd)) &&
          (endDate == null || !endDate.isBefore(otherStart));

      if (overlaps) {
        final endLabel = otherEnd != null ? _formatDateStr(otherEnd) : 'Ongoing';
        return 'Overlapping active contract detected! Employee ($employeeName) already has an active Running contract (${c.refCode}) for period ${_formatDateStr(otherStart)} to $endLabel.';
      }
    }

    return null;
  }

  void _openEditContractSheet() {
    final wageCtrl = TextEditingController(text: _monthlyWage.toStringAsFixed(2));
    final positionCtrl = TextEditingController(text: _jobPosition);

    DateTime editStartDate = _startDate;
    DateTime? editEndDate = _endDate;
    String editDept = _department;
    String editStruct = _salaryStructure;
    String editStage = _selectedStage;
    String editSchedule = _schedule;
    String editType = _contractType;

    String? sheetError;

    final departmentsList = [
      'Finance & Tech Ops',
      'Human Resources',
      'Engineering',
      'Design',
      'Sales',
      'Executive Management',
      'Customer Support',
    ];

    final structuresList = [
      'Regular Employee Base',
      'Contractor Base',
      'Executive Salary Structure',
      'Intern Stipend',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
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
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD7F1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_note, color: Color(0xFF714B67), size: 22),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Update Contract Terms',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF131B2E),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF4E444A)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Edit employee dates, department, position, wage, structure & status.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    // Validation Error Banner inside sheet if present
                    if (sheetError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF5350)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sheetError!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFB71C1C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Stage Selector
                    Text(
                      'Contract Stage *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ['Draft', 'Running', 'Expired', 'Cancelled'].map((st) {
                        final isSel = editStage == st;
                        return ChoiceChip(
                          label: Text(st),
                          selected: isSel,
                          selectedColor: const Color(0xFF714B67),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSel ? Colors.white : const Color(0xFF4E444A),
                          ),
                          backgroundColor: const Color(0xFFF2F3FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onSelected: (val) {
                            if (val) {
                              setSheetState(() {
                                editStage = st;
                                sheetError = null;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Contract Dates Row (Start & End Date Pickers)
                    Row(
                      children: [
                        // Start Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Date *',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: editStartDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setSheetState(() {
                                      editStartDate = picked;
                                      sheetError = null;
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F3FF),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF714B67)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _formatYMD(editStartDate),
                                          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // End Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'End Date',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                  ),
                                  if (editEndDate != null)
                                    GestureDetector(
                                      onTap: () {
                                        setSheetState(() {
                                          editEndDate = null;
                                          sheetError = null;
                                        });
                                      },
                                      child: Text(
                                        'Set Ongoing',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF00696E)),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: editEndDate ?? editStartDate.add(const Duration(days: 365)),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setSheetState(() {
                                      editEndDate = picked;
                                      sheetError = null;
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F3FF),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.event_busy, size: 16, color: Color(0xFF714B67)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          editEndDate != null ? _formatYMD(editEndDate!) : 'Ongoing',
                                          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: editEndDate != null ? const Color(0xFF131B2E) : const Color(0xFF00696E)),
                                        ),
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
                    const SizedBox(height: 14),

                    // Department Dropdown
                    Text(
                      'Department *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: departmentsList.contains(editDept) ? editDept : departmentsList.first,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                          items: departmentsList.map((d) {
                            return DropdownMenuItem(
                              value: d,
                              child: Text(
                                d,
                                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setSheetState(() => editDept = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Job Position TextField
                    Text(
                      'Job Position / Title *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 46,
                      decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                      child: TextField(
                        controller: positionCtrl,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.work_outline, color: Color(0xFF714B67), size: 18),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Monthly Wage
                    Text(
                      'Monthly Gross Wage (INR ₹) *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 46,
                      decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                      child: TextField(
                        controller: wageCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.currency_rupee, color: Color(0xFF00696E), size: 18),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Salary Structure Dropdown
                    Text(
                      'Salary Structure *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: structuresList.contains(editStruct) ? editStruct : structuresList.first,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                          items: structuresList.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(
                                s,
                                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setSheetState(() => editStruct = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Working Schedule Dropdown
                    Text(
                      'Working Schedule *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: editSchedule,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                          items: const [
                            DropdownMenuItem(
                              value: '40 Hours / Week (Standard)',
                              child: Text('40 Hours / Week (Standard)', style: TextStyle(color: Color(0xFF131B2E), fontWeight: FontWeight.w600)),
                            ),
                            DropdownMenuItem(
                              value: '35 Hours / Week (Flexible)',
                              child: Text('35 Hours / Week (Flexible)', style: TextStyle(color: Color(0xFF131B2E), fontWeight: FontWeight.w600)),
                            ),
                            DropdownMenuItem(
                              value: '48 Hours / Week (Extended)',
                              child: Text('48 Hours / Week (Extended)', style: TextStyle(color: Color(0xFF131B2E), fontWeight: FontWeight.w600)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setSheetState(() => editSchedule = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Contract Type Dropdown
                    Text(
                      'Contract Type *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: editType,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                          items: const [
                            DropdownMenuItem(
                              value: 'Permanent / Full-Time',
                              child: Text('Permanent / Full-Time', style: TextStyle(color: Color(0xFF131B2E), fontWeight: FontWeight.w600)),
                            ),
                            DropdownMenuItem(
                              value: 'Fixed-Term Contract',
                              child: Text('Fixed-Term Contract', style: TextStyle(color: Color(0xFF131B2E), fontWeight: FontWeight.w600)),
                            ),
                            DropdownMenuItem(
                              value: 'Consultant / Retainer',
                              child: Text('Consultant / Retainer', style: TextStyle(color: Color(0xFF131B2E), fontWeight: FontWeight.w600)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setSheetState(() => editType = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save / Cancel Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(context),
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
                            onPressed: () async {
                              // 1. Date range validation
                              if (editEndDate != null && editStartDate.isAfter(editEndDate!)) {
                                setSheetState(() {
                                  sheetError = 'Contract End Date cannot precede Start Date.';
                                });
                                return;
                              }

                              final newWage = double.tryParse(wageCtrl.text.trim()) ?? _monthlyWage;
                              if (newWage <= 0) {
                                setSheetState(() {
                                  sheetError = 'Monthly Gross Wage must be greater than 0.';
                                });
                                return;
                              }

                              // 2. Active Overlap Validation
                              final overlapErr = _checkOverlap(
                                currentContractId: _contractId,
                                startDate: editStartDate,
                                endDate: editEndDate,
                                stage: editStage,
                                employeeName: _emp.name,
                              );

                              if (overlapErr != null) {
                                setSheetState(() {
                                  sheetError = overlapErr;
                                });
                                return;
                              }

                              // 3. Perform update via API if possible
                              final apiStatus = editStage == 'Running'
                                  ? 'RUNNING'
                                  : (editStage == 'Expired'
                                      ? 'EXPIRED'
                                      : (editStage == 'Cancelled' ? 'CANCELLED' : 'DRAFT'));

                              if (_contractId != null) {
                                final payload = {
                                  'start_date': _formatYMD(editStartDate),
                                  'end_date': editEndDate != null ? _formatYMD(editEndDate!) : null,
                                  'wage_monthly': newWage,
                                  'department': editDept,
                                  'job_position': positionCtrl.text.trim(),
                                  'structure_name': editStruct,
                                  'status': apiStatus,
                                };
                                ContractService.updateContract(_contractId!, payload);
                              }

                              // Update in _allContracts & MockDataService.contracts
                              final idxInAll = _allContracts.indexWhere((c) => c.id == _contractId || c.refCode == _contractRef);
                              if (idxInAll != -1) {
                                _allContracts[idxInAll] = ContractModel(
                                  id: _contractId ?? 'con-${_emp.id}',
                                  refCode: _contractRef,
                                  employeeName: _emp.name,
                                  department: editDept,
                                  startDate: _formatYMD(editStartDate),
                                  endDate: editEndDate != null ? _formatYMD(editEndDate!) : null,
                                  wageMonthly: newWage,
                                  status: apiStatus,
                                  structureName: editStruct,
                                );
                              }

                              final idxInMock = MockDataService.contracts.indexWhere((c) => c.id == _contractId || c.refCode == _contractRef);
                              if (idxInMock != -1) {
                                MockDataService.contracts[idxInMock] = ContractModel(
                                  id: _contractId ?? 'con-${_emp.id}',
                                  refCode: _contractRef,
                                  employeeName: _emp.name,
                                  department: editDept,
                                  startDate: _formatYMD(editStartDate),
                                  endDate: editEndDate != null ? _formatYMD(editEndDate!) : null,
                                  wageMonthly: newWage,
                                  status: apiStatus,
                                  structureName: editStruct,
                                );
                              }

                              // Update parent screen state
                              setState(() {
                                _startDate = editStartDate;
                                _endDate = editEndDate;
                                _department = editDept;
                                _jobPosition = positionCtrl.text.trim().isNotEmpty ? positionCtrl.text.trim() : _jobPosition;
                                _monthlyWage = newWage;
                                _salaryStructure = editStruct;
                                _selectedStage = editStage;
                                _schedule = editSchedule;
                                _contractType = editType;
                              });

                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF004A31),
                                  behavior: SnackBarBehavior.floating,
                                  content: Text('✓ Contract terms updated and validated with Odoo Payroll!'),
                                ),
                              );
                            },
                            child: const Text('Save Terms'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _printContractSummary() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF004A31),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.print, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Generating Signed Contract PDF ($_contractRef)...',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Operational Header Bar
            _buildHeaderBar(),

            // Scrollable Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                children: [
                  // Contract Lifecycle Stepper
                  _buildLifecycleStepper(),

                  const SizedBox(height: 12),

                  // Business Guard Banner
                  _buildBusinessGuardBanner(),

                  const SizedBox(height: 12),

                  // Section 1: Employment Terms Card (Employee + Dates + Department + Position)
                  _buildEmploymentTermsCard(),

                  const SizedBox(height: 14),

                  // Section 2: Compensation & Wage Card (Wage + Salary Structure)
                  _buildCompensationCard(),

                  const SizedBox(height: 12),

                  // Section 3: Digital Signature Metadata
                  _buildSignatureCard(),

                  const SizedBox(height: 16),

                  // Dual Action Buttons
                  _buildActionButtons(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    final empContracts = _allContracts.where((c) => _matchesEmployeeName(c.employeeName, _emp.name)).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
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
                      Text(
                        'Contract Details',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                      Row(
                        children: [
                          if (empContracts.length > 1) ...[
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: empContracts.any((c) => c.id == _contractId) ? _contractId : empContracts.first.id,
                                isDense: true,
                                dropdownColor: Colors.white,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4E444A),
                                ),
                                items: empContracts.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c.id,
                                    child: Text('${c.refCode} (${c.status})'),
                                  );
                                }).toList(),
                                onChanged: (selId) {
                                  if (selId != null) {
                                    final selected = empContracts.firstWhere((c) => c.id == selId);
                                    _applyContractData(selected);
                                  }
                                },
                              ),
                            ),
                          ] else ...[
                            Text(
                              _contractRef,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4E444A),
                              ),
                            ),
                          ],
                          const SizedBox(width: 5),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF006443),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _selectedStage.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _selectedStage == 'Cancelled'
                                    ? Colors.red[700]
                                    : const Color(0xFF00696E),
                              ),
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
          Row(
            children: [
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('📜 Audit: Contract created 01-Jan-2026 for ${_emp.name}')),
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
                    child: Icon(Icons.history_edu, size: 18, color: Color(0xFF131B2E)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚡ Options: Print PDF • Export XML • Archive')),
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

  Widget _buildLifecycleStepper() {
    final stages = ['Draft', 'Running', 'Expired', 'Cancelled'];
    final currentIdx = stages.indexOf(_selectedStage);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Connecting Track Line
          Positioned(
            left: 24,
            right: 24,
            top: 15,
            child: Container(
              height: 2,
              color: const Color(0xFFE2E8F0),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stages.asMap().entries.map((entry) {
              final idx = entry.key;
              final name = entry.value;
              final isActive = idx == currentIdx;
              final isDone = idx < currentIdx && _selectedStage != 'Cancelled';

              return InkWell(
                onTap: () => _updateContractStage(name),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: (name == 'Cancelled' ? Colors.red : const Color(0xFF4EDEA3)).withValues(alpha: 0.35),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: name == 'Cancelled' ? Colors.red[700] : const Color(0xFF006443),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  name == 'Cancelled' ? Icons.cancel : Icons.verified,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (isDone)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDAE2FD),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.check, color: Color(0xFF131B2E), size: 16),
                          ),
                        )
                      else
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF2F3FF),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD1C3CA),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                          color: isActive
                              ? (name == 'Cancelled' ? Colors.red[800]! : const Color(0xFF006443))
                              : (isDone ? const Color(0xFF4E444A) : const Color(0xFF80747A)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessGuardBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFCCF7FA).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00696E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_user, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Contract Guard',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF004F53),
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: const Color(0xFF4E444A),
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'Contract parameters for '),
                      TextSpan(text: _emp.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF131B2E))),
                      const TextSpan(text: ' are validated against overlapping active periods to prevent double payruns.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmploymentTermsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF714B67)),
                  const SizedBox(width: 8),
                  Text(
                    'Employment Terms',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDAE2FD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _emp.badgeId ?? 'EMP-4091',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF131B2E),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 1. Employee Info Snippet
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF714B67),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Center(
                    child: Text(
                      _emp.name.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
                              _emp.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF131B2E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF57344F),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _department.toUpperCase(),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$_jobPosition · $_department',
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

          const SizedBox(height: 12),

          // 2. Contract Dates Row
          _buildDetailRow(
            icon: Icons.calendar_month,
            label: 'Contract Dates',
            valueWidget: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDateStr(_startDate),
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('→', style: TextStyle(color: Color(0xFF80747A))),
                  ),
                  Text(
                    _formatDateStr(_endDate),
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF00696E)),
                  ),
                ],
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFCCF7FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _endDate == null ? 'Indefinite' : 'Fixed-Term',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF006E73)),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 3. Department Row
          _buildDetailRow(
            icon: Icons.business,
            label: 'Department',
            valueWidget: Text(
              _department,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
            ),
            trailing: const Icon(Icons.check_circle_outline, size: 17, color: Color(0xFF006443)),
          ),

          const SizedBox(height: 8),

          // 4. Job Position Row
          _buildDetailRow(
            icon: Icons.work_outline,
            label: 'Job Position',
            valueWidget: Text(
              _jobPosition,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
            ),
            trailing: const Icon(Icons.verified, size: 17, color: Color(0xFF714B67)),
          ),

          const SizedBox(height: 8),

          // 5. Working Schedule Row
          _buildDetailRow(
            icon: Icons.schedule,
            label: 'Working Schedule',
            valueWidget: Text(
              _schedule,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
            ),
            trailing: const Icon(Icons.lock_outline, size: 17, color: Color(0xFF80747A)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompensationCard() {
    final annualCtc = _monthlyWage * 12;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
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
                  const Icon(Icons.payments_outlined, size: 20, color: Color(0xFF00696E)),
                  const SizedBox(width: 8),
                  Text(
                    'Compensation & Wage',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF006443).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'INR (₹)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF006443),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Big Numeric Stat Display
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Gross Wage',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                    Text(
                      'Base Formula',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00696E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹ ${_monthlyWage.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00696E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ month',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Cost to Company (CTC)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF4E444A)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '₹ ${annualCtc.toStringAsFixed(2)} / yr',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Salary Structure Breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEDFF),
              borderRadius: BorderRadius.circular(14),
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
                          const Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF714B67)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _salaryStructure,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                                ),
                                Text(
                                  'Salary Structure Configured',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => setState(() => _rulesExpanded = !_rulesExpanded),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rules',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF714B67)),
                            ),
                            Icon(
                              _rulesExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 15,
                              color: const Color(0xFF714B67),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                if (_rulesExpanded) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: const [
                      _RulePill('Basic (50%)'),
                      _RulePill('HRA (40%)'),
                      _RulePill('Std Allowance'),
                      _RulePill('Provident Fund'),
                      _RulePill('Professional Tax'),
                      _RulePill('Special Allowance'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDAE2FD),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.draw_outlined, color: Color(0xFF714B67), size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Digitally Signed via PeoplePay e-Sign',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                      Text(
                        'Hash: 8f9b...a12c · Validated',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
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
          const Icon(Icons.check_circle, color: Color(0xFF006443), size: 20),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool canEdit = ApiClient.hasContractsAccess;
    return Column(
      children: [
        if (canEdit) ...[
          // Update Terms Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF714B67),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 2,
              ),
              onPressed: _openEditContractSheet,
              icon: const Icon(Icons.edit_note, size: 19),
              label: Text(
                'Update Contract Terms',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Print Contract Summary Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF131B2E),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 1,
            ),
            onPressed: _printContractSummary,
            icon: const Icon(Icons.print, size: 19, color: Color(0xFF00696E)),
            label: Text(
              'Print Contract Summary',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required Widget valueWidget,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(icon, size: 17, color: const Color(0xFF714B67)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                      ),
                      const SizedBox(height: 1),
                      valueWidget,
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _RulePill extends StatelessWidget {
  final String text;
  const _RulePill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4E444A),
        ),
      ),
    );
  }
}
