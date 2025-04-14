import 'package:flutter/material.dart';

class AppRefreshNotifier extends ChangeNotifier {
  bool _shouldRefreshAccounts = false;
  bool _shouldRefreshTransactions = false;

  void refreshAccounts() {
    _shouldRefreshAccounts = true;
    notifyListeners();
  }

  void refreshTransactions() {
    _shouldRefreshTransactions = true;
    notifyListeners();
  }

  void accountRefreshComplete() {
    _shouldRefreshAccounts = false;
  }

  void transactionRefreshComplete() {
    _shouldRefreshTransactions = false;
  }

  bool get shouldRefreshAccounts => _shouldRefreshAccounts;
  bool get shouldRefreshTransactions => _shouldRefreshTransactions;
}