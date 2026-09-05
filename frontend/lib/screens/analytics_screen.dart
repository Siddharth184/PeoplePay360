import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HR Analytics & Cost Center', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              // Department Payroll Expense Bar Chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly Expense by Department (₹ Lakhs)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barGroups: [
                              BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 24.5, color: AppTheme.odooAubergine, width: 18)]),
                              BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 18.2, color: AppTheme.odooTeal, width: 18)]),
                              BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 12.0, color: AppTheme.emeraldSuccess, width: 18)]),
                              BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 8.5, color: AppTheme.amberWarning, width: 18)]),
                            ],
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    switch (val.toInt()) {
                                      case 0: return const Text('Engineering', style: TextStyle(fontSize: 10));
                                      case 1: return const Text('Finance', style: TextStyle(fontSize: 10));
                                      case 2: return const Text('Sales', style: TextStyle(fontSize: 10));
                                      case 3: return const Text('HR', style: TextStyle(fontSize: 10));
                                      default: return const Text('');
                                    }
                                  },
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Payroll Trend Line Chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('6-Month Payroll Outflow Trend', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: const [
                                  FlSpot(0, 50),
                                  FlSpot(1, 55),
                                  FlSpot(2, 53),
                                  FlSpot(3, 62),
                                  FlSpot(4, 60),
                                  FlSpot(5, 68),
                                ],
                                isCurved: true,
                                color: AppTheme.odooTeal,
                                barWidth: 4,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppTheme.odooTeal.withValues(alpha: 0.15),
                                ),
                              ),
                            ],
                          ),
                        ),
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
