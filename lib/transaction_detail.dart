import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'database_helper.dart';
import 'app_refresh_notifier.dart';

class TransactionDetailPage extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final ScrollController? scrollController;

  const TransactionDetailPage({
    Key? key,
    required this.transaction,
    this.scrollController,
  }) : super(key: key);

  @override
  _TransactionDetailPageState createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _noteController;
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late DateTime selectedDate;
  late String selectedTransactionType;
  String? selectedAccount;
  String? selectedCategory;
  String? selectedSubcategory;
  String? selectedToAccount;

  List<String> accountTypes = [];
  List<String> categories = [];
  List<String> subcategories = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _fetchDatabaseData();
  }

  void _initializeControllers() {
    _noteController = TextEditingController(text: widget.transaction['note'] ?? '');
    _amountController = TextEditingController(
        text: (widget.transaction['amount'] as num?)?.toStringAsFixed(2) ?? ''
    );

    selectedTransactionType = widget.transaction['type'] ?? 'Expense';

    // Handle transfer case specifically
    if (selectedTransactionType == 'Transfer') {
      selectedAccount = widget.transaction['account'] ?? '';
      selectedToAccount = widget.transaction['to_account'] ?? '';
      selectedCategory = selectedToAccount; // Use to_account as the category for transfers
    } else {
      selectedAccount = widget.transaction['account'] ?? '';
      selectedCategory = widget.transaction['category'] ?? '';
    }

    selectedSubcategory = widget.transaction['subcategory'] ?? '';

    final transactionDate = widget.transaction['date'];
    selectedDate = transactionDate != null && transactionDate.isNotEmpty
        ? _parseDate(transactionDate)
        : DateTime.now();

    _dateController = TextEditingController(text: _formatDate(selectedDate));
  }

  DateTime _parseDate(String dateString) {
    try {
      return DateFormat('dd/MM/yyyy').parse(dateString.split(' ').first);
    } catch (e) {
      return DateTime.now();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _fetchDatabaseData() async {
    try {
      final accounts = await DatabaseHelper.instance.getAccounts();
      setState(() {
        accountTypes = accounts.map((a) => a['name'] as String).toList();
        if (selectedAccount == null || selectedAccount!.isEmpty) {
          selectedAccount = accountTypes.isNotEmpty ? accountTypes.first : null;
        }
      });
      await _fetchCategoriesAndSubcategories();
    } catch (e) {
      _showError('Failed to load accounts: ${e.toString()}');
    }
  }

  Future<void> _fetchCategoriesAndSubcategories() async {
    try {
      if (selectedTransactionType == 'Transfer') {
        final allAccounts = await DatabaseHelper.instance.getAccounts();
        final currentFromAccount = selectedAccount;

        setState(() {
          // Filter out the current "From Account" from the "To Account" options
          categories = allAccounts
              .map((a) => a['name'] as String)
              .where((account) => account != currentFromAccount)
              .toList();

          // Preserve the original "To Account" if it's still valid
          if (selectedToAccount != null && categories.contains(selectedToAccount)) {
            selectedCategory = selectedToAccount;
          } else if (categories.isNotEmpty) {
            // Select first available account if original is no longer valid
            selectedCategory = categories.first;
          } else {
            selectedCategory = null;
          }

          subcategories = [];
        });
      } else {
        final type = selectedTransactionType.toLowerCase();
        final categoryList = await DatabaseHelper.instance.getCategories(type);

        setState(() {
          categories = categoryList.map((c) => c['name'] as String).toList();
          // Try to preserve original category if possible
          if (widget.transaction['category'] != null &&
              categories.contains(widget.transaction['category'])) {
            selectedCategory = widget.transaction['category'];
          } else {
            selectedCategory = categories.isNotEmpty ? categories.first : null;
          }
        });

        if (selectedCategory != null) {
          await _fetchSubcategories();
        }
      }
    } catch (e) {
      _showError('Failed to load data: ${e.toString()}');
    }
  }

  Future<void> _fetchSubcategories() async {
    if (selectedTransactionType == 'Transfer' || selectedCategory == null) {
      setState(() => subcategories = []);
      return;
    }

    try {
      final categories = await DatabaseHelper.instance.getCategories(
          selectedTransactionType.toLowerCase()
      );
      final category = categories.firstWhere(
            (c) => c['name'] == selectedCategory,
        orElse: () => {},
      );

      if (category.isNotEmpty) {
        final subcategoryList = await DatabaseHelper.instance
            .getSubcategoriesByCategoryId(category['id']);

        setState(() {
          subcategories = subcategoryList.map((s) => s['name'] as String).toList();
          selectedSubcategory = subcategories.isNotEmpty ? subcategories.first : null;
        });
      }
    } catch (e) {
      _showError('Failed to load subcategories: ${e.toString()}');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
        _dateController.text = _formatDate(pickedDate);
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy (EEE)').format(date);
  }

  String _formatDateForStorage(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _updateTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final refreshNotifier = Provider.of<AppRefreshNotifier>(context, listen: false);

    if (selectedTransactionType == 'Transfer') {
      await _handleTransfer(refreshNotifier);
      return;
    }

    try {
      final accountId = await DatabaseHelper.instance.getAccountIdByName(selectedAccount!);
      final amount = double.parse(_amountController.text);

      final transaction = {
        'id': widget.transaction['id'],
        'type': selectedTransactionType,
        'date': _formatDateForStorage(selectedDate),
        'account_id': accountId,
        'category': selectedCategory ?? '',
        'subcategory': selectedSubcategory ?? '',
        'amount': amount,
        'note': _noteController.text,
      };

      final original = await DatabaseHelper.instance.getTransactionById(widget.transaction['id']);
      if (original == null) {
        _showError('Original transaction not found');
        return;
      }

      await _adjustAccountBalance(
          original['account_id'],
          original['amount'],
          original['type'],
          reverse: true
      );

      await DatabaseHelper.instance.deleteTransaction(widget.transaction['id']);

      await DatabaseHelper.instance.insertTransaction(transaction);

      await _adjustAccountBalance(
          accountId,
          amount,
          selectedTransactionType
      );

      refreshNotifier.refreshAccounts();
      refreshNotifier.refreshTransactions();
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Failed to update transaction: ${e.toString()}');
    }
  }

  Future<void> _handleTransfer(AppRefreshNotifier refreshNotifier) async {
    if (selectedAccount == null || selectedCategory == null) {
      _showError('Please select both From and To accounts');
      return;
    }

    if (selectedAccount == selectedCategory) {
      _showError('Cannot transfer to the same account');
      return;
    }

    try {
      final fromAccountId = await DatabaseHelper.instance.getAccountIdByName(selectedAccount!);
      final toAccountId = await DatabaseHelper.instance.getAccountIdByName(selectedCategory!);
      final amount = double.parse(_amountController.text);

      final transfer = {
        'id': widget.transaction['id'],
        'type': 'Transfer',
        'date': _formatDateForStorage(selectedDate),
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'amount': amount,
        'note': _noteController.text,
      };

      final original = await DatabaseHelper.instance.getTransactionById(widget.transaction['id']);
      if (original == null) {
        _showError('Original transaction not found');
        return;
      }

      await _revertTransfer(original);

      await DatabaseHelper.instance.deleteTransaction(widget.transaction['id']);

      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        await txn.insert('transactions', transfer);

        final fromAccount = await txn.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [fromAccountId],
        );

        final toAccount = await txn.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [toAccountId],
        );

        final newFromBalance = (fromAccount.first['balance'] as num).toDouble() - amount;
        final newToBalance = (toAccount.first['balance'] as num).toDouble() + amount;

        await txn.update(
          'accounts',
          {'balance': newFromBalance},
          where: 'id = ?',
          whereArgs: [fromAccountId],
        );

        await txn.update(
          'accounts',
          {'balance': newToBalance},
          where: 'id = ?',
          whereArgs: [toAccountId],
        );
      });

      refreshNotifier.refreshAccounts();
      refreshNotifier.refreshTransactions();
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Failed to process transfer: ${e.toString()}');
    }
  }

  Future<void> _revertTransfer(Map<String, dynamic> original) async {
    final fromAccountId = original['from_account_id'];
    final toAccountId = original['to_account_id'];
    final amount = original['amount'];

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final fromAccount = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [fromAccountId],
      );

      final toAccount = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [toAccountId],
      );

      final newFromBalance = (fromAccount.first['balance'] as num).toDouble() + amount;
      final newToBalance = (toAccount.first['balance'] as num).toDouble() - amount;

      await txn.update(
        'accounts',
        {'balance': newFromBalance},
        where: 'id = ?',
        whereArgs: [fromAccountId],
      );

      await txn.update(
        'accounts',
        {'balance': newToBalance},
        where: 'id = ?',
        whereArgs: [toAccountId],
      );
    });
  }

  Future<void> _adjustAccountBalance(
      int accountId,
      double amount,
      String type, {
        bool reverse = false
      }) async {
    final account = await DatabaseHelper.instance.getAccountById(accountId);
    double balanceChange = type == 'Income' ? amount : -amount;
    if (reverse) balanceChange = -balanceChange;
    final newBalance = account['balance'] + balanceChange;
    await DatabaseHelper.instance.updateAccountBalance(accountId, newBalance);
  }

  Future<void> _deleteTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
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
    ) ?? false;

    if (!confirmed) return;

    final refreshNotifier = Provider.of<AppRefreshNotifier>(context, listen: false);

    try {
      final transaction = await DatabaseHelper.instance
          .getTransactionById(widget.transaction['id']);

      if (transaction == null) {
        _showError('Transaction not found');
        return;
      }

      if (transaction['type'] == 'Transfer') {
        await _revertTransfer(transaction);
      } else {
        await _adjustAccountBalance(
            transaction['account_id'],
            transaction['amount'],
            transaction['type'],
            reverse: true
        );
      }

      await DatabaseHelper.instance.deleteTransaction(widget.transaction['id']);
      refreshNotifier.refreshAccounts();
      refreshNotifier.refreshTransactions();
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Failed to delete transaction: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildTypeSelector(String type, Color activeColor) {
    return GestureDetector(
      onTap: () async {
        if (selectedTransactionType != type) {
          setState(() {
            selectedTransactionType = type;
            selectedCategory = null;
            selectedSubcategory = null;
          });
          await _fetchCategoriesAndSubcategories();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selectedTransactionType == type ? activeColor : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          type,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
      String label,
      List<String> items,
      String? value,
      ValueChanged<String?> onChanged,
      ) {
    final isTransfer = selectedTransactionType == 'Transfer';
    final displayLabel = isTransfer
        ? (label == 'Account' ? 'From Account' : 'To Account')
        : label;

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: displayLabel,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: (newValue) {
        if (isTransfer && label == 'Account' && newValue == selectedCategory) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot transfer to the same account')),
          );
          return;
        }
        onChanged(newValue);
        if (label == 'Account' && isTransfer) {
          // When From Account changes, update To Account options
          _fetchCategoriesAndSubcategories();
        } else if (label == 'Category' && !isTransfer && newValue != null) {
          _fetchSubcategories();
        }
      },
      validator: (value) => value == null ? 'Please select $displayLabel' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTypeSelector("Income", Colors.blue),
                    _buildTypeSelector("Expense", Colors.red),
                    _buildTypeSelector("Transfer", Colors.blueGrey),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: "Date",
                        border: OutlineInputBorder(),
                      ),
                      controller: _dateController,
                      validator: (value) => value?.isEmpty ?? true ? 'Please select date' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildDropdown(
                  selectedTransactionType == 'Transfer' ? 'From Account' : 'Account',
                  accountTypes,
                  selectedAccount,
                      (value) {
                    setState(() => selectedAccount = value);
                    if (selectedTransactionType == 'Transfer') {
                      _fetchCategoriesAndSubcategories();
                    }
                  },
                ),
                const SizedBox(height: 20),
                _buildDropdown(
                  selectedTransactionType == 'Transfer' ? 'To Account' : 'Category',
                  categories,
                  selectedCategory,
                      (value) => setState(() => selectedCategory = value),
                ),
                if (subcategories.isNotEmpty && selectedTransactionType != 'Transfer') ...[
                  const SizedBox(height: 20),
                  _buildDropdown(
                    "Subcategory",
                    subcategories,
                    selectedSubcategory,
                        (value) => setState(() => selectedSubcategory = value),
                  ),
                ],
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Amount",
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter amount';
                    if (double.tryParse(value) == null) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: "Note",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: _deleteTransaction,
                        child: const Text(
                          "DELETE",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: _updateTransaction,
                        child: const Text("SAVE"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}