import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/salary_structure_service.dart';
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

  bool get _canEdit => ApiClient.hasPayrollConfigWriteAccess;

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
        final targetId = selectId ?? _selectedStructure?.id ?? list.first.id;
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
              final res = await SalaryStructureService.deleteStructure(structure.id);
              if (!mounted) return;
              if (res.isSuccess) {
                messenger.showSnackBar(
                  SnackBar(content: Text(res.message ?? res.data?['detail'] ?? 'Structure deleted')),
                );
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

  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
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
            value: _selectedStructure?.id,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(height: 16),
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
    return DropdownButtonFormField<String>(
      initialValue: value,
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
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(itemLabels?[item] ?? item),
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
