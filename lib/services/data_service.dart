import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database_helper.dart';

class DataService {
  final DatabaseHelper dbHelper = DatabaseHelper();

  Future<Map<String, dynamic>> getAllData() async {
    final db = await dbHelper.database;

    // Fetch all data from all tables
    final accounts = await db.query('accounts');
    final transactions = await db.query('transactions');
    final categories = await db.query('categories');
    final subcategories = await db.query('subcategories');
    final budgets = await db.query('budgets');
    final goals = await db.query('goals');
    final categoryPreferences = await db.query('category_preferences');

    return {
      'metadata': {
        'version': 1,
        'exportDate': DateTime.now().toIso8601String(),
        'appName': 'Finance Manager',
      },
      'accounts': accounts,
      'transactions': transactions,
      'categories': categories,
      'subcategories': subcategories,
      'budgets': budgets,
      'goals': goals,
      'category_preferences': categoryPreferences,
    };
  }

  // Example method - replace with your actual data saving logic
  Future<void> restoreAllData(Map<String, dynamic> data) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // Clear all tables (order matters due to foreign key constraints)
      await txn.delete('category_preferences');
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('goals');
      await txn.delete('subcategories');
      await txn.delete('categories');
      await txn.delete('accounts');

      // Restore accounts first (referenced by other tables)
      if (data['accounts'] != null) {
        for (final account in data['accounts']) {
          await txn.insert('accounts', account);
        }
      }

      // Restore categories (referenced by subcategories and transactions)
      if (data['categories'] != null) {
        for (final category in data['categories']) {
          await txn.insert('categories', category);
        }
      }

      // Restore subcategories
      if (data['subcategories'] != null) {
        for (final subcategory in data['subcategories']) {
          await txn.insert('subcategories', subcategory);
        }
      }

      // Restore transactions
      if (data['transactions'] != null) {
        for (final transaction in data['transactions']) {
          await txn.insert('transactions', transaction);
        }
      }

      // Restore budgets
      if (data['budgets'] != null) {
        for (final budget in data['budgets']) {
          await txn.insert('budgets', budget);
        }
      }

      // Restore goals
      if (data['goals'] != null) {
        for (final goal in data['goals']) {
          await txn.insert('goals', goal);
        }
      }

      // Restore category preferences
      if (data['category_preferences'] != null) {
        for (final pref in data['category_preferences']) {
          await txn.insert('category_preferences', pref);
        }
      }
    });

    // After restoring, we should recalculate all account balances
    await _recalculateAllAccountBalances();
  }

  Future<void> _recalculateAllAccountBalances() async {
    final db = await dbHelper.database;
    final accounts = await db.query('accounts');

    for (final account in accounts) {
      final accountId = account['id'] as int;
      final newBalance = await dbHelper.calculateAccountBalance(accountId);
      await dbHelper.forceUpdateAccountBalance(accountId, newBalance);
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _backupFile async {
    final path = await _localPath;
    return File('$path/finance_backup.json');
  }

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

  Future<void> exportDataToJson() async {
    try {
      if (!await requestStoragePermission()) {
        throw Exception('Storage permission denied');
      }

      final data = await getAllData();
      final file = await _backupFile;
      await file.writeAsString(jsonEncode(data));
    } on PlatformException catch (e) {
      throw Exception('Failed to export data: ${e.message}');
    }
  }

  Future<void> importDataFromJson() async {
    try {
      if (!await requestStoragePermission()) {
        throw Exception('Storage permission denied');
      }

      final file = await _backupFile;
      if (!await file.exists()) {
        throw Exception('No backup file found');
      }

      final contents = await file.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;
      await restoreAllData(data);
    } on PlatformException catch (e) {
      throw Exception('Failed to import data: ${e.message}');
    }
  }

  Future<void> shareBackupFile(BuildContext context) async {
    try {
      final file = await _backupFile;
      if (!await file.exists()) {
        throw Exception('No backup file found');
      }

      // For sharing functionality, you can use the share_plus package
      // await Share.shareXFiles([XFile(file.path)], text: 'Finance App Backup');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup file ready at: ${file.path}')),
      );
    } catch (e) {
      throw Exception('Failed to share backup: $e');
    }
  }

  Future<void> exportDataToCsv() async {
    try {
      if (!await requestStoragePermission()) {
        throw Exception('Storage permission denied');
      }

      final data = await getAllData();
      final csvData = _convertToCsv(data);
      final file = File('${await _localPath}/finance_backup.csv');
      await file.writeAsString(csvData);
    } on PlatformException catch (e) {
      throw Exception('Failed to export data: ${e.message}');
    }
  }

  String _convertToCsv(Map<String, dynamic> data) {
    final buffer = StringBuffer();

    // Example CSV conversion - adjust based on your data structure
    buffer.writeln('Type,Amount,Date,Category,Description');
    if (data['transactions'] != null) {
      for (final transaction in data['transactions']) {
        buffer.writeln([
          transaction['type'],
          transaction['amount'],
          transaction['date'],
          transaction['category'],
          transaction['description'],
        ].join(','));
      }
    }

    return buffer.toString();
  }

  Future<void> deleteAllData() async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // Delete in reverse order of foreign key dependencies
      await txn.delete('category_preferences');
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('goals');
      await txn.delete('subcategories');
      await txn.delete('categories');
      await txn.delete('accounts');
      await txn.delete('user');
    });
  }
}