import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportScreen extends StatelessWidget {
  final double totalIncome = 4500.0;
  final double totalExpenses = 3200.0;
  final Map<String, double> expensesByCategory = {
    'Food': 1000.0,
    'Transportation': 700.0,
    'Utilities': 500.0,
    'Entertainment': 300.0,
    'Others': 700.0,
  };

  List<PieChartSectionData> _generateCategorySections() {
    return expensesByCategory.entries.map((entry) {
      final category = entry.key;
      final value = entry.value;
      final color = Colors.primaries[expensesByCategory.keys.toList().indexOf(category) % Colors.primaries.length];
      return PieChartSectionData(
        color: color,
        value: value,
        title: '$category\n\$$value',
        radius: 60,
        titleStyle: TextStyle(fontSize: 12, color: Colors.white),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Financial Reports'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monthly Overview
              Text(
                'Monthly Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text('Total Income: \$$totalIncome', style: TextStyle(fontSize: 16)),
              Text('Total Expenses: \$$totalExpenses', style: TextStyle(fontSize: 16, color: Colors.red)),
              SizedBox(height: 20),

              // Pie Chart for Expenses by Category
              Text(
                'Expenses by Category',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 200,
                child: PieChart(PieChartData(
                  sections: _generateCategorySections(),
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                )),
              ),

              SizedBox(height: 20),

              // Line Chart for Income and Expenses Trend
              Text(
                'Income and Expenses Trend',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 300,
                child: LineChart(LineChartData(
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        FlSpot(1, 400),
                        FlSpot(2, 800),
                        FlSpot(3, 1200),
                        FlSpot(4, 600),
                        FlSpot(5, 1000),
                      ],
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                    ),
                    LineChartBarData(
                      spots: [
                        FlSpot(1, 300),
                        FlSpot(2, 700),
                        FlSpot(3, 1000),
                        FlSpot(4, 500),
                        FlSpot(5, 900),
                      ],
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 3,
                    ),
                  ],
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
