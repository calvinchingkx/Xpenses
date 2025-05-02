import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'database_helper.dart';

class CategoryTransactionScreen extends StatefulWidget {
  final String category;
  final String? subcategory;
  final int month;
  final int year;

  const CategoryTransactionScreen({
    Key? key,
    required this.category,
    this.subcategory,
    required this.month,
    required this.year,
  }) : super(key: key);

  @override
  State<CategoryTransactionScreen> createState() => _CategoryTransactionScreenState();
}

class _CategoryTransactionScreenState extends State<CategoryTransactionScreen> {
  double incomeTotal = 0.0;
  double expenseTotal = 0.0;
  Map<String, List<Map<String, dynamic>>> categorizedTransactions = {};
  final RefreshController _refreshController = RefreshController();
  bool _isLoading = false;

  late final DateFormat _monthFormatter = DateFormat('MMM yyyy');
  late final DateFormat _displayDateFormatter = DateFormat('dd/MM/yyyy (EEE)');
  late final DateFormat _storageDateFormatter = DateFormat('dd/MM/yyyy');
  late final NumberFormat _currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await _refreshData();
    _refreshController.refreshCompleted();
  }

  Future<void> _refreshData() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final transactions = widget.subcategory != null
          ? await DatabaseHelper().getTransactionsForCategoryWithSubcategory(
        widget.category,
        widget.subcategory!,
        widget.month,
        widget.year,
      )
          : await DatabaseHelper().getTransactionsForCategory(
        widget.category,
        widget.month,
        widget.year,
      );

      // Calculate totals
      expenseTotal = transactions.fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());

      // Group by date
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var transaction in transactions) {
        final date = _tryParseDate(transaction['date'] as String);
        if (date == null) continue;

        final formattedDate = _storageDateFormatter.format(date);
        grouped.putIfAbsent(formattedDate, () => []).add(transaction);
      }

      final sortedKeys = grouped.keys.toList()
        ..sort((a, b) => _parseDate(b)!.compareTo(_parseDate(a)!));

      if (mounted) {
        setState(() {
          categorizedTransactions = {for (var key in sortedKeys) key: grouped[key]!};
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subcategory != null
            ? '${widget.category} / ${widget.subcategory}'
            : widget.category),
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
            color: theme.dividerColor.withOpacity(0.2),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Total Spent: ${_currencyFormatter.format(expenseTotal)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleMedium?.color,
              ),
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
            'No transactions found',
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
            )),
          ],
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const _TransactionTile({
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = (transaction['amount'] as num).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                transaction['subcategory'] ?? 'No Subcategory',
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
                  transaction['note'] ?? 'No Note',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color?.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction['account_name'] ?? 'No Account',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.red[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}