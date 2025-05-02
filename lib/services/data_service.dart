// file: services/data_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DataService {
  // Example method - replace with your actual data model
  Future<Map<String, dynamic>> getAllData() async {
    // TODO: Replace with your actual data fetching logic
    return {
      'transactions': [],
      'categories': [],
      'accounts': [],
      'settings': {},
      'backupDate': DateTime.now().toIso8601String(),
    };
  }

  // Example method - replace with your actual data saving logic
  Future<void> restoreAllData(Map<String, dynamic> data) async {
    // TODO: Replace with your actual data restoration logic
    print('Restoring data: $data');
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
}