import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'app_refresh_notifier.dart';
import 'database_helper.dart';

class TransactionPage extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback? onDismiss;

  const TransactionPage({
    Key? key,
    required this.scrollController,
    this.onDismiss,
  }) : super(key: key);

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class ReceiptData {
  final String? amount;
  final String? note;
  final String? date;

  ReceiptData({this.amount, this.note, this.date});
}

class _TransactionPageState extends State<TransactionPage> {
  String selectedTransactionType = "Expense";
  DateTime selectedDate = DateTime.now();
  String? selectedAccount;
  String? selectedCategory;
  String? selectedSubcategory;

  List<String> accountTypes = [];
  List<String> categories = [];
  List<String> subcategories = [];

  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final accounts = await DatabaseHelper.instance.getAccounts();
      setState(() {
        accountTypes = accounts.map((e) => e['name'] as String).toList();
        if (accountTypes.isNotEmpty) selectedAccount = accountTypes.first;
      });
      await _loadCategories(selectedTransactionType.toLowerCase());
    } catch (e) {
      _showError('Failed to load data: ${e.toString()}');
    }
  }

  Future<void> _loadCategories(String type) async {
    try {
      List<Map<String, dynamic>> items = [];

      if (type == 'transfer') {
        final allAccounts = await DatabaseHelper.instance.getAccounts();
        items = allAccounts.where((account) => account['name'] != selectedAccount).toList();
      } else {
        items = await DatabaseHelper.instance.getCategories(type);
      }

      setState(() {
        categories = items.map((e) => e['name'] as String).toList();
        selectedCategory = categories.isNotEmpty ? categories.first : null;
        selectedSubcategory = null;
        subcategories.clear();
      });

      if (selectedCategory != null && type != 'transfer') {
        await _loadSubcategories(selectedCategory!);
      }
    } catch (e) {
      _showError('Failed to load categories: ${e.toString()}');
    }
  }

  Future<void> _loadSubcategories(String categoryName) async {
    if (selectedTransactionType == 'Transfer') return;

    try {
      final categoriesFromDb = await DatabaseHelper.instance
          .getCategories(selectedTransactionType.toLowerCase());
      final category = categoriesFromDb.firstWhere(
            (c) => c['name'] == categoryName,
        orElse: () => {'id': -1},
      );

      List<String> newSubcategories = [];
      String? newSelectedSubcategory = null;

      if (category['id'] != -1) {
        final subcategoriesFromDb = await DatabaseHelper.instance
            .getSubcategoriesByCategoryId(category['id']);
        newSubcategories = subcategoriesFromDb.isNotEmpty
            ? subcategoriesFromDb.map((e) => e['name'] as String).toList()
            : [];
        newSelectedSubcategory = newSubcategories.isNotEmpty ? newSubcategories.first : null;
      }

      if (mounted) {
        setState(() {
          subcategories = newSubcategories;
          selectedSubcategory = newSelectedSubcategory;
        });
      }
    } catch (e) {
      _showError('Failed to load subcategories: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate() || _isProcessing) return;

    setState(() => _isProcessing = true);
    final refreshNotifier = Provider.of<AppRefreshNotifier>(context, listen: false);

    try {
      if (selectedTransactionType == 'Transfer') {
        await _handleTransfer(refreshNotifier);
      } else {
        await _handleRegularTransaction(refreshNotifier);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onDismiss?.call();
      }
    } catch (e) {
      _showError('Failed to save: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRegularTransaction(AppRefreshNotifier refreshNotifier) async {
    final accountId = await DatabaseHelper.instance.getAccountIdByName(selectedAccount!);
    final amount = double.parse(amountController.text);

    final categoryPreference = await DatabaseHelper.instance.getCategoryPreference(noteController.text);

    if (categoryPreference != null) {
      selectedCategory = categoryPreference['category'];
      selectedSubcategory = categoryPreference['subcategory'];
    }

    final transaction = {
      'type': selectedTransactionType,
      'date': _formatDate(selectedDate),
      'account_id': accountId,
      'category': selectedCategory ?? '',
      'subcategory': selectedSubcategory ?? '',
      'amount': amount,
      'note': noteController.text,
    };

    await DatabaseHelper.instance.saveCategoryPreference(
      noteController.text.trim().toLowerCase(),
      selectedCategory ?? '',
      selectedSubcategory ?? '',
    );

    await DatabaseHelper.instance.insertTransaction(transaction);
    await _updateAccountBalance(accountId, amount, selectedTransactionType);

    refreshNotifier.refreshAccounts();
    refreshNotifier.refreshTransactions();
  }

  Future<void> _predictCategoryFromNote(String note) async {
    final normalizedNote = note.trim().toLowerCase();

    try {
      final predictedCategory = await DatabaseHelper.instance.getCategoryPreference(normalizedNote);

      if (predictedCategory != null && mounted) {
        final predictedCat = predictedCategory['category']!;
        final predictedSub = predictedCategory['subcategory'];

        // Load subcategories FIRST
        await _loadSubcategories(predictedCat);

        if (mounted) {
          setState(() {
            selectedCategory = predictedCat;
            selectedSubcategory = subcategories.contains(predictedSub) ? predictedSub : null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error predicting category: $e');
    }
  }

  Future<void> _handleTransfer(AppRefreshNotifier refreshNotifier) async {
    if (selectedAccount == null || selectedCategory == null) {
      throw Exception('Please select both accounts');
    }

    final fromAccountId = await DatabaseHelper.instance.getAccountIdByName(selectedAccount!);
    final toAccountId = await DatabaseHelper.instance.getAccountIdByName(selectedCategory!);
    final amount = double.parse(amountController.text);

    final transfer = {
      'type': 'Transfer',
      'date': _formatDate(selectedDate),
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'amount': amount,
      'note': noteController.text,
    };

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.insert('transactions', transfer);

      final fromAccount = (await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [fromAccountId],
      )).first;

      final toAccount = (await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [toAccountId],
      )).first;

      await txn.update(
        'accounts',
        {'balance': (fromAccount['balance'] as num).toDouble() - amount},
        where: 'id = ?',
        whereArgs: [fromAccountId],
      );

      await txn.update(
        'accounts',
        {'balance': (toAccount['balance'] as num).toDouble() + amount},
        where: 'id = ?',
        whereArgs: [toAccountId],
      );
    });

    refreshNotifier.refreshAccounts();
    refreshNotifier.refreshTransactions();
  }

  Future<void> _updateAccountBalance(int accountId, double amount, String type) async {
    final account = await DatabaseHelper.instance.getAccount(accountId);
    final currentBalance = (account['balance'] as num).toDouble();
    final newBalance = type == 'Income'
        ? currentBalance + amount
        : currentBalance - amount;
    await DatabaseHelper.instance.updateAccountBalance(accountId, newBalance);
  }

  String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() => selectedDate = pickedDate);
    }
  }

  Future<void> _showImageSourceDialog() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take Photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source != null) {
      await _scanReceiptAndPredict(source);
    }
  }

  Future<void> _scanReceiptAndPredict(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() => _isProcessing = true);

      // Step 1: Preprocess image (improves OCR accuracy)
      final inputImage = await _preprocessImage(File(pickedFile.path));

      // Step 2: Text recognition
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final fullText = recognizedText.text;
      debugPrint("Full OCR Output:\n$fullText");

      // Step 3: Extract transaction details
      final receiptData = _parseReceiptContent(fullText);

      if (receiptData.amount != null) {
        amountController.text = receiptData.amount!;
        if (receiptData.note != null) {
          noteController.text = receiptData.note!;
          await _predictCategoryFromNote(receiptData.note!);
        }
        _showSuccess('Receipt scanned successfully');
      } else {
        _showError('Could not find valid amount in receipt');
      }
    } catch (e) {
      _showError('Failed to process receipt: ${e.toString()}');
      debugPrint('Error scanning receipt: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<InputImage> _preprocessImage(File imageFile) async {
    // In a real app, you might want to add image preprocessing here
    // For now, we'll just use the original image
    return InputImage.fromFile(imageFile);
  }

  ReceiptData _parseReceiptContent(String fullText) {
    final lines = fullText.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    String? amount;
    String? note;
    String? date;

    // Amount detection (more precise)
    amount = _extractBestAmountMatch(lines);

    // Merchant/note detection (smarter)
    note = _extractMostLikelyMerchant(lines);

    // Optional: Date detection
    date = _extractPossibleDate(lines);

    return ReceiptData(amount: amount, note: note, date: date);
  }

  String? _extractBestAmountMatch(List<String> lines) {
    // Try to find amount in reverse order (usually at bottom)
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];

      // Skip lines that are too long to be amounts
      if (line.length > 15) continue;

      // Try different amount patterns
      final amountPatterns = [
        // Currency symbols and common formats
        RegExp(r'[$€£₹¥]\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)'),
        RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\s*(?:USD|EUR|GBP|INR|JPY)'),
        // Standard number formats
        RegExp(r'\b(\d+\.\d{2})\b'),
        RegExp(r'\b(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\b'),
        // Total lines
        RegExp(r'(?:total|amount|balance|due|subtotal)\s*[:=]?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      ];

      for (final pattern in amountPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null && match.group(1) != null) {
          return match.group(1)!.replaceAll(',', '');
        }
      }
    }
    return null;
  }

  String? _extractMostLikelyMerchant(List<String> lines) {
    final excludePatterns = [
      'receipt', 'invoice', 'vat', 'tax', 'subtotal', 'total', 'amount',
      'change', 'date', 'time', 'cash', 'card', 'thank', 'visa', 'mastercard',
      'change', 'qty', 'quantity', 'discount', 'balance', 'due'
    ];

    // First pass: Look for merchant name at top (first 5 lines or less)
    final topLines = lines.length > 5 ? lines.sublist(0, 5) : lines;
    for (final line in topLines) {
      if (_isLikelyMerchant(line, excludePatterns)) {
        return line;
      }
    }

    // Second pass: Look for any line that looks like a merchant
    for (final line in lines) {
      if (_isLikelyMerchant(line, excludePatterns)) {
        return line;
      }
    }

    return null;
  }

  bool _isLikelyMerchant(String line, List<String> excludePatterns) {
    final lowerLine = line.toLowerCase();

    // Skip if:
    // - Too short or too long
    // - Contains numbers
    // - Matches exclude patterns
    // - Looks like a date
    if (line.length < 3 ||
        line.length > 30 ||
        RegExp(r'\d').hasMatch(line) ||
        excludePatterns.any((pattern) => lowerLine.contains(pattern)) ||
        _looksLikeDate(line)) {
      return false;
    }

    // More checks for merchant-like lines
    final words = line.split(' ');
    if (words.length > 5) return false; // Too many words for a merchant name

    // Contains uppercase letters (many merchants have capitalized names)
    if (line == line.toUpperCase()) return true;

    // Contains common merchant suffixes
    const suffixes = ['ltd', 'inc', 'co', 'store', 'shop', 'restaurant'];
    if (suffixes.any((suffix) => lowerLine.endsWith(suffix))) {
      return true;
    }

    return true;
  }

  String? _extractPossibleDate(List<String> lines) {
    final datePatterns = [
      RegExp(r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b'),
      RegExp(r'\b(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})\b', caseSensitive: false),
    ];

    for (final line in lines) {
      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          return match.group(1);
        }
      }
    }
    return null;
  }

  bool _looksLikeDate(String line) {
    return _extractPossibleDate([line]) != null;
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _confirmDiscardChanges() async {
    if (amountController.text.isEmpty && noteController.text.isEmpty) {
      return true;
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscardChanges();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Transaction Type Selector
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildTypeSelector("Income", Colors.green),
                              _buildTypeSelector("Expense", Colors.red),
                              _buildTypeSelector("Transfer", Colors.blue),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Date Picker
                        GestureDetector(
                          onTap: () => _selectDate(context),
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: "Date",
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              controller: TextEditingController(
                                text: DateFormat('dd/MM/yyyy (EEE)').format(selectedDate),
                              ),
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Note Field with prediction for category
                        TextFormField(
                          controller: noteController,
                          decoration: InputDecoration(
                            labelText: "Note",
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.camera_alt),
                              onPressed: _showImageSourceDialog,
                              tooltip: 'Scan receipt',
                            ),
                          ),
                          maxLines: 1,
                          textInputAction: TextInputAction.next,
                          onChanged: _predictCategoryFromNote,
                        ),
                        const SizedBox(height: 20),

                        // Account Dropdown
                        _buildDropdown(
                          selectedTransactionType == 'Transfer' ? 'From Account' : 'Account',
                          accountTypes,
                          selectedAccount,
                              (value) {
                            setState(() => selectedAccount = value);
                            if (selectedTransactionType == 'Transfer') {
                              _loadCategories('transfer');
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // Category/To Account Dropdown
                        _buildDropdown(
                          selectedTransactionType == 'Transfer' ? 'To Account' : 'Category',
                          categories,
                          selectedCategory,
                              (value) async {
                            setState(() => selectedCategory = value);
                            if (selectedTransactionType != 'Transfer' && value != null) {
                              await _loadSubcategories(value);
                            }
                          },
                        ),

                        // Conditionally display Subcategory dropdown
                        if (selectedTransactionType != 'Transfer' && subcategories.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: _buildDropdown(
                              "Subcategory",
                              subcategories,
                              selectedSubcategory,
                                  (value) => setState(() => selectedSubcategory = value),
                            ),
                          ),

                        // Amount Field
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: "Amount",
                            border: OutlineInputBorder(),
                            prefixText: '\$ ',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            if (double.tryParse(value) == null) return 'Invalid amount';
                            if (double.parse(value) <= 0) return 'Must be positive';
                            return null;
                          },
                        ),
                        const SizedBox(height: 80), // Space for fixed button
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Fixed Save Button at Bottom
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isProcessing ? null : _saveTransaction,
              child: _isProcessing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
                  : const Text(
                "SAVE TRANSACTION",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),

          if (_isProcessing)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(String type, Color activeColor) {
    return GestureDetector(
      onTap: () async {
        if (selectedTransactionType != type) {
          setState(() => selectedTransactionType = type);
          await _loadCategories(type.toLowerCase());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selectedTransactionType == type
              ? activeColor.withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
            color: selectedTransactionType == type ? activeColor : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          type,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: selectedTransactionType == type ? activeColor : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
      String label,
      List<String> items,
      String? value,
      ValueChanged<String?> onChanged,
      ) {
    return DropdownButtonFormField<String>(
      value: value ?? (items.isNotEmpty ? items.first : null),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (selectedTransactionType == 'Transfer' &&
            label == 'Account' &&
            newValue == selectedCategory) {
          _showError('Cannot transfer to the same account');
          return;
        }
        onChanged(newValue);
      },
      validator: (value) => value == null ? 'Please select $label' : null,
    );
  }
}