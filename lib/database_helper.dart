import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  static DatabaseHelper get instance => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'budget.db');

    // Delete the database if it exists
    //await deleteDatabase(path);

    // Create a new database from scratch without versioning
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Creating the necessary tables in the database
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      balance REAL DEFAULT 0.0,
      accountType TEXT DEFAULT 'Cash',
      color INTEGER DEFAULT 0xFF2196F3,
      isArchived INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      date TEXT NOT NULL,
      account_id INTEGER,
      from_account_id INTEGER,
      to_account_id INTEGER,
      category TEXT,
      subcategory TEXT DEFAULT 'No Subcategory',
      amount REAL NOT NULL,
      note TEXT,
      isRecurring INTEGER DEFAULT 0,
      recurrencePattern TEXT,
      FOREIGN KEY(account_id) REFERENCES accounts(id),
      FOREIGN KEY(from_account_id) REFERENCES accounts(id),
      FOREIGN KEY(to_account_id) REFERENCES accounts(id)
    )''');

    await db.execute('''CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      iconCode INTEGER DEFAULT 0,
      color INTEGER DEFAULT 0xFF2196F3
    )''');

    await db.execute('''CREATE TABLE subcategories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category_id INTEGER,
      FOREIGN KEY(category_id) REFERENCES categories(id)
    )''');

    await db.execute('''CREATE TABLE budgets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category TEXT NOT NULL,
      type TEXT NOT NULL,
      budget_limit REAL NOT NULL,
      current_month_spent REAL DEFAULT 0.0,
      previous_months_spent REAL DEFAULT 0.0,
      year_month TEXT NOT NULL,
      created_at TEXT,
      is_active INTEGER DEFAULT 1
    )''');

    await db.execute('''CREATE TABLE goals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      target_amount REAL NOT NULL,
      saved_amount REAL DEFAULT 0.0,
      target_date TEXT,
      created_at TEXT,
      account_id INTEGER,
      FOREIGN KEY(account_id) REFERENCES accounts(id)
    )''');
  }

  //Account Operations
  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await database;
    return await db.query('accounts');
  }

  Future<Map<String, dynamic>> getAccount(int accountId) async {
    final db = await database; // Get database instance

    // Assuming you have an 'accounts' table in your database
    List<Map<String, dynamic>> result = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [accountId],
    );

    if (result.isNotEmpty) {
      return result.first; // Return the first account found
    } else {
      throw Exception('Account not found');
    }
  }

  Future<double> getAccountBalance(int accountId) async {
    final db = await database;
    final result = await db.query(
      'accounts',
      columns: ['balance'],
      where: 'id = ?',
      whereArgs: [accountId],
    );
    if (result.isEmpty) throw Exception('Account not found');
    return (result.first['balance'] as num).toDouble();
  }

  Future<Map<String, dynamic>> getAccountById(int accountId) async {
    final db = await database;
    final result = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [accountId],
    );

    if (result.isNotEmpty) {
      return result.first; // This is not null because we checked for emptiness
    } else {
      throw Exception('Account not found with ID: $accountId');
    }
  }

  Future<int> getAccountIdByName(String accountName) async {
    final db = await database;
    final result = await db.query(
      'accounts',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [accountName],
    );
    if (result.isNotEmpty) {
      // Return the 'id' as an int
      return result.first['id'] as int;
    } else {
      throw Exception('Account not found with name: $accountName');
    }
  }

  Future<int> addAccount(Map<String, dynamic> account) async {
    final db = await database;
    try {
      return await db.insert('accounts', {
        'name': account['name'],
        'accountType': account['accountType'],
        'balance': account['balance'],
      });
    } catch (e) {
      print('Error adding account: $e');
      return -1;
    }
  }

  Future<int> updateAccount(Map<String, dynamic> account) async {
    final db = await database;
    try {
      return await db.update(
        'accounts',
        {
          'name': account['name'],
          'accountType': account['accountType'],
          'balance': account['balance'],
        },
        where: 'id = ?',
        whereArgs: [account['id']],
      );
    } catch (e) {
      print('Error updating account: $e');
      return -1;
    }
  }

  Future<double> calculateAccountBalance(int accountId) async {
    final db = await database;
    final transactions = await db.query(
      'transactions',
      where: 'account_id = ? OR from_account_id = ? OR to_account_id = ?',
      whereArgs: [accountId, accountId, accountId],
    );

    double balance = 0.0;

    for (final t in transactions) {
      final amount = (t['amount'] as num).toDouble();
      final type = t['type'] as String;

      switch (type) {
        case 'Income':
          if (t['account_id'] == accountId) {
            balance += amount;
          }
          break;
        case 'Expense':
          if (t['account_id'] == accountId) {
            balance -= amount;
          }
          break;
        case 'Transfer':
          if (t['from_account_id'] == accountId) {
            balance -= amount;
          }
          if (t['to_account_id'] == accountId) {
            balance += amount;
          }
          break;
      }
    }

    return balance;
  }

  Future<int> forceUpdateAccountBalance(int accountId, double newBalance) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE accounts SET balance = ? WHERE id = ?',
      [newBalance, accountId],
    );
  }

  Future<void> _updateAccountBalance(
      DatabaseExecutor db,
      int accountId,
      double amountChange
      ) async {
    try {
      // Use precise raw SQL to avoid any doubling
      await db.rawUpdate(
        'UPDATE accounts SET balance = ROUND(balance + ?, 2) WHERE id = ?',
        [amountChange, accountId],
      );

      // Verify the update
      final updatedAccount = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [accountId],
      );

      debugPrint('Updated account $accountId balance: ${updatedAccount.first['balance']}');
    } catch (e) {
      debugPrint('Error updating account balance: $e');
      rethrow;
    }
  }

  Future<int> updateAccountBalance(int accountId, double newBalance) async {
    try {
      final db = await database;
      return await db.update(
        'accounts',
        {'balance': newBalance},
        where: 'id = ?',
        whereArgs: [accountId],
      );
    } catch (e) {
      print('Error updating account balance: $e');
      return -1;
    }
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    return await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }


  //Transaction Operations
  Future<Map<String, dynamic>?> getTransactionById(int id) async {
    final db = await database;
    final result = await db.query('transactions', where: 'id = ?', whereArgs: [id]);

    if (result.isNotEmpty) {
      return result.first;  // Return the map if it's not empty
    } else {
      return null;  // Return null if no transaction is found
    }
  }

  Future<List<Map<String, dynamic>>> getTransactionsForMonth(int month, int year) async {
    final db = await database;
    final monthStr = month.toString().padLeft(2, '0');
    final yearStr = year.toString();

    return await db.rawQuery('''
      SELECT 
        t.id, 
        t.type, 
        t.date, 
        CASE
          WHEN t.type = 'Transfer' THEN a_from.name
          ELSE a.name
        END AS account,
        CASE
          WHEN t.type = 'Transfer' THEN a_to.name
          ELSE t.category
        END AS category,
        t.subcategory, 
        t.amount, 
        t.note,
        a_from.name AS from_account,
        a_to.name AS to_account
      FROM transactions t
      LEFT JOIN accounts a ON t.account_id = a.id
      LEFT JOIN accounts a_from ON t.from_account_id = a_from.id
      LEFT JOIN accounts a_to ON t.to_account_id = a_to.id
      WHERE substr(t.date, 4, 2) = ? 
      AND substr(t.date, 7, 4) = ?
      ORDER BY t.date DESC
    ''', [monthStr, yearStr]);
  }

  Future<double?> getTotalByTypeForMonth(String type, int month, int year) async {
    final db = await database;
    final monthStr = month.toString().padLeft(2, '0');
    final yearStr = year.toString();

    final result = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM transactions 
      WHERE type = ? 
      AND substr(date, 4, 2) = ? 
      AND substr(date, 7, 4) = ?
    ''', [type, monthStr, yearStr]);

    return result.first['total'] as double?;
  }

  Future<int> insertTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    try {
      return await db.transaction((txn) async {
        // Convert amount to double once
        final amount = (transaction['amount'] as num).toDouble();
        debugPrint('Original amount: $amount');

        // Insert the transaction record
        final transactionId = await txn.insert('transactions', {
          'type': transaction['type'],
          'date': transaction['date'],
          'account_id': transaction['account_id'],
          'from_account_id': transaction['from_account_id'],
          'to_account_id': transaction['to_account_id'],
          'category': transaction['category'],
          'subcategory': transaction['subcategory'] ?? 'No Subcategory',
          'amount': amount, // Use the converted amount
          'note': transaction['note'],
        });

        // Handle balance updates
        switch (transaction['type']) {
          case 'Income':
            if (transaction['account_id'] != null) {
              await _updateAccountBalance(
                txn,
                transaction['account_id'] as int,
                amount,
              );
            }
            break;

          case 'Expense':
            if (transaction['account_id'] != null) {
              await _updateAccountBalance(
                txn,
                transaction['account_id'] as int,
                -amount,
              );
            }
            break;

          case 'Transfer':
            if (transaction['from_account_id'] != null &&
                transaction['to_account_id'] != null) {
              // Deduct from source
              await _updateAccountBalance(
                txn,
                transaction['from_account_id'] as int,
                -amount,
              );
              // Add to destination
              await _updateAccountBalance(
                txn,
                transaction['to_account_id'] as int,
                amount,
              );
            }
            break;
        }

        debugPrint('Database received amount: ${transaction['amount']} (${transaction['amount'].runtimeType})');

        return transactionId;
      });
    } catch (e) {
      debugPrint('Error inserting transaction: $e');
      return -1;
    }
  }

  Future<int> updateTransactionType(int transactionId, String newType,
      {int? fromAccountId, int? toAccountId, String? category}) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Get the original transaction
      final transaction = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      if (transaction.isEmpty) return 0;
      final original = transaction.first;
      final amount = (original['amount'] as num).toDouble();

      // First reverse the original transaction's effect
      switch (original['type'] as String) {
        case 'Income':
          if (original['account_id'] != null) {
            await _updateAccountBalance(
              txn,
              original['account_id'] as int,
              -amount,
            );
          }
          break;
        case 'Expense':
          if (original['account_id'] != null) {
            await _updateAccountBalance(
              txn,
              original['account_id'] as int,
              amount,
            );
          }
          break;
        case 'Transfer':
          if (original['from_account_id'] != null &&
              original['to_account_id'] != null) {
            // Return to source account
            await _updateAccountBalance(
              txn,
              original['from_account_id'] as int,
              amount,
            );
            // Deduct from destination account
            await _updateAccountBalance(
              txn,
              original['to_account_id'] as int,
              -amount,
            );
          }
          break;
      }

      // Apply the new transaction type
      switch (newType) {
        case 'Income':
          if (fromAccountId != null) {
            await _updateAccountBalance(
              txn,
              fromAccountId,
              amount,
            );
          }
          break;
        case 'Expense':
          if (fromAccountId != null) {
            await _updateAccountBalance(
              txn,
              fromAccountId,
              -amount,
            );
          }
          break;
        case 'Transfer':
          if (fromAccountId != null && toAccountId != null) {
            // Deduct from source account
            await _updateAccountBalance(
              txn,
              fromAccountId,
              -amount,
            );
            // Add to destination account
            await _updateAccountBalance(
              txn,
              toAccountId,
              amount,
            );
          }
          break;
      }

      // Update the transaction record
      return await txn.update(
        'transactions',
        {
          'type': newType,
          'account_id': newType == 'Transfer' ? null : fromAccountId,
          'from_account_id': newType == 'Transfer' ? fromAccountId : null,
          'to_account_id': newType == 'Transfer' ? toAccountId : null,
          'category': category,
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
  }

  Future<int> deleteTransaction(int transactionId) async {
    final db = await database;
    try {
      return await db.transaction((txn) async {
        final transaction = await txn.query(
          'transactions',
          where: 'id = ?',
          whereArgs: [transactionId],
        );

        if (transaction.isEmpty) return 0;
        final t = transaction.first;
        final amount = (t['amount'] as num).toDouble();
        debugPrint('Deleting transaction with amount: $amount');

        // Reverse the original transaction
        switch (t['type'] as String) {
          case 'Income':
            if (t['account_id'] != null) {
              await _updateAccountBalance(
                txn,
                t['account_id'] as int,
                -amount,
              );
            }
            break;

          case 'Expense':
            if (t['account_id'] != null) {
              await _updateAccountBalance(
                txn,
                t['account_id'] as int,
                amount,
              );
            }
            break;

          case 'Transfer':
            if (t['from_account_id'] != null && t['to_account_id'] != null) {
              // Return to source
              await _updateAccountBalance(
                txn,
                t['from_account_id'] as int,
                amount,
              );
              // Deduct from destination
              await _updateAccountBalance(
                txn,
                t['to_account_id'] as int,
                -amount,
              );
            }
            break;
        }

        // Finally delete the transaction
        return await txn.delete(
          'transactions',
          where: 'id = ?',
          whereArgs: [transactionId],
        );
      });
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      return -1;
    }
  }


  //Categories & Subcategories Operations
  Future<List<Map<String, dynamic>>> getCategories(String type) async {
    final db = await database;
    return await db.query('categories', where: 'type = ?', whereArgs: [type]);
  }

  Future<List<Map<String, dynamic>>> getCategoriesWithSubcategories(String categoryType) async {
    final db = await database;

    // Query for categories based on type (income or expense)
    final List<Map<String, dynamic>> categories = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [categoryType],
    );

    // Loop through the categories and fetch their subcategories
    for (var category in categories) {
      final categoryId = category['id'];

      // Query subcategories for each category
      final List<Map<String, dynamic>> subcategories = await db.query(
        'subcategories',
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );

      // Add subcategories to the category map
      // This is safe as we are not modifying the QueryRow directly
      category['subcategories'] = subcategories;
    }

    return categories;  // Return categories with their subcategories
  }

  Future<List<Map<String, dynamic>>> getSubcategories(int categoryId) async {
    final db = await database;
    return await db.query('subcategories', where: 'category_id = ?', whereArgs: [categoryId]);
  }

  Future<List<Map<String, dynamic>>> getSubcategoriesByCategoryId(int categoryId) async {
    final db = await database;
    return await db.query(
      'subcategories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }

  Future<int> addCategory(String name, String type) async {
    final db = await database;
    return await db.insert('categories', {'name': name, 'type': type});
  }

  Future<int> addSubcategory(String name, int categoryId) async {
    final db = await database;
    return await db.insert('subcategories', {
      'name': name,
      'category_id': categoryId,
    });
  }

  Future<int> updateCategory(int id, String newName) async {
    final db = await database;
    return await db.update(
      'categories',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateSubcategory(int id, String newName) async {
    final db = await database;
    return await db.update(
      'subcategories',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSubcategory(int id) async {
    final db = await database;
    return await db.delete('subcategories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSubcategoriesByCategoryId(int categoryId) async {
    final db = await database;
    await db.delete(
      'subcategories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }


  //Budget Operations
  Future<List<Map<String, dynamic>>> getBudgets() async {
    final db = await database;
    try {
      return await db.query('budgets');
    } catch (e) {
      // If query fails, try with alternative column name
      try {
        return await db.rawQuery('''
        SELECT 
          id, 
          category_name as category, 
          type, 
          budget_limit, 
          spent, 
          created_at,
          COALESCE(period, 'monthly') as period
        FROM budgets
      ''');
      } catch (e) {
        debugPrint('Error fetching budgets: $e');
        return [];
      }
    }
  }

  Future<int> addBudget(Map<String, dynamic> budget) async {
    final db = await database;
    return await db.insert('budgets', {
      'category': budget['category'],
      'type': budget['type'] ?? 'expense',
      'budget_limit': budget['budget_limit'],
      'current_month_spent': budget['current_month_spent'] ?? 0.0,
      'previous_months_spent': budget['previous_months_spent'] ?? 0.0,
      'year_month': budget['year_month'],
      'created_at': budget['created_at'] ?? DateTime.now().toIso8601String(),
      'is_active': budget['is_active'] ?? 1
    });
  }

  Future<int> updateBudget(Map<String, dynamic> budget) async {
    final db = await database;
    return await db.update(
      'budgets',
      {
        'category': budget['category'],
        'budget_limit': budget['budget_limit'],
        // Add other fields you want to update
      },
      where: 'id = ?',
      whereArgs: [budget['id']],
    );
  }

  Future<int> deleteBudget(int id) async {
    final db = await database;
    return await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  //Transfer-Specific Operations
  Future<List<Map<String, dynamic>>> getTransfers() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT t1.id, t1.date, 
           a1.name as from_account, 
           a2.name as to_account,
           t1.amount, t1.note
    FROM transactions t1
    JOIN transactions t2 ON t1.date = t2.date AND t1.amount = t2.amount
    JOIN accounts a1 ON t1.account_id = a1.id
    JOIN accounts a2 ON t2.account_id = a2.id
    WHERE t1.type = 'Expense' 
      AND t2.type = 'Income'
      AND t1.category = 'Transfer'
      AND t2.category = 'Transfer'
    ORDER BY t1.date DESC
  ''');
  }

}