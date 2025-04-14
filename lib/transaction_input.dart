import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionPage extends StatefulWidget {
  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  String _transactionType = 'Income';
  final List<String> _accountList = ['Cash', 'Card', 'E-wallet', 'Loan'];
  String? _fromAccount;
  String? _toAccount;
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Method to handle date selection
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Transaction'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _transactionType,
              items: ['Income', 'Expense', 'Transfer'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _transactionType = value!;
                });
              },
            ),
            if (_transactionType == 'Transfer') ...[
              DropdownButton<String>(
                hint: Text("From Account"),
                value: _fromAccount,
                items: _accountList.map((String account) {
                  return DropdownMenuItem<String>(
                    value: account,
                    child: Text(account),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _fromAccount = value!;
                  });
                },
              ),
              DropdownButton<String>(
                hint: Text("To Account"),
                value: _toAccount,
                items: _accountList.where((acc) => acc != _fromAccount).map((String account) {
                  return DropdownMenuItem<String>(
                    value: account,
                    child: Text(account),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _toAccount = value!;
                  });
                },
              ),
            ],
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
              ),
              keyboardType: TextInputType.number,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Date: ${DateFormat.yMd().format(_selectedDate)}"),
                TextButton(
                  onPressed: () => _selectDate(context),
                  child: Text('Select Date'),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                // Code to save transaction data, including the transfer handling
                // Implement database save function here
              },
              child: Text('Save Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}
