import 'package:flutter/material.dart';
import '../services/mock_data_service.dart';
import '../services/employee_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'employee_profile_screen.dart';

class EmployeeDirectoryScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const EmployeeDirectoryScreen({super.key, this.onNavigateTab});

  @override
  State<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  bool _isKanbanView = true;
  String _searchQuery = '';
  String _selectedDept = 'All';
  List<EmployeeModel> _staffList = [];
  bool _isLoading = false;

  final List<String> _departments = ['All', 'Finance & Tech Ops', 'Human Resources', 'Software Dev', 'Sales', 'Marketing', 'Engineering'];

  @override
  void initState() {
    super.initState();
    _staffList = MockDataService.allEmployees;
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    final res = await EmployeeService.getEmployees(
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
          _staffList = res.data!;
        }
      });
    }
  }

  void _openCreateEmployeeSheet() {
    final nameCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String dept = 'Engineering';

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('New Employee Profile', style: Theme.of(context).textTheme.headlineMedium),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Job Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: dept,
                  decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Engineering', child: Text('Engineering')),
                    DropdownMenuItem(value: 'Finance', child: Text('Finance')),
                    DropdownMenuItem(value: 'Human Resources', child: Text('Human Resources')),
                    DropdownMenuItem(value: 'Sales', child: Text('Sales')),
                    DropdownMenuItem(value: 'Marketing', child: Text('Marketing')),
                  ],
                  onChanged: (val) {
                    if (val != null) dept = val;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Work Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.odooAubergine, foregroundColor: Colors.white),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final nav = Navigator.of(context);
                      final scaffold = ScaffoldMessenger.of(context);

                      if (name.isNotEmpty && email.isNotEmpty) {
                        await EmployeeService.createEmployee({
                          'name': name,
                          'work_email': email,
                          'job_position_name': titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Software Engineer',
                          'department_name': dept,
                          'company_name': 'OXP Pvt Ltd',
                        });
                        if (mounted) {
                          _fetchEmployees();
                        }
                      }
                      nav.pop();
                      scaffold.showSnackBar(
                        const SnackBar(content: Text('✅ Employee Saved Successfully')),
                      );
                    },
                    child: const Text('Save Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allStaff = _staffList;
    final filteredStaff = allStaff.where((emp) {
      final matchesQuery = emp.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.jobTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.department.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesDept = _selectedDept == 'All' || emp.department == _selectedDept;
      return matchesQuery && matchesDept;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: (Navigator.canPop(context) || widget.onNavigateTab != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(-1);
                  }
                },
              )
            : null,
        title: const Text('Employee Master Directory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isKanbanView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            tooltip: _isKanbanView ? 'Switch to List View' : 'Switch to Kanban View',
            onPressed: () => setState(() => _isKanbanView = !_isKanbanView),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Create Employee',
            onPressed: _openCreateEmployeeSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(color: AppTheme.odooAubergine),
          // Search & Filters Header
          Container(
            color: AppTheme.surfaceContainerLow,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search employees by name, role, or department...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.odooAubergine),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          
          Expanded(
            child: filteredStaff.isEmpty
                ? Center(
                    child: Text('No employees found matching "$_searchQuery"', style: TextStyle(color: Colors.grey.shade600)),
                  )
                : _isKanbanView
                    ? _buildKanbanView(filteredStaff)
                    : _buildListView(filteredStaff),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanView(List<EmployeeModel> employees) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final emp = employees[index];
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (widget.onNavigateTab != null) {
                // Navigate to Employee profile directly if logic was integrated, 
                // for now we just show a snackbar or push route.
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.odooAubergine.withValues(alpha: 0.1),
                    child: Text(
                      emp.name.split(' ').map((e) => e[0]).take(2).join(),
                      style: const TextStyle(
                        color: AppTheme.odooAubergine,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emp.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emp.jobTitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.odooTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      emp.department,
                      style: const TextStyle(color: AppTheme.odooTeal, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(List<EmployeeModel> employees) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: employees.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final emp = employees[index];
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppTheme.odooAubergine.withValues(alpha: 0.1),
              child: Text(
                emp.name.split(' ').map((e) => e[0]).take(2).join(),
                style: const TextStyle(color: AppTheme.odooAubergine, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${emp.jobTitle} • ${emp.department}'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()),
              );
            },
          ),
        );
      },
    );
  }
}
