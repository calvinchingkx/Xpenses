import 'package:flutter/material.dart';
import 'database_helper.dart'; // Import the DatabaseHelper

class BudgetScreen extends StatefulWidget {
  @override
  _BudgetScreenState createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
    _loadCategories();
  }

  Future<void> _loadBudgets() async {
    setState(() {
      _isLoading = true;
    });
    List<Map<String, dynamic>> budgets = await DatabaseHelper().getBudgets();
    setState(() {
      _budgets = budgets;
      _isLoading = false;
    });
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });
    List<Map<String, dynamic>> categories = await DatabaseHelper().getCategories('expense');
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  Future<void> _addBudget(String category, double amount) async {
    if (category.isEmpty || amount <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a category and enter a valid amount')),
      );
      return;
    }

    await DatabaseHelper().addBudget(category, 'expense', amount);

    // Reload the budgets to reflect the new addition
    _loadBudgets();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Budget Overview'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _budgets.length,
        itemBuilder: (context, index) {
          var budget = _budgets[index];
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              title: Text(budget['category']),
              subtitle: Text('Limit: \$${budget['limit']}'),
              trailing: Text('Spent: \$${budget['spent']}'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddBudgetDialog();
        },
        child: Icon(Icons.add),
      ),
    );
  }

  // Show a dialog to create a new budget
  void _showAddBudgetDialog() {
    String? _selectedCategory;
    double _categoryLimit = 0.0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create New Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                hint: Text('Select Category'),
                value: _selectedCategory,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category['name'],
                    child: Text(category['name']),
                  );
                }).toList(),
              ),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Enter Budget Limit',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _categoryLimit = double.tryParse(value) ?? 0.0;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_selectedCategory != null && _categoryLimit > 0.0) {
                  _addBudget(_selectedCategory!, _categoryLimit);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a category and enter a valid amount')));
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }
}