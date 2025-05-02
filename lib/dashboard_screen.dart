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
              Navigator.pop(context);
            },
            behavior: HitTestBehavior.opaque,
            child: DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.75,
              maxChildSize: 0.75,
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).canvasColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
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
    final theme = Theme.of(context);

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
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Divider(
            thickness: 1,
            color: theme.dividerColor.withOpacity(0.2), // More subtle divider
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_left,
                      color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8)),
                  onPressed: _previousMonth,
                ),
                GestureDetector(
                  onTap: _selectMonth,
                  child: Text(
                    formattedMonth,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600, // Reduced from bold
                      color: theme.textTheme.titleMedium?.color?.withOpacity(0.9),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_right,
                      color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8)),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          Divider(
            thickness: 1,
            color: theme.dividerColor.withOpacity(0.2),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryText('Income', _formatCurrency(incomeTotal),
                    Colors.green[700]!),
                _buildSummaryText('Expenses', _formatCurrency(expenseTotal),
                    Colors.red[700]!),
                _buildSummaryText('Balance', _formatCurrency(incomeTotal - expenseTotal),
                    Colors.blueGrey),
              ],
            ),
          ),
          Divider(
            thickness: 1,
            color: theme.dividerColor.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    final theme = Theme.of(context);

    if (categorizedTransactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No transactions for $formattedMonth',
            style: TextStyle(
              fontSize: 16,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
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
            Divider(
              thickness: 1,
              color: theme.dividerColor,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                _displayDateFormatter.format(parsedDate),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ),
            Divider(
              thickness: 1,
              color: theme.dividerColor,
            ),
            ...transactions.map((transaction) => _TransactionTile(
              transaction: transaction,
              onTap: () => _showCustomBottomSheet(
                TransactionUpdatePage(transaction: transaction),
                onDismiss: _refreshData,
              ),
            )),
          ],
        );
      },
    );
  }

  Widget _buildSummaryText(String title, String amount, Color color) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodySmall?.color,
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

  String get _categoryText {
    final isTransfer = transaction['type'] == 'Transfer';
    if (isTransfer) return 'Transfer';

    final category = transaction['category'] ?? 'No Category';
    final subcategory = transaction['subcategory']?.toString();

    return subcategory?.isNotEmpty == true
        ? '$category/\n$subcategory'
        : category;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTransfer = transaction['type'] == 'Transfer';

    // Softer colors for dark mode
    final amountColor = isTransfer
        ? theme.disabledColor
        : transaction['type'] == "Income"
        ? Colors.blueGrey // Softer blue for income
        : Colors.red[700];    // Softer red for expenses

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
                  _categoryText,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600, // Slightly lighter weight
                      color: theme.textTheme.bodyLarge?.color?.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTransfer
                        ? '${transaction['from_account'] ?? '?'} → ${transaction['to_account'] ?? '?'}'
                        : transaction['account'] ?? 'No Account',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatCurrency((transaction['amount'] as num).toDouble()),
              style: TextStyle(
                fontSize: 16,
                color: amountColor,
                fontWeight: isTransfer ? FontWeight.normal : FontWeight.w600,
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