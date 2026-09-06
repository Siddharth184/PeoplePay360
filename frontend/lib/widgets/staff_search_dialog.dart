import 'package:flutter/material.dart';
import '../services/employee_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class StaffSearchDialog extends StatefulWidget {
  final Function(EmployeeModel)? onSelectEmployee;

  const StaffSearchDialog({super.key, this.onSelectEmployee});

  static void show(BuildContext context, {Function(EmployeeModel)? onSelectEmployee}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StaffSearchDialog(onSelectEmployee: onSelectEmployee),
    );
  }

  @override
  State<StaffSearchDialog> createState() => _StaffSearchDialogState();
}

class _StaffSearchDialogState extends State<StaffSearchDialog> {
  String _searchQuery = '';
  String _selectedDept = 'All';
  List<EmployeeModel> _allStaff = [];
  bool _isLoading = true;

  final List<String> _departments = ['All', 'Finance & Tech Ops', 'Human Resources', 'Software Dev'];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    final res = await EmployeeService.getEmployees();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null) {
          _allStaff = res.data!;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredStaff = _allStaff.where((emp) {
      final matchesQuery = emp.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.jobTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.department.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesDept = _selectedDept == 'All' || emp.department == _selectedDept;
      return matchesQuery && matchesDept;
    }).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      margin: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Header & Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Staff Directory & Search',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by name, role, email or ID...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.odooAubergine),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Department Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _departments.map((dept) {
                final isSelected = _selectedDept == dept;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(dept),
                    selected: isSelected,
                    selectedColor: AppTheme.odooTeal,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      setState(() => _selectedDept = selected ? dept : 'All');
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 20),

          // Employee Search Results List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredStaff.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('No staff members matching "$_searchQuery"', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredStaff.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final emp = filteredStaff[index];
                      return Card(
                        elevation: 0,
                        color: AppTheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.odooAubergine,
                            radius: 24,
                            child: Text(
                              emp.name.split(' ').map((e) => e[0]).take(2).join(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            emp.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${emp.jobTitle} • ${emp.department}', style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(emp.email, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppTheme.odooAubergine),
                          onTap: () {
                            Navigator.pop(context);
                            if (widget.onSelectEmployee != null) {
                              widget.onSelectEmployee!(emp);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
