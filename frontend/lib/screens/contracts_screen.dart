import 'package:flutter/material.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  int _selectedRuleIndex = 1; // HRA Rule
  late TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: MockDataService.salaryRules[_selectedRuleIndex].pythonCode,
    );
  }

  void _selectRule(int index) {
    setState(() {
      _selectedRuleIndex = index;
      _codeController.text = MockDataService.salaryRules[index].pythonCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeRule = MockDataService.salaryRules[_selectedRuleIndex];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contracts & Salary Structure', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              // Contract Summary Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Active Contract: ${MockDataService.contracts.first.refCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.emeraldSuccess.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: const Text('RUNNING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emeraldSuccess)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Monthly Wage: ₹${MockDataService.contracts.first.wageMonthly.toStringAsFixed(2)} / month', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.odooTeal)),
                      const SizedBox(height: 4),
                      Text('Department: ${MockDataService.contracts.first.department}', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Salary Rules (AST Python Engine)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              // Salary Rules Selector Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(MockDataService.salaryRules.length, (index) {
                    final rule = MockDataService.salaryRules[index];
                    final isSelected = index == _selectedRuleIndex;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${rule.code} (${rule.name})'),
                        selected: isSelected,
                        selectedColor: AppTheme.odooAubergine,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimaryLight),
                        onSelected: (_) => _selectRule(index),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              // AST Code Editor Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Rule: ${activeRule.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppTheme.odooTeal.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                            child: Text(activeRule.computationType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.odooTeal)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Python Sandbox Expression:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: _codeController,
                          maxLines: 4,
                          style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF38BDF8), fontSize: 13),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('AST Syntax Status: VALID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emeraldSuccess)),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.odooTeal, foregroundColor: Colors.white),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('⚡ Rule AST Verified & Saved to Database')),
                              );
                            },
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Test Rule'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
