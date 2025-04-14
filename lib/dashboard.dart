import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting and Account Summary
            Text(
              'Hello, User!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Here’s a summary of your financials:',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 16),

            // Example Summary Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard('Income', '\$4,500', Colors.green),
                _buildSummaryCard('Expenses', '\$3,200', Colors.red),
                _buildSummaryCard('Balance', '\$1,300', Colors.blue),
              ],
            ),
            SizedBox(height: 24),

            // Navigation Buttons
            Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(context, 'Add Income', Icons.add_circle, Colors.green),
                _buildActionButton(context, 'Add Expense', Icons.remove_circle, Colors.red),
                _buildActionButton(context, 'View Report', Icons.pie_chart, Colors.blue),
              ],
            ),
            SizedBox(height: 24),

            // Monthly Overview Chart (Placeholder)
            Expanded(
              child: Center(
                child: Text(
                  'Monthly Overview Chart Placeholder',
                  style: TextStyle(color: Colors.grey[500], fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for summary cards
  Widget _buildSummaryCard(String title, String amount, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for action buttons
  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: color, size: 30),
          onPressed: () {
            // Handle navigation or action here
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label clicked!')),
            );
          },
        ),
        Text(label, style: TextStyle(fontSize: 14)),
      ],
    );
  }
}
