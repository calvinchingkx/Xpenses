import 'package:flutter/material.dart';

class TransactionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title for Transaction History
            Text(
              'Transaction History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // List of Transactions
            Expanded(
              child: ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return _buildTransactionCard(transaction);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for individual transaction cards
  Widget _buildTransactionCard(Transaction transaction) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(
          transaction.isIncome ? Icons.arrow_circle_up : Icons.arrow_circle_down,
          color: transaction.isIncome ? Colors.green : Colors.red,
          size: 30,
        ),
        title: Text(
          transaction.category,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(transaction.date),
        trailing: Text(
          (transaction.isIncome ? '+ ' : '- ') + '\$${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: transaction.isIncome ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }
}

// Sample transaction data class
class Transaction {
  final String category;
  final String date;
  final double amount;
  final bool isIncome;

  Transaction({
    required this.category,
    required this.date,
    required this.amount,
    required this.isIncome,
  });
}

// Sample list of transactions
final List<Transaction> transactions = [
  Transaction(category: 'Salary', date: 'Nov 1, 2024', amount: 5000.00, isIncome: true),
  Transaction(category: 'Groceries', date: 'Nov 2, 2024', amount: 150.75, isIncome: false),
  Transaction(category: 'Rent', date: 'Nov 3, 2024', amount: 1200.00, isIncome: false),
  Transaction(category: 'Electricity Bill', date: 'Nov 4, 2024', amount: 80.50, isIncome: false),
  Transaction(category: 'Freelance Project', date: 'Nov 5, 2024', amount: 600.00, isIncome: true),
];
