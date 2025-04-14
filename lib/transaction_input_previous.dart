import 'package:flutter/material.dart';

class TransactionPage1 extends StatefulWidget {
  final ScrollController scrollController;

  const TransactionPage1({Key? key, required this.scrollController}) : super(key: key);

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage1> {
  String selectedTransactionType = "Expense"; // Default selection
  DateTime selectedDate = DateTime.now();
  List<String> accountTypes = ["Cash", "Card", "e-Wallet", "Bank"];
  String? selectedAccount; // Changed to nullable for dropdown
  List<String> categories = ["Food", "Transport", "Utilities"];
  List<String> subcategories = ["Groceries", "Dining Out", "Public Transport"];
  String? selectedCategory;
  String? selectedSubcategory;

  // Controllers for input fields
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction Type Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTransactionTypeButton("Income", Colors.blue),
                _buildTransactionTypeButton("Expense", Colors.red),
                _buildTransactionTypeButton("Transfer", Colors.blueGrey),
              ],
            ),
            SizedBox(height: 8),
            Divider(thickness: 1), // Horizontal line after transaction type

            // Date Section
            SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100, // Aligns the "Date" label
                  child: Text(
                    "Date",
                    style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: Text(
                      "${_formatDate(selectedDate)} (${_getWeekday(selectedDate)})",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Account Section (Dropdown Menu)
            SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 100, // Aligns the label with other fields
                  child: Text(
                    "Account",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 4),
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedAccount,
                    hint: Text("Select Account"), // Hint for dropdown
                    isExpanded: true,
                    onChanged: (value) {
                      setState(() {
                        selectedAccount = value;
                      });
                    },
                    items: accountTypes.map<DropdownMenuItem<String>>((String account) {
                      return DropdownMenuItem<String>(
                        value: account,
                        child: Text(account),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),

            // Category and Subcategory
            SizedBox(height: 4),
            _buildDropdownField("Category", categories, selectedCategory, (value) {
              setState(() {
                selectedCategory = value;
              });
            }),
            SizedBox(height: 4),
            _buildDropdownField("Sub-categ", subcategories, selectedSubcategory, (value) {
              setState(() {
                selectedSubcategory = value;
              });
            }),

            // Amount and Note Sections
            SizedBox(height: 4),
            _buildAlignedNumberInputField("Amount", "Enter amount", amountController),
            SizedBox(height: 4),
            _buildAlignedTextField("Note", "Enter note", noteController),

            // Save Transaction Button
            SizedBox(height: 100), // Extra space before the button
            Center(
              child: ElevatedButton(
                onPressed: _saveTransaction,
                child: Text("Save Transaction"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
            SizedBox(height: 8), // Padding to the bottom
          ],
        ),
      ),
    );
  }

  // Helper to build transaction type button
  Widget _buildTransactionTypeButton(String type, Color borderColor) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTransactionType = type;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selectedTransactionType == type ? borderColor : Colors.grey,
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

  // Helper to build dropdown fields
  Widget _buildDropdownField(String label, List<String> items, String? selectedValue, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 100, // Fixed label width for alignment
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
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Helper to build aligned numeric text fields
  Widget _buildAlignedNumberInputField(String label, String placeholder, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(
          width: 100, // Fixed label width for alignment
          child: Text(
            "$label:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number, // Ensures number-only input
            decoration: InputDecoration(
              hintText: placeholder,
              border: UnderlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  // Helper to build aligned text fields
  Widget _buildAlignedTextField(String label, String placeholder, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(
          width: 100, // Fixed label width for alignment
          child: Text(
            "$label:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: placeholder,
              border: UnderlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  // Method to open date picker
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

  // Method to save the transaction
  void _saveTransaction() {
    // Logic for saving the transaction
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Transaction Saved")),
    );
  }

  // Helper to format date
  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  // Helper to get weekday name
  String _getWeekday(DateTime date) {
    List<String> weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return weekdays[date.weekday - 1];
  }
}
