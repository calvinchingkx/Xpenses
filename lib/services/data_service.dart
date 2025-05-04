import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class DataExportException implements Exception {
  final String message;
  DataExportException(this.message);

  @override
  String toString() => 'DataExportException: $message';
}

class DataImportException implements Exception {
  final String message;
  DataImportException(this.message);

  @override
  String toString() => 'DataImportException: $message';
}

class DataService {
  final DatabaseHelper dbHelper = DatabaseHelper();

  Future<Map<String, dynamic>> getAllData() async {
    try {
      final db = await dbHelper.database;

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
    } catch (e) {
      throw DataExportException('Failed to gather data: ${e.toString()}');
    }
  }

  Future<void> restoreAllData(Map<String, dynamic> data) async {
    try {
      if (data['metadata'] == null || data['metadata']['version'] != 1) {
        throw DataImportException('Invalid data format or version');
      }

      final db = await dbHelper.database;

      await db.transaction((txn) async {
        await _clearDatabase(txn);

        if (data['accounts'] != null) {
          await _bulkInsert(txn, 'accounts', data['accounts']);
        }

        if (data['categories'] != null) {
          await _bulkInsert(txn, 'categories', data['categories']);
        }

        if (data['subcategories'] != null) {
          await _bulkInsert(txn, 'subcategories', data['subcategories']);
        }

        if (data['transactions'] != null) {
          await _bulkInsert(txn, 'transactions', data['transactions']);
        }

        if (data['budgets'] != null) {
          await _bulkInsert(txn, 'budgets', data['budgets']);
        }

        if (data['goals'] != null) {
          await _bulkInsert(txn, 'goals', data['goals']);
        }

        if (data['category_preferences'] != null) {
          await _bulkInsert(txn, 'category_preferences', data['category_preferences']);
        }
      });

      await _recalculateAllAccountBalances();
    } catch (e) {
      throw DataImportException('Failed to restore data: ${e.toString()}');
    }
  }

  Future<void> _bulkInsert(DatabaseExecutor db, String table, List<dynamic> items) async {
    final batch = db.batch();
    for (final item in items) {
      batch.insert(table, item as Map<String, dynamic>);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _clearDatabase(DatabaseExecutor db) async {
    await db.delete('category_preferences');
    await db.delete('transactions');
    await db.delete('budgets');
    await db.delete('goals');
    await db.delete('subcategories');
    await db.delete('categories');
    await db.delete('accounts');
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

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.isGranted ||
          await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      final storageStatus = await Permission.storage.request();
      final manageStatus = await Permission.manageExternalStorage.request();

      return storageStatus.isGranted || manageStatus.isGranted;
    }
    return true;
  }

  Future<String> exportDataToJson() async {
    try {
      if (!await requestStoragePermission()) {
        throw DataExportException('Storage permission denied');
      }

      Directory directory;
      if (Platform.isAndroid) {
        // Try to get the public Downloads directory
        if (await _isDownloadsDirectoryAccessible()) {
          directory = Directory('/storage/emulated/0/Download');
        } else {
          // Fallback to app-specific directory
          directory = await getApplicationSupportDirectory();
        }
      } else {
        // For iOS/other platforms
        directory = await getApplicationSupportDirectory();
      }

      // Create a visible filename
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'finance_backup_$timestamp.json';
      final file = File('${directory.path}/$fileName');

      // Make sure the file is created with proper permissions
      final data = await getAllData();
      await file.writeAsString(jsonEncode(data), flush: true);

      // For Android - make the file visible in media scanner
      if (Platform.isAndroid) {
        try {
          await File(file.path).rename(file.path); // Triggers media scan
        } catch (e) {
          debugPrint('Media scan trigger failed: $e');
        }
      }

      return file.path;
    } on PlatformException catch (e) {
      throw DataExportException('Failed to export data: ${e.message}');
    }
  }

  Future<bool> _isDownloadsDirectoryAccessible() async {
    try {
      final dir = Directory('/storage/emulated/0/Download');
      return await dir.exists();
    } catch (e) {
      return false;
    }
  }

  Future<void> importDataFromJson(File file) async {
    try {
      if (!await requestStoragePermission()) {
        throw DataImportException('Storage permission denied');
      }

      if (!await file.exists()) {
        throw DataImportException('No backup file found');
      }

      final contents = await file.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;
      await restoreAllData(data);
    } on PlatformException catch (e) {
      throw DataImportException('Failed to import data: ${e.message}');
    } on FormatException {
      throw DataImportException('Invalid JSON format');
    }
  }

  Future<void> shareBackupFile(BuildContext context) async {
    try {
      final filePath = await exportDataToJson();
      final file = File(filePath);
      await Share.shareXFiles([XFile(file.path)], text: 'Finance App Backup');
    } catch (e) {
      throw DataExportException('Failed to share backup: $e');
    }
  }

  Future<void> deleteAllData() async {
    try {
      final db = await dbHelper.database;
      await db.transaction(_clearDatabase);
    } catch (e) {
      throw DataExportException('Failed to delete data: ${e.toString()}');
    }
  }
}