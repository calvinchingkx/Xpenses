import 'package:flutter/material.dart';
import 'database_helper.dart'; // Import the DatabaseHelper class

class AccountScreen extends StatefulWidget {
  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  // Load accounts from the database
  void _loadAccounts() async {
    final accounts = await DatabaseHelper.instance.getAccounts();
    if (mounted) {
      setState(() {
        _accounts = accounts;
      });
    }
  }

  // Add or edit an account
  void _addOrEditAccount({Map<String, dynamic>? account}) async {
    final newAccount = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AccountDialog(account: account),
    );

    if (newAccount != null) {
      if (account == null) {
        // Add new account to the database
        await DatabaseHelper.instance.addAccount(newAccount);
      } else {
        // Edit existing account in the database
        newAccount['id'] = account['id'];
        await DatabaseHelper.instance.updateAccount(newAccount);
      }
      // After adding or updating the account
      print('Account added/updated successfully');
      _loadAccounts(); // Reload accounts after adding or editing

    }
  }

  // Delete an account
  void _deleteAccount(int accountId) async {
    await DatabaseHelper.instance.deleteAccount(accountId);
    _loadAccounts(); // Reload accounts after deletion
  }

  // Calculate the total balance
  double _calculateTotalBalance() {
    return _accounts.fold(0.0, (sum, account) => sum + account['balance']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Accounts'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Total Balance: \$${_calculateTotalBalance().toStringAsFixed(2)}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _accounts.length,
              itemBuilder: (context, index) {
                final account = _accounts[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(account['name']),
                    subtitle: Text('Type: ${account['accountType']}'),
                    trailing: Text(
                      '\$${account['balance'].toStringAsFixed(2)}',
                      style: TextStyle(
                        color: account['balance'] < 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => _addOrEditAccount(account: account),
                    onLongPress: () => _deleteAccount(account['id']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditAccount(),
        child: Icon(Icons.add),
        tooltip: 'Add New Account',
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  final Map<String, dynamic>? account;
  _AccountDialog({this.account});

  @override
  _AccountDialogState createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  String _accountType = 'Cash';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?['accountName'] ?? '');
    _balanceController = TextEditingController(
        text: widget.account?['balance']?.toString() ?? '');
    _accountType = widget.account?['accountType'] ?? 'Cash';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.account == null ? 'Add Account' : 'Edit Account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: 'Account Name'),
          ),
          TextField(
            controller: _balanceController,
            decoration: InputDecoration(labelText: 'Starting Balance'),
            keyboardType: TextInputType.number,
          ),
          DropdownButtonFormField<String>(
            value: _accountType,
            items: ['Cash', 'Card', 'E-Wallet', 'Loan']
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _accountType = value!;
              });
            },
            decoration: InputDecoration(labelText: 'Account Type'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Account name cannot be empty')),
              );
              return;
            }
            if (double.tryParse(_balanceController.text) == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invalid balance value')),
              );
              return;
            }

            final newAccount = {
              'name': _nameController.text,
              'accountType': _accountType,
              'balance': double.tryParse(_balanceController.text) ?? 0.0,
            };
            Navigator.pop(context, newAccount);
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}
