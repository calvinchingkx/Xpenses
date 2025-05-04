import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:provider/provider.dart';
import 'app_refresh_notifier.dart';
import 'database_helper.dart';
import 'category_transaction_screen.dart';
import 'services/notification_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

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

      // Load data for current month
      final budgets = await DatabaseHelper().getBudgets(yearMonth: yearMonth);
      final categories = await DatabaseHelper().getCategories('expense');
      final spentAmounts = await DatabaseHelper().getSpentAmountsByCategory(yearMonth);

      // Update budgets with spent amounts
      final updatedBudgets = budgets.map((budget) {
        final category = budget['category'] as String;
        return {
          ...budget,
          'current_month_spent': spentAmounts[category] ?? 0.0,
        };
      }).toList();

      setState(() {
        _budgets = _sortBudgets(updatedBudgets);
        _categories = categories;
      });

    } catch (e) {
      _showError('Failed to load data: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _refreshController.refreshCompleted();
      }
    }
  }

  Future<void> _checkBudgetNotifications(Map<String, dynamic> budget) async {
    final limit = (budget['budget_limit'] as num).toDouble();
    final spent = (budget['current_month_spent'] as num).toDouble();
    final percentage = limit > 0 ? (spent / limit) : 0;
    final category = budget['category'] as String;

    final db = await DatabaseHelper().database;
    final user = await db.query('user', limit: 1);
    final notificationsEnabled = user.isNotEmpty
        ? (user[0]['budget_notifications'] as int?) == 1
        : true;

    if (!notificationsEnabled) return;

    final notificationService = Provider.of<NotificationService>(context, listen: false);

    if (spent > limit && budget['_notification_sent'] != 'alert') {
      final overspendAmount = spent - limit;
      notificationService.showBudgetAlert(category, overspendAmount);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Budget overspent for $category by \$${overspendAmount.toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      budget['_notification_sent'] = 'alert';
    }
    else if (percentage >= 0.8 && budget['_notification_sent'] != 'warning') {
      notificationService.showBudgetWarning(category, percentage * 100);
      budget['_notification_sent'] = 'warning';
    }
    else if (percentage < 0.8 && spent <= limit) {
      budget['_notification_sent'] = null;
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
      final currentYearMonth = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';
      final selectedYearMonth = _selectedMonth ?? currentYearMonth;
      final isCurrentMonth = selectedYearMonth == currentYearMonth;

      if (id == null) {
        // Creating a new budget
        await DatabaseHelper().addBudget({
          'category': category,
          'type': 'expense',
          'budget_limit': amount,
          'current_month_spent': 0.0,
          'previous_months_spent': 0.0,
          'year_month': selectedYearMonth,
          'created_at': currentDate.toIso8601String(),
          'is_active': 1
        });

        // If creating in current month, propagate to future months
        if (isCurrentMonth) {
          await _propagateNewBudgetToFutureMonths(category, amount);
        }
      } else {
        // Updating existing budget
        final existingBudget = await DatabaseHelper().getBudgetById(id);
        if (existingBudget == null) {
          throw Exception('Budget not found');
        }

        // Update the specific budget first
        await DatabaseHelper().updateBudget({
          'id': id,
          'category': existingBudget['category'],
          'type': existingBudget['type'],
          'budget_limit': amount,
          'current_month_spent': existingBudget['current_month_spent'],
          'previous_months_spent': existingBudget['previous_months_spent'],
          'year_month': existingBudget['year_month'],
          'is_active': existingBudget['is_active']
        });

        // If current month, update ALL future months
        if (isCurrentMonth) {
          await _updateFutureMonthsBudgets(category, amount);
        }
        // If future month, update from selected month onwards
        else {
          await _updateFromSelectedMonthOnwards(selectedYearMonth, category, amount);
        }
      }
      await _loadData();
    } catch (e) {
      _showError('Failed to save budget: ${e.toString()}');
    }
  }

  Future<void> _updateFromSelectedMonthOnwards(String selectedYearMonth, String category, double amount) async {
    // Get all months from selected month onwards
    final allMonths = await DatabaseHelper().getBudgetMonths();
    final monthsToUpdate = allMonths.where((m) => m.compareTo(selectedYearMonth) >= 0).toList();

    for (var month in monthsToUpdate) {
      final existing = await DatabaseHelper().getBudgetByCategory(category, month);
      if (existing != null) {
        await DatabaseHelper().updateBudget({
          'id': existing['id'],
          'category': existing['category'],
          'type': existing['type'],
          'budget_limit': amount,
          'current_month_spent': existing['current_month_spent'],
          'previous_months_spent': existing['previous_months_spent'],
          'year_month': existing['year_month'],
          'is_active': existing['is_active']
        });
      } else {
        // Create new budget if doesn't exist for this category/month
        await DatabaseHelper().addBudget({
          'category': category,
          'type': 'expense',
          'budget_limit': amount,
          'current_month_spent': 0.0,
          'previous_months_spent': 0.0,
          'year_month': month,
          'created_at': DateTime.now().toIso8601String(),
          'is_active': 1
        });
      }
    }
  }

  Future<void> _deleteBudget(int id, String category) async {
    try {
      final currentDate = DateTime.now();
      final currentYearMonth = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';
      final budgetToDelete = await DatabaseHelper().getBudgetById(id);

      if (budgetToDelete == null) {
        throw Exception('Budget not found');
      }

      final selectedYearMonth = budgetToDelete['year_month'] as String;
      final isCurrentMonth = selectedYearMonth == currentYearMonth;

      await DatabaseHelper().deleteBudget(id);

      // If current month, delete ALL future months
      if (isCurrentMonth) {
        await _deleteFutureMonthsBudgets(category);
      }
      // If future month, delete from selected month onwards
      else {
        await _deleteFromSelectedMonthOnwards(selectedYearMonth, category);
      }

      await _loadData();
    } catch (e) {
      _showError('Failed to delete budget: ${e.toString()}');
    }
  }

  Future<void> _deleteFromSelectedMonthOnwards(String selectedYearMonth, String category) async {
    // Get all months from selected month onwards
    final allMonths = await DatabaseHelper().getBudgetMonths();
    final monthsToDelete = allMonths.where((m) => m.compareTo(selectedYearMonth) >= 0).toList();

    for (var month in monthsToDelete) {
      final existing = await DatabaseHelper().getBudgetByCategory(category, month);
      if (existing != null) {
        await DatabaseHelper().deleteBudget(existing['id'] as int);
      }
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
              _buildSortMenu(),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: _buildMonthHeader(context),
            ),
          ),
          body: Column(
            children: [
              _buildBudgetSummaryCard(),
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

  Widget _buildMonthHeader(BuildContext context) {
    final theme = Theme.of(context);
    final currentDate = DateTime.now();
    final currentYearMonth = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';
    final selectedMonth = _selectedMonth ?? currentYearMonth;
    final selectedDate = DateTime.parse('$selectedMonth-01');
    final monthText = DateFormat('MMM yyyy').format(selectedDate);

    return Column(
      children: [
        Divider(
          thickness: 1,
          color: theme.dividerColor.withOpacity(0.2),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_left,
                    color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8)),
                onPressed: () => _changeMonth(-1),
              ),
              GestureDetector(
                onTap: _showMonthPicker,
                child: Text(
                  monthText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.titleMedium?.color?.withOpacity(0.9),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.arrow_right,
                    color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8)),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
        ),
        Divider(
          thickness: 1,
          color: theme.dividerColor.withOpacity(0.2),
        ),
      ],
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

  void _changeMonth(int delta) {
    final selectedDate = _selectedMonth != null
        ? DateTime.parse('$_selectedMonth-01')
        : DateTime.now();

    final newDate = DateTime(selectedDate.year, selectedDate.month + delta, 1);
    setState(() {
      _selectedMonth = '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}';
    });
    _loadData();
  }

  Future<void> _showMonthPicker() async {
    final selectedDate = _selectedMonth != null
        ? DateTime.parse('$_selectedMonth-01')
        : DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        _selectedMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
      });
      await _loadData();
    }
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

        _checkBudgetNotifications(budget);

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: InkWell(
            onTap: () => _navigateToCategoryTransactions(budget),
            onLongPress: () => _showBudgetOptions(budget),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    budget['category']?.toString() ?? 'Uncategorized',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
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
            ),
          ),
        );
      },
    );
  }

  void _navigateToCategoryTransactions(Map<String, dynamic> budget) {
    final currentDate = DateTime.now();
    final month = _selectedMonth != null
        ? int.parse(_selectedMonth!.split('-')[1])
        : currentDate.month;
    final year = _selectedMonth != null
        ? int.parse(_selectedMonth!.split('-')[0])
        : currentDate.year;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryTransactionScreen(
          category: budget['category'] as String,
          month: month,
          year: year,
        ),
      ),
    );
  }

  void _showBudgetOptions(Map<String, dynamic> budget) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Budget'),
              onTap: () {
                Navigator.pop(context);
                _showBudgetDialog(budget);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Budget', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                if (budget['id'] != null) {
                  await _confirmDeleteBudget(
                    budget['id'] as int,
                    budget['category'] as String,
                  );
                } else {
                  _showError('Cannot delete - budget has no ID');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteBudget(int id, String category) async {
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
      await _deleteBudget(id, category);
    }
  }

  void _showBudgetDialog(Map<String, dynamic>? budget) {
    String? selectedCategory = budget?['category'];
    final amountController = TextEditingController(
      text: budget?['budget_limit']?.toStringAsFixed(2) ?? '',
    );
    final formKey = GlobalKey<FormState>();

    // Filter out categories that already have budgets in the selected month
    final currentDate = DateTime.now();
    final selectedYearMonth = _selectedMonth ?? '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';

    final availableCategories = _categories.where((category) {
      // If editing existing budget, include its category
      if (budget != null && category['name'] == budget['category']) {
        return true;
      }
      // Check if category already has a budget in this month
      return !_budgets.any((b) => b['category'] == category['name'] && b['year_month'] == selectedYearMonth);
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(budget == null ? 'Create Budget' : 'Edit Budget'),
            if (budget != null && budget['id'] != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDeleteBudget(budget['id'] as int, budget['category'] as String);
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
                items: availableCategories
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
                  budget?['id'] as int?,
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

  Future<void> _propagateNewBudgetToFutureMonths(String category, double amount) async {
    final currentDate = DateTime.now();

    // Generate future months (next 12 months)
    final futureMonths = <String>[];
    for (int i = 1; i <= 12; i++) {
      final date = DateTime(currentDate.year, currentDate.month + i, 1);
      futureMonths.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
    }

    for (var month in futureMonths) {
      // Check if budget already exists for this category and month
      final existing = await DatabaseHelper().getBudgetByCategory(category, month);
      if (existing == null) {
        await DatabaseHelper().addBudget({
          'category': category,
          'type': 'expense',
          'budget_limit': amount,
          'current_month_spent': 0.0,
          'previous_months_spent': 0.0,
          'year_month': month,
          'created_at': currentDate.toIso8601String(),
          'is_active': 1
        });
      }
    }
  }

  Future<void> _updateFutureMonthsBudgets(String category, double amount) async {
    final currentDate = DateTime.now();

    // Generate future months (next 12 months)
    final futureMonths = <String>[];
    for (int i = 1; i <= 12; i++) {
      final date = DateTime(currentDate.year, currentDate.month + i, 1);
      futureMonths.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
    }

    for (var month in futureMonths) {
      final existing = await DatabaseHelper().getBudgetByCategory(category, month);
      if (existing != null) {
        await DatabaseHelper().updateBudget({
          'id': existing['id'],
          'category': existing['category'],
          'type': existing['type'],
          'budget_limit': amount,
          'current_month_spent': existing['current_month_spent'],
          'previous_months_spent': existing['previous_months_spent'],
          'year_month': existing['year_month'],
          'is_active': existing['is_active']
        });
      } else {
        // If no budget exists for this future month, create one
        await DatabaseHelper().addBudget({
          'category': category,
          'type': 'expense',
          'budget_limit': amount,
          'current_month_spent': 0.0,
          'previous_months_spent': 0.0,
          'year_month': month,
          'created_at': currentDate.toIso8601String(),
          'is_active': 1
        });
      }
    }
  }

  Future<void> _deleteFutureMonthsBudgets(String category) async {
    final currentDate = DateTime.now();
    final currentYearMonth = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';

    // Get all future months
    final allMonths = await DatabaseHelper().getBudgetMonths();
    final futureMonths = allMonths.where((m) => m.compareTo(currentYearMonth) > 0).toList();

    for (var month in futureMonths) {
      final existing = await DatabaseHelper().getBudgetByCategory(category, month);
      if (existing != null) {
        await DatabaseHelper().deleteBudget(existing['id'] as int);
      }
    }
  }
}