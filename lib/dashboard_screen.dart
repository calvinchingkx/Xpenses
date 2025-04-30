import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:provider/provider.dart';
import 'database_helper.dart';
import 'transaction_add.dart';
import 'transaction_update.dart';
import 'app_refresh_notifier.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double incomeTotal = 0.0;
  double expenseTotal = 0.0;
  Map<String, List<Map<String, dynamic>>> categorizedTransactions = {};
  DateTime currentMonthDate = DateTime.now();
  final RefreshController _refreshController = RefreshController();
  bool _isLoading = false;

  late final DateFormat _monthFormatter = DateFormat('MMM yyyy');
  late final DateFormat _displayDateFormatter = DateFormat('dd/MM/yyyy (EEE)');
  late final DateFormat _storageDateFormatter = DateFormat('dd/MM/yyyy');
  late final NumberFormat _currencyFormatter =
  NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _refreshData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppRefreshNotifier>().addListener(_refreshListener);
      }
    });
  }

  @override
  void dispose() {
    context.read<AppRefreshNotifier>().removeListener(_refreshListener);
    _refreshController.dispose();
    super.dispose();
  }

  void _refreshListener() {
    if (mounted) _refreshData();
  }

  Future<void> _onRefresh() async {
    await _refreshData();
    _refreshController.refreshCompleted();
  }

  Future<void> _refreshData() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        DatabaseHelper().getTotalByTypeForMonth(
          "Income",
          currentMonthDate.month,
          currentMonthDate.year,
        ),
        DatabaseHelper().getTotalByTypeForMonth(
          "Expense",
          currentMonthDate.month,
          currentMonthDate.year,
        ),
        _loadTransactions(),
      ]);

      if (mounted) {
        setState(() {
          incomeTotal = (results[0] as num?)?.toDouble() ?? 0.0;
          expenseTotal = (results[1] as num?)?.toDouble() ?? 0.0;
          categorizedTransactions = results[2] as Map<String, List<Map<String, dynamic>>>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing data: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String get formattedMonth => _monthFormatter.format(currentMonthDate);

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentMonthDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null && picked != currentMonthDate && mounted) {
      setState(() {
        currentMonthDate = DateTime(picked.year, picked.month, 1);
      });
      await _refreshData();
    }
  }

  void _previousMonth() {
    setState(() {
      currentMonthDate = DateTime(
          currentMonthDate.year,
          currentMonthDate.month - 1,
          1
      );
    });
    _refreshData();
  }

  void _nextMonth() {
    setState(() {
      currentMonthDate = DateTime(
          currentMonthDate.year,
          currentMonthDate.month + 1,
          1
      );
    });
    _refreshData();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadTransactions() async {
    final allTransactions = await DatabaseHelper().getTransactionsForMonth(
      currentMonthDate.month,
      currentMonthDate.year,
    );

    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var transaction in allTransactions) {
      final date = _tryParseDate(transaction['date'] as String);
      if (date == null) continue;

      final formattedDate = _storageDateFormatter.format(date);
      grouped.putIfAbsent(formattedDate, () => []).add(transaction);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => _parseDate(b)!.compareTo(_parseDate(a)!));

    return {for (var key in sortedKeys) key: grouped[key]!};
  }

  DateTime? _tryParseDate(String dateString) {
    try {
      return _storageDateFormatter.parse(dateString.split(' ').first);
    } catch (e) {
      return null;
    }
  }

  DateTime? _parseDate(String dateString) {
    return _tryParseDate(dateString);
  }

  void _showCustomBottomSheet(Widget child, {VoidCallback? onDismiss}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isDismissible: true,
      builder: (BuildContext context) {
        return GestureDetector(
            onTap: () {
            Navigator.pop(context); // Dismiss when tapping outside
          },
          behavior: HitTestBehavior.opaque, // Makes entire area tappable
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.75,
            maxChildSize: 0.75,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: child,
              );
            },
          )
        );
      },
    ).then((_) => onDismiss?.call());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppRefreshNotifier>(
      builder: (context, refreshNotifier, _) {
        if (refreshNotifier.shouldRefreshTransactions) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _refreshData();
            refreshNotifier.transactionRefreshComplete();
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard'),
            centerTitle: true,
          ),
          body: Column(
            children: [
              _buildHeaderSection(context),
              Expanded(
                child: SmartRefresher(
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
                      ? const Center(child: CircularProgressIndicator())
                      : _buildTransactionList(),
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
      },
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          const Divider(thickness: 1, color: Colors.black45),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 0.0),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryText('Income', _formatCurrency(incomeTotal), Colors.blueGrey),
                _buildSummaryText('Expenses', _formatCurrency(expenseTotal), Colors.red),
                _buildSummaryText('Balance', _formatCurrency(incomeTotal - expenseTotal), Colors.green),
              ],
            ),
          ),
          const Divider(thickness: 2, color: Colors.black45),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (categorizedTransactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No transactions for $formattedMonth',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: categorizedTransactions.length,
      itemBuilder: (context, index) {
        final date = categorizedTransactions.keys.elementAt(index);
        final transactions = categorizedTransactions[date]!;
        final parsedDate = _parseDate(date)!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(thickness: 1, color: Colors.black45),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                _displayDateFormatter.format(parsedDate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
            const Divider(thickness: 1, color: Colors.black45),
            ...transactions.map((transaction) => _TransactionTile(
              transaction: transaction,
              onTap: () => _showCustomBottomSheet(
                TransactionUpdatePage(transaction: transaction),
                onDismiss: _refreshData,
              )
            )),
          ],
        );
      },
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    return _currencyFormatter.format(amount);
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
        ? Colors.grey // Changed to grey for transfers
        : transaction['type'] == "Income"
        ? Colors.blueGrey
        : Colors.red;

    // Build category text with subcategory if available
    final categoryText = isTransfer
        ? 'Transfer'
        : transaction['subcategory']?.isNotEmpty == true
        ? '${transaction['category']}/\n${transaction['subcategory']}'
        : transaction['category'] ?? 'No Category';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 14.0),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  categoryText, // Use the built category text
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction['note'] ?? (isTransfer ? 'Transfer' : 'No Note'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTransfer
                        ? '${transaction['from_account'] ?? '?'} → ${transaction['to_account'] ?? '?'}'
                        : transaction['account'] ?? 'No Account',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Text(
              _formatCurrency((transaction['amount'] as num).toDouble()),
              style: TextStyle(
                fontSize: 16,
                color: amountColor,
                fontWeight: isTransfer ? FontWeight.normal : FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    ).format(amount);
  }
}