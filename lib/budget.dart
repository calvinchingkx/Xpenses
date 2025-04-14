import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final budgets = await DatabaseHelper().getBudgets();
      final categories = await DatabaseHelper().getCategories('expense');

      setState(() {
        _budgets = _sortBudgets(budgets.where((b) =>
        b['id'] != null &&
            b['budget_limit'] != null &&
            b['spent'] != null &&
            b['category'] != null).toList());
        _categories = categories;
      });
    } catch (e) {
      _showError('Failed to load data: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
      _refreshController.refreshCompleted();
    }
  }

  List<Map<String, dynamic>> _sortBudgets(List<Map<String, dynamic>> budgets) {
    return List.from(budgets)..sort((a, b) {
      switch (_sortBy) {
        case 'budget_limit':
          final aLimit = (a['budget_limit'] as num).toDouble();
          final bLimit = (b['budget_limit'] as num).toDouble();
          return _sortAscending ? aLimit.compareTo(bLimit) : bLimit.compareTo(aLimit);
        case 'spent':
          final aSpent = (a['spent'] as num).toDouble();
          final bSpent = (b['spent'] as num).toDouble();
          return _sortAscending ? aSpent.compareTo(bSpent) : bSpent.compareTo(aSpent);
        case 'remaining':
          final aRemaining = (a['budget_limit'] as num).toDouble() - (a['spent'] as num).toDouble();
          final bRemaining = (b['budget_limit'] as num).toDouble() - (b['spent'] as num).toDouble();
          return _sortAscending ? aRemaining.compareTo(bRemaining) : bRemaining.compareTo(aRemaining);
        default: // category
          final aCat = a['category']?.toString().toLowerCase() ?? '';
          final bCat = b['category']?.toString().toLowerCase() ?? '';
          return _sortAscending ? aCat.compareTo(bCat) : bCat.compareTo(aCat);
      }
    });
  }

  Future<void> _saveBudget(int? id, String category, double amount) async {
    try {
      if (id == null) {
        await DatabaseHelper().addBudget({
          'category': category,  // Must match the column name
          'type': 'expense',
          'amount': amount,
          'spent': 0.0,
          'created_at': DateTime.now().toIso8601String()
        });
      } else {
        await DatabaseHelper().updateBudget({
          'id': id,
          'category': category,
          'amount': amount
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Overview'),
        actions: [
          PopupMenuButton<String>(
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
              const PopupMenuItem(
                value: 'category',
                child: Text('Sort by Category'),
              ),
              const PopupMenuItem(
                value: 'budget_limit',
                child: Text('Sort by Limit'),
              ),
              const PopupMenuItem(
                value: 'spent',
                child: Text('Sort by Spent'),
              ),
              const PopupMenuItem(
                value: 'remaining',
                child: Text('Sort by Remaining'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading && _budgets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _budgets.isEmpty
          ? Center(
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
      )
          : SmartRefresher(
        controller: _refreshController,
        onRefresh: _loadData,
        child: ListView.builder(
          itemCount: _budgets.length,
          itemBuilder: (context, index) {
            final budget = _budgets[index];
            final limit = (budget['budget_limit'] as num).toDouble();
            final spent = (budget['spent'] as num).toDouble();
            final remaining = limit - spent;
            final percentage = limit > 0 ? (spent / limit) : 0;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                title: Text(budget['category']?.toString() ?? 'Uncategorized'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Limit: \$${limit.toStringAsFixed(2)}'),
                    Text('Spent: \$${spent.toStringAsFixed(2)}'),
                    Text(
                      'Remaining: \$${remaining.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: remaining >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    LinearProgressIndicator(
                      value: (percentage > 1 ? 1 : percentage).toDouble(), // Convert to double
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage > 0.8
                            ? percentage > 1
                            ? Colors.red
                            : Colors.orange
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDeleteBudget(budget['id']),
                ),
                onTap: () => _showBudgetDialog(budget),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBudgetDialog(null),
        child: const Icon(Icons.add),
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
        title: Text(budget == null ? 'Create Budget' : 'Edit Budget'),
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
                    .map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>( // Specify type
                  value: c['name'] as String, // Cast to String
                  child: Text(c['name'] as String), // Cast to String
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
}