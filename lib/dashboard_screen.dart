import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import this for date formatting
import 'transaction_page.dart';
import 'database_helper.dart';
import 'transaction_detail.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double incomeTotal = 0.0;
  double expenseTotal = 0.0;
  Map<String, List<Map<String, dynamic>>> categorizedTransactions = {};

  DateTime currentMonthDate = DateTime.now(); // Store current month as DateTime

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadTransactions();
  }

  // Set the current month (e.g., "< Nov >")
  String get formattedMonth {
    return DateFormat('MMM').format(currentMonthDate); // Get the abbreviated month (e.g., "Nov")
  }

  // Navigate to the previous month
  void _previousMonth() {
    setState(() {
      currentMonthDate = DateTime(currentMonthDate.year, currentMonthDate.month - 1, 1);
    });
    _loadTransactions();
  }

  // Navigate to the next month
  void _nextMonth() {
    setState(() {
      currentMonthDate = DateTime(currentMonthDate.year, currentMonthDate.month + 1, 1);
    });
    _loadTransactions();
  }

  void _loadDashboardData() async {
    final income = await DatabaseHelper.instance.getTotalByType("Income");
    final expense = await DatabaseHelper.instance.getTotalByType("Expense");

    setState(() {
      incomeTotal = income ?? 0.0;
      expenseTotal = expense ?? 0.0;
    });
  }

  void _loadTransactions() async {
    final allTransactions = await DatabaseHelper.instance.getAllTransactions();

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var transaction in allTransactions) {
      final rawDate = transaction['date']; // Example: "06/12/2024 (Fri)"
      try {
        // Extract only the date part and parse it
        final datePart = rawDate.split(' ').first; // "06/12/2024"
        final parsedDate = DateFormat('dd/MM/yyyy').parse(datePart);

        // Only include transactions from the current month
        if (parsedDate.month == currentMonthDate.month && parsedDate.year == currentMonthDate.year) {
          final formattedDate = DateFormat('dd/MM/yyyy').format(parsedDate); // Consistent format
          if (!grouped.containsKey(formattedDate)) {
            grouped[formattedDate] = [];
          }
          grouped[formattedDate]!.add(transaction);
        }
      } catch (e) {
        print('Error parsing date: $rawDate');
        continue; // Skip transactions with invalid dates
      }
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('dd/MM/yyyy').parse(a);
        final dateB = DateFormat('dd/MM/yyyy').parse(b);
        return dateB.compareTo(dateA); // Sort by descending date
      });

    setState(() {
      categorizedTransactions = {for (var key in sortedKeys) key: grouped[key]!};
    });
  }

  void _openTransactionPage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Material(
            color: Colors.transparent,
            child: DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.75,
              maxChildSize: 0.75,
              builder: (BuildContext context, ScrollController scrollController) {
                return GestureDetector(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: TransactionPage(scrollController: scrollController),
                  ),
                );
              },
            ),
          ),
        );
      },
    ).then((_) {
      _loadDashboardData();
      _loadTransactions();
    });
  }

  void _openTransactionDetailPage(Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Material(
            color: Colors.transparent,
            child: DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.75,
              maxChildSize: 0.75,
              builder: (BuildContext context, ScrollController scrollController) {
                return GestureDetector(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: TransactionDetailPage(transaction: transaction),
                  ),
                );
              },
            ),
          ),
        );
      },
    ).then((_) {
      // Reload the dashboard data and transactions after modification or deletion
      _loadDashboardData();
      _loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Divider(thickness: 1, color: Colors.black45),

          // Row for month navigation: "< Dec 2024 >"
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0), // Adjusted padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_left),
                  onPressed: _previousMonth, // Navigate to the previous month
                ),
                Text(
                  formattedMonth, // Display month and year (e.g., "Dec 2024")
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_right),
                  onPressed: _nextMonth, // Navigate to the next month
                ),
              ],
            ),
          ),

          Divider(thickness: 2, color: Colors.black45),

          // Summary Section: Income, Expenses, Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryText('Income', "\$${incomeTotal.toStringAsFixed(2)}", Colors.blueGrey),
              _buildSummaryText('Expenses', "\$${expenseTotal.toStringAsFixed(2)}", Colors.red),
              _buildSummaryText('Balance', "\$${(incomeTotal - expenseTotal).toStringAsFixed(2)}", Colors.green),
            ],
          ),
          Divider(thickness: 2, color: Colors.black45),

          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 80),
              itemCount: categorizedTransactions.keys.length,
              itemBuilder: (context, index) {
                final date = categorizedTransactions.keys.elementAt(index);
                final transactions = categorizedTransactions[date]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(thickness: 1, color: Colors.black45),
                    // Date Header
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatDate(date), // Display the formatted date
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
                        ),
                      ),
                    ),
                    Divider(thickness: 1, color: Colors.black45),
                    // Transactions for the Date
                    ...transactions.map((transaction) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                        child: GestureDetector(
                          onTap: () {
                            _openTransactionDetailPage(transaction); // Open update/delete page on tap
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Text(
                                    transaction['category'] ?? 'No Category',
                                    style: TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ),
                              ),
                              // Note and Account
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      transaction['note'] ?? 'No Note',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      transaction['account'] ?? 'No Account',
                                      style: TextStyle(fontSize: 14, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              // Amount
                              Text(
                                "\$${transaction['amount'] != null ? transaction['amount'].toStringAsFixed(2) : '0.00'}",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: transaction['type'] == "Income" ? Colors.blueGrey : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openTransactionPage,
        child: Icon(Icons.add),
      ),
    );
  }

  String _formatDate(String date) {
    try {
      // Parse the date string (assuming the format is dd/MM/yyyy)
      final parsedDate = DateFormat('dd/MM/yyyy').parse(date);
      // Return the formatted date in "dd/MM/yyyy (EEE)" format (including the weekday)
      return DateFormat('dd/MM/yyyy (EEE)').format(parsedDate);
    } catch (e) {
      // Return the original date if parsing fails
      return date;
    }
  }

  Widget _buildSummaryText(String title, String amount, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
        ),
        Text(
          amount,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

}
