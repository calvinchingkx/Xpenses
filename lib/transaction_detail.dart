import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

class TransactionDetailPage extends StatefulWidget {
  final Map<String, dynamic> transaction;

  TransactionDetailPage({required this.transaction});

  @override
  _TransactionDetailPageState createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  final ScrollController scrollController = ScrollController();
  late TextEditingController _noteController;
  late TextEditingController _amountController;
  DateTime selectedDate = DateTime.now();
  String? selectedTransactionType;
  String? selectedAccount;
  String? selectedCategory;
  String? selectedSubcategory;
  late List<String> accountTypes = [];
  late List<String> categories = [];
  late List<String> subcategories = [];

  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.transaction['note']);
    _amountController = TextEditingController(text: widget.transaction['amount'].toString());

    selectedAccount = widget.transaction['account'] ?? '';
    selectedCategory = widget.transaction['category'] ?? '';
    selectedSubcategory = widget.transaction['subcategory'] ?? '';

    String? transactionDate = widget.transaction['date'];
    if (transactionDate != null && transactionDate.isNotEmpty) {
      try {
        selectedDate = DateTime.parse(transactionDate);
      } catch (e) {
        print("Invalid date format: $e");
        selectedDate = DateTime.now();
      }
    } else {
      selectedDate = DateTime.now();
    }

    selectedTransactionType = widget.transaction['type'] ?? 'Expense';

    _fetchDatabaseData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchDatabaseData() async {
    final accountList = await DatabaseHelper.instance.getAccounts();
    setState(() {
      accountTypes = accountList.map((account) => account['name'] as String).toList();
      selectedAccount = accountTypes.isNotEmpty ? accountTypes.first : null;
    });

    _fetchCategoriesAndSubcategories();
  }

  Future<void> _fetchCategoriesAndSubcategories() async {
    final transactionType = selectedTransactionType == 'Income' ? 'income' : 'expense';

    final categoryList = await DatabaseHelper.instance.getCategories(transactionType);
    setState(() {
      categories = categoryList.map((category) => category['name'] as String).toList();
      selectedCategory = categories.isNotEmpty ? categories.first : null;
    });

    _fetchSubcategories();
  }

  Future<void> _fetchSubcategories() async {
    if (selectedCategory == null) {
      setState(() {
        subcategories = [];
        selectedSubcategory = null; // No subcategory if no category selected
      });
      return;
    }

    final selectedCategoryData = await DatabaseHelper.instance.getCategories(selectedTransactionType == 'Income' ? 'income' : 'expense');
    final selectedCategoryId = selectedCategoryData.firstWhere((category) => category['name'] == selectedCategory)['id'];

    final subcategoryList = await DatabaseHelper.instance.getSubcategoriesByCategoryId(selectedCategoryId);
    setState(() {
      subcategories = subcategoryList.isNotEmpty ? subcategoryList.map((subcategory) => subcategory['name'] as String).toList() : [];
      selectedSubcategory = subcategories.isNotEmpty ? subcategories.first : null;
    });
  }

  // Format the date for display
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy (EEE)').format(date);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
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

  void _updateTransaction() async {
    // Validate the required fields
    if (_amountController.text.isEmpty || selectedAccount == null || selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields!')),
      );
      return;
    }

    // Fetch account ID by name
    final selectedAccountId = await DatabaseHelper.instance.getAccountIdByName(selectedAccount!);

    // Prepare the transaction to update
    var updatedTransaction = {
      'id': widget.transaction['id'],  // Ensure transaction ID is passed here
      'type': selectedTransactionType,
      'date': _formatDate(selectedDate),
      'account_id': selectedAccountId,  // Use account ID
      'category': selectedCategory,
      'subcategory': selectedSubcategory ?? 'No Subcategory',  // Handle empty subcategory
      'amount': double.tryParse(_amountController.text) ?? 0.0,
      'note': _noteController.text,
    };

    try {
      // Step 1: Retrieve the existing transaction to delete it and update balance
      if (widget.transaction['id'] != null) {
        final existingTransaction = await DatabaseHelper.instance.getTransactionById(widget.transaction['id']);
        if (existingTransaction == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transaction not found')),
          );
          return;
        }

        final transactionType = existingTransaction['type'] as String?;
        final transactionAmount = existingTransaction['amount'] as double?;

        // Fetch the account ID from the existing transaction
        final accountId = existingTransaction['account_id'] as int?;
        if (accountId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid account ID for the transaction')),
          );
          return;
        }

        // Fetch account data using account_id
        final accountData = await DatabaseHelper.instance.getAccountById(accountId);

        if (accountData.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Account not found for the transaction')),
          );
          return;
        }

        final accountName = accountData['name'] as String?;

        // If any of the values are null, show an error message
        if (accountName == null || transactionType == null || transactionAmount == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid transaction data')),
          );
          return;
        }

        // Retrieve the old account data
        final oldAccountData = await DatabaseHelper.instance.getAccountByName(accountName);

        // Null check for oldAccountData before proceeding
        if (oldAccountData == null || oldAccountData.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Old account data not found')),
          );
          return;
        }

        final oldAccountId = oldAccountData['id'] as int?;
        double oldAccountBalance = oldAccountData['balance'] ?? 0.0; // Safe fallback to 0.0 if null

        // No need to check if transactionAmount is null anymore, since it's always non-null after the assignment
        if (transactionType == 'Income') {
          oldAccountBalance -= transactionAmount; // Decrease the balance if it was an income transaction
        } else if (transactionType == 'Expense') {
          oldAccountBalance += transactionAmount; // Increase the balance if it was an expense transaction
        }

        // Update the account balance after deleting the old transaction
        await DatabaseHelper.instance.updateAccountBalance(oldAccountId ?? 0, oldAccountBalance);

        // Step 2: Delete the old transaction
        int deleteResult = await DatabaseHelper.instance.deleteTransaction(widget.transaction['id']);
        if (deleteResult > 0) {
          print("Old transaction deleted successfully.");
        } else {
          print("Failed to delete old transaction.");
        }
      }

      // Step 3: Insert the new updated transaction
      final result = await DatabaseHelper.instance.insertTransaction(updatedTransaction);
      if (result > 0) {
        print('Updated transaction saved: $result');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction updated successfully!')),
        );
      } else {
        print("Failed to insert updated transaction.");
      }

      // Step 4: Update the account balance after saving the new transaction
      await _updateAccountBalance(
        selectedAccountId,
        updatedTransaction['amount'] as double,
        updatedTransaction['type'] as String,
      );

      // Step 5: Once everything is complete, navigate back to the previous screen
      Navigator.pop(context);  // Go back to the previous screen
    } catch (e) {
      print('Error updating transaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred while updating the transaction.')),
      );
    }
  }


  Future<void> _updateAccountBalance(int accountId, double amount, String transactionType) async {
    double balanceChange = transactionType == 'Income' ? amount : -amount;

    // Fetch the current balance of the selected account
    Map<String, dynamic> account = await DatabaseHelper.instance.getAccount(accountId);

    // Update the balance
    double newBalance = account['balance'] + balanceChange;

    // Update the account balance in the database
    await DatabaseHelper.instance.updateAccountBalance(accountId, newBalance);
  }

  Future<void> _deleteTransaction(int transactionId) async {
    // Retrieve the existing transaction details
    final existingTransaction = await DatabaseHelper.instance.getTransactionById(transactionId);
    print('Fetched Transaction: $existingTransaction');

    if (existingTransaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction not found')),
      );
      return;
    }

    final transactionType = existingTransaction['type'] as String?;
    final transactionAmount = existingTransaction['amount'] as double?;

    // Debug prints for verifying fetched data
    print('Transaction Type: $transactionType');
    print('Transaction Amount: $transactionAmount');

    // Fetch the account name using the account_id
    final accountId = existingTransaction['account_id'] as int?;
    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid account ID for the transaction')),
      );
      return;
    }

    // Fetch account name using account_id
    final accountData = await DatabaseHelper.instance.getAccountById(accountId);

    // Check if accountData is empty instead of null
    if (accountData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account not found for the transaction')),
      );
      return;
    }

    final accountName = accountData['name'] as String?;

    // Debug print for the account name
    print('Account Name: $accountName');

    // If any of the values are null, show an error message
    if (accountName == null || transactionType == null || transactionAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid transaction data')),
      );
      return;
    }

    // Retrieve the old account data
    final oldAccountData = await DatabaseHelper.instance.getAccountByName(accountName);
    // Check if oldAccountData is null or empty
    if (oldAccountData == null || oldAccountData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Old account not found')),
      );
      return;
    }

// Now it's safe to access the properties of oldAccountData
    final oldAccountId = oldAccountData['id'];
    double oldAccountBalance = oldAccountData['balance'] ?? 0.0;


    // Adjust the old account balance based on the transaction type
    if (transactionType == 'Income') {
      oldAccountBalance -= transactionAmount;
    } else if (transactionType == 'Expense') {
      oldAccountBalance += transactionAmount;
    }

    await DatabaseHelper.instance.updateAccountBalance(oldAccountId, oldAccountBalance);

    // Proceed with deleting the transaction
    int deleteResult = await DatabaseHelper.instance.deleteTransaction(transactionId);
    print("Delete result: $deleteResult");

    if (deleteResult > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction deleted successfully')),
      );

      // Close the current screen
      Navigator.pop(context);  // This will close the screen and navigate back
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete the transaction')),
      );
    }
  }

  Future<bool> _showDeleteDialog() async {
    return await showDialog<bool>(context: context, builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this transaction?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      );
    }) ?? false;
  }

  Widget _buildDropdownField(
      String label,
      List<String> items,
      String? selectedItem,
      Function(String) onChanged
      ) {
    // Ensure selectedItem is never null when passed to the DropdownButtonFormField.
    String itemToDisplay = selectedItem ?? ''; // Default to an empty string if null.

    return DropdownButtonFormField<String>(
      value: itemToDisplay.isNotEmpty ? itemToDisplay : null,  // Handle null value
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction Type Buttons (Income, Expense, Transfer)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () async {
                    if (selectedTransactionType != "Income") {
                      setState(() {
                        selectedTransactionType = "Income"; // Update selected type
                      });
                      await _fetchCategoriesAndSubcategories(); // Load income categories
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedTransactionType == "Income" ? Colors.blue : Colors.grey,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Income",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    if (selectedTransactionType != "Expense") {
                      setState(() {
                        selectedTransactionType = "Expense"; // Update selected type
                      });
                      await _fetchCategoriesAndSubcategories(); // Load expense categories
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedTransactionType == "Expense" ? Colors.red : Colors.grey,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Expense",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    if (selectedTransactionType != "Transfer") {
                      setState(() {
                        selectedTransactionType = "Transfer"; // Update selected type
                      });
                      await _fetchCategoriesAndSubcategories(); // Load transfer categories (if any)
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedTransactionType == "Transfer" ? Colors.blueGrey : Colors.grey,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Transfer",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      "Date:",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatDate(selectedDate), // Format the selected date
                      style: TextStyle(fontSize: 16, color: Colors.blueGrey), // Different color for the date
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Account Dropdown
            _buildDropdownField("Account", accountTypes, selectedAccount ?? "", (value) {
              setState(() {
                selectedAccount = value;
              });
            }),
            SizedBox(height: 20),

            // Category Dropdown
            _buildDropdownField("Category", categories, selectedCategory ?? "", (value) {
              setState(() {
                selectedCategory = value;
              });
            }),
            SizedBox(height: 20),

            // Subcategory Dropdown
            _buildDropdownField("Subcategory", subcategories, selectedSubcategory ?? "", (value) {
              setState(() {
                selectedSubcategory = value;
              });
            }),

            SizedBox(height: 20),

            // Amount Text Field
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Amount",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 20),

            // Note Text Field
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: "Note",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 20),

            // Save Button
            ElevatedButton(
              onPressed: _updateTransaction,
              child: Text("Save Transaction"),
            ),
            ElevatedButton(
              onPressed: () async {
                bool confirmDelete = await _showDeleteDialog();
                if (confirmDelete) {
                  await _deleteTransaction(widget.transaction['id']);
                }
              },
              child: Text("Delete Transaction"),
            ),
          ],
        ),
      ),
    );
  }
}
