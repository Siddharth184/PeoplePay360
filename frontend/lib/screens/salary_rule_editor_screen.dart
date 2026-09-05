import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SalaryRuleEditorScreen extends StatefulWidget {
  final String ruleName;
  final String ruleCode;
  final String category;
  final int sequence;
  final String initialPythonCode;

  const SalaryRuleEditorScreen({
    super.key,
    this.ruleName = 'Gross Salary',
    this.ruleCode = 'GROSS',
    this.category = 'Gross (GROSS)',
    this.sequence = 60,
    this.initialPythonCode = """# Dynamic Salary Rule Expression (Odoo 18)
# Context: contract, worked_days, categories, rules
result = categories['BASIC'] + categories['ALLOWANCE']
if worked_days < 20:
    result = (categories['BASIC'] / 22) * worked_days
# Result propagates to GROSS category""",
  });

  @override
  State<SalaryRuleEditorScreen> createState() => _SalaryRuleEditorScreenState();
}

class _SalaryRuleEditorScreenState extends State<SalaryRuleEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  bool _isActive = true;
  int _computationModeIndex = 2; // 0: Fixed, 1: Percentage, 2: Python Formula
  bool _isTesting = false;
  bool _hasTested = true;
  bool _copied = false;

  final List<String> _quickTokens = [
    'contract.wage',
    "categories['BASIC']",
    'worked_days',
    "rules['HRA']",
    "rules['PF']",
    'payslip.id',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ruleName);
    _codeController = TextEditingController(text: widget.initialPythonCode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _insertToken(String token) {
    final text = _codeController.text;
    final selection = _codeController.selection;
    final newText = selection.isValid
        ? text.replaceRange(selection.start, selection.end, token)
        : '$text\n$token';
    setState(() {
      _codeController.text = newText;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Inserted token: $token'),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _runTestFormula() {
    setState(() {
      _isTesting = true;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _hasTested = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'AST Syntax Validated • Computed Gross: ₹ 80,000.00',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF006443),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _codeController.text));
    setState(() {
      _copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Python code copied to clipboard'),
        duration: Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDiffDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181825),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.difference_rounded, color: Color(0xFF89DCEB), size: 20),
            const SizedBox(width: 8),
            Text(
              'Version Diff • SEQ #60',
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Previous Commit (v2.4):',
              style: GoogleFonts.jetBrainsMono(color: const Color(0xFFA6ADC8), fontSize: 12),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF11111B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "- result = categories['BASIC'] * 1.05\n+ result = categories['BASIC'] + categories['ALLOWANCE']",
                style: GoogleFonts.jetBrainsMono(color: const Color(0xFFA6E3A1), fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF89DCEB))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF131B2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Salary Rule Configuration',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF131B2E),
              ),
            ),
            Text(
              'Regular Structure • Rule SEQ #${widget.sequence}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF4E444A),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.difference_outlined, color: Color(0xFF00696E), size: 20),
            tooltip: 'Version Diff',
            onPressed: _showDiffDialog,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF4E444A), size: 20),
            tooltip: 'More Options',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rule options: Re-evaluate sequence, Export AST, Clone')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sequence Pipeline Visual Stepper
                _buildSequenceStepper(),
                const SizedBox(height: 16),

                // Rule Identity Card
                _buildRuleIdentityCard(),
                const SizedBox(height: 16),

                // Computation Type Switcher
                _buildComputationTypeSwitcher(),
                const SizedBox(height: 16),

                // Python Code Editor Widget (Monaco / JetBrains Dark IDE Theme)
                _buildPythonIdeEditor(),
                const SizedBox(height: 16),

                // Formula Validation Sandbox Card
                _buildFormulaSandboxCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Sticky Bottom Actions Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyBottomActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildSequenceStepper() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 1),
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
                'PIPELINE FLOW ORDER',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF00696E),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '5 Execution Nodes',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: const Color(0xFF4E444A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStepPill('Basic', '#10', isHighlighted: false),
                _buildChevron(),
                _buildStepPill('Allowances', '#20', isHighlighted: false),
                _buildChevron(isHighlighted: true),
                _buildStepPill('GROSS', '#60', isHighlighted: true, hasStar: true),
                _buildChevron(),
                _buildStepPill('Statutory', '#80', isHighlighted: false),
                _buildChevron(),
                _buildStepPill('Net', '#100', isHighlighted: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepPill(String name, String seq, {required bool isHighlighted, bool hasStar = false}) {
    if (isHighlighted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF57344F),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF57344F).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFF714B67), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasStar) ...[
              const Icon(Icons.star_rounded, size: 14, color: Colors.amberAccent),
              const SizedBox(width: 4),
            ],
            Text(
              name,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              seq,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFFFD7F1),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEDFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: const Color(0xFF4E444A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            seq,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: const Color(0xFF80747A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChevron({bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 16,
        color: isHighlighted ? const Color(0xFF00696E) : const Color(0xFFD1C3CA),
      ),
    );
  }

  Widget _buildRuleIdentityCard() {
    return Container(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF92EFF5).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_rounded, size: 15, color: Color(0xFF006E73)),
                    const SizedBox(width: 4),
                    Text(
                      'Gross Calculation Layer',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF006E73),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    'Active',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: _isActive,
                    activeTrackColor: const Color(0xFF57344F),
                    activeThumbColor: Colors.white,
                    onChanged: (val) {
                      setState(() {
                        _isActive = val;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Rule Display Name
          Text(
            'Rule Display Name',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4E444A),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _nameController,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF131B2E),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF2F3FF),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2-Col Grid (Code ID & Category)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Code ID',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF4E444A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.ruleCode,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF57344F),
                            ),
                          ),
                          const Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF80747A)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF4E444A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.category,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF00696E),
                            ),
                          ),
                          const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF00696E)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Evaluation Sequence
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEDFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.low_priority_rounded, size: 18, color: Color(0xFF4E444A)),
                    const SizedBox(width: 8),
                    Text(
                      'Evaluation Sequence',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF4E444A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${widget.sequence}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF131B2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComputationTypeSwitcher() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Computation Mechanism',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF131B2E),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFEAEDFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _buildMechanismOption('Fixed', 0),
              _buildMechanismOption('Percentage', 1),
              _buildMechanismOption('Python Formula', 2, icon: Icons.terminal_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMechanismOption(String label, int index, {IconData? icon}) {
    final isSelected = _computationModeIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _computationModeIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF714B67) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF714B67).withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : const Color(0xFF4E444A),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF4E444A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPythonIdeEditor() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181825),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFF11111B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF38BA8), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF9E2AF), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFA6E3A1), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      'formula_rule_gross.py',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: const Color(0xFFA6ADC8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF313244),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Py 3.11',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF89DCEB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _copyCode,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _copied ? Icons.check_rounded : Icons.content_copy_rounded,
                          size: 16,
                          color: _copied ? const Color(0xFFA6E3A1) : const Color(0xFFA6ADC8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Code Text Area
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _codeController,
              maxLines: null,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12.5,
                color: const Color(0xFFCDD6F4),
                height: 1.5,
              ),
              cursorColor: const Color(0xFF89B4FA),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Quick Insert Dynamic Variable Chips Bar
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF11111B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Insert Tokens',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: const Color(0xFFA6ADC8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _quickTokens.map((token) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => _insertToken(token),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF313244),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+ $token',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF89DCEB),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaSandboxCard() {
    return Container(
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
              Row(
                children: [
                  const Icon(Icons.bug_report_rounded, color: Color(0xFF00696E), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Formula Sandbox',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00696E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: _isTesting ? null : _runTestFormula,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt_rounded, size: 16),
                  label: Text(
                    'Test Formula',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mock employee context
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, size: 16, color: Color(0xFF4E444A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Mock: Aarav Mehta (EMP-4092) • 22/22 days • Base ₹50,000',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF4E444A),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Test Output Box
          if (_hasTested)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEDFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6FFBBE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF004A31)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'AST Verified • Valid',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF004A31),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '1.4ms runtime',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: const Color(0xFF4E444A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Computed Gross Value:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF4E444A),
                        ),
                      ),
                      Text(
                        '₹ 80,000.00',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF57344F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF80747A)),
                      const SizedBox(width: 4),
                      Text(
                        'Safe Execution Sandbox Active (Timeout: 50ms)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF80747A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE2E7FF),
                  foregroundColor: const Color(0xFF131B2E),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Discard',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF57344F),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Rule SEQ #60 (Gross Salary) saved & AST verified!'),
                      backgroundColor: Color(0xFF006443),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  'Save Rule',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
