import 'package:flutter/material.dart';
import 'transaction_input_previous.dart'; // Import the transaction input page

class DashboardScreen1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent background
      appBar: AppBar(
        title: Text('Dashboard'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(thickness: 1), // Full-width horizontal line above summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 1.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryText('Income', '4,500', Colors.green),
                _buildSummaryText('Expense', '3,200', Colors.red),
                _buildSummaryText('Total', '1,300', Colors.blueGrey),
              ],
            ),
          ),
          Divider(thickness: 1), // Full-width horizontal line below summary
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
              return DraggableScrollableSheet(
                initialChildSize: 0.82, // Start at 3/4 of the screen
                minChildSize: 0.82,    // Allow the screen to open to 3/4 height
                maxChildSize: 0.82,   // Allow further drag to almost full screen
                expand: false,
                builder: (context, scrollController) {
                  return TransactionPage1(
                    scrollController: scrollController, // Pass scrollController here
                  );
                },
              );
            },
          );
        },
        child: Icon(Icons.add), // Icon for adding a new transaction
        backgroundColor: Colors.blueGrey, // FAB color
      ),
    );
  }

  // Helper widget for summary text
  Widget _buildSummaryText(String title, String amount, Color amountColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center, // Align title and amount center
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        //SizedBox(height: 2), // Small spacing between title and amount
        Text(
          amount,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
      ],
    );
  }
}
