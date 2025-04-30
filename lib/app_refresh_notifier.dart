import 'package:flutter/material.dart';

class AppRefreshNotifier extends ChangeNotifier {
  bool _shouldRefreshAccounts = false;
  bool _shouldRefreshTransactions = false;
  bool _shouldRefreshBudgets = false;

  void refreshAccounts() {
    _shouldRefreshAccounts = true;
    notifyListeners();
  }

  void refreshTransactions() {
    _shouldRefreshTransactions = true;
    notifyListeners();
  }

  void refreshBudgets() {
    _shouldRefreshBudgets = true;
  }

  void accountRefreshComplete() {
    _shouldRefreshAccounts = false;
  }

  void transactionRefreshComplete() {
    _shouldRefreshTransactions = false;
  }

  void budgetRefreshComplete() {
    _shouldRefreshBudgets = false;
  }

  bool get shouldRefreshAccounts => _shouldRefreshAccounts;
  bool get shouldRefreshTransactions => _shouldRefreshTransactions;
  bool get shouldRefreshBudgets => _shouldRefreshBudgets;
}