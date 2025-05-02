import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'database_helper.dart';
//import 'dashboard_screen.dart'; // Make sure this points to your dashboard file
import 'main.dart';

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> with TickerProviderStateMixin {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  DateTime _selectedMonth = DateTime.now();
  int _currentPieChartTab = 0;
  int _currentTrendChartTab = 0;
  int _currentBarChartTab = 0;
  String? _expandedIncomeCategory;
  String? _expandedExpenseCategory;
  late TabController _pieTabController;
  late TabController _trendTabController;
  late TabController _barTabController;
  bool _isLoading = false;

  bool get _hasAnyData {
    return _totalIncome > 0 ||
        _totalExpenses > 0 ||
        _incomeByCategory.isNotEmpty ||
        _expensesByCategory.isNotEmpty ||
        _monthlyTrends.isNotEmpty ||
        _savingsTrends.isNotEmpty ||
        _transactions.isNotEmpty;
  }

  // Data variables
  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  Map<String, double> _incomeByCategory = {};
  Map<String, double> _expensesByCategory = {};
  Map<String, List<Map<String, dynamic>>> _subcategoryDetails = {};
  Map<String, Map<String, double>> _monthlyTrends = {};
  Map<String, Map<String, double>> _savingsTrends = {};
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _pieTabController = TabController(length: 3, vsync: this);
    _trendTabController = TabController(length: 2, vsync: this);
    _barTabController = TabController(length: 2, vsync: this);

    // Initialize all data structures
    _totalIncome = 0.0;
    _totalExpenses = 0.0;
    _incomeByCategory = {};
    _expensesByCategory = {};
    _subcategoryDetails = {};
    _monthlyTrends = {};
    _savingsTrends = {};
    _transactions = [];

    _loadData();
  }

  @override
  void dispose() {
    _pieTabController.dispose();
    _trendTabController.dispose();
    _barTabController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _fetchReportData(_selectedMonth.month, _selectedMonth.year);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load report data: ${e.toString()}'),
          backgroundColor: Colors.red[400],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
    _refreshController.refreshCompleted();
  }

  Widget _buildMonthHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMMM y').format(_selectedMonth),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[800],
            ),
          ),
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.blueAccent),
            onPressed: () => _selectMonth(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final savings = _totalIncome - _totalExpenses;
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _buildSummaryCard(
            title: 'Income',
            amount: _totalIncome,
            color: Colors.green[700]!,
            icon: Icons.arrow_upward,
          ),
          SizedBox(width: 10),
          _buildSummaryCard(
            title: 'Expense',
            amount: _totalExpenses,
            color: Colors.red[700]!,
            icon: Icons.arrow_downward,
          ),
          SizedBox(width: 10),
          _buildSummaryCard(
            title: 'Savings',
            amount: savings,
            color: savings >= 0 ? Colors.blue[700]! : Colors.orange[700]!,
            icon: savings >= 0 ? Icons.savings : Icons.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: color),
                  SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[600],
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
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieChartSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            TabBar(
              controller: _pieTabController,
              onTap: (index) => setState(() => _currentPieChartTab = index),
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blueAccent,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Income'),
                Tab(text: 'Expenses'),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 320,
              child: IndexedStack(
                index: _currentPieChartTab,
                children: [
                  // Overview Tab
                  _totalIncome == 0 && _totalExpenses == 0
                      ? Center(child: Text('No data available', style: TextStyle(color: Colors.grey)))
                      : Column(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildIncomeExpensePieChart(_totalIncome, _totalExpenses),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Total',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                Text(
                                  '\$${(_totalIncome - _totalExpenses).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey[800],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendItem(Colors.green[700]!, 'Income'),
                          SizedBox(width: 20),
                          _buildLegendItem(Colors.red[700]!, 'Expenses'),
                        ],
                      ),
                    ],
                  ),

                  // Income Tab
                  _incomeByCategory.isEmpty
                      ? Center(child: Text('No income data', style: TextStyle(color: Colors.grey)))
                      : _buildCategoryPieChart(_incomeByCategory, isIncome: true),

                  // Expenses Tab
                  _expensesByCategory.isEmpty
                      ? Center(child: Text('No expense data', style: TextStyle(color: Colors.grey)))
                      : _buildCategoryPieChart(_expensesByCategory, isIncome: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpensePieChart(double income, double expense) {
    final total = income + expense;
    if (total == 0) return Center(child: Text('No data available', style: TextStyle(color: Colors.grey)));

    final incomePercentage = (income / total * 100).toStringAsFixed(1);
    final expensePercentage = (expense / total * 100).toStringAsFixed(1);

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            color: Colors.green[400],
            value: income,
            title: income > 0 ? '$incomePercentage%' : '',
            radius: 60,
            titleStyle: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          PieChartSectionData(
            color: Colors.red[400],
            value: expense,
            title: expense > 0 ? '$expensePercentage%' : '',
            radius: 60,
            titleStyle: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        centerSpaceRadius: 50,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildCategoryPieChart(Map<String, double> data, {required bool isIncome}) {
    if (data.isEmpty) {
      return Center(child: Text('No data available', style: TextStyle(color: Colors.grey)));
    }

    // Expanded color palette to prevent duplicates
    final colors = isIncome
        ? [
      Colors.green[300]!,
      Colors.green[500]!,
      Colors.green[700]!,
      Colors.lightGreen[300]!,
      Colors.lightGreen[500]!,
      Colors.teal[300]!,
      Colors.teal[500]!,
    ]
        : [
      Colors.red[300]!,
      Colors.red[500]!,
      Colors.red[700]!,
      Colors.orange[300]!,
      Colors.orange[500]!,
      Colors.deepOrange[300]!,
      Colors.pink[300]!,
    ];

    final total = isIncome
        ? data.values.fold(0.0, (sum, value) => sum + value)
        : data.values.fold(0.0, (sum, value) => sum + value);

    final sortedData = Map<String, double>.fromEntries(
      data.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );

    // Show top 5 categories + group others
    final Map<String, double> displayData;
    if (sortedData.length > 5) {
      displayData = Map<String, double>.fromEntries(
          sortedData.entries.take(5).toList()
      );
      displayData['Others'] = sortedData.entries
          .skip(5)
          .fold(0.0, (sum, entry) => sum + entry.value);
    } else {
      displayData = sortedData;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: 400,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: displayData.entries.map((entry) {
                      final percentage = total > 0 ? (entry.value / total * 100).toStringAsFixed(1) : '0';
                      return PieChartSectionData(
                        color: colors[displayData.keys.toList().indexOf(entry.key) % colors.length],
                        value: entry.value,
                        title: entry.value / total > 0.05 ? '$percentage%' : '',
                        radius: 60,
                        titleStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                    centerSpaceRadius: 50,
                    sectionsSpace: 0,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isIncome ? 'Income' : 'Expenses',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isIncome ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Flexible(
            child: Container(
              height: 120,
              padding: EdgeInsets.symmetric(horizontal: 16), // Added horizontal padding
              child: SingleChildScrollView(
                child: _buildEnhancedLegend(displayData, colors, isIncome: isIncome),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedLegend(Map<String, double> data, List<Color> colors, {required bool isIncome}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8), // Additional legend padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: data.entries.map((entry) {
          final index = data.keys.toList().indexOf(entry.key);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Text(
                    '\$${entry.value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
        SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTabbedBarChartSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          TabBar(
            controller: _barTabController,
            onTap: (index) {
              setState(() {
                _currentBarChartTab = index;
                _expandedIncomeCategory = null;
                _expandedExpenseCategory = null;
              });
            },
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueAccent,
            tabs: [
              Tab(text: 'Income by Category'),
              Tab(text: 'Expenses by Category'),
            ],
          ),
          SizedBox(
            height: 300,
            child: IndexedStack(
              index: _currentBarChartTab,
              children: [
                _buildBarChartWithCollapsibleDetails(
                  data: _incomeByCategory,
                  isIncome: true,
                  expandedCategory: _expandedIncomeCategory,
                  onCategoryTap: (category) {
                    setState(() {
                      _expandedIncomeCategory = _expandedIncomeCategory == category ? null : category;
                      if (_expandedIncomeCategory != null) _expandedExpenseCategory = null;
                    });
                  },
                ),
                _buildBarChartWithCollapsibleDetails(
                  data: _expensesByCategory,
                  isIncome: false,
                  expandedCategory: _expandedExpenseCategory,
                  onCategoryTap: (category) {
                    setState(() {
                      _expandedExpenseCategory = _expandedExpenseCategory == category ? null : category;
                      if (_expandedExpenseCategory != null) _expandedIncomeCategory = null;
                    });
                  },
                ),
              ],
            ),
          ),
          if (_expandedIncomeCategory != null || _expandedExpenseCategory != null)
            _buildCategoryDetailsSection(),
        ],
      ),
    );
  }

  Widget _buildBarChartWithCollapsibleDetails({
    required Map<String, double> data,
    required bool isIncome,
    required String? expandedCategory,
    required Function(String) onCategoryTap,
  }) {
    final showSubcategories = expandedCategory != null;
    final hasSubcategories = showSubcategories &&
        ((_subcategoryDetails[expandedCategory]?.isNotEmpty ?? false));

    final displayData = showSubcategories
        ? (hasSubcategories
        ? _aggregateSubcategories(_subcategoryDetails[expandedCategory] ?? [])
        : {expandedCategory: data[expandedCategory] ?? 0.0})
        : data;

    return _buildBarChart(
      data: data,
      displayData: displayData,
      isIncome: isIncome,
      onCategoryTap: onCategoryTap,
    );
  }

  Widget _buildBarChart({
    required Map<String, double> data,
    required Map<String, double> displayData,
    required bool isIncome,
    required Function(String) onCategoryTap,
  }) {
    final colors = isIncome
        ? [Colors.green[300]!, Colors.green[500]!, Colors.green[700]!]
        : [Colors.red[300]!, Colors.red[500]!, Colors.red[700]!];

    double getMaxValue(Map<String, double> values) {
      if (values.isEmpty) return 100.0;
      return values.values.reduce((a, b) => a > b ? a : b) * 1.2;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: getMaxValue(displayData),
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (FlTouchEvent event, response) {
              if (event is FlTapUpEvent && response?.spot != null) {
                final touchedIndex = response!.spot!.touchedBarGroupIndex;
                final category = data.keys.toList()[touchedIndex];
                onCategoryTap(category);
              }
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.grey[800]!,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final categoryName = displayData.keys.toList()[group.x.toInt()];
                return BarTooltipItem(
                  '$categoryName\n\$${rod.toY.toStringAsFixed(2)}',
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
                  if (index >= 0 && index < displayData.length) {
                    final category = displayData.keys.toList()[index];
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        category.length > 10 ? '${category.substring(0, 7)}...' : category,
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
            horizontalInterval: getMaxValue(displayData) / 5,
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
              left: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
          ),
          barGroups: displayData.entries.map((entry) {
            final index = displayData.keys.toList().indexOf(entry.key);
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
    );
  }

  Widget _buildCategoryDetailsSection() {
    final isIncome = _expandedIncomeCategory != null;
    final category = isIncome ? _expandedIncomeCategory! : _expandedExpenseCategory!;
    final data = isIncome ? _incomeByCategory : _expensesByCategory;
    final amount = data[category] ?? 0;
    final hasSubcategories = (_subcategoryDetails[category]?.isNotEmpty ?? false);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    if (isIncome) {
                      _expandedIncomeCategory = null;
                    } else {
                      _expandedExpenseCategory = null;
                    }
                  });
                },
              ),
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isIncome ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasSubcategories)
            Center(
              child: Text(
                'No subcategory details available',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          if (hasSubcategories)
            Column(
              children: _subcategoryDetails[category]!
                  .map((subcat) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        subcat['name'] ?? 'Uncategorized',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      '\$${(subcat['amount'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendChartSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            TabBar(
              controller: _trendTabController,
              onTap: (index) => setState(() => _currentTrendChartTab = index),
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blueAccent,
              tabs: [
                Tab(text: 'Income & Expenses'),
                Tab(text: 'Savings'),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: IndexedStack(
                index: _currentTrendChartTab,
                children: [
                  _buildTrendChart(
                    _monthlyTrends,
                    title: '',
                    showLabels: true,
                    showHorizontalAxis: true,
                  ),
                  _buildTrendChart(
                    _savingsTrends,
                    title: '',
                    isSavings: true,
                    showLabels: true,
                    showHorizontalAxis: true,
                  ),
                ],
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
    if (months.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No trend data available', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    final maxValue = trends.values.fold<double>(0.0, (max, data) {
      final currentMax = data.values.fold<double>(0.0, (currMax, val) => val > currMax ? val : currMax);
      return currentMax > max ? currentMax : max;
    });
    final minValue = trends.values.fold<double>(double.infinity, (min, data) {
      final currentMin = data.values.fold<double>(double.infinity, (currMin, val) => val < currMin ? val : currMin);
      return currentMin < min ? currentMin : min;
    });

    final double horizontalInterval;
    if (maxValue <= 0) {
      horizontalInterval = 100.0; // Default interval when no positive values
    } else {
      horizontalInterval = maxValue / 5;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (LineBarSpot touchedSpot) => Colors.grey[800]!,
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
            horizontalInterval: horizontalInterval, // Use the calculated interval
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
          borderData: FlBorderData(
            show: showHorizontalAxis,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
              left: BorderSide(
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
                color: Colors.green[700],
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
                color: Colors.red[700],
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
    );
  }

  Widget _buildRecentTransactions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            SizedBox(height: 12),
            if (_transactions.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No transactions found', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            else
              ..._transactions.take(3).map((t) => _buildTransactionTile(t)).toList(),
            if (_transactions.length > 3)
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MainScreen()),
                    );
                  },
                  child: Text(
                    'View All Transactions',
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ),
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

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isIncome ? Colors.green[100] : Colors.red[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isIncome ? Icons.arrow_upward : Icons.arrow_downward,
            color: isIncome ? Colors.green[700] : Colors.red[700],
            size: 20,
          ),
        ),
        title: Text(
          t['note'] ?? 'No description',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          isTransfer
              ? 'Transfer: ${t['from_account']} → ${t['to_account']}\n${DateFormat('MMM d').format(date)}'
              : '${t['category']} • ${DateFormat('MMM d').format(date)}',
          style: TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isIncome ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isTransfer)
              Text(
                'Transfer',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
        onTap: () => _showTransactionDetails(t),
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transaction Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Type', transaction['type']),
              _buildDetailRow('Amount', '\$${(transaction['amount'] as num).toStringAsFixed(2)}'),
              _buildDetailRow('Date', transaction['date']),
              if (transaction['category'] != null)
                _buildDetailRow('Category', transaction['category']),
              if (transaction['subcategory'] != null)
                _buildDetailRow('Subcategory', transaction['subcategory']),
              if (transaction['note'] != null && transaction['note'].isNotEmpty)
                _buildDetailRow('Note', transaction['note']),
              if (transaction['type'] == 'Transfer') ...[
                _buildDetailRow('From', transaction['from_account']),
                _buildDetailRow('To', transaction['to_account']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
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

  Future<void> _fetchReportData(int month, int year) async {
    final db = DatabaseHelper();

    // Initialize all data structures
    _totalIncome = 0.0;
    _totalExpenses = 0.0;
    _transactions = [];
    _incomeByCategory = {};
    _expensesByCategory = {};
    _subcategoryDetails = {};
    _monthlyTrends = {};
    _savingsTrends = {};

    try {
      // Get totals for the selected month
      _totalIncome = await db.getTotalByTypeForMonth('Income', month, year) ?? 0.0;
      _totalExpenses = await db.getTotalByTypeForMonth('Expense', month, year) ?? 0.0;

      // Get transactions for the selected month
      _transactions = await db.getTransactionsForMonth(month, year) ?? [];

      for (final t in _transactions) {
        if (t['type'] == 'Expense' && t['category'] != null) {
          final category = t['category'] as String;
          final amount = (t['amount'] as num).toDouble();
          _expensesByCategory[category] = (_expensesByCategory[category] ?? 0) + amount;

          // Group by subcategory
          final subcategory = t['subcategory'] as String? ?? 'Uncategorized';
          if (!_subcategoryDetails.containsKey(category)) {
            _subcategoryDetails[category] = [];
          }
          _subcategoryDetails[category]!.add({
            'name': subcategory,
            'amount': amount,
          });
        } else if (t['type'] == 'Income' && t['category'] != null) {
          final category = t['category'] as String;
          final amount = (t['amount'] as num).toDouble();
          _incomeByCategory[category] = (_incomeByCategory[category] ?? 0) + amount;

          // Group by subcategory
          final subcategory = t['subcategory'] as String? ?? 'Uncategorized';
          if (!_subcategoryDetails.containsKey(category)) {
            _subcategoryDetails[category] = [];
          }
          _subcategoryDetails[category]!.add({
            'name': subcategory,
            'amount': amount,
          });
        }
      }

      // Get monthly trends (last 6 months)
      _monthlyTrends = await _getMonthlyTrends() ?? {};

      // Get savings trends (last 6 months)
      _savingsTrends = await _getSavingsTrends() ?? {};

    } catch (e) {
      // Handle any errors that might occur during data fetching
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<Map<String, Map<String, double>>> _getMonthlyTrends() async {
    final db = DatabaseHelper();
    final now = DateTime.now();
    final result = <String, Map<String, double>>{};

    try {
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
    } catch (e) {
      // Return empty map if there's an error
      return {};
    }

    return result;
  }

  Future<Map<String, Map<String, double>>> _getSavingsTrends() async {
    final db = DatabaseHelper();
    final now = DateTime.now();
    final result = <String, Map<String, double>>{};
    double cumulativeSavings = 0.0;

    try {
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
    } catch (e) {
      // Return empty map if there's an error
      return {};
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
        _expandedIncomeCategory = null;
        _expandedExpenseCategory = null;
      });
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Financial Reports'),
        centerTitle: true,
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        enablePullDown: true,
        enablePullUp: false,
        header: const ClassicHeader(
          completeText: 'Refresh completed',
          refreshingText: 'Refreshing...',
          idleText: 'Pull down to refresh',
          releaseText: 'Release to refresh',
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _hasAnyData
            ? SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthHeader(),
              SizedBox(height: 8),
              _buildSummaryCards(),
              SizedBox(height: 16),
              _buildPieChartSection(),
              if (_incomeByCategory.isNotEmpty || _expensesByCategory.isNotEmpty)
                _buildTabbedBarChartSection(),
              if (_monthlyTrends.isNotEmpty || _savingsTrends.isNotEmpty)
                _buildTrendChartSection(),
              _buildRecentTransactions(),
            ],
          ),
        )
            : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insert_chart_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No Financial Data Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Add transactions to see reports',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MainScreen()),
                  );
                },
                child: Text('Add Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}