import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';
import 'salary_rule_editor_screen.dart';

class PayrollConfigScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const PayrollConfigScreen({super.key, this.onNavigateTab});

  @override
  State<PayrollConfigScreen> createState() => _PayrollConfigScreenState();
}

class _PayrollConfigScreenState extends State<PayrollConfigScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedRuleIndex = 1;
  late TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  void _openCreateStructureSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20, left: 20, right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('New Salary Structure', style: Theme.of(context).textTheme.headlineMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Structure Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Reference Code', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'India', child: Text('India')),
                  DropdownMenuItem(value: 'USA', child: Text('USA')),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.odooAubergine, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Salary Structure Created')),
                    );
                  },
                  child: const Text('Save Structure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCreateRuleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20, left: 20, right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('New Salary Rule', style: Theme.of(context).textTheme.headlineMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Rule Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Rule Code', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'BASIC', child: Text('BASIC')),
                  DropdownMenuItem(value: 'ALLOWANCE', child: Text('ALLOWANCE')),
                  DropdownMenuItem(value: 'DEDUCTION', child: Text('DEDUCTION')),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.odooAubergine, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Salary Rule Created')),
                    );
                  },
                  child: const Text('Save Rule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStructuresTab() {
    final structures = MockDataService.salaryStructures;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: structures.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final struct = structures[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ExpansionTile(
            title: Text(struct.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Reference: ${struct.reference} | ${struct.country}'),
            children: [
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Included Rules:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: struct.ruleIds.map((ruleId) {
                        return Chip(
                          label: Text(ruleId, style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppTheme.surfaceContainerLow,
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _openCreateStructureSheet,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Rules'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRulesTab() {
    final activeRule = MockDataService.salaryRules[_selectedRuleIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Salary Rules & AST Sandbox', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Rule: ${activeRule.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.odooTeal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(activeRule.computationType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.odooTeal)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Category: ${activeRule.category} | Sequence: ${activeRule.sequence}', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 20),
                  const Text('Python Sandbox Expression:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _codeController,
                      maxLines: 5,
                      style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF38BDF8), fontSize: 13),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, size: 15, color: AppTheme.emeraldSuccess),
                          const SizedBox(width: 5),
                          Text('AST Syntax Status: VALID', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emeraldSuccess)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.odooAubergine,
                                side: const BorderSide(color: AppTheme.odooAubergine),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SalaryRuleEditorScreen(
                                      ruleName: activeRule.name,
                                      ruleCode: activeRule.code,
                                      category: activeRule.category,
                                      sequence: activeRule.sequence,
                                      initialPythonCode: activeRule.pythonCode,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.open_in_new_rounded, size: 15),
                              label: const Text('Rule Builder', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.odooTeal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('⚡ Rule AST Verified & Saved to Database')),
                                );
                              },
                              icon: const Icon(Icons.play_arrow, size: 16),
                              label: const Text('Test Rule', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: (Navigator.canPop(context) || widget.onNavigateTab != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  final route = ModalRoute.of(context);
                  if (route != null && !route.isFirst) {
                    Navigator.pop(context);
                  } else if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(-1);
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
        title: const Text('Payroll Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.odooAubergine,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.odooAubergine,
          tabs: const [
            Tab(text: 'Salary Structures'),
            Tab(text: 'Salary Rules'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStructuresTab(),
          _buildRulesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.odooAubergine,
        foregroundColor: Colors.white,
        onPressed: () {
          if (_tabController.index == 0) {
            _openCreateStructureSheet();
          } else {
            _openCreateRuleSheet();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
