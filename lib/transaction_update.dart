import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'database_helper.dart';
import 'app_refresh_notifier.dart';

class TransactionUpdatePage extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final ScrollController? scrollController;

  const TransactionUpdatePage({
    Key? key,
    required this.transaction,
    this.scrollController,
  }) : super(key: key);

  @override
  _TransactionUpdatePageState createState() => _TransactionUpdatePageState();
}

class _TransactionUpdatePageState extends State<TransactionUpdatePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _noteController;
  late final TextEditingController _amountController;
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
    _initializeData();
    _fetchDatabaseData();
  }

  void _initializeData() {
    _amountController = TextEditingController(
      text: (widget.transaction['amount'] as num?)?.toStringAsFixed(2) ?? '',
    );
    _noteController = TextEditingController(text: widget.transaction['note'] ?? '');

    selectedTransactionType = widget.transaction['type'] ?? 'Expense';

    if (selectedTransactionType == 'Transfer') {
      selectedAccount = widget.transaction['account'] ?? '';
      selectedToAccount = widget.transaction['to_account'] ?? '';
      selectedCategory = selectedToAccount;
    } else {
      selectedAccount = widget.transaction['account'] ?? '';
      selectedCategory = widget.transaction['category'] ?? '';
    }

    selectedSubcategory = widget.transaction['subcategory'] ?? '';

    final transactionDate = widget.transaction['date'];
    selectedDate = transactionDate != null && transactionDate.isNotEmpty
        ? _parseDate(transactionDate)
        : DateTime.now();
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
          categories = allAccounts
              .map((a) => a['name'] as String)
              .where((account) => account != currentFromAccount)
              .toList();

          if (selectedToAccount != null && categories.contains(selectedToAccount)) {
            selectedCategory = selectedToAccount;
          } else if (categories.isNotEmpty) {
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
      });
    }
  }

  String _formatDateForStorage(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _updateTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final refreshNotifier = Provider.of<AppRefreshNotifier>(context, listen: false);

    try {
      if (selectedTransactionType == 'Transfer') {
        // Handle transfer case
        if (selectedAccount == null || selectedCategory == null) {
          _showError('Please select both From and To accounts');
          return;
        }

        if (selectedAccount == selectedCategory) {
          _showError('Cannot transfer to the same account');
          return;
        }

        final fromAccountId = await DatabaseHelper.instance.getAccountIdByName(selectedAccount!);
        final toAccountId = await DatabaseHelper.instance.getAccountIdByName(selectedCategory!);

        await DatabaseHelper.instance.updateTransactionType(
          widget.transaction['id'],
          'Transfer',
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
          category: selectedCategory,
        );
      } else {
        // Handle income/expense case
        final accountId = await DatabaseHelper.instance.getAccountIdByName(selectedAccount!);

        await DatabaseHelper.instance.updateTransactionType(
          widget.transaction['id'],
          selectedTransactionType,
          fromAccountId: accountId,
          category: selectedCategory,
        );
      }

      // Update other transaction details
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'transactions',
        {
          'date': _formatDateForStorage(selectedDate),
          'subcategory': selectedSubcategory ?? '',
          'amount': double.parse(_amountController.text),
          'note': _noteController.text,
        },
        where: 'id = ?',
        whereArgs: [widget.transaction['id']],
      );

      refreshNotifier.refreshAccounts();
      refreshNotifier.refreshTransactions();
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Failed to update transaction: ${e.toString()}');
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

  Widget _buildTypeSelector(String type, Color activeColor) {
    final isSelected = selectedTransactionType == type;
    return GestureDetector(
      onTap: () async {
        if (!isSelected) {
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
          color: isSelected ? activeColor.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          type,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSelected ? activeColor : Colors.black,
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
          _showError('Cannot transfer to the same account');
          return;
        }
        onChanged(newValue);
        if (label == 'Account' && isTransfer) {
          _fetchCategoriesAndSubcategories();
        } else if (label == 'Category' && !isTransfer && newValue != null) {
          _fetchSubcategories();
        }
      },
      validator: (value) => value == null ? 'Please select $displayLabel' : null,
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
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
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
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
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      decoration: const InputDecoration(
        labelText: "Note",
        border: OutlineInputBorder(),
      ),
      maxLines: 1,
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: _deleteTransaction,
              child: const Text(
                "DELETE",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _updateTransaction,
              child: const Text("SAVE"),
            ),
          ),
        ],
      ),
    );
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
                  _buildDateField(),
                  const SizedBox(height: 20),

                  // Account Dropdown
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
                  _buildAmountField(),

                  // Note Field
                  const SizedBox(height: 20),
                  _buildNoteField(),

                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDiscardChanges() async {
    if (_amountController.text == (widget.transaction['amount'] as num?)?.toStringAsFixed(2) &&
        _noteController.text == (widget.transaction['note'] ?? '')) {
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}