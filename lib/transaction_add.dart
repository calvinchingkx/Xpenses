import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'app_refresh_notifier.dart';
import 'database_helper.dart';

class TransactionPage extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback? onDismiss;

  const TransactionPage({
    Key? key,
    required this.scrollController,
    this.onDismiss,
  }) : super(key: key);

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  String selectedTransactionType = "Expense";
  DateTime selectedDate = DateTime.now();
  String? selectedAccount;
  String? selectedCategory;
  String? selectedSubcategory;

  List<String> accountTypes = [];
  List<String> categories = [];
  List<String> subcategories = [];

  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final accounts = await DatabaseHelper.instance.getAccounts();
      setState(() {
        accountTypes = accounts.map((e) => e['name'] as String).toList();
        if (accountTypes.isNotEmpty) selectedAccount = accountTypes.first;
      });
      await _loadCategories(selectedTransactionType.toLowerCase());
    } catch (e) {
      _showError('Failed to load data: ${e.toString()}');
    }
  }

  Future<void> _loadCategories(String type) async {
    try {
      List<Map<String, dynamic>> items = [];

      if (type == 'transfer') {
        final allAccounts = await DatabaseHelper.instance.getAccounts();
        items = allAccounts.where((account) =>
        account['name'] != selectedAccount
        ).toList();
      } else {
        items = await DatabaseHelper.instance.getCategories(type);
      }

      setState(() {
        categories = items.map((e) => e['name'] as String).toList();
        selectedCategory = categories.isNotEmpty ? categories.first : null;
        selectedSubcategory = null;
        subcategories.clear();
      });

      if (selectedCategory != null && type != 'transfer') {
        await _loadSubcategories(selectedCategory!);
      }
    } catch (e) {
      _showError('Failed to load categories: ${e.toString()}');
    }
  }

  Future<void> _loadSubcategories(String categoryName) async {
    try {
      final categoriesFromDb = await DatabaseHelper.instance
          .getCategories(selectedTransactionType.toLowerCase());
      final category = categoriesFromDb.firstWhere(
            (c) => c['name'] == categoryName,
        orElse: () => {'id': -1},
      );

      if (category['id'] != -1) {
        final subcategoriesFromDb = await DatabaseHelper.instance
            .getSubcategoriesByCategoryId(category['id']);
        setState(() {
          subcategories = subcategoriesFromDb.isNotEmpty
              ? subcategoriesFromDb.map((e) => e['name'] as String).toList()
              : [];
          selectedSubcategory = subcategories.isNotEmpty ? subcategories.first : null;
        });
      }
    } catch (e) {
      _showError('Failed to load subcategories: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final refreshNotifier = Provider.of<AppRefreshNotifier>(context, listen: false);

    try {
      if (selectedTransactionType == 'Transfer') {
        await _handleTransfer(refreshNotifier);
      } else {
        await _handleRegularTransaction(refreshNotifier);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onDismiss?.call();
      }
    } catch (e) {
      _showError('Failed to save: ${e.toString()}');
    }
  }

  Future<void> _handleRegularTransaction(AppRefreshNotifier refreshNotifier) async {
    final accountId = await DatabaseHelper.instance.getAccountIdByName(selectedAccount!);
    final amount = double.parse(amountController.text);

    final transaction = {
      'type': selectedTransactionType,
      'date': _formatDate(selectedDate),
      'account_id': accountId,
      'category': selectedCategory ?? '',
      'subcategory': selectedSubcategory ?? '',
      'amount': amount,
      'note': noteController.text,
    };

    await DatabaseHelper.instance.insertTransaction(transaction);
    await _updateAccountBalance(accountId, amount, selectedTransactionType);

    refreshNotifier.refreshAccounts();
    refreshNotifier.refreshTransactions();
  }

  Future<void> _handleTransfer(AppRefreshNotifier refreshNotifier) async {
    if (selectedAccount == null || selectedCategory == null) {
      throw Exception('Please select both accounts');
    }

    final fromAccountId = await DatabaseHelper.instance.getAccountIdByName(selectedAccount!);
    final toAccountId = await DatabaseHelper.instance.getAccountIdByName(selectedCategory!);
    final amount = double.parse(amountController.text);

    final transfer = {
      'type': 'Transfer',
      'date': _formatDate(selectedDate),
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'amount': amount,
      'note': noteController.text,
    };

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.insert('transactions', transfer);

      final fromAccount = (await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [fromAccountId],
      )).first;

      final toAccount = (await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [toAccountId],
      )).first;

      await txn.update(
        'accounts',
        {'balance': (fromAccount['balance'] as num).toDouble() - amount},
        where: 'id = ?',
        whereArgs: [fromAccountId],
      );

      await txn.update(
        'accounts',
        {'balance': (toAccount['balance'] as num).toDouble() + amount},
        where: 'id = ?',
        whereArgs: [toAccountId],
      );
    });

    refreshNotifier.refreshAccounts();
    refreshNotifier.refreshTransactions();
  }

  Future<void> _updateAccountBalance(int accountId, double amount, String type) async {
    final account = await DatabaseHelper.instance.getAccount(accountId);
    final currentBalance = (account['balance'] as num).toDouble();
    final newBalance = type == 'Income'
        ? currentBalance + amount
        : currentBalance - amount;
    await DatabaseHelper.instance.updateAccountBalance(accountId, newBalance);
  }

  String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() => selectedDate = pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscardChanges();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction Type Selector
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTypeSelector("Income", Colors.blue),
                        _buildTypeSelector("Expense", Colors.red),
                        _buildTypeSelector("Transfer", Colors.blueGrey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date Picker
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: "Date",
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        controller: TextEditingController(
                          text: DateFormat('dd/MM/yyyy (EEE)').format(selectedDate),
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Account Dropdown
                  _buildDropdown(
                    selectedTransactionType == 'Transfer' ? 'From Account' : 'Account',
                    accountTypes,
                    selectedAccount,
                        (value) {
                      setState(() => selectedAccount = value);
                      if (selectedTransactionType == 'Transfer') {
                        _loadCategories('transfer');
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Category/To Account Dropdown
                  _buildDropdown(
                    selectedTransactionType == 'Transfer' ? 'To Account' : 'Category',
                    categories,
                    selectedCategory,
                        (value) => setState(() => selectedCategory = value),
                  ),

                  // Subcategory Dropdown (only when available)
                  if (subcategories.isNotEmpty && selectedTransactionType != 'Transfer')
                    Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildDropdown(
                          "Subcategory",
                          subcategories,
                          selectedSubcategory,
                              (value) => setState(() => selectedSubcategory = value),
                        ),
                      ],
                    ),

                  // Amount Field
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Amount",
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (double.tryParse(value) == null) return 'Invalid amount';
                      if (double.parse(value) <= 0) return 'Must be positive';
                      return null;
                    },
                  ),

                  // Note Field
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: "Note",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                  ),

                  // Add extra space at the bottom for the fixed buttons
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),

          // Fixed Save Button at Bottom
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _saveTransaction,
              child: const Text(
                "SAVE TRANSACTION",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDiscardChanges() async {
    if (amountController.text.isEmpty && noteController.text.isEmpty) {
      return true;
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildTypeSelector(String type, Color activeColor) {
    return GestureDetector(
      onTap: () async {
        if (selectedTransactionType != type) {
          setState(() => selectedTransactionType = type);
          await _loadCategories(type.toLowerCase());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selectedTransactionType == type
              ? activeColor.withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
            color: selectedTransactionType == type ? activeColor : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          type,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: selectedTransactionType == type ? activeColor : Colors.black,
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
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: (newValue) {
        if (selectedTransactionType == 'Transfer' &&
            label == 'Account' &&
            newValue == selectedCategory) {
          _showError('Cannot transfer to same account');
          return;
        }
        onChanged(newValue);
      },
      validator: (value) => value == null ? 'Please select $label' : null,
    );
  }
}