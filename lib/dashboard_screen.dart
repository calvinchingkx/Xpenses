import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show showDatePicker;
import 'package:xpenses/database_helper.dart';
import 'dart:math' as math;
import 'transaction_page.dart';
import 'transaction_detail.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double incomeTotal = 0.0;
  double expenseTotal = 0.0;
  Map<String, List<Map<String, dynamic>>> categorizedTransactions = {};
  DateTime currentMonthDate = DateTime.now();
  final ScrollController _scrollController = ScrollController();
  int _visibleItems = 20;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _scrollController.addListener(_loadMore);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    try {
      final income = await DatabaseHelper.instance.getTotalByType("Income");
      final expense = await DatabaseHelper.instance.getTotalByType("Expense");
      final transactions = await _loadTransactions();

      setState(() {
        incomeTotal = income ?? 0.0;
        expenseTotal = expense ?? 0.0;
        categorizedTransactions = transactions;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing data: ${e.toString()}')),
      );
    }
  }

  String get formattedMonth {
    return DateFormat('MMM yyyy').format(currentMonthDate);
  }

  void _loadMore() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      setState(() => _visibleItems += 20);
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentMonthDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blueGrey,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueGrey,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != currentMonthDate) {
      setState(() {
        currentMonthDate = DateTime(picked.year, picked.month, 1);
      });
      _refreshData();
    }
  }

  void _previousMonth() {
    setState(() {
      currentMonthDate = DateTime(currentMonthDate.year, currentMonthDate.month - 1, 1);
    });
    _refreshData();
  }

  void _nextMonth() {
    setState(() {
      currentMonthDate = DateTime(currentMonthDate.year, currentMonthDate.month + 1, 1);
    });
    _refreshData();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadTransactions() async {
    final allTransactions = await DatabaseHelper.instance.getAllTransactions();
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var transaction in allTransactions) {
      final date = DateUtils.tryParse(transaction['date']);
      if (date == null) continue;

      if (date.month == currentMonthDate.month && date.year == currentMonthDate.year) {
        final formattedDate = DateUtils.formatStorageDate(date);
        grouped.putIfAbsent(formattedDate, () => []).add(transaction);
      }
    }

    // Sort by descending date (newest first)
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => DateUtils.parse(b)!.compareTo(DateUtils.parse(a)!));

    return {for (var key in sortedKeys) key: grouped[key]!};
  }

  void _showCustomBottomSheet(Widget child, {VoidCallback? onDismiss}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54, // Make sure this is set
      isDismissible: true, // Ensure this is true
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => GestureDetector(
        onTap: () {
          Navigator.pop(context); // Close the bottom sheet when tapped outside
        },
        behavior: HitTestBehavior.opaque, // Important for tap detection
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.75,
          maxChildSize: 0.75,
          builder: (_, controller) => GestureDetector(
            onTap: () {}, // Prevent taps from bubbling up
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    ).then((_) {
      onDismiss?.call(); // Call the refresh callback
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Divider(thickness: 1, color: Colors.black45),

          // Minimal Month Selector
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left),
                  onPressed: _previousMonth,
                ),
                GestureDetector(
                  onTap: _selectMonth,
                  child: Text(
                    formattedMonth,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          const Divider(thickness: 2, color: Colors.black45),

          // Summary Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryText('Income', formatCurrency(incomeTotal), Colors.blueGrey),
              _buildSummaryText('Expenses', formatCurrency(expenseTotal), Colors.red),
              _buildSummaryText('Balance', formatCurrency(incomeTotal - expenseTotal), Colors.green),
            ],
          ),

          const Divider(thickness: 2, color: Colors.black45),

          // Transactions List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: math.min(_visibleItems, categorizedTransactions.keys.length),
                itemBuilder: (context, index) {
                  final date = categorizedTransactions.keys.elementAt(index);
                  return _TransactionDateGroup(
                    date: date,
                    transactions: categorizedTransactions[date]!,
                    onTap: (transaction) => _showCustomBottomSheet(
                      TransactionDetailPage(transaction: transaction),
                      onDismiss: _refreshData,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomBottomSheet(
          TransactionPage(scrollController: ScrollController()),
          onDismiss: _refreshData,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryText(String title, String amount, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TransactionDateGroup extends StatelessWidget {
  final String date;
  final List<Map<String, dynamic>> transactions;
  final Function(Map<String, dynamic>) onTap;

  const _TransactionDateGroup({
    required this.date,
    required this.transactions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(thickness: 1, color: Colors.black45),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              DateUtils.formatDisplayDate(DateUtils.parse(date)!),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
        ),
        const Divider(thickness: 1, color: Colors.black45),
        ...transactions.map((transaction) => _TransactionTile(
          transaction: transaction,
          onTap: () => onTap(transaction),
        )),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTransfer = transaction['type'] == 'Transfer';
    final amountColor = isTransfer
        ? Colors.blueGrey
        : transaction['type'] == "Income"
        ? Colors.blueGrey
        : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category/Transfer Indicator (left column)
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  isTransfer
                      ? 'Transfer'
                      : transaction['category'] ?? 'No Category',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
            // Main Content (middle column)
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show NOTE first (now matches data storage)
                  Text(
                    transaction['note'] ?? (isTransfer ? 'Transfer' : 'No Note'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Show ACCOUNT second (now matches data storage)
                  Text(
                    isTransfer
                        ? '${transaction['from_account'] ?? '?'} → ${transaction['to_account'] ?? '?'}'
                        : transaction['account'] ?? 'No Account',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            // Amount (right column)
            Text(
              formatCurrency(transaction['amount'] ?? 0.0),
              style: TextStyle(
                fontSize: 16,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DateUtils {
  static String formatDisplayDate(DateTime date) {
    return DateFormat('dd/MM/yyyy (EEE)').format(date);
  }

  static String formatStorageDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static DateTime? tryParse(String dateString) {
    try {
      return DateFormat('dd/MM/yyyy').parse(dateString.split(' ').first);
    } catch (e) {
      return null;
    }
  }

  static DateTime? parse(String dateString) {
    return tryParse(dateString);
  }
}

String formatCurrency(double amount) {
  return NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  ).format(amount);
}