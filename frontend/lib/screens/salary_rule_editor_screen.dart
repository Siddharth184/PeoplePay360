import 'package:flutter/material.dart';
import 'payroll_config_screen.dart';

@Deprecated('Replaced by unified ERP PayrollConfigScreen')
class SalaryRuleEditorScreen extends StatelessWidget {
  final String ruleName;
  final String ruleCode;
  final String category;
  final int sequence;
  final String initialPythonCode;

  const SalaryRuleEditorScreen({
    super.key,
    this.ruleName = '',
    this.ruleCode = '',
    this.category = '',
    this.sequence = 10,
    this.initialPythonCode = '',
  });

  @override
  Widget build(BuildContext context) {
    return const PayrollConfigScreen();
  }
}
