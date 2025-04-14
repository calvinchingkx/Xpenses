import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // To format the date
import 'database_helper.dart'; // Assuming you have your DatabaseHelper in this file

class TransactionPage extends StatefulWidget {
  final ScrollController scrollController;
  const TransactionPage({Key? key, required this.scrollController}) : super(key: key);

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  String selectedTransactionType = "Expense"; // Default selection
  DateTime selectedDate = DateTime.now();
  String? selectedAccount;
  String? selectedCategory;
  String? selectedSubcategory;

  List<String> accountTypes = []; // Loaded from DB
  List<String> categories = []; // Loaded dynamically based on type
  List<String> subcategories = []; // Loaded dynamically based on category

  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData(); // Load accounts and categories when the page is first created
  }

  void _loadData() async {
    // Load accounts first
    accountTypes = await DatabaseHelper.instance
        .getAccounts()
        .then((accounts) => accounts.map((e) => e['name'] as String).toList());

    // After loading accounts, load categories
    await _loadCategories("expense");  // Set a default category type for the initial load
  }

  // Fetch categories based on transaction type
  Future<void> _loadCategories(String type) async {
    try {
      final categoriesFromDb = await DatabaseHelper.instance.getCategories(type.toLowerCase());
      print('Categories fetched from DB for $type: $categoriesFromDb');

      if (categoriesFromDb.isEmpty) {
        print('No categories found for type: $type');
      }

      categories = categoriesFromDb.map((e) => e['name'] as String).toList();
      selectedCategory = null;
      selectedSubcategory = null;
      subcategories.clear();

      setState(() {});
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  // Load subcategories based on the selected category
  void _loadSubcategories(String? categoryName) async {
    if (categoryName != null) {
      // Fetch category ID based on name
      final categoriesFromDb = await DatabaseHelper.instance.getCategories(selectedTransactionType);
      final selectedCategoryId = categoriesFromDb.firstWhere((category) => category['name'] == categoryName)['id'];

      // Fetch subcategories for the selected category ID
      final subcategoriesFromDb = await DatabaseHelper.instance.getSubcategoriesByCategoryId(selectedCategoryId);

      // Check if subcategories are empty or null, and add a default option if necessary
      if (subcategoriesFromDb.isEmpty) {
        subcategories = ['No Subcategory'];  // Default option
      } else {
        subcategories = subcategoriesFromDb.map((e) => e['name'] as String).toList();
      }
      selectedSubcategory = null; // Reset selected subcategory
      setState(() {}); // Refresh the UI
    }
  }

  // Save transaction
  void _saveTransaction() async {
    if (amountController.text.isEmpty || selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields!')),
      );
      return;
    }

    if (selectedAccount != null && selectedCategory != null) {
      // Fetch account ID by name
      final selectedAccountId = await DatabaseHelper.instance.getAccountIdByName(selectedAccount!);


      var transaction = {
        'type': selectedTransactionType,
        'date': _formatDate(selectedDate),
        'account_id': selectedAccountId,  // Use the account ID, not the name
        'category': selectedCategory,
        'subcategory': selectedSubcategory,
        'amount': double.tryParse(amountController.text) ?? 0.0,
        'note': noteController.text,
      };

      // Insert transaction into the database
      final result = await DatabaseHelper.instance.insertTransaction(transaction);
      print('Transaction saved: $result');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction saved successfully!')),
      );


      // Update account balance
      await _updateAccountBalance(
        selectedAccountId,
        transaction['amount'] as double,  // Ensure it's treated as a double
        transaction['type'] as String,    // Ensure it's treated as a String
      );

      // Reload the dashboard or show confirmation
      setState(() {
        // Update UI or show a snackbar
      });

      // Optionally, close the page or navigate back
      Navigator.pop(context);
    }
  }

  // Method to update the account balance
  Future<void> _updateAccountBalance(int accountId, double amount, String transactionType) async {
    double balanceChange = transactionType == 'Income' ? amount : -amount;

    // Fetch the current balance of the selected account
    Map<String, dynamic> account = await DatabaseHelper.instance.getAccount(accountId);

    // Update the balance
    double newBalance = account['balance'] + balanceChange;

    // Update the account balance in the database
    await DatabaseHelper.instance.updateAccountBalance(accountId, newBalance);
  }

  // Format date helper
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy (EEE)').format(date);
  }

  // Date picker
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

  // Build dropdown field
  Widget _buildDropdownField(String label, List<String> items, String? selectedValue, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            "$label:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: DropdownButton<String>(
            value: selectedValue,
            isExpanded: true,
            hint: Text("Select $label"),
            onChanged: onChanged,
            items: items.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction Type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () async {
                    if (selectedTransactionType != "Income") {
                      setState(() {
                        selectedTransactionType = "Income";  // Update selected type
                      });
                      await _loadCategories("income");  // Load income categories
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
                        selectedTransactionType = "Expense";  // Update selected type
                      });
                      await _loadCategories("expense");  // Load expense categories
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
                        selectedTransactionType = "Transfer";  // Update selected type
                      });
                      await _loadCategories("transfer");  // Load transfer categories (if any)
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

            // Date
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


            // Account
            SizedBox(height: 20),
            _buildDropdownField("Account", accountTypes, selectedAccount, (newAccount) {
              setState(() {
                selectedAccount = newAccount;
              });
            }),

            // Category
            SizedBox(height: 20),
            _buildDropdownField("Category", categories, selectedCategory, (newCategory) {
              setState(() {
                selectedCategory = newCategory;
                _loadSubcategories(newCategory);
              });
            }),

            // Subcategory (if any)
            if (subcategories.isNotEmpty) ...[
              SizedBox(height: 20),
              _buildDropdownField("Subcategory", subcategories, selectedSubcategory, (newSubcategory) {
                setState(() {
                  selectedSubcategory = newSubcategory;
                });
              }),
            ],

            // Amount
            SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    "Amount:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "Enter amount",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            // Note
            SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    "Note:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      hintText: "Enter note",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            // Save Button
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveTransaction,
              child: Text("Save Transaction"),
            ),
          ],
        ),
      ),
    );
  }
}
