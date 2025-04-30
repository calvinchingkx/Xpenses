import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final currentMonth = _selectedMonth.month;
    final currentYear = _selectedMonth.year;

    return FutureBuilder(
      future: _fetchReportData(currentMonth, currentYear),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading data'));
        }

        final reportData = snapshot.data as Map<String, dynamic>;
        final totalIncome = reportData['totalIncome'] ?? 0.0;
        final totalExpenses = reportData['totalExpenses'] ?? 0.0;
        final savings = totalIncome - totalExpenses;
        final expensesByCategory = reportData['expensesByCategory'] ?? {};
        final incomeByCategory = reportData['incomeByCategory'] ?? {};
        final monthlyTrends = reportData['monthlyTrends'] ?? {};
        final transactions = reportData['transactions'] ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text('Financial Reports'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () => _selectMonth(context),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month selector and summary
                  _buildMonthSelector(context),
                  SizedBox(height: 20),

                  // Summary cards
                  _buildSummaryCards(totalIncome, totalExpenses, savings),
                  SizedBox(height: 20),

                  // Income vs Expenses Pie Chart
                  if (totalIncome > 0 || totalExpenses > 0)
                    _buildIncomeExpensePieChart(totalIncome, totalExpenses),
                  SizedBox(height: 20),

                  // Expenses by Category
                  if (expensesByCategory.isNotEmpty)
                    _buildCategoryChart(
                      title: 'Expenses by Category',
                      data: expensesByCategory,
                      isIncome: false,
                    ),
                  SizedBox(height: 20),

                  // Income by Category
                  if (incomeByCategory.isNotEmpty)
                    _buildCategoryChart(
                      title: 'Income by Category',
                      data: incomeByCategory,
                      isIncome: true,
                    ),
                  SizedBox(height: 20),

                  // Monthly Trends
                  if (monthlyTrends.isNotEmpty)
                    _buildTrendChart(monthlyTrends),
                  SizedBox(height: 20),

                  // Recent Transactions
                  if (transactions.isNotEmpty)
                    _buildRecentTransactions(transactions),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchReportData(int month, int year) async {
    final db = DatabaseHelper();

    // Get totals for the selected month
    final totalIncome = await db.getTotalByTypeForMonth('Income', month, year) ?? 0.0;
    final totalExpenses = await db.getTotalByTypeForMonth('Expense', month, year) ?? 0.0;

    // Get transactions for the selected month
    final transactions = await db.getTransactionsForMonth(month, year);

    // Calculate expenses by category
    final expensesByCategory = <String, double>{};
    final incomeByCategory = <String, double>{};

    for (final t in transactions) {
      if (t['type'] == 'Expense' && t['category'] != null) {
        final category = t['category'] as String;
        final amount = (t['amount'] as num).toDouble();
        expensesByCategory[category] = (expensesByCategory[category] ?? 0) + amount;
      } else if (t['type'] == 'Income' && t['category'] != null) {
        final category = t['category'] as String;
        final amount = (t['amount'] as num).toDouble();
        incomeByCategory[category] = (incomeByCategory[category] ?? 0) + amount;
      }
    }

    // Get monthly trends (last 6 months)
    final monthlyTrends = await _getMonthlyTrends();

    return {
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'expensesByCategory': expensesByCategory,
      'incomeByCategory': incomeByCategory,
      'monthlyTrends': monthlyTrends,
      'transactions': transactions,
    };
  }

  Future<Map<String, Map<String, double>>> _getMonthlyTrends() async {
    final db = DatabaseHelper();
    final now = DateTime.now();
    final result = <String, Map<String, double>>{};

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MMM y').format(month);

      final income = await db.getTotalByTypeForMonth('Income', month.month, month.year) ?? 0.0;
      final expense = await db.getTotalByTypeForMonth('Expense', month.month, month.year) ?? 0.0;

      result[monthKey] = {
        'income': income,
        'expense': expense,
      };
    }

    return result;
  }

  Widget _buildMonthSelector(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateFormat('MMMM y').format(_selectedMonth),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: Icon(Icons.filter_list),
          onPressed: () => _selectMonth(context),
        ),
      ],
    );
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
      });
    }
  }

  Widget _buildSummaryCards(double income, double expense, double savings) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Income',
            amount: income,
            color: Colors.green,
            icon: Icons.arrow_upward,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            title: 'Expense',
            amount: expense,
            color: Colors.red,
            icon: Icons.arrow_downward,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            title: 'Savings',
            amount: savings,
            color: savings >= 0 ? Colors.blue : Colors.orange,
            icon: savings >= 0 ? Icons.savings : Icons.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 5),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpensePieChart(double income, double expense) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Income vs Expenses',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      color: Colors.green,
                      value: income,
                      title: '${(income / (income + expense) * 100).toStringAsFixed(1)}%',
                      radius: 60,
                      titleStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.red,
                      value: expense,
                      title: '${(expense / (income + expense) * 100).toStringAsFixed(1)}%',
                      radius: 60,
                      titleStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.green, 'Income'),
                SizedBox(width: 20),
                _buildLegendItem(Colors.red, 'Expenses'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart({
    required String title,
    required Map<String, double> data,
    required bool isIncome,
  }) {
    final colors = isIncome
        ? [Colors.green[300]!, Colors.green[500]!, Colors.green[700]!]
        : [Colors.red[300]!, Colors.red[500]!, Colors.red[700]!];

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: data.values.reduce((a, b) => a > b ? a : b) * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.grey[800]!,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final category = data.keys.toList()[group.x.toInt()];
                        return BarTooltipItem(
                          '$category\n\$${rod.toY.toStringAsFixed(2)}',
                          TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < data.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                data.keys.toList()[index],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            );
                          }
                          return Text('');
                        },
                        reservedSize: 40,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  barGroups: data.entries.map((entry) {
                    final index = data.keys.toList().indexOf(entry.key);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          color: colors[index % colors.length],
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(Map<String, Map<String, double>> monthlyTrends) {
    final months = monthlyTrends.keys.toList();
    final maxValue = monthlyTrends.values.fold(0.0, (max, data) {
      final currentMax = data.values.fold(0.0, (currMax, val) => val > currMax ? val : currMax);
      return currentMax > max ? currentMax : max;
    });

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Trends (Last 6 Months)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => Colors.grey[800]!,
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          final month = months[spot.x.toInt()];
                          final type = spot.barIndex == 0 ? 'Income' : 'Expense';
                          return LineTooltipItem(
                            '$month\n$type: \$${spot.y.toStringAsFixed(2)}',
                            TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= 0 && value < months.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                months[value.toInt()].split(' ')[0],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            );
                          }
                          return Text('');
                        },
                        reservedSize: 22,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: months.length - 1,
                  minY: 0,
                  maxY: maxValue * 1.2,
                  lineBarsData: [
                    LineChartBarData(
                      spots: months.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          monthlyTrends[entry.value]!['income']!,
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      belowBarData: BarAreaData(show: false),
                      dotData: FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: months.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          monthlyTrends[entry.value]!['expense']!,
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 3,
                      belowBarData: BarAreaData(show: false),
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.green, 'Income'),
                SizedBox(width: 20),
                _buildLegendItem(Colors.red, 'Expenses'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(List<Map<String, dynamic>> transactions) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ...transactions.take(5).map((t) => _buildTransactionTile(t)).toList(),
            if (transactions.length > 5) TextButton(
              onPressed: () {
                // Navigate to full transactions list
              },
              child: Text('View All Transactions'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> t) {
    final isIncome = t['type'] == 'Income';
    final isTransfer = t['type'] == 'Transfer';
    final amount = (t['amount'] as num).toDouble();

    // Fix date parsing - handle both formats
    DateTime date;
    try {
      // First try parsing as ISO format (what DateTime.parse expects)
      date = DateTime.parse(t['date'] as String);
    } catch (e) {
      try {
        // If that fails, try parsing your custom format (DD/MM/YYYY)
        final parts = (t['date'] as String).split('/');
        date = DateTime(
          int.parse(parts[2]), // year
          int.parse(parts[1]), // month
          int.parse(parts[0]), // day
        );
      } catch (e) {
        // If both fail, use current date as fallback
        date = DateTime.now();
      }
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isIncome ? Colors.green[100] : Colors.red[100],
          shape: BoxShape.circle,
        ),
        child: Icon(
          isIncome ? Icons.arrow_upward : Icons.arrow_downward,
          color: isIncome ? Colors.green : Colors.red,
        ),
      ),
      title: Text(t['note'] ?? 'No description'),
      subtitle: Text(
        isTransfer
            ? 'Transfer: ${t['from_account']} → ${t['to_account']}\n${DateFormat('MMM d').format(date)}'
            : '${t['category']} • ${DateFormat('MMM d').format(date)}',
      ),
      trailing: Text(
        '\$${amount.toStringAsFixed(2)}',
        style: TextStyle(
          color: isIncome ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}