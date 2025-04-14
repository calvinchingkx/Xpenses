import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'app_refresh_notifier.dart';
import 'database_helper.dart';

class TransactionPage extends StatefulWidget {
  final ScrollController scrollController;
  const TransactionPage({Key? key, required this.scrollController}) : super(key: key);

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
  final _formKey = GlobalKey<FormState>(); // Added form validation

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
        // For transfers, get all accounts except the currently selected one
        final allAccounts = await DatabaseHelper.instance.getAccounts();
        items = allAccounts.where((account) =>
        account['name'] != selectedAccount
        ).toList();
      } else {
        // For income/expense, get categories of the selected type
        items = await DatabaseHelper.instance.getCategories(type);
      }

      setState(() {
        categories = items.map((e) => e['name'] as String).toList();
        selectedCategory = categories.isNotEmpty ? categories.first : null;
        selectedSubcategory = null;
        subcategories.clear();
      });

      // Only load subcategories for non-transfer types
      if (selectedCategory != null && type != 'transfer') {
        await _loadSubcategories(selectedCategory!);
      }
    } catch (e) {
      _showError('Failed to load data: ${e.toString()}');
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
              : ['No Subcategory'];
          if (subcategories.isNotEmpty) selectedSubcategory = subcategories.first;
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

    if (selectedTransactionType == 'Transfer') {
      await _handleTransfer(refreshNotifier);
      return;
    }

    try {
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

      final result = await DatabaseHelper.instance.insertTransaction(transaction);
      if (result > 0) {
        await _updateAccountBalance(accountId, amount, selectedTransactionType);

        // Notify for both accounts and transactions refresh
        refreshNotifier.refreshAccounts();
        refreshNotifier.refreshTransactions();

        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _showError('Failed to save transaction: ${e.toString()}');
    }
  }

  // Update the _updateAccountBalance method to handle type casting properly
  Future<void> _updateAccountBalance(int accountId, double amount, String transactionType) async {
    final balanceChange = transactionType == 'Income' ? amount : -amount;
    final account = await DatabaseHelper.instance.getAccount(accountId);
    final currentBalance = (account['balance'] as num).toDouble(); // Ensure we get a double
    final newBalance = currentBalance + balanceChange;
    await DatabaseHelper.instance.updateAccountBalance(accountId, newBalance);
  }

  // Add this new method for handling transfers
  Future<void> _handleTransfer(AppRefreshNotifier refreshNotifier) async {
    if (!_formKey.currentState!.validate()) return;

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

      // Notify for both accounts refresh
      refreshNotifier.refreshAccounts();
      refreshNotifier.refreshTransactions();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Failed to process transfer: ${e.toString()}');
    }
  }

  String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy (EEE)').format(date);

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

  Widget _buildTypeSelector(String type, Color activeColor) {
    return GestureDetector(
      onTap: () async {
        if (selectedTransactionType != type) {
          setState(() {
            selectedTransactionType = type;
            // Reset account selection when switching to transfer
            if (type == 'Transfer') {
              selectedCategory = null;
            }
          });
          await _loadCategories(type.toLowerCase());
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
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
    final displayLabel = isTransfer && label == 'Category' ? 'To Account' : label;

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: displayLabel,
        border: OutlineInputBorder(),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: (newValue) {
        if (isTransfer && label == 'Account' && newValue == selectedCategory) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot transfer to the same account')),
          );
          return;
        }
        onChanged(newValue);
      },
      validator: (value) => value == null ? 'Please select $displayLabel' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.all(20),
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
            SizedBox(height: 20),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: "Date",
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: _formatDate(selectedDate)),
                ),
              ),
            ),
            SizedBox(height: 20),
            _buildDropdown("Account", accountTypes, selectedAccount, (value) {
              setState(() => selectedAccount = value);
            }),
            SizedBox(height: 20),
            _buildDropdown("Category", categories, selectedCategory, (value) {
              setState(() {
                selectedCategory = value;
                if (value != null) _loadSubcategories(value);
              });
            }),
            if (subcategories.isNotEmpty) ...[
              SizedBox(height: 20),
              _buildDropdown("Subcategory", subcategories, selectedSubcategory,
                      (value) => setState(() => selectedSubcategory = value)),
            ],
            SizedBox(height: 20),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
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
            SizedBox(height: 20),
            TextFormField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: "Note",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveTransaction,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Text("SAVE TRANSACTION"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RefreshNotifier extends ChangeNotifier {
  void refreshData() {
    notifyListeners();
  }
}