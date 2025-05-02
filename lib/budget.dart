import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:provider/provider.dart';
import 'app_refresh_notifier.dart';
import 'database_helper.dart';

class BudgetScreen extends StatefulWidget {
  @override
  _BudgetScreenState createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final RefreshController _refreshController = RefreshController();
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  String _sortBy = 'category';
  bool _sortAscending = true;
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final currentDate = DateTime.now();
      final yearMonth = _selectedMonth ?? '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';

      // Check if we need to create new monthly budgets
      final lastBudget = await DatabaseHelper().getLatestBudget();
      if (lastBudget != null && lastBudget['year_month'] != yearMonth) {
        await _createNewMonthBudgets(lastBudget, yearMonth);
      }

      // Get budgets and categories
      final budgets = await DatabaseHelper().getBudgets(yearMonth: yearMonth);
      final categories = await DatabaseHelper().getCategories('expense');

      // Get actual spent amounts from transactions
      final spentAmounts = await DatabaseHelper().getSpentAmountsByCategory(yearMonth);

      // Update budgets with actual spent amounts
      final updatedBudgets = budgets.map((budget) {
        final category = budget['category'] as String;
        return {
          ...budget,
          'current_month_spent': spentAmounts[category] ?? 0.0,
        };
      }).toList();

      setState(() {
        _budgets = _sortBudgets(updatedBudgets.where((b) =>
        b['id'] != null &&
            b['budget_limit'] != null &&
            b['current_month_spent'] != null &&
            b['category'] != null).toList());
        _categories = categories;
      });
    } catch (e) {
      _showError('Failed to load data: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _refreshController.refreshCompleted();
        Provider.of<AppRefreshNotifier>(context, listen: false).budgetRefreshComplete();
      }
    }
  }

  Future<void> _onRefresh() async {
    try {
      await _loadData();
    } catch (e) {
      if (mounted) {
        _refreshController.refreshFailed();
        _showError('Refresh failed: ${e.toString()}');
      }
    }
  }

  Future<void> _createNewMonthBudgets(Map<String, dynamic> lastBudget, String newYearMonth) async {
    try {
      // Get all active budgets from previous month
      final previousBudgets = await DatabaseHelper().getActiveBudgets();

      for (var budget in previousBudgets) {
        // Create new budget with same settings but reset spent amount
        await DatabaseHelper().addBudget({
          'category': budget['category'],
          'type': budget['type'],
          'budget_limit': budget['budget_limit'],
          'current_month_spent': 0.0,
          'previous_months_spent': (budget['current_month_spent'] as num).toDouble(),
          'year_month': newYearMonth,
          'created_at': DateTime.now().toIso8601String(),
          'is_active': 1
        });

        // Deactivate old budget
        await DatabaseHelper().updateBudget({
          'id': budget['id'],
          'is_active': 0
        });
      }
    } catch (e) {
      _showError('Failed to create new month budgets: ${e.toString()}');
    }
  }

  List<Map<String, dynamic>> _sortBudgets(List<Map<String, dynamic>> budgets) {
    return List.from(budgets)..sort((a, b) {
      String getValue(String key, Map<String, dynamic> item) =>
          item[key]?.toString().toLowerCase() ?? '';

      double getLimit(Map<String, dynamic> item) =>
          (item['budget_limit'] as num?)?.toDouble() ?? 0.0;

      double getSpent(Map<String, dynamic> item) =>
          (item['current_month_spent'] as num?)?.toDouble() ?? 0.0;

      double getRemaining(Map<String, dynamic> item) =>
          getLimit(item) - getSpent(item);

      switch (_sortBy) {
        case 'budget_limit':
          final comparison = getLimit(a).compareTo(getLimit(b));
          return _sortAscending ? comparison : -comparison;
        case 'spent':
          final comparison = getSpent(a).compareTo(getSpent(b));
          return _sortAscending ? comparison : -comparison;
        case 'remaining':
          final comparison = getRemaining(a).compareTo(getRemaining(b));
          return _sortAscending ? comparison : -comparison;
        default: // category
          final comparison = getValue('category', a).compareTo(getValue('category', b));
          return _sortAscending ? comparison : -comparison;
      }
    });
  }

  Future<void> _saveBudget(int? id, String category, double amount) async {
    try {
      final currentDate = DateTime.now();
      final yearMonth = _selectedMonth ?? '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';

      if (id == null) {
        await DatabaseHelper().addBudget({
          'category': category,
          'type': 'expense',
          'budget_limit': amount,
          'current_month_spent': 0.0,
          'previous_months_spent': 0.0,
          'year_month': yearMonth,
          'created_at': currentDate.toIso8601String(),
          'is_active': 1
        });
      } else {
        await DatabaseHelper().updateBudget({
          'id': id,
          'category': category,
          'budget_limit': amount
        });
      }
      await _loadData();
    } catch (e) {
      _showError('Failed to save budget: ${e.toString()}');
    }
  }

  Future<void> _deleteBudget(int id) async {
    try {
      await DatabaseHelper().deleteBudget(id);
      await _loadData();
    } catch (e) {
      _showError('Failed to delete budget: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppRefreshNotifier>(
      builder: (context, refreshNotifier, _) {
        if (refreshNotifier.shouldRefreshBudgets) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadData();
            refreshNotifier.budgetRefreshComplete();
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Budget Overview'),
            actions: [
              _buildMonthSelector(),
              _buildSortMenu(),
            ],
          ),
          body: Column(
            children: [
              // Always show summary at top
              _buildBudgetSummaryCard(),
              // Expanded makes the list take remaining space
              Expanded(
                child: _buildRefreshableList(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showBudgetDialog(null),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        setState(() {
          if (value == _sortBy) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = true;
          }
          _budgets = _sortBudgets(_budgets);
        });
      },
      itemBuilder: (context) => [
        _buildSortMenuItem('category', 'Sort by Category'),
        _buildSortMenuItem('budget_limit', 'Sort by Limit'),
        _buildSortMenuItem('spent', 'Sort by Spent'),
        _buildSortMenuItem('remaining', 'Sort by Remaining'),
      ],
      icon: const Icon(Icons.sort),
    );
  }

  Widget _buildMonthSelector() {
    return FutureBuilder<List<String>>(
      future: DatabaseHelper().getBudgetMonths(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container();
        }

        final currentDate = DateTime.now();
        final currentYearMonth = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';
        final selectedMonth = _selectedMonth ?? currentYearMonth;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: DropdownButton<String>(
            value: selectedMonth,
            items: snapshot.data!.map((month) => DropdownMenuItem(
              value: month,
              child: Text(month),
            )).toList(),
            onChanged: (month) {
              setState(() {
                _selectedMonth = month;
                _loadData();
              });
            },
          ),
        );
      },
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String text) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: _sortBy == value
                ? Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18,
            )
                : null,
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildRefreshableList() {
    return SmartRefresher(
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
      child: _buildBudgetsList(),
    );
  }

  Widget _buildBudgetsList() {
    if (_isLoading && _budgets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_budgets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.money_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Budgets Found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            TextButton(
              onPressed: () => _showBudgetDialog(null),
              child: const Text('Create Your First Budget'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _budgets.length,
      itemBuilder: (context, index) {
        final budget = _budgets[index];
        final limit = (budget['budget_limit'] as num).toDouble();
        final spent = (budget['current_month_spent'] as num).toDouble();
        final remaining = limit - spent;
        final percentage = limit > 0 ? (spent / limit) : 0;

        // Show overspend alert if needed
        if (remaining < 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOverspendAlert(budget['category'], remaining.abs());
          });
        }

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ListTile(
            title: Text(budget['category']?.toString() ?? 'Uncategorized'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Limit: \$${limit.toStringAsFixed(2)}'),
                    Text('Spent: \$${spent.toStringAsFixed(2)}'),
                  ],
                ),
                Text(
                  'Remaining: \$${remaining.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: remaining >= 0 ? Colors.green[700] : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (percentage > 1 ? 1 : percentage).toDouble(),
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentage > 0.8
                          ? percentage > 1
                          ? Colors.red[700]!
                          : Colors.orange[700]!
                          : Colors.green[700]!,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () => _showBudgetDialog(budget),
          ),
        );
      },
    );
  }

  void _showOverspendAlert(String category, double overspendAmount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Budget overspent for $category by \$${overspendAmount.toStringAsFixed(2)}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _confirmDeleteBudget(int id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: const Text('Are you sure you want to delete this budget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      await _deleteBudget(id);
    }
  }

  void _showBudgetDialog(Map<String, dynamic>? budget) {
    String? selectedCategory = budget?['category'];
    final amountController = TextEditingController(
      text: budget?['budget_limit']?.toStringAsFixed(2) ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(budget == null ? 'Create Budget' : 'Edit Budget'),
            if (budget != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  _confirmDeleteBudget(budget['id']);
                },
              ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(
                  value: c['name'] as String,
                  child: Text(c['name'] as String),
                ))
                    .toList(),
                onChanged: (value) => selectedCategory = value,
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _saveBudget(
                  budget?['id'],
                  selectedCategory!,
                  double.parse(amountController.text),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSummaryCard() {
    final totalLimit = _budgets.fold(0.0, (sum, b) => sum + (b['budget_limit'] as num).toDouble());
    final totalSpent = _budgets.fold(0.0, (sum, b) => sum + (b['current_month_spent'] as num).toDouble());
    final totalRemaining = totalLimit - totalSpent;
    final percentageSpent = totalLimit > 0 ? (totalSpent / totalLimit) : 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Budget', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text('\$${totalLimit.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Remaining', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text('\$${totalRemaining.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: totalRemaining >= 0 ? Colors.green[700] : Colors.red,
                        )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percentageSpent > 1 ? 1 : percentageSpent).toDouble(),
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentageSpent > 0.8
                      ? percentageSpent > 1
                      ? Colors.red[700]!
                      : Colors.orange[700]!
                      : Colors.green[700]!,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}