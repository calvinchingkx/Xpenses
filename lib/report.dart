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
  int _currentPieChartTab = 0; // 0=Overview, 1=Income, 2=Expenses
  String? _selectedCategory;
  bool _showCategoryDetails = false;
  String? _selectedCategoryType; // 'income' or 'expense'
  Map<String, double> _categoryDetails = {};

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
        final savingsTrends = reportData['savingsTrends'] ?? {};
        final transactions = reportData['transactions'] ?? [];
        final subcategories = reportData['subcategories'] ?? {};

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
                  // Month selector
                  Text(
                    DateFormat('MMMM y').format(_selectedMonth),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),

                  // Summary cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'Income',
                          amount: totalIncome,
                          color: Colors.green,
                          icon: Icons.arrow_upward,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'Expense',
                          amount: totalExpenses,
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
                  ),
                  SizedBox(height: 20),

                  // Pie Chart with tabs
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        children: [
                          DefaultTabController(
                            length: 3,
                            initialIndex: _currentPieChartTab,
                            child: Column(
                              children: [
                                TabBar(
                                  onTap: (index) {
                                    setState(() {
                                      _currentPieChartTab = index;
                                      _showCategoryDetails = false;
                                    });
                                  },
                                  tabs: [
                                    Tab(text: 'Overview'),
                                    Tab(text: 'Income'),
                                    Tab(text: 'Expenses'),
                                  ],
                                ),
                                SizedBox(height: 16),
                                SizedBox(
                                  height: 300,
                                  child: TabBarView(
                                    children: [
                                      // Overview Tab
                                      Column(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTapDown: (details) {
                                                final touchedSection = _getTouchedPieSection(
                                                  details.localPosition,
                                                  totalIncome,
                                                  totalExpenses,
                                                );
                                                if (touchedSection == 0) {
                                                  setState(() {
                                                    _currentPieChartTab = 1;
                                                  });
                                                } else if (touchedSection == 1) {
                                                  setState(() {
                                                    _currentPieChartTab = 2;
                                                  });
                                                }
                                              },
                                              child: _buildIncomeExpensePieChart(totalIncome, totalExpenses),
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

                                      // Income Tab
                                      incomeByCategory.isEmpty
                                          ? Center(child: Text('No income data'))
                                          : Column(
                                        children: [
                                          Expanded(
                                            child: _buildCategoryPieChart(
                                              incomeByCategory,
                                              isIncome: true,
                                              onCategoryTap: (category) {
                                                setState(() {
                                                  _selectedCategory = category;
                                                  _selectedCategoryType = 'income';
                                                  _showCategoryDetails = true;
                                                  _categoryDetails = _aggregateSubcategories(
                                                    subcategories[category] ?? [],
                                                  );
                                                });
                                              },
                                            ),
                                          ),
                                          SizedBox(height: 10),
                                          Text(
                                            'Tap on a category to see details',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Expenses Tab
                                      expensesByCategory.isEmpty
                                          ? Center(child: Text('No expense data'))
                                          : Column(
                                        children: [
                                          Expanded(
                                            child: _buildCategoryPieChart(
                                              expensesByCategory,
                                              isIncome: false,
                                              onCategoryTap: (category) {
                                                setState(() {
                                                  _selectedCategory = category;
                                                  _selectedCategoryType = 'expense';
                                                  _showCategoryDetails = true;
                                                  _categoryDetails = _aggregateSubcategories(
                                                    subcategories[category] ?? [],
                                                  );
                                                });
                                              },
                                            ),
                                          ),
                                          SizedBox(height: 10),
                                          Text(
                                            'Tap on a category to see details',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Category details if selected
                  if (_showCategoryDetails && _selectedCategory != null)
                    _buildCategoryDetailsView(),

                  // Income by Category
                  if (!_showCategoryDetails && incomeByCategory.isNotEmpty)
                    _buildCategoryBarChart(
                      title: 'Income by Category',
                      data: incomeByCategory,
                      isIncome: true,
                      subcategories: subcategories,
                      onCategoryTap: (category) {
                        setState(() {
                          _selectedCategory = category;
                          _selectedCategoryType = 'income';
                          _showCategoryDetails = true;
                          _categoryDetails = _aggregateSubcategories(
                            subcategories[category] ?? [],
                          );
                        });
                      },
                    ),

                  // Expenses by Category
                  if (!_showCategoryDetails && expensesByCategory.isNotEmpty)
                    _buildCategoryBarChart(
                      title: 'Expenses by Category',
                      data: expensesByCategory,
                      isIncome: false,
                      subcategories: subcategories,
                      onCategoryTap: (category) {
                        setState(() {
                          _selectedCategory = category;
                          _selectedCategoryType = 'expense';
                          _showCategoryDetails = true;
                          _categoryDetails = _aggregateSubcategories(
                            subcategories[category] ?? [],
                          );
                        });
                      },
                    ),

                  // Monthly Trends
                  if (monthlyTrends.isNotEmpty)
                    _buildTrendChart(
                      monthlyTrends,
                      title: 'Monthly Income & Expenses',
                      showLabels: true,
                      showHorizontalAxis: true,
                    ),

                  // Savings Trends
                  if (savingsTrends.isNotEmpty)
                    _buildTrendChart(
                      savingsTrends,
                      title: 'Monthly Savings',
                      isSavings: true,
                      showLabels: true,
                      showHorizontalAxis: true,
                    ),

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

  Map<String, double> _aggregateSubcategories(List<Map<String, dynamic>> subcategories) {
    final result = <String, double>{};
    for (final subcat in subcategories) {
      final name = subcat['name'] as String;
      final amount = (subcat['amount'] as num).toDouble();
      result[name] = (result[name] ?? 0) + amount;
    }
    return result;
  }

  Widget _buildCategoryDetailsView() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _showCategoryDetails = false;
                    });
                  },
                ),
                Text(
                  '$_selectedCategory Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 10),
            if (_categoryDetails.isEmpty)
              Center(child: Text('No details available')),
            if (_categoryDetails.isNotEmpty)
              Column(
                children: _categoryDetails.entries.map((entry) {
                  return ListTile(
                    title: Text(entry.key),
                    trailing: Text(
                      '\$${entry.value.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: _selectedCategoryType == 'income' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
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

  int _getTouchedPieSection(Offset position, double income, double expense) {
    final total = income + expense;
    final angle = (position.dx / 200) * 360;
    if (angle < (income / total) * 360) {
      return 0; // Income section
    } else {
      return 1; // Expense section
    }
  }

  Widget _buildIncomeExpensePieChart(double income, double expense) {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            color: Colors.green,
            value: income,
            title: '\$${income.toStringAsFixed(0)}',
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
            title: '\$${expense.toStringAsFixed(0)}',
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
    );
  }

  Widget _buildCategoryPieChart(
      Map<String, double> data, {
        required bool isIncome,
        required Function(String) onCategoryTap,
      }) {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            if (event is FlTapUpEvent && pieTouchResponse?.touchedSection != null) {
              final touchedIndex = pieTouchResponse!.touchedSection!.touchedSectionIndex;
              final category = data.keys.toList()[touchedIndex];
              onCategoryTap(category);
            }
          },
        ),
        sections: data.entries.map((entry) {
          final color = isIncome
              ? Colors.green.withOpacity(0.7)
              : Colors.red.withOpacity(0.7);
          return PieChartSectionData(
            color: color,
            value: entry.value,
            title: '\$${entry.value.toStringAsFixed(0)}',
            radius: 60,
            titleStyle: TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList(),
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildCategoryBarChart({
    required String title,
    required Map<String, double> data,
    required bool isIncome,
    required Map<String, List<Map<String, dynamic>>> subcategories,
    required Function(String) onCategoryTap,
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
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: data.values.reduce((a, b) => a > b ? a : b) * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, response) {
                      if (response?.spot != null && event is FlTapUpEvent) {
                        final touchedIndex = response!.spot!.touchedBarGroupIndex;
                        final category = data.keys.toList()[touchedIndex];
                        onCategoryTap(category);
                      }
                    },
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
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${value.toInt()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: data.values.reduce((a, b) => a > b ? a : b) / 5,
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                  ),
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
            SizedBox(height: 10),
            Text(
              'Tap on a bar to see category details',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(
      Map<String, Map<String, double>> trends, {
        required String title,
        bool isSavings = false,
        bool showLabels = false,
        bool showHorizontalAxis = false,
      }) {
    final months = trends.keys.toList();
    final maxValue = trends.values.fold(0.0, (max, data) {
      final currentMax = data.values.fold(0.0, (currMax, val) => val > currMax ? val : currMax);
      return currentMax > max ? currentMax : max;
    });
    final minValue = trends.values.fold(double.infinity, (min, data) {
      final currentMin = data.values.fold(double.infinity, (currMin, val) => val < currMin ? val : currMin);
      return currentMin < min ? currentMin : min;
    });

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
              height: 250,
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => Colors.grey[800]!,
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          final month = months[spot.x.toInt()];
                          final value = spot.y;
                          return LineTooltipItem(
                            '$month\n\$${value.toStringAsFixed(2)}',
                            TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue / 5,
                  ),
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
                        showTitles: showLabels,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${value.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: showHorizontalAxis,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                  ),
                  minX: 0,
                  maxX: months.length - 1,
                  minY: isSavings ? minValue * 1.1 : 0,
                  maxY: maxValue * 1.2,
                  lineBarsData: [
                    if (!isSavings)
                      LineChartBarData(
                        spots: months.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            trends[entry.value]!['income']!,
                          );
                        }).toList(),
                        isCurved: false,
                        color: Colors.green,
                        barWidth: 3,
                        belowBarData: BarAreaData(show: false),
                        dotData: FlDotData(show: true),
                      ),
                    if (!isSavings)
                      LineChartBarData(
                        spots: months.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            trends[entry.value]!['expense']!,
                          );
                        }).toList(),
                        isCurved: false,
                        color: Colors.red,
                        barWidth: 3,
                        belowBarData: BarAreaData(show: false),
                        dotData: FlDotData(show: true),
                      ),
                    if (isSavings)
                      LineChartBarData(
                        spots: months.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            trends[entry.value]!['savings']!,
                          );
                        }).toList(),
                        isCurved: false,
                        color: Colors.blue,
                        barWidth: 3,
                        belowBarData: BarAreaData(show: false),
                        dotData: FlDotData(show: true),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            if (!isSavings)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(Colors.green, 'Income'),
                  SizedBox(width: 20),
                  _buildLegendItem(Colors.red, 'Expenses'),
                ],
              ),
            if (isSavings)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(Colors.blue, 'Savings'),
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

    DateTime date;
    try {
      date = DateTime.parse(t['date'] as String);
    } catch (e) {
      try {
        final parts = (t['date'] as String).split('/');
        date = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      } catch (e) {
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
    final subcategories = <String, List<Map<String, dynamic>>>{};

    for (final t in transactions) {
      if (t['type'] == 'Expense' && t['category'] != null) {
        final category = t['category'] as String;
        final amount = (t['amount'] as num).toDouble();
        expensesByCategory[category] = (expensesByCategory[category] ?? 0) + amount;

        // Group by subcategory
        final subcategory = t['subcategory'] as String? ?? 'Uncategorized';
        if (!subcategories.containsKey(category)) {
          subcategories[category] = [];
        }
        subcategories[category]!.add({
          'name': subcategory,
          'amount': amount,
        });
      } else if (t['type'] == 'Income' && t['category'] != null) {
        final category = t['category'] as String;
        final amount = (t['amount'] as num).toDouble();
        incomeByCategory[category] = (incomeByCategory[category] ?? 0) + amount;

        // Group by subcategory
        final subcategory = t['subcategory'] as String? ?? 'Uncategorized';
        if (!subcategories.containsKey(category)) {
          subcategories[category] = [];
        }
        subcategories[category]!.add({
          'name': subcategory,
          'amount': amount,
        });
      }
    }

    // Get monthly trends (last 6 months)
    final monthlyTrends = await _getMonthlyTrends();

    // Get savings trends (last 6 months)
    final savingsTrends = await _getSavingsTrends();

    return {
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'expensesByCategory': expensesByCategory,
      'incomeByCategory': incomeByCategory,
      'monthlyTrends': monthlyTrends,
      'savingsTrends': savingsTrends,
      'transactions': transactions,
      'subcategories': subcategories,
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

  Future<Map<String, Map<String, double>>> _getSavingsTrends() async {
    final db = DatabaseHelper();
    final now = DateTime.now();
    final result = <String, Map<String, double>>{};
    double cumulativeSavings = 0.0;

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MMM y').format(month);

      final income = await db.getTotalByTypeForMonth('Income', month.month, month.year) ?? 0.0;
      final expense = await db.getTotalByTypeForMonth('Expense', month.month, month.year) ?? 0.0;
      final savings = income - expense;
      cumulativeSavings += savings;

      result[monthKey] = {
        'savings': cumulativeSavings,
      };
    }

    return result;
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
        _showCategoryDetails = false;
        _selectedCategory = null;
      });
    }
  }
}