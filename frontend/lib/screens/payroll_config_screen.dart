import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/contract_service.dart';
import '../services/salary_structure_service.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';

class PayrollConfigScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const PayrollConfigScreen({super.key, this.onNavigateTab});

  @override
  State<PayrollConfigScreen> createState() => _PayrollConfigScreenState();
}

class _PayrollConfigScreenState extends State<PayrollConfigScreen> {
  List<SalaryStructureModel> _structures = [];
  SalaryStructureModel? _selectedStructure;
  bool _isLoading = true;
  bool _isLoadingDetail = false;
  String? _error;

  // Simulation inputs
  final TextEditingController _wageController = TextEditingController(text: '100000');
  final TextEditingController _workedDaysController = TextEditingController(text: '22');
  final TextEditingController _expectedDaysController = TextEditingController(text: '22');
  RuleSimulationResponseModel? _simulationResult;
  bool _isSimulating = false;
  String? _simulationError;

  // Employee Payroll Board Filter State
  String _empSearchQuery = '';
  String _selectedDeptFilter = 'All';
  String _selectedPosFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadStructures();
  }

  @override
  void dispose() {
    _wageController.dispose();
    _workedDaysController.dispose();
    _expectedDaysController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // DATA LOADING
  // ===========================================================================
  Future<void> _loadStructures({String? selectId}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await SalaryStructureService.getStructures();
    if (!mounted) return;

    if (res.isSuccess && res.data != null) {
      final list = res.data!;
      setState(() {
        _structures = list;
        _isLoading = false;
      });

      if (list.isNotEmpty) {
        final targetId = selectId ??
            (list.any((s) => s.id == _selectedStructure?.id) ? _selectedStructure!.id : list.first.id);
        _selectStructure(targetId);
      } else {
        setState(() => _selectedStructure = null);
      }
    } else {
      setState(() {
        _error = res.message ?? 'Failed to load salary structures';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectStructure(String structureId) async {
    setState(() {
      _isLoadingDetail = true;
      _simulationResult = null;
      _simulationError = null;
    });

    final res = await SalaryStructureService.getStructureDetail(structureId);
    if (!mounted) return;

    if (res.isSuccess && res.data != null) {
      setState(() {
        _selectedStructure = res.data;
        _isLoadingDetail = false;
      });
    } else {
      final local = _structures.firstWhere(
        (s) => s.id == structureId,
        orElse: () => _structures.first,
      );
      setState(() {
        _selectedStructure = local;
        _isLoadingDetail = false;
      });
    }
  }

  // ===========================================================================
  // SIMULATION
  // ===========================================================================
  Future<void> _runSimulation() async {
    if (_selectedStructure == null) return;
    final wage = double.tryParse(_wageController.text.trim());
    final worked = double.tryParse(_workedDaysController.text.trim()) ?? 22.0;
    final expected = double.tryParse(_expectedDaysController.text.trim()) ?? 22.0;

    if (wage == null || wage <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid monthly wage')),
      );
      return;
    }

    setState(() {
      _isSimulating = true;
      _simulationError = null;
    });

    final payload = {
      'salary_structure_id': _selectedStructure!.id,
      'wage_monthly': wage,
      'worked_days': worked,
      'expected_days': expected,
    };

    final res = await SalaryStructureService.simulateStructure(payload);
    if (!mounted) return;

    if (res.isSuccess && res.data != null) {
      setState(() {
        _simulationResult = res.data;
        _isSimulating = false;
      });
    } else {
      setState(() {
        _simulationError = res.message ?? 'Simulation failed';
        _isSimulating = false;
      });
    }
  }

  // ===========================================================================
  // STRUCTURE MODAL
  // ===========================================================================
  void _openStructureModal({SalaryStructureModel? structureToEdit}) {
    if (!_canEdit) {
      _showReadOnlyNotice();
      return;
    }

    final isEdit = structureToEdit != null;
    final nameController = TextEditingController(text: isEdit ? structureToEdit.name : '');
    final codeController = TextEditingController(text: isEdit ? structureToEdit.code : '');
    final notesController = TextEditingController(text: isEdit ? structureToEdit.notes : '');
    bool isActive = isEdit ? structureToEdit.isActive : true;
    bool isSubmitting = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Salary Structure' : 'New Salary Structure',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (modalError != null) ...[
                      _buildErrorBanner(modalError!),
                      const SizedBox(height: 12),
                    ],

                    _buildTextField(controller: nameController, label: 'Structure Name *', hint: 'e.g. Regular Staff Salary'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: codeController,
                      label: 'Code *',
                      hint: 'e.g. REG_SALARY',
                      capitalization: TextCapitalization.characters,
                      helperText: 'Uppercase letters, numbers, and underscores only',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(controller: notesController, label: 'Notes / Description', maxLines: 2),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Active Status', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight)),
                        Switch(
                          value: isActive,
                          activeTrackColor: AppTheme.odooAubergine,
                          onChanged: (val) => setModalState(() => isActive = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.odooAubergine,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final code = codeController.text.trim().toUpperCase();
                                if (name.isEmpty || code.isEmpty) {
                                  setModalState(() => modalError = 'Name and Code are required');
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  modalError = null;
                                });

                                final payload = {
                                  'name': name,
                                  'code': code,
                                  'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                  if (isEdit) 'is_active': isActive,
                                };

                                final nav = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);
                                final res = isEdit
                                    ? await SalaryStructureService.updateStructure(structureToEdit.id, payload)
                                    : await SalaryStructureService.createStructure(payload);

                                if (!mounted) return;

                                if (res.isSuccess && res.data != null) {
                                  nav.pop();
                                  _loadStructures(selectId: res.data!.id);
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Structure ${isEdit ? "updated" : "created"} successfully')),
                                  );
                                } else {
                                  setModalState(() {
                                    isSubmitting = false;
                                    modalError = res.message ?? 'Action failed';
                                  });
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(isEdit ? 'Update Structure' : 'Create Structure', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
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

  // ===========================================================================
  // STRUCTURE DELETE
  // ===========================================================================
  void _confirmDeleteStructure(SalaryStructureModel structure) {
    if (!_canEdit) {
      _showReadOnlyNotice();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Structure', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${structure.name}"? '
          'If referenced by existing payruns, it will be safely deactivated.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondaryLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimsonDanger, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final deletedId = structure.id;
              final res = await SalaryStructureService.deleteStructure(deletedId);
              if (!mounted) return;
              if (res.isSuccess) {
                messenger.showSnackBar(
                  SnackBar(content: Text(res.message ?? res.data?['detail'] ?? 'Structure deleted')),
                );
                setState(() {
                  _structures.removeWhere((s) => s.id == deletedId);
                  if (_selectedStructure?.id == deletedId) {
                    _selectedStructure = _structures.isNotEmpty ? _structures.first : null;
                  }
                });
                _loadStructures();
              } else {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: ${res.message}')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // RULE MODAL
  // ===========================================================================
  void _openRuleModal({SalaryRuleModel? ruleToEdit}) {
    if (!_canEdit) {
      _showReadOnlyNotice();
      return;
    }
    if (_selectedStructure == null) return;

    final isEdit = ruleToEdit != null;
    final nameController = TextEditingController(text: isEdit ? ruleToEdit.name : '');
    final codeController = TextEditingController(text: isEdit ? ruleToEdit.code : '');
    final sequenceController = TextEditingController(text: isEdit ? ruleToEdit.sequence.toString() : '10');
    final fixedAmountController = TextEditingController(text: isEdit && ruleToEdit.fixedAmount != null ? ruleToEdit.fixedAmount.toString() : '');
    final percentageRateController = TextEditingController(text: isEdit && ruleToEdit.percentageRate != null ? ruleToEdit.percentageRate.toString() : '');
    final pythonCodeController = TextEditingController(text: isEdit ? (ruleToEdit.pythonCode ?? '') : 'result = contract.wage * 0.4');
    final quantityController = TextEditingController(text: isEdit ? ruleToEdit.quantity.toString() : '1.0');

    String selectedCategory = isEdit ? ruleToEdit.category : 'BASIC';
    String selectedComputationType = isEdit ? ruleToEdit.computationType : 'FIXED';
    String selectedPercentageBase = isEdit ? (ruleToEdit.percentageBase ?? 'BASIC') : 'BASIC';
    bool isActive = isEdit ? ruleToEdit.isActive : true;

    bool isSubmitting = false;
    bool isValidatingPython = false;
    PythonRuleValidationResponseModel? pythonValidationResult;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Salary Rule' : 'Add Rule',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (modalError != null) ...[
                      _buildErrorBanner(modalError!),
                      const SizedBox(height: 12),
                    ],

                    // All fields stacked vertically for mobile
                    _buildTextField(controller: nameController, label: 'Rule Name *', hint: 'e.g. Basic Salary'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: codeController,
                      label: 'Code *',
                      hint: 'e.g. BASIC',
                      capitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: sequenceController,
                      label: 'Sequence *',
                      hint: '10',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    // Category dropdown
                    _buildDropdownField(
                      label: 'Category *',
                      value: selectedCategory,
                      items: const ['BASIC', 'ALLOWANCE', 'GROSS', 'DEDUCTION', 'NET'],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Computation type dropdown
                    _buildDropdownField(
                      label: 'Computation Type *',
                      value: selectedComputationType,
                      items: const ['FIXED', 'PERCENTAGE', 'PYTHON_CODE'],
                      itemLabels: const {'FIXED': 'Fixed Amount', 'PERCENTAGE': 'Percentage', 'PYTHON_CODE': 'Python Code'},
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedComputationType = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Conditional fields based on computation type
                    if (selectedComputationType == 'FIXED') ...[
                      _buildTextField(
                        controller: fixedAmountController,
                        label: 'Fixed Amount (₹) *',
                        prefixText: '₹ ',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ] else if (selectedComputationType == 'PERCENTAGE') ...[
                      _buildDropdownField(
                        label: 'Percentage Base *',
                        value: selectedPercentageBase,
                        items: const ['WAGE', 'BASIC', 'GROSS'],
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedPercentageBase = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: percentageRateController,
                        label: 'Rate (%) *',
                        suffixText: '%',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ] else if (selectedComputationType == 'PYTHON_CODE') ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Python Expression',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.odooTeal,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            onPressed: isValidatingPython
                                ? null
                                : () async {
                                    setModalState(() {
                                      isValidatingPython = true;
                                      pythonValidationResult = null;
                                    });
                                    final res = await SalaryStructureService.validatePythonRule(
                                      pythonCodeController.text,
                                    );
                                    if (!mounted) return;
                                    setModalState(() {
                                      isValidatingPython = false;
                                      if (res.isSuccess && res.data != null) {
                                        pythonValidationResult = res.data;
                                      } else {
                                        pythonValidationResult = PythonRuleValidationResponseModel(
                                          valid: false,
                                          message: res.message ?? 'Validation failed',
                                        );
                                      }
                                    });
                                  },
                            icon: isValidatingPython
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Validate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: pythonCodeController,
                          maxLines: 4,
                          style: GoogleFonts.jetBrainsMono(color: const Color(0xFF38BDF8), fontSize: 13),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'result = categories["BASIC"] * 0.4',
                            hintStyle: TextStyle(color: Colors.white30),
                          ),
                        ),
                      ),
                      if (pythonValidationResult != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: pythonValidationResult!.valid
                                ? AppTheme.emeraldSuccess.withValues(alpha: 0.1)
                                : AppTheme.crimsonDanger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: pythonValidationResult!.valid ? AppTheme.emeraldSuccess : AppTheme.crimsonDanger,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                pythonValidationResult!.valid ? Icons.check_circle : Icons.error,
                                color: pythonValidationResult!.valid ? AppTheme.emeraldSuccess : AppTheme.crimsonDanger,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pythonValidationResult!.message,
                                  style: TextStyle(
                                    color: pythonValidationResult!.valid ? AppTheme.emeraldSuccess : AppTheme.crimsonDanger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: quantityController,
                      label: 'Quantity Multiplier',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Active', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight)),
                        Switch(
                          value: isActive,
                          activeTrackColor: AppTheme.odooAubergine,
                          onChanged: (val) => setModalState(() => isActive = val),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.odooAubergine,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final code = codeController.text.trim().toUpperCase();
                                final seq = int.tryParse(sequenceController.text.trim()) ?? 10;
                                final qty = double.tryParse(quantityController.text.trim()) ?? 1.0;

                                if (name.isEmpty || code.isEmpty) {
                                  setModalState(() => modalError = 'Rule Name and Code are required');
                                  return;
                                }

                                final Map<String, dynamic> payload = {
                                  'name': name,
                                  'code': code,
                                  'sequence': seq,
                                  'category': selectedCategory,
                                  'computation_type': selectedComputationType,
                                  'quantity': qty,
                                  'is_active': isActive,
                                };

                                if (selectedComputationType == 'FIXED') {
                                  final amt = double.tryParse(fixedAmountController.text.trim());
                                  if (amt == null) {
                                    setModalState(() => modalError = 'Fixed amount is required for FIXED rules');
                                    return;
                                  }
                                  payload['fixed_amount'] = amt;
                                } else if (selectedComputationType == 'PERCENTAGE') {
                                  final rate = double.tryParse(percentageRateController.text.trim());
                                  if (rate == null) {
                                    setModalState(() => modalError = 'Percentage rate is required');
                                    return;
                                  }
                                  payload['percentage_base'] = selectedPercentageBase;
                                  payload['percentage_rate'] = rate;
                                } else if (selectedComputationType == 'PYTHON_CODE') {
                                  final codeText = pythonCodeController.text.trim();
                                  if (codeText.isEmpty) {
                                    setModalState(() => modalError = 'Python code is required');
                                    return;
                                  }
                                  payload['python_code'] = codeText;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  modalError = null;
                                });

                                final nav = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);
                                final res = isEdit
                                    ? await SalaryStructureService.updateRule(ruleToEdit.id, payload)
                                    : await SalaryStructureService.createRule(_selectedStructure!.id, payload);

                                if (!mounted) return;

                                if (res.isSuccess) {
                                  nav.pop();
                                  _selectStructure(_selectedStructure!.id);
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Rule ${isEdit ? "updated" : "added"} successfully')),
                                  );
                                } else {
                                  setModalState(() {
                                    isSubmitting = false;
                                    modalError = res.message ?? 'Rule action failed';
                                  });
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(isEdit ? 'Update Rule' : 'Save Rule', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
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

  // ===========================================================================
  // RULE DELETE
  // ===========================================================================
  void _confirmDeleteRule(SalaryRuleModel rule) {
    if (!_canEdit) {
      _showReadOnlyNotice();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Rule: ${rule.code}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${rule.name}" (${rule.code})? '
          'If referenced by payslips, it will be deactivated instead.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondaryLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimsonDanger, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final res = await SalaryStructureService.deleteRule(rule.id);
              if (!mounted) return;
              if (res.isSuccess) {
                messenger.showSnackBar(
                  SnackBar(content: Text(res.message ?? res.data?['detail'] ?? 'Rule removed')),
                );
                _selectStructure(_selectedStructure!.id);
              } else {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: ${res.message}')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReadOnlyNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Read-Only: Modifying structures & rules requires HR Payroll Manager access'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================
  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'BASIC':
        return const Color(0xFF2563EB);
      case 'ALLOWANCE':
        return AppTheme.odooTeal;
      case 'GROSS':
        return AppTheme.odooAubergine;
      case 'DEDUCTION':
        return const Color(0xFFEA580C);
      case 'NET':
        return AppTheme.emeraldSuccess;
      default:
        return AppTheme.textSecondaryLight;
    }
  }

  String _formatRuleCalc(SalaryRuleModel r) {
    if (r.computationType == 'FIXED') {
      return 'Fixed ₹${(r.fixedAmount ?? 0).toStringAsFixed(2)}';
    } else if (r.computationType == 'PERCENTAGE') {
      return '${r.percentageRate ?? 0}% of ${r.percentageBase ?? "WAGE"}';
    } else {
      return 'Python Formula';
    }
  }

  bool get _canRead => ApiClient.hasPayrollConfigReadAccess;
  bool get _canEdit => ApiClient.hasPayrollConfigWriteAccess;

  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    if (!_canRead) {
      return Scaffold(
        backgroundColor: AppTheme.deepBgLight,
        body: SafeArea(child: _buildAccessRestrictedState()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.deepBgLight,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 600;
                      if (isWide) {
                        return _buildWideLayout();
                      } else {
                        return _buildMobileLayout();
                      }
                    },
                  ),
      ),
    );
  }

  Widget _buildAccessRestrictedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.crimsonDanger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, size: 32, color: AppTheme.crimsonDanger),
            ),
            const SizedBox(height: 16),
            Text(
              'Access Restricted',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have permission to view payroll structures and rules. '
              'Please contact your system administrator if you require access.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textSecondaryLight),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.odooAubergine,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _loadStructures(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDE LAYOUT (>= 600px)
  // ===========================================================================
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left panel: header + structure list
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header in left panel
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payroll Config',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Salary structures & rules',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondaryLight),
                    ),
                    const SizedBox(height: 12),
                    if (_canEdit)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.odooAubergine,
                            side: const BorderSide(color: AppTheme.odooAubergine),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _openStructureModal(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New Structure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    if (!_canEdit)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.odooTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 14, color: AppTheme.odooTeal),
                            const SizedBox(width: 4),
                            Text('Read-Only', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.odooTeal)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Structure list
              Expanded(child: _buildStructureListPanel()),
            ],
          ),
        ),
        Container(width: 1, color: AppTheme.borderLight),
        // Right panel: detail
        Expanded(child: _buildDetailContent()),
      ],
    );
  }

  // ===========================================================================
  // MOBILE LAYOUT (< 600px)
  // ===========================================================================
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildMobileHeader(),
          const SizedBox(height: 12),
          // Structure selector dropdown
          _buildMobileStructureSelector(),
          const SizedBox(height: 8),
          // Detail content
          _buildDetailContent(),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.onNavigateTab == null && Navigator.canPop(context))
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevatedLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back, size: 18, color: AppTheme.odooAubergine),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payroll Rules & Structure',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                    ),
                    Text(
                      'Manage salary structures and rules',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondaryLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_canEdit)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.odooAubergine,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                  ),
                  onPressed: () => _openStructureModal(),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('New Structure', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              if (!_canEdit)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.odooTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: AppTheme.odooTeal),
                      const SizedBox(width: 4),
                      Text('Read-Only', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.odooTeal)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStructureSelector() {
    if (_structures.isEmpty) return const SizedBox.shrink();

    final validSelectedId = _structures.any((s) => s.id == _selectedStructure?.id)
        ? _selectedStructure?.id
        : _structures.first.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: validSelectedId,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.odooAubergine),
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
            dropdownColor: Colors.white,
            items: _structures.map((s) {
              return DropdownMenuItem<String>(
                value: s.id,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.code,
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textSecondaryLight),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s.isActive ? AppTheme.emeraldSuccess : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _selectStructure(val);
            },
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STRUCTURE LIST PANEL (Wide mode left pane)
  // ===========================================================================
  Widget _buildStructureListPanel() {
    if (_structures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No salary structures yet',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondaryLight),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _structures.length,
      separatorBuilder: (context, i) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final s = _structures[index];
        final isSelected = s.id == _selectedStructure?.id;

        return InkWell(
          onTap: () => _selectStructure(s.id),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.odooAubergine.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppTheme.odooAubergine.withValues(alpha: 0.4) : AppTheme.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.odooAubergine : AppTheme.textPrimaryLight,
                        ),
                      ),
                    ),
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s.isActive ? AppTheme.emeraldSuccess : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.code} · ${s.ruleCount} rules · ${s.employeeCount} employees',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textSecondaryLight),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // DETAIL CONTENT (shared between mobile and wide)
  // ===========================================================================
  Widget _buildDetailContent() {
    if (_structures.isEmpty) {
      return _buildEmptyStructuresState();
    }

    if (_selectedStructure == null) {
      return Center(
        child: Text('Select a salary structure', style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondaryLight)),
      );
    }

    if (_isLoadingDetail) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final struct = _selectedStructure!;
    final rules = struct.rules;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Structure summary card
          _buildStructureSummaryCard(struct),
          const SizedBox(height: 20),

          // Rules section header
          _buildRulesSectionHeader(rules.length),
          const SizedBox(height: 10),

          // Rules list or empty state
          if (rules.isEmpty)
            _buildEmptyRulesState()
          else
            _buildRulesList(rules),

          const SizedBox(height: 24),

          // Simulator section
          _buildSimulatorSection(),
          const SizedBox(height: 24),

          // Employee Payroll Structure & Package Assignment Board
          _buildEmployeePayrollAssignmentSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmptyStructuresState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Salary Structures',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a salary structure to define payroll computation rules.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondaryLight),
            ),
            if (_canEdit) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.odooAubergine,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => _openStructureModal(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Structure'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // STRUCTURE SUMMARY CARD
  // ===========================================================================
  Widget _buildStructureSummaryCard(SalaryStructureModel struct) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + Actions
          Row(
            children: [
              Expanded(
                child: Text(
                  struct.name,
                  style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                ),
              ),
              if (_canEdit) ...[
                _buildSmallIconButton(Icons.edit_outlined, AppTheme.odooAubergine, () => _openStructureModal(structureToEdit: struct)),
                const SizedBox(width: 4),
                _buildSmallIconButton(Icons.delete_outline, AppTheme.crimsonDanger, () => _confirmDeleteStructure(struct)),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Badges wrap
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadge(struct.code, AppTheme.odooAubergine, AppTheme.odooAubergine.withValues(alpha: 0.1)),
              _buildBadge(
                struct.isActive ? 'Active' : 'Inactive',
                struct.isActive ? AppTheme.emeraldSuccess : AppTheme.textSecondaryLight,
                struct.isActive ? AppTheme.emeraldSuccess.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
              ),
              _buildBadge('${struct.ruleCount} rules', AppTheme.textSecondaryLight, AppTheme.surfaceElevatedLight),
              _buildBadge('${struct.activeRuleCount} active', AppTheme.odooTeal, AppTheme.odooTeal.withValues(alpha: 0.1)),
              _buildBadge('${struct.employeeCount} employees', AppTheme.textSecondaryLight, AppTheme.surfaceElevatedLight),
            ],
          ),

          if (struct.notes != null && struct.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              struct.notes!,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondaryLight, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // RULES SECTION
  // ===========================================================================
  Widget _buildRulesSectionHeader(int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Computation Rules ($count)',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
          ),
        ),
        if (_canEdit)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.odooTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => _openRuleModal(),
            icon: const Icon(Icons.add, size: 16),
            label: Text('Add Rule', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildEmptyRulesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          Icon(Icons.rule_outlined, size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            'No salary rules configured',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
          ),
          const SizedBox(height: 4),
          Text(
            'Add Basic, Allowance, Deduction, Gross or Net rules to make this structure usable in payrun.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondaryLight),
          ),
          if (_canEdit) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.odooTeal,
                side: const BorderSide(color: AppTheme.odooTeal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _openRuleModal(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Rule', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRulesList(List<SalaryRuleModel> rules) {
    return Column(
      children: rules.map((r) => _buildRuleCard(r)).toList(),
    );
  }

  Widget _buildRuleCard(SalaryRuleModel rule) {
    final catColor = _getCategoryColor(rule.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: sequence + code + actions
          Row(
            children: [
              // Sequence badge
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevatedLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${rule.sequence}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Code
              Text(
                rule.code,
                style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
              ),
              const Spacer(),
              // Actions
              if (_canEdit) ...[
                _buildSmallIconButton(Icons.edit_outlined, AppTheme.odooAubergine, () => _openRuleModal(ruleToEdit: rule)),
                _buildSmallIconButton(Icons.delete_outline, AppTheme.crimsonDanger, () => _confirmDeleteRule(rule)),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Rule name
          Text(
            rule.name,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
          ),
          const SizedBox(height: 4),

          // Calculation summary
          Text(
            _formatRuleCalc(rule),
            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppTheme.odooTeal),
          ),
          const SizedBox(height: 8),

          // Bottom: category badge + active status + quantity
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildBadge(rule.category, catColor, catColor.withValues(alpha: 0.1)),
              _buildBadge(
                rule.isActive ? 'Active' : 'Inactive',
                rule.isActive ? AppTheme.emeraldSuccess : AppTheme.textSecondaryLight,
                rule.isActive ? AppTheme.emeraldSuccess.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
              ),
              if (rule.quantity != 1.0)
                _buildBadge('Qty: ${rule.quantity}', AppTheme.textSecondaryLight, AppTheme.surfaceElevatedLight),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SIMULATOR SECTION
  // ===========================================================================
  Widget _buildSimulatorSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined, size: 20, color: AppTheme.odooAubergine),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Salary Simulator',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Test net salary computation against a monthly wage before running live payruns.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondaryLight),
          ),
          const SizedBox(height: 14),

          // Inputs stacked vertically on mobile
          _buildTextField(
            controller: _wageController,
            label: 'Monthly Wage (₹)',
            prefixText: '₹ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _workedDaysController,
                  label: 'Worked Days',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  controller: _expectedDaysController,
                  label: 'Expected Days',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.odooAubergine,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: _isSimulating ? null : _runSimulation,
              icon: _isSimulating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text('Simulate', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),

          if (_simulationError != null) ...[
            const SizedBox(height: 12),
            _buildErrorBanner(_simulationError!),
          ],

          if (_simulationResult != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildSimulationResults(),
          ],
        ],
      ),
    );
  }

  Widget _buildSimulationResults() {
    final result = _simulationResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Summary', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight)),
        const SizedBox(height: 10),

        // 2×2 grid for KPIs
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildKpiTile('BASIC', result.basic, const Color(0xFF2563EB)),
            _buildKpiTile('GROSS', result.gross, AppTheme.odooAubergine),
            _buildKpiTile('DEDUCTIONS', result.deductions, const Color(0xFFEA580C)),
            _buildKpiTile('NET SALARY', result.net, AppTheme.emeraldSuccess),
          ],
        ),

        if (result.lines.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Rule Breakdown', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight)),
          const SizedBox(height: 8),
          ...result.lines.map((line) => _buildSimulationLineCard(line)),
        ],
      ],
    );
  }

  Widget _buildKpiTile(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationLineCard(RuleSimulationLineModel line) {
    final catColor = _getCategoryColor(line.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevatedLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Sequence
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('${line.sequence}', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          // Rule info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      line.ruleCode,
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                    ),
                    const SizedBox(width: 6),
                    _buildBadge(line.category, catColor, catColor.withValues(alpha: 0.1)),
                  ],
                ),
                if (line.explanation.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line.explanation,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textSecondaryLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount
          Text(
            '₹${line.amount.toStringAsFixed(2)}',
            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeePayrollAssignmentSection() {
    final allEmps = MockDataService.allEmployees;
    final allDepts = ['All', ...allEmps.map((e) => e.department).where((d) => d.isNotEmpty).toSet()];
    final allPositions = ['All', ...allEmps.map((e) => e.jobTitle).where((p) => p.isNotEmpty).toSet()];

    // Filter employees
    final filteredEmps = allEmps.where((emp) {
      if (_empSearchQuery.isNotEmpty) {
        final q = _empSearchQuery.toLowerCase();
        final matchName = emp.name.toLowerCase().contains(q);
        final matchBadge = (emp.badgeId ?? '').toLowerCase().contains(q);
        if (!matchName && !matchBadge) return false;
      }
      if (_selectedDeptFilter != 'All' && !emp.department.toLowerCase().contains(_selectedDeptFilter.toLowerCase())) {
        return false;
      }
      if (_selectedPosFilter != 'All' && !emp.jobTitle.toLowerCase().contains(_selectedPosFilter.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.odooAubergine.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.badge_outlined, color: AppTheme.odooAubergine, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employee Payroll & Package Assignment',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                    ),
                    Text(
                      'Directly assign or edit salary structures and packages per employee, department, or job position',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondaryLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_canEdit)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.odooAubergine,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 0,
                  ),
                  onPressed: () => _openEmployeePayrollModal(),
                  icon: const Icon(Icons.assignment_add, size: 16),
                  label: Text('Batch Assign', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Bar: Search + Department + Position
          Column(
            children: [
              // Search Input
              TextField(
                onChanged: (val) => setState(() => _empSearchQuery = val.trim()),
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF131B2E)),
                decoration: InputDecoration(
                  hintText: 'Filter by employee name or ID...',
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondaryLight),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryLight),
                  suffixIcon: _empSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _empSearchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceElevatedLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.borderLight)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.borderLight)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.odooAubergine)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),

              // Dropdown Filters Row
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      label: 'Department',
                      value: allDepts.contains(_selectedDeptFilter) ? _selectedDeptFilter : 'All',
                      items: allDepts,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDeptFilter = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdownField(
                      label: 'Job Position / Post',
                      value: allPositions.contains(_selectedPosFilter) ? _selectedPosFilter : 'All',
                      items: allPositions,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPosFilter = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Count Badge Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${filteredEmps.length} of ${allEmps.length} Employees',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryLight),
              ),
              if (_selectedDeptFilter != 'All' || _selectedPosFilter != 'All' || _empSearchQuery.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _empSearchQuery = '';
                      _selectedDeptFilter = 'All';
                      _selectedPosFilter = 'All';
                    });
                  },
                  child: const Text('Reset Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Employee Payroll Cards List
          if (filteredEmps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevatedLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Icon(Icons.person_search_outlined, size: 36, color: AppTheme.textSecondaryLight),
                  const SizedBox(height: 8),
                  Text('No employees match the filters', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Try adjusting your search query, department, or job position filter.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondaryLight)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredEmps.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final emp = filteredEmps[index];
                return _buildEmployeePayrollCard(emp);
              },
            ),
        ],
      ),
    );
  }



  Widget _buildEmployeePayrollCard(EmployeeModel emp) {
    final contract = MockDataService.contracts.firstWhere(
      (c) => c.employeeName.toLowerCase().contains(emp.name.toLowerCase().split(' ').first),
      orElse: () => ContractModel(
        id: 'new',
        refCode: 'CON/NEW',
        employeeName: emp.name,
        department: emp.department,
        startDate: '2026-01-01',
        wageMonthly: 85000.0,
        status: 'RUNNING',
        structureName: _selectedStructure?.name ?? 'Regular Employee Base',
      ),
    );

    final hourlyRate = contract.wageMonthly / 176.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevatedLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.odooAubergine,
                child: Text(
                  emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name,
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                    ),
                    Text(
                      '${emp.jobTitle} • ${emp.department} • ${emp.badgeId ?? "EMP"}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondaryLight),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildBadge(
                contract.status,
                contract.status == 'RUNNING' ? AppTheme.emeraldSuccess : const Color(0xFFE65100),
                contract.status == 'RUNNING' ? AppTheme.emeraldSuccess.withValues(alpha: 0.1) : const Color(0xFFFFF3E0),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Package & Structure Details (Responsive layout, no overflow)
          Wrap(
            spacing: 16,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Base Package', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textSecondaryLight)),
                  Text(
                    '₹ ${contract.wageMonthly.toStringAsFixed(2)} / Mo',
                    style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                  ),
                  Text(
                    '~ ₹ ${hourlyRate.toStringAsFixed(2)} / hr (176h standard)',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.odooTeal),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ref Code', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textSecondaryLight)),
                  Text(
                    contract.refCode,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                  ),
                  Text(
                    'Since ${contract.startDate}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.textSecondaryLight),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Card Action Buttons
          if (_canEdit)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 200,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.odooAubergine,
                      side: const BorderSide(color: AppTheme.odooAubergine),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _openEmployeePayrollModal(targetEmp: emp),
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text('Edit Base Package', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          if (!_canEdit)
            Text(
              'Read-Only Payroll Access',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondaryLight),
            ),
        ],
      ),
    );
  }

  void _openEmployeePayrollModal({EmployeeModel? targetEmp, bool isOverride = false}) {
    if (!_canEdit) {
      _showReadOnlyNotice();
      return;
    }

    final availableEmps = MockDataService.allEmployees;
    final availableDepts = availableEmps.map((e) => e.department).where((d) => d.isNotEmpty).toSet().toList();
    final availablePositions = availableEmps.map((e) => e.jobTitle).where((p) => p.isNotEmpty).toSet().toList();

    String scopeType = targetEmp != null ? 'EMPLOYEE' : 'DEPARTMENT';
    String selectedEmpId = (targetEmp != null && availableEmps.any((e) => e.id == targetEmp.id))
        ? targetEmp.id
        : (availableEmps.isNotEmpty ? availableEmps.first.id : '');
    String selectedDept = (targetEmp != null && availableDepts.contains(targetEmp.department))
        ? targetEmp.department
        : (availableDepts.isNotEmpty ? availableDepts.first : 'Engineering');
    String selectedPosition = (targetEmp != null && availablePositions.contains(targetEmp.jobTitle))
        ? targetEmp.jobTitle
        : (availablePositions.isNotEmpty ? availablePositions.first : '');

    final initialContract = targetEmp != null
        ? MockDataService.contracts.firstWhere(
            (c) => c.employeeName.toLowerCase().contains(targetEmp.name.toLowerCase().split(' ').first),
            orElse: () => ContractModel(id: '', refCode: '', employeeName: targetEmp.name, department: targetEmp.department, startDate: '2026-01-01', wageMonthly: 90000.0, status: 'RUNNING'),
          )
        : null;

    final wageCtrl = TextEditingController(text: (initialContract?.wageMonthly ?? 95000.0).toStringAsFixed(0));
    final effectiveFromCtrl = TextEditingController(text: DateTime.now().toString().split(' ').first);
    final reasonCtrl = TextEditingController(text: 'Compensation package update');

    // 7 Salary Rule Override Controllers
    final basicPctCtrl = TextEditingController(text: '50');
    final hraPctCtrl = TextEditingController(text: '40');
    final stdAmtCtrl = TextEditingController(text: '10000');
    final pfPctCtrl = TextEditingController(text: '6');
    final ptAmtCtrl = TextEditingController(text: '2000');

    bool isSubmittingModal = false;
    String selectedStructId = _selectedStructure?.id ?? (_structures.isNotEmpty ? _structures.first.id : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final double currentWage = double.tryParse(wageCtrl.text.trim()) ?? 0.0;
            final double basicPct = double.tryParse(basicPctCtrl.text.trim()) ?? 50.0;
            final double hraPct = double.tryParse(hraPctCtrl.text.trim()) ?? 40.0;
            final double stdAmt = double.tryParse(stdAmtCtrl.text.trim()) ?? 10000.0;
            final double pfPct = double.tryParse(pfPctCtrl.text.trim()) ?? 6.0;
            final double ptAmt = double.tryParse(ptAmtCtrl.text.trim()) ?? 2000.0;

            final double basicVal = currentWage * (basicPct / 100.0);
            final double hraVal = basicVal * (hraPct / 100.0);
            final double stdVal = stdAmt;
            final double grossVal = basicVal + hraVal + stdVal;
            final double pfVal = basicVal * (pfPct / 100.0);
            final double ptVal = ptAmt;
            final double netVal = grossVal - pfVal - ptVal;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.odooAubergine, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isOverride ? 'Assign Custom Payroll Structure' : 'Edit Employee Payroll Config',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assign salary structure and monthly package by individual employee, department, or job position',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondaryLight),
                    ),
                    const SizedBox(height: 16),

                    // Scope Type Selection (Segmented)
                    Text('Target Scope', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Individual Employee'),
                            selected: scopeType == 'EMPLOYEE',
                            onSelected: (val) => setSheetState(() => scopeType = 'EMPLOYEE'),
                            selectedColor: AppTheme.odooAubergine.withValues(alpha: 0.15),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Department'),
                            selected: scopeType == 'DEPARTMENT',
                            onSelected: (val) => setSheetState(() => scopeType = 'DEPARTMENT'),
                            selectedColor: AppTheme.odooAubergine.withValues(alpha: 0.15),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Job Position'),
                            selected: scopeType == 'POSITION',
                            onSelected: (val) => setSheetState(() => scopeType = 'POSITION'),
                            selectedColor: AppTheme.odooAubergine.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Target Selectors based on Scope
                    if (scopeType == 'EMPLOYEE')
                      _buildDropdownField(
                        label: 'Select Employee',
                        value: selectedEmpId,
                        items: MockDataService.allEmployees.map((e) => e.id).toList(),
                        itemLabels: Map.fromEntries(MockDataService.allEmployees.map((e) => MapEntry(e.id, '${e.name} (${e.department})'))),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => selectedEmpId = val);
                        },
                      )
                    else if (scopeType == 'DEPARTMENT')
                      _buildDropdownField(
                        label: 'Select Department',
                        value: selectedDept,
                        items: MockDataService.allEmployees.map((e) => e.department).where((d) => d.isNotEmpty).toSet().toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => selectedDept = val);
                        },
                      )
                    else
                      _buildDropdownField(
                        label: 'Select Job Position / Post',
                        value: selectedPosition,
                        items: MockDataService.allEmployees.map((e) => e.jobTitle).where((p) => p.isNotEmpty).toSet().toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => selectedPosition = val);
                        },
                      ),
                    const SizedBox(height: 12),

                    // Salary Structure Dropdown
                    _buildDropdownField(
                      label: 'Assign Salary Structure',
                      value: selectedStructId,
                      items: _structures.map((s) => s.id).toList(),
                      itemLabels: Map.fromEntries(_structures.map((s) => MapEntry(s.id, '${s.name} (${s.code})'))),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedStructId = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Monthly Wage Field
                    TextFormField(
                      controller: wageCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setSheetState(() {}),
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textPrimaryLight),
                      decoration: InputDecoration(
                        labelText: 'Monthly Base Wage Package (₹)',
                        prefixText: '₹ ',
                        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondaryLight),
                        filled: true,
                        fillColor: AppTheme.surfaceElevatedLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.borderLight)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 7 SALARY COMPUTATION RULES BREAKDOWN & CUSTOMIZATION CARD
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevatedLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calculate_outlined, color: AppTheme.odooAubergine, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '7 Salary Computation Rules Breakdown',
                                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: AppTheme.odooAubergine.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                child: Text('Live Engine', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.odooAubergine)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Edit individual rule percentages or fixed amounts below to customize salary heads for this employee:',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textSecondaryLight),
                          ),
                          const SizedBox(height: 12),

                          // Rule 1: BASIC
                          _buildRuleEditableRow('BASIC', 'Basic Salary', 'BASIC', '50% of Wage', basicPctCtrl, '%', basicVal, () => setSheetState(() {})),
                          const SizedBox(height: 8),

                          // Rule 2: HRA
                          _buildRuleEditableRow('HRA', 'House Rent Allowance', 'ALLOWANCE', '40% of BASIC', hraPctCtrl, '%', hraVal, () => setSheetState(() {})),
                          const SizedBox(height: 8),

                          // Rule 3: STD
                          _buildRuleEditableRow('STD', 'Standard Allowance', 'ALLOWANCE', 'Fixed Allowance', stdAmtCtrl, '₹ ', stdVal, () => setSheetState(() {}), isPrefix: true),
                          const SizedBox(height: 8),

                          // Rule 4: GROSS (Calculated)
                          _buildRuleSummaryRow('GROSS', 'Gross Salary', 'GROSS', 'BASIC + HRA + STD', grossVal, AppTheme.emeraldSuccess),
                          const SizedBox(height: 8),

                          // Rule 5: PF
                          _buildRuleEditableRow('PF', 'Provident Fund (Employee)', 'DEDUCTION', '6% of BASIC', pfPctCtrl, '%', -pfVal, () => setSheetState(() {}), isDeduction: true),
                          const SizedBox(height: 8),

                          // Rule 6: PT
                          _buildRuleEditableRow('PT', 'Professional Tax', 'DEDUCTION', 'Fixed State PT', ptAmtCtrl, '₹ ', -ptVal, () => setSheetState(() {}), isDeduction: true, isPrefix: true),
                          const SizedBox(height: 8),

                          // Rule 7: NET (Calculated)
                          _buildRuleSummaryRow('NET', 'Net Payable Salary', 'NET', 'GROSS - Deductions', netVal, AppTheme.odooAubergine),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Effective From Date
                    _buildTextField(
                      controller: effectiveFromCtrl,
                      label: 'Effective From Date *',
                      hint: 'YYYY-MM-DD',
                    ),
                    const SizedBox(height: 12),

                    // Reason Field
                    _buildTextField(
                      controller: reasonCtrl,
                      label: 'Reason for Compensation Revision',
                      hint: 'Annual increment / Role change',
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.odooAubergine,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: isSubmittingModal
                            ? null
                            : () async {
                                final newWage = double.tryParse(wageCtrl.text.trim());
                                if (newWage == null || newWage <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid monthly wage greater than 0')),
                                  );
                                  return;
                                }
                                final structObj = _structures.firstWhere(
                                  (s) => s.id == selectedStructId,
                                  orElse: () => _structures.first,
                                );

                                setSheetState(() => isSubmittingModal = true);
                                final eff = effectiveFromCtrl.text.trim();
                                final reason = reasonCtrl.text.trim();

                                final nav = Navigator.of(sheetContext);
                                final messenger = ScaffoldMessenger.of(context);

                                if (scopeType == 'EMPLOYEE' && targetEmp != null) {
                                  final contract = MockDataService.contracts.firstWhere(
                                    (c) => c.employeeName.toLowerCase().contains(targetEmp.name.toLowerCase().split(' ').first),
                                    orElse: () => ContractModel(id: 'c-${targetEmp.id}', refCode: 'CON/2026/001', employeeName: targetEmp.name, department: targetEmp.department, startDate: '2026-01-01', wageMonthly: 85000.0, status: 'RUNNING'),
                                  );

                                  final res = await ContractService.reviseCompensation(
                                    contract.id,
                                    {
                                      'new_wage': newWage,
                                      'new_salary_structure_id': structObj.id,
                                      'new_structure_name': structObj.name,
                                      'effective_from': eff.isEmpty ? DateTime.now().toString().split(' ').first : eff,
                                      'reason': reason.isEmpty ? 'Compensation revision' : reason,
                                    },
                                  );

                                  if (!mounted) return;
                                  nav.pop();

                                  if (res.isSuccess) {
                                    setState(() {
                                      _updateOrCreateContract(
                                        targetEmp.name,
                                        targetEmp.department,
                                        newWage,
                                        structObj.name,
                                        basicVal: basicVal,
                                        hraVal: hraVal,
                                        stdVal: stdVal,
                                        grossVal: grossVal,
                                        pfVal: pfVal,
                                        ptVal: ptVal,
                                        netVal: netVal,
                                        effectiveFrom: eff,
                                      );
                                    });
                                    messenger.showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppTheme.odooAubergine,
                                        content: Text('Monthly base package revised for ${targetEmp.name} to ₹${newWage.toStringAsFixed(0)} with updated 7 rules effective ${eff.isEmpty ? DateTime.now().toString().split(" ").first : eff}.'),
                                      ),
                                    );
                                  } else {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppTheme.crimsonDanger,
                                        content: Text(res.message ?? 'Compensation revision failed'),
                                      ),
                                    );
                                  }
                                } else {
                                  setState(() {
                                    if (scopeType == 'EMPLOYEE') {
                                      final empObj = MockDataService.allEmployees.firstWhere((e) => e.id == selectedEmpId);
                                      _updateOrCreateContract(
                                        empObj.name,
                                        empObj.department,
                                        newWage,
                                        structObj.name,
                                        basicVal: basicVal,
                                        hraVal: hraVal,
                                        stdVal: stdVal,
                                        grossVal: grossVal,
                                        pfVal: pfVal,
                                        ptVal: ptVal,
                                        netVal: netVal,
                                        effectiveFrom: eff,
                                      );
                                    } else if (scopeType == 'DEPARTMENT') {
                                      final empsInDept = MockDataService.allEmployees.where((e) => e.department.toLowerCase().contains(selectedDept.toLowerCase()));
                                      for (final e in empsInDept) {
                                        _updateOrCreateContract(
                                          e.name,
                                          e.department,
                                          newWage,
                                          structObj.name,
                                          basicVal: basicVal,
                                          hraVal: hraVal,
                                          stdVal: stdVal,
                                          grossVal: grossVal,
                                          pfVal: pfVal,
                                          ptVal: ptVal,
                                          netVal: netVal,
                                          effectiveFrom: eff,
                                        );
                                      }
                                    } else if (scopeType == 'POSITION') {
                                      final empsInPos = MockDataService.allEmployees.where((e) => e.jobTitle.toLowerCase().contains(selectedPosition.toLowerCase()));
                                      for (final e in empsInPos) {
                                        _updateOrCreateContract(
                                          e.name,
                                          e.department,
                                          newWage,
                                          structObj.name,
                                          basicVal: basicVal,
                                          hraVal: hraVal,
                                          stdVal: stdVal,
                                          grossVal: grossVal,
                                          pfVal: pfVal,
                                          ptVal: ptVal,
                                          netVal: netVal,
                                          effectiveFrom: eff,
                                        );
                                      }
                                    }
                                  });

                                  nav.pop();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.odooAubergine,
                                      content: Text('✓ Successfully updated payroll config & 7 computation rules (${structObj.name})'),
                                    ),
                                  );
                                }
                              },
                        child: isSubmittingModal
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save & Apply Compensation Revision', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
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

  void _updateOrCreateContract(
    String empName,
    String dept,
    double wage,
    String structName, {
    double? basicVal,
    double? hraVal,
    double? stdVal,
    double? grossVal,
    double? pfVal,
    double? ptVal,
    double? netVal,
    String? effectiveFrom,
  }) {
    // 1. Update contract in MockDataService
    final idx = MockDataService.contracts.indexWhere(
      (c) => c.employeeName.toLowerCase().contains(empName.toLowerCase().split(' ').first),
    );
    if (idx >= 0) {
      final existing = MockDataService.contracts[idx];
      MockDataService.contracts[idx] = ContractModel(
        id: existing.id,
        refCode: existing.refCode,
        employeeName: existing.employeeName,
        department: existing.department,
        startDate: existing.startDate,
        endDate: existing.endDate,
        wageMonthly: wage,
        status: existing.status,
        structureName: structName,
      );
    } else {
      MockDataService.contracts.add(ContractModel(
        id: 'con-${DateTime.now().millisecondsSinceEpoch}',
        refCode: 'CON/2026/${MockDataService.contracts.length + 10}',
        employeeName: empName,
        department: dept,
        startDate: '2026-01-01',
        wageMonthly: wage,
        status: 'RUNNING',
        structureName: structName,
      ));
    }

    // 2. Update/create target month's payslip in MockDataService.payslips
    final effDateStr = (effectiveFrom != null && effectiveFrom.trim().isNotEmpty)
        ? effectiveFrom.trim()
        : DateTime.now().toString().split(' ').first;
    final yearMonth = effDateStr.length >= 7 ? effDateStr.substring(0, 7) : '2026-09';

    final calculatedBasic = basicVal ?? (wage * 0.50);
    final calculatedHra = hraVal ?? (calculatedBasic * 0.40);
    final calculatedStd = stdVal ?? 10000.0;
    final calculatedGross = grossVal ?? (calculatedBasic + calculatedHra + calculatedStd);
    final calculatedPf = pfVal ?? (calculatedBasic * 0.06);
    final calculatedPt = ptVal ?? 2000.0;
    final calculatedNet = netVal ?? (calculatedGross - calculatedPf - calculatedPt);

    final updatedLines = [
      PayslipLineModel(ruleName: 'Basic Salary', ruleCode: 'BASIC', category: 'BASIC', amount: calculatedBasic),
      PayslipLineModel(ruleName: 'House Rent Allowance', ruleCode: 'HRA', category: 'ALLOWANCE', amount: calculatedHra),
      PayslipLineModel(ruleName: 'Standard Allowance', ruleCode: 'STD', category: 'ALLOWANCE', amount: calculatedStd),
      PayslipLineModel(ruleName: 'Gross Salary', ruleCode: 'GROSS', category: 'GROSS', amount: calculatedGross),
      PayslipLineModel(ruleName: 'Provident Fund', ruleCode: 'PF', category: 'DEDUCTION', amount: -calculatedPf),
      PayslipLineModel(ruleName: 'Professional Tax', ruleCode: 'PT', category: 'DEDUCTION', amount: -calculatedPt),
      PayslipLineModel(ruleName: 'Net Salary', ruleCode: 'NET', category: 'NET', amount: calculatedNet),
    ];

    final slipIdx = MockDataService.payslips.indexWhere(
      (p) => p.employeeName.toLowerCase().contains(empName.toLowerCase().split(' ').first) && p.periodStart.startsWith(yearMonth),
    );

    if (slipIdx >= 0) {
      final existingSlip = MockDataService.payslips[slipIdx];
      MockDataService.payslips[slipIdx] = existingSlip.copyWith(
        contractMonthlyWage: wage,
        grossAmount: calculatedGross,
        netAmount: calculatedNet,
        lines: updatedLines,
      );
    } else {
      MockDataService.payslips.insert(
        0,
        PayslipModel(
          id: 'pay-${DateTime.now().millisecondsSinceEpoch}',
          refCode: 'SLIP/${yearMonth.replaceAll('-', '/')}-001',
          employeeName: empName,
          periodStart: '$yearMonth-01',
          periodEnd: '$yearMonth-30',
          contractMonthlyWage: wage,
          grossAmount: calculatedGross,
          netAmount: calculatedNet,
          status: 'DONE',
          lines: updatedLines,
        ),
      );
    }
  }

  Widget _buildRuleEditableRow(
    String code,
    String name,
    String category,
    String formula,
    TextEditingController ctrl,
    String unitSymbol,
    double computedAmount,
    VoidCallback onChanged, {
    bool isDeduction = false,
    bool isPrefix = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDeduction ? const Color(0xFFFFF0F0) : AppTheme.surfaceElevatedLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isDeduction ? AppTheme.crimsonDanger.withValues(alpha: 0.3) : AppTheme.borderLight),
            ),
            child: Text(code, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: isDeduction ? AppTheme.crimsonDanger : AppTheme.textPrimaryLight)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight)),
                Text(formula, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.textSecondaryLight)),
              ],
            ),
          ),
          SizedBox(
            width: 75,
            height: 34,
            child: TextFormField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => onChanged(),
              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                prefixText: isPrefix ? unitSymbol : null,
                suffixText: !isPrefix ? unitSymbol : null,
                prefixStyle: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF131B2E)),
                suffixStyle: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF131B2E)),
                filled: true,
                fillColor: AppTheme.surfaceElevatedLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppTheme.borderLight)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              '${computedAmount < 0 ? "- ₹" : "₹"}${computedAmount.abs().toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: isDeduction ? AppTheme.crimsonDanger : AppTheme.textPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleSummaryRow(
    String code,
    String name,
    String category,
    String formula,
    double computedAmount,
    Color themeColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: themeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(code, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight)),
                Text(formula, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.textSecondaryLight)),
              ],
            ),
          ),
          Text(
            '₹${computedAmount.toStringAsFixed(2)}',
            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: themeColor),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SHARED UI COMPONENTS
  // ===========================================================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helperText,
    String? prefixText,
    String? suffixText,
    int maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: capitalization,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textPrimaryLight),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixText: prefixText,
        suffixText: suffixText,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondaryLight),
        filled: true,
        fillColor: AppTheme.surfaceElevatedLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.odooAubergine, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    Map<String, String>? itemLabels,
    required ValueChanged<String?> onChanged,
  }) {
    final uniqueItems = items.toSet().toList();
    final String? safeValue = uniqueItems.contains(value)
        ? value
        : (uniqueItems.isNotEmpty ? uniqueItems.first : null);

    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: safeValue,
      dropdownColor: Colors.white,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondaryLight),
        filled: true,
        fillColor: AppTheme.surfaceElevatedLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.borderLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.borderLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.odooAubergine, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: uniqueItems.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(itemLabels?[item] ?? item, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _buildSmallIconButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.crimsonDanger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.crimsonDanger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.crimsonDanger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(color: AppTheme.crimsonDanger, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
