import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:provider/provider.dart';
import 'app_refresh_notifier.dart';
import 'database_helper.dart';
import 'account_transaction_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final RefreshController _refreshController = RefreshController();
  final List<String> _customSortOrder = [
    'Cash',
    'Credit Card',
    'Debit Card',
    'E-Wallet',
    'Fixed Deposit',
    'Loan',
    'Other'
  ];

  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = false;
  bool _isDeleting = false;
  bool _isReorderable = false;
  String _sortBy = 'custom';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final accounts = await DatabaseHelper.instance.getAccounts();
      final validatedAccounts = accounts.map((account) => {
        ...account,
        'balance': (account['balance'] as num?)?.toDouble() ?? 0.0,
      }).toList();

      if (mounted) {
        setState(() => _accounts = _sortAccounts(validatedAccounts));
      }

      // Add verification step
      await _verifyAccountBalances();
      // Reload after verification if needed
      if (mounted) {
        final refreshedAccounts = await DatabaseHelper.instance.getAccounts();
        setState(() => _accounts = _sortAccounts(refreshedAccounts));
      }
    } catch (e) {
      if (mounted) _showError('Failed to load accounts: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _refreshController.refreshCompleted();
      }
    }
  }

  List<Map<String, dynamic>> _sortAccounts(List<Map<String, dynamic>> accounts) {
    if (_isReorderable) return List.from(accounts);

    return List.from(accounts)..sort((a, b) {
      String getValue(String key, Map<String, dynamic> item) =>
          item[key]?.toString().toLowerCase() ?? '';

      double getBalance(Map<String, dynamic> item) =>
          (item['balance'] as num?)?.toDouble() ?? 0.0;

      switch (_sortBy) {
        case 'custom':
          final aType = getValue('accountType', a);
          final bType = getValue('accountType', b);
          final aIndex = _customSortOrder.indexOf(aType);
          final bIndex = _customSortOrder.indexOf(bType);

          if (aIndex != -1 && bIndex != -1) {
            return _sortAscending ? aIndex.compareTo(bIndex) : bIndex.compareTo(aIndex);
          }
          return getValue('name', a).compareTo(getValue('name', b));

        case 'balance':
          final comparison = getBalance(a).compareTo(getBalance(b));
          return _sortAscending ? comparison : -comparison;

        default:
          final comparison = getValue(_sortBy, a).compareTo(getValue(_sortBy, b));
          return _sortAscending ? comparison : -comparison;
      }
    });
  }

  Future<void> _onRefresh() async {
    try {
      await _loadAccounts();
      if (mounted) {
        Provider.of<AppRefreshNotifier>(context, listen: false).accountRefreshComplete();
      }
    } catch (e) {
      if (mounted) {
        _refreshController.refreshFailed();
        _showError('Refresh failed: ${e.toString()}');
      }
    }
  }

  void _navigateToAccountTransactions(Map<String, dynamic> account) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountTransactionScreen(
          accountId: account['id'] as int,
          accountName: account['name']?.toString() ?? 'Account',
        ),
      ),
    );
  }

  Future<void> _saveCustomOrder() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final updates = _accounts.asMap().entries.map((e) =>
          DatabaseHelper.instance.updateAccount({
            'id': e.value['id'],
            'sortOrder': e.key,
          })
      );

      await Future.wait(updates);
      setState(() => _isReorderable = false);
    } catch (e) {
      _showError('Failed to save order: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addOrEditAccount({Map<String, dynamic>? account}) async {
    final newAccount = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AccountDialog(account: account),
    );

    if (newAccount == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final accountData = {
        'name': newAccount['name']?.toString() ?? '',
        'accountType': newAccount['accountType']?.toString() ?? 'Cash',
        'balance': (newAccount['balance'] as num?)?.toDouble() ?? 0.0,
      };

      if (account == null) {
        final id = await DatabaseHelper.instance.addAccount(accountData);
        if (id != -1) {
          setState(() => _accounts.insert(0, {...accountData, 'id': id}));
        }
      } else {
        accountData['id'] = account['id'];
        await DatabaseHelper.instance.updateAccount(accountData);
        setState(() {
          final index = _accounts.indexWhere((a) => a['id'] == account['id']);
          if (index != -1) {
            _accounts = List.from(_accounts)..[index] = accountData;
            _accounts = _sortAccounts(_accounts);
          }
        });
      }

      Provider.of<AppRefreshNotifier>(context, listen: false).refreshAccounts();
    } catch (e) {
      _showError('Failed to save account: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount(int accountId) async {
    if (_isDeleting) return;

    setState(() => _isDeleting = true);
    try {
      await DatabaseHelper.instance.deleteAccount(accountId);
      if (mounted) {
        setState(() => _accounts = List.from(_accounts)..removeWhere((a) => a['id'] == accountId));
      }
      Provider.of<AppRefreshNotifier>(context, listen: false).refreshAccounts();
    } catch (e) {
      _showError('Failed to delete account: ${e.toString()}');
      _loadAccounts();
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _verifyAccountBalances() async {
    for (final account in _accounts) {
      await _verifySingleAccountBalance(account['id'] as int);
    }
  }

  Future<void> _verifySingleAccountBalance(int accountId) async {
    try {
      final dbHelper = DatabaseHelper.instance;

      // Get stored balance
      final storedBalance = await dbHelper.getAccountBalance(accountId);

      // Calculate balance from transactions
      final calculatedBalance = await dbHelper.calculateAccountBalance(accountId);

      // Correct if discrepancy found
      if (calculatedBalance != storedBalance) {
        await dbHelper.forceUpdateAccountBalance(accountId, calculatedBalance);
      }
    } catch (e) {
      debugPrint('Error verifying account $accountId: $e');
    }
  }

  double _calculateTotalBalance() {
    return _accounts.fold(0.0, (sum, account) =>
    sum + ((account['balance'] as num?)?.toDouble() ?? 0.0));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppRefreshNotifier>(
      builder: (context, refreshNotifier, _) {
        if (refreshNotifier.shouldRefreshAccounts) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadAccounts();
            refreshNotifier.accountRefreshComplete();
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Accounts'),
            centerTitle: true,
            actions: [_buildSortMenu()],
          ),
          body: Column(
            children: [
              _buildTotalBalanceCard(),
              const Divider(height: 1),
              Expanded(child: _buildRefreshableList()),
            ],
          ),
          floatingActionButton: _isReorderable
              ? FloatingActionButton(
            onPressed: _saveCustomOrder,
            child: const Icon(Icons.save),
            tooltip: 'Save Order',
          )
              : FloatingActionButton(
            onPressed: () => _addOrEditAccount(),
            child: const Icon(Icons.add),
            tooltip: 'Add New Account',
          ),
        );
      },
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      onSelected: (value) => setState(() {
        if (value == 'reorder') {
          _isReorderable = !_isReorderable;
          if (!_isReorderable) _saveCustomOrder();
        } else {
          _isReorderable = false;
          if (value == _sortBy) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = true;
          }
        }
        _accounts = _sortAccounts(_accounts);
      }),
      itemBuilder: (context) => [
        _buildSortMenuItem('custom', 'Sort by Default'),
        _buildSortMenuItem('name', 'Sort by Name'),
        _buildSortMenuItem('accountType', 'Sort by Type'),
        _buildSortMenuItem('balance', 'Sort by Balance'),
        PopupMenuItem<String>(
          value: 'reorder',
          child: Row(
            children: [
              const SizedBox(width: 26),
              if (_isReorderable) const Icon(Icons.check, size: 18),
              const SizedBox(width: 8),
              const Text('Custom Reorder Mode'),
            ],
          ),
        ),
      ],
      icon: const Icon(Icons.sort),
    );
  }

  PopupMenuEntry<String> _buildSortMenuItem(String value, String text) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: _sortBy == value
                ? Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18,
            )
                : null,
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildTotalBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Balance:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            '\$${_calculateTotalBalance().toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshableList() {
    return SmartRefresher(
      controller: _refreshController,
      onRefresh: _onRefresh,
      enablePullDown: true,
      enablePullUp: false,
      header: const ClassicHeader(
        completeText: 'Refresh completed',
        refreshingText: 'Refreshing...',
        idleText: 'Pull down to refresh',
        releaseText: 'Release to refresh',
      ),
      child: _buildAccountsList(),
    );
  }

  Widget _buildAccountsList() {
    if (_isLoading && _accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Accounts Found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            TextButton(
              onPressed: () => _addOrEditAccount(),
              child: const Text('Add Your First Account'),
            ),
          ],
        ),
      );
    }

    return _isReorderable
        ? _buildReorderableList()
        : _buildRegularList();
  }

  Widget _buildReorderableList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _accounts.length,
      onReorder: (oldIndex, newIndex) => setState(() {
        if (oldIndex < newIndex) newIndex--;
        final item = _accounts.removeAt(oldIndex);
        _accounts.insert(newIndex, item);
      }),
      itemBuilder: (context, index) => _buildAccountCard(_accounts[index], index),
    );
  }

  Widget _buildRegularList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _accounts.length,
      itemBuilder: (context, index) => _buildAccountCard(_accounts[index], index),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account, int index) {
    final balance = (account['balance'] as num?)?.toDouble() ?? 0.0;
    final accountName = account['name']?.toString() ?? 'Unnamed Account';
    final accountType = account['accountType']?.toString() ?? 'Unknown Type';
    final isNegative = balance < 0;
    final isProcessing = _isLoading &&
        (_isDeleting || _accounts.indexWhere((a) => a['id'] == account['id']) != -1);

    return Card(
      key: Key('account_${account['id']}'),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: InkWell(
        onTap: isProcessing ? null : () => _navigateToAccountTransactions(account),
        onLongPress: _isReorderable ? null : () => _showAccountOptions(account),
        child: Stack(
          children: [
            ListTile(
              leading: _isReorderable
                  ? ReorderableDragStartListener(
                index: index,
                child: CircleAvatar(
                  backgroundColor: _getAccountColor(accountType),
                  child: const Icon(Icons.drag_handle, color: Colors.white),
                ),
              )
                  : CircleAvatar(
                backgroundColor: _getAccountColor(accountType),
                child: Icon(_getAccountIcon(accountType), color: Colors.white),
              ),
              title: Text(accountName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(accountType),
              trailing: Text(
                '\$${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isNegative ? Colors.red : Colors.green[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAccountOptions(Map<String, dynamic> account) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Account'),
              onTap: () {
                Navigator.pop(context);
                _addOrEditAccount(account: account);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final shouldDelete = await _confirmAccountDeletion();
                if (shouldDelete ?? false) {
                  await _deleteAccount(account['id'] as int);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmAccountDeletion() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete this account?'),
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
    );
  }

  Color _getAccountColor(String type) {
    return const {
      'Cash': Colors.blue,
      'Credit Card': Colors.purple,
      'Debit Card': Colors.indigo,
      'E-Wallet': Colors.orange,
      'Fixed Deposit': Colors.teal,
      'Loan': Colors.red,
      'Other': Colors.grey,
    }[type] ?? Colors.grey;
  }

  IconData _getAccountIcon(String type) {
    return const {
      'Cash': Icons.attach_money,
      'Credit Card': Icons.credit_card,
      'Debit Card': Icons.payment,
      'E-Wallet': Icons.account_balance_wallet,
      'Fixed Deposit': Icons.lock_clock,
      'Loan': Icons.money_off,
      'Other': Icons.account_balance,
    }[type] ?? Icons.account_balance;
  }
}

class AccountDialog extends StatefulWidget {
  final Map<String, dynamic>? account;
  const AccountDialog({Key? key, this.account}) : super(key: key);

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late String _accountType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?['name'] ?? '');
    _balanceController = TextEditingController(
      text: (widget.account?['balance'] as num?)?.toStringAsFixed(2) ?? '0.00',
    );
    _accountType = widget.account?['accountType']?.toString() ?? 'Cash';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.account == null ? 'Add Account' : 'Edit Account'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Account Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter account name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(
                  labelText: 'Balance',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter balance';
                  if (double.tryParse(value!) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _accountType,
                decoration: const InputDecoration(
                  labelText: 'Account Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'Cash',
                  'Credit Card',
                  'Debit Card',
                  'E-Wallet',
                  'Fixed Deposit',
                  'Loan',
                  'Other'
                ].map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                ))
                    .toList(),
                onChanged: (value) => setState(() => _accountType = value ?? 'Cash'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'accountType': _accountType,
                'balance': double.tryParse(_balanceController.text) ?? 0.0,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}