import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:provider/provider.dart';
import 'app_refresh_notifier.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class AccountScreen extends StatefulWidget {
  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final RefreshController _refreshController = RefreshController();
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final accounts = await DatabaseHelper.instance.getAccounts();
      if (mounted) {
        setState(() {
          _accounts = accounts;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load accounts: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _refreshController.refreshCompleted();
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadAccounts();
    // Also reset the refresh notifier flag if needed
    Provider.of<AppRefreshNotifier>(context, listen: false).accountRefreshComplete();
  }

  void _addOrEditAccount({Map<String, dynamic>? account}) async {
    final newAccount = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AccountDialog(account: account),
    );

    if (newAccount != null) {
      try {
        if (account == null) {
          await DatabaseHelper.instance.addAccount(newAccount);
        } else {
          newAccount['id'] = account['id'];
          await DatabaseHelper.instance.updateAccount(newAccount);
        }
        // Notify for refresh
        Provider.of<AppRefreshNotifier>(context, listen: false).refreshAccounts();
        _loadAccounts();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save account: ${e.toString()}')),
        );
      }
    }
  }

  void _deleteAccount(int accountId) async {
    try {
      await DatabaseHelper.instance.deleteAccount(accountId);
      // Notify for refresh
      Provider.of<AppRefreshNotifier>(context, listen: false).refreshAccounts();
      _loadAccounts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: ${e.toString()}')),
      );
    }
  }

  double _calculateTotalBalance() {
    return _accounts.fold(0.0, (sum, account) => sum + (account['balance'] as num).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppRefreshNotifier>(
      builder: (context, refreshNotifier, _) {
        // Handle refresh notifications
        if (refreshNotifier.shouldRefreshAccounts) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadAccounts();
            refreshNotifier.accountRefreshComplete();
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Manage Accounts'),
            centerTitle: true,
          ),
          body: SmartRefresher(
            controller: _refreshController,
            onRefresh: _onRefresh,
            enablePullDown: true,
            enablePullUp: false,
            header: ClassicHeader(
              completeText: 'Refresh completed',
              refreshingText: 'Refreshing...',
              idleText: 'Pull down to refresh',
              releaseText: 'Release to refresh',
            ),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Total Balance: \$${_calculateTotalBalance().toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
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
                    childCount: _accounts.length,
                  ),
                ),
                if (_isLoading)
                  SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addOrEditAccount(),
            child: Icon(Icons.add),
            tooltip: 'Add New Account',
          ),
        );
      },
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