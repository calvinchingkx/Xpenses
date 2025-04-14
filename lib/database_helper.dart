import 'dart:async';
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

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'budget.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    balance REAL DEFAULT 0.0,
    accountType TEXT DEFAULT 'Cash'
  )''');

    await db.execute('''CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT,
      date TEXT,
      account_id INTEGER,
      from_account_id INTEGER,
      to_account_id INTEGER,
      category TEXT,
      subcategory TEXT DEFAULT 'No Subcategory',
      amount REAL,
      note TEXT,
      FOREIGN KEY(account_id) REFERENCES accounts(id),
      FOREIGN KEY(from_account_id) REFERENCES accounts(id),
      FOREIGN KEY(to_account_id) REFERENCES accounts(id)
    )''');

    await db.execute('''CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL
    )''');

    await db.execute('''CREATE TABLE subcategories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      category_id INTEGER,
      FOREIGN KEY(category_id) REFERENCES categories(id)
    )''');

    await db.execute('''CREATE TABLE budgets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category_name TEXT,
      type TEXT,
      budget_limit REAL,
      spent REAL DEFAULT 0.0,
      created_at TEXT
    )''');

    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(type)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE transactions ADD COLUMN subcategory TEXT DEFAULT "No Subcategory"');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE categories ADD COLUMN type TEXT NOT NULL DEFAULT "expense"');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE transactions ADD COLUMN from_account_id INTEGER');
      await db.execute('ALTER TABLE transactions ADD COLUMN to_account_id INTEGER');
      await db.execute('CREATE TABLE budgets (id INTEGER PRIMARY KEY AUTOINCREMENT, category_name TEXT, type TEXT, budget_limit REAL, spent REAL DEFAULT 0.0, created_at TEXT)');
    }
    if (oldVersion < 5) {
      await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
      await db.execute('CREATE INDEX idx_transactions_type ON transactions(type)');
    }
  }

  Future<double?> getTotalByType(String type) async {
    final db = await database;

    // Query the database to sum the amount based on the type (Income or Expense)
    final result = await db.rawQuery('''
      SELECT SUM(amount) FROM transactions
      WHERE type = ?
    ''', [type]);

    if (result.isNotEmpty && result.first.values.first != null) {
      return result.first.values.first as double?;
    }
    return 0.0; // Return 0.0 if no result or null
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

  // TRANSACTION CRUD
  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
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
    ORDER BY t.date DESC
  ''');
  }

  // Add this to your DatabaseHelper class
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

  Future<int> insertTransaction(Map<String, dynamic> transaction) async {
    try {
      final db = await database;
      return await db.insert('transactions', transaction);
    } catch (e) {
      print('Error inserting transaction: $e');
      return -1; // Indicate failure
    }
  }

  Future<int> updateTransaction(Map<String, dynamic> transaction) async {
    try {
      final db = await database;

      // Ensure 'account' is correctly mapped to 'account_id'
      transaction['account_id'] = await getAccountIdByName(transaction['account']);
      print('Mapped account ID: ${transaction['account_id']}'); // Debug print
      transaction.remove('account'); // Remove 'account' from transaction

      // Get the old transaction details before updating (for balance recalculation)
      final oldTransaction = await getTransactionById(transaction['id']);
      print('Old Transaction: $oldTransaction'); // Debug print

      if (oldTransaction != null) {
        // Get the current account balance using getAccountById
        int accountId = oldTransaction['account_id'];
        final account = await getAccountById(accountId); // This will never be null
        print('Current Account: $account'); // Debug print

        double currentBalance = account['balance'];

        // Calculate the change in balance based on the type of transaction
        double amountDifference = transaction['amount'] - oldTransaction['amount'];
        print('Amount Difference: $amountDifference'); // Debug print

        // Adjust the account balance
        double newBalance = currentBalance + amountDifference;
        print('New Account Balance: $newBalance'); // Debug print

        // First, delete the old transaction
        await db.delete(
          'transactions',
          where: 'id = ?',
          whereArgs: [oldTransaction['id']],
        );
        print('Old transaction deleted');

        // Then, update the account balance
        await updateAccountBalance(accountId, newBalance);
        print('Account balance updated');
      }

      // Finally, add the new transaction
      int insertResult = await db.insert(
        'transactions',
        transaction,
        conflictAlgorithm: ConflictAlgorithm.replace, // Ensure it replaces the transaction if it already exists
      );
      print('New transaction added with result: $insertResult'); // Debug print

      return insertResult;
    } catch (e) {
      print('Error updating transaction: $e');
      return -1;
    }
  }

  Future<int> deleteTransaction(int transactionId) async {
    try {
      final db = await database;

      // Log database open status
      print("Database is open: ${db.isOpen}");

      // Log the transaction ID being deleted
      print("Attempting to delete transaction with ID: $transactionId");

      // Ensure foreign keys are enabled (if necessary)
      await db.rawQuery("PRAGMA foreign_keys = ON;");

      // Perform the deletion
      final result = await db.delete(
        'transactions',  // Table name
        where: 'id = ?',  // The condition for the deletion
        whereArgs: [transactionId],  // ID parameter for the condition
      );

      // Log the result of the delete operation
      print("Delete result: $result");

      return result;  // Will return 1 if deleted, 0 if no rows affected
    } catch (e) {
      // Log any errors
      print('Error deleting transaction: $e');
      return -1;  // Return -1 to indicate failure
    }
  }


  Future<Map<String, dynamic>?> getTransactionById(int id) async {
    final db = await database;
    final result = await db.query('transactions', where: 'id = ?', whereArgs: [id]);

    if (result.isNotEmpty) {
      return result.first;  // Return the map if it's not empty
    } else {
      return null;  // Return null if no transaction is found
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

  // ACCOUNT CRUD
  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await database;
    return await db.query('accounts');
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

  Future<Map<String, dynamic>?> getAccountByName(String accountName) async {
    final db = await database;
    var result = await db.query(
      'accounts',
      where: 'name = ?',
      whereArgs: [accountName],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // CATEGORY CRUD
  Future<List<Map<String, dynamic>>> getCategories(String type) async {
    final db = await database;
    return await db.query('categories', where: 'type = ?', whereArgs: [type]);
  }

  Future<int> addCategory(String name, String type) async {
    final db = await database;
    return await db.insert('categories', {'name': name, 'type': type});
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

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // Method to delete category along with its subcategories
  Future<void> deleteCategoryWithSubcategories(int categoryId) async {
    final db = await database;

    // Delete subcategories first
    await deleteSubcategoriesByCategoryId(categoryId);

    // Then delete the category
    await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }

  // SUBCATEGORY CRUD
  // Get all subcategories for a specific category
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

  // Method to delete subcategories by category ID
  Future<void> deleteSubcategoriesByCategoryId(int categoryId) async {
    final db = await database;
    await db.delete(
      'subcategories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }

  Future<int> addSubcategory(String name, int categoryId) async {
    final db = await database;
    return await db.insert('subcategories', {
      'name': name,
      'category_id': categoryId,
    });
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

  Future<int> deleteSubcategory(int id) async {
    final db = await database;
    return await db.delete('subcategories', where: 'id = ?', whereArgs: [id]);
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

  Future<int> addBudget(String category, String type, double limit) async {
    final db = await database;
    final budget = {
      'category_name': category,
      'type': type,
      'budget_limit': limit,
      'spent': 0.0, // Default value
      'created_at': DateTime.now().toIso8601String(), // Current timestamp
    };
    return await db.insert('budgets', budget);
  }

  /// Get all budgets from the database
  Future<List<Map<String, dynamic>>> getBudgets() async {
    try {
      final db = await database;
      return await db.query('budgets');
    } catch (e) {
      print('Budgets table not available yet: $e');
      return [];
    }
  }
}